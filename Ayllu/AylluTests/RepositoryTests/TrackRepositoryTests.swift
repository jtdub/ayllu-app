import XCTest
@testable import Ayllu
import GRDB
import CoreLocation

final class TrackRepositoryTests: XCTestCase {
    var database: DatabaseManager!
    var repository: TrackRepository!
    var projectId: Int64!

    override func setUpWithError() throws {
        database = try DatabaseManager.inMemory()
        repository = TrackRepository(dbPool: database.dbPool)
        let projectRepo = ProjectRepository(dbPool: database.dbPool)
        let project = try projectRepo.create(Project(name: "Test Project"))
        projectId = project.id
    }

    override func tearDownWithError() throws {
        database = nil
        repository = nil
        projectId = nil
    }

    // MARK: - Track Create Tests

    func testCreateTrack() throws {
        let track = Track(projectId: projectId, name: "Morning Survey", description: "First track")
        let created = try repository.createTrack(track)
        XCTAssertNotNil(created.id)
        XCTAssertEqual(created.name, "Morning Survey")
        XCTAssertEqual(created.projectId, projectId)
    }

    func testStartRecording() throws {
        let track = try repository.startRecording(projectId: projectId)
        XCTAssertNotNil(track.id)
        XCTAssertTrue(track.isRecording)
        XCTAssertEqual(track.name, "Track 001")
    }

    func testStartRecordingWithCustomName() throws {
        let track = try repository.startRecording(projectId: projectId, name: "Custom Track")
        XCTAssertEqual(track.name, "Custom Track")
        XCTAssertTrue(track.isRecording)
    }

    func testStartRecordingAutoIncrements() throws {
        _ = try repository.startRecording(projectId: projectId)
        let secondTrack = try repository.startRecording(projectId: projectId)
        XCTAssertEqual(secondTrack.name, "Track 002")
    }

    // MARK: - Track Read Tests

    func testFetchAllTracks() throws {
        try repository.createTrack(Track(projectId: projectId, name: "Track 1"))
        try repository.createTrack(Track(projectId: projectId, name: "Track 2"))
        try repository.createTrack(Track(projectId: projectId, name: "Track 3"))
        let tracks = try repository.fetchAllTracks()
        XCTAssertEqual(tracks.count, 3)
    }

    func testFetchAllTracksByProject() throws {
        let projectRepo = ProjectRepository(dbPool: database.dbPool)
        let otherProject = try projectRepo.create(Project(name: "Other"))
        guard let otherProjectId = otherProject.id else {
            XCTFail("Project should have ID")
            return
        }
        try repository.createTrack(Track(projectId: projectId, name: "T1"))
        try repository.createTrack(Track(projectId: projectId, name: "T2"))
        try repository.createTrack(Track(projectId: otherProjectId, name: "T3"))
        let projectTracks = try repository.fetchAllTracks(projectId: projectId)
        XCTAssertEqual(projectTracks.count, 2)
    }

    func testFetchTrackById() throws {
        let created = try repository.createTrack(Track(projectId: projectId, name: "Test"))
        guard let id = created.id else {
            XCTFail("Track should have ID")
            return
        }
        let fetched = try repository.fetchTrackById(id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "Test")
    }

    func testFetchRecordingTrack() throws {
        XCTAssertNil(try repository.fetchRecordingTrack())
        _ = try repository.startRecording(projectId: projectId)
        let recording = try repository.fetchRecordingTrack()
        XCTAssertNotNil(recording)
        XCTAssertTrue(recording?.isRecording ?? false)
    }

    // MARK: - Track Update Tests

    func testUpdateTrack() throws {
        var track = try repository.createTrack(Track(projectId: projectId, name: "Original"))
        track.name = "Updated"
        track.description = "New description"
        let updated = try repository.updateTrack(track)
        XCTAssertEqual(updated.name, "Updated")
        XCTAssertEqual(updated.description, "New description")
    }

