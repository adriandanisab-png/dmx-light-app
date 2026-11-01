import SwiftUI
import AppKit
import ShowModel

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count != 6 { s = "808080" }
        let v = UInt32(s, radix: 16) ?? 0x808080
        self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255, opacity: 1)
    }

    var hexString: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.gray
        let r = Int((c.redComponent * 255).rounded()), g = Int((c.greenComponent * 255).rounded()),
            b = Int((c.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

/// Edits a cell's name, colour and notes. Only reachable targets are shown, so no bad note can be mapped.
struct ConsoleCellEditor: View {
    let target: ConsoleTarget
    @Binding var map: ConsoleMap
    @Environment(\.dismiss) private var dismiss

    private var cell: Binding<ConsoleCell> {
        Binding(get: { map.cells[target] ?? ConsoleCell() },
                set: { map.cells[target] = $0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit \(target.shortTitle)").font(.title2)
            TextField("Name", text: cell.name).textFieldStyle(.roundedBorder)
            ColorPicker("Colour", selection: Binding(
                get: { Color(hex: cell.wrappedValue.colorHex) },
                set: { cell.wrappedValue.colorHex = $0.hexString }))
            Text("Notes").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: cell.notes).frame(height: 80).border(Color.gray.opacity(0.4))
            HStack {
                Button("Clear", role: .destructive) { map.cells[target] = nil; dismiss() }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 360)
    }
}
