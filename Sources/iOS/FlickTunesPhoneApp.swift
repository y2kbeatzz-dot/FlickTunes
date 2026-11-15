import MultipeerConnectivity
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
    // Store the user's preferences; sensor collection only runs in the foreground.
    @AppStorage("flicktunes.motionFlickEnabled.v1") private var motionFlickEnabled = true
    @AppStorage("flicktunes.gestureSensitivity.v1") private var gestureSensitivity = 0.4
    @AppStorage("flicktunes.pauseAfterHandoff.v1") private var pauseAfterHandoff = true
    @State private var toast: String?
    @State private var queuedFlick: TransferPacket?
    @State private var queuedPeer: MCPeerID?
    @State private var showingHelp = false
    @State private var showingAbout = false
    @State private var showingPortal = false
    @State private var confirmingForget = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            FlickStyle.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "waveform.path").font(.largeTitle).foregroundStyle(FlickStyle.pink)
                        Text("RIFT").font(.system(size: 38, weight: .bold, design: .rounded))
                        Text("Flick music, photos, files and links to your Mac.").foregroundStyle(.white.opacity(0.72))
                    }.padding(.top, 24)
                    HStack(spacing: 12) {
                        Button { showingHelp = true } label: {
                            Label("Get started", systemImage: "list.number")
                        }
                        Button { showingAbout = true } label: {
                            Label("About", systemImage: "info.circle")
                        }
                    }
                    .buttonStyle(.bordered)

                    Button { showingPortal = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "square.on.square.dashed")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("RIFT Portal • Photos, Files & Links")
                                    .font(.headline)
                                Text("Pick an item. Swipe left. Watch it arrive.")
                                    .font(.subheadline).opacity(0.85)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                        .background(
                            LinearGradient(colors: [FlickStyle.violet.opacity(0.78), FlickStyle.pink.opacity(0.53)],
                                           startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 20)
                        )
                    }
                    .buttonStyle(.plain)

                    StatusCard(
                        symbol: "sparkles",
                        headline: "Quick start",
                        subheadline: "1. Keep RIFT running on your Mac. 2. Pair once. 3. Play Apple Music on iPhone. 4. Gently flick your phone — no button needed."
                    )

                    StatusCard(symbol: "music.note", headline: music.song.map { "\($0.title) · \($0.artist)" } ?? "Apple Music", subheadline: music.message)
                    Button { music.refresh() } label: { Label("Refresh Now Playing", systemImage: "arrow.clockwise") }.buttonStyle(.bordered)

                    Text("YOUR MAC").font(.caption.bold()).foregroundStyle(.white.opacity(0.6))
                    if !nearby.connectedPeers.isEmpty {
                        StatusCard(
                            symbol: "checkmark.circle.fill",
                            headline: "Connected to \(nearby.connectedPeers.map(\.displayName).joined(separator: ", "))",
                            subheadline: motionFlickEnabled ? "Paired and ready. Gently flick your iPhone while this screen is open." : "Paired and ready. Enable motion flick or use the button below."
                        )
                    } else {
                        StatusCard(
                            symbol: nearby.connectingPeer == nil ? "laptopcomputer" : "hourglass.circle",
                            headline: nearby.connectingPeer.map { "Connecting to \($0.displayName)…" } ??
                                (nearby.preferredPeerName.map { "Waiting for saved Mac: \($0)" } ?? "Find your Mac"),
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
                    if nearby.preferredPeerName != nil {
                        Text("Your saved Mac is remembered. If iOS pauses nearby connections, RIFT will reconnect when you return. You don't need to pair again unless you select Forget Pairing.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.56))
                    }

                    Button(action: sendSong) {
                        Label("Flick to Mac", systemImage: "arrow.up.right")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity).padding(18)
                    }
                    .buttonStyle(.plain)
                    .background(LinearGradient(colors: [FlickStyle.violet, FlickStyle.pink], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 20))
                    .disabled(nearby.connectedPeers.isEmpty)
                    .opacity(nearby.connectedPeers.isEmpty ? 0.5 : 1)

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $motionFlickEnabled) {
                            Label("Flick iPhone to hand off Apple Music", systemImage: "hand.draw")
                                .font(.headline)
                        }
                        .tint(FlickStyle.pink)
                        Text("A gentle wrist flick in any direction triggers a song handoff when this app is open. Your preference is saved.")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.74))

                        HStack {
                            Text("Sensitivity")
                            Spacer()
                            Text(gestureSensitivity < 0.3 ? "Easy" :
                                 gestureSensitivity < 0.7 ? "Normal" : "Firm")
                                .foregroundStyle(FlickStyle.pink)
                        }
                        .font(.subheadline.weight(.medium))
                        Slider(value: $gestureSensitivity, in: 0...1, step: 0.05)
                            .tint(FlickStyle.pink)
                            .disabled(!motionFlickEnabled)

                        Toggle("Test motion without sending a song", isOn: $flick.testMode)
                            .font(.subheadline)
                            .tint(FlickStyle.violet)
                            .disabled(!motionFlickEnabled)

                        HStack {
                            Text(flick.receivingMotion ? "Sensor active" : "Sensor waiting")
                            Spacer()
                            Text("Flicks: \(flick.detectionCount)")
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))

                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.15))
                                Capsule().fill(
                                    LinearGradient(colors: [FlickStyle.violet, FlickStyle.pink],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .frame(width: max(0, geometry.size.width * flick.signalLevel))
                            }
                        }
                        .frame(height: 7)
                        Text(motionFlickEnabled ? flick.message : "Flick gesture off — use the send button instead.")
                            .font(.footnote).foregroundStyle(FlickStyle.pink.opacity(0.88))
                        if !flick.isSupported {
                            Text("Motion sensing isn't available on this device. Test on a physical iPhone.")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                    }
                    .padding(17)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
                    Toggle("Pause iPhone after Mac confirms playback", isOn: $pauseAfterHandoff)
                        .tint(FlickStyle.pink)
                    Text("RIFT reads the Music app's current song and sends metadata, not audio. Keep both devices nearby and on Wi-Fi with Bluetooth enabled. Supported songs must be available in the Mac's Music library.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.55))
                    if let toast { StatusCard(symbol: "info.circle", headline: "Handoff", subheadline: toast) }
                    HStack {
                        Text("Created by Ksyusha · life999")
                        Spacer()
                        Link("Creator page", destination: URL(string: "https://guns.lol/life999")!)
                            .buttonStyle(.borderless)
                        Button("About") { showingAbout = true }
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.72))
                }
                .padding(22)
            }
        }
        .fullScreenCover(isPresented: $showingPortal) {
            PortalSendView(nearby: nearby)
                .preferredColorScheme(.dark)
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
            nearby.onConnected = { peer in
                guard let packet = queuedFlick else { return }
                queuedFlick = nil
                let intendedMac = queuedPeer
                defer { queuedPeer = nil }
                guard intendedMac == peer,
                      Date().timeIntervalSince(packet.sentAt) < 20 else {
                    toast = "Saved flick expired or a different Mac connected. Flick again to send."
                    return
                }
                if nearby.send(.handoff(packet), to: peer) {
                    toast = "Reconnected — sending \(packet.title) to your Mac…"
                } else {
                    toast = "Could not send the saved flick. Try again."
                }
            }
            nearby.onAcknowledgement = { succeeded, details in
                toast = details
                if succeeded && pauseAfterHandoff {
                    music.pauseOnSuccess = true
                    music.pauseAfterSuccessfulTransfer()
                }
            }
            flick.sensitivity = gestureSensitivity
            await music.requestAccess()
            if motionFlickEnabled && scenePhase == .active { flick.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                nearby.resumeAfterForeground()
                music.refresh()
                if motionFlickEnabled { flick.start() }
            case .background:
                flick.stop()
                queuedFlick = nil
                queuedPeer = nil
                nearby.suspendForBackground()
            default:
                flick.stop()
            }
        }
        .onChange(of: motionFlickEnabled) { _, isOn in
            if isOn && scenePhase == .active { flick.start() }
            else { flick.stop() }
        }
        .onChange(of: gestureSensitivity) { _, newValue in
            flick.sensitivity = newValue
        }
        .onChange(of: showingPortal) { _, isPortalOpen in
            // Dragging an item through Portal must not accidentally trigger
            // the separate motion gesture for Apple Music handoff.
            if isPortalOpen { flick.stop() }
            else if motionFlickEnabled && scenePhase == .active { flick.start() }
        }
    }

    private func sendSong() {
        music.refresh()
        guard let packet = music.song else { toast = music.message; return }
        guard !nearby.connectedPeers.isEmpty else {
            if let rememberedMac = nearby.savedMacPeer {
                queuedFlick = packet
                queuedPeer = rememberedMac
                nearby.resumeAfterForeground()
                toast = "Flick saved for \(rememberedMac.displayName). Waiting up to 20 seconds for your Mac to reconnect…"
            } else {
                toast = "Select your Mac once and approve pairing. After that, it will reconnect automatically."
            }
            return
        }
        if nearby.send(.handoff(packet)) { toast = "Sent \(packet.title) — waiting for Mac…" }
    }
}
