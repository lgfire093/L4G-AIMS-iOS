import Foundation

/// Client for the Windows panel. Mirrors `com.l4g.remote.PanelApi`.
final class PanelAPI: @unchecked Sendable {
    private(set) var serverIP: String

    init(serverIP: String) {
        self.serverIP = serverIP.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func setServerIP(_ ip: String) {
        let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { serverIP = trimmed }
    }

    func baseURL(path: String) -> URL? {
        var raw = serverIP
        if raw.isEmpty { raw = "127.0.0.1" }
        if !raw.lowercased().hasPrefix("http://") && !raw.lowercased().hasPrefix("https://") {
            raw = "http://" + raw
        }
        guard var components = URLComponents(string: raw) else { return nil }
        if components.port == nil { components.port = AppConfig.panelPort }
        let basePath = components.path
        components.path = basePath + path
        return components.url
    }

    func executeCommand(_ command: String) async throws -> String {
        guard let url = baseURL(path: AppConfig.pathExecute) else { throw HTTPFailure.badURL }
        let response = try await HTTPClient.postEncrypted(url, json: ["command": command])
        let decrypted = CryptoBox.decrypt(response.text)
        if let data = decrypted.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let output = object["output"] as? String {
            return output
        }
        return decrypted
    }

    func sendAction(_ action: String, value: Any?) async throws -> String {
        guard let url = baseURL(path: AppConfig.pathAction) else { throw HTTPFailure.badURL }
        var payload: [String: Any] = ["action": action]
        if let value { payload["value"] = value }
        let response = try await HTTPClient.postEncrypted(url, json: payload)
        return CryptoBox.decrypt(response.text)
    }

    func getState() async throws -> [String: Any] {
        guard let url = baseURL(path: AppConfig.pathState) else { throw HTTPFailure.badURL }
        let response = try await HTTPClient.get(url)
        return Self.decodeObject(response.text)
    }

    func getLogs() async throws -> [[String: Any]] {
        guard let url = baseURL(path: AppConfig.pathLogs) else { throw HTTPFailure.badURL }
        let response = try await HTTPClient.get(url)
        let object = Self.decodeObject(response.text)
        return object["logs"] as? [[String: Any]] ?? []
    }

    func checkStatus() async throws -> String {
        guard let url = baseURL(path: AppConfig.pathStatus) else { throw HTTPFailure.badURL }
        let response = try await HTTPClient.get(url)
        return CryptoBox.decrypt(response.text)
    }

    static func decodeObject(_ text: String) -> [String: Any] {
        let decrypted = CryptoBox.decrypt(text)
        guard let data = decrypted.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }

    /// One-shot reachability check used by discovery and the manual link screen.
    static func probe(host: String, timeout: TimeInterval = 0.9) async -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let api = PanelAPI(serverIP: trimmed)
        guard let url = api.baseURL(path: AppConfig.pathState) else { return false }
        do {
            let result = try await HTTPClient.get(url, session: HTTPClient.probe, timeout: timeout)
            return result.status == 200
        } catch {
            return false
        }
    }
}
