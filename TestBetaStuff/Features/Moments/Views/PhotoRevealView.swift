import SwiftUI

struct PhotoRevealView: View {
  @StateObject private var viewModel = PhotoRevealViewModel()

  var body: some View {
    Text("Photo Reveal")
      .navigationTitle("Photo Reveal")
      .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationView {
    PhotoRevealView()
  }
}
