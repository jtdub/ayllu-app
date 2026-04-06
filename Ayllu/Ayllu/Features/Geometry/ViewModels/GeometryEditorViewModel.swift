import Foundation
import CoreLocation
import GRDB

/// ViewModel for drawing and editing geometries (polygons/polylines)
@Observable
final class GeometryEditorViewModel {
    private let dbPool: DatabasePool
    private let locationService: LocationService

    let projectId: Int64
    var existingGeometry: Geometry?

    var name = ""
    var description = ""
    var geometryType: GeometryType = .polygon
    var vertices: [CLLocationCoordinate2D] = []
    var linkedRecordId: Int64?
    var fillColor = "#007AFF40"
    var strokeColor = "#007AFF"
    var isTracing = false
    var error: String?

    private var lastTraceLocation: CLLocation?
    private let traceDistanceThreshold: Double = 5.0 // meters

    init(dbPool: DatabasePool, locationService: LocationService, projectId: Int64) {
        self.dbPool = dbPool
        self.locationService = locationService
        self.projectId = projectId
    }

    // MARK: - Computed Properties

    var area: Double? {
        guard geometryType == .polygon, vertices.count >= 3 else { return nil }
        return GeoCalculator.polygonArea(coordinates: vertices)
    }

    var perimeter: Double {
        if geometryType == .polygon && vertices.count >= 3 {
            return GeoCalculator.polygonPerimeter(coordinates: vertices)
        } else if vertices.count >= 2 {
            return GeoCalculator.polylineLength(coordinates: vertices)
        }
        return 0
    }

    var isValid: Bool {
        let minVertices = geometryType == .polygon ? 3 : 2
        return !name.trimmingCharacters(in: .whitespaces).isEmpty && vertices.count >= minVertices
    }

    var formattedArea: String? {
        guard let area else { return nil }
        return GeoCalculator.formatArea(area)
    }

    var formattedPerimeter: String {
        GeoCalculator.formatLength(perimeter)
    }

    // MARK: - Vertex Management

    func addVertex(_ coordinate: CLLocationCoordinate2D) {
        vertices.append(coordinate)
    }

    func removeVertex(at index: Int) {
        guard index >= 0 && index < vertices.count else { return }
        vertices.remove(at: index)
    }

    func moveVertex(at index: Int, to coordinate: CLLocationCoordinate2D) {
        guard index >= 0 && index < vertices.count else { return }
        vertices[index] = coordinate
    }

    func undoLastVertex() {
        guard !vertices.isEmpty else { return }
        vertices.removeLast()
    }

    // MARK: - GPS Trace

    func startGPSTrace() {
        isTracing = true
        lastTraceLocation = nil
        locationService.startUpdatingLocation()
    }

    func stopGPSTrace() {
        isTracing = false
        lastTraceLocation = nil
    }

    func processTraceLocation(_ location: CLLocation) {
        guard isTracing else { return }
        guard location.horizontalAccuracy <= 20 else { return } // Only use accurate fixes

        if let last = lastTraceLocation {
            let distance = location.distance(from: last)
            guard distance >= traceDistanceThreshold else { return }
        }

        lastTraceLocation = location
        vertices.append(location.coordinate)
    }

    // MARK: - Save

    func save() -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return false }

        let coordinates = Geometry.geoJSONCoordinates(from: vertices)
        let repo = GeometryRepository(dbPool: dbPool)

        do {
            if var existing = existingGeometry {
                existing.name = trimmedName
                existing.description = description.isEmpty ? nil : description
                existing.geometryType = geometryType
                existing.coordinates = coordinates
                existing.area = area
                existing.perimeter = perimeter
                existing.fillColor = fillColor
                existing.strokeColor = strokeColor
                existing.recordId = linkedRecordId
                try repo.update(existing)
            } else {
                let geometry = Geometry(
                    projectId: projectId,
                    recordId: linkedRecordId,
                    name: trimmedName,
                    description: description.isEmpty ? nil : description,
                    geometryType: geometryType,
                    coordinates: coordinates,
                    area: area,
                    perimeter: perimeter,
                    fillColor: fillColor,
                    strokeColor: strokeColor
                )
                try repo.create(geometry)
            }
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Load Existing

    func loadExisting(_ geometry: Geometry) {
        existingGeometry = geometry
        name = geometry.name
        description = geometry.description ?? ""
        geometryType = geometry.geometryType
        vertices = geometry.clLocationCoordinates
        linkedRecordId = geometry.recordId
        fillColor = geometry.fillColor ?? "#007AFF40"
        strokeColor = geometry.strokeColor ?? "#007AFF"
    }
}
