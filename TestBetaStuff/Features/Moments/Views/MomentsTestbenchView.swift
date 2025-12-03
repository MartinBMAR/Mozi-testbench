import CoreLocation
import SwiftUI

struct MomentsTestbenchView: View {
  var body: some View {
    NavigationView {
      List {
        NavigationLink("Photo Processing") {
          PhotoProcessingView()
        }
        NavigationLink("Photo Reveal") {
          PhotoRevealView()
        }
      }
      .navigationTitle("Moments Testbench")
    }
  }
}

// MARK: - Photo Thumbnail View

struct PhotoThumbnailView: View {
  let photo: PhotoAsset
  let thumbnail: UIImage?
  var referenceLocation: CLLocation?

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
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

      // Distance badge
      if let reference = referenceLocation,
        let distance = photo.formattedDistance(from: reference)
      {
        Text(distance)
          .font(.system(size: 9, weight: .semibold))
          .foregroundColor(.white)
          .padding(.horizontal, 4)
          .padding(.vertical, 2)
          .background(Color.black.opacity(0.7))
          .cornerRadius(4)
          .padding(4)
      }

      // No location indicator
      if referenceLocation != nil && !photo.hasLocation {
        Image(systemName: "location.slash.fill")
          .font(.system(size: 10))
          .foregroundColor(.white)
          .padding(4)
          .background(Color.orange.opacity(0.8))
          .cornerRadius(4)
          .padding(4)
      }
    }
    .cornerRadius(4)
  }
}

// MARK: - Preview

#Preview {
  MomentsTestbenchView()
}
