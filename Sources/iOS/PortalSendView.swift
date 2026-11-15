import CoreTransferable
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Select a real file or photo, then swipe left to send it to the saved Mac.
/// Portal never requests access to the whole photo library or file system.
struct PortalSendView: View {
    @ObservedObject var nearby: NearbyBridge

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showFiles = false
    @State private var stagedURL: URL?
    @State private var stagedName = ""
    @State private var stagedImage = false
    @State private var isSending = false
    @State private var status = "Choose an item above to begin."
    @State private var linkText = ""
    @AppStorage("rift.portal.effect") private var savedEffect = PortalTransition.glide.rawValue
    private var transition: PortalTransition { PortalTransition(rawValue: savedEffect) ?? .glide }
    @State private var flying = false
    @State private var dragOffset: CGFloat = 0
    @State private var linkDragOffset: CGFloat = 0
    @State private var linkFlying = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            FlickStyle.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Button { dismiss() } label: {
                            Label("Music", systemImage: "chevron.left")
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                        Text("RIFT • SEND")
                            .font(.caption.bold())
                            .foregroundStyle(FlickStyle.pink)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Send anything.")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                        Text("Swipe it away. Watch it arrive.")
                            .font(.headline)
                            .foregroundStyle(FlickStyle.pink)
                        Text("Choose a photo, video, document or link. Drag its card left and RIFT opens on the right edge of your Mac.")
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .padding(.top, 22)

                    StatusCard(
                        symbol: nearby.connectedPeers.isEmpty ? "wifi.exclamationmark" : "checkmark.circle.fill",
                        headline: nearby.connectedPeers.isEmpty ? "Mac not connected" : "Connected and ready",
                        subheadline: nearby.connectedPeers.isEmpty
                            ? "Go back to Music to connect your Mac once. RIFT will remember it."
                            : "Connected to \(nearby.connectedPeers.first?.displayName ?? "Mac")."
                    )

                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPhoto, matching: .any(of: [.images, .videos])) {
                            Label("Photos & Videos", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FlickStyle.violet)

                        Button { showFiles = true } label: {
                            Label("Browse Files", systemImage: "doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("READY TO SEND")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.6))

                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.white.opacity(0.10))
                        VStack(spacing: 15) {
                            if let url = stagedURL, stagedImage,
                               let image = UIImage(contentsOfFile: url.path) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 240, maxHeight: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 15))
                            } else {
                                Image(systemName: stagedURL == nil ? "square.on.square.dashed" : "doc.fill")
                                    .font(.system(size: 58))
                                    .foregroundStyle(FlickStyle.pink)
                            }
                            Text(stagedURL == nil ? "Pick a photo or file above" : stagedName)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                            Label("Drag LEFT to send to your Mac", systemImage: "arrow.left")
                                .font(.subheadline.bold())
                                .foregroundStyle(FlickStyle.pink)
                        }
                        .padding(24)
                    }
                    .frame(height: 290)
                    .contentShape(RoundedRectangle(cornerRadius: 24))
                    // Follow the finger continuously, then fly beyond the left
                    // edge only when the user releases a deliberate swipe.
                    .offset(x: flying ? -800 : dragOffset)
                    .scaleEffect(flying
                        ? (transition == .bloom ? 0.50 : 0.93)
                        : max(0.84, 1.0 - abs(dragOffset) / 1300.0))
                    .rotationEffect(.degrees(flying ? -13 : Double(dragOffset / 16.0)))
                    .opacity(flying ? 0 : 1)
                    .overlay(alignment: .leading) {
                        if dragOffset < -30 && !flying {
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.system(size: 37))
                                .foregroundStyle(FlickStyle.pink)
                                .offset(x: -20)
                                .transition(.opacity)
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 6)
                            .onChanged { value in
                                guard !isSending && !flying else { return }
                                dragOffset = min(0, value.translation.width)
                            }
                            .onEnded { value in
                                guard !isSending && !flying else { return }
                                let deliberate = value.translation.width < -115 &&
                                    abs(value.translation.width) > abs(value.translation.height) * 1.3
                                if deliberate && stagedURL != nil && !nearby.connectedPeers.isEmpty {
                                    sendSelected()
                                } else {
                                    withAnimation(.spring(response: 0.40, dampingFraction: 0.60)) {
                                        dragOffset = 0
                                    }
                                    if deliberate && stagedURL == nil {
                                        status = "Choose a photo or file first."
                                    } else if deliberate && nearby.connectedPeers.isEmpty {
                                        status = "Pair with your Mac before throwing an item."
                                    }
                                }
                            }
                    )
                    .accessibilityLabel("Selected item. Drag left and release to send to Mac.")

                    Button(action: sendSelected) {
                        Label("Send to Mac", systemImage: "arrow.up.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FlickStyle.pink)
                    .disabled(stagedURL == nil || isSending || nearby.connectedPeers.isEmpty)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Choose your arrival effect", systemImage: "sparkles")
                                .font(.headline)
                            Spacer()
                            Text("SAVED").font(.caption.bold()).foregroundStyle(FlickStyle.pink)
                        }
                        Text("Controls how the right-edge portal opens on your Mac. Your choice stays saved.")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.67))
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(PortalTransition.allCases) { effect in
                                Button {
                                    savedEffect = effect.rawValue
                                    UISelectionFeedbackGenerator().selectionChanged()
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Image(systemName: effect.symbol).font(.title3)
                                            Spacer()
                                            if transition == effect {
                                                Image(systemName: "checkmark.circle.fill")
                                            }
                                        }
                                        Text(effect.title).font(.headline)
                                        Text(effect.explanation)
                                            .font(.caption)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .opacity(0.72)
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
                                    .padding(12)
                                    .background(
                                        transition == effect ? FlickStyle.violet.opacity(0.57) : Color.white.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 16)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16)
                                            .strokeBorder(transition == effect ? FlickStyle.pink : Color.white.opacity(0.12), lineWidth: 1.5)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Send a website link", systemImage: "link").font(.headline)
                        TextField("https://example.com", text: $linkText)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        HStack {
                            Button("Send link") { sendLink() }
                                .buttonStyle(.borderedProminent)
                                .tint(FlickStyle.violet)
                            Button("Send copied text") { sendClipboard() }
                                .buttonStyle(.bordered)
                        }
                        .disabled(nearby.connectedPeers.isEmpty)
                        if PortalURL.normalized(linkText) != nil {
                            HStack(spacing: 10) {
                                Image(systemName: "link.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(FlickStyle.pink)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Drag this link to your Mac")
                                        .font(.headline)
                                    Text(linkText)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "arrow.left")
                            }
                            .padding(14)
                            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                            .offset(x: linkFlying ? -700 : linkDragOffset)
                            .opacity(linkFlying ? 0 : 1)
                            .gesture(DragGesture(minimumDistance: 6)
                                .onChanged { value in
                                    guard !linkFlying else { return }
                                    linkDragOffset = min(0, value.translation.width)
                                }
                                .onEnded { value in
                                    if value.translation.width < -115 &&
                                        nearby.connectedPeers.isEmpty == false {
                                        sendLink()
                                    } else {
                                        withAnimation(.spring(response: 0.40, dampingFraction: 0.65)) {
                                            linkDragOffset = 0
                                        }
                                    }
                                })
                        }
                        Text("Copied text is shared only when you choose to send it. Website links wait for you to open them on Mac.")
                            .font(.caption).foregroundStyle(.white.opacity(0.65))
                    }
                    .padding(18)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 19))

                    if isSending { ProgressView("Sending securely…").tint(FlickStyle.pink) }
                    StatusCard(symbol: "info.circle", headline: "Transfer status", subheadline: status)
                    Text("RIFT opens on the right edge of your Mac after your item arrives. Files save to Downloads/RIFT. Keep RIFT open on iPhone while sending.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.6))
                }
                .padding(22)
            }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                stageFromFiles(url)
            case .failure(let error):
                status = "Files picker: \(error.localizedDescription)"
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await stagePhoto(item) }
        }
    }

    private func stageFromFiles(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let temp = try makeTemporaryCopy(url, name: url.lastPathComponent)
            stagedURL = temp
            stagedName = url.lastPathComponent
            stagedImage = UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false
            status = "Ready. Drag left or tap Send to Mac."
        } catch {
            status = "Couldn't import file: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func stagePhoto(_ item: PhotosPickerItem) async {
        status = "Importing from your photo library…"
        do {
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                guard let movie = try await item.loadTransferable(type: PortalPickedMovie.self) else {
                    status = "The selected video couldn't be read."
                    return
                }
                stagedURL = movie.url
                stagedName = movie.url.lastPathComponent
                stagedImage = false
                status = "Video ready. Drag the card left to send it in full quality."
                return
            }
            guard let data = try await item.loadTransferable(type: Data.self) else {
                status = "The selected photo couldn't be read."
                return
            }
            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
            let name = "Photo-\(Int(Date().timeIntervalSince1970)).\(ext)"
            let dest = try temporaryURL(for: name)
            try data.write(to: dest, options: .atomic)
            stagedURL = dest
            stagedName = name
            stagedImage = true
            status = "Photo ready — drag left to send."
        } catch {
            status = "Couldn't import media: \(error.localizedDescription)"
        }
    }

    private func temporaryURL(for filename: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlickTunesPortal", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("\(UUID().uuidString)-\(filename)")
    }

    private func makeTemporaryCopy(_ source: URL, name: String) throws -> URL {
        let dest = try temporaryURL(for: name)
        try FileManager.default.copyItem(at: source, to: dest)
        return dest
    }

    private func animateThrow() {
        let duration: Double = transition == .fade ? 0.55 : 0.33
        withAnimation(.easeIn(duration: duration)) {
            flying = true
            dragOffset = -800
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
            flying = false
            dragOffset = 0
        }
    }

    private func animateLinkThrow() {
        withAnimation(.easeIn(duration: transition == .fade ? 0.55 : 0.33)) {
            linkFlying = true
            linkDragOffset = -700
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            linkFlying = false
            linkDragOffset = 0
        }
    }

    private func sendSelected() {
        guard !isSending, let stagedURL else { return }
        guard !nearby.connectedPeers.isEmpty else {
            status = "Connect to your Mac in the Music tab first."
            return
        }
        isSending = true
        animateThrow()
        status = "Sending \(stagedName)…"
        nearby.sendPortalFile(at: stagedURL, named: stagedName, transition: transition) { ok, message in
            isSending = false
            status = message
            if ok { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            else { UINotificationFeedbackGenerator().notificationOccurred(.error) }
        }
    }

    private func sendLink() {
        guard let url = PortalURL.normalized(linkText) else {
            status = "Enter an http:// or https:// URL."
            return
        }
        let sent = nearby.send(.portalLink(url, transition: transition))
        status = sent
            ? "Sent link to Mac. It won't open without a click."
            : "Mac disconnected. Reconnect and try again."
        if sent { animateLinkThrow() }
    }

    private func sendClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty, text.count <= 100_000 else {
            status = "Copy some text first (maximum 100,000 characters)."
            return
        }
        if let url = PortalURL.normalized(text) {
            status = nearby.send(.portalLink(url, transition: transition)) ? "Sent clipboard link." : "Mac isn't connected."
        } else {
            status = nearby.send(.portalText(text, transition: transition)) ? "Sent clipboard text." : "Mac isn't connected."
        }
    }
}


/// PhotosPicker can expose very large movies only as file transfers.
/// Copy the provider's temporary file immediately so it remains available
/// for MCSession's streaming resource transfer.
private struct PortalPickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("FlickTunesPortal", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let originalExt = received.file.pathExtension
            let suffix = originalExt.isEmpty ? "mov" : originalExt
            let destination = folder.appendingPathComponent(
                "Video-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString.prefix(6)).\(suffix)"
            )
            try FileManager.default.copyItem(at: received.file, to: destination)
            return PortalPickedMovie(url: destination)
        }
    }
}
