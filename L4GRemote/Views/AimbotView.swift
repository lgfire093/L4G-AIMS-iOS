import SwiftUI

struct AimbotView: View {
    @EnvironmentObject private var store: PanelStore

    @State private var statusLine = "Ready"
    @State private var statusColor = Theme.textSecondary
    @State private var busyCommand: String?
    @State private var power = 50.0
    @State private var editingPower = false

    var body: some View {
        VStack(spacing: 12) {
            scanCard
            aimHeadCard
            realAimbotCard
        }
        .onAppear { power = Double(store.state.realAimbotPower) }
        .onChange(of: store.state.realAimbotPower) { value in
            if !editingPower { power = Double(value) }
        }
    }

    // MARK: - Scan / count

    private var scanCard: some View {
        GlassCard(accent: Theme.cyan) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    SectionLabel(text: "Entity scanner", color: Theme.cyan)
                    Spacer()
                    StatusPill(
                        text: "\(store.state.entityCount) targets",
                        color: store.state.entityCount > 0 ? Theme.neonGreen : Theme.textSecondary
                    )
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(statusLine)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(statusColor)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }

                HStack(spacing: 9) {
                    Button {
                        runScan()
                    } label: {
                        HStack(spacing: 6) {
                            if busyCommand == "scan" {
                                ProgressView().progressViewStyle(.circular).tint(Theme.cyan).scaleEffect(0.7)
                            }
                            Text("SCAN PLAYERS")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.cyan))
                    .disabled(busyCommand != nil)

                    Button {
                        Task {
                            _ = await store.refreshESP()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.violet))
                    .frame(width: 52)
                }

                if !store.state.aimStatus.isEmpty {
                    Text(store.state.aimStatus)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.textDim)
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - Aim head

    private var aimHeadCard: some View {
        GlassCard(accent: store.state.aimHead ? Theme.greenStroke : Theme.cyan) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(text: "Head aim", color: Theme.cyan)
                    Spacer()
                    StatusPill(
                        text: store.state.aimHead ? "ACTIVE" : "STANDBY",
                        color: store.state.aimHead ? Theme.neonGreen : Theme.textSecondary,
                        filled: store.state.aimHead
                    )
                }

                Text(store.state.aimHead ? "AIM HEAD ON (Active)" : "AIM HEAD OFF (Restored)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(store.state.aimHead ? Theme.neonGreen : Theme.textDim)

                HStack(spacing: 9) {
                    Button {
                        setAimHead(true)
                    } label: {
                        Text("AIM HEAD ON")
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.neonGreen))
                    .disabled(busyCommand != nil)

                    Button {
                        setAimHead(false)
                    } label: {
                        Text("AIM HEAD OFF")
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.crimson))
                    .disabled(busyCommand != nil)
                }
            }
        }
    }

    // MARK: - Real aimbot

    private var realAimbotCard: some View {
        GlassCard(accent: store.state.realAimbotActive ? Theme.greenStroke : Theme.cyanStroke) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    SectionLabel(text: "Real aimbot", color: Theme.cyan)
                    Spacer()
                    StatusPill(
                        text: store.state.realAimbotActive ? "REAL AIM: ON" : "REAL AIM: OFF",
                        color: store.state.realAimbotActive ? Theme.neonGreen : Theme.textSecondary,
                        filled: store.state.realAimbotActive
                    )
                }

                Text(store.state.realAimbotActive
                     ? "REAL AIMBOT ON (Drag upward to snap)"
                     : "REAL AIMBOT OFF (Standby)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(store.state.realAimbotActive ? Theme.neonGreen : Theme.textDim)

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("POWER")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .tracking(1.3)
                            .foregroundColor(Theme.textDim)
                        Spacer()
                        Text("\(Int(power))% (\(max(5, Int(power * 1.5))) px drag)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.cyan)
                    }

                    Slider(value: $power, in: 1...100, step: 1) { editing in
                        editingPower = editing
                        if !editing {
                            Task { _ = await store.setRealPower(Int(power)) }
                        }
                    }
                    .tint(Theme.cyan)
                }

                HStack(spacing: 9) {
                    Button {
                        setRealAimbot(true)
                    } label: {
                        Text("REAL AIM ON")
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.neonGreen))
                    .disabled(busyCommand != nil)

                    Button {
                        setRealAimbot(false)
                    } label: {
                        Text("REAL AIM OFF")
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.crimson))
                    .disabled(busyCommand != nil)
                }
            }
        }
    }

    // MARK: - Actions

    private func runScan() {
        guard busyCommand == nil else { return }
        busyCommand = "scan"
        statusLine = "Scanning memory for players..."
        statusColor = Theme.sky
        Task {
            let output = await store.scanPlayers()
            busyCommand = nil
            if let output {
                statusLine = output
                statusColor = Theme.neonGreen
            } else {
                statusLine = "Scan failed"
                statusColor = Theme.crimson
            }
        }
    }

    private func setAimHead(_ on: Bool) {
        guard busyCommand == nil else { return }
        busyCommand = on ? "headon" : "headoff"
        statusLine = on ? "Activating Head Aim..." : "Deactivating Head Aim..."
        statusColor = Theme.sky
        Task {
            let output = await store.aimHead(on: on)
            busyCommand = nil
            statusLine = output ?? (on ? "Aim head on" : "Aim head off")
            statusColor = output == nil ? Theme.crimson : (on ? Theme.neonGreen : Theme.textDim)
        }
    }

    private func setRealAimbot(_ on: Bool) {
        guard busyCommand == nil else { return }
        busyCommand = on ? "realon" : "realoff"
        Task {
            _ = await store.realAimbot(on: on)
            busyCommand = nil
        }
    }
}
