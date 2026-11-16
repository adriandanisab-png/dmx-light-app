import SwiftUI
import ShowModel

/// Strobe fader: writes 0...255 to the strobe channel of every selected fixture that has one.
struct StrobeControl: View {
    @ObservedObject var model: AppModel
    @State private var value = 0.0

    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "tortoise").foregroundStyle(.secondary)
            Slider(value: $value, in: 0...255)
                .onChange(of: value) { _, v in
                    let byte = UInt8(min(max(v.rounded(), 0), 255))
                    model.programmerApply { type, values in
                        for (i, ch) in type.channels.enumerated() where ch.function == .strobe { values[i] = byte }
                    }
                }
                .accessibilityIdentifier("programmerStrobe")
            Image(systemName: "hare").foregroundStyle(.secondary)
            Text("\(Int(value))").monospacedDigit().frame(width: 52, alignment: .trailing)
        }
    }
}
