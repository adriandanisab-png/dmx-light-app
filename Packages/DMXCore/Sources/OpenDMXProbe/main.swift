// Hardware check for the SH-RS09B: lists serial ports and (given a path) chases channel 1.
// Usage: swift run opendmx-probe [/dev/cu.usbserial-XXXX]
import Foundation
import DMXOutput

#if DEBUG
let ports = SerialPortDiscovery.ports()
print("Serial ports (FTDI first):")
for p in ports {
    let ftdi = p.vendorID == SerialPortDiscovery.ftdiVendorID ? "  [FTDI]" : ""
    print("  \(p.path)  \(p.productName ?? "?")\(ftdi)")
}
if let path = CommandLine.arguments.dropFirst().first {
    let out = OpenDMXOutput(path: path)
    out.onDisconnect = { print("adapter lost") }
    do { try out.start() } catch { print("open failed: \(error)"); exit(1) }
    print("Chasing channel 1 for 10 s...")
    let end = Date().addingTimeInterval(10)
    var level = 0
    while Date() < end {
        var f = DMXFrame()
        f[1] = UInt8(level)
        try? out.send(f)
        level = (level + 5) % 256
        Thread.sleep(forTimeInterval: 0.05)
    }
    var off = DMXFrame(); off[1] = 0
    try? out.send(off)
    Thread.sleep(forTimeInterval: 0.2)
    out.stop()
} else {
    print("Pass a port path to run a channel 1 chase.")
}
#else
print("opendmx-probe is a debug-only tool.")
#endif
