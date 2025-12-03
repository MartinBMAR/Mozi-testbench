import SwiftUI

#if canImport(JournalingSuggestions)
  import JournalingSuggestions
#endif

struct Suggestions: View {
  var body: some View {
    VStack {
      #if canImport(JournalingSuggestions)
        // JournalingSuggestions is only available on physical devices
          JournalingSuggestionsPicker {
            Text("Get suggestions")
          } onCompletion: { suggestion in
            // Handle the selected suggestion
            print("Selected suggestion: \(suggestion)")
          }
      #else
        // Fallback for simulator or when framework is not available
        Text("Journaling suggestions are only available on device")
          .foregroundColor(.secondary)
      #endif
    }
  }
}
