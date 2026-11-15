import Foundation

/// The visual arrival effect chosen on iPhone; no remote code is executed.
enum PortalTransition: String, CaseIterable, Identifiable, Codable {
    case glide, bloom, fade

    var id: String { rawValue }
    var title: String {
        switch self {
        case .glide: return "Glide"
        case .bloom: return "Bloom"
        case .fade: return "Fade"
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
