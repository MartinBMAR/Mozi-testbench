import CoreLocation
import SwiftUI

struct PhotoProcessingView: View {
  @StateObject private var viewModel = MomentsTestbenchViewModel()
  @StateObject private var locationManager = LocationManager()
  @State private var logsHidden = false
  @State private var showLocationPicker = false
  @State private var selectedMapLocation: CLLocation?
  @State private var selectedMapLocationName: String?

  private let columns = [
    GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 4)
  ]

  var body: some View {
    VStack(spacing: 0) {
      photoLibrarySection
      Divider()
      locationComparisonSection
      Divider()
      logsSection
    }
    .navigationTitle("Photo Processing")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button {
          viewModel.reset()
        } label: {
          Image(systemName: "arrow.counterclockwise")
        }
      }
    }
    .sheet(isPresented: $showLocationPicker) {
      LocationPickerView(
        locationManager: locationManager,
        selectedLocation: $selectedMapLocation,
        selectedLocationName: $selectedMapLocationName
      )
    }
    .onChange(of: selectedMapLocation) { _, newLocation in
      if let location = newLocation {
        viewModel.setReferenceFromMapSelection(location, name: selectedMapLocationName)
      }
    }
    .onAppear {
      locationManager.requestAuthorization()
    }
  }

  // MARK: - Photo Library Section

  private var photoLibrarySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Photo Library")
          .font(.headline)

        Spacer()

        // Access status badge
        Text(viewModel.photoAccessStatusText)
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundColor(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(accessStatusColor)
          .cornerRadius(8)
      }
      .padding(.horizontal)
      .padding(.top, 12)

      // Fetch button
      Button {
        Task {
          await viewModel.fetchRecentPhotos(days: 30)
        }
      } label: {
        HStack {
          if viewModel.isLoadingPhotos {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .white))
              .scaleEffect(0.8)
          } else {
            Image(systemName: "photo.on.rectangle.angled")
          }
          Text("Fetch Photos (Last 30 Days)")
        }
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(viewModel.isLoadingPhotos ? Color.gray : Color.blue)
        .cornerRadius(10)
      }
      .disabled(viewModel.isLoadingPhotos)
      .padding(.horizontal)

      // Photo count
      if !viewModel.recentPhotos.isEmpty {
        Text("\(viewModel.recentPhotos.count) photos found")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.horizontal)
      }

      // Photo grid
      if viewModel.recentPhotos.isEmpty && !viewModel.isLoadingPhotos {
        emptyPhotoView
      } else {
        photoGrid
      }
    }
  }

  private var accessStatusColor: Color {
    switch viewModel.photoAccessStatus {
    case .authorized:
      return .green
    case .limited:
      return .orange
    case .denied:
      return .red
    case .notDetermined:
      return .gray
    }
  }

  // MARK: - Location Comparison Section

  private var locationComparisonSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Location Comparison")
          .font(.headline)

        Spacer()

        // Location stats badge
        if !viewModel.recentPhotos.isEmpty {
          Text("\(viewModel.photosWithLocationCount)/\(viewModel.recentPhotos.count) with location")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .padding(.horizontal)
      .padding(.top, 12)

      // Reference location controls
      HStack(spacing: 8) {
        // Use current location button
        Button {
          useCurrentLocation()
        } label: {
          HStack {
            Image(systemName: "location.fill")
            Text("Current")
          }
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundColor(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(locationManager.isAuthorized ? Color.blue : Color.gray)
          .cornerRadius(8)
        }
        .disabled(!locationManager.isAuthorized)

        // Pick on map button
        Button {
          showLocationPicker = true
        } label: {
          HStack {
            Image(systemName: "map")
            Text("Pick on Map")
          }
          .font(.caption)
          .fontWeight(.semibold)
          .foregroundColor(.white)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color.purple)
          .cornerRadius(8)
        }

        Spacer()

        // Clear button
        if viewModel.referenceLocation != nil {
          Button {
            viewModel.clearReferenceLocation()
            selectedMapLocation = nil
            selectedMapLocationName = nil
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundColor(.secondary)
          }
        }
      }
      .padding(.horizontal)

      // Reference location info
      if let name = viewModel.referenceLocationName {
        HStack {
          Image(systemName: "mappin.circle.fill")
            .foregroundColor(.blue)
          Text(name)
            .font(.subheadline)
          Spacer()
        }
        .padding(.horizontal)
      }

      // Filter controls
      if viewModel.referenceLocation != nil {
        VStack(spacing: 8) {
          // Filter toggle
          HStack {
            Toggle(
              isOn: Binding(
                get: { viewModel.isLocationFilterEnabled },
                set: { _ in viewModel.toggleLocationFilter() }
              )
            ) {
              Text("Filter by radius")
                .font(.subheadline)
            }
          }
          .padding(.horizontal)

          // Radius picker
          if viewModel.isLocationFilterEnabled {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 8) {
                ForEach(MomentsTestbenchViewModel.radiusOptions, id: \.value) { option in
                  Button {
                    viewModel.setFilterRadius(option.value)
                  } label: {
                    Text(option.label)
                      .font(.caption)
                      .fontWeight(.medium)
                      .padding(.horizontal, 12)
                      .padding(.vertical, 6)
                      .background(viewModel.filterRadius == option.value ? Color.blue : Color(.systemGray5))
                      .foregroundColor(viewModel.filterRadius == option.value ? .white : .primary)
                      .cornerRadius(6)
                  }
                }
              }
              .padding(.horizontal)
            }

            // Filtered count
            Text("Showing \(viewModel.filteredPhotos.count) of \(viewModel.recentPhotos.count) photos")
              .font(.caption)
              .foregroundColor(.secondary)
              .padding(.horizontal)
          }
        }
      }

      // Location authorization warning
      if !locationManager.isAuthorized && locationManager.authorizationStatus != .notDetermined {
        HStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.orange)
          Text("Location access denied. Enable in Settings to use current location.")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
      }
    }
    .padding(.bottom, 12)
  }

  private func useCurrentLocation() {
    if let location = locationManager.rawLocation {
      viewModel.setReferenceFromCurrentLocation(location, name: locationManager.currentLocation?.cityName)
    } else {
      locationManager.requestLocation()
      // Try again after a short delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        if let location = locationManager.rawLocation {
          viewModel.setReferenceFromCurrentLocation(location, name: locationManager.currentLocation?.cityName)
        }
      }
    }
  }

  private var emptyPhotoView: some View {
    VStack(spacing: 8) {
      Image(systemName: "photo.stack")
        .font(.system(size: 40))
        .foregroundColor(.secondary)

      Text("No photos loaded")
        .font(.subheadline)
        .foregroundColor(.secondary)

      Text("Tap the button above to fetch recent photos")
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 30)
  }

  private var photoGrid: some View {
    ScrollView {
      LazyVGrid(columns: columns, spacing: 4) {
        ForEach(viewModel.filteredPhotos) { photo in
          PhotoThumbnailView(
            photo: photo,
            thumbnail: viewModel.thumbnails[photo.id],
            referenceLocation: viewModel.referenceLocation
          )
        }
      }
      .padding(.horizontal, 4)
      .padding(.vertical, 8)
    }
    .frame(maxHeight: .infinity)
  }

  // MARK: - Logs Section

  private var logsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Debug Logs")
          .font(.headline)

        Spacer()

        Button(logsHidden ? "Show" : "Hide") {
          withAnimation {
            logsHidden.toggle()
          }
        }
        .font(.caption)
        .foregroundColor(.blue)

        Button("Clear") {
          viewModel.clearLogs()
        }
        .font(.caption)
        .foregroundColor(.blue)
      }
      .padding(.horizontal)
      .padding(.top, 12)

      if !logsHidden {
        ScrollView {
          VStack(alignment: .leading, spacing: 4) {
            ForEach(viewModel.logs) { log in
              HStack(alignment: .top, spacing: 8) {
                Text(log.formattedTime)
                  .font(.system(.caption2, design: .monospaced))
                  .foregroundColor(.secondary)

                Text(log.message)
                  .font(.system(.caption, design: .monospaced))
                  .foregroundColor(.primary)

                Spacer()
              }
              .padding(.horizontal)
              .padding(.vertical, 2)
            }
          }
          .padding(.vertical, 8)
        }
      }
    }
  }
}

#Preview {
  NavigationView {
    PhotoProcessingView()
  }
}
