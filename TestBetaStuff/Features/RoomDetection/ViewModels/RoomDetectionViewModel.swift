import Foundation
import SwiftUI
import Combine

/// ViewModel for Room Detection feature
class RoomDetectionViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var userProfile: UserProfile
    @Published var detectedPeers: [DetectedPeer] = []
    @Published var isActive: Bool = false
    @Published var logs: [LogEntry] = []
    @Published var messageText: String = ""

    // MARK: - Private Properties

    private var manager: RoomDetectionManager?
    private let userDefaultsKey = "com.testbeta.userProfile"
    private let maxLogs = 100

    // MARK: - Initialization

    init() {
        // Load or create user profile
        if let savedProfile = Self.loadUserProfile() {
            self.userProfile = savedProfile
        } else {
            self.userProfile = UserProfile.createDefault()
            Self.saveUserProfile(userProfile)
        }
    }

    // MARK: - Public Methods

    /// Toggle room detection on/off
    func toggleDetection() {
        if isActive {
            stopDetection()
        } else {
            startDetection()
        }
    }

    /// Start room detection
    func startDetection() {
        guard !isActive else { return }

        // Create manager if needed
        if manager == nil {
            manager = RoomDetectionManager(userProfile: userProfile)
            setupManagerCallbacks()
        }

        // Start detection
        manager?.startDetection()
        isActive = true
        addLog("✅ Room detection started")
    }

    /// Stop room detection
    func stopDetection() {
        guard isActive else { return }

        manager?.stopDetection()
        isActive = false
        detectedPeers.removeAll()
        addLog("🛑 Room detection stopped")
    }

    /// Send test message to all connected peers
    func sendTestMessage() {
        guard !messageText.isEmpty else { return }

        manager?.sendMessage(messageText)
        addLog("📤 Sent: \"\(messageText)\"")
        messageText = ""
    }

    /// Update user profile
    func updateProfile(displayName: String) {
        userProfile = UserProfile(
            id: userProfile.id,
            displayName: displayName,
            joinedAt: userProfile.joinedAt
        )
        Self.saveUserProfile(userProfile)

        // Restart detection if active to broadcast new profile
        if isActive {
            stopDetection()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startDetection()
            }
        }

        addLog("✏️ Profile updated: \(displayName)")
    }

    /// Clear logs
    func clearLogs() {
        logs.removeAll()
    }

    // MARK: - Private Methods

    private func setupManagerCallbacks() {
        manager?.onPeersUpdated = { [weak self] peers in
            self?.detectedPeers = peers
        }

        manager?.onLog = { [weak self] message in
            self?.addLog(message)
        }
    }

    private func addLog(_ message: String) {
        let entry = LogEntry(message: message)
        logs.insert(entry, at: 0)

        // Keep only last N logs
        if logs.count > maxLogs {
            logs = Array(logs.prefix(maxLogs))
        }
    }

    // MARK: - User Defaults Persistence

    private static func saveUserProfile(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "com.testbeta.userProfile")
        }
    }

    private static func loadUserProfile() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: "com.testbeta.userProfile") else {
            return nil
        }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }
}

// MARK: - Log Entry Model

struct LogEntry: Identifiable {
    let id = UUID()
    let message: String
    let timestamp: Date

    init(message: String, timestamp: Date = Date()) {
        self.message = message
        self.timestamp = timestamp
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}
