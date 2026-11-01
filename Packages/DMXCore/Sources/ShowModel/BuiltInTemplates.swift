import Foundation

public enum BuiltInTemplates {
    private static func type(_ name: String, _ chans: [(String, ChannelFunction)]) -> FixtureType {
        FixtureType(name: name, channels: chans.map { ChannelDef(name: $0.0, function: $0.1) })
    }

    public static let all: [FixtureType] = [
        type("Dimmer", [("Intensity", .intensity)]),
        type("RGB", [("Red", .red), ("Green", .green), ("Blue", .blue)]),
        type("RGBW", [("Red", .red), ("Green", .green), ("Blue", .blue), ("White", .white)]),
        type("RGB + Dimmer + Strobe", [("Intensity", .intensity), ("Red", .red), ("Green", .green),
                                       ("Blue", .blue), ("Strobe", .strobe)]),
        type("Moving Head 8ch", [("Pan", .pan), ("Tilt", .tilt), ("Color wheel", .colorWheel), ("Gobo", .gobo),
                                 ("Strobe", .strobe), ("Intensity", .intensity), ("Speed", .speed), ("Macro", .macro)]),
        type("Moving Head 16ch", [("Pan", .pan), ("Pan fine", .panFine), ("Tilt", .tilt), ("Tilt fine", .tiltFine),
                                  ("Speed", .speed), ("Intensity", .intensity), ("Strobe", .strobe),
                                  ("Red", .red), ("Green", .green), ("Blue", .blue), ("White", .white),
                                  ("Color wheel", .colorWheel), ("Gobo", .gobo), ("Macro", .macro),
                                  ("Control 1", .generic), ("Control 2", .generic)]),
    ]
}