    func testStopRecording() throws {
        let track = try repository.startRecording(projectId: projectId)
        guard let trackId = track.id else {
            XCTFail("Track should have ID")
            return
        }
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 37.77, longitude: -122.41, altitude: 10))
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 37.78, longitude: -122.42, altitude: 15))
        let stopped = try repository.stopRecording(trackId: trackId)
        XCTAssertNotNil(stopped)
        XCTAssertFalse(stopped?.isRecording ?? true)
        XCTAssertNotNil(stopped?.endTime)
        XCTAssertNotNil(stopped?.distance)
    }

    // MARK: - Track Delete Tests

    func testDeleteTrack() throws {
        let track = try repository.createTrack(Track(projectId: projectId, name: "Delete"))
        guard let id = track.id else {
            XCTFail("Track should have ID")
            return
        }
        try repository.deleteTrack(id: id)
        XCTAssertNil(try repository.fetchTrackById(id))
    }

    // MARK: - Count Tests

    func testCountTracks() throws {
        XCTAssertEqual(try repository.countTracks(), 0)
        try repository.createTrack(Track(projectId: projectId, name: "T1"))
        try repository.createTrack(Track(projectId: projectId, name: "T2"))
        XCTAssertEqual(try repository.countTracks(), 2)
    }

    func testCountTracksForProject() throws {
        XCTAssertEqual(try repository.countTracksForProject(projectId), 0)
        try repository.createTrack(Track(projectId: projectId, name: "T1"))
        XCTAssertEqual(try repository.countTracksForProject(projectId), 1)
    }

    // MARK: - Formatted Properties Tests

    func testFormattedDistance() throws {
        var track = Track(projectId: projectId, name: "Test")
        track.distance = nil
        XCTAssertEqual(track.formattedDistance, "—")
        track.distance = 500
        XCTAssertEqual(track.formattedDistance, "500 m")
        track.distance = 1_500
        XCTAssertEqual(track.formattedDistance, "1.50 km")
    }

    func testFormattedDuration() throws {
        var track = Track(projectId: projectId, name: "Test")
        track.duration = nil
        XCTAssertEqual(track.formattedDuration, "—")
        track.duration = 125
        XCTAssertEqual(track.formattedDuration, "2:05")
        track.duration = 3_725
        XCTAssertEqual(track.formattedDuration, "1:02:05")
    }
}

// MARK: - Track Point Tests

extension TrackRepositoryTests {
    func testAddTrackPoint() throws {
        let track = try repository.createTrack(Track(projectId: projectId, name: "Test"))
        guard let trackId = track.id else {
            XCTFail("Track should have ID")
            return
        }
        let point = try repository.addTrackPoint(TrackPoint(
            trackId: trackId, latitude: 37.7749, longitude: -122.4194, altitude: 10.5
        ))
        XCTAssertNotNil(point.id)
        XCTAssertEqual(point.trackId, trackId)
        XCTAssertEqual(point.latitude, 37.7749, accuracy: 0.0001)
    }

    func testAddTrackPointFromCLLocation() throws {
        let track = try repository.createTrack(Track(projectId: projectId, name: "Test"))
        guard let trackId = track.id else {
            XCTFail("Track should have ID")
            return
        }
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            altitude: 10.5, horizontalAccuracy: 5.0, verticalAccuracy: 3.0, timestamp: Date()
        )
        let point = try repository.addTrackPoint(trackId: trackId, location: location)
        XCTAssertNotNil(point.id)
        XCTAssertEqual(point.altitude, 10.5)
        XCTAssertEqual(point.horizontalAccuracy, 5.0)
    }

    func testFetchTrackPoints() throws {
        let track = try repository.createTrack(Track(projectId: projectId, name: "Test"))
        guard let trackId = track.id else {
            XCTFail("Track should have ID")
            return
        }
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 1, longitude: 1))
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 2, longitude: 2))
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 3, longitude: 3))
        let points = try repository.fetchTrackPoints(trackId: trackId)
        XCTAssertEqual(points.count, 3)
    }

    func testFetchTrackCoordinates() throws {
        let track = try repository.createTrack(Track(projectId: projectId, name: "Test"))
        guard let trackId = track.id else {
            XCTFail("Track should have ID")
            return
        }
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 37.0, longitude: -122.0))
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 38.0, longitude: -123.0))
        let coordinates = try repository.fetchTrackCoordinates(trackId: trackId)
        XCTAssertEqual(coordinates.count, 2)
        XCTAssertEqual(coordinates[0].latitude, 37.0, accuracy: 0.1)
    }

    func testCountTrackPoints() throws {
        let track = try repository.createTrack(Track(projectId: projectId, name: "Test"))
        guard let trackId = track.id else {
            XCTFail("Track should have ID")
            return
        }
        XCTAssertEqual(try repository.countTrackPoints(trackId: trackId), 0)
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 1, longitude: 1))
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 2, longitude: 2))
        XCTAssertEqual(try repository.countTrackPoints(trackId: trackId), 2)
    }
}

// MARK: - Simplification and Bounding Box Tests

