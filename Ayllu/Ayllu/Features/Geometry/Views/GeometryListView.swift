import SwiftUI

/// List of geometries (polygons/polylines) for a project
struct GeometryListView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(LocationService.self) private var locationService

    let projectId: Int64

    @State private var viewModel: GeometryListViewModel?
    @State private var showingEditor = false

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.geometries.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Geometries",
                        systemImage: "pentagon",
                        description: Text("Draw polygons or polylines to record areas and boundaries.")
                    )
                } else {
                    List {
                        ForEach(viewModel.geometries) { geometry in
                            NavigationLink {
                                GeometryDetailView(geometry: geometry)
                            } label: {
                                GeometryRow(geometry: geometry)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.deleteGeometry(viewModel.geometries[index])
                            }
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Geometries")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .fullScreenCover(isPresented: $showingEditor) {
            NavigationStack {
                GeometryEditorView(
                    projectId: projectId
                ) {
                    viewModel?.loadGeometries()
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = GeometryListViewModel(dbPool: database.dbPool, projectId: projectId)
            }
            viewModel?.loadGeometries()
        }
    }
}

// MARK: - Geometry Row

private struct GeometryRow: View {
    let geometry: Geometry

    var body: some View {
        HStack {
            Image(systemName: geometry.geometryType.iconName)
                .foregroundStyle(.secondary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(geometry.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(geometry.geometryType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let area = geometry.area, geometry.geometryType == .polygon {
                        Text(GeoCalculator.formatArea(area))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let perimeter = geometry.perimeter {
                        Text(GeoCalculator.formatLength(perimeter))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("\(geometry.coordinates.count) vertices")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
