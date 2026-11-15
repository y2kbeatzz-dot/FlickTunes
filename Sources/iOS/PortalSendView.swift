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
    @State private var status = "Select a photo or file to start."
    @State private var linkText = ""
    @State private var transition: PortalTransition = .glide
    @State private var flying = false

    var body: some View {
        ZStack {
            FlickStyle.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Portal.")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                        Text("Throw it. It lands on your Mac.")
                            .font(.headline)
                            .foregroundStyle(FlickStyle.pink)
                        Text("Photos, documents and links — no AirDrop menu.")
                            .foregroundStyle(.white.opacity(0.72))
                    }
                    .padding(.top, 22)

                    StatusCard(
                        symbol: nearby.connectedPeers.isEmpty ? "wifi.exclamationmark" : "checkmark.circle.fill",
                        headline: nearby.connectedPeers.isEmpty ? "Waiting for your Mac" : "Mac ready",
                        subheadline: nearby.connectedPeers.isEmpty
                            ? "Pair in the Music tab first. Portal uses the same saved connection."
                            : "Connected to \(nearby.connectedPeers.first?.displayName ?? "Mac")."
                    )

                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Choose Photo", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(FlickStyle.violet)

                        Button { showFiles = true } label: {
                            Label("Choose File", systemImage: "doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("SELECTED ITEM")
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
                            Text(stagedURL == nil ? "Choose something to throw" : stagedName)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                            Label("Swipe this card off the LEFT edge", systemImage: "arrow.left")
                                .font(.subheadline.bold())
                                .foregroundStyle(FlickStyle.pink)
                        }
                        .padding(24)
                    }
                    .frame(height: 290)
                    .contentShape(RoundedRectangle(cornerRadius: 24))
                    .offset(x: flying ? -650 : 0)
                    .opacity(flying ? 0 : 1)
                    .gesture(
                        DragGesture(minimumDistance: 25).onEnded { value in
                            guard value.translation.width < -95,
                                  abs(value.translation.width) > abs(value.translation.height) else {
                                return
                            }
                            sendSelected()
                        }
                    )
                    .accessibilityLabel("Selected file. Swipe left to send to Mac.")

                    Button(action: sendSelected) {
                        Label("Send selected item to Mac", systemImage: "arrow.up.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(FlickStyle.pink)
                    .disabled(stagedURL == nil || isSending || nearby.connectedPeers.isEmpty)

                    VStack(alignment: .leading, spacing: 9) {
                        Text("ARRIVAL ANIMATION").font(.caption.bold()).foregroundStyle(.white.opacity(0.65))
                        Picker("Arrival", selection: $transition) {
                            ForEach(PortalTransition.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Send a link", systemImage: "link").font(.headline)
                        TextField("https://example.com", text: $linkText)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        HStack {
                            Button("Send Link") { sendLink() }
                                .buttonStyle(.borderedProminent)
                                .tint(FlickStyle.violet)
                            Button("Send Clipboard") { sendClipboard() }
                                .buttonStyle(.bordered)
                        }
                        .disabled(nearby.connectedPeers.isEmpty)
                        Text("Clipboard text is only read when you tap Send Clipboard. Links are shown on your Mac, not opened automatically.")
                            .font(.caption).foregroundStyle(.white.opacity(0.65))
                    }
                    .padding(18)
                    .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 19))

                    if isSending { ProgressView("Sending securely…").tint(FlickStyle.pink) }
                    StatusCard(symbol: "info.circle", headline: "Portal status", subheadline: status)
                    Text("Files arrive in Downloads/FlickTunes on your Mac. A small arrival animation appears near the Mac pointer. Keep both devices nearby and FlickTunes open on iPhone until sending finishes.")
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
            status = "Ready. Swipe the card left or tap Send."
        } catch {
            status = "Couldn't import file: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func stagePhoto(_ item: PhotosPickerItem) async {
        status = "Importing photo…"
        do {
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
            status = "Photo ready. Swipe the card left."
        } catch {
            status = "Couldn't import photo: \(error.localizedDescription)"
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
        withAnimation(.easeIn(duration: 0.28)) { flying = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            flying = false
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
        status = nearby.send(.portalLink(url))
            ? "Sent link to Mac. It won't open without a click."
            : "Mac disconnected. Reconnect and try again."
    }

    private func sendClipboard() {
        guard let text = UIPasteboard.general.string, !text.isEmpty, text.count <= 100_000 else {
            status = "Copy some text first (maximum 100,000 characters)."
            return
        }
        if let url = PortalURL.normalized(text) {
            status = nearby.send(.portalLink(url)) ? "Sent clipboard link." : "Mac isn't connected."
        } else {
            status = nearby.send(.portalText(text)) ? "Sent clipboard text." : "Mac isn't connected."
        }
    }
}
