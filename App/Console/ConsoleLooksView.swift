import SwiftUI
import ShowModel

/// Looks: sets of cells to be on. Recall sends only the toggles needed from the believed state.
struct ConsoleLooksView: View {
    @Binding var map: ConsoleMap
    @Binding var selection: Set<ConsoleTarget>
    let mode: ConsoleMode
    @EnvironmentObject var model: AppModel
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Looks").font(.headline)
            HStack {
                TextField("Look name", text: $newName).textFieldStyle(.roundedBorder)
                Button("Save look") {
                    let targets = selection.subtracting([.blackout])
                    map.looks.append(ConsoleLook(name: newName.isEmpty ? "Look \(map.looks.count + 1)" : newName,
                                                 targets: targets))
                    newName = ""; selection = []
                }
                .disabled(selection.isEmpty)
                .accessibilityIdentifier("saveLook")
            }
            Text(selection.isEmpty ? "Switch to Select mode and click cells to build a look."
                                   : "\(selection.count) cell(s) selected")
                .font(.caption).foregroundStyle(.secondary)
            if !selection.isEmpty { Button("Clear selection") { selection = [] }.font(.caption) }
            ForEach($map.looks) { $look in
                HStack {
                    Button {
                        Task { await model.recall(look) }
                    } label: {
                        Text("Recall").frame(minWidth: 56, minHeight: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("recallLook.\(look.name)")
                    TextField("Name", text: $look.name).textFieldStyle(.roundedBorder)
                    Text("\(look.targets.count)").font(.caption).foregroundStyle(.secondary)
                    Button { map.looks.removeAll { $0.id == look.id } } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                }
            }
        }
    }
}
