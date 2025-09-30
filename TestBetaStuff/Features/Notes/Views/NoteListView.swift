import SwiftUI

struct NoteListView: View {
  @StateObject private var viewModel = NoteViewModel()

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
      .navigationTitle("Notes")
      .sheet(isPresented: $viewModel.isCreatingNote) {
        NoteCreationView(viewModel: viewModel)
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
        NoteRowView(note: note)
          .swipeActions(edge: .trailing, allowsFullSwipe: true) {
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
}

// MARK: - Note Row View
struct NoteRowView: View {
  let note: Note

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
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
    .padding(.vertical, 4)
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