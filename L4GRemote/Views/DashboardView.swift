import SwiftUI
import UIKit

struct DashboardView: View {
    var onLogout: () -> Void

    @EnvironmentObject private var auth: KeyAuthClient
    @StateObject private var store = PanelStore()

    @State private var tab: Tab = .dashboard
    @State private var category: Category = .aimbot
    @State private var showLogoutConfirm = false
    @State private var showUpdateAlert = false
    @State private var connectBusy = false

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case external = "External"
        case hotkeys = "Hotkeys"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .dashboard: return "gauge.with.dots.needle.67percent"
            case .external: return "play.rectangle.on.rectangle"
            case .hotkeys: return "keyboard"
            case .settings: return "slider.horizontal.3"
            }
        }
    }

    enum Category: String, CaseIterable {
        case aimbot = "Aimbot"
        case collider = "Collider"
        case esp = "ESP"
    }

    var body: some View {
        ZStack {
            ScreenBackground()

            VStack(spacing: 0) {
                header
                if tab == .dashboard {
                    categoryBar
                }
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomBar
            }
        }
        .panelBanner(store.banner, onDismiss: store.clearBanner)
        .environmentObject(store)
        .onAppear {
            store.start()
            Task { await store.checkForUpdate(force: true) }
        }
        .onDisappear { store.stop() }
        .onChange(of: store.update) { update in
            if update != nil { showUpdateAlert = true }
        }
        .alert("Update available", isPresented: $showUpdateAlert) {
            if let url = store.update?.downloadURL {
                Button("Open download") { UIApplication.shared.open(url) }
            }
            Button("Later", role: .cancel) {}
        } message: {
            if let update = store.update {
                Text("L4G AIMS \(update.version) is available.\n\n\(update.notes)")
            }
        }
        .confirmationDialog("End this session?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Log out", role: .destructive, action: onLogout)
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ConnectionDot(online: store.connected)
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text("L4G AIMS")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .tracking(1.4)
                        .foregroundColor(Theme.textPrimary)
                    StatusPill(
                        text: store.discovering ? "SCANNING" : (store.connected ? "LINKED" : "NO LINK"),
                        color: store.discovering ? Theme.amber : (store.connected ? Theme.emerald : Theme.crimson)
                    )
                }
                Text(store.serverIP)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(Theme.textDim)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button {
                connectGame()
            } label: {
                HStack(spacing: 5) {
                    if connectBusy {
                        ProgressView().progressViewStyle(.circular).tint(Theme.textPrimary).scaleEffect(0.7)
                    }
                    Text(store.controllerOnline ? "ONLINE" : "CONNECT")
                }
            }
            .buttonStyle(HeaderPillStyle(
                tint: store.controllerOnline ? Theme.emerald : Theme.crimson,
                filled: store.controllerOnline
            ))
            .disabled(connectBusy)

            Button {
                showLogoutConfirm = true
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .padding(9)
                    .background(Circle().fill(Color.white.opacity(0.05)))
                    .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: - Category pills

    private var categoryBar: some View {
        HStack(spacing: 8) {
            ForEach(Category.allCases, id: \.self) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { category = item }
                } label: {
                    Text(item.rawValue.uppercased())
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.0)
                        .foregroundColor(category == item ? Theme.textPrimary : Theme.textDim)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(category == item
                                      ? Theme.cyan.opacity(0.16)
                                      : Color.white.opacity(0.035))
                        )
                        .overlay(
                            Capsule()
                                .stroke(category == item
                                        ? Theme.cyan.opacity(0.55)
                                        : Color.white.opacity(0.06),
                                        lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .dashboard:
            ScrollView(showsIndicators: false) {
                Group {
                    switch category {
                    case .aimbot: AimbotView()
                    case .collider: ColliderView()
                    case .esp: ESPView()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        case .external:
            ExternalView()
        case .hotkeys:
            HotkeysView()
        case .settings:
            SettingsView(onLogout: onLogout)
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { item in
                IconTabButton(icon: item.icon, title: item.rawValue, selected: tab == item) {
                    withAnimation(.easeInOut(duration: 0.15)) { tab = item }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 2)
        .background(
            Rectangle()
                .fill(Theme.surface.opacity(0.96))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.cyan.opacity(0.16))
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func connectGame() {
        guard !connectBusy else { return }
        connectBusy = true
        Task {
            _ = await store.connectGame()
            connectBusy = false
        }
    }
}

struct HeaderPillStyle: ButtonStyle {
    let tint: Color
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(1.1)
            .foregroundColor(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(tint.opacity(filled ? 0.18 : 0.08))
            )
            .overlay(Capsule().stroke(tint.opacity(0.45), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
