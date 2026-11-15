import SwiftUI

@main
struct FlickTunesPhoneApp: App {
    var body: some Scene {
        WindowGroup { PhoneHomeView().preferredColorScheme(.dark) }
    }
}

struct PhoneHomeView: View {
    @StateObject private var nearby = NearbyBridge()
    @StateObject private var music = PhoneMusic()
    @StateObject private var flick = FlickGesture()
    @State private var toast: String?
    @State private var showingHelp = false
    @State private var showingAbout = false
    @State private var confirmingForget = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            FlickStyle.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "waveform.path").font(.largeTitle).foregroundStyle(FlickStyle.pink)
                        Text("FlickTunes").font(.system(size: 38, weight: .bold, design: .rounded))
                        Text("Flick your music to your Mac.").foregroundStyle(.white.opacity(0.72))
                    }.padding(.top, 24)
                    HStack(spacing: 12) {
                        Button { showingHelp = true } label: {
                            Label("Setup guide", systemImage: "list.number")
                        }
                        Button { showingAbout = true } label: {
                            Label("About", systemImage: "info.circle")
                        }
                    }
                    .buttonStyle(.bordered)
                    StatusCard(
                        symbol: "sparkles",
                        headline: "Quick start",
                        subheadline: "1. Start FlickTunes on Mac. 2. Play a song in Music. 3. Pair once. 4. Tap Flick to Mac."
                    )

                    StatusCard(symbol: "music.note", headline: music.song.map { "\($0.title) · \($0.artist)" } ?? "Apple Music", subheadline: music.message)
                    Button { music.refresh() } label: { Label("Refresh Now Playing", systemImage: "arrow.clockwise") }.buttonStyle(.bordered)

                    Text("YOUR MAC").font(.caption.bold()).foregroundStyle(.white.opacity(0.6))
                    if !nearby.connectedPeers.isEmpty {
                        StatusCard(
                            symbol: "checkmark.circle.fill",
                            headline: "Connected to \(nearby.connectedPeers.map(\.displayName).joined(separator: ", "))",
                            subheadline: "Ready to send your Apple Music song."
                        )
                    } else {
                        StatusCard(
                            symbol: nearby.connectingPeer == nil ? "laptopcomputer" : "hourglass.circle",
                            headline: nearby.connectingPeer.map { "Connecting to \($0.displayName)…" } ?? "Searching for your Mac",
                            subheadline: nearby.status
                        )
                        ForEach(nearby.discoveredPeers, id: \.self) { peer in
                            Button { nearby.connect(to: peer) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "laptopcomputer")
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(peer.displayName)
                                        if nearby.preferredPeerName == peer.displayName {
                                            Text("Previously paired")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.6))
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: nearby.connectingPeer == peer ? "hourglass" : "link")
                                }
                                .padding(16)
                                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                            .disabled(!nearby.canConnect(to: peer))
                            .opacity(nearby.canConnect(to: peer) ? 1 : 0.6)
                        }
                    }
                    HStack {
                        Button { nearby.rescan() } label: {
                            Label("Rescan", systemImage: "arrow.clockwise")
                        }
                        .disabled(!nearby.connectedPeers.isEmpty || nearby.connectingPeer != nil)
                        if nearby.preferredPeerName != nil || !nearby.connectedPeers.isEmpty {
                            Button(role: .destructive) { confirmingForget = true } label: {
                                Label("Forget Pairing", systemImage: "xmark.circle")
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    Text(nearby.status).font(.footnote).foregroundStyle(.white.opacity(0.65))

                    Button(action: sendSong) {
                        Label("Flick to Mac", systemImage: "arrow.up.right")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity).padding(18)
                    }
                    .buttonStyle(.plain)
                    .background(LinearGradient(colors: [FlickStyle.violet, FlickStyle.pink], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 20))
                    .disabled(nearby.connectedPeers.isEmpty)
                    .opacity(nearby.connectedPeers.isEmpty ? 0.5 : 1)

                    Toggle("Enable motion flick while app is open", isOn: Binding(get: { flick.enabled }, set: { $0 ? flick.start() : flick.stop() }))
                        .tint(FlickStyle.pink)
                    Toggle("Pause iPhone after Mac confirms playback", isOn: $music.pauseOnSuccess)
                        .tint(FlickStyle.pink)
                    Text("FlickTunes reads the Music app's current song and sends metadata, not audio. Keep both devices nearby and on Wi-Fi with Bluetooth enabled. Supported songs must be available in the Mac's Music library.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.55))
                    if let toast { StatusCard(symbol: "info.circle", headline: "Handoff", subheadline: toast) }
                    HStack {
                        Text("Created by life999")
                        Spacer()
                        Button("About & creator") { showingAbout = true }
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
                }
                .padding(22)
            }
        }
        .sheet(isPresented: $showingHelp) { FlickTunesHelpView(platform: .iphone) }
        .sheet(isPresented: $showingAbout) { FlickTunesAboutView() }
        .confirmationDialog("Forget this Mac?", isPresented: $confirmingForget, titleVisibility: .visible) {
            Button("Forget and Disconnect", role: .destructive) { nearby.forgetPairedDevice() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You will need to pair with your Mac again.")
        }
        .task {
            nearby.beginBrowsing()
            flick.onFlick = sendSong
            nearby.onAcknowledgement = { succeeded, details in
                toast = details
                if succeeded { music.pauseAfterSuccessfulTransfer() }
            }
            await music.requestAccess()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                nearby.resumeAfterForeground()
                music.refresh()
            case .background:
                flick.stop()
                nearby.suspendForBackground()
            default:
                flick.stop()
            }
        }
    }

    private func sendSong() {
        music.refresh()
        guard let packet = music.song else { toast = music.message; return }
        guard !nearby.connectedPeers.isEmpty else { toast = "Pair with your Mac first."; return }
        if nearby.send(.handoff(packet)) { toast = "Sent \(packet.title) — waiting for Mac…" }
    }
}
