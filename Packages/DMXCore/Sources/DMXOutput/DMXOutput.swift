public protocol DMXOutputDevice: AnyObject, Sendable {
    var isConnected: Bool { get }
    func send(_ frame: DMXFrame) throws
}
