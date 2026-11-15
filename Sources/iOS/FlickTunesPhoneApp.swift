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

                    StatusCard(symbol: "music.note", headline: music.song.map { "\($0.title) · \($0.artist)" } ?? "Apple Music", subheadline: music.message)
                    Button { music.refresh() } label: { Label("Refresh Now Playing", systemImage: "arrow.clockwise") }.buttonStyle(.bordered)

                    Text("YOUR MAC").font(.caption.bold()).foregroundStyle(.white.opacity(0.6))
                    if nearby.discoveredPeers.isEmpty {
                        StatusCard(symbol: "laptopcomputer", headline: "Searching nearby…", subheadline: "Open FlickTunes on your Mac, then approve its pairing request.")
                    } else {
                        ForEach(nearby.discoveredPeers, id: \.self) { peer in
                            Button { nearby.connect(to: peer) } label: {
                                HStack { Image(systemName: "laptopcomputer"); Text(peer.displayName); Spacer(); Image(systemName: "link") }
                                    .padding(16)
                                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                            }.foregroundStyle(.white)
                        }
                    }
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
                }
                .padding(22)
            }
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
            if phase != .active { flick.stop() }
            else { music.refresh() }
        }
    }

    private func sendSong() {
        music.refresh()
        guard let packet = music.song else { toast = music.message; return }
        guard !nearby.connectedPeers.isEmpty else { toast = "Pair with your Mac first."; return }
        if nearby.send(.handoff(packet)) { toast = "Sent \(packet.title) — waiting for Mac…" }
    }
}
