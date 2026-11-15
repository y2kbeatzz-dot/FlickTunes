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
                GuideStep(number: 1, icon: "laptopcomputer", title: "Start RIFT on Mac", description: "Open the receiver on your Mac. It stays running in the menu bar even if you close its window."),
                GuideStep(number: 2, icon: "wifi", title: "Allow nearby access", description: "Keep the devices near each other with Wi-Fi and Bluetooth enabled. Allow Local Network access when prompted."),
                GuideStep(number: 3, icon: "music.note", title: "Play a song in Apple Music", description: "Start your song in the Music app, then switch to FlickTunes and allow Media & Apple Music access."),
                GuideStep(number: 4, icon: "link", title: "Pair once, then reconnect automatically", description: "Select your Mac the first time and approve it there. RIFT remembers both devices, so you don't need to select or type anything every launch."),
                GuideStep(number: 5, icon: "arrow.up.right", title: "Flick to send music", description: "The Music screen has a live gesture meter and a Test mode. Gently flick the iPhone while FlickTunes is open. Adjust sensitivity or use the send button."),
                GuideStep(number: 6, icon: "square.on.square.dashed", title: "Portal: drag photos, files and links", description: "Choose Portal from the Music screen. Pick a photo or file, or paste a link. Drag its card off the left edge and release. It flies off iPhone; a glowing portal opens on the RIGHT edge of the Mac screen and the file emerges from it after transfer.")
            ]
        case .mac:
            return [
                GuideStep(number: 1, icon: "desktopcomputer", title: "Keep the receiver running", description: "You can close the RIFT window; the menu-bar receiver continues running until you quit the app."),
                GuideStep(number: 2, icon: "wifi", title: "Prepare both devices", description: "Keep Wi-Fi and Bluetooth enabled, and approve Local Network access."),
                GuideStep(number: 3, icon: "checkmark.shield", title: "Approve your iPhone once", description: "Accept the first pairing request from your iPhone. Approved phones are remembered; there's no need to repeat setup every time."),
                GuideStep(number: 4, icon: "music.note", title: "Make the song available", description: "The song must exist in your Mac Music library. Streaming-only tracks outside the library may not resume."),
                GuideStep(number: 5, icon: "slider.horizontal.3", title: "Enable Music automation", description: "Allow RIFT to control Music when prompted. Find the permission under System Settings → Privacy & Security → Automation."),
                GuideStep(number: 6, icon: "square.on.square.dashed", title: "Catch Portal drops", description: "Open Portal on iPhone and swipe a selected item off the left edge. Mac saves photos and files to Downloads/RIFT, opens an animated portal on the RIGHT screen edge, and makes the item pop out. Use Test Portal Effect in the Mac app to try the effect without sending. Links remain clickable in FlickTunes.")
            ]
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FlickStyle.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("One app. Your devices connected.")
                            .font(.system(size: 29, weight: .bold, design: .rounded))
                        Text("Send music, photos, files and links between iPhone and Mac.")
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
                            Text("If you see Connecting for too long, keep both apps open and tap Rescan on iPhone. RIFT remembers the last approved Mac. Use Forget Pairing on BOTH devices only when you need a fresh start.")
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
            .navigationTitle("How RIFT Works")
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
                        Text("RIFT")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.9.0")")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.65))
                        Text("Your music and files, one gesture away.")
                            .foregroundStyle(.white.opacity(0.8))
                        VStack(alignment: .leading, spacing: 13) {
                            Text("CREATED BY")
                                .font(.caption.bold()).foregroundStyle(FlickStyle.pink)
                            Text("Ksyusha").font(.title2.bold())
                            Text("life999 · Creator profile")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                            Text("Created by Ksyusha (life999). Apple Music handoff and Portal transfers for photos, files, links, and clipboard text.")
                                .foregroundStyle(.white.opacity(0.7))
                            Link(destination: URL(string: "https://guns.lol/life999")!) {
                                Label("Creator page · guns.lol/life999", systemImage: "link")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(FlickStyle.violet)
                            Link(destination: URL(string: "https://github.com/y2kbeatzz-dot/FlickTunes")!) {
                                Label("View RIFT on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(19)
                        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Flick gesture", systemImage: "hand.draw").font(.headline)
                            Text("Play Apple Music on iPhone, open RIFT, and flick gently. The sensor meter and Test mode show whether a gesture registers without sending.")
                            Label("Your choice stays saved", systemImage: "checkmark.shield").font(.headline)
                            Text("Pairing, motion sensitivity and your selected gesture preference are saved locally. Motion sensing only runs while FlickTunes is foregrounded. Portal's left-edge card swipe is a separate gesture.")
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
            .navigationTitle("About RIFT")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}
