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
    @Published private(set) var connectingPeer: MCPeerID?
    @Published private(set) var preferredPeerName: String?
    @Published private(set) var isSuspended = false
    @Published private(set) var status = "Looking for nearby devices…"
    @Published private(set) var invitationFrom: String?
    @Published private(set) var lastReceived: TransferPacket?

    var onHandoff: ((TransferPacket, MCPeerID) -> Void)?
    var onAcknowledgement: ((Bool, String) -> Void)?
    var onPortalLink: ((URL) -> Void)?
    var onPortalText: ((String) -> Void)?
    var onPortalFile: ((PortalReceivedFile) -> Void)?
    var onPortalError: ((String) -> Void)?
    /// Called on the main queue after a previously approved or manually selected Mac connects.
    var onConnected: ((MCPeerID) -> Void)?

    private enum Mode { case idle, advertising, browsing }
    private var mode: Mode = .idle
    private let localPeer: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var pendingInvitation: ((Bool, MCSession?) -> Void)?
    private var pendingInviter: MCPeerID?
    private var approvedPeer: MCPeerID?
    private var preferredPeer: MCPeerID?
    private var trustedPhone: MCPeerID?
    private var retryWork: DispatchWorkItem?
    private var timeoutWork: DispatchWorkItem?
    private var retryCount = 0
    // Keeps the same incoming invite from producing overlapping approval
    // prompts or repeated MCSession negotiations.
    private var lastAcceptedInvitePeer: MCPeerID?
    private var lastAcceptedInviteAt = Date.distantPast
    private static let identityKey = "flicktunes.localPeer.v2"
    private static let preferredKey = "flicktunes.preferredMac.v2"
    private static let trustedKey = "flicktunes.trustedPhone.v2"

    override init() {
        #if os(iOS)
        let name = UIDevice.current.name
        #else
        let name = Host.current().localizedName ?? "FlickTunes Mac"
        #endif
        // A fresh MCPeerID every launch makes old pairings impossible to restore.
        let peer = Self.loadPeer(Self.identityKey) ?? MCPeerID(displayName: String(name.prefix(32)))
        self.localPeer = peer
        self.session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        self.preferredPeer = Self.loadPeer(Self.preferredKey)
        self.trustedPhone = Self.loadPeer(Self.trustedKey)
        self.preferredPeerName = preferredPeer?.displayName ?? trustedPhone?.displayName
        super.init()
        Self.savePeer(peer, key: Self.identityKey)
        session.delegate = self
    }

    func beginAdvertising() {
        guard mode != .advertising else { return }
        stopDiscovery()
        mode = .advertising
        let service = MCNearbyServiceAdvertiser(peer: localPeer, discoveryInfo: nil, serviceType: Self.serviceType)
        service.delegate = self
        advertiser = service
        service.startAdvertisingPeer()
        status = connectedPeers.isEmpty ? "Ready — waiting for your iPhone" : connectionDescription
    }

    func beginBrowsing() {
        guard mode != .browsing else { return }
        stopDiscovery()
        mode = .browsing
        let discovery = MCNearbyServiceBrowser(peer: localPeer, serviceType: Self.serviceType)
        discovery.delegate = self
        browser = discovery
        discovery.startBrowsingForPeers()
        status = connectedPeers.isEmpty ? "Looking for your Mac…" : connectionDescription
    }

    func connect(to peer: MCPeerID) {
        guard mode == .browsing, !isSuspended, connectingPeer == nil,
              !connectedPeers.contains(peer), discoveredPeers.contains(peer) else { return }
        retryWork?.cancel()
        retryWork = nil
        retryCount = 0
        invite(peer, automatically: false)
    }

    /// Persisted peer identity, not just the visible device name.
    /// A stale flick should never be delivered to a different device that
    /// happens to advertise the same display name.
    var savedMacPeer: MCPeerID? { preferredPeer }

    func canConnect(to peer: MCPeerID) -> Bool {
        mode == .browsing && !isSuspended && connectingPeer == nil &&
        connectedPeers.isEmpty && discoveredPeers.contains(peer)
    }

    func rescan() {
        guard mode == .browsing, !isSuspended, connectedPeers.isEmpty else { return }
        cancelPending()
        retryCount = 0
        discoveredPeers.removeAll()
        browser?.stopBrowsingForPeers()
        // A new browser instance discards old discovery callbacks from an
        // earlier scan, preventing ghost peers and repeated device rows.
        let refreshed = MCNearbyServiceBrowser(peer: localPeer, serviceType: Self.serviceType)
        refreshed.delegate = self
        browser = refreshed
        refreshed.startBrowsingForPeers()
        status = "Searching for your Mac again…"
    }

    func suspendForBackground() {
        guard mode == .browsing, !isSuspended else { return }
        isSuspended = true
        cancelPending()
        browser?.stopBrowsingForPeers()
        // Do not deliberately disconnect an established session when the
        // user briefly switches to Music. iOS can suspend it on its own.
        status = connectedPeers.isEmpty
            ? "Searching paused while iPhone is in background"
            : connectionDescription
    }

    func resumeAfterForeground() {
        guard mode == .browsing else { beginBrowsing(); return }
        if isSuspended {
            isSuspended = false
            retryCount = 0
            discoveredPeers.removeAll()
            browser?.startBrowsingForPeers()
            status = connectedPeers.isEmpty ? "Looking for your saved Mac…" : connectionDescription
        } else if let preferredPeer, connectedPeers.isEmpty, discoveredPeers.contains(preferredPeer) {
            scheduleReconnect(preferredPeer)
        }
    }

    func acceptInvitation(_ accept: Bool) {
        guard let handler = pendingInvitation else { return }
        pendingInvitation = nil
        invitationFrom = nil
        if accept {
            approvedPeer = pendingInviter
            lastAcceptedInvitePeer = pendingInviter
            lastAcceptedInviteAt = Date()
        }
        pendingInviter = nil
        handler(accept, accept ? session : nil)
        status = accept ? "Connecting approved iPhone…" : "Connection declined"
    }

    func forgetPairedDevice() {
        cancelPending()
        preferredPeer = nil
        trustedPhone = nil
        approvedPeer = nil
        preferredPeerName = nil
        retryCount = 0
        lastAcceptedInvitePeer = nil
        lastAcceptedInviteAt = .distantPast
        UserDefaults.standard.removeObject(forKey: Self.preferredKey)
        UserDefaults.standard.removeObject(forKey: Self.trustedKey)
        session.disconnect()
        connectedPeers.removeAll()
        status = "Pairing cleared — connect again to approve a new device"
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

    /// Sends an actual file via MCSession's resource stream, not as a giant
    /// JSON message. Callers must keep the temporary local file until completion.
    func sendPortalFile(
        at url: URL, named filename: String, transition: PortalTransition,
        completion: @escaping (Bool, String) -> Void
    ) {
        guard let peer = session.connectedPeers.first else {
            completion(false, "Connect to your Mac first.")
            return
        }
        let cleanName = String(filename
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .prefix(120))
        let safeName = cleanName.isEmpty ? "Transfer" : cleanName
        let resourceName = "ft--\(transition.rawValue)--\(UUID().uuidString)--\(safeName)"
        guard let _ = session.sendResource(at: url, withName: resourceName, toPeer: peer, withCompletionHandler: { error in
            DispatchQueue.main.async {
                if let error {
                    completion(false, "Transfer failed: \(error.localizedDescription)")
                } else {
                    completion(true, "Sent \(safeName) to your Mac.")
                }
            }
        }) else {
            completion(false, "Could not start the file transfer. Reconnect and try again.")
            return
        }
    }

    func stop() {
        cancelPending()
        stopDiscovery()
        mode = .idle
        session.disconnect()
        connectedPeers.removeAll()
        status = "Nearby connection stopped"
    }

    deinit {
        browser?.stopBrowsingForPeers()
        advertiser?.stopAdvertisingPeer()
        retryWork?.cancel()
        timeoutWork?.cancel()
        session.disconnect()
    }

    private var connectionDescription: String {
        "Connected to \(connectedPeers.map(\.displayName).joined(separator: ", "))"
    }

    private func stopDiscovery() {
        browser?.stopBrowsingForPeers()
        advertiser?.stopAdvertisingPeer()
        browser = nil
        advertiser = nil
        discoveredPeers.removeAll()
    }

    private func cancelPending() {
        retryWork?.cancel()
        retryWork = nil
        timeoutWork?.cancel()
        timeoutWork = nil
        connectingPeer = nil
    }

    private func invite(_ peer: MCPeerID, automatically: Bool) {
        guard let browser, mode == .browsing, !isSuspended,
              connectedPeers.isEmpty, connectingPeer == nil,
              discoveredPeers.contains(peer) else { return }
        connectingPeer = peer
        status = automatically ? "Reconnecting to \(peer.displayName)…" : "Pairing with \(peer.displayName)…"
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 15)
        timeoutWork?.cancel()
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.connectingPeer == peer, self.connectedPeers.isEmpty else { return }
            self.connectingPeer = nil
            self.timeoutWork = nil
            self.status = "Connection timed out — check both devices"
            if self.preferredPeer == peer { self.scheduleReconnect(peer) }
        }
        timeoutWork = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 19, execute: timeout)
    }

    private func scheduleReconnect(_ peer: MCPeerID) {
        guard mode == .browsing, !isSuspended, preferredPeer == peer,
              connectedPeers.isEmpty, connectingPeer == nil, retryWork == nil else { return }
        guard discoveredPeers.contains(peer) else {
            status = "Waiting for \(peer.displayName) to appear…"
            return
        }
        let delays: [TimeInterval] = [4, 10]
        guard retryCount < delays.count else {
            status = "Saved Mac unavailable — use Rescan if it remains offline"
            return
        }
        let delay = delays[retryCount]
        retryCount += 1
        status = "Reconnecting to saved Mac (\(retryCount)/\(delays.count))…"
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.retryWork = nil
            guard self.discoveredPeers.contains(peer) else {
                self.status = "Mac out of range — waiting for it to appear"
                return
            }
            self.invite(peer, automatically: true)
        }
        retryWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func handleState(_ peer: MCPeerID, _ state: MCSessionState) {
        switch state {
        case .connected:
            // MultipeerConnectivity sometimes emits repeated state notifications.
            // They must not trigger duplicate handoffs or stack peer labels.
            let wasConnected = connectedPeers.contains(peer)
            cancelPending()
            connectedPeers = [peer]
            retryCount = 0
            status = connectionDescription
            if mode == .browsing {
                preferredPeer = peer
                preferredPeerName = peer.displayName
                Self.savePeer(peer, key: Self.preferredKey)
            }
            if mode == .advertising, approvedPeer == peer {
                trustedPhone = peer
                preferredPeerName = peer.displayName
                approvedPeer = nil
                Self.savePeer(peer, key: Self.trustedKey)
            }
            // One callback for each real transition, not each MCSession event.
            if !wasConnected { onConnected?(peer) }
        case .connecting:
            if connectedPeers.isEmpty && (connectingPeer == peer || approvedPeer == peer) {
                status = "Connecting securely to \(peer.displayName)…"
            }
        case .notConnected:
            // Stale .notConnected callbacks may arrive after a newer connected
            // event. Never let one overwrite a live connection.
            if session.connectedPeers.contains(peer) { return }
            let wasTracked = connectedPeers.contains(peer) || connectingPeer == peer || approvedPeer == peer
            guard wasTracked else { return }
            connectedPeers.removeAll { $0 == peer }
            if connectingPeer == peer {
                timeoutWork?.cancel()
                timeoutWork = nil
                connectingPeer = nil
            }
            if approvedPeer == peer { approvedPeer = nil }
            if !connectedPeers.isEmpty { status = connectionDescription }
            else if isSuspended { status = "Paused — reopen FlickTunes to reconnect" }
            else if mode == .browsing, preferredPeer == peer { scheduleReconnect(peer) }
            else if mode == .browsing { status = "Connection ended — select your Mac to retry" }
            else { status = "Waiting for your saved iPhone to reconnect" }
        @unknown default:
            status = "Connection state changed"
        }
    }

    private static func loadPeer(_ key: String) -> MCPeerID? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: data)
    }

    private static func savePeer(_ peer: MCPeerID, key: String) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: peer, requiringSecureCoding: true) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

