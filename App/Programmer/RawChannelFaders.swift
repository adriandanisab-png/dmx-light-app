import SwiftUI
import ShowModel

/// One fader per channel of the first selected fixture's type. Each fader moves the matching channel
/// (same name, else same function) on every selected fixture, so mixed types move together.
struct RawChannelFaders: View {
    let patch: Patch
    let selection: [UUID]
    @ObservedObject var model: AppModel

    var body: some View {
        if let first = selection.compactMap({ id in patch.fixtures.first { $0.id == id } }).first,
           let type = patch.type(of: first) {
            ScrollView(.horizontal) {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(type.channels.enumerated()), id: \.element.id) { index, channel in
                        VStack {
                            Text("\(model.shownValue(fixture: first, channel: index))").font(.caption.monospacedDigit())
                            VerticalFader(value: Binding(
                                get: { Double(model.shownValue(fixture: first, channel: index)) },
                                set: { model.programmerSetMatching(channel, to: UInt8(min(max($0.rounded(), 0), 255))) }))
                                .frame(width: 30, height: 100)
                                .accessibilityLabel(channel.name)
                            Text(channel.name).font(.caption2).lineLimit(1)
                        }
                        .frame(width: 54)
                    }
                }
                .padding(.vertical, Space.xs)
            }
        } else {
            Label("Select fixtures to see their channels.", systemImage: "hand.point.up.left").foregroundStyle(.secondary)
        }
    }
}
