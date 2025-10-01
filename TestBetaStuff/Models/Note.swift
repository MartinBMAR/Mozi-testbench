import Foundation

struct Note: Identifiable {
  let id: UUID
  var text: String
  let dateCreated: Date
  var location: NoteLocation?
  var personName: String = ""

  init(id: UUID = UUID(), text: String, dateCreated: Date = Date(), location: NoteLocation? = nil, personName: String = "") {
    self.id = id
    self.text = text
    self.dateCreated = dateCreated
    self.location = location
    self.personName = personName
  }
}