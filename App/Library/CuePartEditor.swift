import SwiftUI
import ShowModel

/// Orange "missing" badge for a cue part that is absent or points at deleted items.
struct MissingBadge: View {
    var text = "missing"
    var body: some View {
        Text(text).font(.caption.bold())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.orange, in: Capsule()).foregroundStyle(.black)
    }
}

/// Picks the snapshots and effects a cue plays in Direct mode.
struct DirectPartMenu: View {
    @Binding var cue: Cue
    let show: Show
    let row: Int

    private var part: DirectCuePart? { cue.direct }
    private var hasUsable: Bool {
        guard let d = part else { return false }
        if d.snapshotIDs.isEmpty && d.effectIDs.isEmpty { return true }
        return d.snapshotIDs.contains { id in show.snapshots.contains { $0.id == id } }
            || d.effectIDs.contains { id in show.effects.contains { $0.id == id } }
    }

    var body: some View {
        Menu {
            if !show.snapshots.isEmpty { Text("Snapshots") }
            ForEach(show.snapshots) { s in
                Toggle(s.name, isOn: Binding(get: { part?.snapshotIDs.contains(s.id) ?? false },
                                             set: { on in edit { $0.snapshotIDs = toggled($0.snapshotIDs, s.id, on) } }))
            }
            if !show.effects.isEmpty { Divider(); Text("Effects") }
            ForEach(show.effects) { e in
                Toggle(e.name, isOn: Binding(get: { part?.effectIDs.contains(e.id) ?? false },
                                             set: { on in edit { $0.effectIDs = toggled($0.effectIDs, e.id, on) } }))
            }
            Divider()
            Button("Empty look (all dark)") { cue.direct = DirectCuePart() }
            Button("Remove Direct part") { cue.direct = nil }
        } label: {
            if hasUsable, let d = part {
                Text(d.snapshotIDs.isEmpty && d.effectIDs.isEmpty ? "empty" : "\(d.snapshotIDs.count) snap, \(d.effectIDs.count) fx")
            } else {
                MissingBadge()
            }
        }
        .fixedSize()
        .accessibilityIdentifier("cueDirect.\(row)")
    }

    private func edit(_ change: (inout DirectCuePart) -> Void) {
        var d = cue.direct ?? DirectCuePart()
        change(&d)
        cue.direct = d
    }

    private func toggled(_ ids: [UUID], _ id: UUID, _ on: Bool) -> [UUID] {
        on ? (ids.contains(id) ? ids : ids + [id]) : ids.filter { $0 != id }
    }
}

/// Picks the console look (or the current console state) a cue recalls in Console mode.
struct ConsolePartMenu: View {
    @Binding var cue: Cue
    let show: Show
    @ObservedObject var model: AppModel
    let row: Int

    var body: some View {
        Menu {
            Button("Current console state (\(model.console.state.on.count) cells)") {
                cue.console = .targets(model.console.state.on)
            }
            if !show.console.looks.isEmpty { Divider(); Text("Looks") }
            ForEach(show.console.looks) { look in
                Button(look.name.isEmpty ? "Look" : look.name) { cue.console = .look(look.id) }
            }
            Divider()
            Button("Remove Console part") { cue.console = nil }
        } label: {
            switch cue.console {
            case nil: MissingBadge()
            case let .look(id)?:
                if let look = show.console.looks.first(where: { $0.id == id }) { Text(look.name) }
                else { MissingBadge(text: "missing look") }
            case let .targets(set)?: Text("\(set.count) cells")
            }
        }
        .fixedSize()
        .accessibilityIdentifier("cueConsole.\(row)")
    }
}
