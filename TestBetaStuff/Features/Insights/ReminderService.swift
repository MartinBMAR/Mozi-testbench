import Foundation
import EventKit

/// Service for creating iOS reminders from insights
class ReminderService {
  private let eventStore = EKEventStore()

  /// Request access to reminders
  /// - Returns: True if access granted, false otherwise
  func requestAccess() async -> Bool {
    do {
      return try await eventStore.requestFullAccessToReminders()
    } catch {
      print("Error requesting reminders access: \(error)")
      return false
    }
  }

  /// Create a reminder from an insight's suggested action
  /// - Parameters:
  ///   - title: The title for the reminder
  ///   - notes: Optional notes to add to the reminder
  /// - Throws: Error if reminder creation fails
  func createReminder(title: String, notes: String? = nil) async throws {
    // Request access if needed
    let hasAccess = await requestAccess()
    guard hasAccess else {
      throw ReminderError.accessDenied
    }

    // Get default calendar for reminders
    guard let defaultCalendar = eventStore.defaultCalendarForNewReminders() else {
      throw ReminderError.noDefaultCalendar
    }

    // Create reminder
    let reminder = EKReminder(eventStore: eventStore)
    reminder.title = title
    reminder.notes = notes
    reminder.calendar = defaultCalendar

    // Save reminder
    try eventStore.save(reminder, commit: true)
  }
}

// MARK: - Errors

enum ReminderError: LocalizedError {
  case accessDenied
  case noDefaultCalendar

  var errorDescription: String? {
    switch self {
    case .accessDenied:
      return "Access to reminders was denied. Please enable access in Settings."
    case .noDefaultCalendar:
      return "No default reminders list found."
    }
  }
}
