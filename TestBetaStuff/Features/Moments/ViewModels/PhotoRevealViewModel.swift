import Combine
import Foundation

@MainActor
class PhotoRevealViewModel: ObservableObject {
  @Published var isLoading = false
}
