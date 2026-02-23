import Foundation
import CoreGPX

/// Service for exporting waypoints to GPX format
struct GPXExporter {
    /// Export options for customizing GPX output
    struct Options {
        var includeExtensions: Bool = true
        var includeAccuracy: Bool = true
        var creator: String = "Ayllu Field Research"

        static let `default` = Self()
    }

    // MARK: - Export Methods

    /// Exports waypoints to a GPX string
    func export(waypoints: [Waypoint], project: Project? = nil, options: Options = .default) -> String {
        let root = createGPXRoot(waypoints: waypoints, project: project, options: options)
        return root.gpx()
    }

    /// Exports waypoints to a GPX file at the specified URL
    func export(
        waypoints: [Waypoint],
        project: Project? = nil,
        to fileURL: URL,
        options: Options = .default
    ) throws {
        let gpxString = export(waypoints: waypoints, project: project, options: options)
        try gpxString.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// Exports waypoints and returns a temporary file URL for sharing
    func exportForSharing(
        waypoints: [Waypoint],
        project: Project? = nil,
        fileName: String? = nil,
        options: Options = .default
    ) throws -> URL {
        let name = fileName ?? generateFileName(project: project)
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(name).gpx")

        try export(waypoints: waypoints, project: project, to: fileURL, options: options)
        return fileURL
    }

    // MARK: - Private Methods

    private func createGPXRoot(
        waypoints: [Waypoint],
        project: Project?,
        options: Options
    ) -> GPXRoot {
        let root = GPXRoot(creator: options.creator)

        // Add metadata if project is provided
        if let project = project {
            let metadata = GPXMetadata()
            metadata.name = project.name
            metadata.desc = project.description
            metadata.time = project.createdAt
            root.metadata = metadata
        }

        // Convert waypoints
        for waypoint in waypoints {
            let gpxWaypoint = createGPXWaypoint(from: waypoint, options: options)
            root.add(waypoint: gpxWaypoint)
        }

        return root
    }

    private func createGPXWaypoint(from waypoint: Waypoint, options: Options) -> GPXWaypoint {
        let gpxWaypoint = GPXWaypoint(latitude: waypoint.latitude, longitude: waypoint.longitude)

        // Core attributes
        gpxWaypoint.name = waypoint.name
        gpxWaypoint.desc = waypoint.description
        gpxWaypoint.time = waypoint.createdAt
        gpxWaypoint.elevation = waypoint.altitude

        // Category as type
        if let category = waypoint.category {
            gpxWaypoint.type = category.displayName
        }

        // Symbol based on category
        gpxWaypoint.symbol = symbolForCategory(waypoint.category)

        // Comment with tags
        if !waypoint.tags.isEmpty {
            gpxWaypoint.comment = "Tags: \(waypoint.tags.joined(separator: ", "))"
        }

        // Add extensions for custom fields and accuracy
        if options.includeExtensions && shouldAddExtensions(waypoint: waypoint, options: options) {
            gpxWaypoint.extensions = createExtensions(for: waypoint, options: options)
        }

        return gpxWaypoint
    }

    private func shouldAddExtensions(waypoint: Waypoint, options: Options) -> Bool {
        if !waypoint.customFields.isEmpty { return true }
        if options.includeAccuracy {
            if waypoint.horizontalAccuracy != nil { return true }
            if waypoint.verticalAccuracy != nil { return true }
            if waypoint.heading != nil { return true }
            if waypoint.speed != nil { return true }
        }
        return false
    }

    private func createExtensions(for waypoint: Waypoint, options: Options) -> GPXExtensions {
        let extensions = GPXExtensions()

        // Add accuracy data
        if options.includeAccuracy {
            if let hAcc = waypoint.horizontalAccuracy {
                extensions.append(at: nil, contents: ["ayllu:horizontalAccuracy": String(format: "%.2f", hAcc)])
            }
            if let vAcc = waypoint.verticalAccuracy {
                extensions.append(at: nil, contents: ["ayllu:verticalAccuracy": String(format: "%.2f", vAcc)])
            }
            if let heading = waypoint.heading {
                extensions.append(at: nil, contents: ["ayllu:heading": String(format: "%.1f", heading)])
            }
            if let speed = waypoint.speed {
                extensions.append(at: nil, contents: ["ayllu:speed": String(format: "%.2f", speed)])
            }
        }

        // Add custom fields
        for (key, value) in waypoint.customFields {
            let safeKey = key.replacingOccurrences(of: " ", with: "_")
            extensions.append(at: nil, contents: ["ayllu:\(safeKey)": value])
        }

        return extensions
    }

    private func symbolForCategory(_ category: WaypointCategory?) -> String {
        guard let category = category else { return "Waypoint" }

        switch category {
        case .site: return "City (Large)"
        case .feature: return "Building"
        case .artifact: return "Museum"
        case .sample: return "Drinking Water"
        case .photoPoint: return "Scenic Area"
        case .controlPoint: return "Crossing"
        case .datum: return "Navaid, Red"
        case .observation: return "Binoculars"
        case .specimen: return "Forest"
        case .transectMarker: return "Trail Head"
        case .other: return "Waypoint"
        }
    }

    private func generateFileName(project: Project?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        if let projectName = project?.name {
            let safeName = projectName
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "/", with: "-")
            return "\(safeName)_\(timestamp)"
        }

        return "ayllu_export_\(timestamp)"
    }
}
