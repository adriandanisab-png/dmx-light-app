import SwiftUI
import ShowModel

/// Top bar of the Console tab: mode picker, reset, and the always-visible BLACKOUT button (key B).
struct ConsolePlaybackView: View {
    @Binding var mode: ConsoleMode
    @Binding var showReset: Bool
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Picker("Mode", selection: $mode) {
                ForEach(ConsoleMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).frame(width: 220)
            .accessibilityIdentifier("consoleMode")
            Button { showReset = true } label: { Label("Reset console\u{2026}", systemImage: "arrow.counterclockwise") }
            Spacer()
            let on = model.console.state.blackout
            Button {
                Task { await model.fire(.blackout) }
            } label: {
                Label("Blackout", systemImage: on ? "moon.fill" : "moon")
                    .font(.title2.bold())
                    .frame(minWidth: 170, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
            .tint(on ? .red : Color.red.opacity(0.45))
            .keyboardShortcut("b", modifiers: [])
            .help("Blackout (B)")
            .accessibilityIdentifier("blackoutButton")
            .accessibilityValue(on ? "on" : "off")
        }
        .padding([.horizontal, .top], Space.sm)
    }
}
