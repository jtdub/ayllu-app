import Foundation
import GRDB

/// ViewModel managing the import flow: parse -> preview -> persist
@Observable
final class ImportViewModel {
    let dbPool: DatabasePool
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

        Task.detached { [self] in
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }

            guard let format = ImportFormat.detect(from: url) else {
                await MainActor.run {
                    self.error = "Unsupported file format. Use .gpx, .csv, or .geojson files."
                    self.isParsing = false
                }
                return
            }

            do {
                let data = try Data(contentsOf: url)

                switch format {
                case .gpx:
                    let items = try GPXImportService.parse(data: data)
                    await MainActor.run { self.finishParsing(items: items) }
                case .csv:
                    let result = try CSVImportService.parseHeaders(data: data)
                    await MainActor.run {
                        self.csvHeaders = result.headers
                        self.csvRows = result.rows
                        self.needsColumnMapping = true
                        self.isParsing = false
                    }
                case .geojson:
                    let items = try GeoJSONImportService.parse(data: data)
                    await MainActor.run { self.finishParsing(items: items) }
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isParsing = false
                }
            }
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

        Task.detached { [self] in
            do {
                let result = try ImportService.persistItems(
                    itemsToImport,
                    projectId: projectId,
                    dbPool: self.dbPool
                )
                await MainActor.run {
                    self.importResult = result
                    self.isImporting = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isImporting = false
                }
            }
        }
    }

    // MARK: - Private

    private func updateCounts() {
        waypointCount = parsedItems.filter(\.isWaypoint).count
        geometryCount = parsedItems.filter { !$0.isWaypoint }.count
    }
}
