import Foundation
import GRDB
import CoreLocation

/// Repository for Track and TrackPoint CRUD operations
struct TrackRepository {
    let dbPool: DatabasePool

    // MARK: - Track Create

    /// Creates a new track and returns it with the assigned ID
    @discardableResult
    func createTrack(_ track: Track) throws -> Track {
        try dbPool.write { db in
            var newTrack = track
            try newTrack.insert(db)
            return newTrack
        }
    }

    /// Starts a new recording track
    @discardableResult
    func startRecording(projectId: Int64, name: String? = nil) throws -> Track {
        let count = try countTracksForProject(projectId)
        let trackName = name ?? String(format: "Track %03d", count + 1)

        let track = Track(
            projectId: projectId,
            name: trackName,
            startTime: Date(),
            isRecording: true
        )

        return try createTrack(track)
    }

    // MARK: - Track Read

    /// Fetches all tracks for a project
    func fetchAllTracks(projectId: Int64? = nil) throws -> [Track] {
        try dbPool.read { db in
            var query = Track.all().order(Track.Columns.startTime.desc)

            if let projectId = projectId {
                query = query.filter(Track.Columns.projectId == projectId)
            }

            return try query.fetchAll(db)
        }
    }

    /// Fetches a track by ID
    func fetchTrackById(_ id: Int64) throws -> Track? {
        try dbPool.read { db in
            try Track.fetchOne(db, key: id)
        }
    }

    /// Fetches the currently recording track (if any)
    func fetchRecordingTrack() throws -> Track? {
        try dbPool.read { db in
            try Track
                .filter(Track.Columns.isRecording == true)
                .fetchOne(db)
        }
    }

    // MARK: - Track Update

    /// Updates an existing track
    @discardableResult
    func updateTrack(_ track: Track) throws -> Track {
        try dbPool.write { db in
            var updatedTrack = track
            updatedTrack.updatedAt = Date()
            try updatedTrack.update(db)
            return updatedTrack
        }
    }

    /// Stops recording and calculates statistics
    func stopRecording(trackId: Int64) throws -> Track? {
        try dbPool.write { db in
            guard var track = try Track.fetchOne(db, key: trackId) else {
                return nil
            }

            track.isRecording = false
            track.endTime = Date()

            // Calculate statistics from track points
            let points = try TrackPoint
                .filter(TrackPoint.Columns.trackId == trackId)
                .order(TrackPoint.Columns.timestamp)
                .fetchAll(db)

            if let firstPoint = points.first, let lastPoint = points.last {
                // Calculate total distance
                var totalDistance: Double = 0
                var previousLocation: CLLocation?

                for point in points {
                    let location = point.location
                    if let previous = previousLocation {
                        totalDistance += location.distance(from: previous)
                    }
                    previousLocation = location
                }

                track.distance = totalDistance
                track.duration = lastPoint.timestamp.timeIntervalSince(firstPoint.timestamp)

                // Calculate elevation gain/loss
                var elevationGain: Double = 0
                var elevationLoss: Double = 0
                var previousAltitude: Double?

                for point in points {
                    if let altitude = point.altitude, let previous = previousAltitude {
                        let diff = altitude - previous
                        if diff > 0 {
                            elevationGain += diff
                        } else {
                            elevationLoss += abs(diff)
                        }
                    }
                    previousAltitude = point.altitude
                }

                track.elevationGain = elevationGain
                track.elevationLoss = elevationLoss
            }

            try track.update(db)
            return track
        }
    }

    // MARK: - Track Delete

    /// Deletes a track by ID (cascades to track points)
    func deleteTrack(id: Int64) throws {
        try dbPool.write { db in
            _ = try Track.deleteOne(db, key: id)
        }
    }

    // MARK: - Track Points

    /// Adds a track point
    @discardableResult
    func addTrackPoint(_ point: TrackPoint) throws -> TrackPoint {
        try dbPool.write { db in
            var newPoint = point
            try newPoint.insert(db)
            return newPoint
        }
    }

    /// Adds a track point from CLLocation
    @discardableResult
    func addTrackPoint(
        trackId: Int64,
        location: CLLocation,
        segmentIndex: Int = 0
    ) throws -> TrackPoint {
        let point = TrackPoint.from(
            location: location,
            trackId: trackId,
            segmentIndex: segmentIndex
        )
        return try addTrackPoint(point)
    }

    /// Fetches all points for a track
    func fetchTrackPoints(trackId: Int64) throws -> [TrackPoint] {
        try dbPool.read { db in
            try TrackPoint
                .filter(TrackPoint.Columns.trackId == trackId)
                .order(TrackPoint.Columns.timestamp)
                .fetchAll(db)
        }
    }

    /// Fetches track points as CLLocationCoordinate2D array (for map display)
    func fetchTrackCoordinates(trackId: Int64) throws -> [CLLocationCoordinate2D] {
        try fetchTrackPoints(trackId: trackId).map { $0.coordinate }
    }

    /// Returns the number of points in a track
    func countTrackPoints(trackId: Int64) throws -> Int {
        try dbPool.read { db in
            try TrackPoint
                .filter(TrackPoint.Columns.trackId == trackId)
                .fetchCount(db)
        }
    }

    // MARK: - Count

    /// Returns the number of tracks for a project
    func countTracksForProject(_ projectId: Int64) throws -> Int {
        try dbPool.read { db in
            try Track
                .filter(Track.Columns.projectId == projectId)
                .fetchCount(db)
        }
    }

    /// Returns the total number of tracks
    func countTracks() throws -> Int {
        try dbPool.read { db in
            try Track.fetchCount(db)
        }
    }
}
