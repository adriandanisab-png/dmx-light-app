import SwiftUI
import ShowModel

/// One vertical fader per channel of the selected fixture. Writes the shared DMX frame.
struct TouchFaderPanel: View {
    let patch: Patch
    let fixtureID: UUID?
    @ObservedObject var model: AppModel

    var body: some View {
        if let fixture = patch.fixtures.first(where: { $0.id == fixtureID }), let type = patch.type(of: fixture) {
            ScrollView(.horizontal) {
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(Array(type.channels.enumerated()), id: \.element.id) { index, channel in
                        VStack {
                            Text("\(model.shownValue(fixture: fixture, channel: index))").font(.caption.monospacedDigit())
                            VerticalFader(value: Binding(
                                get: { Double(model.shownValue(fixture: fixture, channel: index)) },
                                set: { model.programmerSet(channel: index, to: UInt8(min(max($0.rounded(), 0), 255)), fixtures: [fixture.id]) }))
                            .frame(width: 36, height: 140)
                            .accessibilityLabel(channel.name)
                            Text(channel.name).font(.caption).lineLimit(1)
                            Text(channel.function.rawValue).font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(width: 64)
                    }
                }
                .padding(12)
            }
        } else {
            Text("Select a fixture in the patch to test its channels.")
                .foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// A touch-friendly vertical fader, 0...255.
struct VerticalFader: View {
    @Binding var value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.3))
                RoundedRectangle(cornerRadius: 6).fill(Color.accentColor)
                    .frame(height: geo.size.height * value / 255)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let fraction = 1 - g.location.y / geo.size.height
                value = min(max(fraction, 0), 1) * 255
            })
        }
        .accessibilityElement()
        .accessibilityValue("\(Int(value))")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 5, 255)
            case .decrement: value = max(value - 5, 0)
            @unknown default: break
            }
        }
    }
}
