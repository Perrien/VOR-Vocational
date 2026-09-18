# Cockpit And App Shell — Part 1: Free Flight Flight Deck

Status: **APPROVED 2026-09-18**

## Parts

**For the owner and the next authoring session — not for the executor.**

1. `Cockpit-And-App-Shell-1-Free-Flight-Flight-Deck` — direct-launch reusable Free Flight flight deck: session, cockpit, radios, Chart controls, and Debug diagnostics. ← this part
2. `Cockpit-And-App-Shell-2-Mode-Navigation` — Home, Mode catalogs, Position Challenge entry, and navigation into the shipped flight deck.

| Exploration ID | Part |
|---|---:|
| S1–S5 | 2 |
| S6 | 1 |
| I1–I8 | 1 |
| U1–U7 | 2 |
| U8–U25 | 1 |

## Context

V0.2 first ships a directly launched Free Flight flight deck so cockpit and radio work can be tested without navigating through the future Mode shell. Part 2 will replace that direct launch with Home and catalog navigation after this flight deck has shipped.

Today `ContentView` renders only `MapView` at `Xcode Proj/VOR Vocational/App/ContentView.swift:10-13` (`struct ContentView: View { … MapView() }`). `MapView` owns the aircraft, receiver, camera, layer, and challenge state locally at `Xcode Proj/VOR Vocational/Features/Map/MapView.swift:15-68` (`@State private var planePosition`, `nav1Ident`, `nav2Ident`, `heading`, `timeMultiplier`, and layer flags), then lays out a right control panel beside a fixed-height bottom panel at `MapView.swift:82-157` (`HStack(spacing: 0)`, `MapControlPanel(...)`). The current bottom panel is already wired to `PlaneControlView` and two `NavRadioView` instances at `MapView.swift:112-136`.

The existing map preserves normalized content coordinates through `FlatMap.point(for:in:)` and `FlatMap.sourcePosition(for:in:)` at `Xcode Proj/VOR Vocational/Features/Map/OverlayViews.swift:44-60`; keep the new flight session's aircraft position in this normalized source space. `FlightTimerView` currently turns map-space movement into `FlightPhysics.advance` at `MapView.swift:503-513`, and must retain that physics. VOR stations already have `frequency`, `relativePosition`, and `rangeNM` at `Xcode Proj/VOR Vocational/Domain/Models.swift:50-74`; existing reception is identifier-based and range-gated at `MapView.swift:424-432`. Midland Cityport is bundled as airport `GPMC` at `Xcode Proj/VOR Vocational/Content/Airports.json:24-28` (`"x": 0.5067`, `"y": 0.6889`).

The test target already tests pure navigation and flight movement in `Xcode Proj/VORVocationalTests/NavigationCoreTests.swift:5-208` (`final class NavigationCoreTests: XCTestCase`). Use that target for the pure channel, swap, and fresh-session tests in this part.

## Decisions (2026-09-18)

