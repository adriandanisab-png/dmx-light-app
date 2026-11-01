import SwiftUI
import ShowModel

/// The "Programmer" tab: stage on the left, controls on the right.
struct ProgrammerView: View {
    @Binding var document: ShowDocument
    @Binding var selection: [UUID]
    @ObservedObject var model: AppModel
    @State private var showRecord = false

    private var patch: Patch { document.show.patch }

    var body: some View {
        HSplitView {
            StageView(document: $document, selection: $selection, model: model)
                .frame(minWidth: 380)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ProgrammerBanner(model: model)
                    selectionList
                    IntensityControl(model: model)
                    ColorControl(model: model)
                    if selectedTypes.contains(where: hasPanTilt) { PanTiltPad(model: model) }
                    StrobeControl(model: model)
                    RawChannelFaders(patch: patch, selection: selection, model: model)
                    HStack {
                        Button("Record\u{2026}") { showRecord = true }
                            .disabled(model.programmer.isEmpty)
                            .accessibilityIdentifier("recordButton")
                        Button("Clear (Esc)") { model.clearProgrammer() }
                            .keyboardShortcut(.escape, modifiers: [])
                            .accessibilityIdentifier("clearProgrammer")
                    }
                    Divider()
                    library
                }
                .padding(12)
            }
            .frame(minWidth: 380, idealWidth: 440, maxWidth: 560)
        }
        .sheet(isPresented: $showRecord) {
            RecordSnapshotSheet { name, hex in
                document.show.snapshots.append(model.programmer.record(name: name, colorHex: hex))
            }
        }
    }

    private var selectedTypes: [FixtureType] {
        selection.compactMap { id in patch.fixtures.first { $0.id == id } }.compactMap { patch.type(of: $0) }
    }

    private func hasPanTilt(_ t: FixtureType) -> Bool {
        t.channels.contains { $0.function == .pan } && t.channels.contains { $0.function == .tilt }
    }

    private var selectionBinding: Binding<Set<UUID>> {
        Binding(get: { Set(selection) },
                set: { new in
                    var ordered = selection.filter { new.contains($0) }
                    ordered += patch.fixtures.map(\.id).filter { new.contains($0) && !ordered.contains($0) }
                    selection = ordered
                })
    }

    private var selectionList: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Fixtures (\(selection.count) selected)").font(.headline)
                Spacer()
                Button("Select all") { selection = patch.fixtures.map(\.id) }
                    .accessibilityIdentifier("selectAllButton")
                Button("None") { selection = [] }
            }
            List(patch.fixtures, selection: selectionBinding) { f in
                Text(f.name).tag(f.id)
                    .accessibilityIdentifier("fixtureRow.\(f.name)")
            }
            .frame(height: 120)
            .accessibilityIdentifier("fixtureList")
        }
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Library").font(.headline)
            if document.show.snapshots.isEmpty {
                Text("No snapshots yet. Record one from the programmer.").foregroundStyle(.secondary)
            }
            ForEach(Array(document.show.snapshots.enumerated()), id: \.element.id) { index, snap in
                HStack {
                    Circle().fill(Color(hex: snap.colorHex)).frame(width: 12, height: 12)
                    Text(snap.name).accessibilityIdentifier("librarySnapshot.\(index)")
                    Spacer()
                    Button { document.show.snapshots.removeAll { $0.id == snap.id } } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                }
            }
        }
        .accessibilityIdentifier("library")
    }
}

/// "Programmer active: overrides playback", with a clear button, while the programmer holds values.
struct ProgrammerBanner: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if !model.programmer.isEmpty {
            HStack {
                Text("Programmer active: overrides playback")
                Spacer()
                Button("Clear") { model.clearProgrammer() }
            }
            .padding(8)
            .background(Color.orange.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(.black)
            .accessibilityIdentifier("programmerBanner")
        }
    }
}
