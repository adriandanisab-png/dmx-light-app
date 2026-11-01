# DMX Light App for Mac: Design

Working title: **DMX Bridge** (rename freely)
Date: 2026-11-02
Status: owner answers folded in (2026-11-02); ready for owner sign-off

---

## 1. Intent: what this is and why

The owner runs stage lighting with a **Stairville DMX Master II** console (the
older 19" rack unit: 12 "scanners" × 16 DMX channels, 30 banks × 8 scenes,
6 chases, 8 faders, MIDI IN, DMX IN, DMX OUT). Programming looks on the console
is slow and limited. The owner wants to:

- **program and run the lights from a Mac**: create snapshots (looks),
  effects and sequences in a comfortable UI;
- **see a preview** of the stage while programming, so a show can be built
  without the lights switched on (or even connected);
- **keep the console as a backup** if the Mac or adapter fails mid-show.

The console's MIDI input is limited (verified from its manual, section
4-7): it only **toggles stored scenes, chases and blackout**. It cannot set
individual channels or faders. So the app has **two output modes**, which
the owner wants built together:

| Mode | How the Mac reaches the lights | What the Mac can do |
|---|---|---|
| **Direct (DMX)** | Mac → USB-DMX adapter → fixtures | Everything: every channel of every light, snapshots, effects, cues |
| **Console (MIDI)** | Mac → USB-MIDI cable → console MIDI IN; console → fixtures | Fire/stop console scenes (banks 1–15), chases 1–6, blackout, in any combination or timed sequence |

Both modes share one show file, one preview and one playback screen.

## 2. Goals (v1)

1. **Patch:** define the rig: fixtures, their type (profile), DMX start
   address, position on the stage plot.
2. **Fixture & channel configuration panel (owner requirement).** The
   owner doesn't yet have a definitive list of their lights, so this panel
   is the main way the rig gets defined. The user must be able to:
   - create a fixture type from scratch: name, number of channels, and for
     each channel its **function** (intensity, red, green, blue, white,
     amber, UV, colour wheel, gobo, pan, pan fine, tilt, tilt fine, strobe,
     speed, macro, generic), its default value, and optional named value
     ranges (e.g. "0–9 open, 10–19 red");
   - duplicate or edit a type, or start from a built-in template (dimmer,
     RGB, RGBW, RGB+dimmer+strobe, moving head 8/16 ch);
   - add fixtures of a type, set the DMX address, name and (Console mode)
     the console scanner number 1–12. Auto-address with overlap warnings;
   - test a channel straight from the panel with a "touch" fader that
     outputs live when armed.
   **QLC+ `.qxf` import** is a later add-on to this panel (milestone 9).
3. **Programmer:** select fixtures, set intensity / colour (colour picker) /
   pan-tilt / strobe / raw channel values. Live output follows the
   programmer when output is armed.
4. **Snapshots (looks):** save the current programmer state; recall with a
   fade time.
5. **Effects:** parametric generators applied to a fixture selection:
   - intensity chase / wave / random sparkle
   - colour rainbow / colour chase between chosen colours
   - strobe
   - pan/tilt circle and figure-8 (moving heads)
   Parameters: speed (BPM or Hz), size, spread/phase across fixtures,
   direction. Tap-tempo BPM.
6. **Cue lists / chases:** ordered steps (snapshot + effects + fade + hold
   time or manual "GO"). Loop or one-shot.
7. **Live playback page:** a grid of buttons (snapshots, effects, cue lists,
   console scenes), grand master fader, **always-visible BLACKOUT**, tap
   tempo, GO / back for the active cue list.
8. **Preview:** a 2D stage view (see section 6) driven by the same 512-channel
   output the hardware gets.
9. **Console mode:** a console map of banks 1–15 × 8 scenes and chases 1–6,
   which the user can name, colour and attach notes to; buttons on the
   playback page fire them over MIDI (section 5).
10. **Console scene capture (optional hardware, deferred):** the owner's
    SH-RS09B cable can't read DMX, so this is the lowest priority. Only if
    a USB Pro-type adapter with DMX input is present, the app fires each console scene over MIDI,
    reads the console's DMX OUT, and stores the real channel values. The
    preview then shows console scenes accurately, and the captured looks
    can be reused as Direct-mode snapshots.
11. **Backup support:** a "Console cheat sheet" export (PDF/print) that
    lists, for chosen snapshots, the per-scanner fader values to program
    into the console by hand, so the backup holds the same key looks.
12. **Works without hardware:** Preview-only mode, plus a virtual MIDI
    output and a virtual DMX device for testing.
13. **Show files:** save/open/autosave; one file holds patch, profiles,
    snapshots, effects, cue lists, console map, stage plot.

## 3. Non-goals (v1)

