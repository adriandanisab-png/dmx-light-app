import SwiftUI
import ShowModel

/// The Fixtures page (was Config): fixture types, patch, touch test and channel monitor.
struct ConfigView: View {
    @Binding var document: ShowDocument
    @ObservedObject var model: AppModel
    @State private var selectedTypeID: UUID?
    @State private var selectedFixtureID: UUID?
    @State private var showAddSheet = false
    @State private var lowerTab: LowerTab = .touch

    enum LowerTab: String, CaseIterable, Identifiable {
        case touch = "Touch test", monitor = "Channel monitor"
        var id: String { rawValue }
    }

    private var patch: Binding<Patch> { $document.show.patch }

    var body: some View {
        VStack(spacing: 0) {
            IssueBanner(patch: patch.wrappedValue)
                .padding(.horizontal, Space.md).padding(.top, Space.sm)
            HSplitView {
                typesColumn.frame(minWidth: 300, idealWidth: 340, maxWidth: 440)
                VStack(spacing: 0) {
                    SectionHeader("Patch", systemImage: "list.number") {
                        Button { showAddSheet = true } label: { Label("Add fixtures\u{2026}", systemImage: "plus") }
                            .buttonStyle(.borderedProminent)
                            .disabled(patch.wrappedValue.types.isEmpty)
                            .help(patch.wrappedValue.types.isEmpty ? "Create a fixture type first" : "Patch new fixtures")
                            .accessibilityIdentifier("addFixturesButton")
                    }
                    .padding(Space.sm)
                    if patch.wrappedValue.fixtures.isEmpty {
                        ContentUnavailableView {
                            Label("No fixtures patched", systemImage: "lightbulb.slash")
                        } description: {
                            Text(patch.wrappedValue.types.isEmpty
                                 ? "Start with a fixture type: choose New from template on the left."
                                 : "Add fixtures of a type to give them DMX addresses.")
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        PatchTable(patch: patch, selectedFixtureID: $selectedFixtureID)
                    }
                    Divider()
                    Picker("", selection: $lowerTab) {
                        ForEach(LowerTab.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 280).padding(Space.xs)
                    Group {
                        switch lowerTab {
                        case .touch:
                            TouchFaderPanel(patch: patch.wrappedValue, fixtureID: selectedFixtureID, model: model)
                        case .monitor:
                            ChannelMonitorView(model: model)
                        }
                    }
                    .frame(minHeight: 200, idealHeight: 240)
                }
                .frame(minWidth: 560)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddFixturesSheet(patch: patch, preferredTypeID: selectedTypeID)
        }
    }

    private var typesColumn: some View {
        VStack(spacing: 0) {
            SectionHeader("Fixture types", systemImage: "lightspectrum.horizontal") {
                Menu {
                    ForEach(BuiltInTemplates.all) { template in
                        Button(template.name) { addType(from: template) }
                    }
                    Divider()
                    Button("Empty type") { addType(from: FixtureType(name: "New type", channels: [])) }
                } label: {
                    Label("New from template\u{2026}", systemImage: "plus")
                }
                .fixedSize()
                .accessibilityIdentifier("newFromTemplate")
            }
            .padding(Space.sm)
            List(selection: $selectedTypeID) {
                ForEach(patch.wrappedValue.types) { type in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(type.name)
                            Text("\(type.channelCount) ch").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { duplicate(type) } label: { Image(systemName: "plus.square.on.square") }
                            .buttonStyle(.borderless).help("Duplicate")
                        Button { delete(type) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless).help(isUsed(type) ? "In use by fixtures" : "Delete")
                            .disabled(isUsed(type))
                    }
                    .tag(type.id)
                    .accessibilityIdentifier("typeRow.\(type.name)")
                }
            }
            .frame(minHeight: 120, maxHeight: 220)
            Divider()
            if let id = selectedTypeID, let binding = typeBinding(id) {
                FixtureTypeEditor(type: binding)
            } else {
                ContentUnavailableView {
                    Label("No type selected", systemImage: "lightspectrum.horizontal")
                } description: {
                    Text("Select a fixture type to edit its channels.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func typeBinding(_ id: UUID) -> Binding<FixtureType>? {
        guard patch.wrappedValue.types.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { patch.wrappedValue.types.first { $0.id == id } ?? FixtureType(name: "", channels: []) },
            set: { new in
                if let i = patch.wrappedValue.types.firstIndex(where: { $0.id == id }) {
                    patch.wrappedValue.types[i] = new
                }
            })
    }

    private func isUsed(_ type: FixtureType) -> Bool {
        patch.wrappedValue.fixtures.contains { $0.typeID == type.id }
    }

    /// Copies a template with fresh identifiers so edits never touch the built-in.
    private func addType(from template: FixtureType) {
        let copy = FixtureType(name: template.name,
                               channels: template.channels.map {
                                   ChannelDef(name: $0.name, function: $0.function,
                                              defaultValue: $0.defaultValue, ranges: $0.ranges)
                               })
        patch.wrappedValue.types.append(copy)
        selectedTypeID = copy.id
    }

    private func duplicate(_ type: FixtureType) {
        let copy = FixtureType(name: type.name + " copy",
                               channels: type.channels.map {
                                   ChannelDef(name: $0.name, function: $0.function,
                                              defaultValue: $0.defaultValue, ranges: $0.ranges)
                               })
        patch.wrappedValue.types.append(copy)
        selectedTypeID = copy.id
    }

    private func delete(_ type: FixtureType) {
        guard !isUsed(type) else { return }
        patch.wrappedValue.types.removeAll { $0.id == type.id }
        if selectedTypeID == type.id { selectedTypeID = nil }
    }
}

/// Plain-language text for patch problems, shared by the banner and the row badges.
enum PatchIssueText {
    static func text(for issue: PatchIssue, in patch: Patch) -> String {
        func name(_ id: UUID) -> String { patch.fixtures.first { $0.id == id }?.name ?? "Fixture" }
        func fixture(_ id: UUID) -> Fixture? { patch.fixtures.first { $0.id == id } }
        switch issue {
        case let .overlap(a, b):
            return "\(name(b)) overlaps \(name(a)) (address \(fixture(b)?.address ?? 0))"
        case let .pastEnd(id): return "\(name(id)) runs past channel 512"
        case let .addressOutOfRange(id): return "\(name(id)) has an address outside 1\u{2013}512"
        case let .unknownType(id): return "\(name(id)) has no fixture type"
        case let .scannerOutOfRange(id): return "\(name(id)) has a console scanner outside 1\u{2013}12"
        case let .duplicateScanner(s): return "Console scanner \(s) is used twice"
        case let .emptyType(id): return "\(name(id)) uses a type with no channels"
        }
    }

    /// Fixtures an issue should badge.
    static func fixtureIDs(for issue: PatchIssue, in patch: Patch) -> [UUID] {
        switch issue {
        case let .overlap(a, b): return [a, b]
        case let .pastEnd(id), let .addressOutOfRange(id), let .unknownType(id),
             let .scannerOutOfRange(id), let .emptyType(id): return [id]
        case let .duplicateScanner(s): return patch.fixtures.filter { $0.consoleScanner == s }.map(\.id)
        }
    }
}

struct IssueBanner: View {
    let patch: Patch

    var body: some View {
        let issues = patch.validate()
        if !issues.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Label("Patch problems", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline).foregroundStyle(.red)
                ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                    Text(PatchIssueText.text(for: issue, in: patch)).font(.callout)
                }
            }
            .padding(Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.4), lineWidth: 1))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("patchIssueBanner")
        }
    }
}
