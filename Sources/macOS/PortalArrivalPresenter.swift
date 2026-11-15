import AppKit
import SwiftUI
import QuartzCore

/// A temporary non-interactive overlay, positioned beside the current pointer.
/// It does not take focus from the user's current Mac app.
final class PortalArrivalPresenter {
    private var panel: NSPanel?
    private var currentID = UUID()

    func present(name: String, kind: ArrivalKind, transition: PortalTransition, previewURL: URL? = nil) {
        panel?.orderOut(nil)
        panel = nil
        let id = UUID()
        currentID = id

        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let width: CGFloat = 330
        let height: CGFloat = 154
        let x = min(max(pointer.x + 18, bounds.minX + 8), bounds.maxX - width - 8)
        let y = min(max(pointer.y - 25, bounds.minY + 8), bounds.maxY - height - 8)

        let destination = NSRect(x: x, y: y, width: width, height: height)
        // For Glide the item enters from the Mac's LEFT edge, matching the
        // swipe out of the LEFT side of the iPhone.
        let initial = transition == .glide
            ? NSRect(x: bounds.minX - width, y: y, width: width, height: height)
            : destination
        let toast = NSPanel(
            contentRect: initial,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        toast.isOpaque = false
        toast.backgroundColor = .clear
        toast.hasShadow = false
        toast.level = .floating
        toast.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        toast.ignoresMouseEvents = true
        toast.hidesOnDeactivate = false
        let preview = previewURL.flatMap { NSImage(contentsOf: $0) }
        toast.contentView = NSHostingView(rootView: PortalArrivalToast(
            filename: name,
            kind: kind,
            transition: transition,
            previewImage: preview
        ))
        panel = toast
        toast.orderFrontRegardless()
        if transition == .glide {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.62
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                toast.animator().setFrame(destination, display: true)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) { [weak self] in
            guard let self, self.currentID == id else { return }
            self.panel?.orderOut(nil)
            self.panel = nil
        }
    }
}

enum ArrivalKind: Equatable {
    case file, photo, video, link, clipboard

    var icon: String {
        switch self {
        case .file: return "doc.fill"
        case .photo: return "photo.fill"
        case .video: return "film.fill"
        case .link: return "link"
        case .clipboard: return "doc.on.clipboard"
        }
    }

    var heading: String {
        switch self {
        case .file: return "File landed on your Mac"
        case .photo: return "Photo landed on your Mac"
        case .video: return "Video landed on your Mac"
        case .link: return "Link from iPhone"
        case .clipboard: return "Clipboard from iPhone"
        }
    }
}

private struct PortalArrivalToast: View {
    let filename: String
    let kind: ArrivalKind
    let transition: PortalTransition
    let previewImage: NSImage?

    @State private var appeared = false

    private var initialOffset: CGFloat { 0 }

    private var initialScale: CGFloat {
        transition == .bloom ? 0.45 : 0.92
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.62, green: 0.31, blue: 1),
                                     Color(red: 0.98, green: 0.28, blue: 0.61)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                if let previewImage, kind == .photo {
                    Image(nsImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                } else {
                    Image(systemName: kind.icon)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 60, height: 60)
            VStack(alignment: .leading, spacing: 6) {
                Text(kind.heading)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(filename)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
                Text("Via FlickTunes Portal")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(red: 1, green: 0.58, blue: 0.78))
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .frame(width: 326, height: 118)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 25)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 25)
                .strokeBorder(.white.opacity(0.27), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.32), radius: 25, y: 8)
        .padding(2)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : initialScale)
        .offset(x: appeared ? 0 : initialOffset)
        .onAppear {
            withAnimation(
                transition == .glide
                    ? .spring(response: 0.55, dampingFraction: 0.72)
                    : .easeOut(duration: transition == .fade ? 0.65 : 0.44)
            ) {
                appeared = true
            }
        }
    }
}
