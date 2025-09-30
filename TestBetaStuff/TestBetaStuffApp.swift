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

        NoteListView()
          .tabItem {
            Label("Notes", systemImage: "note.text")
          }
      }
    }
  }
}
