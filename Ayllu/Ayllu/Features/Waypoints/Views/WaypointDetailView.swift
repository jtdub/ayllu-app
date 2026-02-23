import SwiftUI
import MapKit

/// Detail view for a single waypoint
struct WaypointDetailView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(LocationService.self) private var locationService
    @Environment(\.dismiss) private var dismiss

    @AppStorage("coordinateFormat") private var coordinateFormat: CoordinateFormatter.Format = .decimal
    @AppStorage("distanceUnit") private var distanceUnit: CoordinateFormatter.DistanceUnit = .meters

    let waypoint: Waypoint

    @State private var currentWaypoint: Waypoint
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingAllFormats = false
    @State private var showingDistanceCalculator = false

    init(waypoint: Waypoint) {
        self.waypoint = waypoint
        _currentWaypoint = State(initialValue: waypoint)
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        List {
            // Map Preview Section
            Section {
                Map {
                    Marker(
                        currentWaypoint.name,
                        coordinate: currentWaypoint.coordinate
                    )
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Coordinates Section
            Section("Coordinates") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(CoordinateFormatter.format(
                        latitude: currentWaypoint.latitude,
                        longitude: currentWaypoint.longitude,
                        format: coordinateFormat
                    ))
                    .font(.system(.body, design: .monospaced))

                    Button {
                        showingAllFormats = true
                    } label: {
                        Text("Show all formats")
                            .font(.caption)
                    }
                }

                if let altitude = currentWaypoint.altitude {
                    LabeledContent(
                        "Altitude",
                        value: CoordinateFormatter.formatAltitude(altitude, unit: distanceUnit)
                    )
                }

                if let accuracy = currentWaypoint.horizontalAccuracy {
                    LabeledContent(
                        "Accuracy",
                        value: CoordinateFormatter.formatAccuracy(accuracy, unit: distanceUnit)
                    )
                }

                if let heading = currentWaypoint.heading {
                    LabeledContent("Heading", value: String(format: "%.0f°", heading))
                }
            }

            // Distance from Current Location
            if let location = locationService.currentLocation {
                Section("From Current Location") {
                    let distance = GeoCalculator.distance(from: location, to: currentWaypoint)
                    let bearing = GeoCalculator.bearing(from: location, to: currentWaypoint)

                    LabeledContent("Distance") {
                        Text(CoordinateFormatter.formatDistance(distance, unit: distanceUnit))
                            .font(.system(.body, design: .monospaced))
                    }

                    LabeledContent("Bearing") {
                        Text(GeoCalculator.formatBearing(bearing))
                            .font(.system(.body, design: .monospaced))
                    }

                    if let heading = locationService.currentHeading,
                       heading.magneticHeading >= 0 {
                        let relativeBearing = (bearing - heading.magneticHeading + 360)
                            .truncatingRemainder(dividingBy: 360)
                        LabeledContent("Relative Direction") {
                            HStack {
                                Image(systemName: "arrow.up")
                                    .rotationEffect(.degrees(relativeBearing))
                                    .foregroundStyle(.blue)
                                Text(relativeDirectionText(relativeBearing))
                            }
                        }
                    }
                }
            }

            // Details Section
            Section("Details") {
                LabeledContent("Name", value: currentWaypoint.name)

                if let description = currentWaypoint.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(description)
                    }
                }

                if let category = currentWaypoint.category {
                    LabeledContent("Category") {
                        Label(category.displayName, systemImage: category.iconName)
                    }
                }

                if !currentWaypoint.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        FlowLayout(spacing: 4) {
                            ForEach(currentWaypoint.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                LabeledContent("Created", value: dateFormatter.string(from: currentWaypoint.createdAt))
            }

            // Actions Section
            Section {
                Button {
                    copyCoordinates()
                } label: {
                    Label("Copy Coordinates", systemImage: "doc.on.doc")
                }

                Button {
                    openInMaps()
                } label: {
                    Label("Open in Maps", systemImage: "map")
                }

                Button {
                    showingDistanceCalculator = true
                } label: {
                    Label("Distance to Another Waypoint", systemImage: "arrow.left.and.right")
                }

                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit Waypoint", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Waypoint", systemImage: "trash")
                }
            }
        }
        .navigationTitle(currentWaypoint.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditSheet) {
            WaypointFormView(projectId: currentWaypoint.projectId, mode: .edit(currentWaypoint))
        }
        .sheet(isPresented: $showingAllFormats) {
            CoordinateFormatsSheet(
                latitude: currentWaypoint.latitude,
                longitude: currentWaypoint.longitude
            )
        }
        .alert("Delete Waypoint?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteWaypoint()
            }
        }
        .sheet(isPresented: $showingDistanceCalculator) {
            DistanceCalculatorSheet(fromWaypoint: currentWaypoint)
        }
        .onAppear {
            locationService.startUpdatingLocation()
            locationService.startUpdatingHeading()
        }
    }

    private func relativeDirectionText(_ bearing: Double) -> String {
        switch bearing {
        case 0..<22.5, 337.5...360:
            return "Ahead"
        case 22.5..<67.5:
            return "Ahead Right"
        case 67.5..<112.5:
            return "Right"
        case 112.5..<157.5:
            return "Behind Right"
        case 157.5..<202.5:
            return "Behind"
        case 202.5..<247.5:
            return "Behind Left"
        case 247.5..<292.5:
            return "Left"
        case 292.5..<337.5:
            return "Ahead Left"
        default:
            return ""
        }
    }

    private func copyCoordinates() {
        let text = CoordinateFormatter.format(
            latitude: currentWaypoint.latitude,
            longitude: currentWaypoint.longitude,
            format: coordinateFormat
        )
        UIPasteboard.general.string = text
    }

    private func openInMaps() {
        let coordinate = currentWaypoint.coordinate
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = currentWaypoint.name
        mapItem.openInMaps()
    }

    private func deleteWaypoint() {
        guard let id = currentWaypoint.id else { return }
        let repo = WaypointRepository(dbPool: database.dbPool)
        try? repo.delete(id: id)
        dismiss()
    }
}

// MARK: - Coordinate Formats Sheet

struct CoordinateFormatsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let latitude: Double
    let longitude: Double

    var body: some View {
        NavigationStack {
            List {
                ForEach(CoordinateFormatter.Format.allCases, id: \.self) { format in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(format.displayName)
                            .font(.headline)
                        Text(CoordinateFormatter.format(
                            latitude: latitude,
                            longitude: longitude,
                            format: format
                        ))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        UIPasteboard.general.string = CoordinateFormatter.format(
                            latitude: latitude,
                            longitude: longitude,
                            format: format
                        )
                    }
                }
            }
            .navigationTitle("Coordinate Formats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > width, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: width, height: y + rowHeight)
        }
    }
}

#Preview {
    NavigationStack {
        WaypointDetailView(waypoint: Waypoint(
            id: 1,
            projectId: 1,
            name: "Test Waypoint",
            description: "A test waypoint",
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 100,
            horizontalAccuracy: 5,
            tags: ["site", "important"]
        ))
    }
}
