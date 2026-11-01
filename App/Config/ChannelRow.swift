import SwiftUI
import ShowModel

/// One channel of a fixture type: name, function, default value and value ranges.
struct ChannelRow: View {
    @Binding var channel: ChannelDef
    var onDelete: () -> Void
    @State private var showRanges = false

    private var defaultText: Binding<String> {
        Binding(get: { String(channel.defaultValue) },
                set: { if let v = Int($0) { channel.defaultValue = UInt8(clamping: min(max(v, 0), 255)) } })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "line.3.horizontal").foregroundStyle(.secondary)
                TextField("Name", text: $channel.name).textFieldStyle(.roundedBorder)
                Picker("", selection: $channel.function) {
                    ForEach(ChannelFunction.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().frame(width: 110)
                TextField("0", text: defaultText)
                    .textFieldStyle(.roundedBorder).frame(width: 48)
                    .help("Default value 0\u{2013}255")
                Button { showRanges.toggle() } label: {
                    Image(systemName: showRanges ? "chevron.down" : "chevron.right")
                }
                .buttonStyle(.borderless).help("Value ranges (\(channel.ranges.count))")
                Button(role: .destructive, action: onDelete) { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless).help("Remove channel")
            }
            if showRanges {
                ForEach($channel.ranges.indices, id: \.self) { i in
                    HStack {
                        rangeField($channel.ranges[i].from)
                        Text("\u{2013}")
                        rangeField($channel.ranges[i].to)
                        TextField("Label", text: $channel.ranges[i].label).textFieldStyle(.roundedBorder)
                        Button { channel.ranges.remove(at: i) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                    }
                    .padding(.leading, 24)
                }
                Button("Add range") {
                    channel.ranges.append(ValueRange(from: 0, to: 255, label: "Range"))
                }
                .padding(.leading, 24)
            }
        }
    }

    private func rangeField(_ value: Binding<UInt8>) -> some View {
        TextField("0", text: Binding(get: { String(value.wrappedValue) },
                                     set: { if let v = Int($0) { value.wrappedValue = UInt8(clamping: min(max(v, 0), 255)) } }))
            .textFieldStyle(.roundedBorder).frame(width: 48)
    }
}