| # | Decision |
|---|---|
| S6 | Free Flight retains all current flight and chart functionality in a reorganized interface, with frequency-tuned NAV radios, because V0.2 is a functional cleanup rather than a mock-up. *(Amended 2026-09-18 — tuning input reverted to a typed ident field rather than physical knobs; see the T4 note.)* |
| I1 | Free Flight is the reusable baseline flight surface; future Missions layer route planning and other mission-only behavior around it, because common cockpit behavior must not become conditional by Mode. |
| I2 | A new Free Flight entry creates a fresh, non-resumable session, because resume rules belong to a future Mission design. |
| I3 | Extract the reusable flight surface from the current `MapView` and give Free Flight a thin direct-launch wrapper, because future Mission panels must not be switches inside one all-purpose screen. |
| I4 | NAV receivers tune 108.00–117.95 MHz in 0.05 MHz channels; the selected frequency always displays, while received ident and CDI data appear only in range. |
| I5 | ~~Use separate physical-looking whole-MHz and fine 0.05-MHz knobs, because they provide a realistic coarse/fine interaction without nested hit targets.~~ **Superseded 2026-09-18:** the knob interaction proved fiddly in practice; NAV radios tune by typing a station's ident instead. See the T4 note. |
| I6 | ~~Whole-MHz tuning stops at 108 and 117; fine tuning wraps .00–.95 without carrying, because the two knobs stay independent.~~ **Superseded 2026-09-18:** no longer user-facing (no knobs); the underlying `adjustWhole`/`adjustFine` clamp/wrap rules still hold in `NAVReceiver` and remain tested. |
| I7 | Each flight wrapper creates one per-flight session object, and the reusable surface operates on it, because Mode boundaries own their own flight state. |
| I8 | A dedicated NAV1 ↔ NAV2 control exchanges active frequencies and OBS settings only, because it supports receiver handoff without altering aircraft state. |
| U8 | Put the chart above a bottom-docked cockpit with equal heading, NAV1, and NAV2 bays; enforce a 1100 × 760 point minimum window and clamp their shared visual scale to 0.80×...1.00× instead of a compact reflow. |
| U9 | Render the cockpit as one continuous dark panel with subtle bay dividers, because it should read as one aircraft cockpit rather than dashboard cards. |
| U10 | Keep playback speed in the normal heading bay, because it is a routine flying control. |
| U11 | Each bay is a vertical stack with a primary dial above a horizontal lower control row, because the cockpit needs a repeatable visual hierarchy. |
| U12 | The Heading Indicator is the complete black compass display; its lower-row Heading Knob replaces the paired hold-turn buttons and turns left to decrease/right to increase heading. |
| U13 | Put Play/Pause with airspeed, playback, and the Heading Knob in the heading bay's lower row. |
| U14 | ~~Each NAV bay places the CDI-style VOR Indicator above a lower Radio Panel, with its OBS Dial at the indicator's lower-left.~~ **Superseded 2026-09-18:** OBS is set by dragging the VOR Indicator directly; there is no separate OBS Dial. See the T4 note. |
| U15 | Standardize both NAV bays on the CDI-style VOR Indicator; do not expose the current HSI alternative in V0.2. |
| U16 | ~~Each Radio Panel contains selected frequency, received ident, and paired tuning knobs; the OBS Dial remains attached to its VOR Indicator.~~ **Superseded 2026-09-18:** the Radio Panel is the receiver label, an editable ident field, and the tuned frequency only — no tuning knobs, no separate OBS Dial. See the T4 note. |
| U17 | Fresh Free Flight starts both receivers at 108.00 MHz with no received identifier, because tuning is a deliberate first action. |
| U18 | Fresh Free Flight starts paused at Midland Cityport, heading 000°, and 260 knots. |
| U19 | Fresh Free Flight starts both OBS Dials at 000°. |
| U20 | Chart contains player-facing VOR/service filters, airports, radials, grid/grid scale, and sightseeing layers; Flight Diagnostics owns true position, reception/signal data, and editable CDI scale. |
| U21 | Open Chart from a small persistent Liquid Glass Chart button in the chart's upper-right. |
| U22 | Do not add custom Preferences in V0.2, because all chart and flight choices are per-session. |
| U23 | Flight Diagnostics exists only in Debug builds and opens from the Debug menu, because simulation truth must not enter normal play. |
| U24 | Flight Diagnostics live-updates read-only position and receiver/signal values; CDI scale is its only editable control. |
| U25 | Enforce a primary-window minimum of 1100 × 760 points, because all three cockpit bays must remain usable together. |

## Tickets closed by this plan

- none — the exploration folded in no tickets.

## Prefactoring

**None needed.** The current `MapView` state is inseparable from the behavior being changed: it stores station identifiers rather than frequencies and starts at the chart centre rather than Midland Cityport. A behavior-preserving extraction would be immediately invalidated. Task 1 instead establishes the exact pure frequency and session rules before any SwiftUI wiring changes.

## Approach

Build the direct-launch flight deck in five layers: exact receiver/session state, a reusable map-and-flight surface, a physical cockpit, player-facing Chart controls, and Debug-only diagnostics. Part 1 deliberately leaves `ContentView` launching Free Flight so the owner can test every cockpit change without a Mode-selection detour. Part 2 replaces that launch with the final app shell.

