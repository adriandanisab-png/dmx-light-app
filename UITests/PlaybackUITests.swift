import XCTest

final class PlaybackUITests: DMXUITestCase {
    func testRecallLightsButtonAndBlackoutKey() throws {
        addRGBFixtures(count: 2)
        recordRedSnapshot(named: "Red wash")
        // Clear the programmer so playback is what drives the frame.
        element("clearProgrammer").click()

        openTab("Playback")
        let button = element("playbackButton.Red wash")
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForValue("off", of: button))
        button.click()
        XCTAssertTrue(waitForValue("on", of: button))
        XCTAssertTrue(element("fadeTimeField").waitForExistence(timeout: 5), "fade time is editable on this page")
        XCTAssertTrue(element("playbackStagePreview").exists, "the stage preview is visible while playing back")

        app.typeKey("b", modifierFlags: [])
        let blackout = element("blackoutButton")
        XCTAssertTrue(waitForValue("on", of: blackout))

        // Preview-only mode with blackout: the rendered frame is all zero (debug value on the status bar).
        let status = element("outputStatus")
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        let zero = NSPredicate(format: "value == %@", "frameSum=0")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: zero, object: status)], timeout: 5), .completed)
    }

    /// Faders are slider-backed accessibility elements; synthetic drags don't reach SwiftUI gestures on CI.
    func testFaderBanks() throws {
        addRGBFixtures(count: 2)
        recordRedSnapshot(named: "Red wash")
        element("clearProgrammer").click()
        openTab("Playback")

        let picker = element("faderBankPicker")
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        let snapshotsBank = app.radioButtons["Snapshots"].firstMatch
        if snapshotsBank.exists { snapshotsBank.click() }
        let fader = element("snapshotFader.Red wash")
        XCTAssertTrue(fader.waitForExistence(timeout: 5))
        XCTAssertEqual(level(of: fader), 0, accuracy: 0.001)
        pull(fader, to: 0.6)
        XCTAssertTrue(waitForLevel(of: fader) { $0 > 0.3 }, "snapshot fader moved to \(level(of: fader)) \(diag)")
        let status = element("outputStatus")
        let lit = NSPredicate(format: "value != %@", "frameSum=0")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: lit, object: status)], timeout: 5), .completed)
        XCTAssertTrue(waitForValue("on", of: element("playbackButton.Red wash")), "the fader activates the snapshot")

        let fixtures = app.radioButtons["Fixtures"].firstMatch
        XCTAssertTrue(fixtures.waitForExistence(timeout: 5))
        fixtures.click()
        let first = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'fixtureFader.'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertEqual(level(of: first), 0, accuracy: 0.001)
        pull(first, to: 0.8)
        XCTAssertTrue(waitForLevel(of: first) { $0 > 0.5 }, "fixture fader moved to \(level(of: first))")
    }

    func testPickLightsAndColour() throws {
        addRGBFixtures(count: 3)
        openTab("Playback")
        let fixtures = app.radioButtons["Fixtures"].firstMatch
        XCTAssertTrue(fixtures.waitForExistence(timeout: 10))
        fixtures.click()

        // Click two lights' names to pick them: a "Picked" group fader appears.
        let names = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'faderName.'"))
        XCTAssertTrue(names.firstMatch.waitForExistence(timeout: 5))
        names.element(boundBy: 0).click()
        names.element(boundBy: 2).click()
        XCTAssertTrue(waitForValue("picked", of: names.element(boundBy: 0)))
        let group = element("pickedFader")
        XCTAssertTrue(group.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForValue("2 picked", of: element("colorTarget")))

        // Red, then the group fader up: the picked pars light.
        element("pickedSwatch.red").click()
        pull(group, to: 0.8)
        let status = element("outputStatus")
        let lit = NSPredicate(format: "value != %@", "frameSum=0")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: lit, object: status)], timeout: 5), .completed)
        XCTAssertTrue(element("pickedColorReset").isEnabled)
    }

    /// Sets the vertical fader through its slider accessibility action (0 bottom, 1 top): no drag.
    private var diag = ""

    private func pull(_ fader: XCUIElement, to level: Double) {
        fader.adjust(toNormalizedSliderPosition: level)
        if !waitForLevel(of: fader, timeout: 2, { $0 > 0.05 }) {
            // Diagnostics for CI, then a plain click on the track as a second route.
            let note = "adjust did not move \(fader.identifier): frame=\(fader.frame) value=\(String(describing: fader.value)) type=\(fader.elementType.rawValue)"
            XCTContext.runActivity(named: note) { _ in }
            diag += note + "; "
            fader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1 - level)).click()
            _ = waitForLevel(of: fader, timeout: 2, { $0 > 0.05 })
            diag += "after click value=\(String(describing: fader.value)) button=\(String(describing: element("playbackButton.Red wash").value)) status=\(String(describing: element("outputStatus").value)); "
        }
    }

    /// A slider's value is a number (0...1) or, for text-valued elements, "NN %".
    private func level(of el: XCUIElement) -> Double {
        if let n = el.value as? NSNumber { return n.doubleValue }
        if let s = el.value as? String {
            return (Double(s.replacingOccurrences(of: " %", with: "")).map { $0 / 100 }) ?? Double(s) ?? -1
        }
        return -1
    }

    private func waitForLevel(of el: XCUIElement, timeout: TimeInterval = 5, _ ok: (Double) -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if ok(level(of: el)) { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return ok(level(of: el))
    }
}
