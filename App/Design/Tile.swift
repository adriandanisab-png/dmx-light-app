import SwiftUI
import AppKit

/// Big playback tile (snapshots and effects): tinted when off, full colour with a soft glow and a white ring when on.
struct TileButtonStyle: ButtonStyle {
    let color: Color
    var isOn: Bool
    var isSelected = false
    var minHeight: CGFloat = 72

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        configuration.label
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(Space.xs)
            .foregroundStyle(isOn ? color.readableForeground : Color.primary)
            .background(shape.fill(color.opacity(isOn ? 1 : 0.22)))
            .overlay(shape.stroke(isOn ? Color.white : (isSelected ? Color.white.opacity(0.6) : Color.white.opacity(0.08)),
                                  lineWidth: isOn ? 2 : (isSelected ? 1.5 : 1)))
            .shadow(color: isOn ? color.opacity(0.65) : .clear, radius: 10)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(shape)
    }
}

/// Name in headline weight plus a small caption.
struct TileLabel: View {
    let title: String
    var caption: String?

    var body: some View {
        VStack(spacing: 2) {
            Text(title).font(.headline).lineLimit(2).multilineTextAlignment(.center)
            if let caption { Text(caption).font(.caption).opacity(0.75) }
        }
    }
}

extension Color {
    /// Black on light colours, white on dark ones.
    var readableForeground: Color {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .white
        let l = 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
        return l > 0.6 ? .black : .white
    }
}
