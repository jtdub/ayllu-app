import Foundation
import GRDB

/// ViewModel managing the import flow: parse -> preview -> persist
@Observable
final class ImportViewModel {
    private let dbPool: DatabasePool
    var projectId: Int64?

    var parsedItems: [ParsedItem] = []
    var selectedItemIds: Set<String> = []
    var isParsing = false

    // CSV-specific
    var csvHeaders: [String] = []
    var csvRows: [[String]] = []
    var needsColumnMapping = false

    // Import state
    var isImporting = false
    var importResult: ImportResult?
    var error: String?

    // Cached counts
    var waypointCount = 0
    var geometryCount = 0

    init(dbPool: DatabasePool, projectId: Int64?) {
        self.dbPool = dbPool
        self.projectId = projectId
    }

    var selectedCount: Int {
        selectedItemIds.count
    }

    // MARK: - Parse

    func parseFile(url: URL) {
        isParsing = true
        error = nil
        parsedItems = []

        Task {
            do {
                let result = try await Self.doParse(url: url)

                switch result {
                case .items(let items):
                    finishParsing(items: items)
                case let .csv(headers, rows):
                    csvHeaders = headers
                    csvRows = rows
                    needsColumnMapping = true
                    isParsing = false
                }
            } catch {
                self.error = error.localizedDescription
                isParsing = false
            }
        }
    }

    private enum ParseOutput: Sendable {
        case items([ParsedItem])
        case csv(headers: [String], rows: [[String]])
    }

    private static func doParse(url: URL) async throws -> ParseOutput {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        guard let format = ImportFormat.detect(from: url) else {
            throw ImportError.unsupportedFormat
        }

        let data = try Data(contentsOf: url)

        switch format {
        case .gpx:
            return .items(try GPXImportService.parse(data: data))
        case .csv:
            let result = try CSVImportService.parseHeaders(data: data)
            return .csv(headers: result.headers, rows: result.rows)
        case .geojson:
            return .items(try GeoJSONImportService.parse(data: data))
        }
    }

    private func finishParsing(items: [ParsedItem]) {
        parsedItems = items
        selectedItemIds = Set(items.map(\.id))
        updateCounts()
        isParsing = false
    }

    func applyCSVMapping(_ mapping: CSVColumnMapping) {
        parsedItems = CSVImportService.mapToItems(
            rows: csvRows,
            headers: csvHeaders,
            mapping: mapping
        )
        selectedItemIds = Set(parsedItems.map(\.id))
        updateCounts()
        needsColumnMapping = false
        csvHeaders = []
        csvRows = []
    }

    // MARK: - Selection

    func toggleItem(_ id: String) {
        if selectedItemIds.contains(id) {
            selectedItemIds.remove(id)
        } else {
            selectedItemIds.insert(id)
        }
    }

    func selectAll() {
        selectedItemIds = Set(parsedItems.map(\.id))
    }

    func deselectAll() {
        selectedItemIds.removeAll()
    }

    // MARK: - Import

    func performImport() {
        guard let projectId else {
            error = "No project selected."
            return
        }
        guard !selectedItemIds.isEmpty else {
            error = "No items selected for import."
            return
        }

        isImporting = true
        error = nil

        let itemsToImport = parsedItems.filter { selectedItemIds.contains($0.id) }
        let pool = dbPool

        Task {
            do {
                let result = try ImportService.persistItems(
                    itemsToImport,
                    projectId: projectId,
                    dbPool: pool
                )
                self.importResult = result
                self.isImporting = false
            } catch {
                self.error = error.localizedDescription
                self.isImporting = false
            }
        }
    }

    // MARK: - Private

    private func updateCounts() {
        waypointCount = parsedItems.filter(\.isWaypoint).count
        geometryCount = parsedItems.filter { !$0.isWaypoint }.count
    }
}

private enum ImportError: LocalizedError {
    case unsupportedFormat

    var errorDescription: String? {
        "Unsupported file format. Use .gpx, .csv, or .geojson files."
    }
}
