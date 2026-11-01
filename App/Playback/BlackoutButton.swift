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
            Text("BLACKOUT").font(.title.bold()).frame(minWidth: 220, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .tint(isOn ? .red : .gray)
        .keyboardShortcut("b", modifiers: [])
        .help("Blackout (B)")
        .accessibilityIdentifier("blackoutButton")
        .accessibilityValue(isOn ? "on" : "off")
    }
}
