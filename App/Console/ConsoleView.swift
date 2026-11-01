import SwiftUI
import ShowModel
import ConsoleMIDI

enum ConsoleMode: String, CaseIterable, Identifiable {
    case play = "Play", edit = "Edit", select = "Select"
    var id: String { rawValue }
}

/// The "Console" tab: grid, looks, MIDI settings and test panel.
struct ConsoleView: View {
    @Binding var document: ShowDocument
    @EnvironmentObject var model: AppModel
    @State private var mode: ConsoleMode = .play
    @State private var selection: Set<ConsoleTarget> = []
    @State private var editingTarget: ConsoleTarget?
    @State private var showReset = false

    private var map: Binding<ConsoleMap> { $document.show.console }

    var body: some View {
        HSplitView {
            VStack(spacing: 8) {
                ConsolePlaybackView(mode: $mode, showReset: $showReset)
                if !model.isArmed {
                    Text("Output is not armed: nothing is sent to the console. Press ARM in the toolbar.")
                        .font(.callout).foregroundStyle(.orange)
                        .accessibilityIdentifier("armHint")
                }
                ScrollView {
                    ConsoleGrid(map: map.wrappedValue, mode: mode, selection: $selection, editingTarget: $editingTarget)
                        .padding(8)
                }
                Text("Banks 16\u{2013}30 can't be reached over MIDI")
                    .font(.footnote).foregroundStyle(.secondary).padding(.bottom, 6)
            }
            .frame(minWidth: 620)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ConsoleLooksView(map: map, selection: $selection, mode: mode)
                    Divider()
                    MIDISettingsView(map: map)
                    Divider()
                    MIDITestPanel(defaultChannel: map.wrappedValue.midiChannel)
                }
                .padding(12)
            }
            .frame(minWidth: 320, idealWidth: 360, maxWidth: 460)
        }
        .sheet(item: $editingTarget) { target in
            ConsoleCellEditor(target: target, map: map)
        }
        .sheet(isPresented: $showReset) { ResetConsoleSheet() }
        .onAppear { model.loadConsoleMap(document.show.console) }
        .onChange(of: document.show.console) { _, new in model.loadConsoleMap(new) }
    }
}

extension ConsoleTarget: @retroactive Identifiable {
    public var id: String { ConsoleTarget.label(self) }

    static func label(_ t: ConsoleTarget) -> String {
        switch t {
        case let .scene(b, s): return "b\(b)s\(s)"
        case let .chase(c): return "c\(c)"
        case .blackout: return "blackout"
        }
    }

    var identifier: String { "consoleCell.\(ConsoleTarget.label(self))" }

    var shortTitle: String {
        switch self {
        case let .scene(b, s): return "B\(b)\u{00B7}S\(s)"
        case let .chase(c): return "Chase \(c)"
        case .blackout: return "Blackout"
        }
    }
}

struct ResetConsoleSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reset console").font(.title2)
            Text("Release all scenes on the console, press its blackout off, then press Done.")
            Text("Done marks every cell and blackout as off in this app. Nothing is sent.")
                .font(.footnote).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Done") { model.console.markAllOff(); dismiss() }
                    .keyboardShortcut(.defaultAction).accessibilityIdentifier("resetDone")
            }
        }
        .padding(20).frame(width: 420)
    }
}
