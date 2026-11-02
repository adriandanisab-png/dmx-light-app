import SwiftUI

/// TAP button (key T) plus an editable BPM readout.
struct TapTempoButton: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            Button { model.tapTempoTap() } label: {
                Text("TAP").font(.headline).frame(minWidth: 60, minHeight: 32)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("t", modifiers: [])
            .help("Tap tempo (T)")
            .accessibilityIdentifier("tapTempoButton")
            TextField("BPM", value: Binding(get: { model.bpm.rounded() }, set: { model.setBPM($0) }),
                      format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.roundedBorder).frame(width: 64).multilineTextAlignment(.trailing)
                .accessibilityIdentifier("bpmField")
            Text("BPM").foregroundStyle(.secondary)
        }
    }
}
