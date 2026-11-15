import Foundation
import MultipeerConnectivity
#if os(iOS)
import UIKit
#endif

/// The Mac advertises; the iPhone discovers and requests a connection.
/// MultipeerConnectivity provides encrypted transport over nearby networks.
final class NearbyBridge: NSObject, ObservableObject {
    static let serviceType = "flicktunes"

    @Published private(set) var discoveredPeers: [MCPeerID] = []
    @Published private(set) var connectedPeers: [MCPeerID] = []
    @Published private(set) var status = "Looking for nearby devices…"
    @Published private(set) var invitationFrom: String?
    @Published private(set) var lastReceived: TransferPacket?

    var onHandoff: ((TransferPacket, MCPeerID) -> Void)?
    var onAcknowledgement: ((Bool, String) -> Void)?

    private let localPeer: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var pendingInvitation: ((Bool, MCSession?) -> Void)?

    override init() {
        #if os(iOS)
        let name = UIDevice.current.name
        #else
        let name = Host.current().localizedName ?? "FlickTunes Mac"
        #endif
        let peer = MCPeerID(displayName: String(name.prefix(32)))
        self.localPeer = peer
        self.session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    func beginAdvertising() {
        stop()
        let advertiser = MCNearbyServiceAdvertiser(peer: localPeer, discoveryInfo: nil, serviceType: Self.serviceType)
        advertiser.delegate = self
        self.advertiser = advertiser
        advertiser.startAdvertisingPeer()
        status = "Ready — waiting for your iPhone"
    }

    func beginBrowsing() {
        stop()
        let browser = MCNearbyServiceBrowser(peer: localPeer, serviceType: Self.serviceType)
        browser.delegate = self
        self.browser = browser
        browser.startBrowsingForPeers()
        status = "Looking for your Mac…"
    }

    func connect(to peer: MCPeerID) {
        guard let browser else { return }
        status = "Requesting connection to \(peer.displayName)…"
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 25)
    }

    func acceptInvitation(_ accept: Bool) {
        let handler = pendingInvitation
        pendingInvitation = nil
        invitationFrom = nil
        handler?(accept, accept ? session : nil)
        if !accept { status = "Connection declined" }
    }

    @discardableResult
    func send(_ message: WireMessage, to specificPeer: MCPeerID? = nil) -> Bool {
        let peers = specificPeer.map { [$0] } ?? session.connectedPeers
        guard !peers.isEmpty, let payload = try? JSONEncoder().encode(message) else {
            status = "No connected device"
            return false
        }
        do {
            try session.send(payload, toPeers: peers, with: .reliable)
            return true
        } catch {
            status = "Transfer failed: \(error.localizedDescription)"
            return false
        }
    }

    func stop() {
        browser?.stopBrowsingForPeers()
        advertiser?.stopAdvertisingPeer()
        browser = nil
        advertiser = nil
    }

    deinit {
        browser?.stopBrowsingForPeers()
        advertiser?.stopAdvertisingPeer()
        session.disconnect()
    }

    private func refreshPeers() {
        connectedPeers = session.connectedPeers
        if !connectedPeers.isEmpty {
            status = "Connected to \(connectedPeers.map(\.displayName).joined(separator: ", "))"
        }
    }
}

extension NearbyBridge: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.refreshPeers()
            if state == .notConnected { self.status = "\(peerID.displayName) disconnected" }
            if state == .connecting { self.status = "Connecting to \(peerID.displayName)…" }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(WireMessage.self, from: data) else { return }
        DispatchQueue.main.async {
            switch message.kind {
            case .handoff:
                guard let packet = message.packet else { return }
                self.lastReceived = packet
                self.onHandoff?(packet, peerID)
            case .acknowledgement:
                self.onAcknowledgement?(message.succeeded ?? false, message.details ?? "No details")
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension NearbyBridge: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            if self.pendingInvitation != nil { invitationHandler(false, nil); return }
            self.pendingInvitation = invitationHandler
            self.invitationFrom = peerID.displayName
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async { self.status = "Advertising failed: \(error.localizedDescription)" }
    }
}

extension NearbyBridge: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(peerID) { self.discoveredPeers.append(peerID) }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { self.discoveredPeers.removeAll { $0 == peerID } }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { self.status = "Discovery failed: \(error.localizedDescription)" }
    }
}
