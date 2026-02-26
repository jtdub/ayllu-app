import SwiftUI

/// App color definitions
extension Color {
    // MARK: - Brand Colors

    static let aylluPrimary = Color.blue
    static let aylluSecondary = Color.teal

    // MARK: - Semantic Colors

    static let waypointDefault = Color.red
    static let waypointSite = Color.purple
    static let waypointFeature = Color.blue
    static let waypointArtifact = Color.orange
    static let waypointSample = Color.green
    static let waypointPhoto = Color.yellow
    static let waypointControl = Color.primary
    static let waypointObservation = Color.cyan
    static let waypointSpecimen = Color.mint
    static let waypointTransect = Color.indigo

    // MARK: - Status Colors

    static let gpsExcellent = Color.green
    static let gpsGood = Color.green
    static let gpsFair = Color.yellow
    static let gpsPoor = Color.orange
    static let gpsNone = Color.red

    static let downloadComplete = Color.green
    static let downloadActive = Color.blue
    static let downloadPending = Color.gray
    static let downloadPaused = Color.orange
    static let downloadFailed = Color.red

    // MARK: - Waypoint Category Colors

    static func waypointColor(for category: WaypointCategory?) -> Color {
        guard let category = category else { return .waypointDefault }
        switch category {
        case .site: return .waypointSite
        case .feature: return .waypointFeature
        case .artifact: return .waypointArtifact
        case .sample: return .waypointSample
        case .photoPoint: return .waypointPhoto
        case .controlPoint, .datum: return .waypointControl
        case .observation: return .waypointObservation
        case .specimen: return .waypointSpecimen
        case .transectMarker: return .waypointTransect
        case .other: return .waypointDefault
        }
    }
}

// MARK: - GPS Signal Quality Colors

extension SignalQuality {
    var uiColor: Color {
        switch self {
        case .excellent, .good: return .gpsExcellent
        case .fair: return .gpsFair
        case .poor: return .gpsPoor
        case .veryPoor, .none: return .gpsNone
        }
    }
}

// MARK: - Download Status Colors

extension DownloadStatus {
    var uiColor: Color {
        switch self {
        case .complete: return .downloadComplete
        case .downloading: return .downloadActive
        case .pending: return .downloadPending
        case .paused: return .downloadPaused
        case .failed: return .downloadFailed
        }
    }
}
