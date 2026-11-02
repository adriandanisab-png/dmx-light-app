import SwiftUI
import AppKit
import ShowModel
import Engine

/// 2D preview: a Canvas in a `TimelineView(.animation)` reading the engine's latest frame on the main
/// thread, with transparent interactive overlays for dragging and selecting fixtures.
/// Takes the model explicitly (never via the environment).
struct StageView: View {
    @Binding var document: ShowDocument
    @Binding var selection: [UUID]
    @ObservedObject var model: AppModel
    /// False on the Playback page: preview only, no editing, dragging or selecting.
    var editable = true
    /// With `editable` false: fixtures can still be clicked to (de)select, but not moved.
    var selectOnly = false
    @State private var background: NSImage?
    @State private var lasso: CGRect?
    @State private var dragStart: StagePoint?

    var body: some View {
        VStack(spacing: 0) {
            if editable { StageEditorToolbar(document: $document) }
            GeometryReader { geo in
                let size = geo.size
                ZStack {
                    canvas(size: size)
                    if editable {
                    // Background drag layer: lasso, and click on empty stage clears the selection.
                    Color.clear.contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { g in
                                let r = CGRect(x: min(g.startLocation.x, g.location.x), y: min(g.startLocation.y, g.location.y),
                                               width: abs(g.location.x - g.startLocation.x), height: abs(g.location.y - g.startLocation.y))
                                if r.width > 4 || r.height > 4 { lasso = r }
                            }
                            .onEnded { g in
                                if let r = lasso {
                                    let positions = StagePreviewModel.positions(for: document.show.patch)
                                    let hit = document.show.patch.fixtures.filter {
                                        guard let p = positions[$0.id] else { return false }
                                        return r.contains(CGPoint(x: p.x * size.width, y: p.y * size.height))
                                    }.map(\.id)
                                    selection = isShift ? Array(Set(selection).union(hit)) : hit
                                } else if !isShift {
                                    selection = []
                                }
                                lasso = nil
                            })
                    if let lasso {
                        Rectangle().stroke(Color.white, style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .background(Color.white.opacity(0.08))
                            .frame(width: lasso.width, height: lasso.height)
                            .position(x: lasso.midX, y: lasso.midY)
                            .allowsHitTesting(false)
                    }
                    fixtureOverlays(size: size)
                    } else if selectOnly {
                        fixtureOverlays(size: size)
                    }
                }
                .frame(width: size.width, height: size.height)
                .clipped()
            }
            .background(Color.black.opacity(0.4))
        }
        .onAppear { background = document.backgroundImageData.flatMap { NSImage(data: $0) } }
        .onChange(of: document.backgroundImageData) { _, new in background = new.flatMap { NSImage(data: $0) } }
    }

    private var isShift: Bool { NSEvent.modifierFlags.contains(.shift) }

    private func canvas(size: CGSize) -> some View {
        let patch = document.show.patch
        let positions = StagePreviewModel.positions(for: patch)
        let selected = Set(selection)
        return TimelineView(.animation) { timeline in
            // Main thread, display rate. Never the engine/DMX threads.
            let looks = StagePreviewModel.looks(frame: model.runner.latestFrame(), patch: patch)
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                if let background {
                    context.draw(Image(nsImage: background), in: CGRect(origin: .zero, size: canvasSize))
                }
                for f in patch.fixtures {
                    guard let p = positions[f.id], let look = looks[f.id] else { continue }
                    StageFixtureGlyph.draw(in: context, at: CGPoint(x: p.x * canvasSize.width, y: p.y * canvasSize.height),
                                           look: look, selected: selected.contains(f.id), time: t, name: f.name)
                }
            }
        }
    }

    private func fixtureOverlays(size: CGSize) -> some View {
        let positions = StagePreviewModel.positions(for: document.show.patch)
        return ForEach(document.show.patch.fixtures) { f in
            let p = positions[f.id] ?? StagePoint(x: 0.5, y: 0.5)
            Color.white.opacity(0.001)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .position(x: p.x * size.width, y: p.y * size.height)
                .onTapGesture {
                    if selectOnly {
                        if selection.contains(f.id) { selection.removeAll { $0 == f.id } } else { selection.append(f.id) }
                    } else if isShift {
                        if selection.contains(f.id) { selection.removeAll { $0 == f.id } } else { selection.append(f.id) }
                    } else {
                        selection = [f.id]
                    }
                }
                .highPriorityGesture(DragGesture(minimumDistance: 3)  // wins over the stage's lasso
                    .onChanged { g in
                        if dragStart == nil { dragStart = p }
                        guard let start = dragStart, size.width > 0, size.height > 0,
                              let i = document.show.patch.fixtures.firstIndex(where: { $0.id == f.id }) else { return }
                        if !selection.contains(f.id) { selection = [f.id] }
                        document.show.patch.fixtures[i].stagePosition = StagePoint(
                            x: min(max(start.x + g.translation.width / size.width, 0), 1),
                            y: min(max(start.y + g.translation.height / size.height, 0), 1))
                    }
                    .onEnded { _ in dragStart = nil }, including: editable ? .all : .subviews)
                .accessibilityElement()
                .accessibilityLabel(f.name)
                .accessibilityIdentifier("stageFixture.\(f.id.uuidString)")
                .accessibilityValue(StagePreviewModel.positionText(p))
                .accessibilityAddTraits(selection.contains(f.id) ? .isSelected : [])
        }
    }
}

/// The "Stage" tab: Preview and Channels sub-tabs.
struct StageTabView: View {
    @Binding var document: ShowDocument
    @Binding var selection: [UUID]
    @ObservedObject var model: AppModel
    @State private var sub = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $sub) {
                Text("Preview").tag(0)
                Text("Channels").tag(1)
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 240).padding(8)
            .accessibilityIdentifier("stageSubTab")
            if sub == 0 {
                StageView(document: $document, selection: $selection, model: model)
            } else {
                ChannelMonitorView(model: model)
            }
        }
    }
}