### 1. New: `Xcode Proj/VOR Vocational/Features/Flight/FlightSession.swift`

Create the `@Observable` per-flight state object and the pure receiver value type. Import `Observation` for the observable types. Keep all stored radio channels as integers in hundredths of MHz: valid whole MHz are `108...117`, fine steps are `0...19`, and `frequencyHundredths` is `wholeMHz * 100 + fineStep * 5`. Format the displayed value with exactly two decimal places. Never store a `Double` channel or a station identifier in the session.

`NAVReceiver` contains `wholeMHz`, `fineStep`, and `obs`. Its initial value is `108`, `0`, `0`. `adjustWhole(by:)` clamps to `108...117`; `adjustFine(by:)` wraps modulo 20 and never changes `wholeMHz`; `adjustOBS(by:)` wraps to `0..<360`. A receiver is equatable so the tests can compare it after a swap.

`FlightSession` owns `normalizedAircraftPosition`, `heading`, `speedKnots`, `isFlying`, `timeMultiplier`, two receivers, chart zoom/pan/layer state, selected VOR, and `cdiMax`. Its Free Flight initializer receives a normalized airport position and sets exactly: Midland Cityport position, heading `0`, speed `260`, paused, multiplier `1`, both receivers `108.00` and OBS `000°`, zoom `1`, pan `.zero`, all current map layers visible except grid and sightseeing regions, and grid size `50 NM`. Its `swapNAVReceivers()` exchanges the complete receiver values and nothing else.

Create a lightweight observable `FlightDiagnosticsStore` in the same file. It holds the active `FlightSession?` for the Debug-only scene; it is only a registry and must not duplicate flight state or persist it.

### 2. `Xcode Proj/VOR Vocational/Domain/Models.swift` and `Xcode Proj/VOR Vocational/Domain/Navigation/VORNavigation.swift`

Add `Airport.myosia`, matching the existing `VORStation.myosia` loading convention at `Models.swift:77-95`, so production code resolves `GPMC` from bundled data instead of copying its coordinate. In the direct-launch wrapper, require exactly one airport with `icao == "GPMC"`; use `preconditionFailure("Midland Cityport (GPMC) is missing from Airports.json")` if that data contract is broken.

Add a pure `VORNavigation.station(withFrequencyHundredths:in:) -> VORStation?`. It compares `Int((station.frequency * 100).rounded())` with the integer channel and returns the matching station regardless of current range. Also add one pure `receiverReading` helper that accepts a receiver frequency and OBS, normalized aircraft position, station list, map width/height in NM, and `cdiMax`; it returns the in-range matching station and its CDI reading, or no station with the existing NAV-flag reading. Convert normalized points to NM using the supplied map dimensions before calling the existing `cdiReading` geometry. `MapView` and Flight Diagnostics must both call this helper. Keep `station(withIdent:in:)` unchanged for later code; this part removes its Free Flight call sites but does not delete it.

### 3. New: `Xcode Proj/VOR Vocational/Features/Flight/FreeFlightView.swift`; edit `ContentView.swift`, `VORVocationalApp.swift`, and `MapView.swift`

`FreeFlightView` owns `@State` session state constructed exactly once for its current view identity from `Airport.myosia`, and registers that session in `FlightDiagnosticsStore` while visible. Part 2 must create a new `FreeFlightView` identity on every entry, giving every entry a fresh session. It is the direct Part 1 launch surface; do not add a Home button or Mode routing here. `ContentView` renders `FreeFlightView` during this part and keeps the preview at `1100 × 760` points.

Change the main window content to enforce a minimum `1100 × 760` point size. In Debug builds only, add a second, separately openable `Flight Diagnostics` window and a `Debug` menu command that opens it. Inject the same `FlightDiagnosticsStore` into both scenes. Do not alter signing, targets, deployment settings, or the project file by hand.

