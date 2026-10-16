# I-003 — Wind, flight recording, and first debrief

**Status:** Stage 2 implemented and behavior-verified — awaiting owner review

**Idea:** [I-003 in IDEAS.md](../IDEAS.md#i-003--mission-quality-and-debrief)

**Requirements:** [Settled exploration](../Explorations/I-003-mission-quality-and-debrief.md)

**Current checkpoint:** Stage 2 — Inspect the completed flight; owner visual review and commit decision pending

## Outcome and boundaries

Build shared mission capabilities for Calm or editable Steady wind, timed
recording, and an unscored planned-versus-flown debrief. The supplied Silverkeep
Strip → Midland Cityport flight is the first integration and test mission.
Other authored and generated missions use the same implementation by supplying
their own mission definition and conditions.

Flight Complete or the first outward crossing of the full source chart ends
the flight. The live mission continues to hide aircraft truth and the planned
route. The debrief reveals the recorded path, any supplied planned route, and
the final position. No shared behavior depends on the first mission's identity,
bundle resource, airports, route shape, or number of instructions.

The three owner checkpoints are:

1. Navigate with steady wind using the existing cockpit and NAV instruments.
2. Inspect an accurately recorded flight in a first working debrief.
3. Pan, zoom, and fit the comparison, with the finished layout verified.

Scoring, grades, arrival thresholds, route corridors, automatic leg selection,
sample inspection, replay, saved history, user-authored routes, new missions,
terrain, and aircraft-performance systems are outside this plan. The proposed
35% route / 65% arrival weighting remains a proposal for later exploration.
Checkmarks are player assists and never influence recording or assessment.

Keep the current Myosia content, route, radials, and existing test tolerances.
There are no dependency, Xcode-project, signing, capability, entitlement,
bundle-ID, or target changes. macOS remains the only target.

The reusable integration contract and tests for alternative mission inputs
are in scope. Building a mission generator, authoring UI, additional catalog
entries, or future mission-specific objectives is separate work; those future
producers must be able to supply the shared inputs without replacing this
wind, simulation, recording, ending, or debrief implementation.

## Source baseline

Reviewed against `30d1875`, with a clean working tree before planning:

- `TransportBriefingView` owns the resolved six-point route and five NAV
  instructions. It has a static chart and no editable flight conditions.
- `TransportMissionView` owns a `FlightSession`, independent checklist, and
  an optional `MissionFlightCompletion`. Completion captures time and raw
  distance to the literal airport; it does not retain a path or final position.
- `FlightSession` holds flight state but does not advance it. `MapView`'s
  private timer turns first, moves on the resulting heading, and clamps to the
  displayed crop. Its `Date` clock caps a wall-time advance at 0.1 seconds.
- `FlatMap` contains the source calibration and presentation crop. Its inverse
  projection rejects positions outside the crop. This is suitable for dragging
  visible markers, but must not constrain mission movement or recordings.
- Free Flight uses the shared flight surface. Position Challenge has no flight
  timer and uses a stationary, draggable guess marker with hidden-target NAV
  readings. Preserve that distinction.
- Debug → Flight Diagnostics already exposes the live session's truth in a
  separate development window. Normal mission play must not gain those aids.
- The project uses synchronized source folders and defaults app declarations
  to `MainActor`. New pure domain values/math should be explicitly
  `nonisolated`; mutable session state and SwiftUI remain on the main actor.
  Add test coverage to the existing `NavigationCoreTests.swift`, avoiding a
  project membership edit.

The README and exploration agree with this baseline except for the exact
180° turn rule: `FlightPhysics.turn` currently turns left when its raw heading
difference is −180°, although its comment and the exploration promise a
consistent right turn. This plan follows the settled right-turn requirement
and adds coverage for both +180° and −180° representations. Older archived
plans describe forward-only instruction advancement; the current independent
checklist is authoritative.

The current completion model already derives destination distance from its
input plan. The Transport result view still contains fixed route/destination
wording. Keep the former data-driven behavior and replace the latter with
shared presentation that reads the supplied mission metadata.

## Engineering decisions

### Reusable mission contract

- Introduce an immutable `MissionFlightDefinition` describing mission identity
  and title, initial aircraft position/heading/airspeed, ordered planned chart
  points when available, and an optional named arrival reference. A route-based
  adapter uses the existing `ResolvedFlightPlan` and `FlightPlanBriefing`; it
  must not load a bundle or select a particular plan inside the shared runner.
  Shared chart geometry needs named source-normalized positions, without
  requiring a particular authored waypoint type or bundle representation.
- Pass briefing instructions as data with a variable count and optional final
  reference. Do not assume five instructions, six points, a specific airport,
  or a terminal VOR reference. Hide the checklist when no instructions are
  supplied. Keep checks independent of recording and completion in every case.
- Accept initial aircraft state explicitly. The first mission uses its route
  origin, but the runner must not force all missions to start there; a future
  recovery mission can begin away from its intended route without changing
  the simulation or recorder.
- The briefing owns an editable `MissionWindSetup`; launch passes a validated,
  immutable `FlightConditions` alongside the mission definition. Wind setup
  controls and validation are reusable. A generator or another launcher can
  provide validated conditions directly without going through Transport UI.
- `MissionFlightView` owns the common live-flight/checklist/ending/retry flow;
  `MissionDebriefView` accepts only the completed snapshot plus navigation
  callbacks. `TransportBriefingView` and any retained `TransportMissionView`
  are thin content/navigation adapters to these shared pieces. They must not
  own a separate movement loop, recorder, completion algorithm, or debrief.
- Capture mission title, planned geometry, and optional arrival reference in
  the immutable completion. Labels, markers, and direct-distance measurements
  come from those values. Without an arrival reference, omit that measurement;
  without a planned route, show the recorded path and fit it alone. Do not
  substitute Midland or invent a route for either missing input.
- All mission launches use the common recording and full-chart ending policy.
  Free Flight and Practice are separate modes; their lack of mission recording
  is a mode policy, never a condition such as `missionID == transport`.
  Wind/motion/recording/boundary math receives no mission-type switch or bundle
  lookup. The simulation consumes state and conditions, not route instructions.
- A future authored or generated mission must integrate by constructing these
  values and using the shared views/session. No edit to the shared flight
  algorithms or debrief should be required merely because its route, title,
  destination, or source differs. Future objective-specific rules remain
  separate from this common flight evidence; no general objective engine is
  needed for this slice.

### World coordinates and ownership

- Introduce a pure `FlightWorld` calibration in `Domain/Simulation/`: width
  **500 NM**, height **500 × 1254 / 1748 NM**, normalized source coordinates,
  and conversions between normalized positions and NM. `FlatMap` delegates
  its existing dimension values to this calibration; content is unchanged.
- Calculate movement in physical NM with east-positive x and south-positive
  y, converting to source-normalized positions for storage and navigation.
  No screen sizes, crop rectangles, zoom, or pan enter mission dynamics.
- `FlightSession` owns advancement, elapsed simulated time, fixed conditions,
  optional mission recording, and a completed result. The map sends timing
  events and draws state. It does not integrate movement or decide endings.
- Sessions without explicit conditions default to Calm. Free Flight uses the
  same direct motion and source calibration, with its visible draggable marker
  and cockpit retained, but has no recording, automatic mission ending, or
  debrief. Removing the presentation-bound movement clamp means its aircraft
  can also move beyond the visible crop; do not add a new recovery UI in this
  slice. Verify and document this shared-motion change at Stage 1's review.
- Position Challenge retains its current no-simulation policy and crop-bounded
  guess drag. Chart inverse projection may remain restricted for this gesture;
  simulation never uses that inverse projection.

### Wind setup and lifecycle

- Use immutable `FlightConditions` containing Calm or a Steady wind value.
  Preserve Steady wind at 0 kt as the selected mode, although its displacement
  equals Calm. Direction uses the existing heading/radial north reference;
  introduce no magnetic variation or additional north convention.
- A briefing owns editable setup, separate from launched conditions. Start in
  Calm. First selecting Steady wind independently draws uniform whole-degree
  **000–359°** and whole-knot **5–25 kt** values, inclusive. Inject a random
  generator into setup logic for deterministic tests; do not test luck.
- Retain text entries through redraws, Calm/Steady switching, and Back to
  Briefing. Only first selection and explicit Randomize populate new values.
  Randomize replaces both fields. A newly opened briefing starts fresh in
  Calm; there is no persisted setup.
- Label direction **Wind from** and speed in **kt**. Trim surrounding whitespace
  and require whole-number entries. Steady launch accepts direction 0–359 and
  speed 0–40. Display valid bearings with three digits. **360 is invalid** and
  needs correction to 000; do not normalize or clamp invalid entries. Empty,
  decimal, nonnumeric, negative, and out-of-range entries show the relevant
  range and disable the mission launch action (Fly Transport in the first
  integration). Calm may launch regardless of retained
  invalid Steady entries.
- Mission launch creates a validated conditions value before constructing the
  session. It stays fixed while flying and paused. Show **Calm** or, for
  example, **Wind from 270° at 15 kt** near the live mission clock and in the
  result. The wind editor belongs only to the briefing.
- Fly Again creates a new session from the definition's exact initial aircraft
  state with the same launched conditions, cleared clock/checklist/result,
  fresh radios, and fresh recording. For the first mission that state is at
  Silverkeep; for a recovery mission it may be away from the route origin.
  Back to Briefing discards the flight/recording while preserving that
  briefing's setup. Back to Missions or Home releases both when the briefing
  is left. Scope retention to this view lifetime, not app-wide storage.

### Direct trajectory and clock

- Retain 3° per simulated second and shortest turns; implement the settled
  consistent right turn for exactly 180°, correcting the baseline discrepancy.
  Airspeed is constant during each advance. A control change starts the
  next trajectory from the current physical state; actual heading remains
  distinct from selected heading.
- Define one pure trajectory evaluator for any offset within an advance.
  Integrate the constant-rate turning arc until the target is reached, then
  add the straight remainder. Add constant wind displacement over the same
  entire duration. Avoid small fixed integration steps.
- With heading θ in radians, speed v in NM/s, and signed turn rate ω in rad/s,
  the turning displacement at t is
  `dx = v/ω × (cos θ₀ − cos(θ₀ + ωt))` and
  `dy = −v/ω × (sin(θ₀ + ωt) − sin θ₀)`.
  For a straight portion use `dx = v × sin θ × t`,
  `dy = −v × cos θ × t`. Wind from bearing β contributes
  `dx = −w × sin β × t`, `dy = w × cos β × t`, with w in NM/s.
  Use a numerically stable form for very short arcs and a separate straight
  case for zero turn. These equations define the teaching model.
- A narrow cancellable timing view/task uses `ContinuousClock`, waking about
  every 16 ms on the main actor and supplying measured positive elapsed wall
  duration. The session applies the current playback multiplier once and uses
  that same simulated duration for movement, clock, samples, and endings.
  Consume measured elapsed time rather than silently dropping the portion
  beyond the old 0.1-second cap; large advances are handled by the trajectory
  and event solver. Approximate wake frequency is not an integration step.
- Start a fresh timing baseline on Play/resume. Cancel on pause, replacement,
  or disappearance; guard advancement inside the session too. Bind task
  identity to both the session and play state so a retry cannot run an old
  session. Do not catch up time spent paused or after leaving the screen.
- While playing at 0 kt, wind drift, turning, time, and recording continue.
  Calm plus 0 kt leaves position stationary while time/recording continue.
  Pause freezes all of these. Camera, panel, and window changes do not
  advance, restart, or perturb the flight.

### Recording and one authoritative ending

- A mission recording is an in-memory array of immutable samples: source-
  normalized position, simulated seconds, actual heading, and airspeed.
  Store wind once in the flight conditions. Free Flight and Practice do not
  allocate recordings.
- Capture t=0 immediately. Track the next regular sample as an integer second
  index, rather than accumulating floating-point intervals. For each advance,
  evaluate the trajectory at every crossed whole simulated second, including
  several samples in one timer update.
- For manual or automatic completion, retain the exact ending time and state.
  If a sample already has that exact timestamp, replace it with the ending
  state; otherwise append it. Finishing at t=0 leaves one authoritative start/
  finish sample. Finishing between regular seconds adds an endpoint. Never
  invent a segment, duplicate a timestamp, or retain a sample after the ending.
- A completion snapshot owns the mission definition, conditions, recording,
  final position/heading/airspeed, elapsed time, optional raw arrival-reference
  distance, and an ending reason (`playerCompleted` or `leftChart`). It is
  immutable; time and final sample agree. When an arrival reference is supplied,
  distance uses `VORNavigation.distanceNM` and that literal coordinate, without
  a new arrival tolerance. For the first integration this remains the exact
  Midland airport coordinate, rather than the nearby route intersection.
- Manual completion works before Play and regardless of checklist progress.
  Finalize once and make later completion/advance requests harmless. A
  completed session cannot restart through a stale Play binding or timer.
  Retry creates a new session rather than clearing the completed one in place.
- Leaving a flight or debrief releases that recording. The debrief reads only
  the snapshot, never a mutable live aircraft or continuing simulation.

### First outward boundary crossing

- The common mission boundary is source x/y in **0...1**, including portions
  outside the normal crop. Touching an edge and returning inward is not an exit.
  Finish at the earliest point where the continuation goes outward. This can
  occur before an advance's endpoint even if that endpoint is inside again.
- Split the direct trajectory at target-heading arrival and at every x/y
  velocity zero within the turning arc. Find those critical times from
  `vx = v × sin θ + windX` and `vy = −v × cos θ + windY` using their analytic
  roots on the actual signed heading sweep. Include straight-segment endpoints.
  Each resulting interval is monotone in each coordinate, so an exit cannot
  hide between its endpoints.
- For every outward crossing candidate of x=0, x=1, y=0, or y=1, bracket the
  root within its monotone interval and bisect the direct coordinate function.
  Select the earliest outward root across both axes; coincident corner roots
  are one event. Tangencies are discarded by examining the continuation into
  the next interval. A boundary start moving outward ends at t=0; moving
  inward or along the boundary does not. An edge reached exactly at an advance
  endpoint ends there if the continuing trajectory goes outward.
- Stop the solver when the time bracket is at most **1e-8 simulated seconds**
  and the position bracket is at most **1e-9 NM**, with a defensive iteration
  limit that reports failure instead of silently choosing a later point.
  Pin the crossed coordinate to its exact edge; do not clamp the other
  coordinate or hide a solver failure. Handle the constant/stationary case
  without division by zero.
- If the converged crossing bracket contains a regular sample time, evaluate
  that time directly. When it lies on the crossed edge within the solver's
  **1e-9 NM** position criterion and continues outward, use that regular time
  as the common event timestamp. This gives a numerically coincident crossing
  and regular sample one authoritative endpoint. Otherwise keep the solved
  fractional timestamp; do not round arbitrary manual completion times.
- Determine this event before sampling the advance. Emit regular samples only
  through the ending time, then its authoritative endpoint. Freeze the model
  there and open the debrief directly, without a pause/resume intermediate
  state, extra confirmation, or score penalty.

### Numerical acceptance

These are new motion/event checks, not replacements for existing tolerances.
Use existing chart calibration and independent expected results, including
straight flights, known circular arcs, and analytically solvable crossings.

| Check | Acceptance |
| --- | --- |
| Straight/arc-plus-straight endpoint and scheduled sample positions | Within 1e-7 NM of independent expected geometry |
| Actual heading | Within 1e-7° using circular angular difference |
| Equal simulated input histories at 1×, 5×, 10×, 30× | Same sample count and integer regular timestamps; positions within 1e-6 NM, headings within 1e-7°, final timestamp/elapsed time within 1e-6 s |
| First outward crossing | Position within 1e-7 NM and time within 1e-6 s of independent expected crossing; same reason at every playback speed |

Exercise 0, 120, and 260 kt, Calm and 0–40 kt wind, left/right/wraparound/180°
turns, target arrival during an advance, irregular tick partitions, and at
least a one-hour simulated history. Apply control changes at identical
**simulated** times by splitting advances at those events. Equivalent wall-time
input timings at different playback speeds are not equivalent flights.
Compare to independent references as well as to other playback runs; agreement
among implementations alone is insufficient.

### Proof that the first mission is only an input

- Keep the existing supplied-route regression checks. Add distinct in-memory
  definitions with other origins/destinations and different point/instruction
  counts, including no intermediate waypoints and no terminal reference. Build
  at least one through `FlightPlanResolver` from an in-memory `FlightPlan`,
  without reading `SilverkeepToMidland.json`. This exercises the same input
  path a generator will use without building a generator now.
- Run alternate definitions through the same session, conditions, recorder,
  completion, and retry code. Verify each retains its own title, reference
  geometry, start state, wind, and destination distance; no data leaks between
  consecutive missions. Include an explicit start away from the planned origin
  and a definition with no arrival reference or planned route.
- For identical initial state, conditions, and simulated control history,
  changing mission identity or planned route must not change the physical path,
  sampling, or boundary event. Assert this alongside independent math checks.
- Exercise the shared live/debrief views with an alternate definition using a
  SwiftUI preview or bounded debug harness. Confirm titles, variable checklist,
  route markers, arrival label/optional metric, fit, and Fly Again derive from
  that definition. This adds no second production catalog mission and does not
  modify bundled world data or existing fixtures.
- Review the shared implementation for hard-coded Transport/Silverkeep/Midland
  names, plan IDs, file names, and fixed instruction/point counts. Such values
  belong only to the first mission's content adapter and its specific tests.

## Files and responsibilities

All Swift paths below are under `Xcode Proj/VOR Vocational/` unless noted.
Names for new internal helpers may vary without changing these responsibilities.

| File | Work |
| --- | --- |
| `Domain/Simulation/FlightWorld.swift` (new) | Pure source calibration and NM conversions. |
| `Domain/Simulation/FlightConditions.swift` (new) | Validated immutable wind and displacement vector. |
| `Domain/Simulation/FlightPhysics.swift` | Direct trajectory evaluation and first outward crossing math. |
| `Domain/Simulation/FlightRecording.swift` (new) | Sample and recording values, regular schedule, exact finalization. |
| `Domain/FlightPlanning/MissionFlightDefinition.swift` (new) | Shared mission inputs and route-based adapter, independent of bundled mission selection. |
| `Domain/FlightPlanning/MissionFlightProgress.swift` | Preserve independent checklist; extend completion snapshot and ending reason. |
| `Features/Flight/FlightSession.swift` | Own advancement, fixed conditions, optional mission recording/end state. |
| `Features/Map/MapView.swift` | Timing delivery and rendering; remove view-owned physics and crop-bound simulation. |
| `Features/Map/OverlayViews.swift` | Delegate calibration; add an explicit full-source projection/rendering option for debrief without changing the live crop default. |
| `Features/Missions/MissionWindSetup.swift` (new) | Reusable briefing-owned text, controls, validation, and injectable randomization. |
| `Features/Missions/MissionFlightView.swift` (new/extracted) | Shared live mission, variable checklist, fixed wind reference, ending/retry/exit lifecycle. |
| `Features/Missions/TransportBriefingView.swift` | Adapt the first bundled plan to shared inputs/setup and retain the briefing lifecycle. |
| `Features/Missions/TransportMissionView.swift` | Reduce to a thin adapter or replace call sites with the shared mission view. |
| `Features/Missions/MissionDebriefView.swift` (new) | Shared completed-flight chart, dynamic summary/labels, camera, and actions. |
| `Features/Flight/FlightDiagnosticsView.swift` | Debug-only full-source truth, wind and recording visibility. |
| `App/VORVocationalApp.swift` | Debug-only alternate mission window using the shared runner, separate from the production catalog. |
| `Xcode Proj/VORVocationalTests/NavigationCoreTests.swift` | Meaningful motion, recording, ending, input, and lifecycle coverage. |
| `README.md`, `IDEAS.md`, this plan | Update actual delivered behavior and verification at each checkpoint. |

Avoid a general weather engine, event framework, history store, mission
generator, or application-wide coordinator. Shared mission values and views
within the existing briefing/session ownership boundaries are sufficient.

## Ordered implementation

### Stage 1 — Navigate with steady wind

**State:** Complete — owner accepted and committed as `76f44b7 Add steady wind and model-owned flight motion`

- [x] Add the pure calibration, wind value, and direct trajectory evaluator.
  Apply the agreed turn rules, including consistent right turns at 180°;
  replace turn-then-move integration. Existing legacy `advance` checks remain
  valid if that helper is retained; do not
  rewrite them to conceal a change in the new trajectory's behavior.
- [x] Move physical advancement and elapsed-time ownership into the session;
  replace the map's physics bindings with the narrow monotonic timing driver.
  Keep Position Challenge stationary and modes without conditions Calm.
- [x] Establish the reusable mission definition and extract the common live
  mission flow into `MissionFlightView`. Pass explicit starting state and
  variable instructions; keep Transport as the first content adapter. Replace
  fixed route/destination wording in the shared manual result with input data.
- [x] Add reusable briefing setup/validation and launch immutable conditions.
  Keep the first mission's five instructions reachable at the 1100×760 minimum;
  allow the setup and
  instructions to scroll while keeping launch and validation understandable.
- [x] Show locked wind near the live clock and in the existing manual result.
  Make Fly Again reuse the exact launched conditions and Back to Briefing
  retain setup. Prevent manual completion from resuming the finished session.
- [x] Extend Debug diagnostics with wind and actual/selected heading. Render
  its truth map over the full source extent so travel outside the live crop
  remains inspectable. Do not expose truth in the mission panel or Chart menu.
- [x] Add focused tests for the equations, bearings/signs, turns, playback
  partitioning, pause, zero airspeed, input validation, one-time randomization,
  mode switching, and conditions retained through retry/return.
- [x] Test alternate in-memory mission inputs, starting away from a route
  origin, variable/empty checklists, and direct conditions injection. Identical
  state/control histories must have identical dynamics regardless of mission
  identity or planned geometry. Show an alternate shared-view preview.
- [x] Update README with the behavior delivered at this stage, including the
  shared movement change. Mark recording and automatic exits as still pending.

**Visible checkpoint:** Run Home → Missions → Transport. Switch to Steady wind,
enter **Wind from 270° at 20 kt**, and fly an initial northerly heading; use the
NAV instruments to observe drift and select a correction. Separately, set
airspeed to 0 and Play: Debug diagnostics should show eastward drift, while
Pause freezes position, heading, and clock. Try Calm, invalid 360° / 55 kt /
decimal / empty entries, Randomize, Calm → Steady retention, hide/show panel,
manual completion, Fly Again, and Back to Briefing. Wind stays locked during
flight; neither route nor aircraft truth appears on the live chart.

**Verification:** Run the complete existing macOS test suite plus the new
tests; build/run this checkpoint. Check Free Flight movement/drag and the
Position Challenge's stationary guess/NAV behavior. Show the owner evidence
at minimum window size, the alternate mission preview, and the Free Flight
crop behavior for review. Verify shared code has no first-mission constants.

**Commit point:** Update this plan's result, present the working app and test
result, then stop for the owner to choose whether to commit **before changing
Stage 2 files**. Suggested commit: `Add steady wind and model-owned flight motion`.
Recording, automatic off-map endings, and a debrief are intentionally not yet
delivered at this checkpoint; manual completion remains available.

**Verification result — 2026-10-15**

- Baseline macOS suite: **29 passed, 0 failures**. Final Stage 1 suite:
  **38 passed, 0 failures**, using the command below and the existing signing
  settings. The sandbox could not access the configured certificate; normal
  local build access succeeded without project or signing changes.
- Final result bundle:
  `/tmp/VOR-I003-DerivedData/Logs/Test/Test-VOR Vocational-2026.10.15_18-02-49--0500.xcresult`.
- Independent cardinal-wind and known quarter-/half-circle geometry checks
  passed at 1e-7 NM. Every simulated second of a one-hour control history was
  checked under Calm and 40-kt wind at 1×, 5×, 10×, and 30×: **28,800 evaluated
  states**, within the planned 1e-6 NM / 1e-7° playback criteria and 1e-6 s
  elapsed-time criterion. These evaluate motion; recorded samples are Stage 2.
- The new playback test caught roundoff at target-heading/180° boundaries.
  Shared heading arithmetic now treats machine-precision ties consistently
  and snaps to the reached target. Existing fixtures and test tolerances were
  retained. The two existing destination-distance assertions now unwrap the
  optional metric while retaining their original numeric expectations.
- In the running app, invalid 360° / 55-kt entries showed both ranges and
  disabled Fly Transport. Calm → Steady restored edited 270° / 20-kt values;
  explicit Randomize changed both. Launch displayed those locked conditions.
- At 0-kt airspeed with Wind from 270° at 20 kt, Play advanced the clock and
  moved the diagnostic position east to x=0.3401. Pause held that position and
  8.27 s. Manual completion with unchecked instructions reported 0:00:08 and
  89.20 NM from Midland Cityport, retained wind, and disabled flight controls.
  Fly Again reset the clock, checks, radios, and airspeed, retaining wind;
  Back to Briefing retained the edited draft. Hide/show retained checks/wind.
- The Debug-only alternate window displayed Crosswind survey, one instruction,
  a 090°/120-kt starting state, and Wind from 180° at 15 kt. Early completion
  used its own Survey endpoint (106.24 NM), and retry restored that mission's
  state. It uses `MissionFlightView` without a bundled plan or catalog entry.
- Free Flight exposed its visible aircraft and working Play/Pause; Position
  Challenge started with its guess marker and NAV controls, without flight
  controls. Existing navigation/Practice regression tests passed. The map's
  aircraft drag code is retained; a full-size manual drag review remains below.
- Shared runner/setup/physics/definition code contains no Transport, Silverkeep,
  Midland, fixed first-mission point/step count, or bundled-plan lookup.

**Owner handoff**

- The owner reported Stage 1 working, committed it as `76f44b7`, and explicitly
  authorized Stage 2. No further Stage 1 commit decision is pending.
- Detailed minimum-window readability and physical chart-marker drag were not
  verifiable in automation. Retain those checks for the final visual review;
  do not reinterpret the owner's general acceptance as a measured visual test.

**Try it:** The verified Debug app is at
`/tmp/VOR-I003-DerivedData/Build/Products/Debug/VOR Vocational.app`.
Open Missions → Transport, select Steady wind, enter 270° / 20 kt, and Fly
Transport. Window → Flight Diagnostics exposes the main session's truth only
for development. Window → Mission Runner Preview opens the alternate input.
At the Stage 1 checkpoint, recording, automatic ending, and debrief were still
pending. Stage 2 below now delivers them.

### Stage 2 — Record the flight and show a first working debrief

**State:** Implemented and behavior-verified; awaiting owner visual review and commit decision

- [x] Add the sample schedule and exact start/finish rules to all mission
  sessions. Complete the immutable result and idempotent ending lifecycle.
- [x] Add the monotone-interval crossing solver and finalize at the earliest
  outward full-source edge crossing, including an exit/reentry within one
  turning advance. Ignore checklist interactions throughout.
- [x] Replace the cockpit/result-card layout after either ending with a
  shared `MissionDebriefView` reading the snapshot. The first functional chart
  uses the full source artwork and fits both supplied planned and flown paths,
  or the flown path alone when the mission supplies no planned route.
  It must already reveal the actual final position and distinguish the paths.
- [x] Show mission title, wind, simulated H:MM:SS, and direct distance from the
  supplied named arrival reference to two decimals in NM when present. For the
  first integration this is Midland Cityport; do not hard-code it in the view.
  Show reason **Flight Complete** or **Left the chart**. Label
  this as an unscored review. Include Fly Again, Back to Briefing, Back to
  Missions, and Home with the agreed recording/setup lifetimes.
- [x] Expose sample count, last sample time, recording polyline, and ending
  reason in Debug diagnostics while a session is inspectable. Use the actual
  model values, not a second debug simulation or a production reveal switch.
- [x] Test t=0 finish, regular/finish coincidence, fractional finish, multiple
  crossed seconds, stationary recording, pause/resume, repeated completion,
  stale ticks after completion, retry/exit disposal, and checklist independence.
- [x] Test each chart edge, corners, starting on an edge inward/outward/along,
  tangential contact without exit, wind-only exit, and curved exit/reentry
  with a later inside endpoint. Verify the same exact ending/sample contract
  at every playback speed using independent expected crossings.
- [x] Run the alternate-definition recording/completion/retry checks and
  shared-debrief preview from the reuse contract. Verify optional arrival
  measurements and planned geometry, dynamic names, different route lengths,
  and cross-mission isolation without a Transport-specific branch.
- [x] Update README and record verification here without claiming final
  debrief interaction or visual acceptance.

**Visible checkpoint:** Complete before Play to see a one-point flight at
Silverkeep, then fly/turn/pause and finish between sample times. Compare the
planned route to the flown path and inspect Debug sample timing. Fly north
at 30× until the full source edge is crossed; it must open the debrief directly,
with no later outside path or continuing clock. Confirm the part beyond the
live display crop is visible. Fly Again keeps wind and starts a fresh path;
Back to Briefing clears the path and retains the editable setup.

**Verification:** Run the full macOS suite and this checkpoint. Recheck the
numerical acceptance table, early completion, and a curved crossing case.
Demonstrate an alternate definition through the same recorder and debrief.
Verify the debrief is independent of the former live camera and cannot resume
the simulation. The initial chart must be useful at 1100×760 even before polish.

**Commit point:** Show the results and stop for the owner to choose whether to
commit **before Stage 3**. Suggested commit:
`Record mission flights and reveal their unscored debrief`.

**Verification result — 2026-10-15**

- Full macOS suite: **53 tests passed, 0 failures**, with the existing shared
  scheme, test plan, and signing configuration. No project, dependency, bundled
  content, or existing numeric tolerance changes.
- Final result bundle:
  `/tmp/VOR-I003-DerivedData/Logs/Test/Test-VOR Vocational-2026.10.15_18-44-29--0500.xcresult`.
- Recording checks cover exact start, every crossed integer second in a large
  advance, actual heading/airspeed, stationary and wind-only flights, pause/
  resume, fractional finish, coincident regular/finish and start/finish, repeat
  completion, stale ticks, checklist independence, retry, and release of the
  previous session while retaining an immutable completed value.
- Eight one-hour recordings (Calm and 40-kt wind at 1×/5×/10×/30×) each retained
  3,601 scheduled samples. All regular timestamps matched; cross-playback
  positions/headings met 1e-6 NM / 1e-7° and final time met 1e-6 s. Independent
  arc-plus-wind samples met 1e-7 NM, including a finish after target arrival.
- Independent exit references cover all four edges, corners, outward/inward/
  along-edge starts, exact endpoint crossings, touch-and-return, touch followed
  by edge tracking, wind cancellation, wind-only exit, and fractional endings.
  Calm and wind-shifted curved exit/reentry cases have known first crossings
  at 10 s and 20 s despite later inside endpoints. Crossing checks met the
  plan's 1e-6 s / 1e-7 NM criteria without widening any existing tolerance.
- Boundary failures pause without advancing position, time, or recording and
  expose the failure. They never silently retain a later outside state.
- Completed state and time now derive from the final recorded sample. The old
  distance-only constructor was removed because it cannot supply an honest
  path. Its existing 0-NM / 50-NM assertions now run recorded stationary flights
  at the same positions and durations, retaining the original numeric checks.
- In the running app, finishing Transport before Play opened a dedicated
  debrief with **one recorded sample, six planned points, 0:00:00, 89.24 NM**,
  Calm, and Flight Complete. The cockpit was absent; no segment was invented.
- A northbound 260-kt flight with Wind from 270° at 20 kt at 30× paused at
  **1715.94 s**, with **1,716 samples** and last regular time **1715.000000 s**.
  Both remained unchanged while paused. Checking step 2 and resuming continued
  the same recording.
- That flight automatically opened Left the chart at the full north edge:
  **2979.933110 s, 2,981 samples, x=0.3731, y=0**, with a displayed 0:49:40 and
  255.97 NM from Midland Cityport. The final timestamp/count/position remained
  frozen. The fitted chart includes the portion outside the live display crop.
- Fly Again reset the flight/checks/clock while preserving wind. A separate
  manual completion retained **12 samples**, ending at **10.099874 s** and
  reporting 89.45 NM. Back to Briefing retained 270° / 20 kt; Diagnostics then
  showed no active session, confirming the prior recording was released.
- The alternate in-memory mission used the same debrief with its own title,
  two planned points, one start/finish sample, 180° / 15-kt wind, and Survey
  endpoint measurement (106.24 NM). Retry restored its own starting state.
  Unit coverage also checks empty route/arrival inputs and cross-mission
  recording isolation. Shared recording/exit/debrief code has no first-mission
  names or bundle lookup.
- Basic fit/projection checks cover full source edges, physical aspect ratio,
  stationary tracks, and complete route/track containment. The chart draws the
  uncropped source artwork and positions marker symbols at exact coordinates.
  Pan, zoom, Fit Flight, label collision tuning, and final visual acceptance
  remain Stage 3 work.

**Owner checkpoint**

- [ ] Review the planned/flown comparison, markers, legend, reason, measurements,
  and actions at 1100×760. Capture initially returned a blank preview; activating
  the verified app through Finder produced a Stage Manager thumbnail showing
  both routes and the full edge track, but full-size readability could not be
  confirmed. Do not mark this as final visual acceptance.
- [ ] Choose whether to commit Stage 2 before Stage 3 implementation.

**Try it:** The verified app is open on a completed northbound wind flight.
Use Fly Again to start a new recording with the same conditions; Flight Complete
opens the static comparison at any time. For an automatic ending, fly north
at 30× until the full chart edge. Window → Flight Diagnostics shows sample
count, exact last timestamp, path, and ending. Window → Mission Runner Preview
uses different mission data through the same flow. The current view fits the
flight automatically; pan/zoom and Fit Flight are deliberately still pending.

### Stage 3 — Finish debrief inspection and visual verification

**State:** Not started; depends on Stage 2's owner checkpoint

- [ ] Add pan/zoom and **Fit Flight**, operating solely on a debrief-local
  camera. On opening and on Fit Flight, fit the union of all planned points
  and recorded positions with at least 48 points of screen margin per side.
  Include marker/label extents; handle one-point/stationary tracks without
  zero-sized bounds. A missing planned route fits the flown path alone.
  Fit on layout-size changes using the same snapshot.
- [ ] Use a physical source-space projection with the original aspect ratio.
  Letterbox with ocean as needed. Do not reuse the live cropped projection
  or crop-bound pan constraints in a way that hides any of the flight.
- [ ] Start at the fitted scale. Allow zoom from 0.5× to 16× that scale,
  anchored at the pointer, and pan far enough to inspect every full-source
  edge. Fit Flight resets pan and zoom. Keep stroke widths and marker sizes
  readable in screen points; no gestures alter recorded data.
- [ ] Start visual review with an **orange dashed 3-point planned route** and
  a **dark blue solid 3-point flown path**, each with a contrasting halo, plus
  a legend using the same line styles, omitting planned-route legend items when
  no planned route is supplied. Distinguish Start, any named arrival reference,
  and Finish by shape and label as well as colour. Offset overlapping labels;
  show combined start/finish meaning for a zero-time flight, without a fake
  segment. Visual tuning may change colour/spacing, never recording geometry.
- [ ] Use a summary beside the chart, approximately 340–400 points wide and
  scrollable when necessary. Keep reason, conditions, measurements, and all
  actions reachable at 1100×760. This screen contains no live cockpit.
- [ ] Test pure fit/projection calculations for full-source edge tracks,
  stationary flights, aspect ratio, and route-plus-track containment. Verify
  camera actions leave the snapshot unchanged; do not add tests that merely
  duplicate colour/style literals.
- [ ] Review Calm, uncompensated drift, a corrected route, early completion,
  long tracks, pause/resume, different playback speeds, full-edge endings,
  overlapping markers, alternative mission inputs, and window resizing in the
  running app. Recheck normal
  mission truth hiding and the other two working modes.
- [ ] Update README with the final experience and actual limitations, and
  update I-003 so later scoring exploration is the next action. Retain the
  exploration and its deferred weighting proposal.

**Verification:** Run the full macOS suite and build both Debug and Release
with the existing settings. In Release, confirm Debug diagnostics are absent.
Show the owner the debrief at 1100×760, demonstrate pan/zoom/Fit Flight, and
record any visual review still needing owner acceptance explicitly.

**Commit point:** Present the result and stop for the owner to choose whether
to commit. Suggested commit: `Finish interactive mission debrief inspection`.
After owner acceptance of the final stage, mark the plan complete and move it
to `Plans/Archived/`, updating inbound links in the same documentation change.

## Verification commands and stopping rules

For each implementation stage, use the existing shared scheme and test plan:

```sh
xcodebuild test -project 'Xcode Proj/VOR Vocational.xcodeproj' \
  -scheme 'VOR Vocational' -destination 'platform=macOS' \
  -derivedDataPath /tmp/VOR-I003-DerivedData
```

Use that project/scheme/destination with `build -configuration Release` for
the final Release check. Keep signing settings intact. If the sandbox cannot
access existing signing credentials, request the ordinary local build access;
do not disable signing or change the project as a workaround. Stop and explain
if a prerequisite is genuinely unavailable.

At every commit point, record the command/result, numerical evidence, visible
try-it path, remaining limits, and owner review status here. Do not commit or
continue into the next stage until the owner chooses. This planning change
does not authorize a commit or begin production implementation.

Stop and explain an unrelated test failure, a missing prerequisite, a need to
change content/tolerances/project configuration, or an architectural change
beyond the focused model-owned flight/recording refactor described here. A
missed numerical criterion requires fixing or explaining the calculation;
never widen an existing tolerance or move a fixture to obtain a pass.

## Planning verification

- 2026-10-15: Plan grounded in current source and the settled I-003 exploration.
  No production code, bundled content, project configuration, or tests changed.
- Captured the source/design discrepancy in exact-180° turn direction and
  selected the exploration's consistent right-turn rule explicitly.
- 2026-10-15: Owner clarified that Silverkeep → Midland is only the first test
  mission. Made shared mission inputs, views, wind, recording, ending, and
  debrief mandatory for authored and generated missions, with reuse checks.
- Checked whitespace and all 11 local document links; no missing targets.
- App tests were not run for this documentation-only change.
- Stage 1 is accepted and committed as `76f44b7`. Stage 2 evidence is recorded above; its owner checkpoint and Stage 3 remain pending.
