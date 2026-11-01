import ShowModel

extension Engine {
    /// True for channels that merge HTP and that grand master / blackout scale:
    /// the intensity channel, or (for types without one) the colour channels.
    public static func isIntensity(_ fn: ChannelFunction, typeHasIntensity: Bool) -> Bool {
        if fn == .intensity { return true }
        guard !typeHasIntensity else { return false }
        switch fn {
        case .red, .green, .blue, .white, .amber, .uv: return true
        default: return false
        }
    }
}
