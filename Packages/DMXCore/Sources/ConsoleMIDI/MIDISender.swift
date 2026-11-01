public struct MIDIDestinationInfo: Hashable, Sendable {
    public let uniqueID: Int32
    public let name: String
    public init(uniqueID: Int32, name: String) { self.uniqueID = uniqueID; self.name = name }
}

public protocol MIDISender: AnyObject, Sendable {
    var isConnected: Bool { get }
    func send(_ message: MIDIMessage) throws
}
