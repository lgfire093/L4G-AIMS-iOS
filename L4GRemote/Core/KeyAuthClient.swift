import CryptoKit
import Foundation
import UIKit

/// KeyAuth 1.2 client, ported from `com.l4g.remote.KeyAuth`.
/// Same app credentials, same form fields, same success semantics.
@MainActor
final class KeyAuthClient: ObservableObject {
    @Published private(set) var username: String = ""
    @Published private(set) var expiry: String = ""
    @Published private(set) var isLoggedIn: Bool = false

    private var sessionID: String?
    private let defaults = UserDefaults.standard

    init() {
        sessionID = defaults.string(forKey: AppConfig.DefaultsKey.keyAuthSession)
        username = defaults.string(forKey: AppConfig.DefaultsKey.keyAuthUser) ?? ""
        expiry = defaults.string(forKey: AppConfig.DefaultsKey.keyAuthExpiry) ?? ""
        isLoggedIn = defaults.bool(forKey: AppConfig.DefaultsKey.keyAuthLoggedIn)
    }

    // MARK: - Public flow

    func login(user: String, password: String) async -> String? {
        if let error = await ensureInitialized() { return error }

        let fields: [(String, String)] = [
            ("type", "login"),
            ("username", user),
            ("pass", password),
            ("password", password),
            ("sessionid", sessionID ?? ""),
            ("name", AppConfig.KeyAuth.appName),
            ("ownerid", AppConfig.KeyAuth.ownerID),
            ("hwid", Self.hardwareID())
        ]

        do {
            let raw = try await HTTPClient.postForm(Self.apiURL, fields: fields)
            let response = Self.json(raw)
            guard Self.success(response) else {
                let message = response["message"] as? String ?? "Login failed"
                if message.lowercased().contains("session") { sessionID = nil }
                return message
            }

            if let info = response["info"] as? [String: Any] {
                username = info["username"] as? String ?? user
                expiry = info["expiry"] as? String ?? "Lifetime"
                sessionID = info["sessionid"] as? String ?? sessionID
            } else {
                username = user
                expiry = "Active"
            }

            persist(session: sessionID, user: username, expiry: expiry, loggedIn: true)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func register(user: String, password: String, license: String) async -> String? {
        if let error = await ensureInitialized() { return error }

        let fields: [(String, String)] = [
            ("type", "register"),
            ("username", user),
            ("pass", password),
            ("password", password),
            ("key", license),
            ("license", license),
            ("sessionid", sessionID ?? ""),
            ("name", AppConfig.KeyAuth.appName),
            ("ownerid", AppConfig.KeyAuth.ownerID),
            ("hwid", Self.hardwareID())
        ]

        do {
            let raw = try await HTTPClient.postForm(Self.apiURL, fields: fields)
            let response = Self.json(raw)
            guard Self.success(response) else {
                let message = response["message"] as? String ?? "Registration failed"
                if message.lowercased().contains("session") { sessionID = nil }
                return message
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func logout() {
        sessionID = nil
        username = ""
        expiry = ""
        isLoggedIn = false
        defaults.removeObject(forKey: AppConfig.DefaultsKey.keyAuthSession)
        defaults.removeObject(forKey: AppConfig.DefaultsKey.keyAuthUser)
        defaults.removeObject(forKey: AppConfig.DefaultsKey.keyAuthExpiry)
        defaults.set(false, forKey: AppConfig.DefaultsKey.keyAuthLoggedIn)
    }

    // MARK: - Session

    private func ensureInitialized() async -> String? {
        if let sessionID, !sessionID.isEmpty { return nil }

        let fields: [(String, String)] = [
            ("type", "init"),
            ("ver", AppConfig.KeyAuth.version),
            ("name", AppConfig.KeyAuth.appName),
            ("ownerid", AppConfig.KeyAuth.ownerID)
        ]
        do {
            let raw = try await HTTPClient.postForm(Self.apiURL, fields: fields)
            let response = Self.json(raw)
            guard Self.success(response),
                  let newSession = response["sessionid"] as? String,
                  !newSession.isEmpty else {
                return response["message"] as? String ?? "KeyAuth initialization failed"
            }
            sessionID = newSession
            defaults.set(newSession, forKey: AppConfig.DefaultsKey.keyAuthSession)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func persist(session: String?, user: String, expiry: String, loggedIn: Bool) {
        defaults.set(session, forKey: AppConfig.DefaultsKey.keyAuthSession)
        defaults.set(user, forKey: AppConfig.DefaultsKey.keyAuthUser)
        defaults.set(expiry, forKey: AppConfig.DefaultsKey.keyAuthExpiry)
        defaults.set(loggedIn, forKey: AppConfig.DefaultsKey.keyAuthLoggedIn)
    }

    // MARK: - Helpers

    private static var apiURL: URL {
        URL(string: AppConfig.KeyAuth.apiURL)!
    }

    private static func json(_ raw: String) -> [String: Any] {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }

    private static func success(_ response: [String: Any]) -> Bool {
        if let value = response["success"] as? Bool { return value }
        if let value = response["success"] as? NSNumber { return value.boolValue }
        return false
    }

    /// iOS equivalent of Android's ANDROID_ID + Build fingerprint hash.
    /// identifierForVendor is per-vendor, stable across reinstalls of this bundle only.
    private static func hardwareID() -> String {
        let device = UIDevice.current
        let vendor = device.identifierForVendor?.uuidString ?? UUID().uuidString
        let raw = "\(vendor):\(device.model):\(device.systemName):\(device.systemVersion)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
