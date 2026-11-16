import SwiftUI
import ShowModel

struct MIDISettingsView: View {
    @Binding var map: ConsoleMap
    @ObservedObject var model: AppModel

    private var noteOffEnabled: Binding<Bool> {
        Binding(get: { map.noteOffDelayMs != nil },
                set: { map.noteOffDelayMs = $0 ? (map.noteOffDelayMs ?? 50) : nil })
    }

    private var delayText: Binding<String> {
        Binding(get: { map.noteOffDelayMs.map(String.init) ?? "" },
                set: { if let v = Int($0), v >= 0 { map.noteOffDelayMs = min(v, 5000) } })
    }

    var body: some View {
        Section {
            if model.destinations.isEmpty {
                LabeledContent("Interface") {
                    HStack {
                        Text("No MIDI interface found").foregroundStyle(.secondary)
                        refreshButton
                    }
                }
            } else {
                HStack {
                    Picker("Interface", selection: Binding(
                        get: { model.selectedDestinationID },
                        set: { model.selectDestination($0) })) {
                        Text("None").tag(Int32?.none)
                        ForEach(model.destinations, id: \.uniqueID) { Text($0.name).tag(Optional($0.uniqueID)) }
                    }
                    refreshButton
                }
            }
            Stepper("MIDI channel: \(map.midiChannel)", value: $map.midiChannel, in: 1...16)
            Text("Must match the console: hold MIDI/Rec 3 s, Bank Up/Down, hold MIDI/Rec 3 s")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Send Note Off after each Note On", isOn: noteOffEnabled)
            if map.noteOffDelayMs != nil {
                LabeledContent("Delay (ms)") {
                    TextField("50", text: delayText).textFieldStyle(.roundedBorder).frame(width: 70)
                }
            }
        } header: {
            SectionHeader("MIDI settings", systemImage: "pianokeys")
        }
    }

    private var refreshButton: some View {
        Button { model.refreshDestinations() } label: { Image(systemName: "arrow.clockwise") }
            .buttonStyle(.borderless)
            .help("Refresh interface list")
    }
}
