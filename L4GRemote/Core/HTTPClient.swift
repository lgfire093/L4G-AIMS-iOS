import Foundation

struct HTTPResult {
    let status: Int
    let text: String
}

enum HTTPFailure: LocalizedError {
    case badURL
    case transport(String)
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid panel address"
        case .transport(let message): return message
        case .server(let code): return "Panel returned HTTP \(code)"
        }
    }
}

enum HTTPClient {
    /// Main API session: 8 s request / 12 s resource, no cache, no cookies.
    static let api: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.httpAdditionalHeaders = ["Accept": "*/*"]
        return URLSession(configuration: configuration)
    }()

    /// Discovery probes abort fast so a /24 sweep stays bounded.
    static let probe: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 0.9
        configuration.timeoutIntervalForResource = 1.2
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }()

    static func get(_ url: URL, session: URLSession = api, timeout: TimeInterval? = nil) async throws -> HTTPResult {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(AppConfig.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        if let timeout { request.timeoutInterval = timeout }
        return try await send(request, session: session)
    }

    /// Android POSTs the base64 ciphertext as an octet-stream body, not JSON.
    static func postEncrypted(_ url: URL, json: [String: Any]) async throws -> HTTPResult {
        let plainData: Data
        do {
            plainData = try JSONSerialization.data(withJSONObject: json, options: [])
        } catch {
            throw HTTPFailure.transport("Cannot encode request")
        }
        guard let plaintext = String(data: plainData, encoding: .utf8) else {
            throw HTTPFailure.transport("Cannot encode request")
        }
        let ciphertext = CryptoBox.encrypt(plaintext)
        guard let body = ciphertext.data(using: .utf8) else {
            throw HTTPFailure.transport("Cannot encode request")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
        return try await send(request, session: api)
    }

    /// KeyAuth expects application/x-www-form-urlencoded with Android's `+` for space.
    static func postForm(_ url: URL, fields: [(String, String)]) async throws -> String {
        let body = fields
            .map { "\(formEncode($0.0))=\(formEncode($0.1))" }
            .joined(separator: "&")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("KeyAuth", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        let result = try await send(request, session: api)
        return result.text
    }

    private static func send(_ request: URLRequest, session: URLSession) async throws -> HTTPResult {
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let text = String(data: data, encoding: .utf8) ?? ""
            if status >= 400 {
                if !text.isEmpty { return HTTPResult(status: status, text: text) }
                throw HTTPFailure.server(status)
            }
            return HTTPResult(status: status, text: text)
        } catch let failure as HTTPFailure {
            throw failure
        } catch let error as URLError {
            throw HTTPFailure.transport(Self.describe(error))
        } catch {
            throw HTTPFailure.transport(error.localizedDescription)
        }
    }

    private static func describe(_ error: URLError) -> String {
        switch error.code {
        case .timedOut: return "Panel timed out"
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed: return "Panel unreachable"
        case .networkConnectionLost: return "Connection lost"
        case .notConnectedToInternet: return "No network"
        case .appTransportSecurityRequiresSecureConnection: return "Blocked by ATS"
        default: return error.localizedDescription
        }
    }

    private static func formEncode(_ value: String) -> String {
        var out = ""
        for byte in value.utf8 {
            switch byte {
            case 0x30...0x39, 0x41...0x5A, 0x61...0x7A, 0x2D, 0x2E, 0x5F, 0x2A:
                out.append(Character(UnicodeScalar(byte)))
            case 0x20:
                out.append("+")
            default:
                out += String(format: "%%%02X", byte)
            }
        }
        return out
    }
}
