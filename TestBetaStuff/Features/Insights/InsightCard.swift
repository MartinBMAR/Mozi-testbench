import SwiftUI

struct InsightCard: View {
  let insight: Insight

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header: Category + Priority
      HStack {
        categoryIcon
        Text(insight.category.replacingOccurrences(of: "_", with: " "))
          .font(.caption)
          .fontWeight(.semibold)
          .textCase(.uppercase)
          .foregroundColor(categoryColor)

        Spacer()

        priorityBadge
      }

      // Title
      Text(insight.title)
        .font(.headline)
        .foregroundColor(.primary)

      // Description
      Text(insight.description)
        .font(.subheadline)
        .foregroundColor(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      // Suggested Action (if present)
      if let action = insight.suggestedAction, !action.isEmpty {
        HStack(spacing: 6) {
          Image(systemName: "lightbulb.fill")
            .font(.caption)
          Text(action)
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(.orange)
        .padding(.top, 4)
      }

      // Evidence
      Text(insight.evidence)
        .font(.caption2)
        .foregroundColor(.secondary.opacity(0.7))
        .padding(.top, 4)
    }
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(categoryColor.opacity(0.08))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(categoryColor.opacity(0.3), lineWidth: 1.5)
        )
    )
  }

  // MARK: - Category Icon

  private var categoryIcon: some View {
    let iconName: String = {
      switch insight.category {
      case "ACTION_REMINDER": return "bell.fill"
      case "RELATIONSHIP_HEALTH": return "heart.fill"
      case "CONVERSATION_STARTER": return "bubble.left.and.bubble.right.fill"
      case "THOUGHTFUL_GESTURE": return "gift.fill"
      default: return "star.fill"
      }
    }()

    return Image(systemName: iconName)
      .font(.title3)
      .foregroundColor(categoryColor)
  }

  // MARK: - Category Color

  private var categoryColor: Color {
    switch insight.category {
    case "ACTION_REMINDER": return .red
    case "RELATIONSHIP_HEALTH": return .blue
    case "CONVERSATION_STARTER": return .green
    case "THOUGHTFUL_GESTURE": return .purple
    default: return .gray
    }
  }

  // MARK: - Priority Badge

  private var priorityBadge: some View {
    Text(insight.priority)
      .font(.caption2)
      .fontWeight(.semibold)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(priorityColor.opacity(0.2))
      .foregroundColor(priorityColor)
      .clipShape(Capsule())
  }

  // MARK: - Priority Color

  private var priorityColor: Color {
    switch insight.priority {
    case "HIGH": return .red
    case "MEDIUM": return .orange
    case "LOW": return .gray
    default: return .gray
    }
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 16) {
    InsightCard(insight: Insight(
      category: "ACTION_REMINDER",
      priority: "HIGH",
      title: "Follow up about job interview",
      description: "Sarah mentioned her final interview was scheduled for this week. A follow-up message shows you care about important moments in her life.",
      evidence: "From notes: Note 1, Note 3",
      suggestedAction: "Send a text asking how the interview went"
    ))

    InsightCard(insight: Insight(
      category: "CONVERSATION_STARTER",
      priority: "MEDIUM",
      title: "Ask about hiking plans",
      description: "John expressed interest in visiting national parks. This could be a great conversation topic for your next meetup.",
      evidence: "From notes: Note 2",
      suggestedAction: nil
    ))
  }
  .padding()
}
