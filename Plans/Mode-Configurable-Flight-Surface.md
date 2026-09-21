# Mode-configurable flight surface

## Status and goal

**Status:** Ready to build. This is the next focused slice after V0.2.

**Goal:** Let a mode declare which chart aids and cockpit controls support its
learning or mission purpose, without turning the reusable `MapView` into a
collection of mode-specific conditions. Position Challenge is the first
consumer: hide airports, retain the heading indicator and NAV radios, remove
speed/playback/Play-Pause controls, and guarantee that its guess marker cannot
be moved by the flight timer. Free Flight must retain its current behaviour.

## Current context

- VOR is one macOS SwiftUI target. It teaches VOR navigation on the fixed,
  fictional Myosia chart; it is not becoming a full flight simulator or a GPS
  display.
- `FlightSession` owns shared live state: aircraft/marker position, heading,
  speed, timer state, NAV receivers, and chart-layer preferences.
- `MapView` is the reusable chart/cockpit surface. It currently hard-codes all
  chart layers and a full `PlaneControlView`, including
  `isChallengeActive: false`.
- `PositionChallengeView` uses the session's aircraft-position property as the
  draggable **guess marker** while passing its separate hidden target as the
  radio reception position. If `isFlying` becomes true, `FlightTimerView`
  changes the same guess-marker property and corrupts the placement.
- The existing three-bay cockpit is composed by `CockpitPanel`. `PlaneControlView`
  currently combines the heading indicator/knob with speed, playback, and
  Play-Pause controls. `HeadingIndicator` is already a separate reusable view.
- Future supplied missions will need their own explicit choices about chart
  aids, overlays, and permitted controls. This plan creates only the small
  configuration seam they will use; it does not define mission rules yet.

## Design decision

Add a value-type configuration named `FlightSurfaceConfiguration` in the
Flight feature. It supplies presentation and interaction policy to `MapView`:

- which baseline chart layers begin visible for the mode (this first slice
  needs airports specifically; preserve the existing Free Flight chart
  controls and defaults). This is an initial preference, not a restriction:
  Position Challenge still exposes the normal Airports toggle in Chart;
- whether aircraft simulation can run;
- which pieces of the heading bay are rendered: the heading indicator/knob and
  the speed/playback/Play-Pause row.

`MapView` consumes this configuration generically; it must not import or test
for `PositionChallenge` or any mission name. A configuration can constrain a
session even if the session carries a stale value: when simulation is not
allowed, the surface does not render the timer and the mode start action
explicitly pauses the session. This two-part protection covers both a new
challenge and the case where a session was already flying.

Use explicit presets for this slice:

- `.freeFlight` preserves the current map/cockpit experience.
- `.positionChallenge` begins with airports hidden, permits chart panning/zooming
  and the normal Chart controls (including re-enabling airports), retains NAV
  tuning/OBS and the heading presentation, omits speed/playback/Play-Pause, and
  disallows simulated movement.

Do not put mode policy in `FlightSession`; it is mutable per-session state,
not a statement of what the mode teaches. Do not add a generic permission enum
or configurable mission builder yet: two named presets and focused properties
are enough evidence for the future API.

## Files

| File | Work |
| --- | --- |
| `Xcode Proj/VOR Vocational/Features/Flight/FlightSurfaceConfiguration.swift` | Create the value-type configuration and the two explicit presets. The Xcode project uses synchronized source groups, so no hand-edit of `project.pbxproj` is needed. |
| `Xcode Proj/VOR Vocational/Features/Flight/PlaneControls.swift` | Separate the heading presentation from the optional flight-control row while retaining Free Flight's visual layout and control bindings. When that row is omitted, retain the heading indicator at its Free Flight/VOR-instrument size rather than enlarging it. |
| `Xcode Proj/VOR Vocational/Features/Map/MapView.swift` | Accept the configuration, apply its allowed chart-layer/cockpit choices, and prevent `FlightTimerView` from running when the configuration forbids movement. Retain a Free Flight default or pass the explicit preset at every caller. |
| `Xcode Proj/VOR Vocational/Features/Flight/FreeFlightView.swift` | Pass the Free Flight preset explicitly, documenting it as the unconstrained baseline. |
| `Xcode Proj/VOR Vocational/Features/Practice/PositionChallengeView.swift` | Pass the Position Challenge preset; make `start()` pause the session before resetting the guess and target. |
| `Xcode Proj/VORVocationalTests/NavigationCoreTests.swift` | Add focused assertions for the policy presets and retain/extend state tests needed to prove a fresh session and the pure configuration behaviour. |
| `IDEAS.md` | After implementation, replace the Position Challenge movement item with accurate forward-looking context for the completed configuration seam and the next likely mission-specific use. Do not remove the V0.3 initiative. |
| `README.md` | Update only if the implementation changes the documented high-level arrangement or player-visible current state. |

