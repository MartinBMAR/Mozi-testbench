# LLM Insights Feature - Implementation Plan

**Version**: 1.0
**Date**: 2025-10-01
**Estimated Time**: 5-6 hours
**Scope**: Simplified MVP - no persistence, no animations, basic error handling

---

## Table of Contents

1. [Feature Overview](#feature-overview)
2. [Technical Architecture](#technical-architecture)
3. [Implementation Phases](#implementation-phases)
4. [File Structure](#file-structure)
5. [Testing Checklist](#testing-checklist)
6. [Future Enhancements](#future-enhancements)

---

## Feature Overview

### User Flow
1. User opens Notes app and taps "Select" button
2. User selects 1-10 notes by tapping checkboxes
3. User taps "Generate Insights" button
4. System analyzes notes using on-device Apple Intelligence
5. User views insights in a modal sheet with categorized cards
6. User taps "Done" to dismiss and return to notes list

### Key Constraints
- Minimum: 1 note required
- Maximum: 10 notes recommended
- On-device processing only (privacy-preserving)
- Requires iOS 18.2+ with Apple Intelligence enabled
- No persistence (ephemeral insights)
- No cross-person validation (allows mixed selections)

---

## Technical Architecture

### Data Flow
```
NoteListView (Selection)
    ↓
NoteViewModel (Selection State)
    ↓
InsightsView (Trigger)
    ↓
LLMViewModel (Orchestration)
    ↓
InsightsService (LLM Integration)
    ↓
LanguageModelSession (Apple FoundationModels)
    ↓
InsightsResponse (@Generable struct)
    ↓
InsightsView (Display)
```

### Key Components
- **Models**: Note, Insight, InsightsResponse
- **Services**: InsightsService (LLM integration)
- **ViewModels**: NoteViewModel (selection), LLMViewModel (generation)
- **Views**: NoteListView, InsightsView, InsightCard

---

## Implementation Phases

---

## Phase 1: Data Models (30 minutes)

### 1.1 Update Note Model

**File**: `TestBetaStuff/Models/Note.swift`

**Current structure**:
```swift
struct Note: Identifiable {
  let id: UUID
  var text: String
  let dateCreated: Date
  var location: NoteLocation?
}
```

**Changes needed**:
```swift
struct Note: Identifiable {
  let id: UUID
  var text: String
  let dateCreated: Date
  var location: NoteLocation?
  var personName: String = ""  // NEW: Person association

  init(id: UUID = UUID(), text: String, dateCreated: Date = Date(), location: NoteLocation? = nil, personName: String = "") {
    self.id = id
    self.text = text
    self.dateCreated = dateCreated
    self.location = location
    self.personName = personName
  }
}
```

**Why**: Person name enables contextual insights about specific relationships

---

### 1.2 Create Insight Models

**New file**: `TestBetaStuff/Models/Insight.swift`

**Complete implementation**:
```swift
import Foundation
import FoundationModels

// MARK: - Enums (for UI layer)

enum InsightCategory: String, Codable {
  case actionReminder = "ACTION_REMINDER"
  case relationshipHealth = "RELATIONSHIP_HEALTH"
  case conversationStarter = "CONVERSATION_STARTER"
  case thoughtfulGesture = "THOUGHTFUL_GESTURE"

  var displayName: String {
    switch self {
    case .actionReminder: return "Action Reminder"
    case .relationshipHealth: return "Relationship Health"
    case .conversationStarter: return "Conversation Starter"
    case .thoughtfulGesture: return "Thoughtful Gesture"
    }
  }
}

enum InsightPriority: String, Codable {
  case high = "HIGH"
  case medium = "MEDIUM"
  case low = "LOW"
}

// MARK: - LLM Response Models (@Generable)

@Generable
struct Insight: Identifiable, Codable {
  var id = UUID()
  var category: String
  var priority: String
  var title: String
  var description: String
  var evidence: String
  var suggestedAction: String?

  // Computed properties for UI
  var categoryEnum: InsightCategory? {
    InsightCategory(rawValue: category)
  }

  var priorityEnum: InsightPriority? {
    InsightPriority(rawValue: priority)
  }
}

@Generable
struct InsightsResponse: Codable {
  var insights: [Insight]
}
```

**Key decisions**:
- Use `String` for category/priority in `@Generable` models (LLM returns strings)
- Provide computed properties to convert to enums for type-safe UI code
- Keep `id = UUID()` to ensure each insight is identifiable
- `suggestedAction` is optional (not all insights need actions)

**Testing @Generable**:
Before implementing the full service, test that `@Generable` works:
```swift
// In LLMView or a test view
let testSession = LanguageModelSession()
let response = try await testSession.respond(
  to: "Generate a test insight",
  generating: InsightsResponse.self
)
print(response.insights)
```

---

## Phase 2: Selection Logic (1 hour)

### 2.1 Update NoteViewModel

**File**: `TestBetaStuff/Features/Notes/ViewModels/NoteViewModel.swift`

**Add to existing class**:
```swift
class NoteViewModel: ObservableObject {
  // ... existing properties ...

  // MARK: - Selection Mode Properties
  @Published var isSelectionMode: Bool = false
  @Published var selectedNoteIds: Set<UUID> = []

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
}
```

**Why**:
- `Set<UUID>` for O(1) lookup/insert/remove performance
- Automatic deselection when exiting selection mode prevents stale state
- Sorted by date ensures prompt presents notes chronologically
- Validation encapsulated in ViewModel

---

## Phase 3: LLM Integration (2 hours)

### 3.1 Create InsightsService

**New file**: `TestBetaStuff/Features/Insights/InsightsService.swift`

**Complete implementation**:
```swift
import Foundation
import FoundationModels

/// Service for generating relationship insights from notes using Apple's on-device LLM
class InsightsService {

  private let session: LanguageModelSession

  init() {
    // Initialize session with system instructions
    session = LanguageModelSession {
      """
      You are a relationship insights assistant. Analyze personal notes to provide actionable insights that help maintain meaningful relationships.

      Generate insights in these categories:
      - ACTION_REMINDER: Follow-ups on stated intentions or time-sensitive matters
      - RELATIONSHIP_HEALTH: Patterns suggesting attention or care needed
      - CONVERSATION_STARTER: Topics to discuss based on interests/situations
      - THOUGHTFUL_GESTURE: Gift, activity, or gesture ideas from mentioned details

      Guidelines:
      - Be specific and actionable
      - Reference concrete details from the notes
      - Maintain a supportive, non-judgmental tone
      - Generate up to 4 insights (one per category if applicable)
      - If notes lack sufficient context, return empty insights array
      - Priority levels: HIGH (urgent/time-sensitive), MEDIUM (important but not urgent), LOW (nice to have)
      """
    }
  }

  /// Generate insights from an array of notes
  /// - Parameter notes: Array of 1-10 notes to analyze
  /// - Returns: InsightsResponse containing generated insights
  /// - Throws: Error if LLM request fails
  func generateInsights(from notes: [Note]) async throws -> InsightsResponse {
    let prompt = buildPrompt(from: notes)
    let response = try await session.respond(to: prompt, generating: InsightsResponse.self)
    return response
  }

  /// Build analysis prompt from notes
  private func buildPrompt(from notes: [Note]) -> String {
    // Extract unique person names
    let personNames = Set(notes.map { $0.personName })
      .filter { !$0.isEmpty }

    // Build person context
    let personContext: String
    if personNames.isEmpty {
      personContext = ""
    } else if personNames.count == 1 {
      personContext = "about \(personNames.first!)"
    } else {
      personContext = "about \(personNames.joined(separator: ", "))"
    }

    // Start building prompt
    var prompt = "Analyze these notes \(personContext):\n\n"

    // Add each note with metadata
    let dateFormatter = ISO8601DateFormatter()

    for (index, note) in notes.enumerated() {
      let dateStr = dateFormatter.string(from: note.dateCreated)

      prompt += "Note \(index + 1) (Created: \(dateStr)"

      if !note.personName.isEmpty {
        prompt += ", Person: \(note.personName)"
      }

      if let location = note.location, let cityName = location.cityName {
        prompt += ", Location: \(cityName)"
      }

      prompt += "):\n"
      prompt += "\(note.text)\n\n"
    }

    // Add current date for time-sensitive insights
    let today = dateFormatter.string(from: Date())
    prompt += "Today's date: \(today)\n\n"

    // Add output format instructions
    prompt += """
    Generate insights as a JSON object with this structure:
    {
      "insights": [
        {
          "category": "ACTION_REMINDER" | "RELATIONSHIP_HEALTH" | "CONVERSATION_STARTER" | "THOUGHTFUL_GESTURE",
          "priority": "HIGH" | "MEDIUM" | "LOW",
          "title": "Brief summary (max 60 characters)",
          "description": "2-3 sentences explaining the insight",
          "evidence": "Reference to supporting notes (e.g., 'Note 1, Note 3')",
          "suggestedAction": "Optional specific next step"
        }
      ]
    }

    If notes don't provide enough context, return empty insights array.
    """

    return prompt
  }
}
```

**Key implementation notes**:
- **System instructions**: Set once at initialization, apply to all requests
- **Prompt structure**: Notes → Metadata → Current date → Format instructions
- **Person handling**: Gracefully handles 0, 1, or multiple person names
- **Date format**: ISO8601 (2025-10-01T14:30:00Z) for unambiguous parsing
- **Location inclusion**: Optional context if available
- **Error propagation**: Throws errors from LanguageModelSession for caller to handle

**Token considerations**:
- System instructions: ~200 tokens
- Per note overhead: ~50 tokens (metadata)
- Note content: Variable (avg 100-200 tokens)
- Output format: ~150 tokens
- Response: ~500-800 tokens
- **Total for 5 notes**: ~1500-2000 tokens (well within 4096 limit)

---

### 3.2 Update LLMViewModel

**File**: `TestBetaStuff/Features/LLM/LLMViewModel.swift`

**Add to existing class**:
```swift
class LLMViewModel: ObservableObject {
  // ... existing properties ...

  // MARK: - Insights Properties
  private let insightsService = InsightsService()
  @Published var insights: InsightsResponse?
  @Published var insightsError: String?
  @Published var isGeneratingInsights: Bool = false

  // MARK: - Insights Methods

  /// Generate insights from selected notes
  /// - Parameter notes: Array of notes to analyze (1-10 notes)
  @MainActor
  func generateInsights(from notes: [Note]) async {
    isGeneratingInsights = true
    insightsError = nil
    insights = nil

    do {
      let response = try await insightsService.generateInsights(from: notes)
      insights = response
    } catch {
      print("Insights generation error: \(error)")
      insightsError = "Unable to generate insights. Please try again."
    }

    isGeneratingInsights = false
  }

  /// Reset insights state
  func resetInsights() {
    insights = nil
    insightsError = nil
    isGeneratingInsights = false
  }
}
```

**Why**:
- `@MainActor` ensures UI updates happen on main thread
- Error messages kept user-friendly (technical details logged)
- Separate reset method for state management
- Service encapsulation (LLMViewModel doesn't know about LanguageModelSession)

---

## Phase 4: Selection UI (1.5 hours)

### 4.1 Update NoteListView

**File**: `TestBetaStuff/Features/Notes/Views/NoteListView.swift`

**Add properties**:
```swift
struct NoteListView: View {
  @StateObject private var viewModel = NoteViewModel()
  @StateObject private var llmViewModel = LLMViewModel()  // NEW

  @State private var showInsights = false  // NEW
  @State private var showAvailabilityAlert = false  // NEW
  @State private var showLimitAlert = false  // NEW

  // ... rest of implementation ...
}
```

**Update navigation title**:
```swift
.navigationTitle(
  viewModel.isSelectionMode
    ? "\(viewModel.selectedCount) Selected"
    : "Notes"
)
```

**Update toolbar**:
```swift
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

      VStack(spacing: 4) {
        Button("Generate Insights") {
          handleGenerateInsights()
        }
        .disabled(!viewModel.canGenerateInsights || llmViewModel.isGeneratingInsights)

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
```

**Add insight generation handler**:
```swift
private func handleGenerateInsights() {
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

  // All good, show insights
  showInsights = true
}
```

**Add sheet for insights**:
```swift
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
```

**Add alerts**:
```swift
.alert("Apple Intelligence Required", isPresented: $showAvailabilityAlert) {
  Button("OK", role: .cancel) { }
} message: {
  Text("Insights require iOS 18.2+ with Apple Intelligence enabled on a compatible device.")
}

.alert("Too Many Notes Selected", isPresented: $showLimitAlert) {
  Button("OK", role: .cancel) { }
} message: {
  Text("Please select up to 10 notes for best results. You currently have \(viewModel.selectedCount) selected.")
}
```

**Update notesListView**:
```swift
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
        if !viewModel.isSelectionMode {  // Hide swipe actions in selection mode
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
```

---

### 4.2 Update NoteRowView

**File**: `TestBetaStuff/Features/Notes/Views/NoteListView.swift` (same file, NoteRowView struct)

**Complete updated implementation**:
```swift
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

  private var formattedDate: String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: note.dateCreated, relativeTo: Date())
  }
}
```

**Key UI changes**:
- Checkbox appears on left when `isSelectionMode == true`
- Selected rows get light blue background
- Person name shown as badge at top of note content
- Tap gesture on checkbox for selection
- Background color changes based on selection state

---

### 4.3 Update NoteCreationView

**File**: `TestBetaStuff/Features/Notes/Views/NoteCreationView.swift`

**Add state property**:
```swift
struct NoteCreationView: View {
  @ObservedObject var viewModel: NoteViewModel
  @State private var personName: String = ""  // NEW

  // ... rest of properties ...
}
```

**Update body to add person name field** (add above note text field):
```swift
var body: some View {
  NavigationView {
    VStack(spacing: 16) {
      // Person name field (NEW)
      TextField("Person name (optional)", text: $personName)
        .textFieldStyle(.roundedBorder)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.words)
        .padding(.horizontal)

      // Existing note text field
      TextField("What's on your mind?", text: $viewModel.currentNoteText, axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .lineLimit(5...10)
        .padding(.horizontal)

      // ... rest of UI ...
    }
  }
}
```

**Update save button action**:
```swift
Button("Save") {
  viewModel.saveNote(personName: personName)
}
.disabled(!viewModel.canSaveNote)
```

**Update NoteViewModel.saveNote() method**:
```swift
// In NoteViewModel.swift
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

  notes.insert(note, at: 0)
  print("✓ Note saved: \(note.text.prefix(50))...")

  // Reset state
  currentNoteText = ""
  speechRecognizer.reset()
  locationManager.currentLocation = nil
  isCreatingNote = false
}
```

**Person name handling**:
- Optional field (not required)
- Auto-capitalization for proper names
- Trimmed whitespace before saving
- Case-insensitive comparison in prompts (done in InsightsService)

---

## Phase 5: Insights Display (2 hours)

### 5.1 Create InsightsView

**New file**: `TestBetaStuff/Features/Insights/InsightsView.swift`

**Complete implementation**:
```swift
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
```

**State handling**:
- **Loading**: Shows while `isGeneratingInsights == true`
- **Error**: Shows if `insightsError != nil`
- **Success**: Shows if `insights != nil` (can be empty array)
- **Initial**: Shouldn't be visible (`.task` triggers immediately)

**Navigation**:
- Modal sheet presentation (configured in NoteListView)
- Done button dismisses and triggers cleanup callback
- `.task` modifier ensures generation starts on appear

---

### 5.2 Create InsightCard

**New file**: `TestBetaStuff/Features/Insights/InsightCard.swift`

**Complete implementation**:
```swift
import SwiftUI

struct InsightCard: View {
  let insight: Insight

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header: Category + Priority
      HStack {
        categoryIcon
        Text(insight.category.replacingOccurrences(of: "_", with: " "))
          .font(.caption)
          .fontWeight(.semibold)
          .textCase(.uppercase)
          .foregroundColor(categoryColor)

        Spacer()

        priorityBadge
      }

      // Title
      Text(insight.title)
        .font(.headline)
        .foregroundColor(.primary)

      // Description
      Text(insight.description)
        .font(.subheadline)
        .foregroundColor(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      // Suggested Action (if present)
      if let action = insight.suggestedAction, !action.isEmpty {
        HStack(spacing: 6) {
          Image(systemName: "lightbulb.fill")
            .font(.caption)
          Text(action)
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundColor(.orange)
        .padding(.top, 4)
      }

      // Evidence
      Text(insight.evidence)
        .font(.caption2)
        .foregroundColor(.secondary.opacity(0.7))
        .padding(.top, 4)
    }
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(categoryColor.opacity(0.08))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(categoryColor.opacity(0.3), lineWidth: 1.5)
        )
    )
  }

  // MARK: - Category Icon

  private var categoryIcon: some View {
    let iconName: String = {
      switch insight.category {
      case "ACTION_REMINDER": return "bell.fill"
      case "RELATIONSHIP_HEALTH": return "heart.fill"
      case "CONVERSATION_STARTER": return "bubble.left.and.bubble.right.fill"
      case "THOUGHTFUL_GESTURE": return "gift.fill"
      default: return "star.fill"
      }
    }()

    return Image(systemName: iconName)
      .font(.title3)
      .foregroundColor(categoryColor)
  }

  // MARK: - Category Color

  private var categoryColor: Color {
    switch insight.category {
    case "ACTION_REMINDER": return .red
    case "RELATIONSHIP_HEALTH": return .blue
    case "CONVERSATION_STARTER": return .green
    case "THOUGHTFUL_GESTURE": return .purple
    default: return .gray
    }
  }

  // MARK: - Priority Badge

  private var priorityBadge: some View {
    Text(insight.priority)
      .font(.caption2)
      .fontWeight(.semibold)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(priorityColor.opacity(0.2))
      .foregroundColor(priorityColor)
      .clipShape(Capsule())
  }

  // MARK: - Priority Color

  private var priorityColor: Color {
    switch insight.priority {
    case "HIGH": return .red
    case "MEDIUM": return .orange
    case "LOW": return .gray
    default: return .gray
    }
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 16) {
    InsightCard(insight: Insight(
      category: "ACTION_REMINDER",
      priority: "HIGH",
      title: "Follow up about job interview",
      description: "Sarah mentioned her final interview was scheduled for this week. A follow-up message shows you care about important moments in her life.",
      evidence: "From notes: Note 1, Note 3",
      suggestedAction: "Send a text asking how the interview went"
    ))

    InsightCard(insight: Insight(
      category: "CONVERSATION_STARTER",
      priority: "MEDIUM",
      title: "Ask about hiking plans",
      description: "John expressed interest in visiting national parks. This could be a great conversation topic for your next meetup.",
      evidence: "From notes: Note 2",
      suggestedAction: nil
    ))
  }
  .padding()
}
```

**Design choices**:
- **Color coding**: Category determines border/background/icon color
- **Icon mapping**: SF Symbols matched to each category
- **Priority badge**: Capsule style on top-right
- **Suggested action**: Highlighted in orange with lightbulb icon
- **Evidence**: Small text at bottom for transparency
- **Fixed size**: Prevents text truncation in narrow views

**Category-Color mapping**:
- 🔔 ACTION_REMINDER → Red (urgency)
- ❤️ RELATIONSHIP_HEALTH → Blue (care)
- 💬 CONVERSATION_STARTER → Green (opportunity)
- 🎁 THOUGHTFUL_GESTURE → Purple (delight)

---

## Phase 6: Basic Error Handling (30 minutes)

### 6.1 Availability Check

**Already implemented in Phase 4.1** (NoteListView updates)

**Summary**:
- Check `llmViewModel.availability` before showing insights
- Show alert if unavailable with descriptive message
- Prevent generation if Apple Intelligence not enabled

**Alert message**:
```
"Insights require iOS 18.2+ with Apple Intelligence enabled on a compatible device."
```

---

### 6.2 Selection Validation

**Already implemented in Phase 4.1** (NoteListView updates)

**Validations**:
1. **Minimum**: At least 1 note (enforced by `canGenerateInsights`)
2. **Maximum**: At most 10 notes (alert shown if exceeded)
3. **Button state**: Disabled if count invalid or already generating

**Alert message**:
```
"Please select up to 10 notes for best results. You currently have [X] selected."
```

---

### 6.3 LLM Error Handling

**Already implemented in Phase 3.2** (LLMViewModel updates)

**Error scenarios**:
1. **LanguageModelSession throws**: Caught and converted to user-friendly message
2. **Parsing fails**: Handled by FoundationModels framework (@Generable)
3. **Model unavailable**: Session initialization would fail
4. **Timeout**: System-level handling by FoundationModels

**User-facing error**:
```
"Unable to generate insights. Please try again."
```

**Developer logging**:
```swift
print("Insights generation error: \(error)")
```

---

## File Structure

### New Files (4 total)

```
TestBetaStuff/
├── Models/
│   └── Insight.swift                          [NEW] ~100 lines
└── Features/
    └── Insights/
        ├── InsightsService.swift              [NEW] ~120 lines
        ├── InsightsView.swift                 [NEW] ~140 lines
        └── InsightCard.swift                  [NEW] ~120 lines
```

### Modified Files (4 total)

```
TestBetaStuff/
├── Models/
│   └── Note.swift                             [MODIFIED] +1 property
└── Features/
    ├── Notes/
    │   ├── ViewModels/
    │   │   └── NoteViewModel.swift            [MODIFIED] +6 methods
    │   └── Views/
    │       ├── NoteListView.swift             [MODIFIED] +80 lines
    │       └── NoteCreationView.swift         [MODIFIED] +10 lines
    └── LLM/
        └── LLMViewModel.swift                 [MODIFIED] +4 methods
```

**Total lines of code**: ~570 new/modified lines

---

## Implementation Order

### Step 1: Models (30 minutes)
✅ **Goal**: Set up data structures

1. Open `TestBetaStuff/Models/Note.swift`
   - Add `var personName: String = ""`
   - Update initializer

2. Create `TestBetaStuff/Models/Insight.swift`
   - Copy complete implementation from Phase 1.2
   - Ensure `import FoundationModels` is included

3. **Test @Generable**: In LLMView, add temporary test code:
   ```swift
   Button("Test @Generable") {
     Task {
       let session = LanguageModelSession()
       let response = try await session.respond(
         to: "Generate one test insight about friendship",
         generating: InsightsResponse.self
       )
       print("Success: \(response.insights.count) insights")
     }
   }
   ```
   - Run app, tap button, verify no crashes
   - Check console for "Success: X insights"

---

### Step 2: Service Layer (1 hour)
✅ **Goal**: LLM integration working with hardcoded test data

4. Create `TestBetaStuff/Features/Insights/` directory
   - Right-click Features folder → New Group → "Insights"

5. Create `InsightsService.swift`
   - Copy complete implementation from Phase 3.1

6. Update `LLMViewModel.swift`
   - Add properties and methods from Phase 3.2
   - Keep existing `processNotes()` method (unused for now)

7. **Test with hardcoded notes**: In LLMView, temporarily add:
   ```swift
   Button("Test Service") {
     Task {
       let testNotes = [
         Note(text: "Had lunch with Sarah. She mentioned her job interview next week.", personName: "Sarah"),
         Note(text: "Sarah loves hiking and wants to visit Yosemite.", personName: "Sarah"),
         Note(text: "Need to check in on Sarah's interview.", personName: "Sarah")
       ]
       await viewModel.generateInsights(from: testNotes)
       if let insights = viewModel.insights {
         print("Generated \(insights.insights.count) insights")
       }
     }
   }
   ```
   - Run app, tap button, wait 2-3 seconds
   - Check console for insight count
   - Verify no errors

---

### Step 3: Selection UI (1.5 hours)
✅ **Goal**: User can select notes and see "Generate Insights" button

8. Update `NoteViewModel.swift`
   - Add properties and methods from Phase 2.1

9. Update `NoteCreationView.swift`
   - Add person name field from Phase 4.3
   - Update save method call

10. Update `NoteListView.swift`
    - Add all properties from Phase 4.1
    - Update navigation title
    - Add toolbar buttons (Select/Cancel + bottom toolbar)
    - Add alerts (availability, limit)
    - **DON'T add sheet yet** (InsightsView doesn't exist)

11. Update `NoteRowView` (inside NoteListView.swift)
    - Add parameters and checkbox from Phase 4.2
    - Update ForEach to pass new parameters

12. **Test selection flow**:
    - Run app, go to Notes
    - Create 3 notes with different person names
    - Tap "Select" → verify checkboxes appear
    - Tap notes → verify selection count updates in title
    - Verify "Generate Insights" button appears at bottom
    - Tap Cancel → verify checkboxes disappear

---

### Step 4: Insights Display (1.5 hours)
✅ **Goal**: Full end-to-end flow working

13. Create `InsightCard.swift`
    - Copy complete implementation from Phase 5.2
    - Build and verify no compile errors

14. Create `InsightsView.swift`
    - Copy complete implementation from Phase 5.1
    - Build and verify no compile errors

15. Update `NoteListView.swift`
    - Add sheet presentation from Phase 4.1
    - Add `handleGenerateInsights()` method

16. **Test full flow**:
    - Run app, create 2-3 notes about same person
    - Tap "Select" → select notes → tap "Generate Insights"
    - Verify insights sheet appears with loading state
    - Wait 2-3 seconds → verify insights cards appear
    - Check card colors, icons, priority badges
    - Tap "Done" → verify sheet dismisses and selection mode exits

---

### Step 5: Edge Cases & Polish (30 minutes)
✅ **Goal**: Handle errors gracefully

17. **Test availability check**:
    - If possible, disable Apple Intelligence in settings
    - Try to generate insights → verify alert appears
    - Re-enable Apple Intelligence

18. **Test validation**:
    - Select 12 notes
    - Tap "Generate Insights" → verify limit alert
    - Deselect to 8 notes → verify button works

19. **Test empty context**:
    - Create note with only "Met John"
    - Select and generate → verify empty state or minimal insights

20. **Test error handling**:
    - Turn off WiFi (shouldn't matter - on-device)
    - Enable Airplane Mode → generate insights → should still work
    - If model throws error, verify error view appears

---

## Testing Checklist

### Functional Testing

- [ ] **Note Creation**
  - [ ] Can create note with person name
  - [ ] Can create note without person name
  - [ ] Person name field auto-capitalizes
  - [ ] Person name saved correctly

- [ ] **Selection Mode**
  - [ ] "Select" button enters selection mode
  - [ ] Checkboxes appear on all notes
  - [ ] Selection count updates in navigation title
  - [ ] Tapping note toggles selection
  - [ ] Selected notes have blue background
  - [ ] "Cancel" exits selection mode and clears selection
  - [ ] Swipe actions hidden during selection mode

- [ ] **Validation**
  - [ ] "Generate Insights" disabled with 0 notes selected
  - [ ] "Generate Insights" enabled with 1-10 notes
  - [ ] Alert shown when selecting >10 notes
  - [ ] Alert shown when Apple Intelligence unavailable

- [ ] **Insights Generation**
  - [ ] Loading state appears immediately
  - [ ] Loading message displayed ("Analyzing notes...")
  - [ ] Insights generate within 3-5 seconds
  - [ ] Insights cards appear with correct data
  - [ ] Empty state shown for insufficient context

- [ ] **Insights Display**
  - [ ] Category icons correct (🔔❤️💬🎁)
  - [ ] Category colors correct (red/blue/green/purple)
  - [ ] Priority badges show and colored correctly
  - [ ] Suggested actions appear when present
  - [ ] Evidence references shown
  - [ ] Privacy indicator visible
  - [ ] Note count displayed

- [ ] **Navigation & Dismissal**
  - [ ] Sheet presents correctly
  - [ ] "Done" button dismisses sheet
  - [ ] Selection mode exits after dismissal
  - [ ] Selection cleared after dismissal
  - [ ] Can generate insights multiple times

- [ ] **Error Handling**
  - [ ] Error view appears on LLM failure
  - [ ] User-friendly error message shown
  - [ ] Can dismiss error view
  - [ ] Empty state shown for no insights

### Edge Cases

- [ ] **Single note**: Generates insights from 1 note
- [ ] **Ten notes**: Successfully processes 10 notes
- [ ] **Mixed persons**: Handles notes about different people
- [ ] **No person names**: Works without person associations
- [ ] **Very short notes**: Handles "Met Sarah" gracefully
- [ ] **Very long notes**: Handles notes >500 words
- [ ] **Special characters**: Works with emojis, accents, etc.
- [ ] **Empty person field**: Handles empty string vs nil
- [ ] **Duplicate insights**: LLM doesn't return duplicates

### Performance

- [ ] **Generation time**: 1-5 notes complete in <5 seconds
- [ ] **UI responsiveness**: No freezing during generation
- [ ] **Memory**: No crashes with 10 notes
- [ ] **Cancellation**: Closing sheet doesn't crash

### Platform Requirements

- [ ] **iOS 18.2+**: Feature works on compatible OS
- [ ] **Apple Intelligence**: Enabled and functioning
- [ ] **Compatible device**: iPhone 15 Pro or later (check Apple's device list)
- [ ] **Offline**: Works without internet connection

---

## Future Enhancements

### V2 Features (Not Implemented)
- [ ] Insight actions (Dismiss, Mark as Done)
- [ ] Insight persistence (save history)
- [ ] "Last analyzed" timestamps
- [ ] Cross-person validation (enforce single person)
- [ ] Token limit calculation (dynamic max notes)
- [ ] Streaming responses (progressive display)
- [ ] Insight filtering by category/priority
- [ ] "Analyze All People" batch mode
- [ ] System Reminders integration
- [ ] Copy insight text action
- [ ] Share insight functionality

### Polish Improvements (Not Implemented)
- [ ] Card appearance animations (stagger, slide-in)
- [ ] Dismiss/Complete animations (fade, slide-out)
- [ ] Selection mode transition animation
- [ ] Loading progress indicator (estimated time)
- [ ] Haptic feedback on selection
- [ ] VoiceOver labels and hints
- [ ] Dynamic Type support
- [ ] Dark mode color adjustments
- [ ] Accessibility audit

### Data Enhancements (Not Implemented)
- [ ] SwiftData/CoreData persistence
- [ ] Person entity with relationships
- [ ] Note tags/categories
- [ ] Insight history tracking
- [ ] Usage analytics (which categories used most)
- [ ] Feedback mechanism (thumbs up/down)

---

## Troubleshooting

### Common Issues

**Issue**: @Generable macro not recognized
- **Solution**: Ensure `import FoundationModels` at top of file
- **Solution**: Check deployment target is iOS 18.2+
- **Solution**: Clean build folder (Cmd+Shift+K)

**Issue**: "Model unavailable" error
- **Solution**: Verify Apple Intelligence enabled in Settings → Apple Intelligence & Siri
- **Solution**: Check device compatibility (iPhone 15 Pro or later)
- **Solution**: Ensure sufficient battery (>20%)
- **Solution**: Not in Low Power Mode

**Issue**: Insights return empty array
- **Solution**: Notes may lack sufficient context
- **Solution**: Try with more detailed notes
- **Solution**: Check if system prompt is too restrictive

**Issue**: Generation takes >10 seconds
- **Solution**: May indicate device thermal throttling
- **Solution**: Reduce number of selected notes
- **Solution**: Try again after device cools down

**Issue**: Sheet doesn't dismiss after Done
- **Solution**: Verify `onDismiss` callback is called
- **Solution**: Check `showInsights` binding updates
- **Solution**: Ensure `toggleSelectionMode()` is called

**Issue**: Selection count doesn't update
- **Solution**: Verify `selectedNoteIds` is `@Published`
- **Solution**: Check `toggleNoteSelection` updates Set correctly
- **Solution**: Ensure UI uses `selectedCount` computed property

---

## Code Style Guidelines

### Naming Conventions
- **Views**: `InsightsView`, `InsightCard` (singular, descriptive)
- **ViewModels**: `NoteViewModel`, `LLMViewModel` (singular + ViewModel suffix)
- **Services**: `InsightsService` (plural + Service suffix)
- **Models**: `Insight`, `Note` (singular, domain entity)

### Comments
- Use `// MARK:` to organize sections
- Add inline comments for non-obvious logic
- Document public methods with `///` doc comments

### SwiftUI Best Practices
- Extract subviews when body exceeds ~20 lines
- Use `@ViewBuilder` for conditional view logic
- Prefer `@StateObject` for initial creation
- Use `@ObservedObject` when passed from parent
- Keep views as dumb as possible (logic in ViewModels)

### Error Handling
- Log technical errors with `print()` for debugging
- Show user-friendly messages in UI
- Always provide fallback UI state

---

## Deployment Notes

### Minimum Requirements
- **iOS**: 18.2 or later
- **Xcode**: 16.0 or later
- **Device**: Apple Intelligence-compatible (iPhone 15 Pro, iPad Air M2, Mac with Apple Silicon)

### Build Settings
- Deployment Target: iOS 18.2
- Swift Language Version: Swift 5.9+
- Frameworks: FoundationModels.framework (linked automatically)

### App Store Considerations
- **Privacy**: Highlight on-device processing in App Privacy details
- **Requirements**: List Apple Intelligence requirement clearly
- **Description**: Explain insights feature benefits
- **Screenshots**: Show insights cards with sample data

---

## Success Metrics

### How to Know It's Working
1. User can select notes and generate insights in <10 taps
2. Insights appear within 5 seconds for 1-5 notes
3. At least 2-3 insights generated from rich note content
4. Zero crashes during normal usage
5. Privacy messaging clear and visible

### User Testing Questions
1. Is the selection flow intuitive?
2. Are insights actionable and relevant?
3. Is the privacy messaging reassuring?
4. Is the loading time acceptable?
5. Do category colors/icons make sense?

---

## Contact & Support

**Implementation Questions**: Refer to specific phase documentation above
**Apple Intelligence Docs**: https://developer.apple.com/documentation/foundationmodels
**WWDC Sessions**:
- "Meet the Foundation Models framework" (WWDC25-286)
- "Deep dive into the Foundation Models framework" (WWDC25-301)

---

**End of Implementation Plan**
*Last Updated: 2025-10-01*
