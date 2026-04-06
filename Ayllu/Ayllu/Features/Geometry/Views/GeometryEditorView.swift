import SwiftUI
import MapLibre
import CoreLocation
import GRDB

/// Full-screen editor for drawing polygons and polylines on the map
struct GeometryEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let projectId: Int64
    let dbPool: DatabasePool
    let locationService: LocationService
    var existingGeometry: Geometry?
    var onSave: () -> Void

    @State private var viewModel: GeometryEditorViewModel?
    @State private var showingNameSheet = false

    init(
        projectId: Int64,
        dbPool: DatabasePool,
        locationService: LocationService,
        existingGeometry: Geometry? = nil,
        onSave: @escaping () -> Void
    ) {
        self.projectId = projectId
        self.dbPool = dbPool
        self.locationService = locationService
        self.existingGeometry = existingGeometry
        self.onSave = onSave
    }

    var body: some View {
        Group {
            if let viewModel {
                ZStack {
                    GeometryDrawingMapView(
                        vertices: viewModel.vertices,
                        geometryType: viewModel.geometryType,
                        userLocation: locationService.currentLocation,
                        onTapMap: { coordinate in
                            viewModel.addVertex(coordinate)
                        }
                    )
                    .ignoresSafeArea(edges: .bottom)

                    // Top info bar
                    VStack {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(viewModel.vertices.count) vertices")
                                    .font(.caption.bold())
                                if let area = viewModel.formattedArea {
                                    Text("Area: \(area)")
                                        .font(.caption)
                                }
                                if viewModel.perimeter > 0 {
                                    let label = viewModel.geometryType == .polygon ? "Perimeter" : "Length"
                                    Text("\(label): \(viewModel.formattedPerimeter)")
                                        .font(.caption)
                                }
                            }
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            Spacer()
                        }
                        .padding()

                        Spacer()

                        // Bottom toolbar
                        HStack(spacing: 16) {
                            // Type toggle
                            Button {
                                viewModel.geometryType = viewModel.geometryType == .polygon ? .polyline : .polygon
                            } label: {
                                Label(
                                    viewModel.geometryType.displayName,
                                    systemImage: viewModel.geometryType.iconName
                                )
                                .font(.caption)
                            }
                            .buttonStyle(.bordered)

                            // GPS Trace toggle
                            Button {
                                if viewModel.isTracing {
                                    viewModel.stopGPSTrace()
                                } else {
                                    viewModel.startGPSTrace()
                                }
                            } label: {
                                Label(
                                    viewModel.isTracing ? "Stop Trace" : "GPS Trace",
                                    systemImage: viewModel.isTracing ? "location.fill" : "location"
                                )
                                .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .tint(viewModel.isTracing ? .red : .accentColor)

                            // Undo
                            Button {
                                viewModel.undoLastVertex()
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            .disabled(viewModel.vertices.isEmpty)
                            .buttonStyle(.bordered)

                            Spacer()

                            // Save
                            Button {
                                showingNameSheet = true
                            } label: {
                                Label("Save", systemImage: "checkmark")
                                    .font(.caption.bold())
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.vertices.count < 2)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Draw Geometry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .sheet(isPresented: $showingNameSheet) {
            NavigationStack {
                GeometryNameSheet(viewModel: viewModel!) {
                    onSave()
                    dismiss()
                }
            }
            .presentationDetents([.medium])
        }
        .onAppear {
            if viewModel == nil {
                let vm = GeometryEditorViewModel(
                    dbPool: dbPool,
                    locationService: locationService,
                    projectId: projectId
                )
                if let existing = existingGeometry {
                    vm.loadExisting(existing)
                }
                viewModel = vm
            }
            locationService.startUpdatingLocation()
        }
        .onChange(of: locationService.currentLocation) { _, newLocation in
            guard let location = newLocation else { return }
            viewModel?.processTraceLocation(location)
        }
    }
}

// MARK: - Name Sheet

private struct GeometryNameSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: GeometryEditorViewModel
    let onComplete: () -> Void

    var body: some View {
        Form {
            Section("Geometry Details") {
                TextField("Name", text: Binding(
                    get: { viewModel.name },
                    set: { viewModel.name = $0 }
                ))

                TextField("Description (optional)", text: Binding(
                    get: { viewModel.description },
                    set: { viewModel.description = $0 }
                ), axis: .vertical)
            }

            if let area = viewModel.formattedArea {
                Section("Measurements") {
                    LabeledContent("Area", value: area)
                    LabeledContent("Perimeter", value: viewModel.formattedPerimeter)
                }
            }
        }
        .navigationTitle("Save Geometry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if viewModel.save() {
                        dismiss()
                        onComplete()
                    }
                }
                .disabled(!viewModel.isValid)
            }
        }
    }
}

