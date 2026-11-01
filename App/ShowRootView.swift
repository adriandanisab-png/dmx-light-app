import SwiftUI
import ShowModel

/// Root of one document window: Config and Console tabs, shared ARM toggle and error toast.
struct ShowRootView: View {
    @Binding var document: ShowDocument
    @StateObject private var model = AppModel()

    var body: some View {
        TabView {
            ConfigView(document: $document)
                .tabItem { Text("Config") }
            ConsoleView(document: $document)
                .tabItem { Text("Console") }
        }
        .environmentObject(model)
        .frame(minWidth: 1000, minHeight: 640)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { ArmButton() }
            ToolbarItem(placement: .status) {
                Text(model.outputStatus).font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("outputStatus")
            }
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
        .onAppear {
            model.loadPatch(document.show.patch)
            model.loadConsoleMap(document.show.console)
        }
    }
}

/// The window's single ARM control: red when armed. Nothing is sent while disarmed.
struct ArmButton: View {
    @EnvironmentObject var model: AppModel

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
