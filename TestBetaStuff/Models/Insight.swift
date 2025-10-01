import Foundation
import FoundationModels

// MARK: - Enums (for UI layer)

enum InsightCategory: String, Codable {
  case actionReminder = "ACTION_REMINDER"
  case relationshipHealth = "RELATIONSHIP_HEALTH"
  case conversationStarter = "CONVERSATION_STARTER"
  case thoughtfulGesture = "THOUGHTFUL_GESTURE"

  var displayName: String {
    switch self {
    case .actionReminder: return "Action Reminder"
    case .relationshipHealth: return "Relationship Health"
    case .conversationStarter: return "Conversation Starter"
    case .thoughtfulGesture: return "Thoughtful Gesture"
    }
  }
}

enum InsightPriority: String, Codable {
  case high = "HIGH"
  case medium = "MEDIUM"
  case low = "LOW"
}

// MARK: - LLM Response Models (@Generable)

@Generable
struct Insight: Identifiable, Codable {
  var id = UUID()
  var category: String
  var priority: String
  var title: String
  var description: String
  var suggestedAction: String?

  // Computed properties for UI
  var categoryEnum: InsightCategory? {
    InsightCategory(rawValue: category)
  }

  var priorityEnum: InsightPriority? {
    InsightPriority(rawValue: priority)
  }
}

@Generable
struct InsightsResponse: Codable {
  var insights: [Insight]
}
