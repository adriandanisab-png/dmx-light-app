import SwiftUI

/// Sends any note/velocity/channel. Needs the window to be armed, like everything else.
struct MIDITestPanel: View {
    let defaultChannel: Int
    @ObservedObject var model: AppModel
    @State private var note = 0
    @State private var velocity = 127
    @State private var channel: Int?

    var body: some View {
        Section {
            Stepper("Note: \(note)", value: $note, in: 0...127)
            Stepper("Velocity: \(velocity)", value: $velocity, in: 1...127)
            Stepper("Channel: \(channel ?? defaultChannel)",
                    value: Binding(get: { channel ?? defaultChannel }, set: { channel = $0 }), in: 1...16)
            HStack {
                Button("Send") {
                    let ch = channel ?? defaultChannel
                    Task { await model.sendRaw(note: note, velocity: velocity, channel: ch) }
                }
                .accessibilityIdentifier("testSend")
                Button("Clear log") { model.clearLog() }
            }
            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(Array(model.midiLog.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption.monospaced())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 110)
            .padding(Space.xs)
            .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        } header: {
            SectionHeader("MIDI test panel", systemImage: "waveform.path")
        }
    }
}
