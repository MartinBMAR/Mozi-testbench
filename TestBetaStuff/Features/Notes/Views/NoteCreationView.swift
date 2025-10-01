import SwiftUI

struct NoteCreationView: View {
  @ObservedObject var viewModel: NoteViewModel
  @State private var personName: String = ""
  @FocusState private var isTextFieldFocused: Bool
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            // Header: Date and Privacy Indicator
            headerView

            // Location (if available)
            if let location = viewModel.locationManager.currentLocation {
              locationView(location: location)
            }

            // Person name field
            TextField("Person name (optional)", text: $personName)
              .textFieldStyle(.roundedBorder)
              .autocorrectionDisabled()
              .textInputAutocapitalization(.words)

            // Text Input
            textEditorView
          }
          .padding()
        }

        // Bottom area: Record Button
        bottomArea
      }
      .navigationTitle("New Note")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            viewModel.cancelNoteCreation()
            dismiss()
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Save") {
            viewModel.saveNote(personName: personName)
            dismiss()
          }
          .disabled(!viewModel.canSaveNote)
          .bold()
        }
      }
      .onAppear {
        isTextFieldFocused = true
      }
    }
  }

  // MARK: - Header View
  private var headerView: some View {
    HStack {
      Text(formattedDate)
        .font(.subheadline)
        .foregroundColor(.secondary)

      Spacer()

      Label("Private", systemImage: "lock.fill")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }

  // MARK: - Location View
  private func locationView(location: NoteLocation) -> some View {
    HStack {
      Image(systemName: "location.fill")
        .foregroundColor(.blue)
        .font(.caption)

      Text(location.cityName ?? "Unknown Location")
        .font(.subheadline)
        .foregroundColor(.secondary)

      Spacer()
    }
    .padding(.vertical, 4)
  }

  // MARK: - Text Editor View
  private var textEditorView: some View {
    VStack(alignment: .leading, spacing: 8) {
      if viewModel.currentNoteText.isEmpty && !isTextFieldFocused {
        Text("Tap the microphone to record or type your note here...")
          .foregroundColor(.secondary)
          .font(.body)
      }

      TextEditor(text: $viewModel.currentNoteText)
        .focused($isTextFieldFocused)
        .frame(minHeight: 200)
        .scrollContentBackground(.hidden)
    }
  }

  // MARK: - Bottom Area
  private var bottomArea: some View {
    VStack(spacing: 16) {
      Divider()

      HStack {
        Spacer()

        RecordButton(viewModel: viewModel)

        Spacer()
      }
      .padding(.vertical, 8)
    }
    .background(Color(.systemBackground))
  }

  // MARK: - Computed Properties
  private var formattedDate: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: Date())
  }
}

#Preview {
  NoteCreationView(viewModel: NoteViewModel())
}