extension NearbyBridge: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.handleState(peerID, state)
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
            case .portalLink:
                guard let text = message.details, let url = PortalURL.normalized(text) else { return }
                self.onPortalLink?(url)
            case .portalText:
                guard let text = message.details, text.count <= 100_000 else { return }
                self.onPortalText?(text)
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        DispatchQueue.main.async {
            guard self.trustedPhone == peerID else { return }
            self.status = "Receiving a Portal file…"
        }
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // The incoming temporary file is only guaranteed to exist during this
        // delegate callback. Move it immediately, without executing contents.
        #if os(macOS)
        guard trustedPhone == peerID else { return }
        guard error == nil, let localURL else {
            DispatchQueue.main.async {
                self.onPortalError?("The file transfer was interrupted.")
                self.status = "File transfer failed"
            }
            return
        }
        let parts = resourceName.split(separator: "--", maxSplits: 3, omittingEmptySubsequences: false)
        guard parts.count == 4, parts[0] == "ft",
              let style = PortalTransition(rawValue: String(parts[1])) else { return }
        let rawName = String(parts[3])
        let cleaned = rawName
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let name = cleaned.isEmpty || cleaned == "." || cleaned == ".."
            ? "Received File" : String(cleaned.prefix(120))
        do {
            let fm = FileManager.default
            let downloads = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let folder = downloads.appendingPathComponent("FlickTunes", isDirectory: true)
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let source = URL(fileURLWithPath: name)
            let ext = source.pathExtension
            let stem = source.deletingPathExtension().lastPathComponent
            var destination = folder.appendingPathComponent(name)
            var suffix = 2
            while fm.fileExists(atPath: destination.path) {
                let next = ext.isEmpty ? "\(stem) (\(suffix))" : "\(stem) (\(suffix)).\(ext)"
                destination = folder.appendingPathComponent(next)
                suffix += 1
            }
            try fm.moveItem(at: localURL, to: destination)
            let received = PortalReceivedFile(url: destination, name: destination.lastPathComponent, transition: style)
            DispatchQueue.main.async {
                self.status = "Portal file received"
                self.onPortalFile?(received)
            }
        } catch {
            DispatchQueue.main.async {
                self.status = "Could not save incoming file"
                self.onPortalError?("File could not be saved: \(error.localizedDescription)")
            }
        }
        #endif
    }
}

