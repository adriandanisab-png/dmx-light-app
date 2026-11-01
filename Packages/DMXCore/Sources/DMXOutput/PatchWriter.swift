import ShowModel

public enum PatchWriter {
    public static func defaults(for patch: Patch) -> DMXFrame {
        var frame = DMXFrame()
        for fixture in patch.fixtures {
            guard let type = patch.type(of: fixture) else { continue }
            for (i, ch) in type.channels.enumerated() {
                frame[fixture.address + i] = ch.defaultValue
            }
        }
        return frame
    }

    public static func set(_ value: UInt8, channel index: Int, of fixture: Fixture, in frame: inout DMXFrame, patch: Patch) {
        guard let type = patch.type(of: fixture), (0..<type.channelCount).contains(index) else { return }
        frame[fixture.address + index] = value
    }
}
