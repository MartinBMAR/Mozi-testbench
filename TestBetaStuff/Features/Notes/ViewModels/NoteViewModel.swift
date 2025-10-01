import Foundation
import SwiftUI
import Combine

class NoteViewModel: ObservableObject {
  // MARK: - Published Properties
  @Published var notes: [Note] = []
  @Published var currentNoteText: String = ""
  @Published var isCreatingNote: Bool = false

  // MARK: - Selection Mode Properties
  @Published var isSelectionMode: Bool = false
  @Published var selectedNoteIds: Set<UUID> = []

  // MARK: - Services
  let speechRecognizer = SpeechRecognizer()
  let locationManager = LocationManager()
  private let storageService = NoteStorageService()

  // MARK: - Private Properties
  private var cancellables = Set<AnyCancellable>()

  // MARK: - Initialization
  init() {
    setupBindings()
    loadNotes()
  }

  // MARK: - Setup
  private func setupBindings() {
    // Sync speech recognizer text with current note text
    speechRecognizer.$transcribedText
      .receive(on: DispatchQueue.main)
      .sink { [weak self] text in
        self?.currentNoteText = text
      }
      .store(in: &cancellables)
  }

  // MARK: - Note Management
  func createNewNote() {
    currentNoteText = ""
    speechRecognizer.reset()
    locationManager.currentLocation = nil
    isCreatingNote = true

    // Request location for new note
    locationManager.requestLocation()
  }

  func saveNote(personName: String = "") {
    guard !currentNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      print("⚠️ Cannot save empty note")
      return
    }

    let note = Note(
      text: currentNoteText,
      location: locationManager.currentLocation,
      personName: personName.trimmingCharacters(in: .whitespacesAndNewlines)
    )

    notes.insert(note, at: 0) // Add to beginning of array
    print("✓ Note saved: \(note.text.prefix(50))...")

    // Persist to disk
    saveNotesToDisk()

    // Reset state
    currentNoteText = ""
    speechRecognizer.reset()
    locationManager.currentLocation = nil
    isCreatingNote = false
  }

  func deleteNote(at index: Int) {
    guard index < notes.count else { return }
    let note = notes[index]
    notes.remove(at: index)
    print("🗑️ Note deleted: \(note.text.prefix(50))...")

    // Persist to disk
    saveNotesToDisk()
  }

  func deleteNote(_ note: Note) {
    if let index = notes.firstIndex(where: { $0.id == note.id }) {
      deleteNote(at: index)
    }
  }

  func cancelNoteCreation() {
    currentNoteText = ""
    speechRecognizer.reset()
    locationManager.currentLocation = nil
    isCreatingNote = false
  }

  // MARK: - Recording Control
  func startRecording() {
    if speechRecognizer.authorizationStatus != .authorized {
      speechRecognizer.requestAuthorization { [weak self] authorized in
        if authorized {
          self?.speechRecognizer.startRecording()
        } else {
          print("❌ Speech recognition not authorized")
        }
      }
    } else {
      speechRecognizer.startRecording()
    }
  }

  func stopRecording() {
    speechRecognizer.stopRecording()
  }

  // MARK: - Computed Properties
  var canSaveNote: Bool {
    !currentNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var noteCount: Int {
    notes.count
  }

  // MARK: - Selection Methods

  /// Toggle selection mode on/off, clearing selection when disabled
  func toggleSelectionMode() {
    isSelectionMode.toggle()
    if !isSelectionMode {
      selectedNoteIds.removeAll()
    }
  }

  /// Toggle individual note selection
  func toggleNoteSelection(_ noteId: UUID) {
    if selectedNoteIds.contains(noteId) {
      selectedNoteIds.remove(noteId)
    } else {
      selectedNoteIds.insert(noteId)
    }
  }

  /// Get selected notes sorted by date (most recent first)
  func getSelectedNotes() -> [Note] {
    notes.filter { selectedNoteIds.contains($0.id) }
      .sorted { $0.dateCreated > $1.dateCreated }
  }

  /// Validate selection count (1-10 notes)
  var canGenerateInsights: Bool {
    selectedNoteIds.count >= 1 && selectedNoteIds.count <= 10
  }

  /// Get count of selected notes
  var selectedCount: Int {
    selectedNoteIds.count
  }

  // MARK: - Storage Methods

  /// Load notes from persistent storage
  private func loadNotes() {
    do {
      notes = try storageService.loadNotes()
    } catch {
      print("❌ Failed to load notes: \(error.localizedDescription)")
      notes = []
    }
  }

  /// Save notes to persistent storage
  private func saveNotesToDisk() {
    do {
      try storageService.saveNotes(notes)
    } catch {
      print("❌ Failed to save notes: \(error.localizedDescription)")
    }
  }
}