# Cockpit And App Shell — Part 2: Mode Navigation

Status: **APPROVED 2026-09-18**

## Parts

**For the owner and the next authoring session — not for the executor.**

1. `Cockpit-And-App-Shell-1-Free-Flight-Flight-Deck` — direct-launch reusable Free Flight flight deck: session, cockpit, radios, Chart controls, and Debug diagnostics. **Executed and pushed 2026-09-18.**
2. `Cockpit-And-App-Shell-2-Mode-Navigation` — Home, Mode catalogs, Position Challenge entry, and navigation into the shipped flight deck. ← this part

| Exploration ID | Part |
|---|---:|
| S1–S5 | 2 |
| S6 | 1 |
| I1–I8 | 1 |
| U1–U7 | 2 |
| U8–U25 | 1 |

## Context

Part 1 shipped the reusable, direct-launch Free Flight flight deck. `ContentView` currently renders
only `FreeFlightView` with no other destination: `Xcode Proj/VOR Vocational/App/ContentView.swift:10-14`
(`struct ContentView: View { var body: some View { FreeFlightView() } }`). `FreeFlightView` is a thin
wrapper that constructs exactly one `FlightSession` and hands it to `MapView`, by design carrying no
Home button or Mode routing: `Xcode Proj/VOR Vocational/Features/Flight/FreeFlightView.swift:3-4,18-19`
(`/// Direct-launch wrapper...`, `MapView(session: session)`). `VORVocationalApp` already enforces the
`1100 × 760` minimum window and injects `FlightDiagnosticsStore`, and its `#if DEBUG` Flight
Diagnostics window and Debug menu are untouched by this part:
`Xcode Proj/VOR Vocational/App/VORVocationalApp.swift:18-40`.

`ADR-0001` records the shipped architecture this part must keep following: one reusable flight
surface (`MapView` + `FlightSession`), with each Mode boundary owning its own per-flight session
object rather than the shared surface growing Mode-conditional behavior. Part 2's Position Challenge
work is a second application of that same pattern, not a new one.

The domain logic for Position Challenge is untouched and still compiles and passes its existing
tests: `Xcode Proj/VOR Vocational/Domain/Simulation/PositionChallenge.swift` (`randomTarget`, `score`,
`State`), exercised by `Xcode Proj/VORVocationalTests/NavigationCoreTests.swift:259`
(`func testPositionChallenge()`). Its player-facing panel already exists but is unused dead code,
parked here since Part 1's extraction: `Xcode Proj/VOR Vocational/Features/Flight/PlaneControls.swift:406`
(`struct PositionChallengePanel: View`). Part 1 deliberately removed challenge-specific
reference-position behavior from `MapView` and left this domain code and its tests alone specifically
so this part could pick it back up.

The exploration `Cockpit-And-App-Shell` is **CLOSED** and supplies this part's decisions verbatim
(S1–S5, U1–U7 below); nothing here reopens scope it settled.

## Decisions (2026-09-18)

| # | Decision |
|---|---|
| S1 | V0.2 opens on a Home screen presenting Learn, Practice, Free Flight, and Missions as four large horizontal Mode cards, each carrying its Mode label. Free Flight enters the shipped flight deck directly; Learn, Practice, and Missions each enter a separate list screen. |
| S2 | Position Challenge is a Practice Skill Exercise, available from the Practice list. |
| S3 | The Learn and Missions lists show named, visibly unavailable future entries rather than an empty state, drawing on the concepts established in `NorthStar`. |
| S4 | Learn shows Position Fix and Radial Intercept and Track as unavailable future Skill Exercises. Missions shows Transport, Sightseeing, Nav Failure, Off-course Recovery, and One NAV Down as unavailable future Missions. These entries stay in place so later versions can activate them without restructuring the lists. |
| S5 | Every Home Mode card carries one concise descriptive phrase beneath its label. The Learn, Practice, and Missions list screens do not repeat descriptions; they focus on their named entries. |
| U1 | Home, the Mode lists, and Free Flight replace one another in the primary app window. Player-visible diagnostics remain confined to the separate Debug-only window Part 1 shipped. |
| U2 | A persistent, clearly labeled Home control sits in the upper-left of every Mode list and of Free Flight. It is a small, clear Liquid Glass button that expands slightly on hover. |
| U3 | An unavailable Learn or Missions entry is a non-selectable row carrying a small, discreet "Coming soon" label. It shows no preview and does not react to selection. |
| U4 | Home arranges its four Mode cards in a two-by-two grid. |
| U5 | Home uses the Myosia map as a subtly blurred background. Each Mode card uses an SF Symbol as its V0.2 artwork cue; bespoke Mode artwork is deferred. |
| U6 | Learn, Practice, and Missions retain the blurred Myosia-map background and place their entries on high-contrast reading panels. |
| U7 | Position Challenge is the only actionable Practice row and has a clear Start affordance. Every other Practice row is a non-selectable "Coming soon" row, styled like U3. |

