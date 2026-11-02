import XCTest

final class EffectsUITests: DMXUITestCase {
    private func selectAllFixtures() {
        openTab("Programmer")
        let all = element("selectAllButton")
        XCTAssertTrue(all.waitForExistence(timeout: 5))
        all.click()
    }

    func testCreateRainbowAndPlay() throws {
        addRGBFixtures(count: 4)
        selectAllFixtures()
        openTab("Library")
        let new = element("newEffectButton")
        XCTAssertTrue(new.waitForExistence(timeout: 5))
        new.click()
        let rainbow = element("effectKind.rainbow")
        XCTAssertTrue(rainbow.waitForExistence(timeout: 5))
        rainbow.click()
        element("useSelectionButton").click()
        let save = element("effectSave")
        XCTAssertTrue(save.isEnabled)
        save.click()

        openTab("Playback")
        let button = element("effectButton.Rainbow")
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForValue("off", of: button))
        button.click()
        XCTAssertTrue(waitForValue("on", of: button))
        XCTAssertTrue(element("runningEffect.Rainbow").waitForExistence(timeout: 5))
    }

    func testPresetChaseIsExclusiveAndOverlaysStack() throws {
        addRGBFixtures(count: 3)
        openTab("Playback")
        let chase = element("effectPreset.Chase")
        let wave = element("effectPreset.Wave")
        let strobe = element("effectPreset.Strobe")
        XCTAssertTrue(chase.waitForExistence(timeout: 5))
        chase.click()
        XCTAssertTrue(waitForValue("on", of: chase))
        // A chase on dark RGB pars still lights them (no snapshot is playing).
        let status = element("outputStatus")
        let lit = NSPredicate(format: "value != %@", "frameSum=0")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: lit, object: status)], timeout: 6), .completed)

        wave.click()
        XCTAssertTrue(waitForValue("on", of: wave))
        XCTAssertTrue(waitForValue("off", of: chase), "starting a chase stops the other chase")

        strobe.click()
        XCTAssertTrue(waitForValue("on", of: strobe))
        XCTAssertTrue(waitForValue("on", of: wave), "overlays stack over a chase")
        XCTAssertTrue(element("effectLevel.Strobe").waitForExistence(timeout: 5))

        let stopWave = element("effectStop.Wave")
        XCTAssertTrue(stopWave.waitForExistence(timeout: 5))
        stopWave.click()
        XCTAssertTrue(waitForValue("off", of: wave), "stop button switches the effect off")
        XCTAssertTrue(waitForValue("on", of: strobe))
    }

    func testBPMFieldIsEditable() throws {
        openTab("Playback")
        let field = element("bpmField")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        let editor = element("bpmEditor")
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.typeKey("a", modifierFlags: .command)
        editor.typeText("90\r")
        XCTAssertTrue(waitForValue("90", of: element("bpmField")))
    }

    func testPickFixturesForPreset() throws {
        addRGBFixtures(count: 4)
        openTab("Playback")
        let chips = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "effectPick."))
        XCTAssertTrue(chips.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(chips.count, 4)
        chips.element(boundBy: 2).click()
        chips.element(boundBy: 0).click()
        XCTAssertTrue(waitForValue("picked", of: chips.element(boundBy: 2)))
        let target = element("effectsTarget")
        XCTAssertTrue(waitForValue("on 2 picked", of: target))

        let chase = element("effectPreset.Chase")
        chase.click()
        XCTAssertTrue(waitForValue("on", of: chase))
        let row = element("runningEffect.Chase")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let count = element("effectFixtureCount.Chase")
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForValue("2 fx", of: count))

        // Pick all again and move the running chase onto every fixture.
        element("effectPickAll").click()
        element("effectRetarget.Chase").click()
        XCTAssertTrue(waitForValue("4 fx", of: count))
    }
}
