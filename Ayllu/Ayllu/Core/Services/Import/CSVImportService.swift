import Foundation

/// Parses CSV files into importable items with column mapping
struct CSVImportService {
    enum CSVImportError: LocalizedError {
        case emptyFile
        case noDataRows
        case invalidEncoding

        var errorDescription: String? {
            switch self {
            case .emptyFile: return "The CSV file is empty."
            case .noDataRows: return "The CSV file has headers but no data rows."
            case .invalidEncoding: return "The CSV file could not be read as text."
            }
        }
    }

    /// Parses CSV data into headers and rows
    static func parseHeaders(data: Data) throws -> (headers: [String], rows: [[String]]) {
        guard let content = String(data: data, encoding: .utf8) else {
            throw CSVImportError.invalidEncoding
        }

        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard let headerLine = lines.first else {
            throw CSVImportError.emptyFile
        }

        let headers = parseCSVLine(headerLine)

        guard lines.count > 1 else {
            throw CSVImportError.noDataRows
        }

        let rows = lines.dropFirst().map { parseCSVLine($0) }
        return (headers: headers, rows: rows)
    }

    /// Maps parsed CSV rows to items using column mapping
    static func mapToItems(
        rows: [[String]],
        headers: [String],
        mapping: CSVColumnMapping
    ) -> [ParsedItem] {
        guard let nameIdx = headers.firstIndex(of: mapping.nameColumn),
              let latIdx = headers.firstIndex(of: mapping.latitudeColumn),
              let lonIdx = headers.firstIndex(of: mapping.longitudeColumn) else {
            return []
        }

        let descIdx = mapping.descriptionColumn.flatMap { headers.firstIndex(of: $0) }
        let altIdx = mapping.altitudeColumn.flatMap { headers.firstIndex(of: $0) }
        let catIdx = mapping.categoryColumn.flatMap { headers.firstIndex(of: $0) }

        return rows.compactMap { row -> ParsedItem? in
            guard nameIdx < row.count, latIdx < row.count, lonIdx < row.count else {
                return nil
            }

            guard let lat = Double(row[latIdx].trimmingCharacters(in: .whitespaces)),
                  let lon = Double(row[lonIdx].trimmingCharacters(in: .whitespaces)) else {
                return nil
            }

            let name = row[nameIdx].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }

            let desc = descIdx.flatMap { $0 < row.count ? row[$0] : nil }
            let alt = altIdx.flatMap { $0 < row.count ? Double(row[$0]) : nil }
            let cat = catIdx.flatMap { idx -> WaypointCategory? in
                guard idx < row.count else { return nil }
                return WaypointCategory(rawValue: row[idx].trimmingCharacters(in: .whitespaces).lowercased())
            }

            let waypoint = ParsedWaypoint(
                name: name,
                description: desc,
                latitude: lat,
                longitude: lon,
                altitude: alt,
                category: cat
            )
            return .waypoint(waypoint)
        }
    }

    /// Parses a single CSV line respecting quoted fields and escaped double-quotes
    static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()

        while let char = iterator.next() {
            if char == "\"" {
                if inQuotes {
                    // Peek: if next char is also a quote, it's an escaped quote
                    if let next = iterator.next() {
                        if next == "\"" {
                            current.append("\"")
                        } else {
                            inQuotes = false
                            if next == "," {
                                fields.append(current.trimmingCharacters(in: .whitespaces))
                                current = ""
                            } else {
                                current.append(next)
                            }
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            } else if char == "," && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))

        return fields
    }
}
