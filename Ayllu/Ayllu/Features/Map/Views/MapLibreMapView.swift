import SwiftUI
import MapLibre
import CoreLocation

/// UIViewRepresentable wrapper for MapLibre's MLNMapView
/// Provides offline-capable map with OpenTopoMap tiles
struct MapLibreMapView: UIViewRepresentable {
    @Binding var waypoints: [Waypoint]
    @Binding var selectedWaypoint: Waypoint?
    @Binding var userLocation: CLLocation?
    var onQuickWaypointTap: ((CLLocationCoordinate2D) -> Void)?

    // OpenTopoMap tile URL template
    private static let openTopoMapURL = "https://tile.opentopomap.org/{z}/{x}/{y}.png"

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Configure map settings
        mapView.showsUserLocation = true
        mapView.showsUserHeadingIndicator = true
        mapView.compassViewPosition = .topRight
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = false

        // Set initial camera
        if let location = userLocation {
            mapView.setCenter(location.coordinate, zoomLevel: 14, animated: false)
        } else {
            // Default to center of contiguous US
            mapView.setCenter(
                CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
                zoomLevel: 4,
                animated: false
            )
        }

        // Configure tile source
        configureTileSource(mapView)

        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        // Update waypoint annotations
        updateAnnotations(mapView, context: context)

        // Center on user location if available and not already tracking
        if let location = userLocation, !context.coordinator.hasSetInitialLocation {
            mapView.setCenter(location.coordinate, zoomLevel: 14, animated: true)
            context.coordinator.hasSetInitialLocation = true
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Private Methods

    private func configureTileSource(_ mapView: MLNMapView) {
        // Use the default demo style - OpenTopoMap tiles will be added after style loads
        mapView.styleURL = URL(string: "https://demotiles.maplibre.org/style.json")
    }

    private func updateAnnotations(_ mapView: MLNMapView, context: Context) {
        // Remove existing waypoint annotations
        if let existingAnnotations = mapView.annotations?.filter({ $0 is WaypointAnnotation }) {
            mapView.removeAnnotations(existingAnnotations)
        }

        // Add new waypoint annotations
        let annotations = waypoints.map { waypoint in
            WaypointAnnotation(waypoint: waypoint)
        }
        mapView.addAnnotations(annotations)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: MapLibreMapView
        var hasSetInitialLocation = false

        init(_ parent: MapLibreMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            // Add OpenTopoMap as raster source after style loads
            let options: [MLNTileSourceOption: Any] = [
                .tileSize: NSNumber(value: 256),
                .minimumZoomLevel: NSNumber(value: 1),
                .maximumZoomLevel: NSNumber(value: 17)
            ]

            let source = MLNRasterTileSource(
                identifier: "opentopomap",
                tileURLTemplates: [MapLibreMapView.openTopoMapURL],
                options: options
            )

            style.addSource(source)

            let rasterLayer = MLNRasterStyleLayer(identifier: "opentopomap-layer", source: source)
            style.addLayer(rasterLayer)
        }

        func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            guard let waypointAnnotation = annotation as? WaypointAnnotation else {
                return nil
            }

            let reuseIdentifier = "waypoint-\(waypointAnnotation.waypoint.category?.rawValue ?? "other")"

            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)

            if annotationView == nil {
                annotationView = MLNAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
                annotationView?.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
                annotationView?.backgroundColor = markerColor(for: waypointAnnotation.waypoint.category)
                annotationView?.layer.cornerRadius = 15
                annotationView?.layer.borderWidth = 2
                annotationView?.layer.borderColor = UIColor.white.cgColor
            }

            return annotationView
        }

        func mapView(_ mapView: MLNMapView, didSelect annotation: MLNAnnotation) {
            guard let waypointAnnotation = annotation as? WaypointAnnotation else { return }
            parent.selectedWaypoint = waypointAnnotation.waypoint
            mapView.deselectAnnotation(annotation, animated: true)
        }

        func mapView(_ mapView: MLNMapView, annotationCanShowCallout annotation: MLNAnnotation) -> Bool {
            return annotation is WaypointAnnotation
        }

        private func markerColor(for category: WaypointCategory?) -> UIColor {
            guard let category = category else { return .systemRed }
            switch category {
            case .site: return .systemPurple
            case .feature: return .systemBlue
            case .artifact: return .systemOrange
            case .sample: return .systemGreen
            case .photoPoint: return .systemYellow
            case .controlPoint, .datum: return .black
            case .observation: return .systemCyan
            case .specimen: return .systemMint
            case .transectMarker: return .systemIndigo
            case .other: return .systemRed
            }
        }
    }
}

// MARK: - Waypoint Annotation

/// Custom annotation class for waypoints
class WaypointAnnotation: NSObject, MLNAnnotation {
    let waypoint: Waypoint

    var coordinate: CLLocationCoordinate2D {
        waypoint.coordinate
    }

    var title: String? {
        waypoint.name
    }

    var subtitle: String? {
        waypoint.category?.displayName
    }

    init(waypoint: Waypoint) {
        self.waypoint = waypoint
        super.init()
    }
}

// MARK: - Preview

#Preview {
    MapLibreMapView(
        waypoints: .constant([]),
        selectedWaypoint: .constant(nil),
        userLocation: .constant(nil)
    )
}
