# I-005 — Moving position and heading challenge

**Status:** Stage 1 implemented and verified; awaiting owner review/commit decision. Stages 2 and 3 have not begun.
**Idea:** [I-005 — Guided lessons and richer Practice](../IDEAS.md#i-005--guided-lessons-and-richer-practice).
**Requirements:** [Active exploration](../Explorations/I-005-moving-position-and-heading-challenge.md), including the [owner's marker reference](../Explorations/References/I-005-position-heading-marker.png).
**Goal:** Deliver a second, timed Practice exercise in which the player uses two NAV receivers to estimate a hidden moving aircraft's position and heading, submits one estimate, and inspects separate distance, heading, and elapsed-time results. Replace the stationary exercise's plane placement icon with the shared precise circle, without an arrow.

This packet covers that complete bounded exercise, not all of I-005. Guided lessons and combined scoring remain later work. Keep the exploration active until this scope is complete. No implementation or commit is authorized merely by saving this plan.

## Starting context and constraints

- Read `README.md`, `Design/IDEAS.md`, `Design/Glossary.md`, this plan, and the linked exploration before resuming. Source code remains the authority. At planning time there were no other active plans.
- Existing stationary Practice separates a hidden reception target from a guess stored in `FlightSession.normalizedAircraftPosition`. It has no flight timer. Preserve its target generator, distance calculation, and start/check/reset flow; change the marker and corresponding instructions only.
- `MapView` already composes chart layers, two radios, a heading bay, an optional side panel, and caller-supplied overlays. Its current overlay scales with chart zoom; the new precise symbols need a separate screen-sized overlay. Its built-in marker drag and camera share the session's position/zoom/pan.
- The current live chart shows `FlatMap.sourceCrop`, clamps marker placement to that crop, and permits 1–6× zoom. A valid moving aircraft can leave that crop while remaining on the full source chart. The moving exercise therefore needs full-source plotting and comparison inspection; preserve the existing crop/camera defaults in other modes.
- `FlightPhysics.Trajectory`, `FlightWorld`, and `VORNavigation` provide physical motion, first outward chart crossings, calibration, range, and heading math. Reuse these foundations. `FlightSession` only ends at the chart boundary when it has a mission; do not create a dummy mission or expect a non-mission session to end this exercise.
- The existing live loop uses `ContinuousClock`, which includes system sleep. It does not satisfy this exercise's timing requirement. Keep that existing loop unchanged and give the exercise its own clock ownership.
- `RotaryKnob` and other instruments receive scroll input through an AppKit event monitor. SwiftUI `.disabled` alone must not be assumed to block those callbacks.
- Existing worktree changes at planning time included `README.md`, `Design/IDEAS.md`, `Design/Glossary.md`, and the exploration/reference. Preserve unrelated edits. Establish the execution baseline before changing source.
- One macOS application target and its existing test target only. No new dependencies, signing/capability/entitlement/bundle-ID changes, or hand edits to the Xcode project. Source folders are synchronized; put new source files under the existing application folder and extend the existing test file rather than changing test membership.
- Never change Myosia data, physical calibration, existing fixtures, or tolerances to make a check pass. Normal missions must continue hiding true position and the planned route.

## Implementation decisions

### Ownership and awake-time flight

Use a dedicated `@MainActor @Observable MovingPositionChallengeSession` for this exercise. Extending the mission runner would bring checklist, recording, flight-control, and debrief semantics into a different activity; the recommended dedicated session keeps those behaviors separate while reusing their physical math and chart surface.

The session owns ready, active, generation-failed, completed, and abandoned states. It contains:

- A validated immutable scenario: starting `FlightAircraftState`, a calm constant-heading trajectory, and its first full-chart exit time/state.
- One independent player estimate: normalized position and whole-degree estimated heading. Neither property steers the aircraft or flies the marker. Do not retain a previous fix or an estimate trail.
- An ordinary `FlightSession` used only for chart preferences, camera, and receiver settings. Its aircraft simulation stays off. Its position/heading are not the moving aircraft's truth. Feed true position to the radios explicitly, and the estimate binding to the heading presentation explicitly.
- An attempt clock anchor, current elapsed time, and an immutable completion snapshot containing actual position/heading, estimate position/heading, elapsed seconds, ending reason, distance error, and shortest heading error in 0–180°.

Use Swift's [SuspendingClock](https://developer.apple.com/documentation/swift/suspendingclock): its time excludes system sleep. At successful Begin/Try Again, capture an anchor after scenario validation and input resets. Compute authoritative elapsed time from that same anchor on every refresh and action, rather than accumulating nominal frame durations. Evaluate the original trajectory at that elapsed time. A roughly 30-Hz cancellable refresh task is for display delivery, not timekeeping.

Refresh-task delays, cancellation/recreation, focus loss, minimization, and panel changes must not reset the anchor or discard awake time. Refresh on return as well as periodically. Do not use scene inactivity as a pause condition. System sleep needs no second subtraction or notification-based pause: the clock itself excludes it. Verify actual sleep on the Mac; fake timestamps alone do not establish that behavior.

Submit captures one clock instant, synchronizes truth and elapsed time to it, then freezes the estimate and actual state together. If the first chart exit is at or before that instant, freeze at the precomputed exit instead and report **Left the chart**. The same synchronization precedes estimate/radio edits so an input delivered after exit cannot change a finished attempt. Completion is idempotent. Explicit navigation abandons the attempt, cancels refresh delivery, and invalidates stale callbacks; no saved result or background flight survives leaving the exercise.

### Valid random scenarios

Keep generation and measurement pure in `MovingPositionChallenge.swift`, with injectable random input for deterministic tests.

1. Try at most **1,000** candidates. For each candidate independently draw a full-source normalized start in `0.1...0.9` on both axes and an integer heading in `0..<360`. Use **260 kt**, calm conditions, and selected heading equal to actual heading. Each Begin/Try Again makes fresh draws; accidental identical random outcomes do not imply replay.
2. Use the existing trajectory to compute first outward chart exit. A search horizon of the full chart's diagonal divided by speed, plus one second, bounds this straight-line flight. Reject an unresolved exit or an exit before **600 seconds**. An exit exactly at 600 seconds is permitted; 600 seconds is a minimum buffer, not a deadline.
3. Prove at least two distinct VORs are in range continuously over `[0, 600]`. In physical NM, intersect the straight flight segment with each station's service-range circle to obtain its closed time interval in range. Clip intervals to `[0, 600]`. Sort all interval boundaries plus 0 and 600; require coverage count ≥2 at each boundary and in every intervening open interval. Coverage is constant inside those intervals, so their midpoints establish the whole interval. A changing station pair is allowed. A tangent contact cannot cover a neighboring gap. Do not replace this proof with samples every second, endpoint counts, or a requirement that one fixed pair covers the whole path.
4. Use the existing inclusive `distance <= rangeNM` semantics. Handle roundoff conservatively: an ambiguous numerical sliver may reject a candidate, but must not bridge a real coverage gap. Validate finite inputs and count distinct stations. Do not widen radio ranges or change navigation tolerances.
5. Return an explicit failure if no candidate passes. Keep the timer stopped, radios/estimate disabled, and show **Couldn't create a valid challenge. Try again.** with **Try Again** and navigation available. Never launch a best-candidate, hard-coded, or stationary-generator fallback. After 600 seconds use ordinary receiver range behavior; no extra guarantee is implied.

The exploration's eastbound example (start 260 NM east/150 NM south, heading 090°) is a feasibility reference for tests, not a production fallback. Check it against bundled data, not rewritten station fixtures.

### Flow, defaults, and input gates

| State/action | Required behavior |
| --- | --- |
| Practice catalog | Keep **Position Challenge** and add **Position & Heading Challenge**, each with the existing row's Start affordance. Selecting the moving row opens ready instructions, not an already-running attempt. |
| Ready | Show the chart and disabled cockpit with no true-position/heading reveal. **Begin** starts generation and then the timed attempt. Radios, OBS, swap, estimate dragging, and heading input cannot work before launch. |
| Active | NAV1/NAV2 receive from current hidden truth. Enable tuning, OBS, swap, marker dragging, and immediate estimated-heading adjustment. **Submit** is available throughout; no first-fix or heading confirmation stages. Show a running **Elapsed** timer and read-only **Still air · 260 kt · 1×** reference. No Play/Pause, speed edit, or playback selector. |
| Completed | Freeze both estimates and truth, disable all exercise/cockpit edits, reveal comparison, and show separate **Distance error**, **Heading error**, and **Elapsed** measurements. Use **Submitted** or **Left the chart** for the ending. **Try Again** generates a new attempt and starts it immediately. |
| Navigation | Provide **Back to Practice** as well as Home in the moving wrapper. Leaving an active attempt discards it immediately without an extra confirmation, score, or persistence. Returning opens ready state. |

On every successful new attempt reset NAV1 and NAV2 to `NAVReceiver()` (**108.00 MHz**, active frequency, **OBS 000°**), clear ident-entry drafts and rotary accumulation/focus, reset estimate to full-chart center `(0.5, 0.5)` and heading **000°**, and zero elapsed time. Reset the live camera to a full-source fit and reopen the Practice panel. Use an attempt identity to prevent SwiftUI reusing a previous radio's text or pending gesture. Failed generation must leave no partially active attempt.

Retain chart layer preferences and grid size within the moving screen across retries; on fresh entry use the existing Practice defaults: VORs and all service volumes/radials on, airports/grid/sightseeing/checkpoint names off, grid size 50 NM, CDI full scale 10°. Clear selected station on retry. Retain no settings after leaving the screen. Panel visibility and resize never reset radios, estimates, or elapsed time.

Keep Chart controls, station selection/range rings, pan, and zoom available in ready, active, and completed states. These are inspection controls, not pre-start radio/estimate inputs. Keep the running timer visible in the existing status slot above the cockpit even when the Practice panel is hidden; reserve about 40 points and verify minimum-window layout. Keep Submit available there as well so hiding the panel does not obstruct ending the attempt.

Extend heading presentation with an explicit estimate mode. Its compass and knob both use only the player's estimate; remove the flight-specific HDG/SEL distinction and selected-heading bug in that mode. The reserved space **below** the indicator reads **Estimated heading 000°**, zero-padded and wrapped to 000–359°. Whole-degree changes update the estimate and arrow immediately. Existing flight presentation stays the default.

Use UI disabling and guarded binding/model setters. Update the scroll bridge to respect enabled state and reject disabled callbacks, including OBS and radio knobs, without blocking result-chart zoom. Test text entry, scroll, direct drag, and NAV swap before launch and after completion.

### Precise marker and comparison camera

Initial marker measurements are reviewable UI choices, not changes to geographic accuracy:

- Estimate: 28-point circle, 4-point center dot, four 5-point inward ticks, 2-point orange strokes with a contrasting halo. In the moving exercise add an outward heading arrow from circle edge to a tip 34 points from center, with an 8-point head. In the stationary exercise omit that arrow entirely. Its heading knob must not orient or otherwise alter the arrowless circle.
- Use a continuous filled **hit shape**, independent of the visible strokes: a circle of radius 26 screen points for the stationary marker and 46 for the moving marker. It covers the interior, arrow in every orientation, and at least a 10-point buffer. The hit region and drawing remain constant in screen points at every chart zoom.
- Only a drag beginning inside this hit region moves the estimate. Retain the pointer's initial offset so grabbing its edge/arrow does not jump the center. Background clicks never reposition it; background drags pan. Convert screen translation through the current viewport and clamp the estimate center to the applicable source bounds. Guard interrupted/stale drags at completion and retry.
- Actual result: the same circle/dot/ticks/arrow concept, with solid blue strokes, a 36-point circle, and arrow tip 40 points from center. Estimate result strokes are dashed, including its arrow. Draw the dashed estimate over the actual with halos that preserve the solid line through dash gaps. Slightly different radii/arrow lengths make coincident equal-heading results inspectable without displacing geographic centers.
- Label the two result symbols **Estimate** and **Actual** with separate contrasting labels and leader lines where needed. Only labels may move to avoid collisions. The existing mission-debrief layout helper moves symbol centers, so do not reuse that behavior here. Include a connecting position-error line beneath symbols.

Extend the shared map through explicit viewport/camera inputs with unchanged defaults. The new moving exercise uses the **full source crop** `(0,0,1,1)` while active, with 1–6× live zoom. A crop-only implementation would be smaller, but would make some otherwise valid true positions impossible to plot; full-source presentation is recommended for this exercise only. Do not change the global `FlatMap.sourceCrop`.

Comparison stays in the same MapView/chart region and keeps the cockpit frozen. Fit the two exact result positions using physical calibration, reserving the top 80 points for navigation/Chart controls and an additional **80-point inset** for full arrows and labels. Use a **0.05-NM minimum fitting span** per axis for a finite close-up, with **0.25–16,384×** comparison zoom relative to the full-source fit. Both extremes and all headings must fit within the actual available chart size. Allow enough comparison pan padding to fit arrows at chart edges; do not clamp an edge-centered fit back into clipping. Share projection math with chart layers and inverse drag conversion rather than implementing competing transforms.

Fit automatically at completion and whenever the available chart area changes (window resize or panel toggle). Provide pointer-anchored scroll zoom, center-anchored +/- controls, and **Fit Comparison** to restore the close-up after inspection. Live retry restores 1×/zero pan, not the comparison camera. Tiny/coincident centers may still overlap; styles, labels, headings, and measurements must remain readable. No artificial position offset or distance exaggeration is allowed. Keep the debrief's current camera and 10-NM fit policy unchanged.

Store unrounded measurements. Display NM to two decimals (positive values below 0.01 as **<0.01 NM**), heading error to one decimal degree, and elapsed as `m:ss` or `h:mm:ss`, from the same authoritative duration as flight. No score, threshold coloring, pass/fail, grade, or ranking; 5 NM/10° remain future-scoring notes only.

## Exact file scope

Application paths in this table are relative to **`Xcode Proj/VOR Vocational/`**. Do not create additional production files unless this packet is revised with the owner.

| File | Action and responsibility | Stages |
| --- | --- | --- |
| `Features/Map/PositionEstimateMarker.swift` | Create shared precise marker, styles, and continuous hit geometry. | 1 |
| `Features/Map/ChartViewport.swift` | Create pure forward/inverse viewport math, camera policy, and fit requests with symbol padding. Existing formulas/defaults must remain equivalent. | 1 |
| `Features/Map/MapView.swift` | Add configurable crop/limits/fit request, screen-sized overlay receiving the viewport, precise stationary marker option, estimated-heading input, and complete input gates; retain existing default behavior. | 1, 2 |
| `Features/Map/OverlayViews.swift` | Parameterize inverse `FlatMap.sourcePosition` crop with its current default, matching existing parameterized fit/forward projection. | 1 |
| `Features/Flight/FlightSurfaceConfiguration.swift` | Select the stationary circle and add the moving policy: no built-in aircraft marker, no simulation, no flight controls. | 1, 2 |
| `Features/Flight/PlaneControls.swift` | Add explicit estimated-heading presentation/readout; ensure custom cockpit inputs obey disabled state. | 2 |
| `Features/Practice/PositionChallengeView.swift` | Replace plane instructions with marker instructions; use shared arrowless placement. Preserve existing scoring/target flow. | 1 |
| `Features/Practice/PracticeComparisonView.swift` | Create frozen comparison symbols/labels/error line and Fit Comparison controls, using the shared viewport and marker. | 1, 2 |
| `Features/Practice/PracticePreviewView.swift` | Create Debug-only interactive marker/comparison presets; extend with playable moving scenarios in stage 2. | 1, 2 |
| `App/VORVocationalApp.swift` | Add Debug → Practice Preview window/menu entry following the existing mission-preview pattern; all new preview declarations are Debug-only. | 1 |
| `Domain/Simulation/MovingPositionChallenge.swift` | Create scenario validation/generation, scenario/estimate/result values, and physical error measurement. | 2 |
| `Features/Practice/MovingPositionChallengeSession.swift` | Create observable attempt ownership, injectable awake-time source, input mutators, exact ending synchronization, and immutable result. | 2 |
| `Features/Practice/MovingPositionChallengeView.swift` | Create ready/active/failure/result UI, clock delivery, heading binding, status, and navigation. Reuse MapView. | 2 |
| `Features/Practice/PracticeListView.swift` | Replace the Boolean selection with explicit exercise selection and add the second row plus return-to-catalog handling. | 3 |
| `Xcode Proj/VORVocationalTests/NavigationCoreTests.swift` (repository-relative) | Extend this existing file with independent behavioral coverage described below. Do not add test membership. | 1, 2, 3 |
| `README.md`, `Design/IDEAS.md`, `Design/Glossary.md`, this plan, linked exploration | Maintain implementation/review state and final links; archive only on bounded completion. All are repository-relative. | All / closeout |

Read but do not plan edits to `FlightWorld.swift`, `FlightPhysics.swift`, `VORNavigation.swift`, `FlightSession.swift`, mission files, content JSON/artwork, the project file, or build settings. If their APIs prove insufficient, explain the concrete obstacle before expanding scope.

## Ordered work and owner checkpoints

Update checkboxes and verification notes as work completes. At **each commit point**, show the working slice, exact checks/results, and any review limits, then stop **before changing the next group of files**. The owner may commit it themselves or ask for the suggested commit. Do not commit automatically or continue to the next stage until the owner says to proceed.

### Stage 1 — Precise placement and inspectable comparison

- [x] Record working-tree baseline and run the existing full test suite and Debug/Release builds with existing settings. If an unrelated check fails, investigate enough to explain and stop; do not repair it incidentally.
- [x] Add the marker and viewport/fit math. Parameterize crop without changing existing callers' results. Add screen-sized overlay and fit-policy hooks to MapView, leaving normal camera/input defaults intact.
- [x] Switch stationary Practice to the arrowless circle and update its player instructions. Confirm its hidden target, receiver source, and NM result remain independent of dragging and camera changes.
- [x] Add the comparison rendering and Debug → Practice Preview. Provide **Marker drag**, **Coincident / same heading**, **Coincident / different headings**, **0.01 NM**, **1 NM**, **100 NM**, and **Full-chart edge/corner** presets. Add heading variation, panel toggle, zoom, and Fit Comparison controls. Stage-1 comparison takes position/heading values directly so it compiles before the stage-2 domain result type exists; disable the surface's built-in marker in comparison presets. Static comparison presets are explicitly development data, never production random scenarios or results.
- [x] Verify projection round trips, default crop equivalence, fitting extents at minimum and large viewport sizes, and marker hit geometry for cardinal/diagonal headings. Visually try center/interior/tick/arrow/buffer drags at 1× and 6×, background clicks/pan, both styles at tiny/coincident errors, and full arrows near edges. Check normal Position Challenge in the main window.
- [x] Run full tests and Debug/Release builds after these changes. Record counts and any unperformed visual checks below.

**Owner checkpoint:** Home → Practice → Position Challenge exercises the precise arrowless marker. Debug → Practice Preview (also Window → Practice Preview) makes close/coincident/wide comparisons and the entire drag target testable immediately without a timed flight. Review at 1100×760 and a larger window, with the panel shown and hidden.

**Commit point 1:** Suggested message: `Add precise Practice markers and comparison inspection`. Stop here for the owner's commit/proceed decision.

### Stage 2 — Complete moving attempt through Debug Preview

- [ ] Implement pure scenario generation/validation and result measurement. Prove continuous 600-second coverage and first-exit timing before wiring a live view. Include explicit finite failure and deterministic random-input seams.
- [ ] Implement attempt state with injected awake-time readings for tests and SuspendingClock in production. Evaluate truth from the original trajectory; synchronize Submit, estimate/radio edits, exit, retry, and abandonment. Stale callbacks from a previous attempt must do nothing.
- [ ] Implement the moving view and surface configuration. Wire only actual position to reception and only estimated heading to the heading bay. Gate every radio/OBS/knob/swap/marker path before Begin and after completion, including the AppKit scroll bridge. No aircraft movement can come from the surface session.
- [ ] Wire ready instructions, Begin, active Elapsed/Submit status, raw results, generation failure, Try Again resets, and Back to Practice/Home callbacks. Compose the stage-1 comparison inside the same chart and apply full-source live plotting. Keep all active chart aids.
- [ ] Extend Debug Preview with **Random valid attempt**, **Known eastbound attempt**, **Generation unavailable**, and **Near-exit attempt**. Clearly mark fixed or shortened-buffer scenarios as Debug-only fixtures; they must not bypass the production validator in the normal catalog. Keep truth reveal/result injection available only in Debug preview for verifying motion and timing.
- [ ] Run the behavioral checks below and the full suite plus both builds. Use the playable preview for background/minimize, retry reset, immediate Submit, and actual system-sleep review. Record observed versus pending owner review explicitly.

**Owner checkpoint:** Debug → Practice Preview → Random valid attempt supports the complete Begin → tune → drag → estimate heading → Submit → inspect → Try Again loop. Fixed presets let the owner compare 260-kt movement with known geometry and reach chart exit promptly. Production catalog integration is the next stage.

**Commit point 2:** Suggested message: `Implement timed moving position and heading Practice`. Stop here for the owner's commit/proceed decision.

### Stage 3 — Normal Practice integration and bounded completion

- [ ] Add the second catalog row and explicit selection/return routing. Opening the moving entry starts ready; leaving and returning creates a new screen. Preserve stationary entry behavior and Home navigation.
- [ ] Verify the complete normal-catalog flow at 1100×760 and a larger window, both panel states, repeated retries, chart aids, close/full-chart-edge results, keyboard focus, and frozen inputs. The Debug preview must not be required to use the feature.
- [ ] Re-run full tests and Debug/Release builds after catalog integration. Smoke-test Free Flight turns/pause/playback/dragging; stationary reception/scoring/reset; Transport tuning, hidden truth, timing strip, pause, Flight Complete/chart exit, and existing debrief camera.
- [ ] Obtain and record flight review of the 260-kt pace, background/minimize advancement, and actual sleep/wake. If review is pending, mark implementation delivered with review pending and keep the plan/exploration active; do not claim full acceptance or archive prematurely.
- [ ] Once bounded scope and required review are complete, update README's working state/how-to/map for the new exercise and marker; update glossary references from planned to implemented. Update the **existing** I-005 entry with delivered scope, remove its completed Plan field, and set an honest remaining status/next action: explore the next guided lesson; consider combined scoring only when the owner chooses it. Keep the initiative. If more than half of its recorded overall scope has been implemented, ask whether the owner wants the entry removed; never remove it without that answer.
- [ ] Record final verification, then move this plan to `Design/Archived/Plans/` and the bounded exploration to `Design/Archived/Explorations/`. Move the exploration's referenced marker image to `Design/Archived/Explorations/References/` and repair all incoming and relative links, including cross-links between the two records, README, glossary, idea index, and image. Preserve decisions and review evidence.

**Owner checkpoint:** Home → Practice offers both complete exercises. The moving challenge works without a development window; retry is a new hidden situation, and results show three independent raw measurements with a readable two-arrow comparison.

**Commit point 3:** Suggested message: `Expose position and heading challenge in Practice`. Show final verification and stop for the owner's commit decision. Do not start later I-005 work.

## Verification that proves behavior

Extend the existing test file; add focused behavioral cases rather than view snapshots or tests that merely repeat constants.

| Area | Evidence required |
| --- | --- |
| Scenario validity | Reject an inside start heading out too soon; accept exit exactly at 600 s; verify a known valid bundled-data path. Synthetic geometry must include a valid change of covering station pair, a gap between otherwise valid endpoints, a sub-second gap, tangent-only coverage, duplicate station handling, and finite exhaustion/zero candidate budget. A seeded variety of generated scenarios must pass an independent check; random smoke sampling supplements the analytic proof. |
| Physics and measurements | At 260 kt, a known straight 60-s displacement is 4⅓ NM and 600 s is 43⅓ NM; actual heading stays constant. Check a physical 3–4–5 NM position error and headings 359°/001° → 2°, 0°/180° → 180°. Result values do not depend on viewport, panel, zoom, or window size. |
| Time and endings | Fake awake readings with skipped refreshes produce the same truth/time as frequent refreshes; elapsed can exceed 600 s when still on-chart. Submit between refreshes uses its own timestamp; an earlier/equal boundary wins and pins the exact exit state/time. Immediate Submit works. Repeated Submit and late ticks cannot change a completed result. Injected invalid scenarios cannot launch. |
| Independence and reset | Dragging/changing estimated heading never changes actual trajectory or receiver position; time advancement never moves the estimate. Guarded inputs before launch/after completion have no effect. Retry resets both frequencies/OBS, estimate, elapsed, pending ident/gestures, and live camera while preserving intended chart preferences. Old callbacks cannot finish/edit the new attempt. Explicit leave stops and discards it. |
| Camera and markers | Default existing projections remain equivalent; custom full-source projection/inverse works. Assert padded full symbol bounds for tiny, coincident, wide, and edge/corner fits; both centers stay exact. Fit/zoom/pan/resize never mutate the snapshot or errors. Zoom permits substantially closer inspection than 6× without the mission debrief's 10-NM minimum. Confirm manual pan/refit and same-heading coincident legibility visually. |
| Lifecycle on real Mac | Begin, switch apps for a measured interval, return; repeat minimized. Both truth displacement and Elapsed catch up by awake duration. Begin, observe, sleep the Mac for a measured interval, wake, then Submit: sleep duration adds neither distance nor elapsed time and does not itself end the attempt. Repeat sleep/wake once; no lost/doubled interval. An injected clock test cannot substitute for this review. |
| User experience/regressions | No hidden truth leaks through marker, heading dial, labels, selected-heading bug, accessibility text, or normal UI. Tune both NAVs during movement; confirm ordinary out-of-range behavior beyond the guarantee. Test disabled scroll/text/drag/swap, accurate lower readout, stationary arrow omission, clear errors, and the other-mode smoke checks above. Debug conveniences are absent from Release. |

Use the current shared scheme and installed Mac destination, without overriding signing or project settings:

```sh
xcodebuild -project "Xcode Proj/VOR Vocational.xcodeproj" -scheme "VOR Vocational" -destination 'platform=macOS' -derivedDataPath /tmp/VOR-I005 test
xcodebuild -project "Xcode Proj/VOR Vocational.xcodeproj" -scheme "VOR Vocational" -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/VOR-I005 build
xcodebuild -project "Xcode Proj/VOR Vocational.xcodeproj" -scheme "VOR Vocational" -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/VOR-I005 build
```

README reports 90 passing tests for the preceding feature; that is historical evidence, not a fresh baseline for this packet. Record actual execution counts/results. Build/test logs and review captures can stay under `/tmp/VOR-I005`; do not add generated artifacts to source control.

## Execution record

| Checkpoint | Automated checks | Visible / owner review | Commit / next action |
| --- | --- | --- | --- |
| Planning, 2026-10-21 | Source and project configuration read; clock semantics checked against Apple documentation. No build/tests run and no implementation begun. | Marker reference inspected. All feature review pending. | Await owner choice to build. |
| Baseline | 90 tests passed; Debug and Release builds passed with existing settings. Initial sandbox invocation could not access signing identities; normal Xcode/keychain access resolved it without signing changes. Logs: `/tmp/VOR-I005/baseline-{test,debug,release}.log`. | Source behavior checked against exploration. | Stage 1 authorized by owner on 2026-10-21. |
| Stage 1 | Final run: **97 tests passed**, Debug and Release builds passed with existing settings; `git diff --check` passed. Seven new geometry/interaction tests cover projection, drag translation, fitting, pointer anchoring, resize invariance, and hit coverage. Existing preset expectation updated for the intentional arrowless marker. Logs: `/tmp/VOR-I005/stage1-{test,debug,release}.log`. | UI automation checked the 1100×760-content preview and larger layout, both panel states, center/interior/arrow/buffer drags at 1×/6×, arrowless buffer, background click/pan, 0.01-NM/coincident/opposing-corner results, zoom/refit, and the normal stationary start/check flow in the full-screen main window. Exact minimum-size main-window review and owner acceptance remain pending. | **Stopped at commit point 1; no commit made. Await owner review, commit choice, and explicit proceed before Stage 2.** |
| Stage 2 | Pending | Pending, including actual sleep | Stop at commit point 2. |
| Stage 3 | Pending | Pending normal-catalog acceptance | Stop at commit point 3. |

## Boundaries and stop conditions

No guided lessons, final scoring/threshold enforcement, leaderboard, persistence, wind, speed selection, pause/playback controls, heading steering, saved fixes/trails, mission recording, new mission/debrief behavior, iPad target, or general application redesign.

Stop and explain after investigating enough to present concrete options if a prerequisite/build destination is missing, existing checks fail outside this scope, the current station network cannot support the proof, required camera/marker behavior cannot fit the minimum window, real lifecycle behavior contradicts the chosen clock, or implementation needs changes outside the listed files/project guardrails. Do not silently relax the 600-second guarantee, substitute invalid scenarios, expose truth, adjust content/tolerances, or redesign shared flight ownership. At every commit point, stop for the owner's decision before touching the next slice.
