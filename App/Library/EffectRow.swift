import SwiftUI
import ShowModel

/// One effect in the Library: rename, colour, edit, duplicate, delete.
struct EffectRow: View {
    @Binding var effect: Effect
    var onEdit: () -> Void
    var onDuplicate: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack {
            ColorPicker("", selection: Binding(get: { Color(hex: effect.colorHex) }, set: { effect.colorHex = $0.hexString }),
                        supportsOpacity: false).labelsHidden()
            TextField("Name", text: $effect.name).textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                .accessibilityIdentifier("effectName.\(effect.name)")
            Text("\(EffectEditor.title(effect.kind)) \u{00B7} \(effect.fixtureIDs.count) fixtures")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Edit", action: onEdit).accessibilityIdentifier("editEffect.\(effect.name)")
            Button(action: onDuplicate) { Image(systemName: "plus.square.on.square") }
                .help("Duplicate").accessibilityLabel("Duplicate \(effect.name)")
            Button(action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.borderless).accessibilityLabel("Delete \(effect.name)")
        }
    }
}
