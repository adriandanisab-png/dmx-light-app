import SwiftUI

/// Asks for a name and colour. Takes a closure, not the model.
struct RecordSnapshotSheet: View {
    var onSave: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var color = Color(hex: "#FF0000")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Record snapshot").font(.title2)
            TextField("Name", text: $name).textFieldStyle(.roundedBorder).accessibilityIdentifier("snapshotName")
            ColorPicker("Button colour", selection: $color, supportsOpacity: false)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Record") {
                    onSave(name.trimmingCharacters(in: .whitespaces).isEmpty ? "Snapshot" : name, color.hexString)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction).accessibilityIdentifier("snapshotSave")
            }
        }
        .padding(20).frame(width: 360)
    }
}
