import SwiftUI

@main
struct FlickTunesMacApp: App {
    var body: some Scene {
        WindowGroup { MacHomeView().preferredColorScheme(.dark) }
            .defaultSize(width: 650, height: 540)
    }
}

struct MacHomeView: View {
    @StateObject private var nearby = NearbyBridge()
    @State private var result = "Waiting for a song from your iPhone."
    @State private var working = false

    var body: some View {
        ZStack {
            FlickStyle.background.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 14) {
                    Image(systemName: "waveform.path").font(.system(size: 46, weight: .medium)).foregroundStyle(FlickStyle.pink)
                    VStack(alignment: .leading) {
                        Text("FlickTunes").font(.system(size: 38, weight: .bold, design: .rounded))
                        Text("Your music, one flick away.").foregroundStyle(.white.opacity(0.7))
                    }
                }
                StatusCard(symbol: "antenna.radiowaves.left.and.right", headline: "Mac receiver is running", subheadline: nearby.status)
                StatusCard(symbol: working ? "hourglass" : "music.note", headline: working ? "Opening Apple Music…" : "Playback", subheadline: result)
                if let packet = nearby.lastReceived {
                    HStack(spacing: 12) {
                        Image(systemName: "waveform").font(.largeTitle).foregroundStyle(FlickStyle.violet)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(packet.title).font(.headline)
                            Text(packet.artist).foregroundStyle(.white.opacity(0.7))
                            Text("Received at \(Int(packet.position)) seconds").font(.caption).foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                Spacer()
                Text("Keep this app open on your Mac. On your iPhone, pair with this Mac and tap Flick to Mac or enable the motion gesture. For Apple Music control, allow FlickTunes in System Settings → Privacy & Security → Automation.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.6))
            }
            .padding(30)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            nearby.onHandoff = { packet, peer in
                working = true
                result = "Locating \(packet.title)…"
                DispatchQueue.global(qos: .userInitiated).async {
                    let playback = MacMusic.resume(packet)
                    DispatchQueue.main.async {
                        result = playback.message
                        working = false
                        _ = nearby.send(.acknowledgement(succeeded: playback.succeeded, details: playback.message), to: peer)
                    }
                }
            }
            nearby.beginAdvertising()
        }
        .alert("Pair with iPhone?", isPresented: Binding(get: { nearby.invitationFrom != nil }, set: { if !$0 { nearby.acceptInvitation(false) } })) {
            Button("Allow") { nearby.acceptInvitation(true) }
            Button("Decline", role: .cancel) { nearby.acceptInvitation(false) }
        } message: {
            Text("Allow \(nearby.invitationFrom ?? "this device") to send Apple Music handoffs to this Mac?")
        }
    }
}
