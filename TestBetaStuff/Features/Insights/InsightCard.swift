import SwiftUI

struct InsightCard: View {
  let insight: Insight
  @State private var reminderService = ReminderService()
  @State private var isCreatingReminder = false
  @State private var reminderCreated = false
  @State private var reminderError: String?

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
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 6) {
            Image(systemName: "lightbulb.fill")
              .font(.caption)
            Text(action)
              .font(.callout)
              .fixedSize(horizontal: false, vertical: true)
          }
          .foregroundColor(.orange)

          // Add to Reminders button
          Button(action: {
            Task {
              await createReminder(action: action)
            }
          }) {
            HStack(spacing: 4) {
              if isCreatingReminder {
                ProgressView()
                  .scaleEffect(0.7)
              } else if reminderCreated {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.green)
                Text("Added to Reminders")
                  .font(.caption)
                  .foregroundColor(.green)
              } else {
                Image(systemName: "plus.circle.fill")
                Text("Add to Reminders")
                  .font(.caption)
              }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(reminderCreated ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
            .cornerRadius(6)
          }
          .disabled(isCreatingReminder || reminderCreated)

          // Error message
          if let error = reminderError {
            Text(error)
              .font(.caption2)
              .foregroundColor(.red)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(.top, 4)
      }
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

  // MARK: - Reminder Creation

  private func createReminder(action: String) async {
    isCreatingReminder = true
    reminderError = nil

    do {
      let reminderTitle = action
      let reminderNotes = "\(insight.title)\n\n\(insight.description)"

      try await reminderService.createReminder(title: reminderTitle, notes: reminderNotes)

      reminderCreated = true
    } catch {
      reminderError = error.localizedDescription
    }

    isCreatingReminder = false
  }
}
