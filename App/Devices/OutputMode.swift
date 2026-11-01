// OutputMode is defined next to AppModel (it is stored per Mac in UserDefaults, not in the show).
// This file holds its picker.
import SwiftUI

struct OutputModePicker: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Picker("Output", selection: Binding(get: { model.outputMode }, set: { model.setOutputMode($0) })) {
            ForEach(OutputMode.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .disabled(model.isArmed)
        .accessibilityIdentifier("outputMode")
    }
}
