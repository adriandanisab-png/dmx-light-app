import SwiftUI
import ShowModel

/// The Playback page: grand master and blackout, cue panel, running effects, snapshot tiles and effects.
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
        HSplitView {
            controls.frame(minWidth: 420)
            // Live preview of the whole show while playing it back.
            // Clicking fixtures here picks them for the preset effects.
            StageView(document: $document, selection: $model.effectTargets, model: model, editable: false, selectOnly: true)
                .frame(minWidth: 280)
                .accessibilityIdentifier("playbackStagePreview")
        }
    }

    private var controls: some View {
        VStack(spacing: Space.sm) {
            ProgrammerBanner(model: model)
            // Top strip: grand master and blackout.
            Card(padding: Space.sm) {
                HStack(spacing: Space.md) {
                    GrandMasterFader(model: model)
                    BlackoutButton(model: model)
                }
            }
            // Live controls stay pinned; only the buttons scroll.
            CueListPanel(document: $document, model: model)
            RunningEffectsBar(document: $document, model: model)
            ScrollView {
                VStack(alignment: .leading, spacing: Space.md) {
                    snapshotsCard
                    if model.outputMode == .consoleMIDI { consoleLooks }
                    EffectsSection(document: $document, model: model)
                }
                .padding(.trailing, 2)
            }
        }
        .padding(Space.md)
        .onChange(of: snapshots.count) { _, _ in page = min(page, pageCount - 1) }
    }

    private var snapshotsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionHeader("Snapshots", systemImage: "square.grid.2x2") {
                    if pageCount > 1 {
                        Button { page = max(0, page - 1) } label: { Image(systemName: "chevron.left") }
                            .buttonStyle(.borderless).help("Previous page")
                            .disabled(page == 0).accessibilityIdentifier("pagePrev")
                        Text("Page \(page + 1) / \(pageCount)").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                        Button { page = min(pageCount - 1, page + 1) } label: { Image(systemName: "chevron.right") }
                            .buttonStyle(.borderless).help("Next page")
                            .disabled(page >= pageCount - 1).accessibilityIdentifier("pageNext")
                    }
                }
                if snapshots.isEmpty {
                    ContentUnavailableView {
                        Label("No snapshots yet", systemImage: "square.grid.2x2")
                    } description: {
                        Text("Record a look in the Programmer and it shows up here as a button.")
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.xs), count: 4), spacing: Space.xs) {
                        ForEach(Array(pageSnapshots.enumerated()), id: \.element.id) { i, snap in
                            PlaybackButton(snapshot: snap, slot: i + 1,
                                           isOn: model.activeSnapshots.contains(snap.id),
                                           isSelected: selectedID == snap.id) { layered in
                                selectedID = snap.id
                                model.recall(snap.id, layered: layered, fade: nil)
                            }
                        }
                    }
                    Divider()
                    fadeEditor
                }
            }
        }
    }

    /// Fade time of the last-clicked snapshot, editable here. It is used by every recall of that snapshot.
    @ViewBuilder private var fadeEditor: some View {
        if let id = selectedID, let index = snapshots.firstIndex(where: { $0.id == id }) {
            HStack {
                Image(systemName: "timer").foregroundStyle(.secondary)
                Text("Fade for \u{201C}\(snapshots[index].name)\u{201D}")
                TextField("s", value: Binding(
                    get: { document.show.snapshots[index].defaultFade },
                    set: { document.show.snapshots[index].defaultFade = min(max($0, 0), 600) }),
                          format: .number.precision(.fractionLength(0...2)))
                    .textFieldStyle(.roundedBorder).frame(width: 70)
                    .accessibilityIdentifier("fadeTimeField")
                Text("seconds").foregroundStyle(.secondary)
            }
            .font(.callout)
        } else {
            Text("Click a button, then set its fade time here.").font(.callout).foregroundStyle(.secondary)
        }
    }

    private var consoleLooks: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionHeader("Console looks", systemImage: "pianokeys")
                if document.show.console.looks.isEmpty {
                    Text("No looks yet. Build them on the Console page.").font(.callout).foregroundStyle(.secondary)
                }
                HStack {
                    ForEach(document.show.console.looks) { look in
                        Button(look.name) { Task { await model.recall(look) } }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("playbackLook.\(look.name)")
                    }
                }
            }
        }
    }
}
