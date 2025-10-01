import Foundation
import FoundationModels

// MARK: - LLM Response Models (@Generable)

@Generable
struct NoteSummary: Codable {
  var overview: String
  var keyThemes: [String]
  var mainPoints: [String]
  var suggestedAction: String?
}

@Generable
struct SummaryResponse: Codable {
  var summary: NoteSummary
}
