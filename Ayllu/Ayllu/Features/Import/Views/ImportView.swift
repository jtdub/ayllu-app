import SwiftUI
import UniformTypeIdentifiers

/// Main import flow: file picker → preview → import
struct ImportView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(\.dismiss) private var dismiss

    let projectId: Int64

    @State private var viewModel: ImportViewModel?
    @State private var showingFilePicker = false
    @State private var showingColumnMapping = false

    var body: some View {
        Group {
            if let viewModel {
                importContent(viewModel)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Import Data")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.commaSeparatedText, .json, .xml],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel?.parseFile(url: url)
                }
            case .failure(let error):
                viewModel?.error = error.localizedDescription
            }
        }
        .sheet(isPresented: $showingColumnMapping) {
            if let viewModel {
                NavigationStack {
                    CSVColumnMappingView(headers: viewModel.csvHeaders) { mapping in
                        viewModel.applyCSVMapping(mapping)
                    }
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = ImportViewModel(dbPool: database.dbPool, projectId: projectId)
                showingFilePicker = true
            }
        }
        .onChange(of: viewModel?.needsColumnMapping) { _, needsMapping in
            if needsMapping == true {
                showingColumnMapping = true
            }
        }
    }

    @ViewBuilder
    private func importContent(_ viewModel: ImportViewModel) -> some View {
        if viewModel.isParsing {
            VStack(spacing: 16) {
                ProgressView()
                Text("Parsing file...")
                    .foregroundStyle(.secondary)
            }
        } else if let result = viewModel.importResult {
            importCompleteView(result)
        } else if viewModel.parsedItems.isEmpty {
            if let error = viewModel.error {
                ContentUnavailableView(
                    "Import Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                ContentUnavailableView(
                    "No Items Found",
                    systemImage: "doc.questionmark",
                    description: Text("Select a GPX, CSV, or GeoJSON file to import.")
                )
            }
        } else {
            previewList(viewModel)
        }
    }

    @ViewBuilder
    private func previewList(_ viewModel: ImportViewModel) -> some View {
        VStack(spacing: 0) {
            selectionBar(viewModel)
            Divider()
            itemList(viewModel)
            importButton(viewModel)
        }
    }

    @ViewBuilder
    private func selectionBar(_ viewModel: ImportViewModel) -> some View {
        HStack {
            Text("\(viewModel.selectedCount) of \(viewModel.parsedItems.count) selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button("All") { viewModel.selectAll() }
                .font(.subheadline)
            Button("None") { viewModel.deselectAll() }
                .font(.subheadline)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func itemList(_ viewModel: ImportViewModel) -> some View {
        List {
            if viewModel.waypointCount > 0 {
                Section("Waypoints (\(viewModel.waypointCount))") {
                    ForEach(viewModel.parsedItems.filter(\.isWaypoint)) { item in
                        ImportPreviewRow(
                            item: item,
                            isSelected: viewModel.selectedItemIds.contains(item.id),
                            onToggle: { viewModel.toggleItem(item.id) }
                        )
                    }
                }
            }
            if viewModel.geometryCount > 0 {
                Section("Geometries (\(viewModel.geometryCount))") {
                    ForEach(viewModel.parsedItems.filter { !$0.isWaypoint }) { item in
                        ImportPreviewRow(
                            item: item,
                            isSelected: viewModel.selectedItemIds.contains(item.id),
                            onToggle: { viewModel.toggleItem(item.id) }
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func importButton(_ viewModel: ImportViewModel) -> some View {
        Button {
            viewModel.performImport()
        } label: {
            HStack {
                if viewModel.isImporting {
                    ProgressView()
                        .tint(.white)
                }
                Text("Import \(viewModel.selectedCount) Items")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.selectedCount > 0 ? .blue : .gray)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(viewModel.selectedCount == 0 || viewModel.isImporting)
        .padding()
    }

    @ViewBuilder
    private func importCompleteView(_ result: ImportResult) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Import Complete")
                .font(.title2.bold())

            VStack(spacing: 8) {
                if result.waypointsCreated > 0 {
                    Label(
                        "\(result.waypointsCreated) waypoints imported",
                        systemImage: "mappin"
                    )
                }
                if result.geometriesCreated > 0 {
                    Label(
                        "\(result.geometriesCreated) geometries imported",
                        systemImage: "pentagon"
                    )
                }
            }
            .font(.body)

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
