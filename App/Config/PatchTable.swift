import SwiftUI
import ShowModel

/// The patch: one editable row per fixture, with a red badge on rows that have problems.
struct PatchTable: View {
    @Binding var patch: Patch
    @Binding var selectedFixtureID: UUID?

    var body: some View {
        let issues = patch.validate()
        let badged = Set(issues.flatMap { PatchIssueText.fixtureIDs(for: $0, in: patch) })
        VStack(spacing: 0) {
            HStack {
                Text("Name").frame(width: 150, alignment: .leading)
                Text("Type").frame(width: 150, alignment: .leading)
                Text("Address").frame(width: 70, alignment: .leading)
                Text("Scanner").frame(width: 70, alignment: .leading)
                Text("Ch").frame(width: 36, alignment: .leading)
                Spacer()
            }
            .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12)
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach($patch.fixtures) { $fixture in
                        row($fixture, hasIssue: badged.contains(fixture.id), issues: issues)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private func row(_ fixture: Binding<Fixture>, hasIssue: Bool, issues: [PatchIssue]) -> some View {
        let f = fixture.wrappedValue
        let selected = selectedFixtureID == f.id
        return HStack {
            TextField("Name", text: fixture.name).textFieldStyle(.roundedBorder).frame(width: 150)
            Picker("", selection: fixture.typeID) {
                ForEach(patch.types) { Text($0.name).tag($0.id) }
            }
            .labelsHidden().frame(width: 150)
            TextField("1", text: intText(fixture.address, fallback: f.address))
                .textFieldStyle(.roundedBorder).frame(width: 70)
                .accessibilityIdentifier("addressField.\(f.address)")
            TextField("\u{2013}", text: optionalIntText(fixture.consoleScanner))
                .textFieldStyle(.roundedBorder).frame(width: 70)
            Text("\(patch.type(of: f)?.channelCount ?? 0)").frame(width: 36, alignment: .leading)
            if hasIssue {
                Label("Problem", systemImage: "exclamationmark.triangle.fill")
                    .labelStyle(.iconOnly).foregroundStyle(.red)
                    .help(issues.filter { PatchIssueText.fixtureIDs(for: $0, in: patch).contains(f.id) }
                        .map { PatchIssueText.text(for: $0, in: patch) }.joined(separator: "\n"))
            }
            Spacer()
            Button { patch.fixtures.removeAll { $0.id == f.id } } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless)
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 6)
            .fill(hasIssue ? Color.red.opacity(0.2) : (selected ? Color.accentColor.opacity(0.25) : Color.clear)))
        .contentShape(Rectangle())
        .onTapGesture { selectedFixtureID = f.id }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("patchRow.\(f.address)")
    }

    private func intText(_ value: Binding<Int>, fallback: Int) -> Binding<String> {
        Binding(get: { String(value.wrappedValue) }, set: { if let v = Int($0) { value.wrappedValue = v } })
    }

    private func optionalIntText(_ value: Binding<Int?>) -> Binding<String> {
        Binding(get: { value.wrappedValue.map(String.init) ?? "" },
                set: { value.wrappedValue = Int($0) })
    }
}
