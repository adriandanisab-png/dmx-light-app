import CoreMIDI
import Foundation
import ShowModel

/// Sends MIDI 1.0 channel-voice messages to one CoreMIDI destination (e.g. a USB-MIDI cable).
public final class CoreMIDISender: MIDISender, @unchecked Sendable {
    private let uniqueID: Int32
    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private let lock = NSLock()

    public static func destinations() -> [MIDIDestinationInfo] {
        (0..<MIDIGetNumberOfDestinations()).compactMap { i in
            let ref = MIDIGetDestination(i)
            guard ref != 0 else { return nil }
            var id: Int32 = 0
            guard MIDIObjectGetIntegerProperty(ref, kMIDIPropertyUniqueID, &id) == noErr else { return nil }
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(ref, kMIDIPropertyDisplayName, &name)
            return MIDIDestinationInfo(uniqueID: id, name: (name?.takeRetainedValue() as String?) ?? "MIDI \(id)")
        }
    }

    public init(destinationUniqueID: Int32) throws {
        uniqueID = destinationUniqueID
        var status = MIDIClientCreateWithBlock("DMXBridge" as CFString, &client) { _ in }
        guard status == noErr else { throw ConsoleError.sendFailed("MIDI client error \(status)") }
        status = MIDIOutputPortCreate(client, "DMXBridge Out" as CFString, &port)
        guard status == noErr else { throw ConsoleError.sendFailed("MIDI port error \(status)") }
    }

    deinit { MIDIClientDispose(client) }

    private func destination() -> MIDIEndpointRef? {
        var obj: MIDIObjectRef = 0
        var type = MIDIObjectType.other
        guard MIDIObjectFindByUniqueID(uniqueID, &obj, &type) == noErr, obj != 0,
              type == .destination else { return nil }
        return obj
    }

    public var isConnected: Bool { destination() != nil }

    public func send(_ message: MIDIMessage) throws {
        guard let dest = destination() else { throw ConsoleError.noDestination }
        let b = message.bytes
        guard b.count == 3 else { throw ConsoleError.sendFailed("unsupported message length \(b.count)") }
        // UMP type 2 (MIDI 1.0 channel voice), group 0.
        let word = UInt32(0x2) << 28 | UInt32(b[0]) << 16 | UInt32(b[1]) << 8 | UInt32(b[2])
        lock.lock(); defer { lock.unlock() }
        let storage = UnsafeMutableRawPointer.allocate(byteCount: 256, alignment: MemoryLayout<MIDIEventList>.alignment)
        defer { storage.deallocate() }
        let list = storage.bindMemory(to: MIDIEventList.self, capacity: 1)
        var packet = MIDIEventListInit(list, ._1_0)
        packet = MIDIEventListAdd(list, 256, packet, 0, 1, [word])
        let status = MIDISendEventList(port, dest, list)
        guard status == noErr else { throw ConsoleError.sendFailed("CoreMIDI error \(status)") }
    }
}
