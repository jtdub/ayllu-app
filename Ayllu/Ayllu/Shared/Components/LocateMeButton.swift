import SwiftUI

/// Floating button to center the map on the user's current location
struct LocateMeButton: View {
    let hasLocation: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "location.fill")
                .font(.system(size: 20))
                .foregroundStyle(hasLocation ? .blue : .secondary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(radius: 2)
        }
        .disabled(!hasLocation)
    }
}

#Preview {
    VStack(spacing: 20) {
        LocateMeButton(hasLocation: true) {
            // Action
        }

        LocateMeButton(hasLocation: false) {
            // Action
        }
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
