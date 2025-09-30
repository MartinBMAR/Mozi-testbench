import Foundation
import CoreLocation

struct NoteLocation: Codable {
  let latitude: Double
  let longitude: Double
  let cityName: String?

  init(latitude: Double, longitude: Double, cityName: String? = nil) {
    self.latitude = latitude
    self.longitude = longitude
    self.cityName = cityName
  }

  init(coordinate: CLLocationCoordinate2D, cityName: String? = nil) {
    self.latitude = coordinate.latitude
    self.longitude = coordinate.longitude
    self.cityName = cityName
  }
}