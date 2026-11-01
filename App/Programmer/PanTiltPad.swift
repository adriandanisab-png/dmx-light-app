import SwiftUI
import ShowModel

/// XY pad for pan (x) and tilt (y). Shown only when a selected fixture type has pan and tilt.
struct PanTiltPad: View {
    @ObservedObject var model: AppModel
    @State private var point = CGPoint(x: 0.5, y: 0.5)

    var body: some View {
        HStack(alignment: .top) {
            Text("Pan/Tilt").frame(width: 70, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.25))
                    Circle().fill(Color.accentColor).frame(width: 14, height: 14)
                        .offset(x: point.x * geo.size.width - 7, y: point.y * geo.size.height - 7)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                    let x = min(max(g.location.x / geo.size.width, 0), 1)
                    let y = min(max(g.location.y / geo.size.height, 0), 1)
                    point = CGPoint(x: x, y: y)
                    model.programmerApply { type, values in
                        Attributes.setPanTilt(pan: x, tilt: y, type: type, into: &values)
                    }
                })
            }
            .frame(width: 160, height: 120)
            .accessibilityElement()
            .accessibilityLabel("Pan tilt pad")
            .accessibilityIdentifier("panTiltPad")
        }
    }
}
