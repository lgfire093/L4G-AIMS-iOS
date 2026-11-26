import SwiftUI

struct ExternalView: View {
    @EnvironmentObject private var store: PanelStore

    @State private var statusLine = "Stream Off"
    @State private var statusColor = Theme.textSecondary
    @State private var busy = false
    @State private var showFullscreen = false

    private let features: [(id: String, title: String, tint: Color)] = [
        ("line", "Snaplines", Theme.cyan),
        ("box", "Box", Theme.sky),
        ("filled_box", "Filled box", Theme.sky),
        ("health", "Health", Theme.neonGreen),
        ("glow", "Glow", Theme.violet),
        ("counter", "Counter", Theme.amber),
        ("wukong", "Wukong", Theme.violet),
        ("skeleton", "Skeleton", Theme.emerald)
    ]

    private let columns = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]

    private var streamURL: URL? {
        var raw = store.serverIP.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return nil }
        if !raw.lowercased().hasPrefix("http://") && !raw.lowercased().hasPrefix("https://") {
            raw = "http://" + raw
        }
        guard var components = URLComponents(string: raw) else { return nil }
        if components.port == nil { components.port = AppConfig.panelPort }
        components.path = AppConfig.pathStream
        return components.url
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                streamCard
                controlsCard
                togglesCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .fullScreenCover(isPresented: $showFullscreen) {
            FullscreenStreamView(url: streamURL, onClose: { showFullscreen = false })
        }
    }

    private var streamCard: some View {
        GlassCard(accent: store.state.externalESP ? Theme.greenStroke : Theme.cyanStroke) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(text: "External stream", color: Theme.cyan)
                    Spacer()
                    StatusPill(
                        text: store.state.externalESP ? "STREAM ACTIVE" : "OFFLINE",
                        color: store.state.externalESP ? Theme.neonGreen : Theme.crimson,
                        filled: store.state.externalESP
                    )
                }

                Group {
                    if store.state.externalESP, let url = streamURL {
                        StreamCanvas(url: url, showsBadge: true)
                            .frame(height: 196)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        placeholder
                    }
                }

                HStack {
                    Text(statusLine)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(statusColor)
                    Spacer()
                    Text("MJPEG :5000")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textDim)
                }
            }
        }
        .onChange(of: store.state.externalESP) { active in
            if active {
                statusLine = "Live Stream Active (External ESP)"
                statusColor = Theme.neonGreen
            } else if !busy {
                statusLine = "Stream Stopped"
                statusColor = Theme.textDim
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.45))
            VStack(spacing: 7) {
                Image(systemName: "play.rectangle.on.rectangle")
                    .font(.system(size: 25, weight: .light))
                    .foregroundColor(Theme.textDim)
                Text("STREAM STANDBY")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundColor(Theme.textDim)
                Text("Start external ESP to view the desktop overlay")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(Theme.textDim.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(12)
        }
        .frame(height: 196)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var controlsCard: some View {
        GlassCard(accent: Theme.cyan) {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "Stream controls", color: Theme.cyan)
                HStack(spacing: 9) {
                    Button {
                        startStream()
                    } label: {
                        HStack(spacing: 6) {
                            if busy && !store.state.externalESP {
                                ProgressView().progressViewStyle(.circular).tint(Theme.neonGreen).scaleEffect(0.7)
                            }
                            Text("START STREAM")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.neonGreen))
                    .disabled(busy)

                    Button {
                        stopStream()
                    } label: {
                        Text("STOP")
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: Theme.crimson))
                    .disabled(busy)
                }

                Button {
                    showFullscreen = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                        Text("FULLSCREEN")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(tint: Theme.violet))
                .disabled(streamURL == nil)
            }
        }
    }

    private var togglesCard: some View {
        GlassCard(accent: Theme.violet) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    SectionLabel(text: "Stream overlay", color: Theme.violet)
                    Spacer()
                    StatusPill(text: "LIVE", color: Theme.neonGreen)
                }

                LazyVGrid(columns: columns, spacing: 9) {
                    ForEach(features, id: \.id) { feature in
                        HStack(spacing: 6) {
                            Text(feature.title)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(store.state.espValue(for: feature.id) ? Theme.textPrimary : Theme.textSecondary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Toggle("", isOn: Binding(
                                get: { store.state.espValue(for: feature.id) },
                                set: { value in
                                    Task { await store.setESP(feature: feature.id, on: value) }
                                }
                            ))
                            .labelsHidden()
                            .tint(feature.tint)
                            .scaleEffect(0.78)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(feature.tint.opacity(0.14), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private func startStream() {
        guard !busy else { return }
        busy = true
        statusLine = "Starting External ESP Stream..."
        statusColor = Theme.sky
        Task {
            let output = await store.externalESP(on: true)
            busy = false
            if output != nil {
                statusLine = "Live Stream Active (External ESP)"
                statusColor = Theme.neonGreen
            }
        }
    }

    private func stopStream() {
        guard !busy else { return }
        busy = true
        statusLine = "Stopping Stream..."
        statusColor = Theme.textSecondary
        Task {
            _ = await store.externalESP(on: false)
            busy = false
            statusLine = "Stream Stopped"
            statusColor = Theme.textDim
        }
    }
}

// MARK: - MJPEG canvas

struct StreamCanvas: View {
    let url: URL
    var showsBadge = false

    @StateObject private var stream = MJPEGStream()

    var body: some View {
        ZStack {
            Color.black
            if let image = stream.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Theme.cyan)
                    Text(stream.lastError ?? "Connecting to stream...")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(stream.lastError == nil ? Theme.textDim : Theme.crimson)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                }
            }
        }
        .onAppear { stream.start(url: url) }
        .onDisappear { stream.stop() }
        .overlay(alignment: .topLeading) {
            if showsBadge {
                HStack(spacing: 4) {
                    Circle()
                        .fill(stream.isRunning ? Theme.neonGreen : Theme.crimson)
                        .frame(width: 5, height: 5)
                    Text(stream.isRunning ? "LIVE" : "WAIT")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .foregroundColor(stream.isRunning ? Theme.neonGreen : Theme.crimson)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.6)))
                .padding(8)
            }
        }
    }
}

struct FullscreenStreamView: View {
    let url: URL?
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let url {
                StreamCanvas(url: url)
                    .ignoresSafeArea()
            } else {
                Text("No stream address")
                    .foregroundColor(Theme.textDim)
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}
