import Foundation
import UIKit

/// Minimal MJPEG client for `/stream/video.mjpeg`.
/// The panel emits `--frame\r\nContent-Type: image/jpeg\r\nContent-Length: N\r\n\r\n<bytes>`.
final class MJPEGStream: NSObject, ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var buffer = Data()
    private var shouldRun = false
    private var currentURL: URL?
    private var retryWorkItem: DispatchWorkItem?

    func start(url: URL) {
        currentURL = url
        shouldRun = true
        lastError = nil
        open()
    }

    func stop() {
        shouldRun = false
        retryWorkItem?.cancel()
        retryWorkItem = nil
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
        buffer.removeAll()
        DispatchQueue.main.async { self.isRunning = false }
    }

    private func open() {
        guard shouldRun, let url = currentURL else { return }
        task?.cancel()
        session?.invalidateAndCancel()
        buffer.removeAll()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = .infinity
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = [
            "Accept": "*/*",
            "User-Agent": AppConfig.userAgent
        ]

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated

        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        self.session = session

        var request = URLRequest(url: url)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        let task = session.dataTask(with: request)
        self.task = task
        task.resume()

        DispatchQueue.main.async {
            self.isRunning = true
            self.lastError = nil
        }
    }

    private func scheduleRetry(_ message: String) {
        guard shouldRun else { return }
        DispatchQueue.main.async {
            self.lastError = message
            self.isRunning = false
        }
        retryWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.shouldRun else { return }
            self.open()
        }
        retryWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    private func feed(_ data: Data) {
        buffer.append(data)
        let headerSeparator = Data([13, 10, 13, 10])

        while true {
            guard let headerRange = buffer.range(of: headerSeparator) else { return }
            let headerData = buffer[buffer.startIndex..<headerRange.lowerBound]
            guard let header = String(data: headerData, encoding: .utf8) else {
                buffer.removeAll()
                return
            }

            var contentLength: Int?
            for line in header.components(separatedBy: "\r\n") {
                let lower = line.lowercased()
                if lower.hasPrefix("content-length:") {
                    let value = line.drop(while: { $0 != ":" }).dropFirst()
                    contentLength = Int(value.trimmingCharacters(in: .whitespaces))
                }
            }

            guard let length = contentLength, length > 0 else {
                // No length: drop this part header and wait for the next separator.
                buffer.removeSubrange(buffer.startIndex..<headerRange.upperBound)
                continue
            }

            let bodyStart = headerRange.upperBound
            let available = buffer.distance(from: bodyStart, to: buffer.endIndex)
            guard available >= length else { return }

            let bodyEnd = bodyStart + length
            let jpeg = buffer.subdata(in: bodyStart..<bodyEnd)
            buffer.removeSubrange(buffer.startIndex..<bodyEnd)

            if let decoded = UIImage(data: jpeg) {
                DispatchQueue.main.async {
                    self.image = decoded
                    self.isRunning = true
                }
            }
        }
    }
}

extension MJPEGStream: URLSessionDataDelegate {
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            completionHandler(.cancel)
            scheduleRetry("Stream HTTP \(http.statusCode)")
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        feed(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            scheduleRetry(error.localizedDescription)
        } else if shouldRun {
            scheduleRetry("Stream ended")
        }
    }
}
