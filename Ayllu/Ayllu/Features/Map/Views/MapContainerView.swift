import SwiftUI
import CoreLocation

/// Container view for the map with waypoint markers
struct MapContainerView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(LocationService.self) private var locationService

    @State private var waypoints: [Waypoint] = []
    @State private var selectedWaypoint: Waypoint?
    @State private var showingOfflineManager = false
    @State private var userLocation: CLLocation?

    var body: some View {
        ZStack {
            MapLibreMapView(
                waypoints: $waypoints,
                selectedWaypoint: $selectedWaypoint,
                userLocation: $userLocation
            )
            .ignoresSafeArea(edges: .bottom)

            // Quick waypoint FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    QuickWaypointButton {
                        createQuickWaypoint()
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Map")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingOfflineManager = true
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
            }
        }
        .sheet(item: $selectedWaypoint) { waypoint in
            NavigationStack {
                WaypointDetailView(waypoint: waypoint)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingOfflineManager) {
            OfflineRegionManagerView()
        }
        .onAppear {
            loadWaypoints()
            locationService.startUpdatingLocation()
        }
        .onChange(of: locationService.currentLocation) { _, newLocation in
            userLocation = newLocation
        }
    }

    private func loadWaypoints() {
        let repo = WaypointRepository(dbPool: database.dbPool)
        waypoints = (try? repo.fetchAll()) ?? []
    }

    private func createQuickWaypoint() {
        guard let location = locationService.currentLocation else { return }

        // For now, use the first project or show a picker
        let projectRepo = ProjectRepository(dbPool: database.dbPool)
        guard let project = try? projectRepo.fetchAll().first,
              let projectId = project.id else { return }

        let waypointRepo = WaypointRepository(dbPool: database.dbPool)
        if let newWaypoint = try? waypointRepo.createQuick(projectId: projectId, location: location) {
            waypoints.insert(newWaypoint, at: 0)
        }
    }
}

// MARK: - Quick Waypoint Button

struct QuickWaypointButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white, .blue)
                .shadow(radius: 4)
        }
    }
}

#Preview {
    NavigationStack {
        MapContainerView()
    }
}
