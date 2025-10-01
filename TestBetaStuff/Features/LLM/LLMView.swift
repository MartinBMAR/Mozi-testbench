import FoundationModels
import SwiftUI

struct LLMView: View {
  @StateObject private var viewModel = LLMViewModel()
  @StateObject private var noteViewModel = NoteViewModel()
  @State private var showInsights = false

  var body: some View {
    NavigationView {
      ZStack {
        VStack(spacing: 0) {
          // Availability status
          availabilityHeader

          // Notes selection list
          if !noteViewModel.notes.isEmpty {
            notesList
          } else {
            emptyNotesView
          }
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
      .navigationTitle("LLM Insights")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Generate Insights") {
            showInsights = true
          }
          .disabled(!canGenerateInsights)
        }
      }
      .sheet(isPresented: $showInsights) {
        InsightsView(
          notes: noteViewModel.getSelectedNotes(),
          llmViewModel: viewModel,
          onDismiss: {
            noteViewModel.selectedNoteIds.removeAll()
            viewModel.resetInsights()
          }
        )
      }
      .sheet(isPresented: $noteViewModel.isCreatingNote) {
        NoteCreationView(viewModel: noteViewModel)
      }
      .onAppear {
        viewModel.checkFoundationModelsAvailability()
      }
    }
  }

  // MARK: - Availability Header

  private var availabilityHeader: some View {
    VStack(spacing: 8) {
      HStack {
        Image(systemName: availabilityIcon)
          .foregroundColor(availabilityColor)
        Text(availabilityText)
          .font(.subheadline)
          .foregroundColor(availabilityColor)
      }
      .padding(.vertical, 8)

      if noteViewModel.selectedCount > 0 {
        Text("\(noteViewModel.selectedCount) note\(noteViewModel.selectedCount == 1 ? "" : "s") selected")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Divider()
    }
  }

  // MARK: - Notes List

  private var notesList: some View {
    List {
      ForEach(noteViewModel.notes) { note in
        NoteSelectionRow(
          note: note,
          isSelected: noteViewModel.selectedNoteIds.contains(note.id),
          onToggle: {
            noteViewModel.toggleNoteSelection(note.id)
          }
        )
      }
    }
    .listStyle(.plain)
  }

  // MARK: - Empty State

  private var emptyNotesView: some View {
    VStack(spacing: 20) {
      Image(systemName: "note.text")
        .font(.system(size: 60))
        .foregroundColor(.secondary)

      Text("No Notes Available")
        .font(.title3)
        .bold()

      Text("Create some notes first to generate insights")
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)

      Button {
        noteViewModel.createNewNote()
      } label: {
        HStack {
          Image(systemName: "plus.circle.fill")
          Text("Create Your First Note")
        }
        .font(.headline)
        .foregroundColor(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.blue)
        .cornerRadius(10)
      }
      .padding(.top, 8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Helpers

  private var availabilityText: String {
    switch viewModel.availability {
    case .available:
      return "Apple Intelligence Available"
    case .unavailable(.deviceNotEligible):
      return "Device not eligible"
    case .unavailable(.appleIntelligenceNotEnabled):
      return "Apple Intelligence not enabled"
    case .unavailable(.modelNotReady):
      return "Model not ready"
    case .unavailable(let other):
      return "Unavailable: \(String(describing: other))"
    case .none:
      return "Checking availability..."
    }
  }

  private var availabilityIcon: String {
    switch viewModel.availability {
    case .available:
      return "checkmark.circle.fill"
    default:
      return "exclamationmark.triangle.fill"
    }
  }

  private var availabilityColor: Color {
    switch viewModel.availability {
    case .available:
      return .green
    default:
      return .orange
    }
  }

  private var canGenerateInsights: Bool {
    viewModel.availability == .available &&
    noteViewModel.selectedCount >= 1 &&
    noteViewModel.selectedCount <= 10 &&
    !viewModel.isGeneratingInsights
  }

  // MARK: - Floating Action Button

  private var floatingActionButton: some View {
    Button {
      noteViewModel.createNewNote()
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
}

// MARK: - Note Selection Row

struct NoteSelectionRow: View {
  let note: Note
  let isSelected: Bool
  let onToggle: () -> Void

  var body: some View {
    Button(action: onToggle) {
      HStack(spacing: 12) {
        // Checkbox
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundColor(isSelected ? .blue : .gray)

        // Note content
        VStack(alignment: .leading, spacing: 6) {
          // Person badge
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

          // Note text
          Text(note.text)
            .font(.body)
            .foregroundColor(.primary)
            .lineLimit(2)
            .multilineTextAlignment(.leading)

          // Metadata
          HStack(spacing: 8) {
            Text(note.dateCreated, style: .relative)
              .font(.caption2)
              .foregroundColor(.secondary)

            if let cityName = note.location?.cityName {
              Text("• \(cityName)")
                .font(.caption2)
                .foregroundColor(.secondary)
            }
          }
        }

        Spacer()
      }
      .padding(.vertical, 4)
      .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
