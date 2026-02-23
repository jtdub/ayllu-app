import XCTest
@testable import Ayllu
import GRDB

final class NoteEditorViewModelTests: XCTestCase {
    var database: DatabaseManager!
    var projectRepository: ProjectRepository!
    var noteRepository: NoteRepository!
    var speechService: SpeechService!
    var projectId: Int64!

    override func setUpWithError() throws {
        database = try DatabaseManager.inMemory()
        projectRepository = ProjectRepository(dbPool: database.dbPool)
        noteRepository = NoteRepository(dbPool: database.dbPool)
        speechService = SpeechService()

        let project = try projectRepository.create(Project(name: "Test Project"))
        projectId = project.id
    }

    override func tearDownWithError() throws {
        database = nil
        projectRepository = nil
        noteRepository = nil
        speechService = nil
        projectId = nil
    }

    // MARK: - Initial State Tests

    func testInitialStateForNewNote() {
        let viewModel = NoteEditorViewModel(
            repository: noteRepository,
            speechService: speechService,
            projectId: projectId
        )

        // Title should be auto-generated with date
        XCTAssertFalse(viewModel.title.isEmpty)
        XCTAssertTrue(viewModel.title.hasPrefix("Note - "))
        XCTAssertTrue(viewModel.content.isEmpty)
        XCTAssertTrue(viewModel.transcription.isEmpty)
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertNil(viewModel.audioFilePath)
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.isEditing)
    }

    func testInitialStateForExistingNote() throws {
        let existingNote = try noteRepository.create(FieldNote(
            projectId: projectId,
            title: "Existing Note",
            content: "Some content",
            audioFilePath: "/path/to/audio.m4a",
            transcription: "Transcribed text"
        ))

        let viewModel = NoteEditorViewModel(
            repository: noteRepository,
            speechService: speechService,
            projectId: projectId,
            existingNote: existingNote
        )

        XCTAssertEqual(viewModel.title, "Existing Note")
        XCTAssertEqual(viewModel.content, "Some content")
        XCTAssertEqual(viewModel.transcription, "Transcribed text")
        XCTAssertEqual(viewModel.audioFilePath, "/path/to/audio.m4a")
        XCTAssertTrue(viewModel.isEditing)
    }

    func testInitialStateWithWaypointId() throws {
        let waypointRepo = WaypointRepository(dbPool: database.dbPool)
        let waypoint = try waypointRepo.create(Waypoint(
            projectId: projectId,
            name: "WP1",
            latitude: 0,
            longitude: 0
        ))
        guard let waypointId = waypoint.id else {
            XCTFail("Waypoint should have ID")
            return
        }

        let viewModel = NoteEditorViewModel(
            repository: noteRepository,
            speechService: speechService,
            projectId: projectId,
            waypointId: waypointId
        )

        XCTAssertEqual(viewModel.waypointId, waypointId)
    }

    // MARK: - Validation Tests

    func testIsValidWhenTitleNotEmpty() {
        let viewModel = NoteEditorViewModel(
            repository: noteRepository,
            speechService: speechService,
            projectId: projectId
        )

        viewModel.title = "Valid Title"
        XCTAssertTrue(viewModel.isValid)
    }

    func testIsNotValidWhenTitleEmpty() {
        let viewModel = NoteEditorViewModel(
            repository: noteRepository,
            speechService: speechService,
            projectId: projectId
        )

        viewModel.title = ""
        XCTAssertFalse(viewModel.isValid)

        viewModel.title = "   "  // whitespace only
        XCTAssertFalse(viewModel.isValid)
    }

    // MARK: - Has Content Tests

    func testHasContentWhenContentExists() {
        let viewModel = NoteEditorViewModel(
            repository: noteRepository,
            speechService: speechService,
            projectId: projectId
        )

        XCTAssertFalse(viewModel.hasContent)

        viewModel.content = "Some text"
        XCTAssertTrue(viewModel.hasContent)
    }

    func testHasContentWhenTranscriptionExists() {
        let viewModel = NoteEditorViewModel(
            repository: noteRepository,
            speechService: speechService,
            projectId: projectId
        )

        viewModel.transcription = "Transcribed text"
        XCTAssertTrue(viewModel.hasContent)
    }

    func testHasContentWhenAudioExists() throws {
        let existingNote = try noteRepository.create(FieldNote(
            projectId: projectId,
            title: "Audio Note",
            audioFilePath: "/path/to/audio.m4a"
        ))

        let viewModel = NoteEditorViewModel(
            repository: noteRepository,
            speechService: speechService,
            projectId: projectId,
            existingNote: existingNote
        )

        XCTAssertTrue(viewModel.hasContent)
    }

    // MARK: - Save Tests

    func testSaveCreatesNewNote() throws {
        let viewModel = NoteEditorViewModel(
            repository: noteRepository,
            speechService: speechService,
            projectId: projectId
        )

        viewModel.title = "New Note Title"
        viewModel.content = "Note content here"

        let saved = try viewModel.save()

        XCTAssertNotNil(saved.id)
        XCTAssertEqual(saved.title, "New Note Title")
        XCTAssertEqual(saved.content, "Note content here")
        XCTAssertEqual(saved.projectId, projectId)
    }

    func testSaveTrimsWhitespace() throws {
        let viewModel = NoteEditorViewModel(
            repository: noteRepository,
            speechService: speechService,
            projectId: projectId
        )

        viewModel.title = "  Padded Title  "
        viewModel.content = "  Padded content  "
        viewModel.transcription = "  Padded transcription  "

        let saved = try viewModel.save()

        XCTAssertEqual(saved.title, "Padded Title")
        XCTAssertEqual(saved.content, "Padded content")
        XCTAssertEqual(saved.transcription, "Padded transcription")
    }

    func testSaveWithEmptyTranscriptionSetsNil() throws {
        let viewModel = NoteEditorViewModel(
            repository: noteRepository,
            speechService: speechService,
            projectId: projectId
        )

        viewModel.title = "Test"
        viewModel.transcription = "   "  // whitespace only

        let saved = try viewModel.save()

        XCTAssertNil(saved.transcription)
    }

    func testSaveUpdatesExistingNote() throws {
        var existingNote = try noteRepository.create(FieldNote(
            projectId: projectId,
            title: "Original Title",
            content: "Original content"
        ))

        let viewModel = NoteEditorViewModel(
            repository: noteRepository,
            speechService: speechService,
            projectId: projectId,
            existingNote: existingNote
        )

        viewModel.title = "Updated Title"
        viewModel.content = "Updated content"

        let saved = try viewModel.save()

        XCTAssertEqual(saved.id, existingNote.id)
        XCTAssertEqual(saved.title, "Updated Title")
        XCTAssertEqual(saved.content, "Updated content")
    }

    func testSaveLinksToWaypoint() throws {
        let waypointRepo = WaypointRepository(dbPool: database.dbPool)
        let waypoint = try waypointRepo.create(Waypoint(
            projectId: projectId,
            name: "WP1",
            latitude: 0,
            longitude: 0
        ))
        guard let waypointId = waypoint.id else {
            XCTFail("Waypoint should have ID")
            return
        }

        let viewModel = NoteEditorViewModel(
            repository: noteRepository,
            speechService: speechService,
            projectId: projectId,
            waypointId: waypointId
        )

        viewModel.title = "Linked Note"

        let saved = try viewModel.save()

        XCTAssertEqual(saved.waypointId, waypointId)
        XCTAssertTrue(saved.isLinkedToWaypoint)
    }

    // MARK: - Edit Mode Tests

    func testIsEditingFalseForNewNote() {
        let viewModel = NoteEditorViewModel(
            repository: noteRepository,
            speechService: speechService,
            projectId: projectId
        )

        XCTAssertFalse(viewModel.isEditing)
    }

    func testIsEditingTrueForExistingNote() throws {
        let existingNote = try noteRepository.create(FieldNote(
            projectId: projectId,
            title: "Test"
        ))

        let viewModel = NoteEditorViewModel(
            repository: noteRepository,
            speechService: speechService,
            projectId: projectId,
            existingNote: existingNote
        )

        XCTAssertTrue(viewModel.isEditing)
    }

    // MARK: - Project ID Tests

    func testProjectIdIsSet() {
        let viewModel = NoteEditorViewModel(
            repository: noteRepository,
            speechService: speechService,
            projectId: projectId
        )

        XCTAssertEqual(viewModel.projectId, projectId)
    }
}
