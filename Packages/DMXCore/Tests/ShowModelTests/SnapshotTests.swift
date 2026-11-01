import Testing
import Foundation
@testable import ShowModel

@Test func oldShowFileStillOpens() throws {
    // A Plan 1 file: encode a current show, then strip the keys Plan 2 added.
    var obj = try JSONSerialization.jsonObject(with: Show().encode()) as! [String: Any]
    obj.removeValue(forKey: "snapshots")
    obj.removeValue(forKey: "stage")
    let show = try Show.decode(JSONSerialization.data(withJSONObject: obj))
    #expect(show.snapshots == [])
    #expect(show.stage.widthMeters == 10)
    #expect(show.stage.depthMeters == 6)
    #expect(show.formatVersion == 1)
}

@Test func oldFixtureTypeGetsDefaultRanges() throws {
    let t = TestTypes.movingHead16
    var obj = try JSONSerialization.jsonObject(with: JSONEncoder().encode(t)) as! [String: Any]
    obj.removeValue(forKey: "panRangeDegrees")
    obj.removeValue(forKey: "tiltRangeDegrees")
    let decoded = try JSONDecoder().decode(FixtureType.self, from: JSONSerialization.data(withJSONObject: obj))
    #expect(decoded.panRangeDegrees == 540)
    #expect(decoded.tiltRangeDegrees == 270)
}

@Test func snapshotRoundTripInShow() throws {
    var show = Show()
    let fid = UUID()
    show.snapshots = [Snapshot(name: "Red", colorHex: "#FF0000", values: [fid: [0: 255]], defaultFade: 2)]
    show.stage.backgroundFileName = "bg.png"
    let back = try Show.decode(show.encode())
    #expect(back == show)
    #expect(Snapshot(name: "x", colorHex: "#000000").defaultFade == 1.0)
}
