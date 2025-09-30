import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
  // MARK: - Published Properties
  @Published var currentLocation: NoteLocation?
  @Published var isAuthorized: Bool = false
  @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

  // MARK: - Private Properties
  private let locationManager = CLLocationManager()
  private let geocoder = CLGeocoder()

  // MARK: - Initialization
  override init() {
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    checkAuthorizationStatus()
  }

  // MARK: - Authorization
  func checkAuthorizationStatus() {
    let status = locationManager.authorizationStatus
    authorizationStatus = status

    switch status {
    case .authorizedWhenInUse, .authorizedAlways:
      isAuthorized = true
    case .denied, .restricted:
      isAuthorized = false
    case .notDetermined:
      isAuthorized = false
    @unknown default:
      isAuthorized = false
    }
  }

  func requestAuthorization() {
    let status = locationManager.authorizationStatus

    if status == .notDetermined {
      locationManager.requestWhenInUseAuthorization()
    }
  }

  // MARK: - Location Request
  func requestLocation() {
    guard isAuthorized else {
      print("⚠️ Location not authorized")
      requestAuthorization()
      return
    }

    print("📍 Requesting location...")
    locationManager.requestLocation()
  }

  // MARK: - Reverse Geocoding
  private func reverseGeocodeLocation(_ location: CLLocation) {
    geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
      guard let self = self else { return }

      if let error = error {
        print("❌ Geocoding error: \(error.localizedDescription)")
        // Still save location without city name
        let noteLocation = NoteLocation(
          coordinate: location.coordinate,
          cityName: nil
        )
        DispatchQueue.main.async {
          self.currentLocation = noteLocation
        }
        return
      }

      if let placemark = placemarks?.first {
        let cityName = self.formatPlacemark(placemark)
        let noteLocation = NoteLocation(
          coordinate: location.coordinate,
          cityName: cityName
        )

        DispatchQueue.main.async {
          self.currentLocation = noteLocation
          print("✓ Location: \(cityName ?? "Unknown")")
        }
      }
    }
  }

  private func formatPlacemark(_ placemark: CLPlacemark) -> String {
    var components: [String] = []

    if let city = placemark.locality {
      components.append(city)
    }

    if let state = placemark.administrativeArea {
      components.append(state)
    }

    if let country = placemark.country {
      components.append(country)
    }

    return components.isEmpty ? "Unknown Location" : components.joined(separator: ", ")
  }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    print("📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    reverseGeocodeLocation(location)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    print("❌ Location error: \(error.localizedDescription)")
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    checkAuthorizationStatus()
    print("📍 Authorization status changed: \(authorizationStatus.rawValue)")
  }
}