import SwiftUI
import ShowModel

/// Playback page cue panel: list picker, current/next cue, GO (Space), Back and the mode.
struct CueListPanel: View {
    @Binding var document: ShowDocument
    @ObservedObject var model: AppModel

    private var lists: [CueList] { document.show.cueLists }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionHeader("Cue list", systemImage: "list.number") {
                    if !lists.isEmpty {
                        // A popup in the window would take keyboard focus and swallow the B / T / Space shortcuts.
                        Menu {
                            Button("None") { model.selectCueList(nil) }
                            ForEach(lists) { l in Button(l.name) { model.selectCueList(l.id) } }
                        } label: {
                            Text(model.activeCueList?.name ?? "Choose\u{2026}")
                        }
                        .fixedSize()
                        .accessibilityIdentifier("cueListPicker")
                    }
                    Text(model.cueMode == .direct ? "Mode: Direct" : "Mode: Console")
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("cueMode")
                }
                if lists.isEmpty {
                    HStack {
                        Text("No cue lists yet. Build one in the Library page.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                } else if let list = model.activeCueList {
                    HStack(alignment: .center, spacing: Space.md) {
                        cueBox("Current", model.cueCurrent, "cueCurrent")
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        cueBox("Next", model.cueNext, "cueNext")
                        Spacer()
                        Button { model.back() } label: {
                            Label("Back", systemImage: "backward.fill").frame(minWidth: 64)
                        }
                        .controlSize(.extraLarge)
                        .help("Previous cue")
                        .accessibilityIdentifier("cueBack")
                        Button { model.go() } label: {
                            Text("GO").font(.title.bold()).frame(minWidth: 110)
                        }
                        .buttonStyle(.borderedProminent).tint(.green)
                        .controlSize(.extraLarge)
                        .keyboardShortcut(.space, modifiers: [])
                        .help("Next cue (Space)")
                        .accessibilityIdentifier("cueGo")
                    }
                    ConsoleBackupBanner(list: list, show: document.show)
                }
            }
        }
        .onAppear { autoSelect() }
        .onChange(of: lists.count) { _, _ in autoSelect() }
    }

    /// A single list needs no picking.
    private func autoSelect() {
        if model.activeCueListID == nil, lists.count == 1 { model.selectCueList(lists[0].id) }
    }

    private func cueBox(_ title: String, _ cue: Cue?, _ id: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            Text(cue.map { AppModel.numberText($0.number) } ?? "\u{2014}")
                .font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                .accessibilityIdentifier("\(id)Number")
            Text(cue?.name ?? "").font(.caption).lineLimit(1)
                .accessibilityIdentifier("\(id)Name")
        }
        .frame(minWidth: 100, alignment: .leading)
    }
}

/// Orange "N cues have no console backup" warning; hidden when every cue has a usable Console part.
struct ConsoleBackupBanner: View {
    let list: CueList
    let show: Show

    var body: some View {
        let n = list.cuesWithoutConsoleBackup(in: show)
        if n > 0 {
            NoticeBanner(text: n == 1 ? "1 cue has no console backup" : "\(n) cues have no console backup")
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("consoleBackupBanner")
        }
    }
}

extension CueList {
    /// Cues whose Console part is missing or points at a deleted look.
    func cuesWithoutConsoleBackup(in show: Show) -> Int {
        cues.filter { !$0.hasConsoleBackup(in: show) }.count
    }
}

extension Cue {
    func hasConsoleBackup(in show: Show) -> Bool {
        switch console {
        case nil: return false
        case let .look(id)?: return show.console.looks.contains { $0.id == id }
        case .targets?: return true
        }
    }
}
