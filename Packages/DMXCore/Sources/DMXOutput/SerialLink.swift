import Foundation

/// Abstraction over the serial port so the Open DMX loop can be unit-tested.
public protocol SerialLink: AnyObject, Sendable {
    func open(path: String, baud: Int, stopBits: Int) throws
    /// TIOCSBRK, sleep, TIOCCBRK.
    func sendBreak(microseconds: Int) throws
    func sleep(microseconds: Int)
    func write(_ bytes: [UInt8]) throws
    /// tcdrain.
    func drain() throws
    func close()
}

public enum DMXDeviceError: Error, Equatable {
    case openFailed(String), writeFailed(String), disconnected
}
