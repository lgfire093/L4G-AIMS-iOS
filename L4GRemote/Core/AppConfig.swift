import Foundation

/// Wire-level constants shared with the Windows panel and the Android client.
/// Everything here must stay byte-identical to `PanelApi.java` / `KeyAuth.java`.
enum AppConfig {
    static let appName = "L4G AIMS"
    static let bundleVersion = "14.0"
    static let buildNumber = "14"

    static let panelPort = 5000
    static let discoveryPort: UInt16 = 5005

    // Stealth telemetry-disguised routes exposed by NativePort/http.cpp
    static let pathExecute = "/msdownload/update/v3/telemetry/events"
    static let pathAction = "/msdownload/update/v3/telemetry/events"
    static let pathState = "/v1/diagnostics/session/sync"
    static let pathLogs = "/v1/diagnostics/session/logs"
    static let pathStatus = "/generate_204"
    static let pathUpdate = "/api/update/check"
    static let pathStream = "/stream/video.mjpeg"
    static let pathEspBoxes = "/api/esp/boxes"

    static let discoveryRequest = "SYNC_REQ:5000"
    static let discoveryAckPrefixes = ["SYNC_ACK", "L4G_BEACON"]

    /// AES-256-GCM pre-shared key. 12-byte IV is prepended, tag appended.
    static let gcmKey = Data([
        0x4d, 0x37, 0x78, 0x39, 0x24, 0x71, 0x4b, 0x32,
        0x23, 0x76, 0x50, 0x38, 0x2a, 0x7a, 0x4c, 0x34,
        0x21, 0x77, 0x45, 0x31, 0x5e, 0x74, 0x52, 0x35,
        0x28, 0x79, 0x55, 0x30, 0x29, 0x69, 0x4f, 0x33
    ])

    static let userAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
        "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"

    static let cloudManifestURL =
        "https://raw.githubusercontent.com/Lgfire444/L4G-Panel-Update/main/version.json"

    enum KeyAuth {
        static let appName = "Lgfire444's Application"
        static let ownerID = "X80YJg29Pu"
        static let secret = "58ab00395357ca22e571d7e04ee072fdd824e1e06253068a586902a35207b9cb"
        static let version = "1.0"
        static let apiURL = "https://keyauth.win/api/1.2/"
    }

    enum DefaultsKey {
        static let panelIP = "PanelPrefs.last_server_ip"
        static let rememberMe = "L4G_AuthPrefs.remember_me"
        static let savedUser = "L4G_AuthPrefs.saved_user"
        static let savedPass = "L4G_AuthPrefs.saved_pass"

        static let keyAuthSession = "KeyAuthPrefs.session_id"
        static let keyAuthUser = "KeyAuthPrefs.username"
        static let keyAuthExpiry = "KeyAuthPrefs.expiry"
        static let keyAuthLoggedIn = "KeyAuthPrefs.is_logged_in"

        static let hotkeyRefresh = "HotkeyPrefs.key_refresh"
        static let hotkeyAimbot = "HotkeyPrefs.key_aimbot"
        static let hotkeyRealAimbot = "HotkeyPrefs.key_real_aimbot"
    }
}
