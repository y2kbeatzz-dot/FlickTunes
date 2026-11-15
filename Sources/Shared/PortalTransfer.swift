import Foundation

/// The visual arrival effect chosen on iPhone; no remote code is executed.
enum PortalTransition: String, CaseIterable, Identifiable, Codable {
    case glide, bloom, fade, vortex, pulse, warp, spark, ripple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glide: return "Glide"
        case .bloom: return "Bloom"
        case .fade: return "Dissolve"
        case .vortex: return "Vortex"
        case .pulse: return "Pulse"
        case .warp: return "Warp"
        case .spark: return "Stardust"
        case .ripple: return "Ripple"
        }
    }

    var symbol: String {
        switch self {
        case .glide: return "arrow.left"
        case .bloom: return "sparkles"
        case .fade: return "circle.dotted"
        case .vortex: return "tornado"
        case .pulse: return "waveform.path"
        case .warp: return "bolt.fill"
        case .spark: return "star.fill"
        case .ripple: return "water.waves"
        }
    }

    var explanation: String {
        switch self {
        case .glide: return "A smooth slide out of the portal."
        case .bloom: return "The item grows into view."
        case .fade: return "The item slowly materializes."
        case .vortex: return "A spinning entrance."
        case .pulse: return "A bright pulse, then a pop."
        case .warp: return "A fast, stretched-in arrival."
        case .spark: return "A burst of glowing stardust."
        case .ripple: return "Rings ripple as the item appears."
        }
    }
}

struct PortalReceivedFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let transition: PortalTransition
}

/// Recognizes user-entered URLs. Don't open external links without a click.
enum PortalURL {
    static func normalized(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && trimmed.count <= 2048 else { return nil }
        let text = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased(),
              (scheme == "https" || scheme == "http"), url.host != nil
        else { return nil }
        return url
    }
}
