import Foundation

struct TransferPacket: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    let title: String
    let artist: String
    let album: String
    let storeID: String
    let position: TimeInterval
    let duration: TimeInterval
    let wasPlaying: Bool
    let sentAt: Date

    var currentPosition: TimeInterval {
        let elapsed = wasPlaying ? max(0, Date().timeIntervalSince(sentAt)) : 0
        return max(0, min(duration > 0 ? duration : .greatestFiniteMagnitude, position + elapsed))
    }
}

struct WireMessage: Codable {
    enum Kind: String, Codable { case handoff, acknowledgement, portalLink, portalText }
    let kind: Kind
    let packet: TransferPacket?
    let succeeded: Bool?
    let details: String?

    static func handoff(_ packet: TransferPacket) -> WireMessage {
        WireMessage(kind: .handoff, packet: packet, succeeded: nil, details: nil)
    }

    static func acknowledgement(succeeded: Bool, details: String) -> WireMessage {
        WireMessage(kind: .acknowledgement, packet: nil, succeeded: succeeded, details: details)
    }

    static func portalLink(_ url: URL) -> WireMessage {
        WireMessage(kind: .portalLink, packet: nil, succeeded: nil, details: url.absoluteString)
    }

    static func portalText(_ text: String) -> WireMessage {
        WireMessage(kind: .portalText, packet: nil, succeeded: nil, details: text)
    }
}
