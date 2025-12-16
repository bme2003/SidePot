import SwiftUI

enum AppTheme {
    static let corner: CGFloat = 16
}

struct Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(.thinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.corner)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.corner))
    }
}

extension View {
    func card() -> some View { modifier(Card()) }
}

struct Pill: View {
    var text: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(.thinMaterial)
        .overlay(
            Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

struct SectionHeader: View {
    var title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct Banner: View {
    var title: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .card()
    }
}
