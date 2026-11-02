import SwiftUI
import ShowModel

/// Root of one document window: tabs, shared ARM control, status line and error toast.
struct ShowRootView: View {
    @Binding var document: ShowDocument
    @StateObject private var model = AppModel()

    /// The tab-embedded views get the model explicitly; nothing uses `@EnvironmentObject`.
    var body: some View {
        TabView {
            ConfigView(document: $document, model: model)
                .tabItem { Text("Config") }
            StageTabView(document: $document, selection: selectionBinding, model: model)
                .tabItem { Text("Stage") }
            ProgrammerView(document: $document, selection: selectionBinding, model: model)
                .tabItem { Text("Programmer") }
            PlaybackView(document: $document, model: model)
                .tabItem { Text("Playback") }
            LibraryView(document: $document, model: model)
                .tabItem { Text("Library") }
            DevicesView(document: $document, model: model)
                .tabItem { Text("Devices") }
            ConsoleView(document: $document, model: model)
                .tabItem { Text("Console") }
        }
        .frame(minWidth: 1000, minHeight: 640)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { ArmButton(model: model) }
            ToolbarItem(placement: .status) { StatusLine(model: model) }
        }
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                Text(toast)
                    .font(.headline)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.red.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
                    .padding(.bottom, 24)
                    .accessibilityIdentifier("toast")
                    .transition(.opacity)
            }
        }
        .animation(.default, value: model.toast)
        .alert("DMX adapter lost: switch the DMX cable to the console", isPresented: $model.showAdapterLost) {
            Button("OK") { model.showAdapterLost = false }
        } message: {
            Text("Output reconnects by itself when the adapter is plugged back in.")
        }
        .onAppear {
            model.start()
            model.loadShow(document.show)
            model.loadConsoleMap(document.show.console)
        }
        .onChange(of: document.show.patch) { _, _ in model.loadShow(document.show) }
        .onChange(of: document.show.snapshots) { _, _ in model.loadShow(document.show) }
        .onChange(of: document.show.effects) { _, _ in model.loadShow(document.show) }
        .onChange(of: document.show.cueLists) { _, _ in model.loadShow(document.show) }
        .onChange(of: document.show.console) { _, _ in model.loadShow(document.show) }
    }

    private var selectionBinding: Binding<[UUID]> {
        Binding(get: { model.programmer.selection }, set: { model.setSelection($0) })
    }
}

/// Output status line: "Direct \u{00B7} /dev/cu.usbserial-A10K \u{00B7} 30 Hz" / "Adapter lost".
/// Takes the model explicitly (toolbar items don't inherit the environment).
struct StatusLine: View {
    @ObservedObject var model: AppModel

    var body: some View {
        // Polls once a second so "Adapter lost" appears and clears without other UI changes.
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Text(model.outputStatus).font(.caption)
                .foregroundStyle(model.outputStatus == "Adapter lost" ? Color.red : Color.secondary)
                .accessibilityIdentifier("outputStatus")
                .accessibilityValue("frameSum=\(model.frameSum)")
        }
    }
}

/// The window's single ARM control: red when armed. Nothing is sent while disarmed.
/// Takes the model explicitly: macOS toolbar items are hosted outside the window's
/// view tree and don't inherit `environmentObject`, so `@EnvironmentObject` crashes here.
struct ArmButton: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Button {
            model.setArmed(!model.isArmed)
        } label: {
            Text(model.isArmed ? "ARMED" : "ARM")
                .fontWeight(.bold)
                .padding(.horizontal, 8)
        }
        .tint(model.isArmed ? .red : nil)
        .buttonStyle(.borderedProminent)
        .help("Arm output: nothing is sent to lights or the console until armed")
        .accessibilityIdentifier("armButton")
        .accessibilityValue(model.isArmed ? "on" : "off")
    }
}
