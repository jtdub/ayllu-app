import SwiftUI

/// A row displaying a parsed import item with selection toggle
struct ImportPreviewRow: View {
    let item: ParsedItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)

                Image(systemName: iconName)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch item {
        case .waypoint: return "mappin"
        case .geometry(let geo):
            return geo.geometryType == .polygon ? "pentagon" : "line.diagonal"
        }
    }

    private var subtitle: String {
        switch item {
        case .waypoint(let wp):
            return String(format: "%.4f, %.4f", wp.latitude, wp.longitude)
        case .geometry(let geo):
            return "\(geo.geometryType.displayName) - \(geo.coordinates.count) vertices"
        }
    }
}
