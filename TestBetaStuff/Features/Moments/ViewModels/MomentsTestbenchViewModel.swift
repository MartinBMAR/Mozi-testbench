import Foundation
import SwiftUI
import Combine
import Photos

// MARK: - Photo Library Access Status

enum PhotoLibraryAccessStatus {
    case authorized
    case limited
    case denied
    case notDetermined
}

// MARK: - Photo Asset Wrapper

struct PhotoAsset: Identifiable {
    let id: String
    let asset: PHAsset
    let creationDate: Date?

    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.creationDate = asset.creationDate
    }
}

/// ViewModel for Moments Testbench - experimental feature playground
@MainActor
class MomentsTestbenchViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var logs: [TestbenchLog] = []
    @Published var isExperimentRunning: Bool = false
    @Published var experimentResult: String = ""

    // Photo Library
    @Published var photoAccessStatus: PhotoLibraryAccessStatus = .notDetermined
    @Published var recentPhotos: [PhotoAsset] = []
    @Published var isLoadingPhotos: Bool = false
    @Published var thumbnails: [String: UIImage] = [:]

    // MARK: - Private Properties

    private let maxLogs = 50
    private var cancellables = Set<AnyCancellable>()
    private let imageManager = PHCachingImageManager()
    private let thumbnailSize = CGSize(width: 200, height: 200)

    // MARK: - Initialization

    init() {
        addLog("Testbench initialized")
        checkCurrentPhotoStatus()
    }

    // MARK: - Photo Library Methods

    /// Check current photo library authorization status without prompting
    func checkCurrentPhotoStatus() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized:
            photoAccessStatus = .authorized
        case .limited:
            photoAccessStatus = .limited
        case .denied, .restricted:
            photoAccessStatus = .denied
        case .notDetermined:
            photoAccessStatus = .notDetermined
        @unknown default:
            photoAccessStatus = .denied
        }
        addLog("📷 Current photo access: \(photoAccessStatusText)")
    }

    /// Request photo library access
    func checkPhotoLibraryAccess() async -> PhotoLibraryAccessStatus {
        addLog("📷 Requesting photo library access...")
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        switch status {
        case .authorized:
            photoAccessStatus = .authorized
            addLog("✅ Photo access authorized")
            return .authorized
        case .limited:
            photoAccessStatus = .limited
            addLog("⚠️ Photo access limited")
            return .limited
        case .denied, .restricted:
            photoAccessStatus = .denied
            addLog("❌ Photo access denied")
            return .denied
        case .notDetermined:
            photoAccessStatus = .notDetermined
            addLog("❓ Photo access not determined")
            return .notDetermined
        @unknown default:
            photoAccessStatus = .denied
            addLog("❌ Photo access denied (unknown)")
            return .denied
        }
    }

    /// Fetch photos from the last N days
    func fetchRecentPhotos(days: Int = 7) async {
        isLoadingPhotos = true
        recentPhotos = []
        thumbnails = [:]
        addLog("🔍 Fetching photos from last \(days) days...")

        let status = await checkPhotoLibraryAccess()
        guard status == .authorized || status == .limited else {
            addLog("❌ Cannot fetch photos - access not granted")
            isLoadingPhotos = false
            return
        }

        let calendar = Calendar.current
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            addLog("❌ Failed to calculate start date")
            isLoadingPhotos = false
            return
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "creationDate >= %@ AND mediaType == %d",
            startDate as NSDate,
            PHAssetMediaType.image.rawValue
        )
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
        let count = fetchResult.count
        addLog("📸 Found \(count) photos")

        var assets: [PhotoAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(PhotoAsset(asset: asset))
        }

        recentPhotos = assets
        isLoadingPhotos = false

        // Load thumbnails for visible photos
        await loadThumbnails(for: assets)
    }

    /// Load thumbnails for photo assets
    func loadThumbnails(for assets: [PhotoAsset]) async {
        addLog("🖼️ Loading thumbnails...")

        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast
        options.isSynchronous = false

        for photoAsset in assets {
            await loadThumbnail(for: photoAsset, options: options)
        }

        addLog("✅ Thumbnails loaded")
    }

    /// Load a single thumbnail
    private func loadThumbnail(for photoAsset: PhotoAsset, options: PHImageRequestOptions) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            imageManager.requestImage(
                for: photoAsset.asset,
                targetSize: thumbnailSize,
                contentMode: .aspectFill,
                options: options
            ) { [weak self] image, _ in
                if let image = image {
                    Task { @MainActor in
                        self?.thumbnails[photoAsset.id] = image
                    }
                }
                continuation.resume()
            }
        }
    }

    var photoAccessStatusText: String {
        switch photoAccessStatus {
        case .authorized:
            return "Authorized"
        case .limited:
            return "Limited"
        case .denied:
            return "Denied"
        case .notDetermined:
            return "Not Determined"
        }
    }

    // MARK: - Experiment Methods

    /// Run an experimental feature test
    func runExperiment() {
        guard !isExperimentRunning else { return }

        isExperimentRunning = true
        experimentResult = ""
        addLog("🧪 Starting experiment...")

        // Simulate async experiment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.experimentResult = "Experiment completed successfully"
            self?.addLog("✅ Experiment finished")
            self?.isExperimentRunning = false
        }
    }

    /// Reset the testbench state
    func reset() {
        isExperimentRunning = false
        experimentResult = ""
        recentPhotos = []
        thumbnails = [:]
        addLog("🔄 Testbench reset")
    }

    /// Clear all logs
    func clearLogs() {
        logs.removeAll()
    }

    /// Add a custom log entry
    func addLog(_ message: String) {
        let entry = TestbenchLog(message: message)
        logs.insert(entry, at: 0)

        if logs.count > maxLogs {
            logs = Array(logs.prefix(maxLogs))
        }
    }
}

// MARK: - Testbench Log Model

struct TestbenchLog: Identifiable {
    let id = UUID()
    let message: String
    let timestamp: Date

    init(message: String, timestamp: Date = Date()) {
        self.message = message
        self.timestamp = timestamp
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}