// MARK: - Geometry Drawing Map View

struct GeometryDrawingMapView: UIViewRepresentable {
    let vertices: [CLLocationCoordinate2D]
    let geometryType: GeometryType
    let userLocation: CLLocation?
    let onTapMap: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.showsUserLocation = true
        mapView.showsUserHeadingIndicator = true
        mapView.logoView.isHidden = true

        // Initial position
        if let location = userLocation {
            mapView.setCenter(location.coordinate, zoomLevel: 16, animated: false)
        } else {
            mapView.setCenter(
                CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
                zoomLevel: 4,
                animated: false
            )
        }

        // Configure tile source
        mapView.styleURL = URL(string: "https://demotiles.maplibre.org/style.json")

        // Add tap gesture
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tap)

        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        context.coordinator.updateOverlays(mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: GeometryDrawingMapView
        private var currentPolyline: MLNPolyline?
        private var currentPolygon: MLNPolygon?
        private var vertexAnnotations: [MLNPointAnnotation] = []

        init(_ parent: GeometryDrawingMapView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MLNMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onTapMap(coordinate)
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            // Add OpenTopoMap tiles
            let options: [MLNTileSourceOption: Any] = [
                .tileSize: NSNumber(value: 256),
                .minimumZoomLevel: NSNumber(value: 1),
                .maximumZoomLevel: NSNumber(value: 17)
            ]
            let source = MLNRasterTileSource(
                identifier: "opentopomap",
                tileURLTemplates: ["https://tile.opentopomap.org/{z}/{x}/{y}.png"],
                options: options
            )
            style.addSource(source)
            let rasterLayer = MLNRasterStyleLayer(identifier: "opentopomap-layer", source: source)
            style.addLayer(rasterLayer)

            updateOverlays(mapView)
        }

        func updateOverlays(_ mapView: MLNMapView) {
            // Remove existing overlays
            if let polyline = currentPolyline {
                mapView.removeAnnotation(polyline)
                currentPolyline = nil
            }
            if let polygon = currentPolygon {
                mapView.removeAnnotation(polygon)
                currentPolygon = nil
            }
            for annotation in vertexAnnotations {
                mapView.removeAnnotation(annotation)
            }
            vertexAnnotations.removeAll()

            let vertices = parent.vertices
            guard !vertices.isEmpty else { return }

            // Draw vertex markers
            for (index, coord) in vertices.enumerated() {
                let point = MLNPointAnnotation()
                point.coordinate = coord
                point.title = "Point \(index + 1)"
                mapView.addAnnotation(point)
                vertexAnnotations.append(point)
            }

            // Draw shape
            if vertices.count >= 2 {
                var coords = vertices
                if parent.geometryType == .polygon && vertices.count >= 3 {
                    let polygon = MLNPolygon(coordinates: &coords, count: UInt(coords.count))
                    mapView.addAnnotation(polygon)
                    currentPolygon = polygon
                } else {
                    let polyline = MLNPolyline(coordinates: &coords, count: UInt(coords.count))
                    mapView.addAnnotation(polyline)
                    currentPolyline = polyline
                }
            }
        }

        func mapView(_ mapView: MLNMapView, alphaForShapeAnnotation annotation: MLNShape) -> CGFloat {
            if annotation is MLNPolygon {
                return 0.25
            }
            return 1.0
        }

        func mapView(_ mapView: MLNMapView, strokeColorForShapeAnnotation annotation: MLNShape) -> UIColor {
            .systemBlue
        }

        func mapView(_ mapView: MLNMapView, fillColorForPolygonAnnotation annotation: MLNPolygon) -> UIColor {
            .systemBlue
        }

        func mapView(_ mapView: MLNMapView, lineWidthForPolylineAnnotation annotation: MLNPolyline) -> CGFloat {
            3.0
        }
    }
}
