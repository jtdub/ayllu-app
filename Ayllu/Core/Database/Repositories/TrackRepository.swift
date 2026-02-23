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

    // MARK: - Track Simplification

    /// Fetches simplified track coordinates using Douglas-Peucker algorithm
    /// - Parameters:
    ///   - trackId: The track ID
    ///   - tolerance: Simplification tolerance in meters (default 10m)
    /// - Returns: Simplified array of coordinates suitable for map display
    func fetchSimplifiedCoordinates(trackId: Int64, tolerance: Double = 10.0) throws -> [CLLocationCoordinate2D] {
        let points = try fetchTrackPoints(trackId: trackId)
        guard points.count > 2 else {
            return points.map { $0.coordinate }
        }

        let coordinates = points.map { $0.coordinate }
        return simplifyDouglasPeucker(coordinates: coordinates, tolerance: tolerance)
    }

    /// Douglas-Peucker line simplification algorithm
    private func simplifyDouglasPeucker(
        coordinates: [CLLocationCoordinate2D],
        tolerance: Double
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 2 else { return coordinates }

        // Find the point with maximum distance from the line between first and last
        var maxDistance: Double = 0
        var maxIndex = 0

        let first = coordinates.first!
        let last = coordinates.last!

        for i in 1..<(coordinates.count - 1) {
            let distance = perpendicularDistance(
                point: coordinates[i],
                lineStart: first,
                lineEnd: last
            )
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        // If max distance exceeds tolerance, recursively simplify
        if maxDistance > tolerance {
            let firstHalf = simplifyDouglasPeucker(
                coordinates: Array(coordinates[0...maxIndex]),
                tolerance: tolerance
            )
            let secondHalf = simplifyDouglasPeucker(
                coordinates: Array(coordinates[maxIndex...]),
                tolerance: tolerance
            )

            // Combine results, avoiding duplicate point at maxIndex
            return Array(firstHalf.dropLast()) + secondHalf
        } else {
            // All points between first and last are within tolerance
            return [first, last]
        }
    }

    /// Calculate perpendicular distance from point to line in meters
    private func perpendicularDistance(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let pointLoc = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let startLoc = CLLocation(latitude: lineStart.latitude, longitude: lineStart.longitude)
        let endLoc = CLLocation(latitude: lineEnd.latitude, longitude: lineEnd.longitude)

        let lineLength = startLoc.distance(from: endLoc)
        guard lineLength > 0 else {
            return pointLoc.distance(from: startLoc)
        }

        // Calculate area of triangle using cross product, then derive height
        let a = startLoc.distance(from: pointLoc)
        let b = endLoc.distance(from: pointLoc)
        let c = lineLength

        // Heron's formula for area
        let s = (a + b + c) / 2
        let areaSquared = s * (s - a) * (s - b) * (s - c)
        let area = areaSquared > 0 ? sqrt(areaSquared) : 0

        // Height = 2 * area / base
        return (2 * area) / c
    }

    // MARK: - Bounding Box

    /// Fetches the bounding box for a track
    func fetchBoundingBox(trackId: Int64) throws -> (
        north: Double, south: Double, east: Double, west: Double
    )? {
        try dbPool.read { db in
            let row = try Row.fetchOne(db, sql: """
                SELECT
                    MAX(latitude) as north,
                    MIN(latitude) as south,
                    MAX(longitude) as east,
                    MIN(longitude) as west
                FROM track_points
                WHERE trackId = ?
                """, arguments: [trackId])

            guard let row = row,
                  let north: Double = row["north"],
                  let south: Double = row["south"],
                  let east: Double = row["east"],
                  let west: Double = row["west"] else {
                return nil
            }

            return (north: north, south: south, east: east, west: west)
        }
    }

    // MARK: - Bulk Operations

    /// Deletes all tracks for a project (cascades to track points)
    func deleteAllTracks(projectId: Int64) throws {
        try dbPool.write { db in
            _ = try Track
                .filter(Track.Columns.projectId == projectId)
                .deleteAll(db)
        }
    }

    /// Deletes all track points for a track
    func deleteAllTrackPoints(trackId: Int64) throws {
        try dbPool.write { db in
            _ = try TrackPoint
                .filter(TrackPoint.Columns.trackId == trackId)
                .deleteAll(db)
        }
    }

    // MARK: - Statistics

    /// Recalculates statistics for a track from its points
    func recalculateStatistics(trackId: Int64) throws -> Track? {
        try dbPool.write { db in
            guard var track = try Track.fetchOne(db, key: trackId) else {
                return nil
            }

            let points = try TrackPoint
                .filter(TrackPoint.Columns.trackId == trackId)
                .order(TrackPoint.Columns.timestamp)
                .fetchAll(db)

            guard points.count >= 2,
                  let firstPoint = points.first,
                  let lastPoint = points.last else {
                return track
            }

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
            track.updatedAt = Date()

            try track.update(db)
            return track
        }
    }
}