## Tickets closed by this plan

- none — the exploration folded in no tickets.

## Prefactoring

**One extension point is needed before Task 3.** `MapView` currently has no way for a caller to draw
anything positioned in chart space from outside it — Position Challenge needs to reveal the hidden
target and the guess/target distance once checked, at the correct chart coordinates, without
duplicating `MapView`'s internal `imageRect`/`mapSize` layout math in a second file. Task 3 adds one
`@ViewBuilder` overlay parameter to `MapView` that receives the fitted `imageRect` (the same rect
`MapView` already threads through `FlatMap.point(for:in:)`), rather than Position Challenge
recomputing that geometry independently. This is additive: Free Flight supplies no overlay and is
unaffected.

No other prefactor is needed. Home, the Mode lists, and the Practice list are new screens with no
existing code to extract from.

## Approach

Build the shell in three layers: the Home/Mode routing skeleton, the two purely-informational catalog
lists, and the one functional Practice exercise. `ContentView` becomes the router; a plain
`enum AppDestination` (not `NavigationStack`) drives which screen shows, because U1 calls for screens
that flatly *replace* one another and U2 gives every non-Home screen its own explicit way back —
there is no push/pop stack to model. Learn and Missions are both instances of one generic,
reusable unavailable-entries list view, since S3/S4/U3/U6 describe them identically down to the
per-row treatment; Practice reuses that same row style for its non-functional entries and adds one
real, selectable row for Position Challenge.

Position Challenge becomes a third Mode-boundary wrapper alongside `FreeFlightView`, following
`ADR-0001`'s existing pattern rather than starting a new one: it owns one `FlightSession` (its
`normalizedAircraftPosition` doubles as the player's guess marker, exactly as `MapView`'s existing
plane-drag already works) and one `PositionChallenge.State`, and it renders `MapView` with the
Prefactoring overlay supplying the hidden-target and result markers. `MapView` itself gains no
Position-Challenge-specific state.

### 1. New: `Xcode Proj/VOR Vocational/Features/Home/HomeView.swift`; edit `ContentView.swift`

Create `enum AppDestination: Hashable { case home, learn, practice, missions, freeFlight }` and give
`ContentView` a `@State private var destination: AppDestination = .home` driving a plain `switch`
between `HomeView`, the Learn/Missions list, the Practice list, and `FreeFlightView`. Pass each
destination's Home-control action as a closure that sets `destination = .home`; do not introduce
`NavigationStack`, `NavigationSplitView`, or any push-based container.

`HomeView` renders the blurred Myosia-map background (U5) behind a two-by-two grid (U4) of four Mode
cards (Learn, Practice, Free Flight, Missions), each with its label, one descriptive phrase (S5), and
an SF Symbol artwork cue (U5). Selecting a card sets `destination` accordingly. Home has no Home
control of its own — it is the root.

### 2. `Xcode Proj/VOR Vocational/Features/Flight/FreeFlightView.swift`

Add the persistent upper-left Home control (U2) to `FreeFlightView`, wired to the same closure pattern
as the other destinations. Update its doc comment: Part 1's "do not add a Home button or Mode routing
here" no longer applies now that Part 2 has arrived. Do not change how `FreeFlightView` constructs its
`FlightSession`, and do not touch `MapView`'s flight or radio behavior.

### 3. New: `Xcode Proj/VOR Vocational/Features/Learn/ModeListView.swift`, `Xcode Proj/VOR Vocational/Features/Missions/MissionsListView.swift`; edit `ContentView.swift`

Build one generic, reusable list view (`ModeListView` or similar) that takes a title and an array of
named entries and renders each as a non-selectable row with a small "Coming soon" label (U3), over the
blurred Myosia background on a high-contrast reading panel (U6), with the Home control (U2). Instantiate
it once for Learn (Position Fix, Radial Intercept and Track — S4) and once for Missions (Transport,
Sightseeing, Nav Failure, Off-course Recovery, One NAV Down — S4). Neither list repeats a description
per S5.

### 4. New: `Xcode Proj/VOR Vocational/Features/Practice/PracticeListView.swift`, `Xcode Proj/VOR Vocational/Features/Practice/PositionChallengeView.swift`; edit `Xcode Proj/VOR Vocational/Features/Map/MapView.swift`, `Xcode Proj/VOR Vocational/Features/Flight/PlaneControls.swift`, `ContentView.swift`

