import AppKit
import Combine
import MultipeerConnectivity
import SwiftUI
import UniformTypeIdentifiers

@main
struct FlickTunesMacApp: App {
    // App-owned receiver continues running when the main window closes.
    @StateObject private var receiver = MacReceiverModel()
    @StateObject private var loginSettings = RIFTLoginSettings()

    var body: some Scene {
        WindowGroup(id: "main") {
            MacHomeView(receiver: receiver, loginSettings: loginSettings).preferredColorScheme(.dark)
        }
        .defaultSize(width: 710, height: 690)

        MenuBarExtra("RIFT", systemImage: "waveform.path") {
            MacMenuView(receiver: receiver, loginSettings: loginSettings)
        }
    }
}

final class MacReceiverModel: ObservableObject {
    let nearby = NearbyBridge()
    @Published private(set) var result = "Waiting for a song from your iPhone."
    @Published private(set) var working = false
    @Published private(set) var portalStatus = "No Portal items received yet."
    @Published private(set) var lastPortalFile: PortalReceivedFile?
    @Published private(set) var lastPortalLink: URL?
    @Published private(set) var lastPortalText: String?
    private let portalPresenter = PortalArrivalPresenter()
    private var updates: AnyCancellable?

    init() {
        updates = nearby.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.objectWillChange.send() }
        }
        nearby.onHandoff = { [weak self] packet, peer in
            self?.receive(packet, from: peer)
        }
        nearby.onPortalFile = { [weak self] file in
            guard let self else { return }
            self.lastPortalFile = file
            self.portalStatus = "Saved \(file.name) in Downloads/RIFT."
            let fileType = UTType(filenameExtension: file.url.pathExtension)
            let kind: ArrivalKind = fileType?.conforms(to: .image) == true ? .photo
                : (fileType?.conforms(to: .movie) == true ? .video : .file)
            self.portalPresenter.present(name: file.name, kind: kind, transition: file.transition, previewURL: kind == .photo ? file.url : nil)
        }
        nearby.onPortalLink = { [weak self] url, transition in
            guard let self else { return }
            self.lastPortalLink = url
            self.portalStatus = "A link arrived. Click Open Link to visit it."
            self.portalPresenter.present(name: url.absoluteString, kind: .link, transition: transition)
        }
        nearby.onPortalText = { [weak self] text, transition in
            guard let self else { return }
            self.lastPortalText = text
            // Only explicit clipboard sends from the iPhone are handled here.
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            self.portalStatus = "Clipboard text copied to this Mac."
            self.portalPresenter.present(name: "Ready to paste", kind: .clipboard, transition: transition)
        }
        nearby.onPortalError = { [weak self] details in
            self?.portalStatus = details
        }
        // Start discovery at app launch, regardless of the main window.
        nearby.beginAdvertising()
    }

    func start() { nearby.beginAdvertising() }

    /// Test the actual arrival effect without transferring a file.
    /// Useful for adjusting expectations before pairing with an iPhone.
    func previewPortal() {
        portalPresenter.present(
            name: "Your next photo will emerge here",
            kind: .photo,
            transition: .glide
        )
    }

    private func receive(_ packet: TransferPacket, from peer: MCPeerID) {
        guard !working else {
            _ = nearby.send(.acknowledgement(succeeded: false, details: "A handoff is already running."), to: peer)
            return
        }
        working = true
        result = "Locating \(packet.title) in Apple Music…"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let playback = MacMusic.resume(packet)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.result = playback.message
                self.working = false
                _ = self.nearby.send(.acknowledgement(succeeded: playback.succeeded, details: playback.message), to: peer)
            }
        }
    }
}

private struct MacMenuView: View {
    @ObservedObject var receiver: MacReceiverModel
    @ObservedObject var loginSettings: RIFTLoginSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(receiver.nearby.connectedPeers.isEmpty ? "Waiting for iPhone" : "iPhone connected")
        if let phone = receiver.nearby.connectedPeers.first {
            Text(phone.displayName).font(.caption)
        } else if let name = receiver.nearby.preferredPeerName {
            Text("Saved iPhone: \(name)").font(.caption)
        }
        Text(receiver.nearby.status).font(.caption)
        Divider()
        Button("Open RIFT") {
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        Button("Test Right-edge Portal") { receiver.previewPortal() }
        Divider()
        Toggle("Launch at Login", isOn: Binding(
            get: { loginSettings.enabled },
            set: { loginSettings.setEnabled($0) }
        ))
        if loginSettings.requiresApproval {
            Text("Approve RIFT in System Settings → Login Items").font(.caption)
        }
        Button("Quit RIFT") { NSApplication.shared.terminate(nil) }
            .onAppear {
                receiver.start()
                loginSettings.refresh()
            }
    }
}

struct MacHomeView: View {
    @ObservedObject var receiver: MacReceiverModel
    @ObservedObject var loginSettings: RIFTLoginSettings
    @State private var showingHelp = false
    @State private var showingAbout = false
    @State private var confirmingForget = false

