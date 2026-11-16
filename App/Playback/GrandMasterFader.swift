import SwiftUI

/// Horizontal grand master with a percent readout.
struct GrandMasterFader: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: Space.sm) {
            Text("Grand Master").font(.headline).lineLimit(1).fixedSize()
            Slider(value: $model.grandMaster, in: 0...1)
                .frame(minWidth: 80)
                .accessibilityIdentifier("grandMaster")
                .accessibilityValue("\(Int((model.grandMaster * 100).rounded())) %")
            Text("\(Int((model.grandMaster * 100).rounded())) %")
                .font(.title3.monospacedDigit().weight(.semibold))
                .frame(width: 56, alignment: .trailing)
        }
    }
}
