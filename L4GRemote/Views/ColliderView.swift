import SwiftUI

struct ColliderView: View {
    @EnvironmentObject private var store: PanelStore

    @State private var status = "Ready"
    @State private var statusColor = Theme.textSecondary
    @State private var busy = false

    var body: some View {
        VStack(spacing: 12) {
            GlassCard(accent: Theme.cyan) {
                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        SectionLabel(text: "Collider scan", color: Theme.cyan)
                        Spacer()
                        StatusPill(
                            text: "\(store.state.colliderCount) targets",
                            color: store.state.colliderCount > 0 ? Theme.neonGreen : Theme.textSecondary
                        )
                    }

                    Text(status)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(statusColor)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        scan()
                    } label: {
                        HStack(spacing: 7) {
                            if busy {
                                ProgressView().progressViewStyle(.circular).tint(Theme.cyan).scaleEffect(0.7)
                            }
                            Text("SCAN COLLIDER PATTERN")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.cyan))
                    .disabled(busy)
                }
            }

            GlassCard(accent: Theme.violet) {
                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        SectionLabel(text: "Visible aim", color: Theme.violet)
                        Spacer()
                        StatusPill(text: "0x100 → -0x394", color: Theme.violet)
                    }

                    Text("Routes the visible-collider aim path to the head offset.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.textDim)

                    HStack(spacing: 9) {
                        Button {
                            setVisibleAim(true)
                        } label: {
                            Text("VISIBLE AIM ON")
                        }
                        .buttonStyle(PrimaryButtonStyle(tint: Theme.neonGreen))
                        .disabled(busy)

                        Button {
                            setVisibleAim(false)
                        } label: {
                            Text("VISIBLE AIM OFF")
                        }
                        .buttonStyle(PrimaryButtonStyle(tint: Theme.crimson))
                        .disabled(busy)
                    }
                }
            }

            GlassCard(accent: Theme.cyanStroke) {
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "Panel counters", color: Theme.textSecondary)
                    HStack {
                        counter("ENTITIES", value: store.state.entityCount)
                        Divider().overlay(Color.white.opacity(0.08)).frame(height: 26)
                        counter("COLLIDERS", value: store.state.colliderCount)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func counter(_ label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundColor(Theme.textDim)
            Text("\(value)")
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(Theme.cyan)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scan() {
        guard !busy else { return }
        busy = true
        status = "Scanning memory for collider pattern..."
        statusColor = Theme.sky
        Task {
            let output = await store.visibleScan()
            busy = false
            status = output ?? "Scan failed"
            statusColor = output == nil ? Theme.crimson : Theme.neonGreen
        }
    }

    private func setVisibleAim(_ on: Bool) {
        guard !busy else { return }
        busy = true
        status = on ? "Activating Visible Aim..." : "Deactivating Visible Aim..."
        statusColor = Theme.sky
        Task {
            let output = await store.visibleAim(on: on)
            busy = false
            if let output {
                status = on ? "Visible Aim Active (Routing +0x100 → -0x394)" : "Visible Aim Deactivated"
                statusColor = on ? Theme.neonGreen : Theme.textDim
            } else {
                status = "Visible aim command failed"
                statusColor = Theme.crimson
            }
            _ = output
        }
    }
}
