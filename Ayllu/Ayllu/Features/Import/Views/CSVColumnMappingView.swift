import SwiftUI

/// UI for mapping CSV columns to waypoint fields
struct CSVColumnMappingView: View {
    let headers: [String]
    let onApply: (CSVColumnMapping) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var nameColumn = ""
    @State private var latColumn = ""
    @State private var lonColumn = ""
    @State private var descColumn = ""
    @State private var altColumn = ""

    var body: some View {
        Form {
            Section("Required Columns") {
                Picker("Name", selection: $nameColumn) {
                    Text("Select...").tag("")
                    ForEach(headers, id: \.self) { header in
                        Text(header).tag(header)
                    }
                }

                Picker("Latitude", selection: $latColumn) {
                    Text("Select...").tag("")
                    ForEach(headers, id: \.self) { header in
                        Text(header).tag(header)
                    }
                }

                Picker("Longitude", selection: $lonColumn) {
                    Text("Select...").tag("")
                    ForEach(headers, id: \.self) { header in
                        Text(header).tag(header)
                    }
                }
            }

            Section("Optional Columns") {
                Picker("Description", selection: $descColumn) {
                    Text("None").tag("")
                    ForEach(headers, id: \.self) { header in
                        Text(header).tag(header)
                    }
                }

                Picker("Altitude", selection: $altColumn) {
                    Text("None").tag("")
                    ForEach(headers, id: \.self) { header in
                        Text(header).tag(header)
                    }
                }
            }
        }
        .navigationTitle("Map CSV Columns")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Apply") {
                    let mapping = CSVColumnMapping(
                        nameColumn: nameColumn,
                        latitudeColumn: latColumn,
                        longitudeColumn: lonColumn,
                        descriptionColumn: descColumn.isEmpty ? nil : descColumn,
                        altitudeColumn: altColumn.isEmpty ? nil : altColumn
                    )
                    onApply(mapping)
                    dismiss()
                }
                .disabled(nameColumn.isEmpty || latColumn.isEmpty || lonColumn.isEmpty)
            }
        }
        .onAppear {
            autoDetectColumns()
        }
    }

    private func autoDetectColumns() {
        let lower = headers.map { $0.lowercased() }
        if let idx = lower.firstIndex(where: { $0.contains("name") }) {
            nameColumn = headers[idx]
        }
        if let idx = lower.firstIndex(where: { $0.contains("lat") }) {
            latColumn = headers[idx]
        }
        if let idx = lower.firstIndex(where: { $0.contains("lon") }) {
            lonColumn = headers[idx]
        }
        if let idx = lower.firstIndex(where: { $0.contains("desc") }) {
            descColumn = headers[idx]
        }
        if let idx = lower.firstIndex(where: { $0.contains("alt") || $0.contains("elev") }) {
            altColumn = headers[idx]
        }
    }
}