Refactor `MapView` into the reusable flight surface that accepts a `FlightSession` rather than declaring flight state. Keep its map projection, zoom/pan mechanics, overlays, plane drag, and `FlightPhysics.advance` integration. Convert the session's normalized position to map space with `FlatMap.point(for:in:)` before drawing or advancing; convert the result back through `FlatMap.sourcePosition(for:in:)` before writing it to the session. Replace identifier reception at `MapView.swift:424-432` with `VORNavigation.receiverReading`, passing the map's physical dimensions so its in-range result and CDI are the sole values rendered by the indicators and exposed to diagnostics. In Part 1, remove Position Challenge controls and challenge-specific reference-position behavior from the map surface, but leave `PositionChallenge.swift` and its tests untouched for Part 2.

### 4. `Xcode Proj/VOR Vocational/Features/Flight/PlaneControls.swift`

Replace `PlaneControlView` and `NavRadioView` with the three equal flight-deck bays. Size the complete cockpit with one shared `GeometryReader` scale factor clamped to `0.80...1.00`; at the `1100 × 760` minimum the bays use `0.80`, and they grow together only to `1.00`. The heading bay has the existing `HeadingIndicator` on top; its lower row contains editable airspeed, playback picker (`1×`, `5×`, `10×`, `30×`), Play/Pause, and one physical-looking Heading Knob. Remove `HoldTurnButton`; use the current circular-drag pattern from `OBSInstrument.rotationDrag` at `PlaneControls.swift:661-678` for the Heading Knob, rounding its accumulated delta to whole degrees so left lowers the wrapped heading and right raises it.

Both NAV bays use `OBSInstrument` as the fixed CDI-style VOR Indicator only. Delete `NavigationInstrumentStyle`, `HSIInstrument`, and the display picker; the VOR Indicator shows the current CDI/TO-FROM or the existing red `NAV` flag when no station is received. Give each indicator a separate OBS Dial at its lower-left; use the same circular drag behavior to change only that receiver's wrapped OBS. Use circular drag for the two paired frequency knobs as well: clockwise adds one whole-MHz or one fine step, counter-clockwise subtracts one; a drag must not affect the other receiver or OBS.

Below each indicator, render a Radio Panel with the exact two-decimal selected frequency, received ident or `---`, the paired whole-MHz/fine knobs, and its receiver label. The knobs operate the `NAVReceiver` methods from `FlightSession`. Add one dedicated NAV1 ↔ NAV2 control between the NAV bays; it calls `swapNAVReceivers()` and has no other side effect.

### 5. New: `Xcode Proj/VOR Vocational/Features/Map/ChartPopover.swift` and `Xcode Proj/VOR Vocational/Features/Flight/FlightDiagnosticsView.swift`

Replace the right-side `MapControlPanel` with a compact Chart popover opened by a small persistent Liquid Glass `Chart` button at the chart's upper-right. It owns only the existing player-facing controls: VOR visibility, each service-volume filter, airports, selected radials, grid plus grid size, and sightseeing regions. Retain scroll-wheel zoom and map panning; do not add a Chart zoom slider.

`FlightDiagnosticsView` is compiled only in Debug. When no active session exists, show that no Free Flight session is active. Otherwise display live normalized aircraft position, each receiver's selected frequency, received identifier or no reception, current OBS, and CDI reading. Expose `cdiMax` as the only editable field. Do not duplicate any flight calculation: the view reads the active `FlightSession` and calls the shared `VORNavigation.receiverReading` helper with the same Myosia dimensions used by the flight surface.

### 6. `Xcode Proj/VORVocationalTests/NavigationCoreTests.swift`

Add pure tests for whole-MHz clamping at 108/117, fine-step wrapping `.00 ↔ .95` without carry, two-decimal formatting, frequency-based station lookup, session defaults from a supplied Midland position, and swap behavior. Preserve every existing navigation, flight-physics, position-challenge, and service-volume test unchanged.

## Tasks