Add the `@ViewBuilder` chart overlay parameter to `MapView` described in Prefactoring, defaulting to no
overlay so Free Flight is unaffected. Build `PracticeListView` reusing the same row component as Task 3
for its non-functional entries, plus one real, selectable Position Challenge row with a Start
affordance (U7). Move `PositionChallengePanel` out of `PlaneControls.swift` into
`PositionChallengeView.swift` alongside the new wrapper. `PositionChallengeView` owns one
`FlightSession` and one `PositionChallenge.State`; it starts a challenge with
`PositionChallenge.randomTarget`, treats the session's `normalizedAircraftPosition` as the guess
marker, scores with `PositionChallenge.score` on Check, and uses the `MapView` overlay to reveal the
target and the result once checked. Give it the Home control (U2). Do not add scoring history,
persistence, or any Mission-only behavior — this is the existing Skill Exercise relocated, not a new
one.

## Tasks

| # | Task | Status | Then | Commit | Note |
|---|---|---|---|---|---|
| T1 | Build the Home screen and Mode-routing shell | completed | **owner stop** | commit | |
| T2 | Build the Learn and Missions unavailable-entry lists | awaiting owner | **owner stop** | commit | |
| T3 | Build the Practice list and reintroduce Position Challenge | awaiting owner | **owner stop** | commit | see note |
| T4 | Close out Part 2 | not started | continue | — | |

**T1 — Build the Home screen and Mode-routing shell**

- **Files:** `Xcode Proj/VOR Vocational/Features/Home/HomeView.swift` (new; add to the app target
  through Xcode), `Xcode Proj/VOR Vocational/App/ContentView.swift` (edit),
  `Xcode Proj/VOR Vocational/Features/Flight/FreeFlightView.swift` (edit).
