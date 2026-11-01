import Foundation

/// Nothing reaches the device until the user arms output.
@MainActor
public final class OutputGate: ObservableObject {
    @Published public private(set) var isArmed = false
    public let device: DMXOutputDevice
    public init(device: DMXOutputDevice) { self.device = device }
    public func arm() { isArmed = true }
    public func disarm() { isArmed = false }
    /// Returns false (and sends nothing) while disarmed.
    public func submit(_ frame: DMXFrame) throws -> Bool {
        guard isArmed else { return false }
        try device.send(frame)
        return true
    }
}
