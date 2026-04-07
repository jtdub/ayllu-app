import SwiftUI

/// Circular progress indicator with percentage label and color coding
struct CompletenessRingView: View {
    let value: Double
    var size: CGFloat = 80
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(.fill.tertiary, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: value)
                .stroke(Color.completeness(value), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(value * 100))%")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(Color.completeness(value))
        }
        .frame(width: size, height: size)
    }
}