## Ordered work

### 1. Establish the configuration seam

- [ ] Create `FlightSurfaceConfiguration` with the minimal focused policy
  values and named `.freeFlight` / `.positionChallenge` presets.
- [ ] Refactor `PlaneControlView` so the heading indicator/knob remains
  available when the flight-control row is omitted. Avoid duplicating dial
  geometry or its heading binding.
- [ ] Update `MapView` to receive and honor the configuration without any
  knowledge of mode names. Use the configuration's airport default when the
  surface starts, while retaining the normal Chart toggle afterward.
- [ ] Keep Free Flight's airports, chart controls, timer, speed field,
  playback picker, and Play/Pause behaviour visually and functionally
  unchanged.
- [ ] Add pure preset tests and run the existing navigation/simulation tests.

**Checkpoint — reusable surface refactor:** Run the app in Free Flight. Toggle
the familiar chart aids, tune both NAV radios, change heading/speed/playback,
then fly and pause. Confirm the layout and movement match the pre-change
experience. Run the `VORVocationalTests` target or the equivalent `xcodebuild`
test command. Show the result and stop for the owner to choose whether to
commit before starting the Position Challenge integration.

Suggested commit message: `Refactor flight surface around mode configuration`

### 2. Make Position Challenge the first consumer

- [ ] Pass `.positionChallenge` from `PositionChallengeView`.
- [ ] In `start()`, set `session.isFlying = false` before placing the new guess
  marker and target.
- [ ] Verify that Position Challenge starts with airports hidden, and that the
  normal Chart-panel Airports toggle can still show or hide them afterward.
- [ ] Verify that its cockpit retains the heading indicator/knob and both NAV
  radios/OBS controls, while speed, playback, and Play/Pause are absent.
- [ ] Verify that starting a challenge while a session is already flying leaves
  the guess marker stationary; changing heading or pressing Space cannot start
  simulated movement during the challenge.
- [ ] Verify that tuning and centering two in-range VORs, dragging a guess,
  and checking it still produces a correct error/reveal. Start a new challenge
  and repeat once to confirm reset behaviour.

**Checkpoint — observable first use:** Demonstrate the Position Challenge flow
above and show the automated-test result. Free Flight must be tried again to
confirm it remains unaffected. Stop for the owner to choose whether to commit
the completed feature.

Suggested commit message: `Configure Position Challenge flight surface`

### 3. Close out the planning record after the owner accepts the feature

- [ ] Update `IDEAS.md` so it no longer presents the fixed movement bug as
  active work; retain a concise note that Position Challenge established the
  reusable configuration seam and state the next mission-related need only if
  it is still current.
- [ ] Update `README.md` only if its current-state or arrangement description
  is no longer accurate (including correcting the currently inaccurate “CDI or
  HSI display” wording if touched for this work).
- [ ] Move this plan to `Plans/Archived/` once implementation is accepted and
  the records reflect current state. Do not create a historical log elsewhere.

## Acceptance criteria

- Position Challenge never advances its guess marker through simulated flight,
  including when it begins after `isFlying` was already true.
- Position Challenge begins with airports hidden; the user may re-enable them
  through the normal Chart-panel Airports toggle.
- It shows heading presentation plus NAV1/NAV2 radios and their OBS controls;
  it does not show speed, playback, or Play/Pause controls.
- Position Challenge radios continue to use the hidden target for reception;
  dragging the guess does not change radio indications.
- Free Flight remains an unrestricted flight surface with its existing chart
  layers and full flight-control row.
- The navigation/simulation test target passes, and the two user-visible
  checks above have been performed on the macOS app.

## Boundaries and stop conditions

**Included:** the reusable configuration seam, its first Position Challenge
use, the existing movement bug, and tests/documentation necessary to establish
the completed state.

**Deferred:** mission implementation, route/flight-plan models, mission route
overlays, user-authored policies, a generalized permissions framework, hidden
VORs/radials, scoring changes, changes to Myosia data or tolerances, iPad
support, and broader flight-simulation features.

Stop and ask before proceeding if the cockpit cannot omit its flight-control
row without changing the three-bay layout materially, if configuring chart
layers requires an unplanned redesign of `ChartButton`, if Xcode does not
compile synchronized new source files as expected, or if any test outside this
scope fails.
