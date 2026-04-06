import Foundation

/// Service for exporting records and form data to CSV format
struct CSVExportService {
    /// Exports records with their form data as a CSV string
    static func export(
        records: [Record],
        fields: [FormField],
        projectName: String
    ) -> String {
        var lines: [String] = []

        // Header row
        var headers = ["Name", "Type", "Description", "Latitude", "Longitude", "Altitude", "Created"]
        headers += fields.map(\.label)
        lines.append(headers.map { escapeCSV($0) }.joined(separator: ","))

        // Data rows
        let dateFormatter = ISO8601DateFormatter()
        for record in records {
            var row = [
                escapeCSV(record.name),
                escapeCSV(String(record.recordTypeId)),
                escapeCSV(record.description ?? ""),
                record.latitude.map { String($0) } ?? "",
                record.longitude.map { String($0) } ?? "",
                record.altitude.map { String($0) } ?? "",
                dateFormatter.string(from: record.createdAt)
            ]

            for field in fields {
                row.append(escapeCSV(record.formData[field.name] ?? ""))
            }

            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    /// Writes CSV to a temp file and returns the URL for sharing
    static func exportToFile(
        records: [Record],
        fields: [FormField],
        projectName: String
    ) -> URL? {
        let csv = export(records: records, fields: fields, projectName: projectName)
        let fileName = "\(projectName.replacingOccurrences(of: " ", with: "_"))_export.csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            return nil
        }
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