- 3D visualiser (planned v2; keep the preview layer swappable).
- Art-Net / sACN network output (v2; keep the output layer abstract so it
  is one more driver).
- More than **one DMX universe**: the rig and console are single-universe.
- Uploading scenes *into* the console. MIDI can't, and the console's
  "file dump" between two units is an undocumented protocol.
- Timecode, audio-to-light beat detection, video.
- Windows/Linux, iPad.
- Using an external MIDI controller (faders/pads) to drive the app:
  **v1.1**, but design the action system so "MIDI learn" can be added
  without rewrite (every playback action addressable by an ID).

## 4. Anti-goals: failure even if it "works"

- **Output stutter or freeze during a show.** DMX output runs on its own
  real-time thread at a steady rate. UI work, file saving and the preview
  must never block it.
- **Blackout that is not instant or not obvious.** Blackout is one click /
  one key, always visible, and works in both modes.
- **Losing work.** Autosave plus crash-safe writes (write temp, then rename).
- **Surprise output.** Opening a show or switching modes never sends
  light changes until the user arms output. Arming is clearly shown.
- **Console-mode state lies.** The console gives no feedback (MIDI IN only)
  and scene notes *toggle*. The app must show its *believed* state honestly
  and offer a one-click "reset console" routine (section 5.4).
- **Toy UI.** It must be usable in a dark room: dark theme, large hit
  targets on the playback page, readable at a glance.

## 5. Console mode (MIDI) specifics

### 5.1 Verified console MIDI implementation

From the Stairville DMX Master I & II owner's manual, section 4-7. The
console **receives Note On only**:

| Note numbers | Function |
|---|---|
| 0–7 | toggle scenes 1–8 of bank 1 |
| 8n … 8n+7 | toggle scenes 1–8 of bank n+1 (n = 0…14) |
| 112–119 | toggle scenes 1–8 of bank 15 |
| 120–125 | toggle chases 1–6 |
| 126 | blackout |

- MIDI channel is set on the console (hold MIDI/Rec 3 s, Bank Up/Down to
  pick 1–16, hold MIDI/Rec 3 s to store). The app needs a matching setting.
- Banks 16–30 cannot be reached over MIDI.
- The console has **MIDI IN only**, so there is no feedback.

### 5.2 Must be verified on the real console (first hardware task)

The manual doesn't settle these. The builder writes a small **MIDI test
panel** in the app (send any note/velocity/channel) and the owner runs a
test script on the real console:

- Is velocity ignored? (Send 127; never 0, which MIDI treats as Note Off.)
- Does a following Note Off do anything? (Default: send Note Off ~50 ms
  later, then drop it if it causes trouble.)
- Does "blackout" (126) toggle, or only switch on?
- Can several scenes be on at once, and how do they combine (HTP)?
- Does a chase note stop other scenes?

Record the results in `docs/console-midi-findings.md` and set the app's
console behaviour from them. Until verified, use the defaults above.

### 5.3 Console map

- Grid of 15 banks × 8 scenes + 6 chases. Each cell has a name, colour, notes,
  an optional captured DMX frame (goal 10), and a "believed on/off" state.
- A **console look** = a set of cells to be on. Firing a console look
  sends only the toggles needed to get from the believed state to the
  target state.
