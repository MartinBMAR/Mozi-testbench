import Foundation
import FoundationModels

/// Service for generating summaries from notes using Apple's on-device LLM
class SummaryService {

  /// System instructions for the LLM session
  private let systemInstructions = """
    You are a note summarization assistant. Analyze personal notes to provide clear, concise summaries, specific and actionable next steps and reminders to help maintain meaningful relationships.

    Guidelines:
    - Create a brief overview paragraph (2-3 sentences)
    - Identify 2-4 key themes or topics
    - Extract 3-6 main points or important details
    - Maintain a supportive, non-judgmental tone
    - Maintain the original context and meaning
    - Use clear, accessible language
    - Be specific and actionable
    """

  /// Generate summary from an array of notes
  /// - Parameter notes: Array of notes to summarize
  /// - Returns: SummaryResponse containing the generated summary
  /// - Throws: Error if LLM request fails
  func generateSummary(from notes: [Note]) async throws -> SummaryResponse {
    // Create a fresh session for each request to avoid token accumulation
    let session = LanguageModelSession {
      self.systemInstructions
    }

    let prompt = buildPrompt(from: notes)
    let response = try await session.respond(to: prompt, generating: SummaryResponse.self)
    return response.content
  }

  /// Build summarization prompt from notes
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
    var prompt = "Summarize these notes \(personContext):\n\n"

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

    // Add output format instructions
    prompt += """
      Generate a summary as a JSON object with this structure:
      {
        "summary": {
          "overview": "A brief 2-3 sentence overview of all the notes",
          "keyThemes": ["Theme 1", "Theme 2", "Theme 3"],
          "mainPoints": ["Point 1", "Point 2", "Point 3", "Point 4"],
      "suggestedAction": "Specific and actionable next step"
        }
      }

      Provide clear, concise summaries that capture the essence of the notes.
      """

    return prompt
  }
}
