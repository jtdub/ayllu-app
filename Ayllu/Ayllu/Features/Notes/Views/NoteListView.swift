import SwiftUI

/// List view for field notes
struct NoteListView: View {
    @Environment(DatabaseManager.self) private var database

    let projectId: Int64?

    @State private var notes: [FieldNote] = []
    @State private var searchText = ""
    @State private var showingCreateSheet = false
    @State private var selectedProjectIdForNote: Int64?
    @State private var showingNoteEditor = false
    @State private var isLoading = false
    @State private var error: Error?

    init(projectId: Int64? = nil) {
        self.projectId = projectId
    }

    private var filteredNotes: [FieldNote] {
        if searchText.isEmpty {
            return notes
        }
        return notes.filter { note in
            note.title.localizedCaseInsensitiveContains(searchText) ||
            note.content.localizedCaseInsensitiveContains(searchText) ||
            (note.transcription?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if notes.isEmpty {
                ContentUnavailableView(
                    "No Notes",
                    systemImage: "note.text",
                    description: Text("Create a note to get started")
                )
            } else if filteredNotes.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    ForEach(filteredNotes) { note in
                        NavigationLink(value: note) {
                            NoteRowView(note: note)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteNote(note)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search notes")
        .onAppear {
            loadNotes()
        }
        .navigationDestination(for: FieldNote.self) { note in
            NoteEditorView(projectId: note.projectId, existingNote: note)
        }
        .sheet(
            isPresented: $showingCreateSheet,
            onDismiss: {
                loadNotes()
            },
            content: {
                if let projectId = projectId {
                    NoteEditorView(projectId: projectId, existingNote: nil)
                } else {
                    ProjectPickerView { selectedId in
                        selectedProjectIdForNote = selectedId
                        showingCreateSheet = false
                        showingNoteEditor = true
                    }
                }
            }
        )
        .sheet(
            isPresented: $showingNoteEditor,
            onDismiss: {
                selectedProjectIdForNote = nil
                loadNotes()
            },
            content: {
                if let projectId = selectedProjectIdForNote {
                    NoteEditorView(projectId: projectId, existingNote: nil)
                }
            }
        )
    }

    private func loadNotes() {
        isLoading = true
        let repo = NoteRepository(dbPool: database.dbPool)
        do {
            notes = try repo.fetchAll(projectId: projectId)
        } catch {
            self.error = error
        }
        isLoading = false
    }

    private func deleteNote(_ note: FieldNote) {
        guard let id = note.id else { return }
        let repo = NoteRepository(dbPool: database.dbPool)
        do {
            try repo.delete(id: id)
            withAnimation {
                notes.removeAll { $0.id == id }
            }
        } catch {
            self.error = error
        }
    }
}

// MARK: - Row View

struct NoteRowView: View {
    let note: FieldNote

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.title)
                    .font(.headline)

                Spacer()

                if note.hasAudio {
                    Image(systemName: "waveform")
                        .foregroundStyle(.secondary)
                }
            }

            if !note.content.isEmpty {
                Text(note.content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else if let transcription = note.transcription, !transcription.isEmpty {
                Text(transcription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(dateFormatter.string(from: note.createdAt))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        NoteListView(projectId: 1)
    }
}
