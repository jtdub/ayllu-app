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

        // Create a project for tracks
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
        let track = Track(
            projectId: projectId,
            name: "Morning Survey",
            description: "First track of the day"
        )
        let created = try repository.createTrack(track)

        XCTAssertNotNil(created.id)
        XCTAssertEqual(created.name, "Morning Survey")
        XCTAssertEqual(created.description, "First track of the day")
        XCTAssertEqual(created.projectId, projectId)
    }

    func testStartRecording() throws {
        let track = try repository.startRecording(projectId: projectId)

        XCTAssertNotNil(track.id)
        XCTAssertTrue(track.isRecording)
        XCTAssertEqual(track.name, "Track 001")
        XCTAssertNotNil(track.startTime)
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
        // No recording track initially
        XCTAssertNil(try repository.fetchRecordingTrack())

        // Start recording
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

        // Add some track points
        try repository.addTrackPoint(TrackPoint(
            trackId: trackId,
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 10
        ))
        try repository.addTrackPoint(TrackPoint(
            trackId: trackId,
            latitude: 37.7750,
            longitude: -122.4195,
            altitude: 15
        ))

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

        let fetched = try repository.fetchTrackById(id)
        XCTAssertNil(fetched)
    }

    // MARK: - Track Point Tests

    func testAddTrackPoint() throws {
        let track = try repository.createTrack(Track(projectId: projectId, name: "Test"))
        guard let trackId = track.id else {
            XCTFail("Track should have ID")
            return
        }

        let point = try repository.addTrackPoint(TrackPoint(
            trackId: trackId,
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 10.5
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
            altitude: 10.5,
            horizontalAccuracy: 5.0,
            verticalAccuracy: 3.0,
            timestamp: Date()
        )

        let point = try repository.addTrackPoint(trackId: trackId, location: location)

        XCTAssertNotNil(point.id)
        XCTAssertEqual(point.latitude, 37.7749, accuracy: 0.0001)
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
        XCTAssertEqual(coordinates[1].latitude, 38.0, accuracy: 0.1)
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

        track.duration = 125  // 2:05
        XCTAssertEqual(track.formattedDuration, "2:05")

        track.duration = 3_725  // 1:02:05
        XCTAssertEqual(track.formattedDuration, "1:02:05")
    }
}
