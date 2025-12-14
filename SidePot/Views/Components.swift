import SwiftUI

struct Pill: View {
    var text: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(.thinMaterial)
        .clipShape(Capsule())
    }
}

struct Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

extension View {
    func card() -> some View { modifier(Card()) }
}
