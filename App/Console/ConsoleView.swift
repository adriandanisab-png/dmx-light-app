import SwiftUI
import ShowModel
import ConsoleMIDI

enum ConsoleMode: String, CaseIterable, Identifiable {
    case play = "Play", edit = "Edit", select = "Select"
    var id: String { rawValue }
}

/// The Console page: grid, looks, MIDI settings and test panel.
struct ConsoleView: View {
    @Binding var document: ShowDocument
    @ObservedObject var model: AppModel
    @State private var mode: ConsoleMode = .play
    @State private var selection: Set<ConsoleTarget> = []
    @State private var editingTarget: ConsoleTarget?
    @State private var showReset = false

    private var map: Binding<ConsoleMap> { $document.show.console }

    var body: some View {
        HSplitView {
            VStack(spacing: Space.xs) {
                ConsolePlaybackView(mode: $mode, showReset: $showReset, model: model)
                if !model.isArmed {
                    NoticeBanner(text: "Output is not armed: nothing is sent to the console. Press ARM in the toolbar.")
                        .padding(.horizontal, Space.sm)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("armHint")
                }
                ScrollView {
                    Card(padding: Space.sm) {
                        ConsoleGrid(map: map.wrappedValue, mode: mode, selection: $selection, editingTarget: $editingTarget, model: model)
                    }
                    .padding(Space.sm)
                }
                Text("Banks 16\u{2013}30 can't be reached over MIDI")
                    .font(.footnote).foregroundStyle(.secondary).padding(.bottom, Space.xs)
            }
            .frame(minWidth: 500)
            Form {
                ConsoleLooksView(map: map, selection: $selection, mode: mode, model: model)
                MIDISettingsView(map: map, model: model)
                MIDITestPanel(defaultChannel: map.wrappedValue.midiChannel, model: model)
            }
            .formStyle(.grouped)
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 440)
        }
        .sheet(item: $editingTarget) { target in
            ConsoleCellEditor(target: target, map: map)
        }
        .sheet(isPresented: $showReset) { ResetConsoleSheet(model: model) }
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
    @ObservedObject var model: AppModel
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
