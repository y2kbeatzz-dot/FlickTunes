import SwiftUI

enum FlickPlatform {
    case iphone
    case mac
}

private struct GuideStep: Identifiable {
    let number: Int
    let icon: String
    let title: String
    let description: String
    var id: Int { number }
}

struct FlickTunesHelpView: View {
    let platform: FlickPlatform
    @Environment(\.dismiss) private var dismiss

    private var steps: [GuideStep] {
        switch platform {
        case .iphone:
            return [
                GuideStep(number: 1, icon: "laptopcomputer", title: "Start FlickTunes on Mac", description: "Open the receiver on your Mac. It stays running in the menu bar even if you close its window."),
                GuideStep(number: 2, icon: "wifi", title: "Allow nearby access", description: "Keep the devices near each other with Wi-Fi and Bluetooth enabled. Allow Local Network access when prompted."),
                GuideStep(number: 3, icon: "music.note", title: "Play a song in Apple Music", description: "Start your song in the Music app, then switch to FlickTunes and allow Media & Apple Music access."),
                GuideStep(number: 4, icon: "link", title: "Pair once, then reconnect automatically", description: "Select your Mac the first time and approve it there. FlickTunes remembers both devices, so you don't need to select or type anything every launch."),
                GuideStep(number: 5, icon: "arrow.up.right", title: "Gently flick your iPhone", description: "The motion gesture is enabled by default and your preference is saved. With FlickTunes open on iPhone, make a short gentle flick to send the song. The button is an optional backup.")
            ]
        case .mac:
            return [
                GuideStep(number: 1, icon: "desktopcomputer", title: "Keep the receiver running", description: "You can close the FlickTunes window; the menu-bar receiver continues running until you quit the app."),
                GuideStep(number: 2, icon: "wifi", title: "Prepare both devices", description: "Keep Wi-Fi and Bluetooth enabled, and approve Local Network access."),
                GuideStep(number: 3, icon: "checkmark.shield", title: "Approve your iPhone once", description: "Accept the first pairing request from your iPhone. Approved phones are remembered; there's no need to repeat setup every time."),
                GuideStep(number: 4, icon: "music.note", title: "Make the song available", description: "The song must exist in your Mac Music library. Streaming-only tracks outside the library may not resume."),
                GuideStep(number: 5, icon: "slider.horizontal.3", title: "Enable Music automation", description: "Allow FlickTunes to control Music when prompted. Find the permission under System Settings → Privacy & Security → Automation.")
            ]
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FlickStyle.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("One song. Two devices.")
                            .font(.system(size: 29, weight: .bold, design: .rounded))
                        Text("Use these steps to transfer Apple Music playback.")
                            .foregroundStyle(.white.opacity(0.7))
                        ForEach(steps) { step in
                            HStack(alignment: .top, spacing: 15) {
                                Image(systemName: step.icon)
                                    .font(.title2).foregroundStyle(FlickStyle.pink)
                                    .frame(width: 35)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("\(step.number). \(step.title)").font(.headline)
                                    Text(step.description)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.72))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(16)
                            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Connection troubleshooting", systemImage: "wrench.and.screwdriver")
                                .font(.headline)
                            Text("If you see Connecting for too long, keep both apps open and tap Rescan on iPhone. FlickTunes remembers the last approved Mac. Use Forget Pairing on BOTH devices only when you need a fresh start.")
                            Text("iOS may disconnect nearby sessions while FlickTunes is in the background. Reopening it restarts discovery and the saved flick gesture setting. A flick can wait up to 20 seconds for an already-paired Mac to reconnect; it expires rather than transferring later without your knowledge.")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(18)
                        .background(FlickStyle.violet.opacity(0.21), in: RoundedRectangle(cornerRadius: 18))
                    }
                    .padding(22)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("How FlickTunes Works")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

struct FlickTunesAboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                FlickStyle.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 62, weight: .medium))
                            .foregroundStyle(FlickStyle.pink)
                            .padding(26)
                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 28))
                        Text("FlickTunes")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Preview") • Preview")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.65))
                        Text("Flick your music to your Mac.")
                            .foregroundStyle(.white.opacity(0.8))
                        VStack(alignment: .leading, spacing: 13) {
                            Text("CREATED BY")
                                .font(.caption.bold()).foregroundStyle(FlickStyle.pink)
                            Text("life999").font(.title2.bold())
                            Text("Designed and created by life999. A nearby Apple Music handoff experience for iPhone and Mac.")
                                .foregroundStyle(.white.opacity(0.7))
                            Link(destination: URL(string: "https://guns.lol/life999")!) {
                                Label("Creator page · guns.lol/life999", systemImage: "link")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(FlickStyle.violet)
                            Link(destination: URL(string: "https://github.com/y2kbeatzz-dot/FlickTunes")!) {
                                Label("View FlickTunes on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(19)
                        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Flick gesture", systemImage: "hand.draw").font(.headline)
                            Text("Once paired, play Apple Music on your iPhone, open FlickTunes, and flick gently toward your Mac. No repeated pairing or tapping needed.")
                            Label("Your choice stays saved", systemImage: "checkmark.shield").font(.headline)
                            Text("Flick motion preferences and your approved device are remembered on your own devices. Motion sensing only runs while FlickTunes is open and active.")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                        Text("Independent project, not affiliated with Apple. Transfers stay between approved nearby devices.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.57))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: 500)
                    .padding(25)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("About FlickTunes")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}
