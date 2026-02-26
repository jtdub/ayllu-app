import SwiftUI

/// Global search view for searching across all data types
struct GlobalSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DatabaseManager.self) private var database

    @State private var searchText = ""
    @State private var searchResults = SearchResults()
    @State private var isSearching = false
    @State private var searchService: SearchService?

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    ContentUnavailableView(
                        "Search Ayllu",
                        systemImage: "magnifyingglass",
                        description: Text("Search for projects, waypoints, and field notes")
                    )
                } else if searchResults.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    SearchResultsList(results: searchResults, searchText: searchText)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search projects, waypoints, notes...")
            .onChange(of: searchText) { _, newValue in
                performSearch(newValue)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if searchService == nil {
                    searchService = SearchService(dbPool: database.dbPool)
                }
            }
        }
    }

    private func performSearch(_ query: String) {
        guard let service = searchService else { return }

        isSearching = true
        Task {
            do {
                searchResults = try service.search(query)
            } catch {
                searchResults = SearchResults()
            }
            isSearching = false
        }
    }
}

// MARK: - Search Results List

struct SearchResultsList: View {
    let results: SearchResults
    let searchText: String

    var body: some View {
        List {
            if !results.projects.isEmpty {
                Section {
                    ForEach(results.projects) { project in
                        NavigationLink(value: SearchResultItem.project(project)) {
                            SearchResultRow(
                                icon: "folder.fill",
                                title: project.name,
                                subtitle: project.description,
                                type: "Project",
                                searchText: searchText
                            )
                        }
                    }
                } header: {
                    HStack {
                        Text("Projects")
                        Spacer()
                        Text("\(results.projects.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !results.waypoints.isEmpty {
                Section {
                    ForEach(results.waypoints) { waypoint in
                        NavigationLink(value: SearchResultItem.waypoint(waypoint)) {
                            SearchResultRow(
                                icon: "mappin.circle.fill",
                                title: waypoint.name,
                                subtitle: waypoint.description,
                                type: "Waypoint",
                                searchText: searchText
                            )
                        }
                    }
                } header: {
                    HStack {
                        Text("Waypoints")
                        Spacer()
                        Text("\(results.waypoints.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !results.notes.isEmpty {
                Section {
                    ForEach(results.notes) { note in
                        NavigationLink(value: SearchResultItem.note(note)) {
                            SearchResultRow(
                                icon: "note.text",
                                title: note.title,
                                subtitle: note.content,
                                type: "Note",
                                searchText: searchText
                            )
                        }
                    }
                } header: {
                    HStack {
                        Text("Notes")
                        Spacer()
                        Text("\(results.notes.count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationDestination(for: SearchResultItem.self) { item in
            SearchResultDetail(item: item)
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let type: String
    let searchText: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(highlightedText(title, search: searchText))
                    .font(.headline)
                    .lineLimit(1)

                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(highlightedText(subtitle, search: searchText))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(type)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func highlightedText(_ text: String, search: String) -> AttributedString {
        var attributedString = AttributedString(text)

        if let range = text.range(of: search, options: .caseInsensitive) {
            let nsRange = NSRange(range, in: text)
            if let attributedRange = Range(nsRange, in: attributedString) {
                attributedString[attributedRange].foregroundColor = .accentColor
                attributedString[attributedRange].font = .body.bold()
            }
        }

        return attributedString
    }
}

// MARK: - Search Result Detail

struct SearchResultDetail: View {
    let item: SearchResultItem

    var body: some View {
        Group {
            switch item {
            case .project(let project):
                ProjectDetailView(project: project)
            case .waypoint(let waypoint):
                WaypointDetailView(waypoint: waypoint)
            case .note(let note):
                NoteDetailView(note: note)
            }
        }
    }
}

// MARK: - Note Detail View Placeholder

struct NoteDetailView: View {
    let note: FieldNote

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(note.title)
                    .font(.title)
                    .fontWeight(.bold)

                if !note.content.isEmpty {
                    Text(note.content)
                        .font(.body)
                }

                if let transcription = note.transcription, !transcription.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcription")
                            .font(.headline)
                        Text(transcription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Note")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    GlobalSearchView()
}