| # | Task | Status | Then | Commit | Note |
|---|---|---|---|---|---|
| T1 | Add pure receiver, session, and frequency lookup rules with tests | completed | checkpoint | — | |
| T2 | Extract the direct-launch reusable Free Flight surface | completed | **owner stop** | commit | |
| T3 | Build the three-bay physical cockpit and heading controls | completed | **owner stop** | commit | |
| T4 | Add frequency radios, OBS Dials, and NAV swap | completed | **owner stop** | commit | |
| T5 | Replace the map panel with Chart and Debug diagnostics | awaiting owner | **owner stop** | commit + push | |
| T6 | Close out Part 1 | not started | continue | — | |

**T1 — Add pure receiver, session, and frequency lookup rules with tests**

- **Files:** `Xcode Proj/VOR Vocational/Features/Flight/FlightSession.swift` (new; add to the app target through Xcode), `Xcode Proj/VOR Vocational/Domain/Models.swift` (edit), `Xcode Proj/VOR Vocational/Domain/Navigation/VORNavigation.swift` (edit), `Xcode Proj/VORVocationalTests/NavigationCoreTests.swift` (edit).
- **Done when:**
  - `NAVReceiver` stores `wholeMHz`, `fineStep`, and `obs` as described in Approach §1; no production code stores an identifier or a floating-point frequency channel.
  - Tests named `testNAVReceiverWholeMHzClamps`, `testNAVReceiverFineStepWrapsWithoutCarry`, `testNAVReceiverFormatsFrequency`, `testStationLookupByFrequency`, `testFrequencyReceiverReadingRespectsRange`, `testFreshFlightSessionDefaults`, and `testNAVReceiverSwap` pass alongside every pre-existing test.
  - `Airport.myosia` loads the unchanged bundled airport data; `VORNavigation.station(withFrequencyHundredths:in:)` returns a matching station without applying reception range; and `receiverReading` applies the station's range before returning an active CDI result.
  - Run the project gates required by the protocol for this app-code and test change.
- **Do not:** edit `Airports.json`, `VORStations.json`, `FlightPhysics`, `PositionChallenge`, existing test tolerances, or the Xcode project file by hand.

**T2 — Extract the direct-launch reusable Free Flight surface**

- **Files:** `Xcode Proj/VOR Vocational/Features/Flight/FreeFlightView.swift` (new; add to the app target through Xcode), `Xcode Proj/VOR Vocational/App/ContentView.swift` (edit), `Xcode Proj/VOR Vocational/App/VORVocationalApp.swift` (edit), `Xcode Proj/VOR Vocational/Features/Map/MapView.swift` (edit), `Xcode Proj/VORVocationalTests/NavigationCoreTests.swift` (edit only if a pure conversion/helper test is needed).
- **Done when:**
  - `ContentView` launches `FreeFlightView` directly; do not add Home, lists, or Mode routing in this part.
  - `FreeFlightView` resolves the unique bundled `GPMC` airport and its `@State` state creates exactly one `FlightSession` with that normalized coordinate per Free Flight view identity; Part 2 creates a new identity on each entry.
  - `MapView` receives that session instead of declaring aircraft, receiver, camera, layer, or CDI state itself; its plane drag, pan, scroll-wheel zoom, overlays, radial drawing, and `FlightPhysics.advance` behavior still work through normalized source coordinates.
  - The Position Challenge panel and challenge-specific reference-position code no longer appear in the direct Free Flight surface; `PositionChallenge.swift` and its existing tests remain unchanged.
  - Run the project gates required by the protocol.
- **Do not:** alter flight-movement formulas at `Xcode Proj/VOR Vocational/Domain/Simulation/FlightPhysics.swift:11-26` (`static func advance(...)`), add Mode navigation, remove Position Challenge domain code, or change bundled coordinates.
- **Verification handle** — permanent:
  - **Where:** launch the app; direct Free Flight remains the only initial screen in Part 1, and Midland Cityport (`GPMC`) is already drawn on the chart.
  - **Positive:** drag the aircraft marker away from Midland Cityport, close the app window, then launch a new Free Flight view → the marker begins again at Midland Cityport, paused, rather than at the dragged position.
  - **Negative:** pan or zoom the chart, then drag the aircraft → panning/zooming must not move the aircraft until the aircraft marker itself is dragged.
  - **Reads:** `FlightSession.normalizedAircraftPosition` in `Xcode Proj/VOR Vocational/Features/Flight/FlightSession.swift` through `MapView`'s `FlatMap.point(for:in:)` rendering path.
