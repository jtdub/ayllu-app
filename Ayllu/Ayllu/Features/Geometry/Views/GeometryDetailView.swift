import SwiftUI
import GRDB

/// Detail view for a single geometry showing metadata and export options
struct GeometryDetailView: View {
    let geometry: Geometry
    let dbPool: DatabasePool

    @State private var showingGeoJSONExport = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        List {
            Section("Information") {
                LabeledContent("Name", value: geometry.name)
                LabeledContent("Type", value: geometry.geometryType.displayName)

                if let description = geometry.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(description)
                    }
                }

                LabeledContent("Vertices", value: "\(geometry.coordinates.count)")
                LabeledContent("Created", value: dateFormatter.string(from: geometry.createdAt))
            }

            Section("Measurements") {
                if geometry.geometryType == .polygon, let area = geometry.area {
                    LabeledContent("Area", value: GeoCalculator.formatArea(area))
                }
                if let perimeter = geometry.perimeter {
                    let label = geometry.geometryType == .polygon ? "Perimeter" : "Length"
                    LabeledContent(label, value: GeoCalculator.formatLength(perimeter))
                }
            }

            if geometry.geometryType == .polygon {
                Section("Style") {
                    if let fillColor = geometry.fillColor {
                        LabeledContent("Fill Color", value: fillColor)
                    }
                    if let strokeColor = geometry.strokeColor {
                        LabeledContent("Stroke Color", value: strokeColor)
                    }
                    if let strokeWidth = geometry.strokeWidth {
                        LabeledContent("Stroke Width", value: String(format: "%.1f", strokeWidth))
                    }
                }
            }

            Section("Coordinates") {
                ForEach(Array(geometry.coordinates.enumerated()), id: \.offset) { index, coord in
                    if coord.count >= 2 {
                        LabeledContent(
                            "Point \(index + 1)",
                            value: String(format: "%.6f, %.6f", coord[1], coord[0])
                        )
                    }
                }
            }

            Section("Export") {
                Button {
                    showingGeoJSONExport = true
                } label: {
                    Label("Export as GeoJSON", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle(geometry.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingGeoJSONExport) {
            NavigationStack {
                GeoJSONExportView(geoJSON: geometry.toGeoJSON(), name: geometry.name)
            }
        }
    }
}

// MARK: - GeoJSON Export View

private struct GeoJSONExportView: View {
    @Environment(\.dismiss) private var dismiss

    let geoJSON: String
    let name: String

    var body: some View {
        ScrollView {
            Text(geoJSON)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .navigationTitle("GeoJSON")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }

            ToolbarItem(placement: .primaryAction) {
                ShareLink(
                    item: geoJSON,
                    subject: Text(name),
                    message: Text("GeoJSON export from Ayllu")
                )
            }
        }
    }
}
