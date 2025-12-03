import SwiftUI

@main
struct TestBetaStuffApp: App {
  var body: some Scene {
    WindowGroup {
      TabView {
        LLMView()
          .tabItem {
            Label("LLM", systemImage: "brain.head.profile")
          }

        RoomDetectionView()
          .tabItem {
            Label("Room Detection", systemImage: "antenna.radiowaves.left.and.right")
          }
        
        Suggestions()
          .tabItem {
            Label("Suggestions", systemImage: "antenna.radiowaves.left.and.right")
          }
      }
    }
  }
}
