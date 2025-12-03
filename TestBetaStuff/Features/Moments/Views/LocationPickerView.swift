import CoreLocation
import MapKit
import SwiftUI

struct LocationPickerView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var locationManager: LocationManager

  @Binding var selectedLocation: CLLocation?
  @Binding var selectedLocationName: String?

  @State private var cameraPosition: MapCameraPosition = .automatic
  @State private var selectedCoordinate: CLLocationCoordinate2D?
  @State private var isLoadingName: Bool = false


  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Map
        mapView

        Divider()

        // Selection info and actions
        bottomPanel
      }
      .navigationTitle("Select Location")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            if let coordinate = selectedCoordinate {
              selectedLocation = CLLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
              )
            }
            dismiss()
          }
          .fontWeight(.semibold)
          .disabled(selectedCoordinate == nil)
        }
      }
      .onAppear {
        setupInitialPosition()
      }
    }
  }

  // MARK: - Map View

  private var mapView: some View {
    MapReader { proxy in
      Map(position: $cameraPosition) {
        // Show selected location marker
        if let coordinate = selectedCoordinate {
          Marker("Selected", coordinate: coordinate)
            .tint(.blue)
        }

        // Show user location if available
        if let userLocation = locationManager.rawLocation {
          Marker("You", systemImage: "person.fill", coordinate: userLocation.coordinate)
            .tint(.green)
        }
      }
      .mapControls {
        MapUserLocationButton()
        MapCompass()
        MapScaleView()
      }
      .onTapGesture { position in
        if let coordinate = proxy.convert(position, from: .local) {
          selectLocation(at: coordinate)
        }
      }
    }
  }

  // MARK: - Bottom Panel

  private var bottomPanel: some View {
    VStack(spacing: 12) {
      // Use current location button
      Button {
        useCurrentLocation()
      } label: {
        HStack {
          Image(systemName: "location.fill")
          Text("Use Current Location")
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(locationManager.isAuthorized ? Color.blue : Color.gray)
        .cornerRadius(10)
      }
      .disabled(!locationManager.isAuthorized)

      // Selected location info
      if let coordinate = selectedCoordinate {
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Image(systemName: "mappin.circle.fill")
              .foregroundColor(.blue)

            if isLoadingName {
              ProgressView()
                .scaleEffect(0.7)
            } else if let name = selectedLocationName {
              Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
            } else {
              Text("Selected Location")
                .font(.subheadline)
                .fontWeight(.medium)
            }

            Spacer()
          }

          Text(String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude))
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.leading, 24)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
      } else {
        Text("Tap on the map to select a location")
          .font(.subheadline)
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color(.systemGray6))
          .cornerRadius(10)
      }
    }
    .padding()
  }

  // MARK: - Methods

  private func setupInitialPosition() {
    // If we have a previously selected location, center on it
    if let selected = selectedLocation {
      cameraPosition = .region(
        MKCoordinateRegion(
          center: selected.coordinate,
          span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
      )
      selectedCoordinate = selected.coordinate
    }
    // Otherwise, center on user location if available
    else if let userLocation = locationManager.rawLocation {
      cameraPosition = .region(
        MKCoordinateRegion(
          center: userLocation.coordinate,
          span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
      )
    }
    // Request location if authorized but no location yet
    else if locationManager.isAuthorized {
      locationManager.requestLocation()
    }
  }

  private func selectLocation(at coordinate: CLLocationCoordinate2D) {
    selectedCoordinate = coordinate
    selectedLocationName = nil
    isLoadingName = true

    // Reverse geocode to get location name
    locationManager.reverseGeocode(coordinate: coordinate) { name in
      DispatchQueue.main.async {
        self.selectedLocationName = name
        self.isLoadingName = false
      }
    }
  }

  private func useCurrentLocation() {
    guard let location = locationManager.rawLocation else {
      locationManager.requestLocation()
      return
    }

    selectedCoordinate = location.coordinate
    cameraPosition = .region(
      MKCoordinateRegion(
        center: location.coordinate,
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
      )
    )

    // Use existing location name if available
    if let noteLocation = locationManager.currentLocation {
      selectedLocationName = noteLocation.cityName
    } else {
      selectLocation(at: location.coordinate)
    }
  }
}
