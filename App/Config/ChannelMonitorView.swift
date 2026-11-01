import SwiftUI
import DMXOutput

/// 512 small cells with value bars, read from the engine's latest frame on the main thread at display rate.
struct ChannelMonitorView: View {
    @ObservedObject var model: AppModel
    private let columns = 32

    var body: some View {
        TimelineView(.animation) { _ in
            let frame = model.runner.latestFrame()
            Canvas { context, size in
                let rows = DMXFrame.size / columns
                let w = size.width / CGFloat(columns), h = size.height / CGFloat(rows)
                for i in 0..<DMXFrame.size {
                    let cell = CGRect(x: CGFloat(i % columns) * w, y: CGFloat(i / columns) * h, width: w - 1, height: h - 1)
                    context.fill(Path(cell), with: .color(.gray.opacity(0.2)))
                    let level = CGFloat(frame[i + 1]) / 255
                    if level > 0 {
                        let bar = CGRect(x: cell.minX, y: cell.maxY - cell.height * level, width: cell.width, height: cell.height * level)
                        context.fill(Path(bar), with: .color(.accentColor))
                    }
                }
            }
        }
        .padding(8)
        .accessibilityElement()
        .accessibilityLabel("Channel monitor, 512 channels")
    }
}