- **Cues carry both modes** _(designer's call)_. Each cue has a
  *Direct part* (snapshot + effects) and an optional *Console part* (a
  console look that is its backup equivalent). The show runs in one active
  mode at a time, and playback uses the part that matches it. A cue
  without a part for the active mode is shown greyed out and skipped, and
  the playback page warns about it. When the operator switches to Console
  mode after a failure, the cue list stays on the same cue and carries on
  with the Console parts. That's the backup drill. The cue editor shows
  which cues still lack a Console part.

### 5.4 Console reset

Because state can drift (someone touches the console, a note is missed),
"Reset console" asks the user to press the console's own release /
blackout controls (the app shows instructions) and then marks every cell
off. The exact routine depends on findings in 5.2.

## 6. Preview

- **2D top-down stage plot.** The user drags fixtures onto a stage
  rectangle and can set stage size and a background image (a photo or plan
  of the venue).
- Each fixture is drawn as a glowing disc in its current colour and
  intensity. Moving heads also get a **beam line or cone** whose direction
  and length follow pan/tilt. Strobe flashes visually, capped at 10 Hz in
  the preview (photosensitivity).
- The preview reads **the same computed 512-byte frame** that goes to the
  hardware, so it shows what the lights will do. In Console mode it uses
  captured frames where they exist, or shows scene names on labelled tiles
  where they don't.
- Runs at display refresh rate, on the main/render thread, never on the DMX
  thread.
- A small **channel monitor** (512 cells with value bars) is available as a
  second preview tab for debugging.

## 7. Hardware

| Item | Decision |
|---|---|
| **Primary USB-DMX adapter (owner's choice)** | **DSD TECH SH-RS09B**, a USB-to-DMX cable with an FTDI chip and no processor. It works the same way as the Enttec **"Open DMX USB"**: the computer itself generates the DMX signal. This is the adapter the first Direct-mode release must work with. |
| Secondary adapter family | **Enttec DMX USB Pro widget protocol** (Enttec DMX USB Pro / Pro Mk2, DMXKing ultraDMX Micro / ultraDMX2 Pro). Lower priority. It's the only kind with DMX **input**, so goal 10 (capture) only works with one of these. |
| MIDI | Any class-compliant USB-MIDI cable/interface, via CoreMIDI. Connect its **MIDI OUT** to the console's **MIDI** socket. |
| Backup wiring | Fixtures' DMX cable goes from either the USB-DMX adapter or the console. On failure, move the cable to the console. A passive DMX A/B switch box is optional. |

Open DMX (FTDI, SH-RS09B) driver essentials:
- macOS's built-in FTDI driver exposes the cable as `/dev/cu.usbserial-*`.
  Open it with POSIX `open`/`termios`. Set **250000 baud** with the
  `IOSSIOSPEED` ioctl (termios can't express it), 8 data bits, no parity,
  **2 stop bits**, no flow control.
- Every frame: `ioctl(TIOCSBRK)`, hold the break **≥ 100 µs** (aim for
  ~110 µs), `ioctl(TIOCCBRK)`, wait ≥ 12 µs (mark after break), then write
  **start code `0x00` + 512 channel bytes**. Use `tcdrain` before the next
  break.
- Send a full 512 channels every frame at a **steady ~30–40 Hz** from the
  dedicated output thread, which gets real-time / high QoS priority.
  Users report flicker with this cable in other apps, which almost always
  comes from frame-timing jitter. Treat steady timing as the main quality
  bar.
- Fallback if the termios path proves unreliable on Apple Silicon:
  `libftdi1` over `libusb`. This needs detaching Apple's driver, so it's
  a last resort; record the decision in the repo.
- Device detection: match the FTDI USB vendor ID `0x0403` and let the user
  pick the port in Settings. Remember the choice.

USB Pro protocol essentials (for the secondary driver):
- Frame: `0x7E`, label, length LSB, length MSB, data…, `0xE7`.
- Send DMX: label **6**, data = start code `0x00` + up to 512 channel bytes.
- Receive: send label **8** with data `0x00` ("send always"), then read
  label **5** packets (status byte, start code, channel data).
- Output refresh: **~40 Hz** steady (configurable 25–44).

## 8. Architecture (builder may refine)

- **Language/UI:** Swift 6, SwiftUI with AppKit where needed, **macOS 14
  Sonoma or later**, Apple Silicon and Intel.
- **Modules** (Swift packages inside the Xcode project so they are
  unit-testable without UI):
  - `ShowModel`: fixtures, profiles, patch, snapshots, effects, cues,
    console map, stage plot. Codable.
  - `Engine`: each tick it merges programmer + running playbacks + effects
    into one 512-byte frame. Intensity merges HTP, everything else LTP
    (latest wins). Grand master and blackout are applied last.
  - `Effects`: pure functions `(time, fixtureIndex, params) → values`.
  - `Outputs`: a protocol `DMXOutput` with drivers `OpenDMXOutput` (FTDI serial, primary), `EnttecProOutput`,
    `VirtualDMXOutput` (records frames, for tests and preview-only), and
    later Art-Net. `ConsoleMIDIOutput` (CoreMIDI) plus a virtual MIDI
    destination for tests.
  - `Inputs`: `EnttecProInput` for capture.
  - `Fixtures`: built-in profiles and the QLC+ `.qxf` importer.
  - App/UI: patch, stage plot editor, programmer, snapshot/effect/cue
    editors, playback page, console map, settings.
- **Timing:** engine and DMX output on a dedicated high-priority thread or
  dispatch source. The UI talks to the engine through a lock-free or
  actor-guarded command queue. The preview reads the latest frame snapshot.
- **Show file:** a `.dmxshow` document package (JSON plus a background
  image), via `DocumentGroup` or `NSDocument`. Autosave plus versions.
- **Device hot-plug:** detect the adapter and MIDI interface appearing or
  disappearing, show the status in the toolbar, and reconnect automatically.
  When the adapter disappears, show a loud on-screen alert ("DMX adapter
  lost: switch to console backup").

## 9. Screens

1. **Patch**: table of fixtures (name, profile, address, mode) plus an
   "add fixtures" sheet (profile, count, start address, auto-addressing).
   Warns on address overlap or past 512.
2. **Stage**: the 2D preview and stage-plot editor (drag fixtures, select
   by lasso).
3. **Programmer**: selection, intensity, colour picker, pan/tilt pad,
   strobe, raw-channel faders, and "record as snapshot".
4. **Library**: snapshots, effects, cue lists (create, edit, duplicate,
   colour, name).
5. **Playback** (show mode): a button grid of pages, grand master, blackout,
   tap tempo, cue list GO/back, current-cue display.
6. **Console**: the bank/scene/chase map, capture wizard, console looks,
   MIDI channel setting, MIDI test panel, cheat-sheet export.
7. **Settings / Devices**: output mode, adapter selection, refresh rate,
   MIDI port and channel, arm output.

Keyboard: Space = GO, B = blackout (toggle), Esc = clear programmer,
number keys = playback page buttons.

## 10. Testing (important for an agent team)

- All `ShowModel`, `Engine`, `Effects` and `Fixtures` code is unit tested
  with no hardware.
- The engine is tested with golden frames: a given show, time and inputs
  must produce an exact 512-byte output.
- The USB Pro protocol encoding and decoding is tested against byte
  fixtures.
- The QLC+ importer is tested with a handful of real `.qxf` files
  committed as fixtures.
- Console MIDI is tested against a virtual CoreMIDI destination: assert
  the exact notes sent for a console look change.
- UI smoke tests (XCUITest) for patch → programmer → snapshot → playback
  in preview-only mode.
- **Hardware acceptance checklist** (`docs/hardware-test.md`), run by the
  owner: adapter output, capture, console MIDI findings, cable-swap
  backup drill.

## 11. Milestones (suggested order)

1. Show model, **fixture & channel config panel** (goal 2), built-in
   templates, patch, virtual output, channel monitor.
2. **Console mode first pass** _(designer's call: it needs only a USB-MIDI
   cable, so the owner can use the app on the real console early)_: MIDI
   output, MIDI test panel, console map, playback buttons for console
   scenes/chases/blackout, and the findings session on the real console
   (5.2).
3. Engine, programmer, 2D stage preview.
4. Snapshots with fades, playback page, blackout/grand master.
5. **Open DMX (SH-RS09B) output driver**, device status, arming, and a
   flicker check on the real cable.
6. Effects and tap tempo.
7. Cue lists and chases, including the two-part cues (5.3) and console
   looks.
8. Capture wizard (DMX input) and cheat-sheet export.
9. QLC+ import, Enttec Pro driver, autosave hardening, polish, hardware
   acceptance.

The owner can use Console mode on real gear after milestone 2, and Direct
mode after milestone 5. If the rig has no moving heads, pan/tilt effects
and beam cones can move to the end.

## 12. Constraints and facts to respect

- Single DMX universe (512 channels).
- Console: 12 scanners × 16 channels. By convention scanner *n* uses DMX
  addresses 16(n−1)+1 … 16n (1–192). The owner described the console as
  "banks A and B, 16 fixtures each", which doesn't match the manual. See
  open questions.
- Console MIDI can reach banks 1–15 only.
- No Apple developer account is assumed. Distribute a locally signed build
  first; notarisation is optional later.

## 13. Left to the builder

- Exact SwiftUI layout, styling and icons (dark, high contrast, big
  playback buttons).
- Internal threading primitives, file-format details beyond "JSON in a
  package, versioned".
- The effect parameter curves and defaults.
- Whether the preview uses SwiftUI Canvas, Metal or SpriteKit, as long as
  it stays smooth with 50 fixtures.

## 14. Open questions for the owner

Answered by the owner on 2026-11-02:

1. **Console:** DMX Master II, 12 fixtures ("I think"; confirm by looking
   at the console during the milestone 2 findings session). The fixture
   list is **not known yet**, so the app must let the owner configure
   fixtures and channels themselves (goal 2).
2. **Adapter:** the owner is buying a **DSD TECH SH-RS09B** (FTDI,
   Open-DMX style, output only). It's the primary Direct-mode device. Enttec
   Pro support is secondary, and capture is deferred.
3. **Deadline:** "ASAP", with no fixed date. Build order puts usable
   features first: Console mode (milestone 2), then Direct mode with the
   config panel, programmer, preview and snapshots (milestones 3–5). Cut
   or defer first, in this order: capture wizard, QLC+ import, cheat-sheet
   export, Enttec Pro driver, pan/tilt shape effects.

## 15. Calls made by the designer (not yet confirmed by the owner)

- Native Swift/SwiftUI app, macOS 14+.
- Open DMX driver built on the macOS serial port (termios + IOSSIOSPEED +
  break ioctls) rather than libftdi, with libftdi as the fallback.
- Two-part cues (Direct part + Console part) as the backup mechanism.
- Console mode moved early in the build order.
- 2D preview in v1, 3D later.
- QLC+ fixture import instead of building a big fixture library.
- External MIDI controller support deferred to v1.1.
- Backup = manual cable swap plus a printed cheat sheet.
