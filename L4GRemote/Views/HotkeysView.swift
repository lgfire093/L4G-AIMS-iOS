import SwiftUI

struct HotkeysView: View {
    @EnvironmentObject private var store: PanelStore

    private struct Action: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let defaultKey: String
        let defaultsKey: String
        let icon: String
    }

    private let actions: [Action] = [
        Action(id: "refresh_entity", title: "Refresh Entity", subtitle: "Scan targets / refresh matrix",
               defaultKey: "F1", defaultsKey: AppConfig.DefaultsKey.hotkeyRefresh, icon: "scope"),
        Action(id: "aimbot_toggle", title: "Aimbot Toggle", subtitle: "Toggle head aim on the PC",
               defaultKey: "F2", defaultsKey: AppConfig.DefaultsKey.hotkeyAimbot, icon: "target"),
        Action(id: "real_aimbot_toggle", title: "Real Aimbot Toggle", subtitle: "Toggle real aimbot snap",
               defaultKey: "F3", defaultsKey: AppConfig.DefaultsKey.hotkeyRealAimbot, icon: "bolt.horizontal")
    ]

    @State private var bindings: [String: String] = [:]
    @State private var pickerAction: Action?
    @State private var status = "Tap a card to trigger · tap the key to rebind"
    @State private var statusColor = Theme.textDim

    private let defaults = UserDefaults.standard

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                headerCard
                ForEach(actions) { action in
                    actionCard(action)
                }
                syncCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .onAppear(perform: loadBindings)
        .sheet(item: $pickerAction) { action in
            KeyPickerSheet(
                actionTitle: action.title,
                current: bindings[action.id] ?? action.defaultKey
            ) { key in
                bind(action, key: key)
            }
        }
    }

    private var headerCard: some View {
        GlassCard(accent: Theme.cyan) {
            VStack(alignment: .leading, spacing: 7) {
                SectionLabel(text: "Remote hotkeys", color: Theme.cyan)
                Text(status)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(statusColor)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Bindings are stored on the iPhone and pushed to the PC panel. Tap a card for an instant trigger.")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.textDim)
            }
        }
    }

    private func actionCard(_ action: Action) -> some View {
        GlassCard(accent: Theme.violet) {
            HStack(spacing: 12) {
                Image(systemName: action.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Theme.violet)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.violet.opacity(0.12)))
                    .overlay(Circle().stroke(Theme.violet.opacity(0.32), lineWidth: 1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    Text(action.subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.textDim)
                }

                Spacer(minLength: 4)

                Button {
                    pickerAction = action
                } label: {
                    Text(bindings[action.id] ?? action.defaultKey)
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(Theme.cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Theme.cyan.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Theme.cyan.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                trigger(action)
            }
        }
    }

    private var syncCard: some View {
        GlassCard(accent: Theme.cyanStroke) {
            HStack(spacing: 10) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(Theme.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("PANEL SYNC")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(1.3)
                        .foregroundColor(Theme.textSecondary)
                    Text(store.connected ? "Hotkey channel linked to \(store.serverIP)" : "Waiting for panel link")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.textDim)
                }
                Spacer()
                ConnectionDot(online: store.connected)
            }
        }
    }

    // MARK: - Actions

    private func loadBindings() {
        var loaded: [String: String] = [:]
        for action in actions {
            loaded[action.id] = defaults.string(forKey: action.defaultsKey) ?? action.defaultKey
        }
        bindings = loaded
    }

    private func trigger(_ action: Action) {
        status = "Triggering \(action.title)..."
        statusColor = Theme.sky
        Task {
            let output = await store.triggerHotkey(action.id)
            if let output {
                status = "Executed: \(output)"
                statusColor = Theme.neonGreen
            } else {
                status = "Trigger failed"
                statusColor = Theme.crimson
            }
        }
    }

    private func bind(_ action: Action, key: String) {
        bindings[action.id] = key
        defaults.set(key, forKey: action.defaultsKey)
        status = "Binding \(action.title) → \(key)"
        statusColor = Theme.cyan
        Task {
            let output = await store.setHotkey(action.id, key: key)
            if output != nil {
                status = "Bound \(action.title) → \(key)"
                statusColor = Theme.neonGreen
            }
        }
    }
}

// MARK: - Key picker

private struct KeyPickerSheet: View {
    let actionTitle: String
    let current: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private let mouseKeys = ["MOUSE1", "MOUSE2", "MOUSE3", "MOUSE4", "MOUSE5"]
    private let functionKeys = (1...12).map { "F\($0)" }
    private let specialKeys = ["SHIFT", "CTRL", "ALT", "SPACE", "TAB", "CAPSLOCK", "ENTER", "ESCAPE", "DELETE"]
    private let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init)
    private let numbers = (0...9).map(String.init)

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)

    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SELECT KEY")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .tracking(1.4)
                            .foregroundColor(Theme.textPrimary)
                        Text(actionTitle.uppercased())
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .tracking(1.2)
                            .foregroundColor(Theme.cyan)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textSecondary)
                            .padding(9)
                            .background(Circle().fill(Color.white.opacity(0.06)))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        group("MOUSE", keys: mouseKeys)
                        group("FUNCTION", keys: functionKeys)
                        group("SPECIAL", keys: specialKeys)
                        group("LETTERS", keys: letters)
                        group("NUMBERS", keys: numbers)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private func group(_ title: String, keys: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel(text: title, color: Theme.textDim)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(keys, id: \.self) { key in
                    Button {
                        onSelect(key)
                        dismiss()
                    } label: {
                        Text(key)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(key == current ? Theme.bg : Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(key == current ? Theme.cyan : Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Theme.cyan.opacity(key == current ? 0 : 0.16), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
