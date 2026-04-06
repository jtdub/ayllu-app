import SwiftUI

/// Horizontal scrollable breadcrumb navigation for record hierarchy
struct BreadcrumbView: View {
    let breadcrumbs: [Record]
    let onTapRoot: () -> Void
    let onTapBreadcrumb: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button {
                    onTapRoot()
                } label: {
                    Label("Root", systemImage: "house")
                        .font(.caption)
                        .foregroundStyle(breadcrumbs.isEmpty ? .primary : .secondary)
                }
                .buttonStyle(.plain)

                ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, record in
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Button {
                        onTapBreadcrumb(index)
                    } label: {
                        Text(record.name)
                            .font(.caption)
                            .foregroundStyle(index == breadcrumbs.count - 1 ? .primary : .secondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }
}
