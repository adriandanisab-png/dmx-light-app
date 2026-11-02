import Testing
import Foundation
@testable import ShowModel

@Test func presetsMakeEffectsWithFixtures() {
    let ids = [UUID(), UUID(), UUID()]
    for p in EffectPresets.all {
        let e = p.makeEffect(fixtureIDs: ids)
        #expect(e.fixtureIDs == ids && e.name == p.name && e.colorHex == p.colorHex)
        if e.kind == .colorChase { #expect(e.colors.count >= 2) }
    }
}

@Test func presetsAreUnique() {
    let all = EffectPresets.all
    #expect(Set(all.map(\.id)).count == all.count)
    #expect(Set(all.map(\.name)).count == all.count)
    #expect(Set(all.map(\.colorHex)).count == all.count)
}

@Test func presetCategoriesNonEmpty() {
    for c in EffectPresetCategory.allCases { #expect(EffectPresets.all.contains { $0.category == c }) }
}

@Test func presetOverlayFlagFollowsCategory() throws {
    for p in EffectPresets.all { #expect(p.makeEffect(fixtureIDs: []).overlay == (p.category == .overlay)) }
    // Older files have no "overlay" key.
    var e = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Effect(kind: .strobe, fixtureIDs: []))) as! [String: Any]
    e["overlay"] = nil
    let old = try JSONDecoder().decode(Effect.self, from: JSONSerialization.data(withJSONObject: e))
    #expect(old.overlay == false)
}
