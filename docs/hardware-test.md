# Hardware test: DMX Master II over MIDI

Part 1: first session with the real console (plan 1). Tick each step and record results in `docs/console-midi-findings.md`.

- [ ] 1. Connect the USB-MIDI cable's **MIDI OUT** plug to the console's **MIDI** socket.
- [ ] 2. Set the console's MIDI channel to **1** (hold MIDI/Rec 3 s, Bank Up/Down, hold MIDI/Rec 3 s).
- [ ] 3. Program scenes 1 and 2 of bank 1 and chase 1 on the console.
- [ ] 4. In the app: open the Console tab, pick the interface in MIDI settings, press **ARM**, and fire each one (bank 1 scene 1, bank 1 scene 2, chase 1).
- [ ] 5. Run every question from spec 5.2 with the MIDI test panel (see the findings table).
- [ ] 6. Confirm the console label says **DMX Master II** and that it has **12 scanners**.

Safety: nothing is sent until ARM is pressed. Blackout is key **B**. If the app and console disagree, use **Reset console**.

## Part 2: direct DMX through the SH-RS09B (plan 2)

Record results (including the best refresh rate) in `docs/console-midi-findings.md` or below.

- [ ] 1. Plug in the SH-RS09B and connect DMX to the first fixture.
- [ ] 2. Devices → Direct → pick the port → **ARM**.
- [ ] 3. Configure the real fixtures in Config.
- [ ] 4. Touch each channel and confirm the light responds.
- [ ] 5. **Flicker check:** hold one static look for 5 minutes while dragging windows and saving. Note any flicker. If there is any, try refresh 25 Hz and 40 Hz, and record the best value.
- [ ] 6. Unplug the adapter while armed and check the alert ("DMX adapter lost: switch the DMX cable to the console"). Replug and check output resumes.
- [ ] 7. **Backup drill:** move the DMX cable to the console and fire a console scene from the Mac.

Safety: the adapter port is only opened while ARMED. Blackout is key **B**.

