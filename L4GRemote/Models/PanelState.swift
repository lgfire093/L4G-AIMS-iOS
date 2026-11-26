import Foundation

/// Decoded view of the panel's `/v1/diagnostics/session/sync` snapshot.
/// The panel is authoritative; every field is optional and defaults to the
/// same values as `NativePort/state.cpp`.
struct PanelState: Equatable {
    var runtimeOnline = false
    var serviceConnected = false
    var engineActive = false
    var aimbotActive = false
    var aimHead = false
    var realAimbotActive = false
    var realAimbotPower = 50
    var colliderCount = 0
    var entityCount = 0
    var aimStatus = ""
    var aimLastScan = ""
    var esp = ESPFlags()
    var externalESP = false
    var game = "ffmax"
    var hotkeys: [String: String] = [:]

    struct ESPFlags: Equatable {
        var line = true
        var box = true
        var filledBox = true
        var health = true
        var glow = true
        var counter = true
        var wukong = true
        var skeleton = true
        var master = false
    }

    var controllerOnline: Bool { runtimeOnline || serviceConnected || engineActive }

    static func parse(_ json: [String: Any]) -> PanelState {
        var state = PanelState()
        let runtime = json["runtime"] as? [String: Any] ?? [:]
        let aimbot = json["aimbot"] as? [String: Any] ?? [:]
        let real = json["real_aimbot"] as? [String: Any] ?? [:]
        let esp = json["esp"] as? [String: Any] ?? [:]
        let settings = json["settings"] as? [String: Any] ?? [:]
        let game = json["game"] as? [String: Any] ?? [:]

        state.runtimeOnline = bool(runtime["online"])
        state.serviceConnected = bool(runtime["service_connected"])
        state.engineActive = bool(runtime["engine_active"])
        state.aimbotActive = bool(aimbot["active"])
        state.aimHead = bool(aimbot["aim_head"])
        state.realAimbotActive = bool(real["active"])
        state.realAimbotPower = clampInt(real["power"], default: 50, lower: 1, upper: 100)
        state.colliderCount = int(json["collider_count"]) ?? int(runtime["collider_count"]) ?? 0
        state.entityCount = int(runtime["aimbotext_count"]) ?? int(runtime["entities"]) ?? 0
        state.aimStatus = string(runtime["aim_status"])
        state.aimLastScan = string(runtime["aim_last_scan"])

        state.esp.line = bool(esp["line"], default: true)
        state.esp.box = bool(esp["box"], default: true)
        state.esp.filledBox = bool(esp["filled_box"], default: true)
        state.esp.health = bool(esp["health"], default: true)
        state.esp.glow = bool(esp["glow"], default: true)
        state.esp.counter = bool(esp["counter"], default: true)
        state.esp.wukong = bool(esp["wukong"], default: true)
        state.esp.skeleton = bool(esp["skeleton"], default: true)
        state.esp.master = bool(esp["master"])
        state.externalESP = bool(settings["external_esp"]) || bool(settings["phone_esp"])

        let selected = string(game["selected"])
        state.game = selected.isEmpty ? "ffmax" : selected

        if let hotkeys = json["hotkeys"] as? [String: Any] {
            for (key, value) in hotkeys {
                if let text = value as? String { state.hotkeys[key] = text }
            }
        }
        return state
    }

    // MARK: - ESP lookup

    func espValue(for feature: String) -> Bool {
        switch feature {
        case "line": return esp.line
        case "box": return esp.box
        case "filled_box": return esp.filledBox
        case "health": return esp.health
        case "glow": return esp.glow
        case "counter": return esp.counter
        case "wukong": return esp.wukong
        case "skeleton": return esp.skeleton
        default: return false
        }
    }

    mutating func setESP(feature: String, value: Bool) {
        switch feature {
        case "line": esp.line = value
        case "box": esp.box = value
        case "filled_box": esp.filledBox = value
        case "health": esp.health = value
        case "glow": esp.glow = value
        case "counter": esp.counter = value
        case "wukong": esp.wukong = value
        case "skeleton": esp.skeleton = value
        default: break
        }
    }

    // MARK: - Coercion helpers

    private static func bool(_ value: Any?, default fallback: Bool = false) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String { return value == "1" || value.lowercased() == "true" }
        return fallback
    }

    private static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? Double { return Int(value) }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private static func clampInt(_ value: Any?, default fallback: Int, lower: Int, upper: Int) -> Int {
        let parsed = int(value) ?? fallback
        return min(max(parsed, lower), upper)
    }

    private static func string(_ value: Any?) -> String {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return ""
    }
}

struct PanelLogEntry: Identifiable, Equatable {
    let id = UUID()
    let time: String
    let kind: String
    let message: String
}

struct IOSUpdate: Equatable {
    let version: String
    let downloadURL: URL?
    let notes: String
}