- **Commit point:**

```text
cockpit-flight-deck T2: extract reusable Free Flight session

- launch a fresh session at Midland Cityport
- keep map interaction and flight physics on normalized coordinates
```

**T3 — Build the three-bay physical cockpit and heading controls**

- **Files:** `Xcode Proj/VOR Vocational/Features/Flight/PlaneControls.swift` (edit), `Xcode Proj/VOR Vocational/Features/Map/MapView.swift` (edit), `Xcode Proj/VOR Vocational/Features/Flight/FlightSession.swift` (edit only if bindings require a computed property), `Xcode Proj/VOR Vocational/App/VORVocationalApp.swift` (edit).
- **Done when:**
  - The chart is above one continuous dark bottom cockpit with subtle dividers and three equal bays in the fixed order Heading, NAV1, NAV2.
  - The complete cockpit scales with one factor clamped to `0.80...1.00`, and the primary window cannot shrink below `1100 × 760` points.
  - The heading bay contains `HeadingIndicator` above its lower row: airspeed, playback (`1×`, `5×`, `10×`, `30×`), Play/Pause, and one Heading Knob.
  - `HoldTurnButton` and both paired heading buttons are deleted. A left circular drag on the Heading Knob decreases heading; a right circular drag increases it; heading remains wrapped into `0..<360`.
  - Both NAV bays show the existing CDI-style indicator only. `NavigationInstrumentStyle`, `HSIInstrument`, and the navigation-display picker are removed from production code.
  - Run the project gates required by the protocol.
- **Do not:** change CDI geometry or TO/FROM logic in `Xcode Proj/VOR Vocational/Domain/Navigation/VORNavigation.swift:19-43` (`static func cdiReading(...)`), add Chart controls, or add a Home control before Part 2.
- **Material alteration:** the owner asked at this task's stop point to keep `HSIInstrument`'s drawing code rather than delete it outright, since a later part will reintroduce an HSI display option. `HSIInstrument` remains in `PlaneControls.swift` as a self-contained, unreferenced view — not wired into any bay. `NavigationInstrumentStyle` and the navigation-display picker are still deleted; only the drawing struct itself was kept.
- **Verification handle** — permanent:
  - **Where:** launch direct Free Flight and use the heading bay in the bottom cockpit.
  - **Positive:** rotate the Heading Knob right from `000°` → the Heading Indicator advances clockwise and, after Play, the aircraft travels eastward on the chart; rotate it left → the displayed heading decreases.
  - **Negative:** change playback from `1×` to `5×` → the airspeed field remains `260` knots; playback changes simulated movement rate only.
  - **Reads:** `FlightSession.heading`, `speedKnots`, and `timeMultiplier` in `Xcode Proj/VOR Vocational/Features/Flight/FlightSession.swift` through `HeadingIndicator` and `FlightTimerView`.
- **Commit point:**

```text
cockpit-flight-deck T3: build the three-bay flight cockpit

- replace independent cards with one scaled cockpit panel
- add the physical heading controls and CDI-only instrument bays
```

**T4 — Add frequency radios, OBS Dials, and NAV swap**

