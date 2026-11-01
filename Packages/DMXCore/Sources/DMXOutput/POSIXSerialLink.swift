import Foundation
import Darwin

/// Real serial port. Not unit-tested (needs hardware).
public final class POSIXSerialLink: SerialLink, @unchecked Sendable {
    // Darwin macros Swift does not import:
    //   IOSSIOSPEED = _IOW('T', 2, speed_t)   (speed_t is 8 bytes)
    //   TIOCSBRK    = _IO('t', 123),  TIOCCBRK = _IO('t', 122)
    private static let iossiospeed: UInt = 0x8008_5402
    private static let tiocsbrk: UInt = 0x2000_747B
    private static let tioccbrk: UInt = 0x2000_747A

    private let lock = NSLock()
    private var fd: Int32 = -1

    public init() {}
    deinit { close() }

    private static func errnoText() -> String { String(cString: strerror(errno)) }

    public func open(path: String, baud: Int, stopBits: Int) throws {
        close()
        let handle = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard handle >= 0 else { throw DMXDeviceError.openFailed(Self.errnoText()) }
        func fail() -> DMXDeviceError {
            let e = DMXDeviceError.openFailed(Self.errnoText())
            Darwin.close(handle)
            return e
        }
        // Back to blocking I/O.
        let flags = fcntl(handle, F_GETFL)
        guard flags >= 0, fcntl(handle, F_SETFL, flags & ~O_NONBLOCK) >= 0 else { throw fail() }
        var tio = termios()
        guard tcgetattr(handle, &tio) == 0 else { throw fail() }
        cfmakeraw(&tio)
        tio.c_cflag |= tcflag_t(CLOCAL | CREAD)
        tio.c_cflag &= ~tcflag_t(CSIZE | PARENB)
        tio.c_cflag |= tcflag_t(CS8)
        if stopBits == 2 { tio.c_cflag |= tcflag_t(CSTOPB) } else { tio.c_cflag &= ~tcflag_t(CSTOPB) }
        guard tcsetattr(handle, TCSANOW, &tio) == 0 else { throw fail() }
        // Custom baud (250000) is not a termios constant: set it through IOKit's ioctl.
        var speed = speed_t(baud)
        guard ioctl(handle, Self.iossiospeed, &speed) != -1 else { throw fail() }
        lock.lock(); fd = handle; lock.unlock()
    }

    private func currentFD() throws -> Int32 {
        lock.lock(); defer { lock.unlock() }
        guard fd >= 0 else { throw DMXDeviceError.disconnected }
        return fd
    }

    public func sendBreak(microseconds: Int) throws {
        let h = try currentFD()
        guard ioctl(h, Self.tiocsbrk, 0) != -1 else { throw DMXDeviceError.writeFailed(Self.errnoText()) }
        usleep(useconds_t(microseconds))
        guard ioctl(h, Self.tioccbrk, 0) != -1 else { throw DMXDeviceError.writeFailed(Self.errnoText()) }
    }

    public func sleep(microseconds: Int) { usleep(useconds_t(microseconds)) }

    public func write(_ bytes: [UInt8]) throws {
        let h = try currentFD()
        var offset = 0
        while offset < bytes.count {
            let n = bytes[offset...].withUnsafeBytes { Darwin.write(h, $0.baseAddress, $0.count) }
            if n < 0 {
                if errno == EINTR { continue }
                throw DMXDeviceError.writeFailed(Self.errnoText())
            }
            offset += n
        }
    }

    public func drain() throws {
        let h = try currentFD()
        guard tcdrain(h) == 0 else { throw DMXDeviceError.writeFailed(Self.errnoText()) }
    }

    public func close() {
        lock.lock()
        let h = fd; fd = -1
        lock.unlock()
        if h >= 0 { Darwin.close(h) }
    }
}
