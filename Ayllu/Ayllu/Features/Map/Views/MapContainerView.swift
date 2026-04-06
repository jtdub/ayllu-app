import SwiftUI
import CoreLocation

/// Container view for the map with waypoint markers
struct MapContainerView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(LocationService.self) private var locationService

    @AppStorage("useTrueNorth") private var useTrueNorth = false

    @State private var waypoints: [Waypoint] = []
    @State private var geometries: [Geometry] = []
    @State private var selectedWaypoint: Waypoint?
    @State private var showingOfflineManager = false
    @State private var userLocation: CLLocation?
    @State private var centerOnLocation = false

    var body: some View {
        ZStack {
            MapLibreMapView(
                waypoints: $waypoints,
                selectedWaypoint: $selectedWaypoint,
                userLocation: $userLocation,
                centerOnLocation: $centerOnLocation,
                geometries: geometries
            )
            .ignoresSafeArea(edges: .bottom)

            // Heading display overlay (top-left)
            VStack {
                HStack {
                    HeadingDisplayView(
                        heading: locationService.currentHeading,
                        showTrueNorth: useTrueNorth
                    )
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()

                    Spacer()
                }
                Spacer()
            }

            // Floating action buttons
            VStack {
                Spacer()
                HStack {
                    // Locate me button
                    LocateMeButton(hasLocation: userLocation != nil) {
                        centerOnLocation = true
                    }
                    .padding()

                    Spacer()

                    // Quick waypoint button
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
            // Initialize with current location if already available
            if userLocation == nil {
                userLocation = locationService.currentLocation
            }
            locationService.startUpdatingLocation()
            locationService.startUpdatingHeading()
        }
        .onChange(of: locationService.currentLocation) { _, newLocation in
            userLocation = newLocation
        }
    }

    private func loadWaypoints() {
        let waypointRepo = WaypointRepository(dbPool: database.dbPool)
        waypoints = (try? waypointRepo.fetchAll()) ?? []

        let geometryRepo = GeometryRepository(dbPool: database.dbPool)
        geometries = (try? geometryRepo.fetchAll()) ?? []
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
