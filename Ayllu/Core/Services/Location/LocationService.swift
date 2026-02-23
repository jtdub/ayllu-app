import Foundation
import CoreLocation
import Combine

/// Service for managing location updates using CLLocationManager
@Observable
final class LocationService: NSObject {
    // MARK: - Published State

    /// Current location (nil if not yet determined)
    private(set) var currentLocation: CLLocation?

    /// Current authorization status
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// Current heading (nil if not available)
    private(set) var currentHeading: CLHeading?

    /// Whether location services are currently updating
    private(set) var isUpdatingLocation: Bool = false

    /// Last error encountered
    private(set) var lastError: Error?

    // MARK: - Private Properties

    private let locationManager: CLLocationManager
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    // MARK: - Computed Properties

    /// Whether location services are authorized
    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    /// Whether "Always" authorization is granted
    var hasAlwaysAuthorization: Bool {
        authorizationStatus == .authorizedAlways
    }

    /// Current coordinate (nil if no location)
    var currentCoordinate: CLLocationCoordinate2D? {
        currentLocation?.coordinate
    }

    /// Horizontal accuracy in meters (nil if no location)
    var horizontalAccuracy: Double? {
        currentLocation?.horizontalAccuracy
    }

    /// Signal quality description
    var signalQuality: SignalQuality {
        guard let accuracy = horizontalAccuracy else { return .none }
        switch accuracy {
        case ..<5: return .excellent
        case ..<10: return .good
        case ..<25: return .fair
        case ..<50: return .poor
        default: return .veryPoor
        }
    }

    // MARK: - Initialization

    override init() {
        locationManager = CLLocationManager()
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 1  // Update every meter

        // Get initial authorization status
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Authorization

    /// Requests "When In Use" location authorization
    func requestWhenInUseAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Requests "Always" location authorization
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    // MARK: - Location Updates

    /// Starts updating location
    func startUpdatingLocation() {
        guard isAuthorized else {
            requestWhenInUseAuthorization()
            return
        }

        isUpdatingLocation = true
        lastError = nil
        locationManager.startUpdatingLocation()
    }

    /// Stops updating location
    func stopUpdatingLocation() {
        isUpdatingLocation = false
        locationManager.stopUpdatingLocation()
    }

    /// Gets a single location update
    func requestLocation() async throws -> CLLocation {
        guard isAuthorized else {
            throw LocationError.notAuthorized
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    // MARK: - Heading Updates

    /// Starts updating heading (compass)
    func startUpdatingHeading() {
        guard CLLocationManager.headingAvailable() else { return }
        locationManager.startUpdatingHeading()
    }

    /// Stops updating heading
    func stopUpdatingHeading() {
        #if os(iOS)
        locationManager.stopUpdatingHeading()
        #endif
    }

    // MARK: - Background Location

    /// Enables background location updates (requires "Always" authorization)
    func enableBackgroundUpdates() {
        guard hasAlwaysAuthorization else { return }
        #if os(iOS)
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
        #endif
    }

    /// Disables background location updates
    func disableBackgroundUpdates() {
        #if os(iOS)
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
        #endif
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }

        // Filter out old or inaccurate locations
        let age = -location.timestamp.timeIntervalSinceNow
        guard age < 10, location.horizontalAccuracy >= 0 else { return }

        currentLocation = location

        // Fulfill any pending single-location request
        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(returning: location)
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        lastError = error

        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(throwing: error)
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {
        authorizationStatus = status

        // Start updating if just authorized
        if isAuthorized && !isUpdatingLocation {
            startUpdatingLocation()
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateHeading newHeading: CLHeading
    ) {
        // Only use heading if accurate
        guard newHeading.headingAccuracy >= 0 else { return }
        currentHeading = newHeading
    }
}

// MARK: - Supporting Types

enum SignalQuality: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case veryPoor = "Very Poor"
    case none = "No Signal"

    var color: String {
        switch self {
        case .excellent, .good: return "green"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .veryPoor, .none: return "red"
        }
    }

    var iconName: String {
        switch self {
        case .excellent: return "antenna.radiowaves.left.and.right"
        case .good: return "antenna.radiowaves.left.and.right"
        case .fair: return "antenna.radiowaves.left.and.right"
        case .poor: return "antenna.radiowaves.left.and.right.slash"
        case .veryPoor, .none: return "antenna.radiowaves.left.and.right.slash"
        }
    }
}

enum LocationError: LocalizedError {
    case notAuthorized
    case locationUnavailable
    case timeout

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Location access not authorized"
        case .locationUnavailable:
            return "Location is currently unavailable"
        case .timeout:
            return "Location request timed out"
        }
    }
}
