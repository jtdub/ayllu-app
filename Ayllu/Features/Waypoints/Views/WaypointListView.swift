import SwiftUI

/// List view for waypoints
struct WaypointListView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(LocationService.self) private var locationService

    let projectId: Int64?

    @State private var viewModel: WaypointListViewModel?
    @State private var searchText = ""

    init(projectId: Int64? = nil) {
        self.projectId = projectId
    }

    var body: some View {
        Group {
            if let viewModel = viewModel {
                WaypointListContent(viewModel: viewModel, searchText: $searchText)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Waypoints")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel?.showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search waypoints")
        .onChange(of: searchText) { _, newValue in
            viewModel?.searchText = newValue
        }
        .onAppear {
            if viewModel == nil {
                let repo = WaypointRepository(dbPool: database.dbPool)
                viewModel = WaypointListViewModel(repository: repo, projectId: projectId)
            }
            viewModel?.loadWaypoints()
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.showingCreateSheet ?? false },
            set: { viewModel?.showingCreateSheet = $0 }
        )) {
            if let projectId = projectId {
                WaypointFormView(projectId: projectId, mode: .create)
            }
        }
        .alert("Delete Waypoint?", isPresented: Binding(
            get: { viewModel?.showingDeleteConfirmation ?? false },
            set: { viewModel?.showingDeleteConfirmation = $0 }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let waypoint = viewModel?.waypointToDelete {
                    viewModel?.deleteWaypoint(waypoint)
                }
            }
        }
    }
}

// MARK: - Content View

private struct WaypointListContent: View {
    @Bindable var viewModel: WaypointListViewModel
    @Binding var searchText: String

    @AppStorage("coordinateFormat") private var coordinateFormat: CoordinateFormatter.Format = .decimal

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.isEmpty {
                ContentUnavailableView(
                    "No Waypoints",
                    systemImage: "mappin",
                    description: Text("Create a waypoint to get started")
                )
            } else if !viewModel.hasSearchResults {
                ContentUnavailableView.search(text: searchText)
            } else {
                List {
                    ForEach(viewModel.filteredWaypoints) { waypoint in
                        NavigationLink(value: waypoint) {
                            WaypointRowView(
                                waypoint: waypoint,
                                coordinateFormat: coordinateFormat
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.confirmDelete(waypoint)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationDestination(for: Waypoint.self) { waypoint in
            WaypointDetailView(waypoint: waypoint)
        }
    }
}

// MARK: - Row View

struct WaypointRowView: View {
    let waypoint: Waypoint
    let coordinateFormat: CoordinateFormatter.Format

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let category = waypoint.category {
                    Image(systemName: category.iconName)
                        .foregroundStyle(.secondary)
                }

                Text(waypoint.name)
                    .font(.headline)
            }

            Text(CoordinateFormatter.format(
                latitude: waypoint.latitude,
                longitude: waypoint.longitude,
                format: coordinateFormat
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fontDesign(.monospaced)

            HStack {
                if !waypoint.tags.isEmpty {
                    Text(waypoint.tags.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer()

                Text(dateFormatter.string(from: waypoint.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        WaypointListView(projectId: 1)
    }
}
