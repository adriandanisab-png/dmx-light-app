import Testing
import Foundation
@testable import ShowModel

enum TestTypes {
    static func named(_ n: String) -> FixtureType { BuiltInTemplates.all.first { $0.name == n }! }
    static var dimmer: FixtureType { named("Dimmer") }
    static var rgb: FixtureType { named("RGB") }
    static var rgbw: FixtureType { named("RGBW") }
    static var rgbDimmerStrobe: FixtureType { named("RGB + Dimmer + Strobe") }
    static var movingHead16: FixtureType { named("Moving Head 16ch") }
}

@Test func intensityOnDimmerChannel() {
    var v: FixtureValues = [:]
    Attributes.setIntensity(0.5, type: TestTypes.rgbDimmerStrobe, into: &v)
    #expect(v[0] == 128)
    #expect(v.count == 1)
}

@Test func intensityOnRGBOnlyScalesColour() {
    var v: FixtureValues = [0: 255, 1: 100]
    Attributes.setIntensity(0.5, type: TestTypes.rgb, into: &v)
    #expect(v[0] == 128)
    #expect(v[1] == 50)
}

@Test func colourWithWhite() {
    var v: FixtureValues = [:]
    Attributes.setColor(RGB(r: 1, g: 1, b: 0.5), type: TestTypes.rgbw, into: &v)
    #expect(v[0] == 128)
    #expect(v[1] == 128)
    #expect(v[2] == 0)
    #expect(v[3] == 128)
}

@Test func colourWithoutWhite() {
    var v: FixtureValues = [:]
    Attributes.setColor(RGB(r: 1, g: 0, b: 0), type: TestTypes.rgb, into: &v)
    #expect(v == [0: 255, 1: 0, 2: 0])
    #expect(Attributes.color(of: v, type: TestTypes.rgb) == RGB(r: 1, g: 0, b: 0))
}

@Test func panTilt16bit() {
    var v: FixtureValues = [:]
    Attributes.setPanTilt(pan: 0.5, tilt: 0, type: TestTypes.movingHead16, into: &v)
    #expect(v[0] == 128)
    #expect(v[1] == 0)
    #expect(v[2] == 0)
    #expect(v[3] == 0)
}

@Test func panTilt8bitOnly() {
    var v: FixtureValues = [:]
    let t = TestTypes.named("Moving Head 8ch")
    Attributes.setPanTilt(pan: 1, tilt: 0.5, type: t, into: &v)
    #expect(v[0] == 255)
    #expect(v[1] == 128)
}
