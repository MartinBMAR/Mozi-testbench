import SwiftUI

@main
struct TestBetaStuffApp: App {
  var body: some Scene {
    WindowGroup {
      LLMView()
        .tabItem {
          Label("LLM", systemImage: "brain.head.profile")
        }
    }
  }
}
