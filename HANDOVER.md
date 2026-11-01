# DMX Bridge: Handover for the Agent Team

A native macOS app for controlling stage lights. It works two ways:

- **Direct:** Mac → USB-DMX cable → lights. Full control of every channel.
- **Console:** Mac → USB-MIDI cable → Stairville DMX Master II console. Fires its stored scenes, chases and blackout.

You can program in the app with a 2D stage preview. The console stays in the rack as the backup if the Mac or adapter fails.

**Nothing is built yet.** This repo has only documentation.

---

## 1. Read in this order

| # | Document | What it is |
|---|---|---|
| 1 | `docs/superpowers/specs/2026-11-02-dmx-light-app-design.md` | **The design.** Intent, goals, non-goals, anti-goals, verified console MIDI map, hardware, architecture, screens. The source of truth: if a plan disagrees with it, the design wins. Flag the conflict. |
| 2 | `docs/superpowers/plans/2026-11-02-plan-1-foundation-and-console-mode.md` | Setup, fixture & channel config panel, MIDI console control. |
| 3 | `docs/superpowers/plans/2026-11-02-plan-2-direct-dmx-preview-snapshots.md` | Engine, SH-RS09B (Open DMX) driver, programmer, stage preview, snapshots, playback page. |
| 4 | `docs/superpowers/plans/2026-11-02-plan-3-effects-and-cue-lists.md` | Effects, tap tempo, cue lists with console backup parts. |
| 5 | `docs/superpowers/plans/2026-11-02-plan-4-extras-and-hardening.md` | Cheat sheet, QLC+ import, Enttec Pro + capture, hardening, release, user guide. |

Plans run **strictly in order**. Each plan's tasks run in order too. Each task's **Interfaces** block names exactly what it consumes from earlier tasks and what it produces for later ones. Keep those names and signatures; later plans depend on them.

## 2. How to run the work

- Execute each plan with **`superpowers:subagent-driven-development`**: one implementer agent per task, a fresh reviewer agent after each task, and a whole-branch review at the end of each plan.
- Work on a branch per plan (`plan-1-foundation`, `plan-2-direct-dmx`, …) and merge to `main` when the plan's "Done" line holds and all tests pass.
- **TDD is mandatory.** Every task starts with its failing test exactly as written in the plan.
- **One commit per task**, using the message given in the plan.
- Each plan has a **Review Focus** list. Reviewers must check those specifically.
- If a task can't be done as written (an API doesn't exist, a test is impossible), stop and record why in `docs/decisions.md`. Don't silently redesign.

### Build and test commands

```bash
brew install xcodegen
```

```bash
xcodegen generate
```

```bash
swift test --package-path Packages/DMXCore
```

```bash
xcodebuild test -scheme DMXBridge -destination 'platform=macOS'
```

## 3. What needs the owner (humans in the loop)

Agents can do everything with virtual devices **except** these. Pause and ask the owner when you reach them:

| When | What the owner does | Where results go |
|---|---|---|
| End of Plan 1 | Run hardware test part 1 on the real console: fire scenes over MIDI and answer the open MIDI questions | `docs/console-midi-findings.md` |
| End of Plan 2 | Hardware test part 2: SH-RS09B output, **flicker check**, unplug test, backup cable-swap drill | `docs/hardware-test.md` |
| End of Plan 3 | Hardware test part 3: cue list backup drill | `docs/hardware-test.md` |
| End of Plan 4 | Full acceptance on the release build, 60-minute soak test | `docs/hardware-test.md` |

**After the Plan 1 findings session, update `ConsoleController` defaults** (Note Off on/off, blackout behaviour) to match what the console actually does.

## 4. Hardware shopping list (owner)

| Item | Suggested | Approx. price (thomann.ro / eMAG, Nov 2026) |
|---|---|---|
| USB → DMX cable | **DSD TECH SH-RS09B** (FTDI, Open DMX type, output only) | check eMAG |
| USB → MIDI cable | **Miditech MIDILink Mini** (or CME C2MIDI Pro for USB-C) | ~76 lei (~139 lei) |
| DMX cable | 3-pin XLR **DMX** cable from the adapter to the first fixture | — |
| Optional, later | Enttec DMX USB Pro, only if flicker appears or scene capture is wanted | ~939 lei |

Wiring:
- The MIDI cable's **OUT** plug goes into the console's **MIDI** socket.
- In Direct mode, the SH-RS09B's XLR goes into the first fixture's DMX IN.
- In backup, that same DMX lead goes into the console's **DMX OUT** instead.

## 5. Key facts agents must not get wrong

- The console's MIDI **only toggles stored things**: Note On 0–119 = bank 1–15 scenes 1–8, 120–125 = chases 1–6, 126 = blackout. Velocity 127, **never 0**. There's no feedback (MIDI IN only), so the app tracks a *believed* state.
- The console has 12 scanners × 16 channels. Scanner *n* sits at DMX address 16(n−1)+1. Its faders show channels 1–8 (page A) and 9–16 (page B).
- The SH-RS09B has no processor. The Mac makes the DMX timing itself: 250000 baud, 8N2, break ≥ 100 µs, start code 0 + 512 bytes, a steady ~30 Hz loop on its own thread. **Steady timing is the quality bar; jitter causes flicker.**
- **Nothing is ever sent until the user arms output.** Blackout is always one key away (B).

## 6. Glossary for agents new to lighting

- **DMX:** the cable protocol for lights. One "universe" = 512 channels, each 0–255.
- **Fixture:** one light. It uses a block of consecutive channels starting at its **address**.
- **Fixture type / profile:** what each of a fixture's channels does (dimmer, red, pan…).
- **Patch:** which fixtures exist and at which addresses.
- **Snapshot / look / scene:** stored channel values for some fixtures.
- **Programmer:** the scratch area where the operator builds a look before saving it.
- **HTP / LTP:** "highest takes precedence" (used for intensity: the brightest source wins) and "latest takes precedence" (used for colour, position and so on: the newest source wins).
- **Grand master:** the overall brightness fader.
- **Cue list:** an ordered sequence of looks that the operator steps through with **GO**.
- **Chase:** a cue list that steps automatically.
- **Pan/tilt:** horizontal/vertical movement of a moving head, often with a **fine** channel for 16-bit precision.

## 7. Future (not in v1)

External MIDI controller with MIDI learn, Art-Net/sACN, 3D preview. Write a new spec before starting any of these.
