import AppKit
import SwiftUI

/// A non-activating overlay anchored to the RIGHT edge of the display.
/// The file card visibly emerges from a glowing portal and stops on-screen.
/// It never steals focus or intercepts clicks from the user's other apps.
final class PortalArrivalPresenter {
    private var panel: NSPanel?
    private var currentID = UUID()

    func present(name: String, kind: ArrivalKind, transition: PortalTransition, previewURL: URL? = nil) {
        // Callbacks from the receiver are delivered on main, but preserve this
        // guarantee if the presenter is used by a background service later.
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.present(name: name, kind: kind, transition: transition, previewURL: previewURL)
            }
            return
        }

        panel?.orderOut(nil)
        panel = nil
        let id = UUID()
        currentID = id

        let pointer = NSEvent.mouseLocation
        // For multiple monitors, choose the display currently containing the
        // pointer, but ALWAYS use that screen's RIGHT edge for the portal.
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let width: CGFloat = 448
        let height: CGFloat = 280
        let rightEdge = screenFrame.maxX - width
        let lower = screenFrame.minY + 12
        let upper = max(lower, screenFrame.maxY - height - 12)
        let vertical = min(max(pointer.y - height * 0.5, lower), upper)

        let overlay = NSPanel(
            contentRect: NSRect(x: rightEdge, y: vertical, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.hasShadow = false
        overlay.level = .floating
        overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        overlay.ignoresMouseEvents = true
        overlay.hidesOnDeactivate = false
        overlay.isReleasedWhenClosed = false

        let preview = previewURL.flatMap { NSImage(contentsOf: $0) }
        overlay.contentView = NSHostingView(rootView: RightEdgePortalScene(
            filename: name,
            kind: kind,
            transition: transition,
            previewImage: preview
        ))
        panel = overlay
        overlay.orderFrontRegardless()

        // A single overlay at a time. An older animation must not dismiss a
        // new arrival that started while the previous portal was closing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.7) { [weak self] in
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
        case .file: return "File emerged from Portal"
        case .photo: return "Photo emerged from Portal"
        case .video: return "Video emerged from Portal"
        case .link: return "Link from your iPhone"
        case .clipboard: return "Clipboard from your iPhone"
        }
    }
}

private struct RightEdgePortalScene: View {
    let filename: String
    let kind: ArrivalKind
    let transition: PortalTransition
    let previewImage: NSImage?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var portalOpen = false
    @State private var emerged = false
    @State private var closing = false
    @State private var orbit = false

    private let purple = Color(red: 0.59, green: 0.28, blue: 1.0)
    private let pink = Color(red: 1.0, green: 0.26, blue: 0.65)
    private let cyan = Color(red: 0.30, green: 0.88, blue: 1.0)

