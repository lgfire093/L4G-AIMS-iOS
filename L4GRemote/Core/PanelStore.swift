import Foundation
import UIKit

/// Single source of truth for the dashboard. Owns the panel client, the 1 s
/// state poll, discovery, and optimistic ESP toggles.
@MainActor
final class PanelStore: ObservableObject {
    struct Banner: Identifiable, Equatable {
        enum Kind { case success, failure, info }
        let id = UUID()
        let message: String
        let kind: Kind
    }

    @Published private(set) var serverIP: String
    @Published private(set) var connected = false
    @Published private(set) var discovering = false
    @Published private(set) var state = PanelState()
    @Published private(set) var logs: [PanelLogEntry] = []
    @Published private(set) var lastPingMS: Int?
    @Published private(set) var update: IOSUpdate?
    @Published var banner: Banner?

    private var api: PanelAPI
    private var discovery: PanelDiscovery?
    private var pollTask: Task<Void, Never>?
    private var bannerTask: Task<Void, Never>?
    private var started = false
    private var consecutiveFailures = 0
    private var lastUpdateCheck = Date.distantPast

    private let defaults = UserDefaults.standard
    private static let deviceID: String = {
        let key = "L4G.device_id"
        if let saved = UserDefaults.standard.string(forKey: key) { return saved }
        let generated = "l4g-ios-" + UUID().uuidString.lowercased()
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }()

    init() {
        let saved = UserDefaults.standard.string(forKey: AppConfig.DefaultsKey.panelIP) ?? "127.0.0.1"
        serverIP = saved
        api = PanelAPI(serverIP: saved)
    }

    var controllerOnline: Bool { state.controllerOnline }

    // MARK: - Lifecycle

    func start() {
        guard !started else { return }
        started = true
        api = PanelAPI(serverIP: serverIP)
        beginDiscovery()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sync()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stop() {
        started = false
        pollTask?.cancel()
        pollTask = nil
        bannerTask?.cancel()
        discovery?.cancel()
        discovery = nil
    }

    // MARK: - State sync

    func sync() async {
        do {
            let json = try await api.getState()
            let parsed = PanelState.parse(json)
            state = parsed
            connected = true
            consecutiveFailures = 0
            discovering = false
            discovery?.cancel()
            discovery = nil
            parseLogs(json)

            if let updateBlock = json["update"] as? [String: Any],
               (updateBlock["force_remote_update"] as? Bool) == true {
                await checkForUpdate(force: false)
            }
        } catch {
            connected = false
            consecutiveFailures += 1
            // Give the wired/LAN link a few seconds, then re-run discovery.
            if consecutiveFailures == 15 && !discovering {
                beginDiscovery()
            }
        }
    }

    private func parseLogs(_ json: [String: Any]) {
        guard let raw = json["logs"] as? [[String: Any]] else { return }
        logs = raw.suffix(30).map { entry in
            PanelLogEntry(
                time: entry["t"] as? String ?? "",
                kind: entry["kind"] as? String ?? "",
                message: entry["msg"] as? String ?? ""
            )
        }
    }

    // MARK: - Discovery

    private func beginDiscovery() {
        discovery?.cancel()
        discovering = true
        let cached = defaults.string(forKey: AppConfig.DefaultsKey.panelIP)
        let scanner = PanelDiscovery()
        discovery = scanner
        scanner.run(cachedIP: cached) { [weak self] ip in
            Task { @MainActor in
                self?.handleDiscovered(ip)
            }
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000_000)
            guard let self else { return }
            if self.discovering && !self.connected { self.discovering = false }
        }
    }

    private func handleDiscovered(_ ip: String) {
        guard started else { return }
        discovery?.cancel()
        discovery = nil
        discovering = false
        if ip != serverIP || !connected {
            setServerIP(ip, persist: true)
            flash("Panel found at \(ip)", kind: .success)
        }
        connected = true
        Task {
            await sync()
            await checkForUpdate(force: true)
        }
    }

    // MARK: - Manual link

    func setServerIP(_ ip: String, persist: Bool) {
        let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        serverIP = trimmed
        api.setServerIP(trimmed)
        if persist { defaults.set(trimmed, forKey: AppConfig.DefaultsKey.panelIP) }
    }

    func saveServerIP(_ ip: String) async -> Bool {
        setServerIP(ip, persist: true)
        return await ping(ip: serverIP)
    }

    @discardableResult
    func ping(ip: String) async -> Bool {
        let started = Date()
        do {
            _ = try await api.checkStatus()
            lastPingMS = Int(Date().timeIntervalSince(started) * 1000)
            connected = true
            flash("PC panel online (\(lastPingMS ?? 0) ms)", kind: .success)
            await sync()
            return true
        } catch {
            connected = false
            lastPingMS = nil
            flash("Connection failed: \(error.localizedDescription)", kind: .failure)
            return false
        }
    }

