import SwiftUI
import AVFoundation

/// UIViewRepresentable wrapper for AVCaptureVideoPreviewLayer with gesture support
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    /// Called with (devicePoint for focus, viewPoint for indicator)
    var onTapToFocus: ((CGPoint, CGPoint) -> Void)?
    /// Called with the target zoom factor (initialZoom * gesture.scale)
    var onPinchZoom: ((CGFloat) -> Void)?
    var initialZoomForPinch: CGFloat = 1.0

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session

        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tapGesture)

        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        view.addGestureRecognizer(pinchGesture)

        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: CameraPreviewView

        init(_ parent: CameraPreviewView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? CameraPreviewUIView,
                  let previewLayer = view.layer as? AVCaptureVideoPreviewLayer else {
                return
            }

            let viewLocation = gesture.location(in: view)
            let devicePoint = previewLayer.captureDevicePointConverted(
                fromLayerPoint: viewLocation
            )
            parent.onTapToFocus?(devicePoint, viewLocation)
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                parent.initialZoomForPinch = parent.initialZoomForPinch // capture current
            case .changed:
                let targetZoom = parent.initialZoomForPinch * gesture.scale
                parent.onPinchZoom?(targetZoom)
            case .ended, .cancelled:
                parent.initialZoomForPinch = parent.initialZoomForPinch // no-op, reset happens in view
            default:
                break
            }
        }
    }
}

/// UIView subclass that hosts AVCaptureVideoPreviewLayer
class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            previewLayer?.session = session
        }
    }

    private var previewLayer: AVCaptureVideoPreviewLayer? {
        layer as? AVCaptureVideoPreviewLayer
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }

    private func setupLayer() {
        previewLayer?.videoGravity = .resizeAspectFill
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
