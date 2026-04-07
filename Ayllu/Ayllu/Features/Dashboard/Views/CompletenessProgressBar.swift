import SwiftUI

/// Horizontal progress bar with color coding based on completion percentage
struct CompletenessProgressBar: View {
    let value: Double
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(.fill.tertiary)
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.completeness(value))
                    .frame(width: max(0, geometry.size.width * value), height: height)
            }
        }
        .frame(height: height)
    }
}