- **Files:** `Xcode Proj/VOR Vocational/Features/Flight/PlaneControls.swift` (edit), `Xcode Proj/VOR Vocational/Features/Map/MapView.swift` (edit), `Xcode Proj/VOR Vocational/Features/Flight/FlightSession.swift` (edit), `Xcode Proj/VOR Vocational/Domain/Navigation/VORNavigation.swift` (edit only if a pure helper needs correction), `Xcode Proj/VORVocationalTests/NavigationCoreTests.swift` (edit).
- **Done when:**
  - ~~Each Radio Panel displays its receiver label, selected two-decimal frequency, received ident or `---`, paired whole/fine knobs, and a separate OBS Dial attached to its VOR Indicator.~~ **Amended 2026-09-18:** each Radio Panel displays its receiver label, an editable ident field, and the tuned frequency only — no tuning knobs, no separate OBS Dial. See the note below.
  - NAV1 and NAV2 begin at `108.00` with no ident entered and OBS `000°`. Typing a station's ident into the Radio Panel tunes that receiver's frequency to match and turns the frequency green; an unmatched or partial ident leaves the frequency unchanged and in its normal color. Reception (live CDI/TO-FROM vs. the red NAV flag) still depends on range, unchanged from T1.
  - ~~Whole knobs clamp at 108/117; fine knobs wrap `.00...95` in 0.05 MHz steps without changing the whole MHz. Clockwise and counter-clockwise circular drags obey those rules.~~ **Amended 2026-09-18:** no longer user-facing; `NAVReceiver.adjustWhole`/`adjustFine` still hold these rules and remain tested, but nothing in the UI calls them.
  - The NAV1 ↔ NAV2 control swaps complete receiver values (frequency and OBS) and leaves normalized aircraft position, heading, speed, play state, multiplier, camera, layers, selection, and CDI scale unchanged.
  - OBS is set by dragging the VOR Indicator directly, exactly as it worked before this part.
  - Tests from T1 remain green and add an in-range/out-of-range reception assertion using a supplied station and position.
  - Run the project gates required by the protocol.
- **Do not:** ~~reintroduce typed station identifiers~~ (**superseded 2026-09-18** — see the note below), add standby frequencies, DME behavior, HSI, or alter VOR station data and service-volume ranges.
- **Material alteration:** at this task's stop point the owner found the physical-knob tuning "too fiddly and annoying" and asked to revert to typing a station ident, with the OBS Dial dropped in favor of dragging the VOR Indicator directly (its original T1–T3 behavior). Confirmed with the owner that this keeps `FlightSession`/`NAVReceiver` storing frequency as the source of truth (S6/I4 stand); only the tuning *input* reverts to an ident field, which resolves via the pre-existing `VORNavigation.station(withIdent:)` and writes the match's frequency into the receiver via a new `NAVReceiver.tune(toFrequencyHundredths:)`. `FrequencyKnob` and the OBS-Dial use of `RotaryKnob` were deleted; `RotaryKnob` itself remains, still used by the heading bay's Heading Knob. I5, I6, U14, and U16 are amended/superseded above to match.
- **Verification handle** — permanent:
  - **Where:** at the Midland Cityport starting position, operate the NAV1 Radio Panel.
  - **Positive:** type `CTR` into NAV1's ident field → the frequency reads `116.80` in green; drag NAV1's VOR Indicator to set an OBS, then press NAV1 ↔ NAV2 → NAV2 now shows `116.80`/`CTR` and that OBS.
  - **Negative:** type an ident that matches no station → the frequency stays at its previous value and is not green; typing an ident or pressing swap must not change heading, airspeed, or aircraft position.
  - **Reads:** `FlightSession.nav1`, `nav2`, and `swapNAVReceivers()` in `Xcode Proj/VOR Vocational/Features/Flight/FlightSession.swift`, with `VORNavigation.receiverReading` supplying the CDI and `VORNavigation.station(withIdent:)`/`station(withFrequencyHundredths:)` resolving the typed ident.
- **Commit point:**

```text
cockpit-flight-deck T4: add NAV radio ident tuning

- tune NAV frequencies by typing a station ident
- set OBS by dragging the VOR Indicator directly
- support receiver handoff via NAV1 ↔ NAV2 swap
```

**T5 — Replace the map panel with Chart and Debug diagnostics**

