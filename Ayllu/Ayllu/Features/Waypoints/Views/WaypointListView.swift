import SwiftUI
import CoreLocation

/// List view for waypoints
struct WaypointListView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(LocationService.self) private var locationService

    let projectId: Int64?

    @State private var viewModel: WaypointListViewModel?
    @State private var searchText = ""
    @State private var selectedCategory: WaypointCategory?
    @State private var showSortByDistance = false

    init(projectId: Int64? = nil) {
        self.projectId = projectId
    }

    var body: some View {
        Group {
            if let viewModel = viewModel {
                WaypointListContent(
                    viewModel: viewModel,
                    searchText: $searchText,
                    showSortByDistance: showSortByDistance,
                    currentLocation: locationService.currentLocation
                )
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Waypoints")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        viewModel?.showingCreateSheet = true
                    } label: {
                        Label("New Waypoint", systemImage: "plus")
                    }

                    Divider()

                    Toggle(isOn: $showSortByDistance) {
                        Label("Sort by Distance", systemImage: "location")
                    }

                    Divider()

                    Menu("Filter by Category") {
                        Button {
                            selectedCategory = nil
                            viewModel?.selectedCategory = nil
                        } label: {
                            HStack {
                                Text("All Categories")
                                if selectedCategory == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        Divider()

                        ForEach(WaypointCategory.allCases, id: \.self) { category in
                            Button {
                                selectedCategory = category
                                viewModel?.selectedCategory = category
                            } label: {
                                HStack {
                                    Label(category.displayName, systemImage: category.iconName)
                                    if selectedCategory == category {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }

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
            if showSortByDistance {
                locationService.startUpdatingLocation()
            }
        }
        .onChange(of: showSortByDistance) { _, newValue in
            if newValue {
                locationService.startUpdatingLocation()
            }
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
    let showSortByDistance: Bool
    let currentLocation: CLLocation?

    @AppStorage("coordinateFormat") private var coordinateFormat: CoordinateFormatter.Format = .decimal
    @AppStorage("distanceUnit") private var distanceUnit: CoordinateFormatter.DistanceUnit = .meters

    private var sortedWaypoints: [Waypoint] {
        let waypoints = viewModel.filteredWaypoints
        guard showSortByDistance, let location = currentLocation else {
            return waypoints
        }
        return waypoints.sorted {
            GeoCalculator.distance(from: location, to: $0) <
            GeoCalculator.distance(from: location, to: $1)
        }
    }

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
                    // Category filter indicator
                    if viewModel.selectedCategory != nil {
                        CategoryFilterBanner(
                            category: viewModel.selectedCategory!,
                            onClear: { viewModel.selectedCategory = nil }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }

                    ForEach(sortedWaypoints) { waypoint in
                        NavigationLink(value: waypoint) {
                            if showSortByDistance {
                                WaypointDistanceRow(
                                    waypoint: waypoint,
                                    currentLocation: currentLocation,
                                    coordinateFormat: coordinateFormat
                                )
                            } else {
                                WaypointRowView(
                                    waypoint: waypoint,
                                    coordinateFormat: coordinateFormat
                                )
                            }
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

// MARK: - Category Filter Banner

private struct CategoryFilterBanner: View {
    let category: WaypointCategory
    let onClear: () -> Void

    var body: some View {
        HStack {
            Label(category.displayName, systemImage: category.iconName)
                .font(.subheadline)

            Spacer()

            Button {
                onClear()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.1))
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
