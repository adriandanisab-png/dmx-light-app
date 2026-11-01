import SwiftUI

struct GrandMasterFader: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack {
            Text("Grand master").font(.headline)
            Slider(value: $model.grandMaster, in: 0...1)
                .frame(width: 220)
                .accessibilityIdentifier("grandMaster")
                .accessibilityValue("\(Int((model.grandMaster * 100).rounded())) %")
            Text("\(Int((model.grandMaster * 100).rounded())) %").monospacedDigit().frame(width: 52, alignment: .trailing)
        }
    }
}
