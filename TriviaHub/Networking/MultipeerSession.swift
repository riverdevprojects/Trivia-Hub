import Foundation
import MultipeerConnectivity

/// Thin wrapper around `MCSession` + advertiser/browser. It owns the raw peer-to-peer
/// plumbing and forwards decoded events to a delegate (the `GameController`). It knows
/// nothing about game rules — it only moves `TriviaMessage`s and reports connections.
///
/// Host auto-accepts invitations, which is fine for a casual party game (GDD §3.4).
final class MultipeerSession: NSObject, ObservableObject {

    /// Events surfaced to the game layer. All are delivered on the main queue.
    protocol Delegate: AnyObject {
        func multipeer(_ session: MultipeerSession, peer peerID: MCPeerID, didChange state: MCSessionState)
        func multipeer(_ session: MultipeerSession, didReceive message: TriviaMessage, from peerID: MCPeerID)
        /// A joiner discovered/lost an advertised host lobby.
        func multipeer(_ session: MultipeerSession, didUpdateDiscoveredHosts hosts: [MCPeerID])
    }

    weak var delegate: Delegate?

    let myPeerID: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    /// Hosts discovered while browsing (joiner side), kept unique and ordered.
    @Published private(set) var discoveredHosts: [MCPeerID] = []

    /// Currently connected peers (does not include self).
    var connectedPeers: [MCPeerID] { session.connectedPeers }

    init(displayName: String) {
        // Peer display names must be 1–63 bytes; guard against empty/oversized names.
        let safeName = MultipeerSession.sanitize(displayName)
        self.myPeerID = MCPeerID(displayName: safeName)
        self.session = MCSession(peer: myPeerID,
                                 securityIdentity: nil,
                                 encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    static func sanitize(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Player" : trimmed
        // 63-byte cap per MCPeerID contract.
        return String(base.prefix(63))
    }

    // MARK: - Host

    func startHosting() {
        stopHosting()
        let advertiser = MCNearbyServiceAdvertiser(peer: myPeerID,
                                                   discoveryInfo: nil,
                                                   serviceType: GameConfig.serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
    }

    func stopHosting() {
        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil
        advertiser = nil
    }

    // MARK: - Join

    func startBrowsing() {
        stopBrowsing()
        discoveredHosts = []
        notifyDiscovered()
        let browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: GameConfig.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
        browser = nil
    }

    /// Joiner asks to join a discovered host.
    func invite(_ host: MCPeerID) {
        browser?.invitePeer(host, to: session, withContext: nil, timeout: 15)
    }

    // MARK: - Messaging

    /// Broadcast to every connected peer.
    func broadcast(_ message: TriviaMessage) {
        send(message, to: session.connectedPeers)
    }

    /// Send to a specific set of peers.
    func send(_ message: TriviaMessage, to peers: [MCPeerID]) {
        guard !peers.isEmpty else { return }
        do {
            let data = try message.encoded()
            try session.send(data, toPeers: peers, with: .reliable)
        } catch {
            // Non-fatal: a peer may have dropped between roster update and send.
            #if DEBUG
            print("MultipeerSession send failed: \(error)")
            #endif
        }
    }

    /// Tear everything down and disconnect.
    func teardown() {
        stopHosting()
        stopBrowsing()
        session.disconnect()
        discoveredHosts = []
    }

    // MARK: - Helpers

    private func notifyDiscovered() {
        delegate?.multipeer(self, didUpdateDiscoveredHosts: discoveredHosts)
    }
}

// MARK: - MCSessionDelegate

extension MultipeerSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.delegate?.multipeer(self, peer: peerID, didChange: state)
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = TriviaMessage.decode(from: data) else { return }
        DispatchQueue.main.async {
            self.delegate?.multipeer(self, didReceive: message, from: peerID)
        }
    }

    // Unused streaming/resource callbacks — required by protocol.
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate (host)

extension MultipeerSession: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept if there is still room (GDD §3.4).
        let hasRoom = session.connectedPeers.count + 1 < GameConfig.maxPlayers
        invitationHandler(hasRoom, hasRoom ? session : nil)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didNotStartAdvertisingPeer error: Error) {
        #if DEBUG
        print("Advertising failed: \(error)")
        #endif
    }
}

// MARK: - MCNearbyServiceBrowserDelegate (joiner)

extension MultipeerSession: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            if !self.discoveredHosts.contains(peerID) {
                self.discoveredHosts.append(peerID)
                self.notifyDiscovered()
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredHosts.removeAll { $0 == peerID }
            self.notifyDiscovered()
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        #if DEBUG
        print("Browsing failed: \(error)")
        #endif
    }
}
