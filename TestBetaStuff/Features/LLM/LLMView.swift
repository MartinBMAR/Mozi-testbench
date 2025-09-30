import FoundationModels
import SwiftUI

struct LLMView: View {
  @StateObject private var viewModel = LLMViewModel()

  var body: some View {
    VStack(spacing: 16) {
      switch viewModel.availability {
      case .available:
        LLMSessionView(viewModel: viewModel)
      case .unavailable(.deviceNotEligible):
        Text("Device not eligible")
      case .unavailable(.appleIntelligenceNotEnabled):
        Text("Apple Intelligence not enabled")
      case .unavailable(.modelNotReady):
        Text("Model not ready")
      case .unavailable(let other):
        Text("Unavailable: \(String(describing: other))")
      case .none:
        Text("None")
      }
    }
    .padding(16)
    .onAppear {
      viewModel.checkFoundationModelsAvailability()
    }
  }

  struct LLMSessionView: View {
    @ObservedObject var viewModel: LLMViewModel
    @State private var promptText: String = ""

    var body: some View {
      if viewModel.currentSession?.isResponding ?? false {
        ProgressView()
      } else {
        promptView
      }
    }

    var promptView: some View {
      VStack(alignment: .leading, spacing: 16) {
        TextField("Enter your prompt", text: $promptText)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .padding(.horizontal)

        Button("Submit") {
          Task {
            await viewModel.promtSession(with: promptText)
          }
        }
        .padding(.horizontal)
        ScrollView {
          if let response = viewModel.llmResponse {
            Text("Response:")
              .bold()
              .padding(.top)
            Text(response)
              .padding()
          }
        }
      }
    }
  }
}
