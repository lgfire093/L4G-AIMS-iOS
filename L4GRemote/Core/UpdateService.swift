import Foundation

/// Update channel for the iOS client.
///
/// The Windows panel only publishes `pc` and `apk` blocks, so the iOS build
/// looks for an `ios` block in the same GitHub manifest the panel already uses:
///
/// {
///   "pc":  { "version": "14.0", "download_url": "..." },
///   "apk": { "version": "14.0", "version_code": 14, "download_url": "..." },
///   "ios": { "version": "14.0", "download_url": "https://.../L4G_Remote.ipa",
///            "notes": "..." }
/// }
enum UpdateService {
    static func check(serverIP: String, deviceID: String) async -> IOSUpdate? {
        // Primary: the panel's own update endpoint, same call the APK makes.
        if let panelUpdate = await checkPanel(serverIP: serverIP, deviceID: deviceID) {
            return panelUpdate
        }
        return await checkManifest()
    }

    private static func checkPanel(serverIP: String, deviceID: String) async -> IOSUpdate? {
        var raw = serverIP.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return nil }
        if !raw.lowercased().hasPrefix("http://") && !raw.lowercased().hasPrefix("https://") {
            raw = "http://" + raw
        }
        var components = URLComponents(string: raw)
        if components?.port == nil { components?.port = AppConfig.panelPort }
        components?.path = AppConfig.pathUpdate
        components?.queryItems = [
            URLQueryItem(name: "target", value: "all"),
            URLQueryItem(name: "device", value: deviceID)
        ]
        guard let url = components?.url else { return nil }

        do {
            let result = try await HTTPClient.get(url)
            guard let data = result.text.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            // Panel has no ios block today; keep parsing for forward compatibility.
            if let ios = root["ios"] as? [String: Any],
               let update = makeUpdate(ios) {
                return update
            }
            return nil
        } catch {
            return nil
        }
    }

    private static func checkManifest() async -> IOSUpdate? {
        guard let url = URL(string: AppConfig.cloudManifestURL) else { return nil }
        do {
            let result = try await HTTPClient.get(url)
            guard let data = result.text.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ios = root["ios"] as? [String: Any] else {
                return nil
            }
            return makeUpdate(ios)
        } catch {
            return nil
        }
    }

    private static func makeUpdate(_ block: [String: Any]) -> IOSUpdate? {
        let version = (block["version"] as? String)
            ?? (block["latest_version"] as? String)
            ?? ""
        guard !version.isEmpty, version != AppConfig.bundleVersion else { return nil }

        let urlString = (block["download_url"] as? String) ?? ""
        let notes = (block["notes"] as? String)
            ?? (block["changelog"] as? String)
            ?? "New performance and stability improvements."

        return IOSUpdate(
            version: version,
            downloadURL: URL(string: urlString),
            notes: notes
        )
    }
}
