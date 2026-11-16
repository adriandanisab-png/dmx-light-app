import SwiftUI

/// Spacing scale used everywhere so pages line up.
enum Space {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
}

/// Rounded container with a hairline stroke: the one "panel" look for every page.
struct Card<Content: View>: View {
    var padding: CGFloat = Space.md
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}

/// Title row with an SF Symbol and an optional trailing accessory (buttons, captions).
struct SectionHeader<Trailing: View>: View {
    let title: String
    var systemImage: String?
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, systemImage: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.systemImage = systemImage
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: Space.xs) {
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(.secondary).imageScale(.medium)
            }
            Text(title).font(.headline)
            Spacer(minLength: Space.xs)
            trailing()
        }
    }
}

/// Orange / red notice strip used for "programmer active", backup warnings and patch problems.
struct NoticeBanner: View {
    enum Tone { case warning, error }
    let text: String
    var tone: Tone = .warning
    var systemImage = "exclamationmark.triangle.fill"

    var body: some View {
        let color: Color = tone == .error ? .red : .orange
        HStack(spacing: Space.xs) {
            Image(systemName: systemImage).foregroundStyle(color)
            Text(text).font(.callout)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
        .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.4), lineWidth: 1))
    }
}