    var body: some View {
        ZStack {
            FlickStyle.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 45))
                            .foregroundStyle(FlickStyle.pink)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RIFT")
                                .font(.system(size: 37, weight: .bold, design: .rounded))
                            Text("Music and files, beautifully connected.")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        Button { showingAbout = true } label: {
                            Label("About", systemImage: "info.circle")
                        }.buttonStyle(.bordered)
                    }

                    Button { showingHelp = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "list.number")
                            Text("Setup guide & troubleshooting").font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding(16)
                        .background(FlickStyle.violet.opacity(0.23), in: RoundedRectangle(cornerRadius: 17))
                    }
                    .buttonStyle(.plain)

                    StatusCard(
                        symbol: receiver.nearby.connectedPeers.isEmpty ? "antenna.radiowaves.left.and.right" : "checkmark.circle.fill",
                        headline: receiver.nearby.connectedPeers.isEmpty ? "Mac receiver ready" : "iPhone connected",
                        subheadline: receiver.nearby.status
                    )
                    if let name = receiver.nearby.preferredPeerName {
                        HStack {
                            Label("Approved iPhone: \(name)", systemImage: "iphone")
                            Spacer()
                            Button("Forget Pairing") { confirmingForget = true }
                                .buttonStyle(.bordered)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                    }
                    StatusCard(
                        symbol: receiver.working ? "hourglass" : "music.note",
                        headline: receiver.working ? "Opening Apple Music…" : "Playback",
                        subheadline: receiver.result
                    )
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.on.square.dashed")
                                .font(.title2).foregroundStyle(FlickStyle.pink)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("RIFT • Incoming").font(.headline)
                                Text("Send an item from your iPhone: a glowing portal opens on the RIGHT edge of your Mac and the item emerges into the screen.")
                                    .font(.subheadline).foregroundStyle(.white.opacity(0.75))
                            }
                        }
                        HStack(alignment: .center, spacing: 10) {
                            Text(receiver.portalStatus)
                                .font(.footnote).foregroundStyle(.white.opacity(0.8))
                            Spacer(minLength: 6)
                            Button {
                                receiver.previewPortal()
                            } label: {
                                Label("Test Portal Effect", systemImage: "sparkles.rectangle.stack")
                            }
                            .buttonStyle(.bordered)
                        }
                        if let file = receiver.lastPortalFile {
                            HStack(spacing: 10) {
                                Image(systemName: "doc.fill")
                                    .foregroundStyle(FlickStyle.pink)
                                Text(file.name).lineLimit(1)
                                Spacer()
                                Button("Show in Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([file.url])
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        if let link = receiver.lastPortalLink {
                            HStack(spacing: 8) {
                                Image(systemName: "link").foregroundStyle(FlickStyle.pink)
                                Text(link.absoluteString).lineLimit(1)
                                Spacer()
                                Link("Open Link", destination: link).buttonStyle(.bordered)
                            }
                        }
                        if receiver.lastPortalText != nil {
                            Label("Latest clipboard transfer is ready to paste.", systemImage: "doc.on.clipboard")
                                .font(.subheadline)
                        }
                        HStack {
                            Image(systemName: "arrow.down.doc")
                            Text("Files save to Downloads/RIFT. Animated portal opens at the RIGHT screen edge (at the mouse's height).")
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                    }
                    .padding(18)
                    .background(
                        LinearGradient(colors: [FlickStyle.violet.opacity(0.27), FlickStyle.pink.opacity(0.10)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 19)
                    )

                    if let packet = receiver.nearby.lastReceived {
                        HStack(spacing: 12) {
                            Image(systemName: "waveform")
                                .font(.largeTitle)
                                .foregroundStyle(FlickStyle.violet)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(packet.title).font(.headline)
                                Text(packet.artist).foregroundStyle(.white.opacity(0.7))
                                Text("Received at \(Int(packet.position)) seconds")
                                    .font(.caption).foregroundStyle(.white.opacity(0.55))
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        Label("Quick start", systemImage: "sparkles")
                            .font(.headline)
                            .foregroundStyle(FlickStyle.pink)
                        Text("1. Open RIFT on iPhone.")
                        Text("2. Pair once and approve your iPhone; RIFT remembers it.")
                        Text("3. Play a song on iPhone, then open RIFT and gently flick.")
                        Text("4. Allow access to control Apple's Music app if macOS asks.")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))

                    RIFTLaunchAtLoginControl(settings: loginSettings)

                    Text("RIFT remains active in the Mac menu bar when you close this window. Select Quit RIFT from the menu bar to stop receiving files. Your approved iPhone reconnects when you reopen RIFT on it; iOS may pause nearby connections in the background.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.6))
                    HStack {
                        Text("Created by Ksyusha · life999")
                        Spacer()
                        Link("Creator page", destination: URL(string: "https://guns.lol/life999")!)
                            .buttonStyle(.borderless)
                        Button("About") { showingAbout = true }
                    }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
                }
                .padding(27)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .task { receiver.start() }
        .sheet(isPresented: $showingHelp) {
            FlickTunesHelpView(platform: .mac).frame(minWidth: 510, minHeight: 540)
        }
        .sheet(isPresented: $showingAbout) {
            FlickTunesAboutView().frame(minWidth: 430, minHeight: 500)
        }
        .confirmationDialog("Forget approved iPhone?", isPresented: $confirmingForget, titleVisibility: .visible) {
            Button("Forget and Disconnect", role: .destructive) { receiver.nearby.forgetPairedDevice() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You will need to approve pairing again.")
        }
        .alert("Pair with iPhone?", isPresented: Binding(
            get: { receiver.nearby.invitationFrom != nil },
            set: { if !$0 { receiver.nearby.acceptInvitation(false) } }
        )) {
            Button("Allow") { receiver.nearby.acceptInvitation(true) }
            Button("Decline", role: .cancel) { receiver.nearby.acceptInvitation(false) }
        } message: {
            Text("Allow \(receiver.nearby.invitationFrom ?? "this iPhone") to transfer Apple Music playback?")
        }
    }
}
