import SwiftUI
import ShowModel

/// One cue: number, name, fade, follow, and the Direct and Console parts.
struct CueRow: View {
    @Binding var cue: Cue
    let row: Int
    let show: Show
    @ObservedObject var model: AppModel
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("#", value: $cue.number, format: .number.precision(.fractionLength(0...3)))
                .textFieldStyle(.roundedBorder).frame(width: 56)
                .accessibilityIdentifier("cueNumber.\(row)")
            TextField("Name", text: $cue.name).textFieldStyle(.roundedBorder)
                .frame(minWidth: 100, maxWidth: .infinity)
                .accessibilityIdentifier("cueName.\(row)")
            TextField("s", value: Binding(get: { cue.fade }, set: { cue.fade = min(max($0, 0), 600) }),
                      format: .number.precision(.fractionLength(0...2)))
                .textFieldStyle(.roundedBorder).frame(width: 56)
                .accessibilityIdentifier("cueFade.\(row)")
            followMenu.frame(width: 110, alignment: .leading)
            DirectPartMenu(cue: $cue, show: show, row: row).frame(width: 140, alignment: .leading)
            ConsolePartMenu(cue: $cue, show: show, model: model, row: row).frame(width: 140, alignment: .leading)
            Button(action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.borderless).frame(width: 24)
                .accessibilityLabel("Delete cue \(AppModel.numberText(cue.number))")
                .accessibilityIdentifier("cueDelete.\(row)")
        }
    }

    private var autoDelay: Double {
        if case let .auto(after) = cue.follow { return after }
        return 0
    }

    private var followMenu: some View {
        HStack(spacing: 4) {
            Menu {
                Button("Manual") { cue.follow = .manual }
                Button("Auto-follow") { cue.follow = .auto(after: 0) }
            } label: {
                Text(cue.follow == .manual ? "Manual" : "Auto")
            }
            .fixedSize().accessibilityIdentifier("cueFollow.\(row)")
            if case .auto = cue.follow {
                TextField("s", value: Binding(get: { autoDelay }, set: { cue.follow = .auto(after: min(max($0, 0), 600)) }),
                          format: .number.precision(.fractionLength(0...2)))
                    .textFieldStyle(.roundedBorder).frame(width: 44)
                    .accessibilityIdentifier("cueFollowDelay.\(row)")
            }
        }
    }
}
