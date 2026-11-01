import Testing
import Foundation
import ShowModel
import DMXOutput
@testable import Engine

private func look(_ typeName: String, _ set: (Int, inout DMXFrame) -> Void) -> FixtureLook {
    let t = BuiltInTemplates.all.first { $0.name == typeName }!
    let f = Fixture(name: "f", typeID: t.id, address: 10)
    var frame = DMXFrame()
    set(f.address, &frame)
    return FixtureLook.from(frame: frame, fixture: f, type: t)
}

@Test func rgbParRed() {
    let l = look("RGB") { a, f in f[a] = 255 }
    #expect(l.color == RGB(r: 1, g: 0, b: 0))
    #expect(l.intensity == 1)
    #expect(l.strobeHz == nil)
    #expect(l.panDegrees == nil)
}

@Test func whiteAddedToEachComponent() {
    let l = look("RGBW") { a, f in f[a] = 51; f[a + 3] = 51 }   // r=0.2, w=0.2
    #expect(abs(l.color.r - 0.4) < 0.001)
    #expect(abs(l.color.g - 0.2) < 0.001)
}

@Test func dimmerOnlyIsWhite() {
    let l = look("Dimmer") { a, f in f[a] = 51 }
    #expect(l.color == RGB(r: 1, g: 1, b: 1))
    #expect(abs(l.intensity - 0.2) < 0.001)
}

@Test func intensityChannelScalesIntensityNotColour() {
    let l = look("RGB + Dimmer + Strobe") { a, f in f[a] = 255; f[a + 2] = 255 }   // dimmer full, green
    #expect(l.color == RGB(r: 0, g: 1, b: 0))
    #expect(l.intensity == 1)
}

@Test func strobeMapping() {
    func hz(_ v: UInt8) -> Double? { look("RGB + Dimmer + Strobe") { a, f in f[a + 4] = v }.strobeHz }
    #expect(hz(5) == nil)
    #expect(hz(9) == nil)
    #expect(abs(hz(10)! - 1) < 0.001)
    #expect(abs(hz(255)! - 20) < 0.001)
}

@Test func panCentre() {
    let l = look("Moving Head 16ch") { a, f in f[a] = 128; f[a + 1] = 0; f[a + 2] = 128 }
    #expect(abs(l.panDegrees! - 0) <= 1.1)
    #expect(abs(l.tiltDegrees! - 0) <= 1.1)
}

@Test func panExtremes() {
    let l = look("Moving Head 8ch") { a, f in f[a] = 255; f[a + 1] = 0 }   // 8-bit pan/tilt
    #expect(abs(l.panDegrees! - 270) < 0.001)
    #expect(abs(l.tiltDegrees! - (-135)) < 0.001)
}
