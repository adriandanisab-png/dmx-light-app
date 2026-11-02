import SwiftUI
import ShowModel

/// Sheet payload for the effect editor (`isNew` = not yet in the show).
struct EffectEditTarget: Identifiable {
    var effect: Effect
    var isNew: Bool
    var id: UUID { effect.id }
}

struct CueListEditTarget: Identifiable { var id: UUID }

/// The "Library" tab: snapshots, effects and cue lists with create, duplicate, rename, colour and delete.
struct LibraryView: View {
    @Binding var document: ShowDocument
    @ObservedObject var model: AppModel
    @State private var effectTarget: EffectEditTarget?
    @State private var cueListTarget: CueListEditTarget?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                snapshotsSection
                Divider()
                effectsSection
                Divider()
                cueListsSection
            }
            .padding(16)
        }
        .sheet(item: $effectTarget) { target in
            EffectEditor(target: target, document: $document, model: model)
        }
        .sheet(item: $cueListTarget) { target in
            CueListEditor(listID: target.id, document: $document, model: model)
        }
    }

    // MARK: Snapshots

    private var snapshotsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Snapshots").font(.title3.bold())
            if document.show.snapshots.isEmpty {
                Text("No snapshots yet. Record one in the Programmer tab.").foregroundStyle(.secondary)
            }
            ForEach($document.show.snapshots) { $snap in
                LibraryRow(name: $snap.name, colorHex: $snap.colorHex, identifier: "snapshot.\(snap.name)",
                           onDuplicate: {
                               var copy = snap; copy.id = UUID(); copy.name = snap.name + " copy"
                               document.show.snapshots.append(copy)
                           },
                           onDelete: { document.show.snapshots.removeAll { $0.id == snap.id } })
            }
        }
    }

    // MARK: Effects

    private var effectsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Effects").font(.title3.bold())
                Spacer()
                Button("New effect") {
                    effectTarget = EffectEditTarget(effect: Effect(name: "", kind: .intensityChase, fixtureIDs: []),
                                                    isNew: true)
                }
                .accessibilityIdentifier("newEffectButton")
            }
            if document.show.effects.isEmpty {
                Text("No effects yet. Make one here, or click a preset on the Playback page.")
                    .foregroundStyle(.secondary)
            }
            ForEach($document.show.effects) { $effect in
                EffectRow(effect: $effect,
                          onEdit: { effectTarget = EffectEditTarget(effect: effect, isNew: false) },
                          onDuplicate: {
                              var copy = effect; copy.id = UUID(); copy.name = effect.name + " copy"
                              document.show.effects.append(copy)
                          },
                          onDelete: { document.show.effects.removeAll { $0.id == effect.id } })
            }
        }
    }

    // MARK: Cue lists

    private var cueListsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Cue lists").font(.title3.bold())
                Spacer()
                Button("New cue list") {
                    let list = CueList(name: "Cue list \(document.show.cueLists.count + 1)")
                    document.show.cueLists.append(list)
                    cueListTarget = CueListEditTarget(id: list.id)
                }
                .accessibilityIdentifier("newCueListButton")
            }
            if document.show.cueLists.isEmpty {
                Text("No cue lists yet.").foregroundStyle(.secondary)
            }
            ForEach($document.show.cueLists) { $list in
                HStack {
                    TextField("Name", text: $list.name).textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                        .accessibilityIdentifier("cueListName.\(list.name)")
                    Text("\(list.cues.count) cues").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Edit") { cueListTarget = CueListEditTarget(id: list.id) }
                        .accessibilityIdentifier("editCueList.\(list.name)")
                    Button { duplicate(list) } label: { Image(systemName: "plus.square.on.square") }
                        .help("Duplicate").accessibilityLabel("Duplicate \(list.name)")
                    Button { document.show.cueLists.removeAll { $0.id == list.id } } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless).accessibilityLabel("Delete \(list.name)")
                }
            }
        }
    }

    private func duplicate(_ list: CueList) {
        var copy = list
        copy.id = UUID(); copy.name = list.name + " copy"
        copy.cues = list.cues.map { var c = $0; c.id = UUID(); return c }
        document.show.cueLists.append(copy)
    }
}

/// Name, colour, duplicate and delete for one library item.
struct LibraryRow: View {
    @Binding var name: String
    @Binding var colorHex: String
    let identifier: String
    var onDuplicate: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack {
            ColorPicker("", selection: Binding(get: { Color(hex: colorHex) }, set: { colorHex = $0.hexString }),
                        supportsOpacity: false).labelsHidden()
            TextField("Name", text: $name).textFieldStyle(.roundedBorder).frame(maxWidth: 260)
                .accessibilityIdentifier(identifier)
            Spacer()
            Button(action: onDuplicate) { Image(systemName: "plus.square.on.square") }
                .help("Duplicate").accessibilityLabel("Duplicate \(name)")
            Button(action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.borderless).accessibilityLabel("Delete \(name)")
        }
    }
}
