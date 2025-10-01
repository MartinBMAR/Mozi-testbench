import SwiftUI

struct InsightsView: View {
  let notes: [Note]
  @ObservedObject var llmViewModel: LLMViewModel
  let onDismiss: () -> Void

  var body: some View {
    NavigationView {
      Group {
        if llmViewModel.isGeneratingInsights {
          loadingView
        } else if let error = llmViewModel.insightsError {
          errorView(message: error)
        } else if let response = llmViewModel.insights {
          insightsContent(response)
        } else {
          // Initial state (shouldn't normally be visible)
          ProgressView("Preparing...")
        }
      }
      .navigationTitle("Insights")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            onDismiss()
          }
        }
      }
    }
    .task {
      // Generate insights when view appears
      await llmViewModel.generateInsights(from: notes)
    }
  }

  // MARK: - Loading State

  private var loadingView: some View {
    VStack(spacing: 20) {
      ProgressView()
        .scaleEffect(1.5)

      Text("Analyzing notes...")
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

      Text("Unable to Generate Insights")
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

  @ViewBuilder
  private func insightsContent(_ response: InsightsResponse) -> some View {
    if response.insights.isEmpty {
      emptyStateView
    } else {
      ScrollView {
        VStack(spacing: 16) {
          headerSection

          ForEach(response.insights) { insight in
            InsightCard(insight: insight)
          }
        }
        .padding()
      }
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

  // MARK: - Empty State

  private var emptyStateView: some View {
    VStack(spacing: 20) {
      Image(systemName: "brain.head.profile")
        .font(.system(size: 60))
        .foregroundColor(.secondary)

      Text("Not Enough Context")
        .font(.headline)

      Text("The selected notes don't contain enough details to generate meaningful insights.")
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)

      Text("Try selecting notes with more information about conversations, events, or interests.")
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
