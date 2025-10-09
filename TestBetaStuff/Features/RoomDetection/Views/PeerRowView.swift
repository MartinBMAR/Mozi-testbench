import SwiftUI
import CoreLocation

struct PeerRowView: View {
    let peer: DetectedPeer

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(peer.isConnected ? Color.green : Color.orange)
                .frame(width: 10, height: 10)

            // User info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(peer.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if peer.isConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                HStack(spacing: 8) {
                    // Proximity indicator
                    HStack(spacing: 4) {
                        Image(systemName: proximityIcon)
                            .font(.caption2)
                        Text(peer.proximityText)
                            .font(.caption2)
                    }
                    .foregroundColor(proximityColor)

                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    // Last seen
                    Text(peer.timeSinceLastSeen)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }

            Spacer()

            // Connection badge
            if peer.isConnected {
                Text("Connected")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .cornerRadius(6)
            } else {
                Text("Detected")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    // MARK: - Computed Properties

    private var proximityIcon: String {
        switch peer.proximity {
        case .immediate:
            return "circle.fill"
        case .near:
            return "circle.lefthalf.filled"
        case .far:
            return "circle"
        case .unknown:
            return "questionmark.circle"
        @unknown default:
            return "questionmark.circle"
        }
    }

    private var proximityColor: Color {
        switch peer.proximity {
        case .immediate:
            return .green
        case .near:
            return .blue
        case .far:
            return .orange
        case .unknown:
            return .gray
        @unknown default:
            return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        PeerRowView(peer: DetectedPeer(
            id: "123",
            proximity: .immediate,
            lastSeen: Date()
        ))

        PeerRowView(peer: {
            var peer = DetectedPeer(id: "456", proximity: .near)
            peer.profile = UserProfile(id: "456", displayName: "John Doe")
            peer.isConnected = true
            return peer
        }())

        PeerRowView(peer: {
            var peer = DetectedPeer(id: "789", proximity: .far)
            peer.profile = UserProfile(id: "789", displayName: "Jane Smith")
            return peer
        }())
    }
    .padding()
}