- **Done when:**
  - `ContentView` owns an `AppDestination` enum and a plain `switch`, starting at `.home`; no
    `NavigationStack`/`NavigationSplitView`/push-based container is introduced.
  - Home shows the blurred Myosia-map background, a two-by-two grid of the four Mode cards (Learn,
    Practice, Free Flight, Missions), each with its label, one descriptive phrase, and an SF Symbol
    artwork cue; selecting Free Flight's card enters the shipped flight deck unchanged.
  - `FreeFlightView` shows a persistent upper-left Liquid Glass Home control that returns to Home and
    expands slightly on hover; entering Free Flight again from Home still creates a fresh
    `FlightSession` (Part 1's behavior, unchanged).
  - Run the project gates required by the protocol.
- **Do not:** touch `MapView`, `FlightSession`, the cockpit, or NAV radio behavior; add Learn,
  Practice, or Missions screens (Tasks 2–3); add a Settings/Preferences screen.
- **Verification handle** — permanent:
  - **Where:** launch the app.
  - **Positive:** the app opens on Home with four Mode cards in a two-by-two grid; selecting Free
    Flight enters the flight deck exactly as Part 1 shipped it; the Home control in its upper-left
    returns to Home.
  - **Negative:** returning to Home and re-entering Free Flight starts a new session at Midland
    Cityport, paused — dragging the plane in one visit must not carry into the next.
  - **Reads:** `ContentView`'s `AppDestination` switch in
    `Xcode Proj/VOR Vocational/App/ContentView.swift`.
- **Commit point:**

```text
cockpit-flight-deck T1: build Home and the Mode-routing shell

- add enum-driven Home/Free-Flight routing without a navigation stack
- give Free Flight a persistent Home control
```

**T2 — Build the Learn and Missions unavailable-entry lists**

- **Files:** `Xcode Proj/VOR Vocational/Features/Learn/ModeListView.swift` (new; add to the app target
  through Xcode), `Xcode Proj/VOR Vocational/Features/Missions/MissionsListView.swift` (new; add to
  the app target through Xcode), `Xcode Proj/VOR Vocational/App/ContentView.swift` (edit).
- **Done when:**
  - One reusable list view renders a title and named entries as non-selectable rows, each with a
    small "Coming soon" label, no preview, and no selection response, over the blurred Myosia
    background on a high-contrast reading panel; it carries the Home control.
  - Learn lists exactly Position Fix and Radial Intercept and Track; Missions lists exactly
    Transport, Sightseeing, Nav Failure, Off-course Recovery, and One NAV Down. Neither screen shows
    a description under its title or under any entry.
  - `ContentView` routes Home's Learn and Missions cards to these screens and back.
  - Run the project gates required by the protocol.
- **Do not:** make any entry selectable or navigable; add scoring, progress, or unlock state; add
  the Practice list (Task 3).
- **Verification handle** — permanent:
  - **Where:** from Home, open Learn, then Missions.
  - **Positive:** each named entry appears with a "Coming soon" label; the Home control returns to
    Home from either screen.
  - **Negative:** tapping/clicking an unavailable entry does nothing — no preview, no navigation, no
    visual selection state.
  - **Reads:** the shared list view's entry array literals in
    `Xcode Proj/VOR Vocational/Features/Learn/ModeListView.swift` and
    `Xcode Proj/VOR Vocational/Features/Missions/MissionsListView.swift`.
- **Commit point:**

```text
cockpit-flight-deck T2: add the Learn and Missions catalogs

- share one unavailable-entry list view between Learn and Missions
- list the named future Skill Exercises and Missions from the exploration
```

**T3 — Build the Practice list and reintroduce Position Challenge**

- **Files:** `Xcode Proj/VOR Vocational/Features/Practice/PracticeListView.swift` (new; add to the
  app target through Xcode), `Xcode Proj/VOR Vocational/Features/Practice/PositionChallengeView.swift`
  (new; add to the app target through Xcode),
  `Xcode Proj/VOR Vocational/Features/Map/MapView.swift` (edit),
  `Xcode Proj/VOR Vocational/Features/Flight/PlaneControls.swift` (edit),
  `Xcode Proj/VOR Vocational/App/ContentView.swift` (edit).
- **Done when:**
  - `MapView` accepts an optional `@ViewBuilder` chart overlay parameter receiving the fitted
    `imageRect`, defaulting to none; `FreeFlightView`'s rendering is unchanged pixel-for-pixel.
  - `PracticeListView` shows Position Challenge as the one selectable row with a clear Start
    affordance, plus any remaining Practice entries as non-selectable "Coming soon" rows matching
    Task 2's row style.
  - `PositionChallengeView` owns one `FlightSession` and one `PositionChallenge.State`; Start calls
    `PositionChallenge.randomTarget`, dragging the plane sets the guess via the session's existing
    `normalizedAircraftPosition`, and Check calls `PositionChallenge.score` and reveals the target and
    result through the new `MapView` overlay. `PositionChallengePanel` moves out of
    `PlaneControls.swift` into `PositionChallengeView.swift` and is reused, not rewritten.
  - `PositionChallengeView` carries the Home control.
  - Existing tests, including `testPositionChallenge`, remain green untouched.
  - Run the project gates required by the protocol.
- **Do not:** add Position-Challenge-specific state to `FlightSession` or challenge-conditional
  branches inside `MapView` itself; add scoring history or persistence across attempts; add any
  Mission-only behavior.
- **Verification handle** — permanent:
  - **Where:** from Home, open Practice, then start Position Challenge.
  - **Positive:** Start hides the target and lets the plane be dragged as a guess marker; Check shows
    the error distance and reveals the target on the chart; New Challenge (per the existing panel)
    starts a fresh hidden target.
  - **Negative:** leaving Position Challenge via Home and returning to Free Flight shows a fresh
    session unaffected by anything set during the challenge; Free Flight's own chart shows no
    overlay artifacts.
  - **Reads:** `PositionChallenge.State` in
    `Xcode Proj/VOR Vocational/Domain/Simulation/PositionChallenge.swift`, threaded through
    `Xcode Proj/VOR Vocational/Features/Practice/PositionChallengeView.swift`.
- **Commit point:**

```text
cockpit-flight-deck T3: bring back Position Challenge under Practice

- add a chart overlay extension point to MapView for the hidden target
- relocate the existing Position Challenge panel into its own Practice screen
```

- **Material alteration:** the owner's verification found NAV reception reads the guess marker, not
  the hidden target — `MapView.receiverReading` was hardwired to `session.normalizedAircraftPosition`,
  the same property the plane-drag (guess) writes to, so the CDI needles tracked wherever the guess
  was dragged. Since OBS can always be dialed to center the needle from any position, this made "tune
  VORs, dial OBS until centered" convey no information about the real target — the exercise as
  originally built was not just visually wrong but unsolvable. This plan's Prefactoring section
  anticipated only one `MapView` extension point (the chart overlay); it did not anticipate that
  reception itself would also need to be decoupled from the draggable guess. With the owner's
  approval, `MapView` gained a second additive, defaults-to-nil init parameter,
  `receptionPosition: CGPoint?`, that `receiverReading` now prefers over
  `session.normalizedAircraftPosition` when supplied — the same shape as the chart-overlay parameter,
  so Free Flight passes nothing and is unaffected. `PositionChallengeView` now tracks the current
  target separately from `PositionChallenge.State` (which only carries it in scored, unscaled-map-space
  form once revealed) and supplies it as `receptionPosition`, so the radios read as if standing at the
  hidden target throughout the challenge.

  Separately, exercising the radios for Position Challenge surfaced a pre-existing bug in
  `OBSInstrument`'s drag handling in `PlaneControls.swift` (already an edited file for this task): it
  recomputed `obs + delta` fresh from the current whole-degree-rounded `obs` on every drag event, so a
  slow drag's sub-degree deltas kept getting rounded away instead of accumulating — read as the dial
  pausing, then jumping several degrees at once. Fixed by giving it the same carried-forward
  fractional-delta accumulator `RotaryKnob.accumulate(_:)` already uses; applied the identical fix to
  `HSIInstrument`'s drag handling for the same latent bug, though that view is still unwired.

  The owner also found `PositionChallengePanel` scaling and panning with the map and blocking a VOR.
  It had been placed inside the `MapView` chart-overlay closure, which sits in the same
  zoom/pan-scaled group as the map artwork (deliberately, so the target reveal tracks the chart) — so
  the panel was tracking zoom/pan too, and zooming in could push it off screen entirely. Moved the
  panel out to `PositionChallengeView`'s own top-level overlay, alongside the Home control, so it
  stays fixed on screen like Chart/Home regardless of zoom; the chart overlay itself now carries only
  the target/result reveal. Also made the panel draggable (a plain `DragGesture` on its background,
  default threshold, so taps still reach its buttons) so the owner can move it off any VOR it starts
  over.

  The owner also flagged that typing an out-of-range station's ident still auto-filled its frequency,
  even though the CDI correctly showed `NAV` (no reception). This was `NavRadioView`'s original,
  documented Part 1 behavior ("used to resolve a typed ident regardless of current reception range —
  separate from `reading`, which is range-gated") — not a regression from this task, but the owner
  wants it reversed, since seeing a frequency populate is itself a tell that a station exists there.
  `NavRadioView` now takes the same reception position (and map dimensions) `MapView` already computes
  for `receiverReading`, and only resolves a typed ident's station — for both the frequency auto-fill
  and the field's valid/highlighted styling — once it's actually in range from there. In Position
  Challenge this correctly uses the hidden target, not the freely-dragged guess, matching the same
  `receptionPosition` override already threaded through for reception.

**T4 — Close out Part 2**

- **Files:** `Design/Plans/Cockpit-And-App-Shell-2-Mode-Navigation.md` (edit only for task statuses
  and a permitted note if required).
- **Done when:**
  - The owner has completed the T3 verification handle and the executor has updated T1–T3 to
    `completed` in this plan.
  - Confirm every item in **Deferred** (this plan's and Part 1's) has a ticket in `Design/Tickets/`
    with `Status: untriaged`; report the resulting untriaged ticket count in one session line.
  - The owner has made the T3 `commit + push` using its verbatim commit message after all gates are
    green.
  - Archive the exploration `Cockpit-And-App-Shell`, the plan
    `Cockpit-And-App-Shell-1-Free-Flight-Flight-Deck`, and this plan, using the routine in
    `Design/Execution-Protocol.md` §11 — each as `executed`, one `ArchivedCatalog.md` line apiece.
- **Do not:** add Mode content beyond what S1–S5 and U1–U7 describe, add a new ADR unless a real
  trade-off surfaced during Tasks 1–3, or archive anything not named above.

## Explicitly not doing

- Functional Learn exercises or Missions of any kind: only their names appear, per S3/S4.
- Scoring, progress tracking, or unlock state for any Mode: none of S1–S7/U1–U7 calls for it.
- A back/forward navigation stack, breadcrumb, or system back button: U1/U2 call for flat replacement
  with one explicit Home control instead.
- Any change to Free Flight's flight model, cockpit, radios, or Chart/Debug diagnostics: those are
  Part 1's shipped surface, reused as-is.
- Bespoke Mode-card artwork: U5 defers it in favor of SF Symbols.
- Custom Preferences: U22 (Part 1's exploration decision) already ruled this out and nothing here
  reopens it.

## Deferred

Empty at authoring. The executor appends adjacent problems found during this part and files each
immediately as a `Bug-`, `Feature-`, `Decision-`, or `Chore-` ticket with `Status: untriaged`.

- `Bug-Position-Challenge-Play-Not-Disabled` — `PlaneControlView`'s existing `isChallengeActive`
  parameter can't reach it from `PositionChallengeView` without adding challenge-conditional state
  to `MapView`, which Task 3 rules out; Play can still disturb an active challenge's guess.
