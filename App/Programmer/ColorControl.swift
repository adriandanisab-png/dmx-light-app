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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Colour").frame(width: 70, alignment: .leading)
                ColorPicker("", selection: Binding(get: { color }, set: { apply($0) }), supportsOpacity: false)
                    .labelsHidden()
                    .accessibilityIdentifier("programmerColorPicker")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 6), count: 12), alignment: .leading, spacing: 6) {
                ForEach(Self.swatches, id: \.name) { s in
                    Button { apply(Color(hex: s.hex)) } label: {
                        RoundedRectangle(cornerRadius: 5).fill(Color(hex: s.hex)).frame(width: 28, height: 22)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.4)))
                    }
                    .buttonStyle(.plain)
                    .help(s.name)
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
