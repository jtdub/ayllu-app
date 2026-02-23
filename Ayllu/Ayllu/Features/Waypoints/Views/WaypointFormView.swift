import SwiftUI
import CoreLocation

/// Form for creating or editing a waypoint
struct WaypointFormView: View {
    enum Mode {
        case create
        case edit(Waypoint)

        var title: String {
            switch self {
            case .create: return "New Waypoint"
            case .edit: return "Edit Waypoint"
            }
        }
    }

    @Environment(DatabaseManager.self) private var database
    @Environment(LocationService.self) private var locationService
    @Environment(\.dismiss) private var dismiss

    let projectId: Int64
    let mode: Mode

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var latitude: String = ""
    @State private var longitude: String = ""
    @State private var altitude: String = ""
    @State private var category: WaypointCategory?
    @State private var tagsText: String = ""
    @State private var isUsingCurrentLocation: Bool = true

    init(projectId: Int64, mode: Mode) {
        self.projectId = projectId
        self.mode = mode

        if case .edit(let waypoint) = mode {
            _name = State(initialValue: waypoint.name)
            _description = State(initialValue: waypoint.description ?? "")
            _latitude = State(initialValue: String(format: "%.6f", waypoint.latitude))
            _longitude = State(initialValue: String(format: "%.6f", waypoint.longitude))
            _altitude = State(initialValue: waypoint.altitude.map { String(format: "%.1f", $0) } ?? "")
            _category = State(initialValue: waypoint.category)
            _tagsText = State(initialValue: waypoint.tags.joined(separator: ", "))
            _isUsingCurrentLocation = State(initialValue: false)
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (isUsingCurrentLocation && locationService.currentLocation != nil) ||
        (!isUsingCurrentLocation && isValidCoordinates)
    }

    private var isValidCoordinates: Bool {
        guard let lat = Double(latitude), let lon = Double(longitude) else {
            return false
        }
        return CoordinateFormatter.isValidCoordinate(latitude: lat, longitude: lon)
    }

    private var currentLocationText: String {
        guard let location = locationService.currentLocation else {
            return "Waiting for GPS..."
        }
        return CoordinateFormatter.format(coordinate: location.coordinate, format: .decimal)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Waypoint Details") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)

                    Picker("Category", selection: $category) {
                        Text("None").tag(nil as WaypointCategory?)
                        ForEach(WaypointCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.iconName)
                                .tag(cat as WaypointCategory?)
                        }
                    }
                }

                Section("Location") {
                    if case .create = mode {
                        Toggle("Use Current Location", isOn: $isUsingCurrentLocation)
                    }

                    if isUsingCurrentLocation {
                        HStack {
                            Text(currentLocationText)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)

                            Spacer()

                            if locationService.currentLocation != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                ProgressView()
                            }
                        }

                        if let accuracy = locationService.horizontalAccuracy {
                            LabeledContent("Accuracy") {
                                Text(CoordinateFormatter.formatAccuracy(accuracy, unit: .meters))
                                    .foregroundStyle(locationService.signalQuality.color == "green" ? .green : .orange)
                            }
                        }
                    } else {
                        TextField("Latitude", text: $latitude)
                            .keyboardType(.decimalPad)

                        TextField("Longitude", text: $longitude)
                            .keyboardType(.decimalPad)

                        TextField("Altitude (optional)", text: $altitude)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Tags") {
                    TextField("Tags (comma separated)", text: $tagsText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if case .create = mode {
                    locationService.startUpdatingLocation()
                    generateDefaultName()
                }
            }
        }
    }

    private func generateDefaultName() {
        let repo = WaypointRepository(dbPool: database.dbPool)
        let count = (try? repo.countForProject(projectId)) ?? 0
        name = String(format: "WP-%03d", count + 1)
    }

    private func save() {
        guard let locationData = resolveLocationData() else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = parseTags()
        let repo = WaypointRepository(dbPool: database.dbPool)

        switch mode {
        case .create:
            let waypoint = buildWaypoint(
                name: trimmedName,
                description: trimmedDescription,
                locationData: locationData,
                tags: tags
            )
            _ = try? repo.create(waypoint)

        case .edit(var existing):
            existing.name = trimmedName
            existing.description = trimmedDescription.isEmpty ? nil : trimmedDescription
            existing.latitude = locationData.lat
            existing.longitude = locationData.lon
            existing.altitude = locationData.alt
            existing.tags = tags
            existing.category = category
            _ = try? repo.update(existing)
        }

        dismiss()
    }

    private struct LocationData {
        let lat: Double
        let lon: Double
        var alt: Double?
        var hAccuracy: Double?
        var vAccuracy: Double?
        var heading: Double?
        var speed: Double?
    }

    private func resolveLocationData() -> LocationData? {
        if isUsingCurrentLocation, let location = locationService.currentLocation {
            return LocationData(
                lat: location.coordinate.latitude,
                lon: location.coordinate.longitude,
                alt: location.altitude,
                hAccuracy: location.horizontalAccuracy,
                vAccuracy: location.verticalAccuracy,
                heading: location.course >= 0 ? location.course : nil,
                speed: location.speed >= 0 ? location.speed : nil
            )
        } else {
            guard let parsedLat = Double(latitude),
                  let parsedLon = Double(longitude) else {
                return nil
            }
            return LocationData(lat: parsedLat, lon: parsedLon, alt: Double(altitude))
        }
    }

    private func parseTags() -> [String] {
        tagsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func buildWaypoint(
        name: String,
        description: String,
        locationData: LocationData,
        tags: [String]
    ) -> Waypoint {
        Waypoint(
            projectId: projectId,
            name: name,
            description: description.isEmpty ? nil : description,
            latitude: locationData.lat,
            longitude: locationData.lon,
            altitude: locationData.alt,
            horizontalAccuracy: locationData.hAccuracy,
            verticalAccuracy: locationData.vAccuracy,
            heading: locationData.heading,
            speed: locationData.speed,
            tags: tags,
            category: category
        )
    }
}

#Preview {
    WaypointFormView(projectId: 1, mode: .create)
}
