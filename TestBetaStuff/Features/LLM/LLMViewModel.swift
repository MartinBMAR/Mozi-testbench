import Combine
import Foundation
import FoundationModels
import SwiftUI

class LLMViewModel: ObservableObject {
  private var model = SystemLanguageModel.default
  @Published var currentSession: LanguageModelSession?
  @Published var availability: SystemLanguageModel.Availability?
  @Published var llmResponse: String?

  // MARK: - Insights Properties
  private let insightsService = InsightsService()
  @Published var insights: InsightsResponse?
  @Published var insightsError: String?
  @Published var isGeneratingInsights: Bool = false

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

  // MARK: - Insights Methods

  /// Generate insights from selected notes
  /// - Parameter notes: Array of notes to analyze (1-10 notes)
  @MainActor
  func generateInsights(from notes: [Note]) async {
    isGeneratingInsights = true
    insightsError = nil
    insights = nil

    do {
      let response = try await insightsService.generateInsights(from: notes)
      insights = response
    } catch {
      print("Insights generation error: \(error)")
      insightsError = "Unable to generate insights. Please try again."
    }

    isGeneratingInsights = false
  }

  /// Reset insights state
  func resetInsights() {
    insights = nil
    insightsError = nil
    isGeneratingInsights = false
  }
}
