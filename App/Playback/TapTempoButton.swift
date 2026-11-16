import SwiftUI

/// TAP button (key T) plus a BPM readout. Click the readout to type a tempo.
/// (A permanent text field would grab the window's initial focus and swallow the B / T / Space shortcuts.)
struct TapTempoButton: View {
    @ObservedObject var model: AppModel
    @State private var editing = false
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button { model.tapTempoTap() } label: {
                Label("TAP", systemImage: "metronome").font(.headline).frame(minWidth: 70, minHeight: 24)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("t", modifiers: [])
            .help("Tap tempo (T)")
            .accessibilityIdentifier("tapTempoButton")
            if editing {
                TextField("BPM", text: $text)
                    .textFieldStyle(.roundedBorder).frame(width: 64).multilineTextAlignment(.trailing)
                    .focused($focused)
                    .onSubmit { commit() }
                    .onChange(of: focused) { _, f in if !f { commit() } }
                    .accessibilityIdentifier("bpmEditor")
            } else {
                Button {
                    text = String(Int(model.bpm.rounded()))
                    editing = true
                    focused = true
                } label: {
                    Text(String(Int(model.bpm.rounded()))).monospacedDigit().frame(width: 48)
                }
                .help("Click to type a tempo")
                .accessibilityIdentifier("bpmField")
                .accessibilityValue(String(Int(model.bpm.rounded())))
            }
            Text("BPM").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func commit() {
        guard editing else { return }
        editing = false
        if let v = Double(text.trimmingCharacters(in: .whitespaces)) { model.setBPM(v) }
    }
}