    private var emergeAnimation: Animation {
        if reduceMotion { return .easeOut(duration: 0.18) }
        switch transition {
        case .glide: return .spring(response: 0.67, dampingFraction: 0.70)
        case .bloom: return .spring(response: 0.54, dampingFraction: 0.58)
        case .fade: return .easeOut(duration: 0.70)
        case .vortex: return .spring(response: 0.95, dampingFraction: 0.77)
        case .pulse: return .spring(response: 0.38, dampingFraction: 0.48)
        case .warp: return .easeOut(duration: 0.34)
        case .spark: return .spring(response: 0.70, dampingFraction: 0.66)
        case .ripple: return .easeOut(duration: 0.80)
        }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // The portal itself is fixed to the display edge (not the cursor).
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [pink.opacity(0.55), purple.opacity(0.31), .clear],
                        center: .center, startRadius: 7, endRadius: 155
                    )
                )
                .frame(width: 255, height: 275)
                .blur(radius: 16)
                .offset(x: 60)
                .opacity(portalOpen ? 1 : 0)

            // Small light trails appear as the object shoots out of the slit.
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, index == 1 ? cyan : pink, .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: CGFloat(90 + index * 30), height: 3)
                    .blur(radius: 1)
                    .offset(
                        x: emerged ? CGFloat(-220 - index * 28) : 20,
                        y: CGFloat((index - 1) * 35)
                    )
                    .opacity(portalOpen && !closing && !reduceMotion ? 0.70 : 0)
            }

            if portalOpen && !reduceMotion && (transition == .spark || transition == .vortex || transition == .ripple) {
                ForEach(0..<12, id: \.self) { i in
                    let angle = Double(i) * 0.5236
                    Circle()
                        .fill(i.isMultiple(of: 3) ? cyan : pink)
                        .frame(width: CGFloat(i.isMultiple(of: 3) ? 7 : 4))
                        .blur(radius: 0.6)
                        .offset(
                            x: orbit ? -CGFloat(70 + (i % 5) * 35) : 25,
                            y: CGFloat(sin(angle) * (orbit ? 100 : 34))
                        )
                        .opacity(orbit && !closing ? 0.85 : 0)
                }
            }

            if portalOpen && !reduceMotion && (transition == .ripple || transition == .pulse) {
                ForEach(0..<3, id: \.self) { i in
                    Ellipse()
                        .stroke(i == 1 ? cyan.opacity(0.8) : pink.opacity(0.65), lineWidth: 3)
                        .frame(width: CGFloat(85 + i * 50), height: CGFloat(212 + i * 22))
                        .scaleEffect(orbit ? 1.35 : 0.55)
                        .opacity(orbit && !closing ? 0.55 : 0)
                        .offset(x: 16)
                }
            }

            arrivedCard
                .frame(width: 302, height: 132)
                .padding(.trailing, 104)
                // Start inside the right-edge portal, fly LEFT into the Mac.
                .offset(x: reduceMotion ? 0 : (emerged ? 0 : (transition == .warp ? 440 : 350)))
                .scaleEffect(
                    x: reduceMotion || emerged ? 1 : (transition == .warp ? 2.0 : transition == .bloom ? 0.34 : transition == .pulse ? 0.25 : 0.85),
                    y: reduceMotion || emerged ? 1 : (transition == .warp ? 0.24 : transition == .bloom ? 0.34 : 0.85)
                )
                .rotationEffect(.degrees(reduceMotion || emerged ? 0 : (transition == .vortex ? 320 : 0)))
                .blur(radius: !reduceMotion && !emerged && (transition == .fade || transition == .warp) ? 16 : 0)
                .opacity(emerged && !closing ? 1 : 0)

            portalRing
                .offset(x: 28)
        }
        .frame(width: 448, height: 280)
        .clipped()
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.33)) {
                portalOpen = true
            }
            withAnimation(reduceMotion ? .none : .easeOut(duration: transition == .spark ? 1.3 : 0.85)) {
                orbit = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.07 : 0.25)) {
                withAnimation(emergeAnimation) { emerged = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.85) {
                withAnimation(.easeInOut(duration: reduceMotion ? 0.10 : 0.43)) {
                    closing = true
                    portalOpen = false
                }
            }
        }
    }

    private var portalRing: some View {
        ZStack {
            Ellipse()
                .fill(purple.opacity(0.68))
                .frame(width: 90, height: 232)
                .blur(radius: 22)

            Ellipse()
                .stroke(
                    AngularGradient(
                        colors: [cyan, purple, pink, .white, purple, cyan],
                        center: .center
                    ),
                    lineWidth: 8
                )
                .frame(width: 88, height: 222)
                .shadow(color: pink.opacity(0.95), radius: 15)
                .shadow(color: cyan.opacity(0.65), radius: 6)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.24, green: 0.09, blue: 0.48),
                                 Color(red: 0.08, green: 0.04, blue: 0.19)],
                        center: .center,
                        startRadius: 0, endRadius: 70
                    )
                )
                .frame(width: 65, height: 204)

            Ellipse()
                .stroke(.white.opacity(0.77), lineWidth: 1.7)
                .frame(width: 66, height: 204)
                .blur(radius: 0.3)

            Capsule()
                .fill(cyan.opacity(0.78))
                .frame(width: 2.5, height: 123)
                .blur(radius: 2)
        }
        .scaleEffect(x: portalOpen ? 1 : 0.12, y: portalOpen ? 1 : 0.04)
        .opacity(portalOpen ? 1 : 0)
        .accessibilityHidden(true)
    }

    private var arrivedCard: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 17)
                    .fill(
                        LinearGradient(
                            colors: [purple, pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                if let previewImage, kind == .photo {
                    Image(nsImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 68, height: 68)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 17))
                } else {
                    Image(systemName: kind.icon)
                        .font(.system(size: 31))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 68, height: 68)
            VStack(alignment: .leading, spacing: 7) {
                Text(kind.heading)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(filename)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.80))
                    .lineLimit(2)
                Label("RIFT • \(transition.title)", systemImage: "sparkles")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(cyan)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 302, height: 120)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [cyan.opacity(0.8), pink.opacity(0.68), purple.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.3
                )
        }
        .shadow(color: purple.opacity(0.45), radius: 22, y: 7)
        .accessibilityElement(children: .combine)
    }
}
