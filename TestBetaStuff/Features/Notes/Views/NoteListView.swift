import SwiftUI
import FoundationModels

enum NoteProcessingMode {
  case insights
  case summary
}

struct NoteListView: View {
  @StateObject private var viewModel = NoteViewModel()
  @StateObject private var llmViewModel = LLMViewModel()

  @State private var processingMode: NoteProcessingMode = .insights
  @State private var showInsights = false
  @State private var showSummary = false
  @State private var showAvailabilityAlert = false
  @State private var showLimitAlert = false

  var body: some View {
    NavigationView {
      ZStack {
        if viewModel.notes.isEmpty {
          emptyStateView
        } else {
          notesListView
        }

        // Floating action button
        VStack {
          Spacer()
          HStack {
            Spacer()
            floatingActionButton
              .padding()
          }
        }
      }
      .navigationTitle(
        viewModel.isSelectionMode
          ? "\(viewModel.selectedCount) Selected"
          : "Notes"
      )
      .toolbar {
        // Top trailing button
        ToolbarItem(placement: .navigationBarTrailing) {
          if viewModel.isSelectionMode {
            Button("Cancel") {
              viewModel.toggleSelectionMode()
            }
          } else {
            Button("Select") {
              viewModel.toggleSelectionMode()
            }
          }
        }

        // Bottom toolbar (only in selection mode)
        ToolbarItemGroup(placement: .bottomBar) {
          if viewModel.isSelectionMode {
            Spacer()

            VStack(spacing: 8) {
              // Mode picker
              Picker("Processing Mode", selection: $processingMode) {
                Text("Insights").tag(NoteProcessingMode.insights)
                Text("Summary").tag(NoteProcessingMode.summary)
              }
              .pickerStyle(.segmented)
              .frame(maxWidth: 300)

              // Generate button
              Button(processingMode == .insights ? "Generate Insights" : "Generate Summary") {
                handleGenerate()
              }
              .disabled(!viewModel.canGenerateInsights || llmViewModel.isGeneratingInsights || llmViewModel.isGeneratingSummary)

              HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                  .font(.caption2)
                Text("Analyzed privately on your device")
                  .font(.caption2)
              }
              .foregroundColor(.secondary)
            }

            Spacer()
          }
        }
      }
      .sheet(isPresented: $viewModel.isCreatingNote) {
        NoteCreationView(viewModel: viewModel)
      }
      .sheet(isPresented: $showInsights) {
        InsightsView(
          notes: viewModel.getSelectedNotes(),
          llmViewModel: llmViewModel,
          onDismiss: {
            viewModel.toggleSelectionMode()
            llmViewModel.resetInsights()
          }
        )
      }
      .sheet(isPresented: $showSummary) {
        SummaryView(
          notes: viewModel.getSelectedNotes(),
          llmViewModel: llmViewModel,
          onDismiss: {
            viewModel.toggleSelectionMode()
            llmViewModel.resetSummary()
          }
        )
      }
      .alert("Apple Intelligence Required", isPresented: $showAvailabilityAlert) {
        Button("OK", role: .cancel) { }
      } message: {
        Text("AI processing requires iOS 18.2+ with Apple Intelligence enabled on a compatible device.")
      }
      .alert("Too Many Notes Selected", isPresented: $showLimitAlert) {
        Button("OK", role: .cancel) { }
      } message: {
        Text("Please select up to 10 notes for best results. You currently have \(viewModel.selectedCount) selected.")
      }
    }
  }

  // MARK: - Empty State
  private var emptyStateView: some View {
    VStack(spacing: 20) {
      Image(systemName: "note.text")
        .font(.system(size: 60))
        .foregroundColor(.secondary)

      Text("No Notes Yet")
        .font(.title2)
        .bold()

      Text("Tap the + button to create your first note")
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
  }

  // MARK: - Notes List
  private var notesListView: some View {
    List {
      ForEach(viewModel.notes) { note in
        NoteRowView(
          note: note,
          isSelectionMode: viewModel.isSelectionMode,
          isSelected: viewModel.selectedNoteIds.contains(note.id),
          onSelect: { viewModel.toggleNoteSelection(note.id) }
        )
        .contentShape(Rectangle())
        .onTapGesture {
          if viewModel.isSelectionMode {
            viewModel.toggleNoteSelection(note.id)
          }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
          if !viewModel.isSelectionMode {
            Button(role: .destructive) {
              withAnimation {
                viewModel.deleteNote(note)
              }
            } label: {
              Label("Delete", systemImage: "trash")
            }
          }
        }
      }
    }
    .listStyle(.plain)
  }

  // MARK: - Floating Action Button
  private var floatingActionButton: some View {
    Button {
      viewModel.createNewNote()
    } label: {
      Image(systemName: "plus")
        .font(.title2)
        .fontWeight(.semibold)
        .foregroundColor(.white)
        .frame(width: 56, height: 56)
        .background(Color.blue)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
  }

  // MARK: - Helper Methods
  private func handleGenerate() {
    // Validate count
    if viewModel.selectedCount > 10 {
      showLimitAlert = true
      return
    }

    // Check availability
    if llmViewModel.availability != .available {
      showAvailabilityAlert = true
      return
    }

    // Show appropriate view based on mode
    switch processingMode {
    case .insights:
      showInsights = true
    case .summary:
      showSummary = true
    }
  }
}

// MARK: - Note Row View
struct NoteRowView: View {
  let note: Note
  var isSelectionMode: Bool = false
  var isSelected: Bool = false
  var onSelect: (() -> Void)? = nil

  var body: some View {
    HStack(spacing: 12) {
      // Selection checkbox
      if isSelectionMode {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundColor(isSelected ? .blue : .gray)
          .onTapGesture {
            onSelect?()
          }
      }

      // Note content
      VStack(alignment: .leading, spacing: 8) {
        // Person badge (if present)
        if !note.personName.isEmpty {
          HStack(spacing: 4) {
            Image(systemName: "person.circle.fill")
              .font(.caption2)
            Text(note.personName)
              .font(.caption)
              .fontWeight(.medium)
          }
          .foregroundColor(.blue)
        }

        // Note text preview
        Text(note.text)
          .font(.body)
          .lineLimit(3)

        // Metadata: date and location
        HStack(spacing: 12) {
          HStack(spacing: 4) {
            Image(systemName: "calendar")
              .font(.caption2)
            Text(formattedDate)
              .font(.caption)
          }
          .foregroundColor(.secondary)

          if let location = note.location, let cityName = location.cityName {
            HStack(spacing: 4) {
              Image(systemName: "location.fill")
                .font(.caption2)
              Text(cityName)
                .font(.caption)
                .lineLimit(1)
            }
            .foregroundColor(.secondary)
          }

          Spacer()

          Image(systemName: "lock.fill")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }
    }
    .padding(.vertical, 4)
    .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
  }

  // MARK: - Computed Properties
  private var formattedDate: String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: note.dateCreated, relativeTo: Date())
  }
}

#Preview {
  NoteListView()
}

#Preview("With Notes") {
  let viewModel = NoteViewModel()
  viewModel.notes = [
    Note(
      text: "This is a sample note with some text that demonstrates how the note preview looks in the list view.",
      location: NoteLocation(latitude: 37.7749, longitude: -122.4194, cityName: "San Francisco, CA")
    ),
    Note(
      text: "Another note without location",
      dateCreated: Date().addingTimeInterval(-3600)
    ),
    Note(
      text: "A short note",
      dateCreated: Date().addingTimeInterval(-86400)
    )
  ]

  return NoteListView()
    .onAppear {
      // This is just for preview, won't work but shows the idea
    }
}
