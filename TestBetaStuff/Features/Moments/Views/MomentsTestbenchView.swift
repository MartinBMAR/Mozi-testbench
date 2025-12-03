import SwiftUI

struct MomentsTestbenchView: View {
  @StateObject private var viewModel = MomentsTestbenchViewModel()
  @State private var logsHidden = false

  private let columns = [
    GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 4)
  ]

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        // Status Header
        statusHeader

        Divider()

        // Photo Library Section
        photoLibrarySection

        Divider()

        // Logs Section
        logsSection
      }
      .navigationTitle("Moments Testbench")
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
    }
  }

  // MARK: - Status Header

  private var statusHeader: some View {
    HStack {
      Circle()
        .fill(statusColor)
        .frame(width: 12, height: 12)

      Text(viewModel.isLoadingPhotos ? "Loading" : "Ready")
        .font(.headline)
        .foregroundColor(statusColor)

      Spacer()

      Text("Experimental")
        .font(.caption)
        .fontWeight(.semibold)
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.purple)
        .cornerRadius(8)
    }
    .padding()
  }

  private var statusColor: Color {
    if viewModel.isLoadingPhotos {
      return .orange
    }
    return .green
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
          await viewModel.fetchRecentPhotos(days: 7)
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
          Text("Fetch Photos (Last 7 Days)")
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
        ForEach(viewModel.recentPhotos) { photo in
          PhotoThumbnailView(
            photo: photo,
            thumbnail: viewModel.thumbnails[photo.id]
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

// MARK: - Photo Thumbnail View

struct PhotoThumbnailView: View {
  let photo: PhotoAsset
  let thumbnail: UIImage?

  var body: some View {
    ZStack {
      if let thumbnail = thumbnail {
        Image(uiImage: thumbnail)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 100, height: 100)
          .clipped()
      } else {
        Rectangle()
          .fill(Color(.systemGray5))
          .frame(width: 100, height: 100)
          .overlay(
            ProgressView()
              .scaleEffect(0.6)
          )
      }
    }
    .cornerRadius(4)
  }
}

// MARK: - Preview

#Preview {
  MomentsTestbenchView()
}
