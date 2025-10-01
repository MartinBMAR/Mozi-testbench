import Foundation
import FoundationModels

/// Service for generating relationship insights from notes using Apple's on-device LLM
class InsightsService {

  /// System instructions for the LLM session
  private let systemInstructions = """
    You are a relationship insights assistant. Analyze personal notes to provide actionable insights that help maintain meaningful relationships.

    Generate insights in these categories:
    - ACTION_REMINDER: Follow-ups on stated intentions or time-sensitive matters
    - RELATIONSHIP_HEALTH: Patterns suggesting attention or care needed
    - CONVERSATION_STARTER: Topics to discuss based on interests/situations
    - THOUGHTFUL_GESTURE: Activity, or gesture ideas from mentioned details

    Guidelines:
    - Prioritize insights that involve meeting the other person in real life
    - Be specific and actionable
    - Reference concrete details from the notes
    - Maintain a supportive, non-judgmental tone
    - Generate at least 2 insights and up to 4 insights (one per category if applicable)
    - If notes lack sufficient context, return empty insights array
    - Priority levels: HIGH (urgent/time-sensitive), MEDIUM (important but not urgent), LOW (nice to have)
    """

  /// Generate insights from an array of notes
  /// - Parameter notes: Array of 1-10 notes to analyze
  /// - Returns: InsightsResponse containing generated insights
  /// - Throws: Error if LLM request fails
  func generateInsights(from notes: [Note]) async throws -> InsightsResponse {
    // Create a fresh session for each request to avoid token accumulation
    let session = LanguageModelSession {
      self.systemInstructions
    }

    let prompt = buildPrompt(from: notes)
    let response = try await session.respond(to: prompt, generating: InsightsResponse.self)
    return response.content
  }

  /// Build analysis prompt from notes
  private func buildPrompt(from notes: [Note]) -> String {
    // Extract unique person names
    let personNames = Set(notes.map { $0.personName })
      .filter { !$0.isEmpty }

    // Build person context
    let personContext: String
    if personNames.isEmpty {
      personContext = ""
    } else if personNames.count == 1 {
      personContext = "about \(personNames.first!)"
    } else {
      personContext = "about \(personNames.joined(separator: ", "))"
    }

    // Start building prompt
    var prompt = "Analyze these notes \(personContext):\n\n"

    // Add each note with metadata
    let dateFormatter = ISO8601DateFormatter()

    for (index, note) in notes.enumerated() {
      let dateStr = dateFormatter.string(from: note.dateCreated)

      prompt += "Note \(index + 1) (Created: \(dateStr)"

      if !note.personName.isEmpty {
        prompt += ", Person: \(note.personName)"
      }

      prompt += "):\n"
      prompt += "\(note.text)\n\n"
    }

    // Add current date for time-sensitive insights
    let today = dateFormatter.string(from: Date())
    prompt += "Today's date: \(today)\n\n"

    // Add output format instructions
    prompt += """
      Generate insights as a JSON object with this structure:
      {
        "insights": [
          {
            "category": "ACTION_REMINDER" | "RELATIONSHIP_HEALTH" | "CONVERSATION_STARTER" | "THOUGHTFUL_GESTURE",
            "priority": "HIGH" | "MEDIUM" | "LOW",
            "title": "Brief summary (max 40 characters)",
            "description": "1-2 sentences explaining the insight",
            "suggestedAction": "Specific and actionable next step"
          }
        ]
      }

      If notes don't provide enough context, return empty insights array.
      """

    return prompt
  }
}
