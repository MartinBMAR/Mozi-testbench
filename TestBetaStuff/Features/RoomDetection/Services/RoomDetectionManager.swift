import Foundation
import CoreLocation
import CoreBluetooth
import MultipeerConnectivity

// MARK: - Room Detection Manager

/// Manages automatic room detection using iBeacon + Multipeer Connectivity
class RoomDetectionManager: NSObject {

    // MARK: - Properties

    // App-wide beacon UUID (same for all users)
    static let appBeaconUUID = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!

    // Multipeer service type (max 15 chars, lowercase)
    static let serviceType = "testbeta-room"

    // User identification
    private let userProfile: UserProfile

    // iBeacon components
    private let locationManager = CLLocationManager()
    private var beaconRegion: CLBeaconRegion!
    private var isBeaconActive = false

    // Multipeer components
    private var peerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!

    // Detected peers storage
    private(set) var detectedPeers: [String: DetectedPeer] = [:]

    // Cleanup timer
    private var cleanupTimer: Timer?

    // Callbacks
    var onPeersUpdated: (([DetectedPeer]) -> Void)?
    var onLog: ((String) -> Void)?

    // MARK: - Initialization

    init(userProfile: UserProfile) {
        self.userProfile = userProfile
        super.init()
        setupLocationManager()
        setupMultipeer()
    }

    // MARK: - Setup Methods

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()

        // Create beacon region for broadcasting
        let beaconUUID = Self.appBeaconUUID
        let major = userIdToMajor(userProfile.id)
        beaconRegion = CLBeaconRegion(
            uuid: beaconUUID,
            major: major,
            identifier: "com.testbeta.beacon"
        )
        beaconRegion.notifyEntryStateOnDisplay = true
        beaconRegion.notifyOnEntry = true
        beaconRegion.notifyOnExit = true
    }

    private func setupMultipeer() {
        // Create peer ID
        peerID = MCPeerID(displayName: userProfile.id)

        // Create session
        session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session.delegate = self

        // Create advertiser
        advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ["userId": userProfile.id],
            serviceType: Self.serviceType
        )
        advertiser.delegate = self

        // Create browser
        browser = MCNearbyServiceBrowser(
            peer: peerID,
            serviceType: Self.serviceType
        )
        browser.delegate = self
    }

    // MARK: - Public Methods

    /// Start room detection (beacon + multipeer)
    func startDetection() {
        log("🚀 Starting room detection...")

        // Start beacon broadcasting
        startBeaconBroadcasting()

        // Start beacon monitoring
        startBeaconMonitoring()

        // Start multipeer advertising
        advertiser.startAdvertisingPeer()
        log("📡 Started advertising via Multipeer")

        // Start multipeer browsing
        browser.startBrowsingForPeers()
        log("🔍 Started browsing for peers")

        // Start cleanup timer
        startCleanupTimer()
    }

    /// Stop room detection
    func stopDetection() {
        log("🛑 Stopping room detection...")

        // Stop beacon
        stopBeaconBroadcasting()
        locationManager.stopMonitoring(for: beaconRegion)

        // Stop multipeer
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()

        // Disconnect all peers
        session.disconnect()

        // Stop cleanup timer
        cleanupTimer?.invalidate()

        // Clear detected peers
        detectedPeers.removeAll()
        notifyPeersUpdated()

        log("✅ Room detection stopped")
    }

    /// Send test message to all connected peers
    func sendMessage(_ text: String) {
        guard !session.connectedPeers.isEmpty else {
            log("⚠️ No connected peers to send message")
            return
        }

        let message = NetworkMessage(
            type: .message,
            payload: text.data(using: .utf8) ?? Data(),
            timestamp: Date()
        )

        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            log("📤 Sent message to \(session.connectedPeers.count) peer(s)")
        } catch {
            log("❌ Failed to send message: \(error.localizedDescription)")
        }
    }

    // MARK: - Beacon Methods

    private func startBeaconBroadcasting() {
        guard !isBeaconActive else { return }

        if CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self) {
            locationManager.startMonitoring(for: beaconRegion)
            // Note: Actual broadcasting happens via peripheralManager
            // For iOS 13+, we use CLLocationManager which handles this automatically
            isBeaconActive = true
            log("📍 Started beacon broadcasting")
        } else {
            log("❌ Beacon monitoring not available")
        }
    }

    private func stopBeaconBroadcasting() {
        guard isBeaconActive else { return }
        locationManager.stopMonitoring(for: beaconRegion)
        isBeaconActive = false
        log("📍 Stopped beacon broadcasting")
    }

    private func startBeaconMonitoring() {
        // Monitor for any beacon with our app UUID
        let monitorRegion = CLBeaconRegion(
            uuid: Self.appBeaconUUID,
            identifier: "com.testbeta.monitor"
        )

        locationManager.startMonitoring(for: monitorRegion)

        // Use the new iOS 13+ API with CLBeaconIdentityConstraint
        let constraint = CLBeaconIdentityConstraint(uuid: Self.appBeaconUUID)
        locationManager.startRangingBeacons(satisfying: constraint)
        log("👀 Started monitoring for beacons")
    }

    // MARK: - Helper Methods

    /// Convert user ID to beacon major value (simple hash)
    private func userIdToMajor(_ userId: String) -> UInt16 {
        let hash = abs(userId.hashValue)
        return UInt16(hash % 65535)
    }

    /// Extract user ID from beacon major value (reverse lookup - simplified)
    private func majorToUserId(_ major: UInt16) -> String {
        // In production, you'd want a proper mapping service
        // For POC, we use the major value as pseudo-ID
        return "peer-\(major)"
    }

    /// Start cleanup timer to remove stale peers
    private func startCleanupTimer() {
        cleanupTimer?.invalidate()
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.cleanupStalePeers()
        }
    }

    /// Remove peers that haven't been seen in a while
    private func cleanupStalePeers() {
        let timeout: TimeInterval = 10.0
        let now = Date()

        var removedCount = 0
        detectedPeers = detectedPeers.filter { _, peer in
            let isStale = now.timeIntervalSince(peer.lastSeen) > timeout
            if isStale {
                removedCount += 1
            }
            return !isStale
        }

        if removedCount > 0 {
            log("🧹 Cleaned up \(removedCount) stale peer(s)")
            notifyPeersUpdated()
        }
    }

    /// Notify observers of peer updates
    private func notifyPeersUpdated() {
        let peers = Array(detectedPeers.values).sorted { $0.lastSeen > $1.lastSeen }
        DispatchQueue.main.async {
            self.onPeersUpdated?(peers)
        }
    }

    /// Log message
    private func log(_ message: String) {
        print("[RoomDetection] \(message)")
        DispatchQueue.main.async {
            self.onLog?(message)
        }
    }

    /// Send profile to peer
    private func sendProfile(to peer: MCPeerID) {
        do {
            let profileData = try userProfile.encode()
            let message = NetworkMessage(
                type: .profile,
                payload: profileData,
                timestamp: Date()
            )
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: [peer], with: .reliable)
            log("📤 Sent profile to \(peer.displayName)")
        } catch {
            log("❌ Failed to send profile: \(error.localizedDescription)")
        }
    }

    deinit {
        stopDetection()
    }
}

