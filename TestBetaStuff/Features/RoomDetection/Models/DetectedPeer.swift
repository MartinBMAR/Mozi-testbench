import Foundation
import CoreLocation
import MultipeerConnectivity

/// Represents a detected peer in the room
struct DetectedPeer: Identifiable {
    let id: String                      // User ID from beacon
    var profile: UserProfile?           // Profile received via Multipeer
    var proximity: CLProximity          // iBeacon proximity
    var lastSeen: Date                  // Last time beacon was detected
    var isConnected: Bool               // Multipeer connection status
    var peerID: MCPeerID?               // Multipeer peer identifier

    init(id: String, proximity: CLProximity = .unknown, lastSeen: Date = Date()) {
        self.id = id
        self.proximity = proximity
        self.lastSeen = lastSeen
        self.isConnected = false
    }

    /// Display name (uses profile name if available, otherwise ID)
    var displayName: String {
        profile?.displayName ?? "User \(id.prefix(8))"
    }

    /// Proximity as a human-readable string
    var proximityText: String {
        switch proximity {
        case .immediate:
            return "Very Close"
        case .near:
            return "Near"
        case .far:
            return "Far"
        case .unknown:
            return "Unknown"
        @unknown default:
            return "Unknown"
        }
    }

    /// Color representing proximity
    var proximityColor: String {
        switch proximity {
        case .immediate:
            return "green"
        case .near:
            return "blue"
        case .far:
            return "orange"
        case .unknown:
            return "gray"
        @unknown default:
            return "gray"
        }
    }

    /// Time since last seen (for display)
    var timeSinceLastSeen: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSeen, relativeTo: Date())
    }
}