extension NearbyBridge: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            guard self.advertiser === advertiser, self.mode == .advertising else {
                invitationHandler(false, nil)
                return
            }
            if !self.connectedPeers.isEmpty || !self.session.connectedPeers.isEmpty {
                // This receiver accepts one iPhone at a time. Ignore duplicate
                // invites rather than stacking sessions and confirmation alerts.
                invitationHandler(false, nil)
                return
            }
            if self.pendingInvitation != nil {
                invitationHandler(false, nil)
                return
            }
            if self.lastAcceptedInvitePeer == peerID &&
                Date().timeIntervalSince(self.lastAcceptedInviteAt) < 9 {
                invitationHandler(false, nil)
                return
            }
            if self.trustedPhone == peerID {
                self.lastAcceptedInvitePeer = peerID
                self.lastAcceptedInviteAt = Date()
                self.status = "Restoring saved iPhone connection…"
                invitationHandler(true, self.session)
                return
            }
            self.pendingInvitation = invitationHandler
            self.pendingInviter = peerID
            self.invitationFrom = peerID.displayName
            self.status = "Approve pairing from \(peerID.displayName)"
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async { self.status = "Advertising failed: \(error.localizedDescription)" }
    }
}

extension NearbyBridge: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            guard self.browser === browser, self.mode == .browsing, !self.isSuspended else { return }
            guard !self.discoveredPeers.contains(peerID) else { return }
            // Bonjour can report old instances under an identical device
            // name. Show one row per Mac, preferring the saved peer identity.
            if let existing = self.discoveredPeers.first(where: { $0.displayName == peerID.displayName }) {
                if existing == self.preferredPeer { return }
                self.discoveredPeers.removeAll { $0.displayName == peerID.displayName }
            }
            self.discoveredPeers.append(peerID)
            if self.preferredPeer == peerID && self.connectedPeers.isEmpty {
                self.scheduleReconnect(peerID)
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            guard self.browser === browser else { return }
            self.discoveredPeers.removeAll { $0 == peerID }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { self.status = "Discovery failed: \(error.localizedDescription)" }
    }
}