// MARK: - CLLocationManagerDelegate

extension RoomDetectionManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying beaconConstraint: CLBeaconIdentityConstraint) {
        for beacon in beacons {
          let userId = majorToUserId(UInt16(truncating: beacon.major))

            // Skip our own beacon
            if userId == userProfile.id {
                continue
            }

            // Update or create detected peer
            if var peer = detectedPeers[userId] {
                peer.proximity = beacon.proximity
                peer.lastSeen = Date()
                detectedPeers[userId] = peer
            } else {
                let peer = DetectedPeer(id: userId, proximity: beacon.proximity)
                detectedPeers[userId] = peer
                log("👋 Detected new peer: \(userId.prefix(8))... (\(peer.proximityText))")
            }
        }

        notifyPeersUpdated()
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        log("📍 Entered beacon region")
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        log("📍 Exited beacon region")
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension RoomDetectionManager: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Extract peer's userId from their peerID displayName
        let peerId = peerID.displayName

        // Check if we've detected their beacon
        if detectedPeers[peerId] != nil {
            log("✅ Accepting invitation from detected peer: \(peerId.prefix(8))...")
            invitationHandler(true, session)
        } else {
            log("❌ Rejecting invitation from undetected peer: \(peerId.prefix(8))...")
            invitationHandler(false, nil)
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension RoomDetectionManager: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let peerId = info?["userId"] ?? peerID.displayName

        log("🔍 Found Multipeer peer: \(peerId.prefix(8))...")

        // Only invite if we've detected their beacon
        if var peer = detectedPeers[peerId] {
            log("✅ Peer's beacon detected, sending invitation...")
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)

            // Store MCPeerID for later use
            peer.peerID = peerID
            detectedPeers[peerId] = peer
        } else {
            log("⏳ Peer's beacon not detected yet, skipping invitation")
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        let peerId = peerID.displayName
        log("👋 Lost Multipeer peer: \(peerId.prefix(8))...")
    }
}

// MARK: - MCSessionDelegate

extension RoomDetectionManager: MCSessionDelegate {

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let peerId = peerID.displayName

        switch state {
        case .connected:
            log("🤝 Connected to peer: \(peerId.prefix(8))...")

            // Update peer connection status
            if var peer = detectedPeers[peerId] {
                peer.isConnected = true
                peer.peerID = peerID
                detectedPeers[peerId] = peer
                notifyPeersUpdated()

                // Send our profile
                sendProfile(to: peerID)
            }

        case .connecting:
            log("🔄 Connecting to peer: \(peerId.prefix(8))...")

        case .notConnected:
            log("💔 Disconnected from peer: \(peerId.prefix(8))...")

            // Update peer connection status
            if var peer = detectedPeers[peerId] {
                peer.isConnected = false
                detectedPeers[peerId] = peer
                notifyPeersUpdated()
            }

        @unknown default:
            break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(NetworkMessage.self, from: data)

            switch message.type {
            case .profile:
                let profile = try UserProfile.decode(from: message.payload)
                log("📥 Received profile from \(profile.displayName)")

                // Update peer with profile
                if var peer = detectedPeers[profile.id] {
                    peer.profile = profile
                    detectedPeers[profile.id] = peer
                    notifyPeersUpdated()
                }

            case .message:
                if let text = String(data: message.payload, encoding: .utf8) {
                    log("💬 Received message: \"\(text)\"")
                }

            case .heartbeat:
                // Handle heartbeat if needed
                break
            }
        } catch {
            log("❌ Failed to decode message: \(error.localizedDescription)")
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used in this POC
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Not used in this POC
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Not used in this POC
    }
}

// MARK: - Network Message Model

struct NetworkMessage: Codable {
    enum MessageType: String, Codable {
        case profile
        case message
        case heartbeat
    }

    let type: MessageType
    let payload: Data
    let timestamp: Date
}
