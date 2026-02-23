import XCTest
@testable import Ayllu
import GRDB

final class NoteRepositoryTests: XCTestCase {
    var database: DatabaseManager!
    var repository: NoteRepository!
    var projectId: Int64!

    override func setUpWithError() throws {
        database = try DatabaseManager.inMemory()
        repository = NoteRepository(dbPool: database.dbPool)

        // Create a project for notes
        let projectRepo = ProjectRepository(dbPool: database.dbPool)
        let project = try projectRepo.create(Project(name: "Test Project"))
        projectId = project.id
    }

    override func tearDownWithError() throws {
        database = nil
        repository = nil
        projectId = nil
    }

    // MARK: - Create Tests

    func testCreateNote() throws {
        let note = FieldNote(projectId: projectId, title: "Test Note", content: "Some content")
        let created = try repository.create(note)

        XCTAssertNotNil(created.id)
        XCTAssertEqual(created.title, "Test Note")
        XCTAssertEqual(created.content, "Some content")
        XCTAssertEqual(created.projectId, projectId)
    }

    func testCreateNoteWithTranscription() throws {
        let note = FieldNote(
            projectId: projectId,
            title: "Voice Note",
            content: "",
            audioFilePath: "/path/to/audio.m4a",
            transcription: "This is the transcription"
        )
        let created = try repository.create(note)

        XCTAssertNotNil(created.audioFilePath)
        XCTAssertEqual(created.transcription, "This is the transcription")
        XCTAssertTrue(created.hasAudio)
    }

    // MARK: - Read Tests

    func testFetchAll() throws {
        try repository.create(FieldNote(projectId: projectId, title: "Note 1"))
        try repository.create(FieldNote(projectId: projectId, title: "Note 2"))
        try repository.create(FieldNote(projectId: projectId, title: "Note 3"))

        let notes = try repository.fetchAll()
        XCTAssertEqual(notes.count, 3)
    }

    func testFetchAllWithSearch() throws {
        try repository.create(FieldNote(
            projectId: projectId,
            title: "Archaeological findings",
            content: "Found pottery shards"
        ))
        try repository.create(FieldNote(
            projectId: projectId,
            title: "Wildlife observation",
            content: "Spotted deer"
        ))

        let results = try repository.fetchAll(searchTerm: "archaeological")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Archaeological findings")
    }

    func testFetchAllWithHasAudioFilter() throws {
        try repository.create(FieldNote(projectId: projectId, title: "Text Note"))
        try repository.create(FieldNote(
            projectId: projectId,
            title: "Audio Note",
            audioFilePath: "/path/to/audio.m4a"
        ))

        let audioNotes = try repository.fetchAll(hasAudio: true)
        XCTAssertEqual(audioNotes.count, 1)
        XCTAssertEqual(audioNotes.first?.title, "Audio Note")

        let textNotes = try repository.fetchAll(hasAudio: false)
        XCTAssertEqual(textNotes.count, 1)
        XCTAssertEqual(textNotes.first?.title, "Text Note")
    }

    func testFetchById() throws {
        let created = try repository.create(FieldNote(projectId: projectId, title: "Test"))
        guard let id = created.id else {
            XCTFail("Note should have an ID")
            return
        }

        let fetched = try repository.fetchById(id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.title, "Test")
    }

    func testFetchForWaypoint() throws {
        // Create a waypoint
        let waypointRepo = WaypointRepository(dbPool: database.dbPool)
        let waypoint = try waypointRepo.create(Waypoint(
            projectId: projectId,
            name: "WP1",
            latitude: 0,
            longitude: 0
        ))
        guard let waypointId = waypoint.id else {
            XCTFail("Waypoint should have an ID")
            return
        }

        // Create notes, one linked to waypoint
        try repository.create(FieldNote(projectId: projectId, title: "Unlinked Note"))
        try repository.create(FieldNote(
            projectId: projectId,
            waypointId: waypointId,
            title: "Linked Note"
        ))

        let waypointNotes = try repository.fetchForWaypoint(waypointId)
        XCTAssertEqual(waypointNotes.count, 1)
        XCTAssertEqual(waypointNotes.first?.title, "Linked Note")
    }

    // MARK: - Update Tests

    func testUpdateNote() throws {
        var note = try repository.create(FieldNote(projectId: projectId, title: "Original"))
        note.title = "Updated"
        note.content = "New content"

        let updated = try repository.update(note)
        XCTAssertEqual(updated.title, "Updated")
        XCTAssertEqual(updated.content, "New content")
    }

    func testLinkToWaypoint() throws {
        let note = try repository.create(FieldNote(projectId: projectId, title: "Test"))
        guard let noteId = note.id else {
            XCTFail("Note should have an ID")
            return
        }

        XCTAssertFalse(note.isLinkedToWaypoint)

        // Create waypoint and link
        let waypointRepo = WaypointRepository(dbPool: database.dbPool)
        let waypoint = try waypointRepo.create(Waypoint(
            projectId: projectId,
            name: "WP1",
            latitude: 0,
            longitude: 0
        ))

        try repository.linkToWaypoint(noteId: noteId, waypointId: waypoint.id)

        let fetched = try repository.fetchById(noteId)
        XCTAssertEqual(fetched?.waypointId, waypoint.id)
        XCTAssertTrue(fetched?.isLinkedToWaypoint ?? false)
    }

    func testUpdateTranscription() throws {
        let note = try repository.create(FieldNote(projectId: projectId, title: "Voice"))
        guard let noteId = note.id else {
            XCTFail("Note should have an ID")
            return
        }

        try repository.updateTranscription(noteId: noteId, transcription: "New transcription")

        let fetched = try repository.fetchById(noteId)
        XCTAssertEqual(fetched?.transcription, "New transcription")
    }

    // MARK: - Delete Tests

    func testDeleteNote() throws {
        let note = try repository.create(FieldNote(projectId: projectId, title: "To Delete"))
        guard let id = note.id else {
            XCTFail("Note should have an ID")
            return
        }

        try repository.delete(id: id)

        let fetched = try repository.fetchById(id)
        XCTAssertNil(fetched)
    }

    func testDeleteAllForProject() throws {
        try repository.create(FieldNote(projectId: projectId, title: "Note 1"))
        try repository.create(FieldNote(projectId: projectId, title: "Note 2"))

        XCTAssertEqual(try repository.countForProject(projectId), 2)

        try repository.deleteAll(projectId: projectId)

        XCTAssertEqual(try repository.countForProject(projectId), 0)
    }

    // MARK: - Count Tests

    func testCount() throws {
        XCTAssertEqual(try repository.count(), 0)

        try repository.create(FieldNote(projectId: projectId, title: "N1"))
        try repository.create(FieldNote(projectId: projectId, title: "N2"))

        XCTAssertEqual(try repository.count(), 2)
    }

    func testCountWithAudio() throws {
        try repository.create(FieldNote(projectId: projectId, title: "Text"))
        try repository.create(FieldNote(
            projectId: projectId,
            title: "Audio",
            audioFilePath: "/audio.m4a"
        ))

        XCTAssertEqual(try repository.countWithAudio(), 1)
    }

    // MARK: - Full Text Tests

    func testFullText() throws {
        let noteWithBoth = try repository.create(FieldNote(
            projectId: projectId,
            title: "Test",
            content: "Written content",
            transcription: "Spoken words"
        ))

        XCTAssertTrue(noteWithBoth.fullText.contains("Written content"))
        XCTAssertTrue(noteWithBoth.fullText.contains("Spoken words"))
    }
}
