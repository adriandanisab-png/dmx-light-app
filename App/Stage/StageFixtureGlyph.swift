import SwiftUI
import ShowModel
import Engine

/// Draws one fixture into a Canvas: a glowing radial-gradient disc (radius proportional to intensity),
/// plus a beam line for moving heads. Selected fixtures get a ring.
enum StageFixtureGlyph {
    static let baseRadius: CGFloat = 26

    static func draw(in context: GraphicsContext, at center: CGPoint, look: FixtureLook,
                     selected: Bool, time: TimeInterval, name: String) {
        let visible = StagePreviewModel.strobeVisible(hz: look.strobeHz, time: time)
        let level = visible ? look.intensity : 0
        let color = Color(.sRGB, red: look.color.r, green: look.color.g, blue: look.color.b, opacity: 1)
        let radius = baseRadius * (0.35 + 0.65 * CGFloat(level))

        // Dim housing so a dark fixture is still visible.
        let housing = CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14)
        context.fill(Path(ellipseIn: housing), with: .color(.gray.opacity(0.5)))

        if level > 0.01 {
            if let beam = StagePreviewModel.beam(look: look, radius: Double(radius)) {
                var path = Path()
                path.move(to: center)
                path.addLine(to: CGPoint(x: center.x + CGFloat(sin(beam.angle) * beam.length),
                                         y: center.y - CGFloat(cos(beam.angle) * beam.length)))
                context.stroke(path, with: .color(color.opacity(0.8 * level)), lineWidth: 3)
            }
            let disc = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            let gradient = Gradient(colors: [color.opacity(level), color.opacity(0)])
            context.fill(Path(ellipseIn: disc),
                         with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius))
        }
        if selected {
            let ring = CGRect(x: center.x - 20, y: center.y - 20, width: 40, height: 40)
            context.stroke(Path(ellipseIn: ring), with: .color(.white), lineWidth: 2)
        }
        context.draw(Text(name).font(.caption2).foregroundStyle(.secondary),
                     at: CGPoint(x: center.x, y: center.y + 30))
    }
}
