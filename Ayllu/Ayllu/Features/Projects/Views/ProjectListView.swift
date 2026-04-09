import SwiftUI

/// List view for all projects
struct ProjectListView: View {
    @Environment(DatabaseManager.self) private var database
    @State private var viewModel: ProjectListViewModel?
    @State private var searchText = ""

    var body: some View {
        Group {
            if let viewModel = viewModel {
                ProjectListContent(viewModel: viewModel, searchText: $searchText)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel?.showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("addProjectButton")
            }
        }
        .searchable(text: $searchText, prompt: "Search projects")
        .onChange(of: searchText) { _, newValue in
            viewModel?.searchText = newValue
        }
        .onAppear {
            if viewModel == nil {
                let repo = ProjectRepository(dbPool: database.dbPool)
                viewModel = ProjectListViewModel(repository: repo)
            }
            viewModel?.loadProjects()
        }
        .navigationDestination(for: Project.self) { project in
            ProjectDetailView(project: project)
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.showingCreateSheet ?? false },
            set: { viewModel?.showingCreateSheet = $0 }
        )) {
            if let viewModel = viewModel {
                ProjectFormView(mode: .create) { name, description, startDate, endDate in
                    viewModel.createProject(
                        name: name,
                        description: description,
                        startDate: startDate,
                        endDate: endDate
                    )
                }
            }
        }
        .alert("Delete Project?", isPresented: Binding(
            get: { viewModel?.showingDeleteConfirmation ?? false },
            set: { viewModel?.showingDeleteConfirmation = $0 }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let project = viewModel?.projectToDelete {
                    viewModel?.deleteProject(project)
                }
            }
        } message: {
            Text("This will permanently delete the project and all its waypoints, notes, and photos.")
        }
    }
}

// MARK: - Content View

private struct ProjectListContent: View {
    @Bindable var viewModel: ProjectListViewModel
    @Binding var searchText: String

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.isEmpty {
                ContentUnavailableView(
                    "No Projects",
                    systemImage: "folder",
                    description: Text("Create a project to get started")
                )
            } else if !viewModel.hasSearchResults {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    ForEach(viewModel.filteredProjects) { project in
                        NavigationLink(value: project) {
                            ProjectRowView(
                                project: project,
                                statistics: viewModel.statistics(for: project)
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.confirmDelete(project)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Row View

struct ProjectRowView: View {
    let project: Project
    let statistics: ProjectStatistics?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.name)
                .font(.headline)

            if let description = project.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                if let stats = statistics {
                    Label("\(stats.waypointCount)", systemImage: "mappin")
                    Label("\(stats.noteCount)", systemImage: "note.text")
                    Label("\(stats.photoCount)", systemImage: "photo")
                }

                Spacer()

                if let startDate = project.startDate {
                    Text(dateFormatter.string(from: startDate))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ProjectListView()
    }
}
