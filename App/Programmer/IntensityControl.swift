import SwiftUI
import ShowModel

/// Intensity fader 0...100 %. Writes `Attributes.setIntensity` to every selected fixture.
struct IntensityControl: View {
    @ObservedObject var model: AppModel
    @State private var value = 0.0

    var body: some View {
        HStack {
            Text("Intensity").frame(width: 70, alignment: .leading)
            Slider(value: $value, in: 0...1) { editing in _ = editing }
                .onChange(of: value) { _, v in
                    model.programmerApply { type, values in Attributes.setIntensity(v, type: type, into: &values) }
                }
                .accessibilityIdentifier("programmerIntensity")
            Text("\(Int((value * 100).rounded())) %").monospacedDigit().frame(width: 52, alignment: .trailing)
        }
    }
}
