import SwiftUI
import ShowModel

/// Edits one fixture type: name and an ordered, draggable channel list.
struct FixtureTypeEditor: View {
    @Binding var type: FixtureType

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Type name", text: $type.name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("typeNameField")
                Button("Add channel") {
                    type.channels.append(ChannelDef(name: "Channel \(type.channels.count + 1)", function: .generic))
                }
            }
            .padding(.horizontal, 8).padding(.top, 8)
            Text("Channels (drag to reorder). Adding channels re-checks every patched fixture.")
                .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
            List {
                ForEach($type.channels) { $channel in
                    ChannelRow(channel: $channel) {
                        type.channels.removeAll { $0.id == channel.id }
                    }
                }
                .onMove { type.channels.move(fromOffsets: $0, toOffset: $1) }
            }
        }
    }
}
