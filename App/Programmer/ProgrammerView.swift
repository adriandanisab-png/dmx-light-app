import SwiftUI
import ShowModel

/// The Programmer page: stage on the left, grouped controls on the right, Record / Clear in a bottom bar.
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
            VStack(spacing: 0) {
                ProgrammerBanner(model: model).padding([.horizontal, .top], Space.sm)
                Form {
                    selectionSection
                    Section {
                        IntensityControl(model: model)
                    } header: { Label("Intensity", systemImage: "sun.max") }
                    Section {
                        ColorControl(model: model)
                    } header: { Label("Colour", systemImage: "paintpalette") }
                    if selectedTypes.contains(where: hasPanTilt) {
                        Section {
                            PanTiltPad(model: model)
                        } header: { Label("Position", systemImage: "scope") }
                    }
                    Section {
                        StrobeControl(model: model)
                    } header: { Label("Strobe", systemImage: "bolt") }
                    Section {
                        RawChannelFaders(patch: patch, selection: selection, model: model)
                    } header: { Label("Channels", systemImage: "slider.vertical.3") }
                    library
                }
                .formStyle(.grouped)
                bottomBar
            }
            .frame(minWidth: 400, idealWidth: 460, maxWidth: 560)
        }
        .sheet(isPresented: $showRecord) {
            RecordSnapshotSheet { name, hex in
                document.show.snapshots.append(model.programmer.record(name: name, colorHex: hex))
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: Space.sm) {
            Button { model.clearProgrammer() } label: { Label("Clear", systemImage: "xmark.circle") }
                .keyboardShortcut(.escape, modifiers: [])
                .help("Clear the programmer (Esc)")
                .accessibilityLabel("Clear (Esc)")
                .accessibilityIdentifier("clearProgrammer")
            Spacer()
            Button { showRecord = true } label: { Label("Record\u{2026}", systemImage: "record.circle") }
                .buttonStyle(.borderedProminent)
                .disabled(model.programmer.isEmpty)
                .help("Record the programmer as a snapshot")
                .accessibilityIdentifier("recordButton")
        }
        .controlSize(.large)
        .padding(Space.sm)
        .background(.bar)
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

    private var selectionSection: some View {
        Section {
            if patch.fixtures.isEmpty {
                ContentUnavailableView {
                    Label("No fixtures", systemImage: "lightbulb.slash")
                } description: {
                    Text("Add fixtures on the Fixtures page first.")
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                List(patch.fixtures, selection: selectionBinding) { f in
                    Text(f.name).tag(f.id)
                        .accessibilityIdentifier("fixtureRow.\(f.name)")
                }
                .frame(height: 120)
                .accessibilityIdentifier("fixtureList")
            }
        } header: {
            HStack {
                Label("Selection", systemImage: "checkmark.circle")
                Text("\(selection.count) selected").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Select all") { selection = patch.fixtures.map(\.id) }
                    .accessibilityIdentifier("selectAllButton")
                Button("None") { selection = [] }
            }
            .controlSize(.small)
        }
    }

    private var library: some View {
        Section {
            if document.show.snapshots.isEmpty {
                Text("No snapshots yet. Record one from the programmer.").foregroundStyle(.secondary)
            }
            ForEach(Array(document.show.snapshots.enumerated()), id: \.element.id) { index, snap in
                HStack {
                    Circle().fill(Color(hex: snap.colorHex)).frame(width: 12, height: 12)
                    Text(snap.name)
                        .accessibilityLabel(snap.name)
                        .accessibilityIdentifier("librarySnapshot.\(index)")
                    Spacer()
                    Button { document.show.snapshots.removeAll { $0.id == snap.id } } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .help("Delete \(snap.name)")
                        .accessibilityLabel("Delete \(snap.name)")
                }
                .accessibilityElement(children: .contain)
            }
        } header: {
            Label("Recorded", systemImage: "books.vertical")
        }
    }
}

/// "Programmer active: overrides playback", with a clear button, while the programmer holds values.
struct ProgrammerBanner: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if !model.programmer.isEmpty {
            HStack(spacing: Space.xs) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("Programmer active: overrides playback").font(.callout)
                Spacer()
                Button("Clear") { model.clearProgrammer() }.controlSize(.small)
            }
            .padding(.horizontal, Space.sm).padding(.vertical, Space.xs)
            .background(Color.orange.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.4), lineWidth: 1))
            .accessibilityIdentifier("programmerBanner")
        }
    }
}
