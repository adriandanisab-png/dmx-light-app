import Foundation

public enum EffectPresetCategory: String, CaseIterable, Sendable { case chase, overlay }

/// A ready-made effect recipe; `makeEffect` stamps it onto a fixture list.
public struct EffectPreset: Identifiable, Sendable {
    public var id: String
    public var name: String
    public var category: EffectPresetCategory
    public var colorHex: String
    var kind: EffectKind
    var rate: Double = 1
    var size: Double = 1
    var spread: Double = 1
    var direction: EffectDirection = .forward
    var colors: [RGB] = []

    public func makeEffect(fixtureIDs: [UUID]) -> Effect {
        Effect(name: name, colorHex: colorHex, kind: kind, fixtureIDs: fixtureIDs, rateMultiplier: rate,
               size: size, spread: spread, direction: direction, colors: colors)
    }
}

public enum EffectPresets {
    private static let red = RGB(r: 1, g: 0, b: 0), blue = RGB(r: 0, g: 0, b: 1)
    private static let orange = RGB(r: 1, g: 0.4, b: 0), amber = RGB(r: 1, g: 0.7, b: 0)

    public static let all: [EffectPreset] = [
        EffectPreset(id: "chase", name: "Chase", category: .chase, colorHex: "#F5A623", kind: .intensityChase),
        EffectPreset(id: "chase-bounce", name: "Chase back and forth", category: .chase, colorHex: "#E8833A",
                     kind: .intensityChase, direction: .bounce),
        EffectPreset(id: "chase-fast", name: "Fast chase", category: .chase, colorHex: "#D0021B",
                     kind: .intensityChase, rate: 2),
        EffectPreset(id: "wave", name: "Wave", category: .chase, colorHex: "#4A90E2", kind: .intensityWave),
        EffectPreset(id: "wave-slow", name: "Slow wave", category: .chase, colorHex: "#50E3C2",
                     kind: .intensityWave, rate: 0.5),
        EffectPreset(id: "rainbow", name: "Rainbow", category: .chase, colorHex: "#BD10E0", kind: .rainbow),
        EffectPreset(id: "rainbow-wash", name: "Rainbow wash", category: .chase, colorHex: "#9013FE",
                     kind: .rainbow, spread: 0),
        EffectPreset(id: "red-blue", name: "Red/blue chase", category: .chase, colorHex: "#7B61FF",
                     kind: .colorChase, colors: [red, blue]),
        EffectPreset(id: "police", name: "Police", category: .chase, colorHex: "#2D3EE8",
                     kind: .colorChase, rate: 2, colors: [red, blue]),
        EffectPreset(id: "fire", name: "Fire", category: .chase, colorHex: "#FF5A1F",
                     kind: .colorChase, colors: [red, orange, amber]),
        EffectPreset(id: "sparkle", name: "Sparkle", category: .chase, colorHex: "#F8E71C", kind: .sparkle),

        EffectPreset(id: "strobe", name: "Strobe", category: .overlay, colorHex: "#FFFFFF", kind: .strobe),
        EffectPreset(id: "strobe-slow", name: "Slow strobe", category: .overlay, colorHex: "#C8C8C8",
                     kind: .strobe, rate: 0.5),
        EffectPreset(id: "sparkle-overlay", name: "Sparkle overlay", category: .overlay, colorHex: "#FFE9A8",
                     kind: .sparkle),
        EffectPreset(id: "breathe", name: "Breathe", category: .overlay, colorHex: "#7ED6A8",
                     kind: .intensityWave, size: 0.5, spread: 0),
        EffectPreset(id: "circle", name: "Circle", category: .overlay, colorHex: "#36C5F0", kind: .panTiltCircle),
        EffectPreset(id: "figure8", name: "Figure 8", category: .overlay, colorHex: "#2EB67D", kind: .figure8),
        EffectPreset(id: "circle-small", name: "Small circle", category: .overlay, colorHex: "#1F8FB5",
                     kind: .panTiltCircle, size: 0.3),
    ]
}
