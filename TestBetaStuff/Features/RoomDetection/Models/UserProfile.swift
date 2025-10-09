import Foundation
import UIKit

/// Represents a user's profile for room detection
struct UserProfile: Codable, Identifiable {
    let id: String          // UUID string
    let displayName: String
    let joinedAt: Date

    init(id: String = UUID().uuidString, displayName: String, joinedAt: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.joinedAt = joinedAt
    }

    /// Create a default profile with random ID
    static func createDefault() -> UserProfile {
        let deviceName = UIDevice.current.name
        return UserProfile(displayName: deviceName)
    }
}

/// Extension for encoding/decoding for network transmission
extension UserProfile {
    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> UserProfile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UserProfile.self, from: data)
    }
}
