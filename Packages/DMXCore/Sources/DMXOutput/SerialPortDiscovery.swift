import Foundation
import IOKit
import IOKit.serial

public struct SerialPortInfo: Hashable, Sendable {
    public let path: String
    public let vendorID: Int?
    public let productName: String?
    public init(path: String, vendorID: Int?, productName: String?) {
        self.path = path; self.vendorID = vendorID; self.productName = productName
    }
}

public enum SerialPortDiscovery {
    public static let ftdiVendorID = 0x0403

    /// Callout devices (/dev/cu.*), FTDI adapters first. Not unit-tested (needs IOKit/hardware).
    public static func ports() -> [SerialPortInfo] {
        guard let matching = IOServiceMatching(kIOSerialBSDServiceValue) else { return [] }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var result: [SerialPortInfo] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let path = property(service, kIOCalloutDeviceKey) as? String else { continue }
            let vendor = (property(service, "idVendor", parents: true) as? NSNumber)?.intValue
            let product = property(service, "USB Product Name", parents: true) as? String
            result.append(SerialPortInfo(path: path, vendorID: vendor, productName: product))
        }
        return result.sorted {
            let a = $0.vendorID == ftdiVendorID, b = $1.vendorID == ftdiVendorID
            return a != b ? a : $0.path < $1.path
        }
    }

    private static func property(_ service: io_object_t, _ key: String, parents: Bool = false) -> Any? {
        let options: IOOptionBits = parents ? IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents) : 0
        return IORegistryEntrySearchCFProperty(service, kIOServicePlane, key as CFString, kCFAllocatorDefault, options)
    }
}
