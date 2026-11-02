import SwiftUI
import ShowModel

/// Cue list editor sheet: a table of cues with a Direct and a Console column.
struct CueListEditor: View {
    let listID: UUID
    @Binding var document: ShowDocument
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var note: String?

    private var index: Int? { document.show.cueLists.firstIndex { $0.id == listID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let i = index {
                header(i)
                ConsoleBackupBanner(list: document.show.cueLists[i], show: document.show)
                columnTitles
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(Array($document.show.cueLists[i].cues.enumerated()), id: \.element.id) { row, $cue in
                            CueRow(cue: $cue, row: row + 1, show: document.show, model: model) {
                                document.show.cueLists[i].cues.removeAll { $0.id == cue.id }
                            }
                        }
                        if document.show.cueLists[i].cues.isEmpty {
                            Text("No cues yet. Play a look, then press \u{201C}Add cue from current look\u{201D}.")
                                .foregroundStyle(.secondary).padding(20)
                        }
                    }
                }
                HStack {
                    Button("Add cue") { addCue(to: i, direct: nil) }
                        .accessibilityIdentifier("addCue")
                    Button("Add cue from current look") { addFromLook(to: i) }
                        .help("Captures the playing snapshots and running effects as the Direct part")
                        .accessibilityIdentifier("addCueFromLook")
                    if let note { Text(note).font(.caption).foregroundStyle(.orange) }
                    Spacer()
                    Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("cueListDone")
                }
            } else {
                Text("This cue list was deleted.")
                Button("Close") { dismiss() }
            }
        }
        .padding(16)
        .frame(width: 860, height: 520)
        .onChange(of: index.map { document.show.cueLists[$0].cues.map(\.number) } ?? []) { _, numbers in
            guard let i = index, numbers != numbers.sorted() else { return }
            document.show.cueLists[i].cues.sort { $0.number < $1.number }
        }
    }

    private func header(_ i: Int) -> some View {
        HStack {
            TextField("Name", text: $document.show.cueLists[i].name).textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260).accessibilityIdentifier("cueListNameField")
            Toggle("Loop", isOn: $document.show.cueLists[i].loops).accessibilityIdentifier("cueListLoops")
            Spacer()
        }
    }

    private var columnTitles: some View {
        HStack(spacing: 8) {
            Text("#").frame(width: 56, alignment: .leading)
            Text("Name").frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
            Text("Fade s").frame(width: 56, alignment: .leading)
            Text("Follow").frame(width: 110, alignment: .leading)
            Text("Direct").frame(width: 140, alignment: .leading)
            Text("Console").frame(width: 140, alignment: .leading)
            Color.clear.frame(width: 24)
        }
        .font(.caption).foregroundStyle(.secondary)
    }

    private func nextNumber(_ i: Int) -> Double {
        (document.show.cueLists[i].cues.map(\.number).max()).map { $0.rounded(.down) + 1 } ?? 1
    }

    private func addCue(to i: Int, direct: DirectCuePart?) {
        let cue = Cue(number: nextNumber(i), fade: 1, direct: direct)
        document.show.cueLists[i].cues.append(cue)
    }

    /// Direct part = what is playing now: active snapshots and running effects.
    private func addFromLook(to i: Int) {
        let part = DirectCuePart(snapshotIDs: model.activeSnapshots, effectIDs: model.runningEffects.map(\.effectID))
        guard !part.snapshotIDs.isEmpty || !part.effectIDs.isEmpty else {
            note = "Nothing is playing. Play a snapshot or effect first."
            return
        }
        note = nil
        addCue(to: i, direct: part)
    }
}
