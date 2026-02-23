import SwiftUI

/// Sheet for calculating distance between waypoints
struct DistanceCalculatorSheet: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(\.dismiss) private var dismiss

    @AppStorage("distanceUnit") private var distanceUnit: CoordinateFormatter.DistanceUnit = .meters

    let fromWaypoint: Waypoint

    @State private var waypoints: [Waypoint] = []
    @State private var selectedWaypoint: Waypoint?
    @State private var searchText = ""

    private var filteredWaypoints: [Waypoint] {
        let others = waypoints.filter { $0.id != fromWaypoint.id }
        if searchText.isEmpty {
            return others
        }
        return others.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Selected waypoint result
                if let selected = selectedWaypoint {
                    resultCard(to: selected)
                        .padding()
                }

                // Waypoint list
                List(filteredWaypoints) { waypoint in
                    Button {
                        selectedWaypoint = waypoint
                    } label: {
                        waypointRow(waypoint)
                    }
                    .listRowBackground(
                        selectedWaypoint?.id == waypoint.id ?
                        Color.accentColor.opacity(0.1) : Color.clear
                    )
                }
                .listStyle(.plain)
            }
            .navigationTitle("Distance To")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search waypoints")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadWaypoints()
            }
        }
    }

    private func loadWaypoints() {
        let repo = WaypointRepository(dbPool: database.dbPool)
        waypoints = (try? repo.fetchAll(projectId: fromWaypoint.projectId)) ?? []
    }

    @ViewBuilder
    private func resultCard(to destination: Waypoint) -> some View {
        let distance = GeoCalculator.distance(from: fromWaypoint, to: destination)
        let bearing = GeoCalculator.bearing(from: fromWaypoint, to: destination)

        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("From")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(fromWaypoint.name)
                        .font(.headline)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)

                Spacer()

                VStack(alignment: .trailing) {
                    Text("To")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(destination.name)
                        .font(.headline)
                }
            }

            Divider()

            HStack(spacing: 30) {
                VStack {
                    Text(CoordinateFormatter.formatDistance(distance, unit: distanceUnit))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("Distance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack {
                    Text(GeoCalculator.formatBearing(bearing))
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("Bearing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func waypointRow(_ waypoint: Waypoint) -> some View {
        let distance = GeoCalculator.distance(from: fromWaypoint, to: waypoint)

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if let category = waypoint.category {
                        Image(systemName: category.iconName)
                            .foregroundStyle(.secondary)
                    }
                    Text(waypoint.name)
                        .foregroundStyle(.primary)
                }

                if let description = waypoint.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(CoordinateFormatter.formatDistance(distance, unit: distanceUnit))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    DistanceCalculatorSheet(
        fromWaypoint: Waypoint(
            projectId: 1,
            name: "Start Point",
            latitude: 37.7749,
            longitude: -122.4194
        )
    )
}
