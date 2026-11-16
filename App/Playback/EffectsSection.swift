import SwiftUI
import ShowModel

/// Effect buttons for the Playback page: preset chases and overlays, saved effects, and the running list.
struct EffectsSection: View {
    @Binding var document: ShowDocument
    @ObservedObject var model: AppModel

    private var patch: Patch { document.show.patch }
    /// Fixtures picked here (in pick order); every patched fixture when none are picked.
    private var targetIDs: [UUID] {
        let known = Set(patch.fixtures.map(\.id))
        let picked = model.effectTargets.filter { known.contains($0) }
        return picked.isEmpty ? patch.fixtures.map(\.id) : picked
    }
    private var targetText: String {
        model.effectTargets.isEmpty ? "all \(patch.fixtures.count) fixtures" : "\(targetIDs.count) picked"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Card {
                VStack(alignment: .leading, spacing: Space.sm) {
                    SectionHeader("Effects", systemImage: "wand.and.stars") {
                        Text("on \(targetText)").font(.caption).foregroundStyle(.secondary)
                            .accessibilityIdentifier("effectsTarget")
                    }
                    EffectFixturePicker(patch: patch, model: model)
                }
            }
            group("Chases", "arrow.triangle.2.circlepath", .chase)
            group("Overlays", "square.2.layers.3d", .overlay)
            if !document.show.effects.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        SectionHeader("Saved", systemImage: "tray.full")
                        EffectGrid(items: document.show.effects) { e in
                            EffectButton(title: e.name, subtitle: "\(e.fixtureIDs.count) fx", colorHex: e.colorHex,
                                         isOn: model.isRunning(e.id), identifier: "effectButton.\(e.name)") {
                                model.toggleEffect(e)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("effectsSection")
    }

    private func group(_ title: String, _ icon: String, _ category: EffectPresetCategory) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Space.sm) {
                SectionHeader(title, systemImage: icon)
                EffectGrid(items: EffectPresets.all.filter { $0.category == category }) { preset in
                    EffectButton(title: preset.name, subtitle: nil, colorHex: preset.colorHex,
                                 isOn: existing(preset).map { model.isRunning($0.id) } ?? false,
                                 identifier: "effectPreset.\(preset.name)") { fire(preset) }
                }
            }
        }
    }

    private func existing(_ preset: EffectPreset) -> Effect? {
        document.show.effects.first { $0.name == preset.name && $0.fixtureIDs == targetIDs }
    }

    /// Creates the preset's effect for the target fixtures if needed, then toggles it.
    private func fire(_ preset: EffectPreset) {
        if let e = existing(preset) { model.toggleEffect(e); return }
        let ids = targetIDs
        guard !ids.isEmpty else { model.showToast("Patch some fixtures first"); return }
        let e = preset.makeEffect(fixtureIDs: ids)
        document.show.effects.append(e)
        model.startEffect(e)
    }
}

/// Pinned above the scrolling buttons so the running effects, their levels and TAP stay in reach.
struct RunningEffectsBar: View {
    @Binding var document: ShowDocument
    @ObservedObject var model: AppModel

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Space.xs) {
                SectionHeader("Running effects", systemImage: "waveform") {
                    if model.runningEffects.isEmpty { Text("none").font(.caption).foregroundStyle(.secondary) }
                    TapTempoButton(model: model)
                }
                ForEach(model.runningEffects, id: \.effectID) { r in
                    if let e = document.show.effects.first(where: { $0.id == r.effectID }) {
                        RunningEffectRow(effect: e, model: model) {
                            let ids = model.effectTargets.isEmpty ? document.show.patch.fixtures.map(\.id) : model.effectTargets
                            let updated = model.retarget(e, to: ids)
                            if let i = document.show.effects.firstIndex(where: { $0.id == e.id }) { document.show.effects[i] = updated }
                        }
                    }
                }
            }
        }
    }
}

/// A big colour-coded button for one effect.
struct EffectButton: View {
    let title: String
    let subtitle: String?
    let colorHex: String
    let isOn: Bool
    let identifier: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            TileLabel(title: title, caption: subtitle)
        }
        .buttonStyle(TileButtonStyle(color: Color(hex: colorHex), isOn: isOn, minHeight: 44))
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
        .accessibilityValue(isOn ? "on" : "off")
    }
}

/// One running effect: effect master slider and stop button.
struct RunningEffectRow: View {
    let effect: Effect
    @ObservedObject var model: AppModel
    /// Moves this effect onto the fixtures picked on the Playback page.
    var usePicked: () -> Void

