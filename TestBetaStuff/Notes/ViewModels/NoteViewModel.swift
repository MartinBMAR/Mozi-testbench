import Foundation
import SwiftUI
import Combine

class NoteViewModel: ObservableObject {
  // MARK: - Published Properties
  @Published var notes: [Note] = []
  @Published var currentNoteText: String = ""
  @Published var isCreatingNote: Bool = false

  // MARK: - Services
  let speechRecognizer = SpeechRecognizer()
  let locationManager = LocationManager()

  // MARK: - Private Properties
  private var cancellables = Set<AnyCancellable>()

  // MARK: - Initialization
  init() {
    setupBindings()
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

  func saveNote() {
    guard !currentNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      print("⚠️ Cannot save empty note")
      return
    }

    let note = Note(
      text: currentNoteText,
      location: locationManager.currentLocation
    )

    notes.insert(note, at: 0) // Add to beginning of array
    print("✓ Note saved: \(note.text.prefix(50))...")

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
}