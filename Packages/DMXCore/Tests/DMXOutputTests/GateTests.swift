import Testing
@testable import DMXOutput

@MainActor
@Test func gateBlocksUntilArmed() throws {
    let device = VirtualDMXOutput()
    let gate = OutputGate(device: device)
    #expect(try gate.submit(DMXFrame()) == false)
    #expect(device.sentFrames.isEmpty)
    gate.arm()
    #expect(try gate.submit(DMXFrame()) == true)
    #expect(device.sentFrames.count == 1)
}
