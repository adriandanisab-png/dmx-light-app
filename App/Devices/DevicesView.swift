import SwiftUI
import ShowModel
import DMXOutput

/// The Devices page: output mode, serial port (Direct) and MIDI settings (Console).
struct DevicesView: View {
    @Binding var document: ShowDocument
    @ObservedObject var model: AppModel
    @State private var ports: [SerialPortInfo] = []

    var body: some View {
        Form {
            Section {
                OutputModePicker(model: model)
                if model.isArmed {
                    Label("Disarm to change the output settings.", systemImage: "lock.fill")
                        .font(.callout).foregroundStyle(.orange)
                }
            } header: {
                SectionHeader("Output", systemImage: "arrow.up.forward.app")
            }
            switch model.outputMode {
            case .previewOnly:
                Section {
                    ContentUnavailableView {
                        Label("Preview only", systemImage: "eye")
                    } description: {
                        Text("The stage shows the lights. Nothing is sent anywhere.")
                    }
                    .frame(maxWidth: .infinity, minHeight: 130)
                }
            case .directOpenDMX:
                direct
            case .consoleMIDI:
                MIDISettingsView(map: $document.show.console, model: model)
                    .onAppear { model.loadConsoleMap(document.show.console) }
            }
            Section {
                LabeledContent("Status") {
                    HStack(spacing: 6) {
                        Circle().fill(model.outputStatus == "Adapter lost" ? Color.red : (model.isArmed ? Color.green : Color.gray))
                            .frame(width: 8, height: 8)
                        Text(model.outputStatus)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { ports = SerialPortDiscovery.ports() }
    }

    @ViewBuilder private var direct: some View {
        Section {
            if ports.isEmpty {
                ContentUnavailableView {
                    Label("No serial ports found", systemImage: "cable.connector.slash")
                } description: {
                    Text("Plug in the SH-RS09B and refresh the list.")
                } actions: {
                    Button("Refresh") { ports = SerialPortDiscovery.ports() }
                }
                .frame(maxWidth: .infinity, minHeight: 130)
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
        } header: {
            SectionHeader("DMX adapter", systemImage: "cable.connector") {
                Button { ports = SerialPortDiscovery.ports() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .help("Refresh port list")
            }
        }
    }

    private func label(_ p: SerialPortInfo) -> String {
        let ftdi = p.vendorID == SerialPortDiscovery.ftdiVendorID ? " (FTDI)" : ""
        return "\(p.path)\(ftdi)" + (p.productName.map { " \u{2014} \($0)" } ?? "")
    }
}
