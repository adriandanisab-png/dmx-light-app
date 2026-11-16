import SwiftUI

/// Huge BLACKOUT button (key B). In Console mode it fires the console's blackout over MIDI instead.
struct BlackoutButton: View {
    @ObservedObject var model: AppModel

    private var isOn: Bool {
        model.outputMode == .consoleMIDI ? model.console.state.blackout : model.blackout
    }

    var body: some View {
        Button {
            if model.outputMode == .consoleMIDI {
                Task { await model.fire(.blackout) }
            } else {
                model.blackout.toggle()
            }
        } label: {
            Label("Blackout", systemImage: isOn ? "moon.fill" : "moon")
                .font(.title2.bold()).frame(minWidth: 170, minHeight: 36)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.extraLarge)
        .tint(isOn ? .red : Color.red.opacity(0.45))
        .keyboardShortcut("b", modifiers: [])
        .help("Blackout (B)")
        .accessibilityIdentifier("blackoutButton")
        .accessibilityValue(isOn ? "on" : "off")
    }
}
