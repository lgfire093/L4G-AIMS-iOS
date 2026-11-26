import SwiftUI
import UIKit

struct SettingsView: View {
    var onLogout: () -> Void

    @EnvironmentObject private var store: PanelStore
    @EnvironmentObject private var auth: KeyAuthClient

    @State private var manualIP = ""
    @State private var pingNote: String?
    @State private var pingColor = Theme.textSecondary
    @State private var busy = false
    @State private var showLogoutConfirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                serverCard
                gameCard
                accountCard
                updateCard
                logsCard
                footer
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .onAppear { manualIP = store.serverIP }
        .confirmationDialog("Log out of L4G AIMS?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Log out", role: .destructive, action: onLogout)
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Server link

    private var serverCard: some View {
        GlassCard(accent: Theme.cyan) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(text: "PC panel link", color: Theme.cyan)
                    Spacer()
                    HStack(spacing: 6) {
                        ConnectionDot(online: store.connected)
                        Text(store.connected ? "LINKED" : "OFFLINE")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .tracking(0.8)
                            .foregroundColor(store.connected ? Theme.neonGreen : Theme.crimson)
                    }
                }

                HStack {
                    Text(store.serverIP)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    if let ms = store.lastPingMS {
                        Text("\(ms) ms")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.cyan)
                    }
                }

                TextField("192.168.1.10", text: $manualIP)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .modifier(DarkField())

                HStack(spacing: 9) {
                    Button {
                        saveIP()
                    } label: {
                        HStack(spacing: 6) {
                            if busy {
                                ProgressView().progressViewStyle(.circular).tint(Theme.cyan).scaleEffect(0.7)
                            }
                            Text("SAVE & TEST")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.cyan))
                    .disabled(busy)

                    Button {
                        Task {
                            busy = true
                            let ok = await store.ping(ip: store.serverIP)
                            busy = false
                            pingNote = ok ? "Panel responded. Control channel live." : "Panel did not respond."
                            pingColor = ok ? Theme.neonGreen : Theme.crimson
                        }
                    } label: {
                        Text("PING")
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.violet))
                    .disabled(busy)
                }

                if let pingNote {
                    Text(pingNote)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(pingColor)
                }

                Text("The panel binds TCP 5000 on all interfaces. iPhone and PC must share the same Wi-Fi.")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.textDim)
            }
        }
    }

    // MARK: - Game target

    private var gameCard: some View {
        GlassCard(accent: Theme.violet) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Target game", color: Theme.violet)

                HStack(spacing: 8) {
                    gameButton(key: "ffmax", label: "FF MAX")
                    gameButton(key: "ffindia", label: "FF INDIA")
                    gameButton(key: "ffmax64", label: "MAX 64")
                }

                Button {
                    Task {
                        busy = true
                        _ = await store.connectGame()
                        busy = false
                    }
                } label: {
                    Text("⚡ CONNECT GAME")
                }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.neonGreen))
                .disabled(busy)

                if !store.state.aimLastScan.isEmpty {
                    Text("Last scan: \(store.state.aimLastScan)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(1)
                }
            }
        }
    }

    private func gameButton(key: String, label: String) -> some View {
        let selected = store.state.game == key
        return Button {
            Task { _ = await store.selectGame(key) }
        } label: {
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.7)
                .foregroundColor(selected ? Theme.bg : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(selected ? Theme.cyan : Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Theme.cyan.opacity(selected ? 0 : 0.22), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Account

    private var accountCard: some View {
        GlassCard(accent: Theme.violet) {
            VStack(alignment: .leading, spacing: 11) {
                SectionLabel(text: "Account", color: Theme.textSecondary)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(auth.username.isEmpty ? "Signed in" : auth.username)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.textPrimary)
                        Text(auth.expiry.isEmpty ? "KeyAuth session" : "Expires: \(auth.expiry)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.textDim)
                    }
                    Spacer()
                    StatusPill(text: "KEYAUTH", color: Theme.violet)
                }

                Button {
                    showLogoutConfirm = true
                } label: {
                    Text("LOG OUT")
                }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.crimson))
            }
        }
    }

    // MARK: - Updates

    private var updateCard: some View {
        GlassCard(accent: Theme.cyanStroke) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    SectionLabel(text: "Updates", color: Theme.textSecondary)
                    Spacer()
                    Text("v\(AppConfig.bundleVersion) (\(AppConfig.buildNumber))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textDim)
                }

                if let update = store.update {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("L4G AIMS \(update.version) available")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.neonGreen)
                        Text(update.notes)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let url = update.downloadURL {
                            Button {
                                UIApplication.shared.open(url)
                            } label: {
                                Text("OPEN DOWNLOAD")
                            }
                            .buttonStyle(PrimaryButtonStyle(tint: Theme.neonGreen))
                            .padding(.top, 3)
                        }
                    }
                } else {
                    Text("You are on the current iOS build. Updates are checked against the panel manifest.")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.textDim)
                }

                Button {
                    Task { await store.checkForUpdate(force: true) }
                } label: {
                    Text("CHECK FOR UPDATES")
                }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.cyan))
            }
        }
    }

    // MARK: - Panel logs

    private var logsCard: some View {
        GlassCard(accent: Theme.cyanStroke) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "Panel log", color: Theme.textSecondary)
                    Spacer()
                    Text("\(store.logs.count) events")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(Theme.textDim)
                }

                if store.logs.isEmpty {
                    Text("No panel events yet.")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.textDim)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(store.logs.suffix(6)) { entry in
                            HStack(alignment: .top, spacing: 6) {
                                Text(entry.time)
                                    .foregroundColor(Theme.textDim)
                                Text(entry.message)
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(2)
                            }
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                        }
                    }
                    .padding(9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.35))
                    )
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("L4G AIMS for iOS  ·  LAN controller")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textDim)
            Text("AES-256-GCM  ·  UDP 5005 DISCOVERY  ·  TCP 5000")
                .font(.system(size: 8, weight: .heavy, design: .rounded))
                .tracking(1.1)
                .foregroundColor(Theme.textDim.opacity(0.6))
        }
        .padding(.top, 4)
    }

    private func saveIP() {
        let ip = manualIP.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ip.isEmpty else {
            pingNote = "Enter the PC panel IP first."
            pingColor = Theme.crimson
            return
        }
        busy = true
        pingNote = "Testing \(ip):5000..."
        pingColor = Theme.sky
        Task {
            let ok = await store.saveServerIP(ip)
            busy = false
            pingNote = ok ? "Saved. Panel responded on \(ip)." : "Saved, but no response from \(ip)."
            pingColor = ok ? Theme.neonGreen : Theme.crimson
        }
    }
}