extension TrackRepositoryTests {
    func testFetchSimplifiedCoordinates() throws {
        let track = try repository.createTrack(Track(projectId: projectId, name: "Test"))
        guard let trackId = track.id else {
            XCTFail("Track should have ID")
            return
        }
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 37.0, longitude: -122.0))
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 37.0001, longitude: -122.0001))
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 37.0002, longitude: -122.0002))
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 37.001, longitude: -122.001))
        let simplified = try repository.fetchSimplifiedCoordinates(trackId: trackId, tolerance: 5.0)
        XCTAssertTrue(simplified.count <= 4)
        XCTAssertEqual(simplified.first?.latitude ?? 0, 37.0, accuracy: 0.0001)
        XCTAssertEqual(simplified.last?.latitude ?? 0, 37.001, accuracy: 0.0001)
    }

    func testFetchSimplifiedCoordinatesWithFewPoints() throws {
        let track = try repository.createTrack(Track(projectId: projectId, name: "Test"))
        guard let trackId = track.id else {
            XCTFail("Track should have ID")
            return
        }
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 37.0, longitude: -122.0))
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 38.0, longitude: -123.0))
        let simplified = try repository.fetchSimplifiedCoordinates(trackId: trackId)
        XCTAssertEqual(simplified.count, 2)
    }

    func testFetchBoundingBox() throws {
        let track = try repository.createTrack(Track(projectId: projectId, name: "Test"))
        guard let trackId = track.id else {
            XCTFail("Track should have ID")
            return
        }
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 37.0, longitude: -122.0))
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 38.0, longitude: -121.0))
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 37.5, longitude: -121.5))
        let bounds = try repository.fetchBoundingBox(trackId: trackId)
        XCTAssertNotNil(bounds)
        XCTAssertEqual(bounds?.north ?? 0, 38.0, accuracy: 0.0001)
        XCTAssertEqual(bounds?.south ?? 0, 37.0, accuracy: 0.0001)
        XCTAssertEqual(bounds?.east ?? 0, -121.0, accuracy: 0.0001)
        XCTAssertEqual(bounds?.west ?? 0, -122.0, accuracy: 0.0001)
    }

    func testFetchBoundingBoxEmptyTrack() throws {
        let track = try repository.createTrack(Track(projectId: projectId, name: "Empty"))
        guard let trackId = track.id else {
            XCTFail("Track should have ID")
            return
        }
        let bounds = try repository.fetchBoundingBox(trackId: trackId)
        XCTAssertNil(bounds)
    }
}

// MARK: - Bulk Operations and Statistics Tests

extension TrackRepositoryTests {
    func testDeleteAllTracks() throws {
        try repository.createTrack(Track(projectId: projectId, name: "T1"))
        try repository.createTrack(Track(projectId: projectId, name: "T2"))
        XCTAssertEqual(try repository.countTracksForProject(projectId), 2)
        try repository.deleteAllTracks(projectId: projectId)
        XCTAssertEqual(try repository.countTracksForProject(projectId), 0)
    }

    func testDeleteAllTrackPoints() throws {
        let track = try repository.createTrack(Track(projectId: projectId, name: "Test"))
        guard let trackId = track.id else {
            XCTFail("Track should have ID")
            return
        }
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 1, longitude: 1))
        try repository.addTrackPoint(TrackPoint(trackId: trackId, latitude: 2, longitude: 2))
        XCTAssertEqual(try repository.countTrackPoints(trackId: trackId), 2)
        try repository.deleteAllTrackPoints(trackId: trackId)
        XCTAssertEqual(try repository.countTrackPoints(trackId: trackId), 0)
    }

    func testRecalculateStatistics() throws {
        let track = try repository.createTrack(Track(projectId: projectId, name: "Test"))
        guard let trackId = track.id else {
            XCTFail("Track should have ID")
            return
        }
        let baseTime = Date()
        try repository.addTrackPoint(TrackPoint(
            trackId: trackId, latitude: 37.0, longitude: -122.0, altitude: 100, timestamp: baseTime
        ))
        try repository.addTrackPoint(TrackPoint(
            trackId: trackId, latitude: 37.001, longitude: -122.001,
            altitude: 150, timestamp: baseTime.addingTimeInterval(60)
        ))
        try repository.addTrackPoint(TrackPoint(
            trackId: trackId, latitude: 37.002, longitude: -122.002,
            altitude: 120, timestamp: baseTime.addingTimeInterval(120)
        ))
        let updated = try repository.recalculateStatistics(trackId: trackId)
        XCTAssertNotNil(updated)
        XCTAssertNotNil(updated?.distance)
        XCTAssertEqual(updated?.duration ?? 0, 120, accuracy: 0.1)
        XCTAssertEqual(updated?.elevationGain ?? 0, 50, accuracy: 0.1)
        XCTAssertEqual(updated?.elevationLoss ?? 0, 30, accuracy: 0.1)
    }

    func testRecalculateStatisticsEmptyTrack() throws {
        let track = try repository.createTrack(Track(projectId: projectId, name: "Empty"))
        guard let trackId = track.id else {
            XCTFail("Track should have ID")
            return
        }
        let updated = try repository.recalculateStatistics(trackId: trackId)
        XCTAssertNotNil(updated)
        XCTAssertNil(updated?.distance)
    }
}
