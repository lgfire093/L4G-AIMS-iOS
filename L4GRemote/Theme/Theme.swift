import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

enum Theme {
    static let bg = Color(hex: 0x060A14)
    static let surface = Color(hex: 0x0A1020)
    static let surfaceRaised = Color(hex: 0x0E1729)

    static let cyan = Color(hex: 0x00E5FF)
    static let emerald = Color(hex: 0x10B981)
    static let neonGreen = Color(hex: 0x00FF9D)
    static let crimson = Color(hex: 0xEF4444)
    static let amber = Color(hex: 0xF59E0B)
    static let violet = Color(hex: 0xA855F7)
    static let sky = Color(hex: 0x38BDF8)

    static let textPrimary = Color(hex: 0xF8FAFC)
    static let textSecondary = Color(hex: 0x94A3B8)
    static let textDim = Color(hex: 0x64748B)

    static let glassFill = Color(hex: 0x101E36, alpha: 0.72)
    static let glassStroke = Color(hex: 0x38BDF8, alpha: 0.20)
    static let cyanStroke = Color(hex: 0x00E5FF, alpha: 0.38)
    static let greenStroke = Color(hex: 0x10B981, alpha: 0.38)
    static let redStroke = Color(hex: 0xEF4444, alpha: 0.38)

    static let corner: CGFloat = 16
}

struct ScreenBackground: View {
    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(
                colors: [Color(hex: 0x0B2036, alpha: 0.9), Theme.bg],
                center: .topLeading,
                startRadius: 20,
                endRadius: 520
            )
            RadialGradient(
                colors: [Color(hex: 0x1A0B2A, alpha: 0.55), .clear],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

struct GlassCard<Content: View>: View {
    var accent: Color = Theme.cyan
    let content: Content

    init(accent: Color = Theme.cyan, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.glassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .stroke(accent.opacity(0.28), lineWidth: 1)
            )
    }
}

struct SectionLabel: View {
    let text: String
    var color: Color = Theme.textSecondary

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .tracking(1.6)
            .foregroundColor(color)
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    var filled = false

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(1.0)
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(filled ? color.opacity(0.16) : Color.white.opacity(0.03))
            )
            .overlay(Capsule().stroke(color.opacity(0.45), lineWidth: 1))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.cyan
    var solid = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .tracking(0.8)
            .foregroundColor(solid ? Theme.bg : tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(solid ? tint.opacity(configuration.isPressed ? 0.75 : 1.0)
                                : tint.opacity(configuration.isPressed ? 0.24 : 0.13))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(tint.opacity(solid ? 0 : 0.45), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct IconTabButton: View {
    let icon: String
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.6)
            }
            .foregroundColor(selected ? Theme.cyan : Theme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct ConnectionDot: View {
    let online: Bool

    var body: some View {
        Circle()
            .fill(online ? Theme.emerald : Theme.crimson)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke((online ? Theme.emerald : Theme.crimson).opacity(0.35), lineWidth: 4))
            .shadow(color: (online ? Theme.emerald : Theme.crimson).opacity(0.7), radius: 5)
    }
}

struct SwitchRow: View {
    let title: String
    let subtitle: String?
    let isOn: Bool
    let tint: Color
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.textDim)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(get: { isOn }, set: { onChange($0) }))
                .labelsHidden()
                .tint(tint)
        }
    }
}

extension View {
    func panelBanner(_ banner: PanelStore.Banner?, onDismiss: @escaping () -> Void) -> some View {
        overlay(alignment: .top) {
            if let banner {
                HStack(spacing: 10) {
                    Image(systemName: banner.kind == .failure
                          ? "exclamationmark.triangle.fill"
                          : (banner.kind == .success ? "checkmark.circle.fill" : "info.circle.fill"))
                    Text(banner.message)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(3)
                    Spacer(minLength: 0)
                }
                .foregroundColor(color(for: banner.kind))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.surfaceRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(color(for: banner.kind).opacity(0.45), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture(perform: onDismiss)
            }
        }
        .animation(.easeOut(duration: 0.2), value: banner?.id)
    }

    private func color(for kind: PanelStore.Banner.Kind) -> Color {
        switch kind {
        case .success: return Theme.neonGreen
        case .failure: return Theme.crimson
        case .info: return Theme.cyan
        }
    }
}
