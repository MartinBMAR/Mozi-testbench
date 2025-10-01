import SwiftUI

struct SummaryView: View {
  let notes: [Note]
  @ObservedObject var llmViewModel: LLMViewModel
  let onDismiss: () -> Void

  @Environment(\.dismiss) var dismiss
  @State private var reminderService = ReminderService()
  @State private var showingReminderAlert = false
  @State private var reminderAlertMessage = ""
  @State private var isAddingReminder = false

  var body: some View {
    NavigationView {
      Group {
        if llmViewModel.isGeneratingSummary {
          loadingView
        } else if let error = llmViewModel.summaryError {
          errorView(message: error)
        } else if let response = llmViewModel.summary {
          summaryContent(response)
        } else {
          // Initial state (shouldn't normally be visible)
          ProgressView("Preparing...")
        }
      }
      .navigationTitle("Summary")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
            onDismiss()
          }
        }
      }
    }
    .task {
      // Generate summary when view appears
      await llmViewModel.generateSummary(from: notes)
    }
    .alert("Reminder", isPresented: $showingReminderAlert) {
      Button("OK", role: .cancel) { }
    } message: {
      Text(reminderAlertMessage)
    }
  }

  // MARK: - Loading State

  private var loadingView: some View {
    VStack(spacing: 20) {
      ProgressView()
        .scaleEffect(1.5)

      Text("Summarizing notes...")
        .font(.headline)

      Text("This may take a few seconds")
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Error State

  private func errorView(message: String) -> some View {
    VStack(spacing: 20) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 60))
        .foregroundColor(.red)

      Text("Unable to Generate Summary")
        .font(.headline)

      Text(message)
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Success State

  private func summaryContent(_ response: SummaryResponse) -> some View {
    ScrollView {
      VStack(spacing: 24) {
        headerSection

        // Overview Section
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Image(systemName: "doc.text.fill")
              .foregroundColor(.blue)
            Text("Overview")
              .font(.headline)
          }

          Text(response.summary.overview)
            .font(.body)
            .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.blue.opacity(0.08))
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1.5)
            )
        )

        // Key Themes Section
        if !response.summary.keyThemes.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Image(systemName: "tag.fill")
                .foregroundColor(.purple)
              Text("Key Themes")
                .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
              ForEach(response.summary.keyThemes, id: \.self) { theme in
                HStack(spacing: 8) {
                  Circle()
                    .fill(Color.purple)
                    .frame(width: 6, height: 6)
                  Text(theme)
                    .font(.body)
                }
              }
            }
          }
          .padding()
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.purple.opacity(0.08))
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .strokeBorder(Color.purple.opacity(0.3), lineWidth: 1.5)
              )
          )
        }

        // Main Points Section
        if !response.summary.mainPoints.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Image(systemName: "list.bullet")
                .foregroundColor(.green)
              Text("Main Points")
                .font(.headline)
            }

            VStack(alignment: .leading, spacing: 12) {
              ForEach(Array(response.summary.mainPoints.enumerated()), id: \.offset) { index, point in
                HStack(alignment: .top, spacing: 12) {
                  Text("\(index + 1).")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                  Text(point)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                }
              }
            }
          }
          .padding()
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.green.opacity(0.08))
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .strokeBorder(Color.green.opacity(0.3), lineWidth: 1.5)
              )
          )
        }

        // Suggested Action Section
        if let action = response.summary.suggestedAction, !action.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Image(systemName: "lightbulb.fill")
                .foregroundColor(.orange)
              Text("Suggested Action")
                .font(.headline)

              Spacer()

              Button {
                Task {
                  await addToReminders(action: action)
                }
              } label: {
                HStack(spacing: 4) {
                  if isAddingReminder {
                    ProgressView()
                      .scaleEffect(0.8)
                  } else {
                    Image(systemName: "plus.circle.fill")
                    Text("Add to Reminders")
                      .font(.subheadline)
                  }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
              }
              .disabled(isAddingReminder)
            }

            Text(action)
              .font(.body)
              .foregroundColor(.primary)
          }
          .padding()
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.orange.opacity(0.08))
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1.5)
              )
          )
        }
      }
      .padding()
    }
  }

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(spacing: 8) {
      Text("Based on \(notes.count) note\(notes.count == 1 ? "" : "s")")
        .font(.subheadline)
        .foregroundColor(.secondary)

      HStack(spacing: 4) {
        Image(systemName: "lock.fill")
          .font(.caption)
        Text("Analyzed privately on your device")
          .font(.caption)
      }
      .foregroundColor(.secondary)

      Divider()
        .padding(.top, 8)
    }
  }

  // MARK: - Reminder Functions

  private func addToReminders(action: String) async {
    isAddingReminder = true
    defer { isAddingReminder = false }

    do {
      try await reminderService.createReminder(
        title: action,
        notes: "From notes summary"
      )
      reminderAlertMessage = "Reminder added successfully!"
      showingReminderAlert = true
    } catch {
      reminderAlertMessage = error.localizedDescription
      showingReminderAlert = true
    }
  }
}
