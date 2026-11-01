import SwiftUI
import ShowModel

/// The "Playback" tab: pages of 4x4 big buttons, grand master, blackout, and the fade time.
struct PlaybackView: View {
    @Binding var document: ShowDocument
    @ObservedObject var model: AppModel
    @State private var page = 0
    @State private var selectedID: UUID?

    static let perPage = 16

    private var snapshots: [Snapshot] { document.show.snapshots }
    private var pageCount: Int { max(1, (snapshots.count + Self.perPage - 1) / Self.perPage) }
    private var pageSnapshots: [Snapshot] {
        let start = min(page * Self.perPage, snapshots.count)
        return Array(snapshots[start..<min(start + Self.perPage, snapshots.count)])
    }

    var body: some View {
        VStack(spacing: 10) {
            ProgrammerBanner(model: model)
            HStack(spacing: 16) {
                GrandMasterFader(model: model)
                Spacer()
                BlackoutButton(model: model)
            }
            if snapshots.isEmpty {
                Text("No snapshots yet. Record one in the Programmer tab.")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(Array(pageSnapshots.enumerated()), id: \.element.id) { i, snap in
                        PlaybackButton(snapshot: snap, slot: i + 1,
                                       isOn: model.activeSnapshots.contains(snap.id),
                                       isSelected: selectedID == snap.id) { layered in
                            selectedID = snap.id
                            model.recall(snap.id, layered: layered, fade: nil)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            if model.outputMode == .consoleMIDI { consoleLooks }
            HStack {
                fadeEditor
                Spacer()
                Button { page = max(0, page - 1) } label: { Image(systemName: "chevron.left") }
                    .disabled(page == 0).accessibilityIdentifier("pagePrev")
                Text("Page \(page + 1) / \(pageCount)").monospacedDigit()
                Button { page = min(pageCount - 1, page + 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(page >= pageCount - 1).accessibilityIdentifier("pageNext")
            }
        }
        .padding(12)
        .onChange(of: snapshots.count) { _, _ in page = min(page, pageCount - 1) }
    }

    /// Fade time of the last-clicked snapshot, editable here. It is used by every recall of that snapshot.
    @ViewBuilder private var fadeEditor: some View {
        if let id = selectedID, let index = snapshots.firstIndex(where: { $0.id == id }) {
            HStack {
                Text("Fade for \u{201C}\(snapshots[index].name)\u{201D}")
                TextField("s", value: Binding(
                    get: { document.show.snapshots[index].defaultFade },
                    set: { document.show.snapshots[index].defaultFade = min(max($0, 0), 600) }),
                          format: .number.precision(.fractionLength(0...2)))
                    .textFieldStyle(.roundedBorder).frame(width: 70)
                    .accessibilityIdentifier("fadeTimeField")
                Text("seconds")
            }
        } else {
            Text("Click a button, then set its fade time here.").foregroundStyle(.secondary)
        }
    }

    private var consoleLooks: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Console looks").font(.headline)
            if document.show.console.looks.isEmpty {
                Text("No looks yet. Build them in the Console tab.").foregroundStyle(.secondary)
            }
            HStack {
                ForEach(document.show.console.looks) { look in
                    Button(look.name) { Task { await model.recall(look) } }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("playbackLook.\(look.name)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
