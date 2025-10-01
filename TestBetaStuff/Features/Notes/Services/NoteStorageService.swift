import Foundation

class NoteStorageService {
  // MARK: - Properties
  private let fileName = "notes.json"

  // MARK: - Private Methods
  private func getDocumentsDirectory() -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
  }

  private func getFileURL() -> URL {
    getDocumentsDirectory().appendingPathComponent(fileName)
  }

  // MARK: - Public Methods

  /// Save notes array to disk as JSON
  func saveNotes(_ notes: [Note]) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    encoder.dateEncodingStrategy = .iso8601

    let data = try encoder.encode(notes)
    let fileURL = getFileURL()

    try data.write(to: fileURL, options: .atomic)
    print("✓ Saved \(notes.count) notes to: \(fileURL.path)")
  }

  /// Load notes array from disk
  func loadNotes() throws -> [Note] {
    let fileURL = getFileURL()

    // If file doesn't exist, return empty array (first launch)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      print("ℹ️ No saved notes found, starting fresh")
      return []
    }

    let data = try Data(contentsOf: fileURL)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let notes = try decoder.decode([Note].self, from: data)
    print("✓ Loaded \(notes.count) notes from: \(fileURL.path)")

    return notes
  }
}
