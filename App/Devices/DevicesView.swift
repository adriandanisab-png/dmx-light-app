import SwiftUI
import ShowModel
import DMXOutput

/// The "Devices" tab: output mode, serial port (Direct) and MIDI settings (Console).
struct DevicesView: View {
    @Binding var document: ShowDocument
    @ObservedObject var model: AppModel
    @State private var ports: [SerialPortInfo] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                OutputModePicker(model: model)
                if model.isArmed {
                    Text("Disarm to change the output settings.").font(.callout).foregroundStyle(.orange)
                }
                switch model.outputMode {
                case .previewOnly:
                    Text("Preview only: the stage shows the lights, nothing is sent anywhere.")
                        .foregroundStyle(.secondary)
                case .directOpenDMX:
                    direct
                case .consoleMIDI:
                    MIDISettingsView(map: $document.show.console, model: model)
                        .onAppear { model.loadConsoleMap(document.show.console) }
                }
                Divider()
                Text("Status: \(model.outputStatus)").font(.callout).foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .onAppear { ports = SerialPortDiscovery.ports() }
    }

    private var direct: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("DMX adapter").font(.headline)
                Button { ports = SerialPortDiscovery.ports() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Refresh port list")
            }
            if ports.isEmpty {
                Text("No serial ports found. Plug in the SH-RS09B.").foregroundStyle(.secondary)
            }
            Picker("Port", selection: Binding(get: { model.portPath }, set: { model.setPort($0) })) {
                Text("None").tag(String?.none)
                ForEach(ports, id: \.path) { p in
                    Text(label(p)).tag(Optional(p.path))
                }
            }
            .disabled(model.isArmed)
            .accessibilityIdentifier("portPicker")
            Stepper("Refresh rate: \(Int(model.refreshHz)) Hz",
                    value: Binding(get: { model.refreshHz }, set: { model.setRefreshHz($0) }),
                    in: OpenDMXOutput.refreshRange, step: 5)
                .disabled(model.isArmed)
            Text("30 Hz is the default. If lights flicker, try 25 or 40 Hz.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func label(_ p: SerialPortInfo) -> String {
        let ftdi = p.vendorID == SerialPortDiscovery.ftdiVendorID ? " (FTDI)" : ""
        return "\(p.path)\(ftdi)" + (p.productName.map { " \u{2014} \($0)" } ?? "")
    }
}
