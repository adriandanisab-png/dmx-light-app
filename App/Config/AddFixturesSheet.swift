import SwiftUI
import ShowModel

/// Adds several fixtures of one type; shows `PatchError` text inline.
struct AddFixturesSheet: View {
    @Binding var patch: Patch
    var preferredTypeID: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var typeID: UUID?
    @State private var count = "1"
    @State private var startAddress = ""
    @State private var prefix = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add fixtures").font(.title2)
            Picker("Type", selection: $typeID) {
                ForEach(patch.types) { Text($0.name).tag(Optional($0.id)) }
            }
            .accessibilityIdentifier("addType")
            TextField("Count", text: $count).accessibilityIdentifier("addCount")
            TextField("Start address (blank = auto)", text: $startAddress).accessibilityIdentifier("addStart")
            TextField("Name prefix", text: $prefix).accessibilityIdentifier("addPrefix")
            if let error {
                Text(error).foregroundStyle(.red).accessibilityIdentifier("addError")
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Add") { add() }
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("addFixturesConfirm")
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(20).frame(width: 380)
        .onAppear {
            typeID = preferredTypeID.flatMap { id in patch.types.contains { $0.id == id } ? id : nil }
                ?? patch.types.last?.id
            if prefix.isEmpty { prefix = patch.types.first { $0.id == typeID }?.name ?? "Fixture" }
        }
        .onChange(of: typeID) { _, new in
            if let name = patch.types.first(where: { $0.id == new })?.name { prefix = name }
        }
    }

    private func add() {
        guard let typeID else { error = "Choose a fixture type."; return }
        guard let n = Int(count.trimmingCharacters(in: .whitespaces)) else { error = "Count must be a number."; return }
        let trimmed = startAddress.trimmingCharacters(in: .whitespaces)
        var start: Int?
        if !trimmed.isEmpty {
            guard let s = Int(trimmed) else { error = "Start address must be a number or blank."; return }
            start = s
        }
        do {
            try patch.addFixtures(typeID: typeID, count: n, startAddress: start, namePrefix: prefix)
            dismiss()
        } catch PatchError.unknownType {
            error = "That fixture type no longer exists."
        } catch PatchError.noRoom {
            error = "No room: these fixtures don't fit in the 512 channels from that address."
        } catch PatchError.invalidCount {
            error = "Count must be at least 1."
        } catch {
            self.error = String(describing: error)
        }
    }
}
