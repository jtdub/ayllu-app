import SwiftUI
import CoreLocation

/// Post-capture review screen for adding caption and saving
struct PhotoReviewView: View {
    let image: UIImage
    let projectId: Int64
    let waypointId: Int64?
    let location: CLLocation?
    let heading: CLHeading?
    let onSave: (String?) -> Void
    let onRetake: () -> Void

    @State private var caption = ""
    @FocusState private var isCaptionFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Photo preview
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: .infinity)
                .background(Color.black)

            // Bottom panel
            VStack(spacing: 16) {
                // Location info
                if let location = location {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.green)
                        Text(CoordinateFormatter.format(
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            format: .decimal
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                // Caption field
                TextField("Add a caption...", text: $caption, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .focused($isCaptionFocused)

                // Action buttons
                HStack(spacing: 16) {
                    Button {
                        onRetake()
                    } label: {
                        Label("Retake", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onSave(caption.isEmpty ? nil : caption)
                    } label: {
                        Label("Save", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(.regularMaterial)
        }
        .onTapGesture {
            isCaptionFocused = false
        }
    }
}

#Preview {
    PhotoReviewView(
        image: UIImage(systemName: "photo")!,
        projectId: 1,
        waypointId: nil,
        location: CLLocation(latitude: 37.7749, longitude: -122.4194),
        heading: nil,
        onSave: { _ in },
        onRetake: {}
    )
}
