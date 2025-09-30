import Foundation
import FoundationModels

@Generable(description: "Basic information about a trip")
public struct TripModel: Identifiable {
  public var id: String

  @Guide(description: "the country of the trip")
  public var country: String

  @Guide(description: "a list of cities from the country that are worth visiting")
  public var cities: [String]
  
  public init(country: String, cities: [String]) {
    self.id = UUID().uuidString
    self.country = country
    self.cities = cities
  }
}
