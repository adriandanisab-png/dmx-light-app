import SwiftUI
import AppKit
import ShowModel

/// Colour picker plus 12 quick swatches.
struct ColorControl: View {
    @ObservedObject var model: AppModel
    @State private var color = Color.white

    static let swatches: [(name: String, hex: String)] = [
        ("red", "#FF0000"), ("orange", "#FF8000"), ("amber", "#FFBF00"), ("yellow", "#FFFF00"),
        ("lime", "#80FF00"), ("green", "#00FF00"), ("cyan", "#00FFFF"), ("blue", "#0000FF"),
        ("purple", "#8000FF"), ("magenta", "#FF00FF"), ("pink", "#FF80C0"), ("white", "#FFFFFF"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            LabeledContent("Custom") {
                ColorPicker("", selection: Binding(get: { color }, set: { apply($0) }), supportsOpacity: false)
                    .labelsHidden()
                    .accessibilityIdentifier("programmerColorPicker")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), alignment: .leading, spacing: 6) {
                ForEach(Self.swatches, id: \.name) { s in
                    Button { apply(Color(hex: s.hex)) } label: {
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: s.hex))
                            .frame(height: 28)
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
                    .help(s.name.capitalized)
                    .accessibilityLabel(s.name)
                    .accessibilityIdentifier("swatch.\(s.name)")
                }
            }
        }
    }

    private func apply(_ c: Color) {
        color = c
        let ns = NSColor(c).usingColorSpace(.sRGB) ?? .white
        let rgb = RGB(r: Double(ns.redComponent), g: Double(ns.greenComponent), b: Double(ns.blueComponent))
        model.programmerColor(rgb)
    }
}