    var body: some View {
        HStack {
            Circle().fill(Color(hex: effect.colorHex)).frame(width: 12, height: 12)
            Text(effect.name).frame(width: 100, alignment: .leading).lineLimit(1)
            Text("\(effect.fixtureIDs.count) fx").font(.caption).foregroundStyle(.secondary).frame(width: 34)
                .accessibilityIdentifier("effectFixtureCount.\(effect.name)")
            Button(action: usePicked) { Image(systemName: "scope") }
                .help("Run on the picked fixtures")
                .buttonStyle(.borderless)
                .accessibilityLabel("Use picked fixtures for \(effect.name)")
                .accessibilityIdentifier("effectRetarget.\(effect.name)")
            Slider(value: Binding(get: { model.effectLevel(effect.id) }, set: { model.setEffectLevel(effect.id, $0) }),
                   in: 0...1)
                .accessibilityIdentifier("effectLevel.\(effect.name)")
                .accessibilityValue("\(Int((model.effectLevel(effect.id) * 100).rounded())) %")
            Text("\(Int((model.effectLevel(effect.id) * 100).rounded())) %").monospacedDigit()
                .frame(width: 48, alignment: .trailing)
            Button { model.stopEffect(effect.id) } label: { Image(systemName: "stop.fill") }
                .buttonStyle(.borderless).help("Stop")
                .accessibilityLabel("Stop \(effect.name)")
                .accessibilityIdentifier("effectStop.\(effect.name)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("runningEffect.\(effect.name)")
    }
}

/// Four-column grid that is not lazy, so every button is always in the accessibility tree.
struct EffectGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder var content: (Item) -> Content
    private let columns = 4

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(Array(stride(from: 0, to: items.count, by: columns)), id: \.self) { start in
                GridRow {
                    ForEach(items[start..<min(start + columns, items.count)]) { content($0) }
                    ForEach(0..<(start + columns - min(start + columns, items.count)), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, minHeight: 1)
                    }
                }
            }
        }
    }
}

/// Pick which fixtures the preset effects run on. Click order is chase order; the stage preview picks too.
struct EffectFixturePicker: View {
    let patch: Patch
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Fixtures").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Button("All") { model.effectTargets = [] }.accessibilityIdentifier("effectPickAll")
                Button("Odd") { pickEvery(from: 0) }
                Button("Even") { pickEvery(from: 1) }
                Button("Reverse") { model.effectTargets = currentOrder.reversed() }
                    .disabled(model.effectTargets.isEmpty)
                Menu("Type") {
                    ForEach(patch.types.filter { t in patch.fixtures.contains { $0.typeID == t.id } }) { t in
                        Button(t.name) { model.effectTargets = patch.fixtures.filter { $0.typeID == t.id }.map(\.id) }
                    }
                }
                .fixedSize()
            }
            .controlSize(.small)
            FlowChips(items: patch.fixtures) { f in
                let order = model.effectTargets.firstIndex(of: f.id)
                Button { toggle(f.id) } label: {
                    HStack(spacing: 3) {
                        if let order { Text("\(order + 1)").font(.caption2.bold()).monospacedDigit() }
                        Text(f.name).lineLimit(1)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(order != nil ? Color.accentColor : Color.white.opacity(0.1)))
                    .foregroundStyle(order != nil ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(f.name)
                .accessibilityIdentifier("effectPick.\(f.name)")
                .accessibilityValue(order != nil ? "picked" : "")
            }
            Text(model.effectTargets.isEmpty ? "Nothing picked: presets run on all fixtures. Click fixtures here or on the stage."
                                             : "Numbers show chase order. Use the target button on a running effect to move it here.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("effectFixturePicker")
    }

    private var currentOrder: [UUID] { model.effectTargets }

    private func toggle(_ id: UUID) {
        if let i = model.effectTargets.firstIndex(of: id) { model.effectTargets.remove(at: i) }
        else { model.effectTargets.append(id) }
    }

    private func pickEvery(from start: Int) {
        model.effectTargets = patch.fixtures.enumerated().filter { $0.offset % 2 == start }.map(\.element.id)
    }
}

/// Wrapping row of chips.
struct FlowChips<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder var content: (Item) -> Content

    var body: some View {
        WrapLayout(spacing: 6) { ForEach(items) { content($0) } }
    }
}

struct WrapLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0,
                      height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.indices {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
        }
    }

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0; var y: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let s = subviews[i].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty, rows[rows.count - 1].width + spacing + s.width > width {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
            }
            var r = rows[rows.count - 1]
            r.width += (r.indices.isEmpty ? 0 : spacing) + s.width
            r.height = max(r.height, s.height)
            r.indices.append(i)
            rows[rows.count - 1] = r
        }
        return rows
    }
}
