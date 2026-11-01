import SwiftUI
import ShowModel

/// Top bar of the Console tab: mode picker, reset, and the always-visible BLACKOUT button (key B).
struct ConsolePlaybackView: View {
    @Binding var mode: ConsoleMode
    @Binding var showReset: Bool
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Picker("Mode", selection: $mode) {
                ForEach(ConsoleMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).frame(width: 220)
            .accessibilityIdentifier("consoleMode")
            Button("Reset console\u{2026}") { showReset = true }
            Spacer()
            let on = model.console.state.blackout
            Button {
                Task { await model.fire(.blackout) }
            } label: {
                Text("BLACKOUT")
                    .font(.title2.bold())
                    .frame(minWidth: 180, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(on ? .red : .gray)
            .keyboardShortcut("b", modifiers: [])
            .help("Blackout (B)")
            .accessibilityIdentifier("blackoutButton")
            .accessibilityValue(on ? "on" : "off")
        }
        .padding([.horizontal, .top], 8)
    }
}
