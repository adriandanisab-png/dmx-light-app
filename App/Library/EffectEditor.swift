import SwiftUI
import ShowModel

/// Effect editor sheet. The draft runs live on the stage while the sheet is open.
struct EffectEditor: View {
    let target: EffectEditTarget
    @Binding var document: ShowDocument
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Effect

    init(target: EffectEditTarget, document: Binding<ShowDocument>, model: AppModel) {
        self.target = target
        _document = document
        self.model = model
        _draft = State(initialValue: target.effect)
    }

    static func title(_ kind: EffectKind) -> String {
        switch kind {
        case .intensityChase: return "Chase"
        case .intensityWave: return "Wave"
        case .sparkle: return "Sparkle"
        case .rainbow: return "Rainbow"
        case .colorChase: return "Colour chase"
        case .strobe: return "Strobe"
        case .panTiltCircle: return "Circle"
        case .figure8: return "Figure 8"
        }
    }

    private var patch: Patch { document.show.patch }
    private var canSave: Bool {
        !draft.fixtureIDs.isEmpty && (draft.kind != .colorChase || draft.colors.count >= 2)
    }
    private func fixtureName(_ id: UUID) -> String { patch.fixtures.first { $0.id == id }?.name ?? "?" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(target.isNew ? "New effect" : "Edit effect").font(.title2)
                HStack {
                    TextField("Name (optional)", text: $draft.name).textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("effectNameField")
                    ColorPicker("", selection: Binding(get: { Color(hex: draft.colorHex) }, set: { draft.colorHex = $0.hexString }),
                                supportsOpacity: false).labelsHidden()
                }
                Text("Kind").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
                    ForEach(EffectKind.allCases, id: \.self) { kind in
                        Button {
                            draft.kind = kind
                            if kind == .colorChase, draft.colors.count < 2 {
                                draft.colors = [RGB(r: 1, g: 0, b: 0), RGB(r: 0, g: 0, b: 1)]
                            }
                        } label: {
                            Text(Self.title(kind)).frame(maxWidth: .infinity, minHeight: 28)
                                .background(RoundedRectangle(cornerRadius: 6)
                                    .fill(draft.kind == kind ? Color.accentColor : Color.gray.opacity(0.25)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Self.title(kind))
                        .accessibilityIdentifier("effectKind.\(kind.rawValue)")
                        .accessibilityValue(draft.kind == kind ? "on" : "off")
                    }
                }
                Toggle("Overlay (stacks with other effects; chases are exclusive)", isOn: $draft.overlay)
                    .accessibilityIdentifier("effectOverlay")
                fixtures
                Picker("Rate", selection: $draft.rateMultiplier) {
                    ForEach(Effect.rateMultipliers, id: \.self) { m in Text(Self.rateText(m)).tag(m) }
                }
                .pickerStyle(.segmented).accessibilityIdentifier("effectRate")
                slider("Size", $draft.size, "effectSize")
                slider("Spread", $draft.spread, "effectSpread")
                Picker("Direction", selection: $draft.direction) {
                    Text("Forward").tag(EffectDirection.forward)
                    Text("Backward").tag(EffectDirection.backward)
                    Text("Bounce").tag(EffectDirection.bounce)
                }
                .pickerStyle(.segmented).accessibilityIdentifier("effectDirection")
                if draft.kind == .colorChase { colors }
                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("effectCancel")
                    Button("Save") { save() }
                        .keyboardShortcut(.defaultAction).disabled(!canSave)
                        .accessibilityIdentifier("effectSave")
                }
            }
            .padding(20)
        }
        .frame(width: 520, height: 600)
        .onAppear { model.setPreview(canSave ? draft : nil) }
        .onChange(of: draft) { _, d in model.setPreview(canSave ? d : nil) }
        .onDisappear { model.setPreview(nil) }
    }

    static func rateText(_ m: Double) -> String {
        switch m { case 0.25: return "\u{00BC}\u{00D7}"; case 0.5: return "\u{00BD}\u{00D7}"; default: return "\(Int(m))\u{00D7}" }
    }

    private func slider(_ title: String, _ value: Binding<Double>, _ id: String) -> some View {
        HStack {
            Text(title).frame(width: 60, alignment: .leading)
            Slider(value: value, in: 0...1).accessibilityIdentifier(id)
            Text("\(Int((value.wrappedValue * 100).rounded())) %").monospacedDigit().frame(width: 48, alignment: .trailing)
        }
    }

    private var fixtures: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Fixtures (\(draft.fixtureIDs.count), in chase order)").font(.headline)
                    .accessibilityIdentifier("effectFixtureCount")
                    .accessibilityValue("\(draft.fixtureIDs.count)")
                Spacer()
                Button("Use selection") { draft.fixtureIDs = model.programmer.selection }
                    .disabled(model.programmer.selection.isEmpty)
                    .accessibilityIdentifier("useSelectionButton")
                Button("All") { draft.fixtureIDs = patch.fixtures.map(\.id) }
                    .accessibilityIdentifier("useAllButton")
            }
            Text(draft.fixtureIDs.isEmpty ? "None yet: select fixtures in the Programmer tab, then press Use selection."
                                          : draft.fixtureIDs.map(fixtureName).joined(separator: ", "))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var colors: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Colours (at least 2)").font(.headline)
                Spacer()
                Button { draft.colors.append(RGB(r: 1, g: 1, b: 1)) } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add colour").accessibilityIdentifier("effectAddColor")
            }
            ForEach(draft.colors.indices, id: \.self) { i in
                HStack {
                    ColorPicker("Colour \(i + 1)", selection: Binding(
                        get: { Color(.sRGB, red: draft.colors[i].r, green: draft.colors[i].g, blue: draft.colors[i].b, opacity: 1) },
                        set: { c in
                            let h = c.hexString
                            let v = UInt32(h.dropFirst(), radix: 16) ?? 0xFFFFFF
                            draft.colors[i] = RGB(r: Double((v >> 16) & 0xFF) / 255, g: Double((v >> 8) & 0xFF) / 255,
                                                  b: Double(v & 0xFF) / 255)
                        }), supportsOpacity: false)
                    Button { draft.colors.remove(at: i) } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless).disabled(draft.colors.count <= 2)
                        .accessibilityLabel("Remove colour \(i + 1)")
                }
            }
        }
    }

    private func save() {
        var e = draft
        if e.name.trimmingCharacters(in: .whitespaces).isEmpty { e.name = Self.title(e.kind) }
        if let i = document.show.effects.firstIndex(where: { $0.id == e.id }) {
            document.show.effects[i] = e
        } else {
            document.show.effects.append(e)
        }
        dismiss()
    }
}
