import SwiftUI

/// Main tab bar navigation for the app
struct TabBarView: View {
    @State private var selectedTab: Tab = .projects
    @State private var showingSearch = false

    enum Tab: String, CaseIterable {
        case projects = "Projects"
        case map = "Map"
        case notes = "Notes"
        case settings = "Settings"

        var iconName: String {
            switch self {
            case .projects: return "folder"
            case .map: return "map"
            case .notes: return "note.text"
            case .settings: return "gear"
            }
        }

        var selectedIconName: String {
            switch self {
            case .projects: return "folder.fill"
            case .map: return "map.fill"
            case .notes: return "note.text"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ProjectListView()
                    .navigationDestination(for: Project.self) { project in
                        ProjectDetailView(project: project)
                    }
                    .navigationDestination(for: Waypoint.self) { waypoint in
                        WaypointDetailView(waypoint: waypoint)
                    }
                    .navigationDestination(for: Track.self) { track in
                        TrackDetailView(track: track)
                    }
                    .navigationDestination(for: Photo.self) { photo in
                        PhotoDetailView(photo: photo)
                    }
                    .navigationDestination(for: FieldNote.self) { note in
                        NoteEditorView(projectId: note.projectId, existingNote: note)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showingSearch = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            NetworkStatusIndicator()
                        }
                    }
            }
            .tabItem {
                Label(
                    Tab.projects.rawValue,
                    systemImage: selectedTab == .projects
                        ? Tab.projects.selectedIconName
                        : Tab.projects.iconName
                )
            }
            .tag(Tab.projects)

            NavigationStack {
                MapContainerView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            NetworkStatusIndicator()
                        }
                    }
            }
            .tabItem {
                Label(
                    Tab.map.rawValue,
                    systemImage: selectedTab == .map
                        ? Tab.map.selectedIconName
                        : Tab.map.iconName
                )
            }
            .tag(Tab.map)

            NavigationStack {
                NoteListView()
                    .navigationDestination(for: FieldNote.self) { note in
                        NoteEditorView(projectId: note.projectId, existingNote: note)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showingSearch = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            NetworkStatusIndicator()
                        }
                    }
            }
            .tabItem {
                Label(
                    Tab.notes.rawValue,
                    systemImage: selectedTab == .notes
                        ? Tab.notes.selectedIconName
                        : Tab.notes.iconName
                )
            }
            .tag(Tab.notes)

            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            NetworkStatusIndicator()
                        }
                    }
            }
            .tabItem {
                Label(
                    Tab.settings.rawValue,
                    systemImage: selectedTab == .settings
                        ? Tab.settings.selectedIconName
                        : Tab.settings.iconName
                )
            }
            .tag(Tab.settings)
        }
        .sheet(isPresented: $showingSearch) {
            GlobalSearchView()
        }
    }
}

#Preview {
    TabBarView()
}
