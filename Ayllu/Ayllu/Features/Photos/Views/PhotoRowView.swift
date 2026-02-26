import SwiftUI

/// Grid cell component for displaying a photo thumbnail
struct PhotoRowView: View {
    let photo: Photo

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail image
            if let thumbnailURL = photo.thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .empty:
                        Color.gray.opacity(0.3)
                            .overlay {
                                ProgressView()
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Color.gray.opacity(0.3)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        Color.gray.opacity(0.3)
                    }
                }
            } else if let fileURL = photo.fileURL {
                // Fallback to full image if no thumbnail
                AsyncImage(url: fileURL) { phase in
                    switch phase {
                    case .empty:
                        Color.gray.opacity(0.3)
                            .overlay {
                                ProgressView()
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Color.gray.opacity(0.3)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        Color.gray.opacity(0.3)
                    }
                }
            } else {
                // No image available
                Color.gray.opacity(0.3)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }

            // Overlays
            VStack(alignment: .trailing, spacing: 4) {
                // Location badge
                if photo.hasLocation {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(.blue.opacity(0.8))
                        .clipShape(Circle())
                }

                // Waypoint badge
                if photo.waypointId != nil {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(.green.opacity(0.8))
                        .clipShape(Circle())
                }
            }
            .padding(6)
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    let photo = Photo(
        id: 1,
        projectId: 1,
        filePath: "/path/to/photo.jpg",
        thumbnailPath: "/path/to/thumbnail.jpg",
        caption: "Test photo",
        latitude: 37.7749,
        longitude: -122.4194
    )

    return PhotoRowView(photo: photo)
        .frame(width: 150, height: 150)
}
