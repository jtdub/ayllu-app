import Foundation
import CoreLocation
import Observation

/// Service that coordinates LocationService updates with TrackRepository
/// Handles GPS track recording with background support and battery optimization
@Observable
final class TrackRecordingService {
    // MARK: - State

    /// Current track being recorded
    private(set) var currentTrack: Track?

    /// Whether recording is active
    private(set) var isRecording: Bool = false

    /// Whether recording is paused
    private(set) var isPaused: Bool = false

    /// Live distance in meters (updated as points are recorded)
    private(set) var liveDistance: Double = 0

    /// Live duration in seconds
    private(set) var liveDuration: TimeInterval = 0

    /// Current speed in m/s
    private(set) var currentSpeed: Double = 0

    /// Current elevation in meters
    private(set) var currentElevation: Double?

    /// Number of points recorded so far
    private(set) var pointCount: Int = 0

    /// Current segment index (increments on pause/resume)
    private(set) var currentSegmentIndex: Int = 0

    // MARK: - Dependencies

    private let repository: TrackRepository
    private let locationService: LocationService

    // MARK: - Private State

    private var locationObserver: Task<Void, Never>?
    private var batchTimer: Timer?
    private var pendingPoints: [TrackPoint] = []
    private var lastLocation: CLLocation?
    private var startTime: Date?

    // MARK: - Configuration

    private let batchSize = 10  // Flush every 10 points
    private let batchInterval: TimeInterval = 10  // Or every 10 seconds
    private let minimumAccuracy: Double = 50  // Filter points with accuracy > 50m

    // MARK: - Initialization

    init(repository: TrackRepository, locationService: LocationService) {
        self.repository = repository
        self.locationService = locationService
    }

    deinit {
        stopObserving()
    }

    // MARK: - Recording Control

    /// Starts a new GPS track recording
    func startRecording(projectId: Int64, name: String? = nil) async throws {
        guard !isRecording else { return }

        // Create track in database
        let track = try repository.startRecording(projectId: projectId, name: name)
        currentTrack = track

        // Request "Always" authorization for background recording
        if !locationService.hasAlwaysAuthorization {
            locationService.requestAlwaysAuthorization()
        }

        // Enable background location
        locationService.enableBackgroundUpdates()

        // Start location updates
        locationService.startUpdatingLocation()

        // Reset state
        isRecording = true
        isPaused = false
        currentSegmentIndex = 0
        pendingPoints = []
        liveDistance = 0
        liveDuration = 0
        pointCount = 0
        lastLocation = nil
        startTime = Date()

        // Start observing location updates
        startObserving()

        // Start batch timer
        startBatchTimer()
    }

    /// Pauses recording (increments segment index)
    func pauseRecording() async {
        guard isRecording, !isPaused else { return }

        isPaused = true
        currentSegmentIndex += 1

        // Flush any pending points
        await flushPendingPoints()

        // Stop location updates to save battery
        locationService.stopUpdatingLocation()
    }

    /// Resumes recording after pause
    func resumeRecording() {
        guard isRecording, isPaused else { return }

        isPaused = false
        lastLocation = nil  // Reset to avoid false distance between pause and resume

        // Restart location updates
        locationService.startUpdatingLocation()
    }

    /// Stops recording and saves the track with calculated statistics
    func stopRecording() async throws -> Track? {
        guard isRecording, let trackId = currentTrack?.id else { return nil }

        // Flush remaining points
        await flushPendingPoints()

        // Stop observing
        stopObserving()

        // Disable background location
        locationService.disableBackgroundUpdates()

        // Calculate final statistics
        let completedTrack = try repository.stopRecording(trackId: trackId)

        // Cleanup
        isRecording = false
        isPaused = false
        currentTrack = nil
        liveDistance = 0
        liveDuration = 0
        pointCount = 0
        currentSegmentIndex = 0
        lastLocation = nil
        startTime = nil

        return completedTrack
    }

    /// Cancels recording without saving
    func cancelRecording() async throws {
        guard isRecording, let trackId = currentTrack?.id else { return }

        // Stop observing
        stopObserving()

        // Disable background location
        locationService.disableBackgroundUpdates()

        // Delete the track
        try repository.deleteTrack(id: trackId)

        // Cleanup
        isRecording = false
        isPaused = false
        currentTrack = nil
        pendingPoints.removeAll()
        liveDistance = 0
        liveDuration = 0
        pointCount = 0
        currentSegmentIndex = 0
        lastLocation = nil
        startTime = nil
    }

    // MARK: - Private Methods

    private func startObserving() {
        locationObserver = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }

                if self.isRecording && !self.isPaused,
                   let location = self.locationService.currentLocation {
                    await self.processLocationUpdate(location)
                }

                // Check every second
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func stopObserving() {
        locationObserver?.cancel()
        locationObserver = nil
        batchTimer?.invalidate()
        batchTimer = nil
    }

    private func startBatchTimer() {
        batchTimer = Timer.scheduledTimer(withTimeInterval: batchInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.flushPendingPoints()
            }
        }
    }

    private func processLocationUpdate(_ location: CLLocation) {
        // Filter bad GPS
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy < minimumAccuracy else {
            return
        }

        // Don't record duplicate locations
        if let last = lastLocation,
           last.coordinate.latitude == location.coordinate.latitude,
           last.coordinate.longitude == location.coordinate.longitude {
            return
        }

        // Create track point
        guard let trackId = currentTrack?.id else { return }

        let point = TrackPoint.from(
            location: location,
            trackId: trackId,
            segmentIndex: currentSegmentIndex
        )

        // Add to buffer
        pendingPoints.append(point)
        pointCount += 1

        // Update live stats
        if let last = lastLocation {
            liveDistance += location.distance(from: last)
        }
        lastLocation = location
        currentSpeed = location.speed >= 0 ? location.speed : 0
        currentElevation = location.altitude

        if let start = startTime {
            liveDuration = Date().timeIntervalSince(start)
        }

        // Flush if buffer full
        if pendingPoints.count >= batchSize {
            Task {
                await flushPendingPoints()
            }
        }
    }

    private func flushPendingPoints() async {
        guard !pendingPoints.isEmpty else { return }

        let pointsToWrite = pendingPoints
        pendingPoints.removeAll()

        // Write to database in background
        await Task.detached(priority: .utility) {
            for point in pointsToWrite {
                try? self.repository.addTrackPoint(point)
            }
        }.value
    }
}
