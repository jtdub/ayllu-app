import SwiftUI
import MapLibre
import CoreLocation

// MARK: - Region Selection Map View

struct RegionSelectionMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationService.self) private var locationService
    @Binding var selectedBounds: MLNCoordinateBounds?

    @State private var centerCoordinate = CLLocationCoordinate2D(
        latitude: 39.8283,
        longitude: -98.5795
    )
    @State private var zoomLevel: Double = 8
    @State private var hasInitializedLocation = false

    var body: some View {
        NavigationStack {
            ZStack {
                RegionSelectionMapViewRepresentable(
                    centerCoordinate: $centerCoordinate,
                    zoomLevel: $zoomLevel,
                    userLocation: locationService.currentLocation
                )
                .ignoresSafeArea()
                .onAppear {
                    // Initialize with user's current location
                    if let location = locationService.currentLocation, !hasInitializedLocation {
                        centerCoordinate = location.coordinate
                        zoomLevel = 12 // Closer zoom for user's location
                        hasInitializedLocation = true
                    }
                    locationService.startUpdatingLocation()
                }

                // Selection rectangle overlay
                GeometryReader { geometry in
                    let rectSize = min(geometry.size.width, geometry.size.height) * 0.7
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 3)
                        .background(Color.blue.opacity(0.1))
                        .frame(width: rectSize, height: rectSize)
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height / 2
                        )
                }
                .allowsHitTesting(false)

                VStack {
                    Spacer()
                    Text("Pan and zoom to select area")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle("Select Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        confirmSelection()
                    }
                }
            }
        }
    }

    private func confirmSelection() {
        // Calculate bounds based on visible region
        // This is a simplified calculation - the actual bounds depend on map view size
        let latSpan = 0.5 / pow(2, zoomLevel - 8)
        let lonSpan = 0.5 / pow(2, zoomLevel - 8)

        let sw = CLLocationCoordinate2D(
            latitude: centerCoordinate.latitude - latSpan,
            longitude: centerCoordinate.longitude - lonSpan
        )
        let ne = CLLocationCoordinate2D(
            latitude: centerCoordinate.latitude + latSpan,
            longitude: centerCoordinate.longitude + lonSpan
        )

        selectedBounds = MLNCoordinateBounds(sw: sw, ne: ne)
        dismiss()
    }
}

// MARK: - Region Selection Map Representable

struct RegionSelectionMapViewRepresentable: UIViewRepresentable {
    @Binding var centerCoordinate: CLLocationCoordinate2D
    @Binding var zoomLevel: Double
    let userLocation: CLLocation?

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true

        // Center on user location if available, otherwise use provided coordinate
        if let location = userLocation {
            mapView.setCenter(location.coordinate, zoomLevel: 12, animated: false)
            context.coordinator.hasSetInitialLocation = true
        } else {
            mapView.setCenter(centerCoordinate, zoomLevel: zoomLevel, animated: false)
        }

        mapView.styleURL = URL(string: "https://demotiles.maplibre.org/style.json")
        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        // Center on user location if it becomes available and hasn't been set yet
        if let location = userLocation, !context.coordinator.hasSetInitialLocation {
            mapView.setCenter(location.coordinate, zoomLevel: 12, animated: true)
            context.coordinator.hasSetInitialLocation = true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: RegionSelectionMapViewRepresentable
        var hasSetInitialLocation = false

        init(_ parent: RegionSelectionMapViewRepresentable) {
            self.parent = parent
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            parent.centerCoordinate = mapView.centerCoordinate
            parent.zoomLevel = mapView.zoomLevel
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            // Add OpenTopoMap layer
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

            let layer = MLNRasterStyleLayer(identifier: "opentopomap-layer", source: source)
            style.addLayer(layer)
        }
    }
}

#Preview {
    RegionSelectionMapView(selectedBounds: .constant(nil))
}
