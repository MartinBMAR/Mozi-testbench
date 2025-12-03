import Combine
import CoreLocation
import Foundation
import Photos
import SwiftUI

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

  /// Location where the photo was taken (if available)
  var location: CLLocation? {
    asset.location
  }

  /// Whether this photo has location metadata
  var hasLocation: Bool {
    asset.location != nil
  }

  init(asset: PHAsset) {
    self.id = asset.localIdentifier
    self.asset = asset
    self.creationDate = asset.creationDate
  }

  /// Calculate distance from a reference location in meters
  func distance(from referenceLocation: CLLocation) -> Double? {
    guard let photoLocation = location else { return nil }
    return photoLocation.distance(from: referenceLocation)
  }

  /// Get formatted distance string
  func formattedDistance(from referenceLocation: CLLocation) -> String? {
    guard let distance = distance(from: referenceLocation) else { return nil }
    if distance < 1000 {
      return String(format: "%.0fm", distance)
    } else {
      return String(format: "%.1fkm", distance / 1000)
    }
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

  // Location Comparison
  @Published var referenceLocation: CLLocation?
  @Published var referenceLocationName: String?
  @Published var filterRadius: Double = 5000  // meters (default 5km)
  @Published var isLocationFilterEnabled: Bool = false

  // MARK: - Computed Properties

  /// Available radius options in meters
  static let radiusOptions: [(label: String, value: Double)] = [
    ("500m", 500),
    ("1km", 1000),
    ("5km", 5000),
    ("10km", 10000),
    ("50km", 50000),
  ]

  /// Photos filtered by location (if filter is enabled)
  var filteredPhotos: [PhotoAsset] {
    guard isLocationFilterEnabled, let reference = referenceLocation else {
      return recentPhotos
    }

    return recentPhotos.filter { photo in
      guard let distance = photo.distance(from: reference) else {
        return false  // Exclude photos without location when filtering
      }
      return distance <= filterRadius
    }
  }

  /// Count of photos with location metadata
  var photosWithLocationCount: Int {
    recentPhotos.filter { $0.hasLocation }.count
  }

  /// Count of photos without location metadata
  var photosWithoutLocationCount: Int {
    recentPhotos.filter { !$0.hasLocation }.count
  }

  /// Formatted filter radius string
  var formattedFilterRadius: String {
    if filterRadius < 1000 {
      return String(format: "%.0fm", filterRadius)
    } else {
      return String(format: "%.0fkm", filterRadius / 1000)
    }
  }

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

  // MARK: - Location Methods

  /// Set reference location from user's current location
  func setReferenceFromCurrentLocation(_ location: CLLocation, name: String?) {
    referenceLocation = location
    referenceLocationName = name
    addLog("📍 Reference set to current location: \(name ?? "Unknown")")
    logLocationStats()
  }

  /// Set reference location from map selection
  func setReferenceFromMapSelection(_ location: CLLocation, name: String?) {
    referenceLocation = location
    referenceLocationName = name
    addLog("📍 Reference set from map: \(name ?? "Unknown")")
    logLocationStats()
  }

  /// Clear reference location
  func clearReferenceLocation() {
    referenceLocation = nil
    referenceLocationName = nil
    isLocationFilterEnabled = false
    addLog("📍 Reference location cleared")
  }

  /// Toggle location filter
  func toggleLocationFilter() {
    guard referenceLocation != nil else {
      addLog("⚠️ Set a reference location first")
      return
    }
    isLocationFilterEnabled.toggle()
    addLog("🔍 Location filter \(isLocationFilterEnabled ? "enabled" : "disabled") (radius: \(formattedFilterRadius))")
    if isLocationFilterEnabled {
      addLog("📊 Showing \(filteredPhotos.count) of \(recentPhotos.count) photos")
    }
  }

  /// Update filter radius
  func setFilterRadius(_ radius: Double) {
    filterRadius = radius
    addLog("📏 Filter radius set to \(formattedFilterRadius)")
    if isLocationFilterEnabled {
      addLog("📊 Showing \(filteredPhotos.count) of \(recentPhotos.count) photos")
    }
  }

  /// Log location statistics
  private func logLocationStats() {
    guard !recentPhotos.isEmpty else { return }
    addLog("📊 Photos with location: \(photosWithLocationCount)/\(recentPhotos.count)")
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
    referenceLocation = nil
    referenceLocationName = nil
    isLocationFilterEnabled = false
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
