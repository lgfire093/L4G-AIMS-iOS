import SwiftUI

struct ESPView: View {
    @EnvironmentObject private var store: PanelStore

    struct Feature: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let tint: Color
    }

    private let features: [Feature] = [
        .init(id: "line", title: "Snaplines", subtitle: "Line to target", tint: Theme.cyan),
        .init(id: "box", title: "Box", subtitle: "2D outline", tint: Theme.sky),
        .init(id: "filled_box", title: "Filled box", subtitle: "Translucent fill", tint: Theme.sky),
        .init(id: "health", title: "Health", subtitle: "HP bar", tint: Theme.neonGreen),
        .init(id: "glow", title: "Glow", subtitle: "Target halo", tint: Theme.violet),
        .init(id: "counter", title: "Counter", subtitle: "Player count", tint: Theme.amber),
        .init(id: "wukong", title: "Wukong", subtitle: "Wukong marker", tint: Theme.violet),
        .init(id: "skeleton", title: "Skeleton", subtitle: "Bone lines", tint: Theme.emerald)
    ]

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(spacing: 12) {
            statusCard
            togglesCard
        }
    }

    private var statusCard: some View {
        GlassCard(accent: store.state.esp.master ? Theme.greenStroke : Theme.cyanStroke) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(text: "Desktop ESP", color: Theme.cyan)
                    Spacer()
                    StatusPill(
                        text: store.state.esp.master ? "DESKTOP ACTIVE" : "IDLE",
                        color: store.state.esp.master ? Theme.neonGreen : Theme.textSecondary,
                        filled: store.state.esp.master
                    )
                }

                Text(store.state.esp.master ? "Desktop ESP Active" : "Desktop ESP Idle")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(store.state.esp.master ? Theme.neonGreen : Theme.textDim)

                HStack(spacing: 9) {
                    Button {
                        Task { _ = await store.desktopESP(on: true) }
                    } label: {
                        Text("DESKTOP ESP ON")
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.neonGreen))

                    Button {
                        Task { _ = await store.desktopESP(on: false) }
                    } label: {
                        Text("ESP OFF")
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.crimson))
                }

                Button {
                    Task { _ = await store.refreshESP() }
                } label: {
                    Text("REFRESH MATRIX")
                }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.cyan))
            }
        }
    }

    private var togglesCard: some View {
        GlassCard(accent: Theme.violet) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(text: "Overlay features", color: Theme.violet)
                    Spacer()
                    StatusPill(
                        text: "\(enabledCount)/\(features.count)",
                        color: Theme.violet
                    )
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(features) { feature in
                        FeatureToggle(
                            feature: feature,
                            isOn: store.state.espValue(for: feature.id)
                        ) { value in
                            Task { await store.setESP(feature: feature.id, on: value) }
                        }
                    }
                }
            }
        }
    }

    private var enabledCount: Int {
        features.reduce(0) { $0 + (store.state.espValue(for: $1.id) ? 1 : 0) }
    }
}

private struct FeatureToggle: View {
    let feature: ESPView.Feature
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(isOn ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                Text(feature.subtitle)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.textDim)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: Binding(get: { isOn }, set: onChange))
                .labelsHidden()
                .tint(feature.tint)
                .scaleEffect(0.82)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(feature.tint.opacity(isOn ? 0.35 : 0.10), lineWidth: 1)
        )
    }
}
