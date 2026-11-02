import Testing
import Foundation
@testable import ShowModel

@Test func effectCodableRoundTrip() throws {
    let e = Effect(name: "Chase", colorHex: "#FF0000", kind: .colorChase, fixtureIDs: [UUID(), UUID()],
                   rateMultiplier: 2, size: 0.5, spread: 0.25, direction: .bounce,
                   colors: [RGB(r: 1, g: 0, b: 0), RGB(r: 0, g: 0, b: 1)])
    let back = try JSONDecoder().decode(Effect.self, from: JSONEncoder().encode(e))
    #expect(back == e)
}

@Test func effectDefaults() {
    let e = Effect(kind: .rainbow, fixtureIDs: [])
    #expect(e.rateMultiplier == 1 && e.size == 1 && e.spread == 1 && e.direction == .forward)
}

@Test func oldShowOpensWithoutEffects() throws {
    let json = #"{"formatVersion":1,"patch":{"types":[],"fixtures":[]},"console":{"midiChannel":1,"cells":[],"looks":[]}}"#
    let show = try Show.decode(Data(json.utf8))
    #expect(show.effects.isEmpty && show.cueLists.isEmpty)
}
