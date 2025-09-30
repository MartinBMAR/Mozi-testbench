import Combine
import Foundation
import FoundationModels
import SwiftUI

class LLMViewModel: ObservableObject {
  private var model = SystemLanguageModel.default
  @Published var currentSession: LanguageModelSession?
  @Published var availability: SystemLanguageModel.Availability?
  @Published var llmResponse: String?

  func checkFoundationModelsAvailability() {
    print("lightweight availability check \(model.isAvailable)")
    availability = model.availability
    if model.isAvailable {
      startLLMSession()
    }
  }

  func startLLMSession() {
    Task {
//      let instructions = ""
//      let session = LanguageModelSession(instructions: instructions)
      let session = LanguageModelSession()
      currentSession = session
    }
  }

  @MainActor
  func promtSession(with prompt: String) async {
    if let currentSession {
      do {
        let response = try await currentSession.respond(to: prompt)
        llmResponse = response.content
      } catch {
        print("Failed to get LLM response")
      }
    }
  }
}