- **Files:** `Xcode Proj/VOR Vocational/Features/Map/ChartPopover.swift` (new; add to the app target through Xcode), `Xcode Proj/VOR Vocational/Features/Flight/FlightDiagnosticsView.swift` (new; add to the app target through Xcode), `Xcode Proj/VOR Vocational/Features/Map/MapView.swift` (edit), `Xcode Proj/VOR Vocational/Features/Flight/FlightSession.swift` (edit), `Xcode Proj/VOR Vocational/App/VORVocationalApp.swift` (edit).
- **Done when:**
  - The right-side `MapControlPanel` and its zoom slider, CDI field, display picker, Position Challenge panel, and plane-coordinate section are absent from Free Flight.
  - A small persistent Liquid Glass `Chart` button appears in the chart's upper-right. Its popover owns exactly VOR visibility, individual High/Low/Terminal service filters, airport visibility, radial visibility, grid visibility and grid size in NM, and sightseeing-region visibility.
  - Scroll-wheel zoom and drag pan continue to work. Chart does not contain playback, aircraft truth, receiver diagnostics, CDI scale, Position Challenge, HSI selection, or a zoom slider.
  - In Debug builds only, the `Debug` menu opens a separate `Flight Diagnostics` window. With an active session, it live-displays normalized position, NAV1/NAV2 selected frequency, received ident or no reception, OBS, and CDI reading; it edits only `cdiMax`. With no active session it says that no Free Flight session is active.
  - Release builds contain neither the Debug menu item nor the diagnostics window. The shared `FlightDiagnosticsStore` exposes the existing session rather than duplicating any flight calculation or persisted state.
  - Run the project gates required by the protocol.
- **Do not:** add custom Preferences, a Home control, Mode catalogs, a user-visible debug entry, wind controls, or a second persistent flight session.
- **Verification handle** — permanent:
  - **Where:** run a Debug build, launch direct Free Flight, choose **Debug → Flight Diagnostics**, and open the Chart button over the map.
  - **Positive:** use Chart to hide Airports → airport symbols disappear while the chart remains interactive; press Play and turn heading → the diagnostics position and heading-derived receiver readings update live; type `CTR` into NAV1's ident field (per the T4 amendment) → Diagnostics reports `CTR`; edit CDI scale → the CDI response changes from that same session value.
  - **Negative:** leave NAV1 at its default `108.00` with no ident entered → Diagnostics reports no reception and the VOR Indicator shows NAV; toggling a Chart layer must not change the diagnostics position or receiver frequency.
  - **Reads:** `FlightSession` in `Xcode Proj/VOR Vocational/Features/Flight/FlightSession.swift` through `FlightDiagnosticsStore` and shared `VORNavigation.receiverReading`, the source used by the visible VOR Indicators.
- **Commit point:**

```text
cockpit-flight-deck T5: finish Chart controls and diagnostics

- move player chart layers into an on-chart popover
- keep simulation truth in a Debug-only diagnostics window
```

**T6 — Close out Part 1**

- **Files:** `Design/Plans/Cockpit-And-App-Shell-1-Free-Flight-Flight-Deck.md` (edit only for task statuses and a permitted note if required).
- **Done when:**
  - The owner has completed the T5 verification handle and the executor has updated T1–T5 to `completed` in this plan.
  - Confirm every item in **Deferred** has a ticket in `Design/Tickets/` with `Status: untriaged`; report the resulting untriaged ticket count in one session line.
  - The owner has made the T5 `commit + push` using its verbatim commit message after all gates are green.
  - Archive nothing: this is Part 1 of a split. Do not archive this plan, `Cockpit-And-App-Shell`, or any tickets; Part 2 performs the final feature close-out after it ships.
- **Do not:** add Mode navigation, archive design records, claim Part 2 is complete, or write a new ADR.

## Explicitly not doing

- Home, Mode cards, Learn/Practice/Missions lists, the upper-left Home control, and Practice → Position Challenge entry: Part 2 implements the Mode shell after this direct-launch flight deck ships.
- New functional Learn content, Missions, scoring, route planning, flight resume, or any change to flight physics: V0.2 reorganizes Free Flight rather than adding a mission system.
- Standby NAV frequencies, DME, HSI selection, a compact cockpit reflow, custom Preferences, wind controls, or iPad support.
- Position Challenge UI in direct Free Flight: its domain code and tests remain for Part 2, but Free Flight must not expose the exercise.

## Deferred

Empty at authoring. The executor appends adjacent problems found during this part and files each immediately as a `Bug-`, `Feature-`, `Decision-`, or `Chore-` ticket with `Status: untriaged`.