    // MARK: - Commands

    @discardableResult
    func command(_ command: String) async -> String? {
        do {
            let output = try await api.executeCommand(command)
            connected = true
            return output
        } catch {
            connected = false
            flash(error.localizedDescription, kind: .failure)
            return nil
        }
    }

    @discardableResult
    func action(_ action: String, value: Any?) async -> String? {
        do {
            let output = try await api.sendAction(action, value: value)
            connected = true
            return output
        } catch {
            connected = false
            flash(error.localizedDescription, kind: .failure)
            return nil
        }
    }

    func connectGame() async -> String? {
        let output = await command("connect_game")
        if let output { flash(output, kind: .success) }
        return output
    }

    func selectGame(_ key: String) async -> String? {
        let output = await command("game:\(key)")
        if let output { flash(output, kind: .success) }
        return output
    }

    func aimHead(on: Bool) async -> String? {
        let output = await command(on ? "aimbotexton" : "aimbotextoff")
        if let output { flash(output, kind: .success) }
        return output
    }

    func scanPlayers() async -> String? {
        let output = await command("aimbotextload")
        if let output { flash(output, kind: .success) }
        return output
    }

    func realAimbot(on: Bool) async -> String? {
        let output = await command(on ? "realaimboton" : "realaimbotoff")
        if let output { flash(output, kind: .success) }
        return output
    }

    func setRealPower(_ power: Int) async -> String? {
        let clamped = min(max(power, 1), 100)
        let output = await command("realaimbotpower:\(clamped)")
        if let output { flash(output, kind: .info) }
        return output
    }

    func visibleScan() async -> String? {
        let output = await command("collider_scan")
        if let output { flash(output, kind: .success) }
        return output
    }

    func visibleAim(on: Bool) async -> String? {
        let output = await command(on ? "aimbot_ext:on" : "aimbot_ext:off")
        if let output { flash(output, kind: .success) }
        return output
    }

    func desktopESP(on: Bool) async -> String? {
        let output = await command(on ? "desktop_esp:on" : "desktop_esp:off")
        if let output { flash(output, kind: .success) }
        return output
    }

    func refreshESP() async -> String? {
        let output = await command("esprefresh")
        if let output { flash(output, kind: .info) }
        return output
    }

    func setESP(feature: String, on: Bool) async {
        state.setESP(feature: feature, value: on)
        let output = await action("esp_toggle", value: ["feature": feature, "state": on])
        if let output, !isActionOK(output) {
            state.setESP(feature: feature, value: !on)
            flash(message(from: output) ?? "\(feature) toggle failed", kind: .failure)
        }
    }

    func externalESP(on: Bool) async -> String? {
        state.externalESP = on
        let output = await action("external_esp", value: on)
        if let output, isActionOK(output) {
            flash(on ? "External ESP stream started" : "External ESP stopped", kind: .success)
            return message(from: output) ?? output
        }
        state.externalESP = !on
        if let output { flash(message(from: output) ?? "External ESP failed", kind: .failure) }
        return nil
    }

    func triggerHotkey(_ actionID: String) async -> String? {
        let output = await command("hotkey_trigger:\(actionID)")
        if let output { flash(output, kind: .success) }
        return output
    }

    func setHotkey(_ actionID: String, key: String) async -> String? {
        let output = await command("hotkey_set:\(actionID):\(key)")
        if let output { flash("Hotkey bound: \(key)", kind: .info) }
        return output
    }

    // MARK: - Updates

    func checkForUpdate(force: Bool) async {
        let now = Date()
        guard force || now.timeIntervalSince(lastUpdateCheck) > 20 else { return }
        lastUpdateCheck = now
        if let found = await UpdateService.check(serverIP: serverIP, deviceID: Self.deviceID) {
            update = found
        }
    }

    // MARK: - Banners

    func flash(_ message: String, kind: Banner.Kind) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        bannerTask?.cancel()
        banner = Banner(message: trimmed, kind: kind)
        bannerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            guard !Task.isCancelled else { return }
            self?.banner = nil
        }
    }

    func clearBanner() {
        bannerTask?.cancel()
        banner = nil
    }

    // MARK: - JSON helpers

    private func isActionOK(_ raw: String) -> Bool {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return true
        }
        if let ok = object["ok"] as? Bool { return ok }
        if let ok = object["ok"] as? NSNumber { return ok.boolValue }
        return true
    }

    private func message(from raw: String) -> String? {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object["message"] as? String ?? object["output"] as? String
    }
}
