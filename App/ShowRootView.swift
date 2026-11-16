import SwiftUI
import ShowModel

/// The pages of the sidebar. `legacyName` is the old tab name, kept for accessibility identifiers.
enum AppPage: String, CaseIterable, Identifiable {
    case playback, programmer, stage, library, config, devices, console
    var id: String { rawValue }

    var title: String {
        switch self {
        case .playback: return "Playback"
        case .programmer: return "Programmer"
        case .stage: return "Stage"
        case .library: return "Library"
        case .config: return "Fixtures"
        case .devices: return "Devices"
        case .console: return "Console"
        }
    }

    var legacyName: String {
        switch self {
        case .config: return "Config"
        default: return title
        }
    }

    var systemImage: String {
        switch self {
        case .playback: return "play.circle"
        case .programmer: return "slider.horizontal.3"
        case .stage: return "theatermasks"
        case .library: return "books.vertical"
        case .config: return "lightbulb.2"
        case .devices: return "cable.connector"
        case .console: return "pianokeys"
        }
    }

    static let groups: [(title: String, pages: [AppPage])] = [
        ("Show", [.playback]),
        ("Build", [.programmer, .stage, .library]),
        ("Setup", [.config, .devices, .console]),
    ]
}

/// Root of one document window: sidebar, page, unified toolbar (status + ARM) and error toast.
struct ShowRootView: View {
    @Binding var document: ShowDocument
    @StateObject private var model = AppModel()
    @SceneStorage("selectedPage") private var pageRaw = AppPage.playback.rawValue

    private var page: AppPage { AppPage(rawValue: pageRaw) ?? .playback }

    /// Pages get the model explicitly; nothing uses `@EnvironmentObject`.
    var body: some View {
        NavigationSplitView {
            List(selection: Binding<AppPage?>(get: { page }, set: { if let p = $0 { pageRaw = p.rawValue } })) {
                ForEach(AppPage.groups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.pages) { p in
                            Label(p.title, systemImage: p.systemImage)
                                .tag(p)
                                .accessibilityIdentifier("sidebar.\(p.legacyName)")
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            detail
                .navigationTitle(page.title)
        }
        .frame(minWidth: 1100, minHeight: 640)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .status) { StatusLine(model: model) }
            ToolbarItem(placement: .primaryAction) { ArmButton(model: model) }
        }
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                ToastView(text: toast)
                    .padding(.bottom, Space.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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

    @ViewBuilder private var detail: some View {
        switch page {
        case .playback: PlaybackView(document: $document, model: model)
        case .programmer: ProgrammerView(document: $document, selection: selectionBinding, model: model)
        case .stage: StageTabView(document: $document, selection: selectionBinding, model: model)
        case .library: LibraryView(document: $document, model: model)
        case .config: ConfigView(document: $document, model: model)
        case .devices: DevicesView(document: $document, model: model)
        case .console: ConsoleView(document: $document, model: model)
        }
    }

    private var selectionBinding: Binding<[UUID]> {
        Binding(get: { model.programmer.selection }, set: { model.setSelection($0) })
    }
}

/// Bottom-centre capsule with an SF Symbol. Keeps the `toast` identifier on its text.
struct ToastView: View {
    let text: String

    var body: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
            Text(text).font(.callout.weight(.medium))
                .accessibilityIdentifier("toast")
        }
        .padding(.horizontal, Space.md).padding(.vertical, Space.sm)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
    }
}

/// Output status pill: coloured dot plus "Live \u{00B7} Direct \u{00B7} 30 Hz", "Preview only" or "Adapter lost".
/// Takes the model explicitly (toolbar items don't inherit the environment).
struct StatusLine: View {
    @ObservedObject var model: AppModel

    private var parts: (text: String, color: Color) {
        let status = model.outputStatus
        if status == "Adapter lost" { return (status, .red) }
        switch model.outputMode {
        case .previewOnly: return ("Preview only", .gray)
        case .directOpenDMX:
            if model.portPath == nil { return ("Direct \u{00B7} no adapter", .yellow) }
            if model.isArmed { return ("Live \u{00B7} Direct \u{00B7} \(Int(model.refreshHz)) Hz", .green) }
            return ("Direct \u{00B7} disarmed", .yellow)
        case .consoleMIDI:
            if model.isArmed { return ("Live \u{00B7} Console \u{00B7} MIDI", .green) }
            return ("Console \u{00B7} disarmed", .yellow)
        }
    }

    var body: some View {
        // Polls once a second so "Adapter lost" appears and clears without other UI changes.
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let p = parts
            HStack(spacing: 6) {
                Circle().fill(p.color).frame(width: 8, height: 8)
                    .shadow(color: p.color.opacity(0.8), radius: 3)
                    .accessibilityHidden(true)
                Text(p.text).font(.caption.weight(.medium)).lineLimit(1)
                    .accessibilityIdentifier("outputStatus")
                    .accessibilityValue("frameSum=\(model.frameSum)")
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(p.color.opacity(0.14)))
            .foregroundStyle(p.color == .red ? Color.red : Color.primary)
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
            Label(model.isArmed ? "ARMED" : "ARM", systemImage: model.isArmed ? "bolt.fill" : "bolt.slash")
                .fontWeight(.bold)
                .padding(.horizontal, 6)
        }
        .tint(model.isArmed ? .red : nil)
        .buttonStyle(.borderedProminent)
        .help("Arm output: nothing is sent to lights or the console until armed")
        .accessibilityIdentifier("armButton")
        .accessibilityValue(model.isArmed ? "on" : "off")
    }
}
