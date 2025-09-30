import Combine
import Foundation
import FoundationModels
import SwiftUI

class LLMViewModel: ObservableObject {
  private var model = SystemLanguageModel.default
  @Published var currentSession: LanguageModelSession?
  @Published var availability: SystemLanguageModel.Availability?
  @Published var llmResponse: String?
  @Published var tripResponse: TripModel?

  func checkFoundationModelsAvailability() {
    print("lightweight availability check \(model.isAvailable)")
    availability = model.availability
    if model.isAvailable {
      startLLMSession()
    }
  }

  func startLLMSession() {
    Task {
      let instructions = "Use as much context from other apps as possible, focusing on contacts"
      let session = LanguageModelSession(instructions: instructions)
      currentSession = session
      await MainActor.run {

      }
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

  func searchForTrips() async {
    guard let currentSession else { return }
    let options = GenerationOptions(temperature: 2.0)
    let response = try? await currentSession.respond(
      to: "Find a less known european country to make a trip to and a list of cities worth visiting in that country",
      generating: TripModel.self,
      options: options
    )
    tripResponse = response?.content
  }
}
