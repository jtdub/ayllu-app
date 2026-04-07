import SwiftUI

extension Color {
    static func completeness(_ value: Double) -> Color {
        if value >= 0.8 { return .green }
        if value >= 0.5 { return .yellow }
        return .red
    }
}
