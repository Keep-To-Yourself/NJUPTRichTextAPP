import Foundation

class NoteViewModel: ObservableObject {
    @Published var notes: [Note] = []
    private let userDefaultsKey = "savedNotes"
    
    init() {
        loadNotes()
    }
    
    func addNote(title: String, content: String, attributedContent: Data? = nil) {
        let note = Note(title: title, content: content, attributedContent: attributedContent)
        notes.append(note)
        saveNotes()
    }
    
    func deleteNote(at indexSet: IndexSet) {
        notes.remove(atOffsets: indexSet)
        saveNotes()
    }
    
    func updateNote(at index: Int, title: String? = nil, content: String? = nil, attributedContent: Data? = nil) {
        guard index < notes.count else { return }
        if let newTitle = title {
            notes[index].title = newTitle
        }
        if let newContent = content {
            notes[index].content = newContent
        }
        notes[index].attributedContent = attributedContent
        saveNotes()
    }
    
    private func saveNotes() {
        if let encoded = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private func loadNotes() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([Note].self, from: data) {
            notes = decoded
        }
    }
} 