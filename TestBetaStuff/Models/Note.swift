import Foundation

struct Note: Identifiable {
  let id: UUID
  var text: String
  let dateCreated: Date
  var location: NoteLocation?

  init(id: UUID = UUID(), text: String, dateCreated: Date = Date(), location: NoteLocation? = nil) {
    self.id = id
    self.text = text
    self.dateCreated = dateCreated
    self.location = location
  }
}