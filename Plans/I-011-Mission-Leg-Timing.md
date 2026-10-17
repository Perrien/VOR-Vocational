# I-011 — Mission leg timing

**Status:** Stage 1 accepted for commit; Stage 2 authorized
**Goal:** Let the player judge when to accelerate playback by reading a fixed still-air schedule, a current-leg running estimate, and a next-leg duration preview.

**Idea:** [I-011 in IDEAS.md](../IDEAS.md#i-011--mission-leg-timing)
**Requirements:** [Settled exploration](../Explorations/I-011-mission-leg-timing.md)
**Current checkpoint:** Owner requested “Commit and then proceed.” Commit Stage 1, then implement Stage 2 through its checkpoint. Prior visual review limits remain recorded, not inferred as completed.

## Context, baseline, and boundaries

Reviewed on 2026-10-16 against **0541bd7**, `Finish interactive mission debrief inspection`. The working tree already contains the I-011 exploration and related README, IDEAS, and glossary edits; preserve them. Planning alone did not authorize implementation or a commit. The owner's “Let's begin implementing the I-011 plan” authorizes Stage 1; stage checkpoints and commit choices still apply.

The current app is one macOS SwiftUI target. Transport has a resolved six-point, five-leg route, five independent checklist instructions, editable wind before launch, shared model-owned movement and recording, and an unscored debrief. The briefing shows distances and one total estimate at 260 kt. The live mission shows no leg timing. `FlightSession.advance(wallElapsed:)` owns simulated time, physics, samples, and chart-exit completion; the view only delivers monotonic time. Source folders are synchronized, pure domain declarations need explicit `nonisolated`, and app/view state stays on the main actor.

Two project records need care:

- I-003 documents still describe its Stage 3 commit as pending, although HEAD contains that implementation commit. Use the committed source as this plan's baseline; do not infer that the outstanding minimum-window and corrected-flight visual reviews were accepted. Do not edit or archive I-003 as part of this feature.
- README names Window for the development windows, while `VORVocationalApp` explicitly exposes them in the **Debug** menu. Use **Debug → Mission Runner Preview** for this plan's trial path. Correct that small README menu description when updating the delivered behavior.

All timing in this plan is **still-air**. Do not read actual aircraft position, heading, wind, groundspeed, receiver readings, or recording samples to calculate progress or choose a timed leg. Planned route geometry may supply leg distances before flight. Wind keeps affecting physical movement normally; wind correction remains a later player flight-planning skill.

Preserve Myosia data, authored radials, existing fixtures/tolerances, NAV behavior, chart truth-hiding, recording cadence, chart-exit rules, and the independent checklist. No dependency, Xcode-project, signing, capability, entitlement, bundle-ID, deployment-target, or target changes. Free Flight and Position Challenge keep their existing surfaces and behavior. New mission catalogs, route authoring, scoring, wind planning, editable planning airspeed, historical timer entry, and whole-route live forecasts are outside scope.

One feature is planned in three independently reviewable stages. Stop at every stage's commit point until the owner chooses to proceed.

## Fixed schedule and mission inputs

- Introduce immutable timing data separate from checklist instructions and chart presentation: an ordered array of leg labels/distances, the assigned planning airspeed, and an explicit startup policy. Use leg ordinals/stable indices for identity; repeated endpoint names must not collide.
- Adapt **all** `ResolvedFlightPlan.legs`, including legs without VOR guidance. Transport must have five timed legs, with the final intersection-to-airport leg included. Keep its fifth checklist instruction as the existing Elmstead radial reference, with no fabricated reference distance or additional timed leg.
- The route adapter sets the planning airspeed to the mission's assigned initial airspeed: currently 260 kt for Transport. There is no new editable planning-speed field. A mission may explicitly supply another baseline without shared code knowing its identity.
- For distance `d` NM and planning airspeed `v` kt, planned duration is `d / v × 3600` seconds. Planned reach time is the sum of unrounded durations through that leg, measured from simulated flight start. Preserve this schedule throughout the flight.
- Pass optional timing data through `MissionFlightDefinition`; `nil` means timing was not supplied. Do not infer timing from its arbitrary `plannedPoints` or instruction count. The route adapter supplies timing explicitly; a generic mission can omit it.
- Validate timing independently of flight viability. Empty supplied legs, non-finite or non-positive distance/planning speed, or non-finite derived durations/cumulative totals produce **Timing unavailable** with no timing controls or assist. Preserve enough validation status to distinguish invalid supplied timing from absent timing. An invalid timing attachment does not block an otherwise valid mission or silently become a valid-looking empty schedule. No new minimum positive distance is introduced; leave the route resolver's existing duplicate-point threshold unchanged.
- Startup policy is `.firstLegOnFirstPlay` for the supplied route adapter and `.manual` by default for other producers. A future recovery mission can use the manual policy even when its chart route starts elsewhere. Never compare live position with a route point to infer this policy.
- Add a schedule to `FlightPlanBriefing` separately from its existing five instruction steps. Preserve their kinds, guidance, order, and terminal-reference distance of `nil`. This plan changes the old comment that final airport geometry is chart-only: it will now also be shown in the timing schedule, without becoming a literal VOR instruction.

## Running estimate, controls, and unavailable states

Use a pure value model for timing and a session-owned instance of that model. The session exposes start/restart/undo operations and derived read-only display values; views must not maintain independent countdowns.

### One selected leg and one Undo context

- On the first successful transition to Play, handle automatic startup once. With `.firstLegOnFirstPlay` and no explicit selection, begin leg 1 at that current simulated timestamp. An explicit selection before Play takes precedence. Pause/resume never restarts timing.
- **Start this leg** selects any valid geometric leg at the current simulated time with its full distance remaining. Starting the selected leg is presented as **Restart from now**. Only one countdown is visible/active.
- Allow Start/Restart while paused; no estimated travel accrues until Play. These actions never change heading, airspeed, radios, flight time, checklist, recording, or completion.
- Each manual Start/Restart saves the prior timing context for one Undo, replacing any older Undo context. Save the selected leg, timing reference, accumulated estimated travel, exact expiry timestamp if any, and consumed playback-return state.
- Advance the selected context **and the saved Undo context** on each accepted simulated segment using that segment's airspeed. This lets Undo restore what the prior estimate would show now, including an expiry during its inactive interval, without reconstructing speed changes from one-second recording samples or keeping an unbounded history. Only the selected context may trigger playback assistance.
- Undo restores that saved context and clears Undo availability. If there was no previous selection, return to the unselected timing state. Undo does not rewind the aircraft/clock/checklist, reverse a playback change, or re-arm a consumed return. Before the first Play, undoing an explicit selection back to none allows the ordinary first-Play policy; after first Play, Undo never repeats automatic startup.
- A new manual Start/Restart creates a fresh timing context and fresh one-time return eligibility. Fly Again clears selected progress, Undo, expiry, first-Play handling, and return consumption. Completion, simulation error, or leaving the mission stops live advancement/actions.

### Estimated distance and exact expiry

- Accumulate `airspeed × acceptedSimulatedSeconds / 3600` NM from each context's reference. Earlier travel keeps the airspeed that applied then. Do not multiply by playback again.
- Before expiry, remaining time is `remainingEstimatedNM / currentAirspeed × 3600`; updated reach time is current simulated elapsed time plus remaining time. All progress assumes the selected leg is being flown correctly, including during turns; it measures no actual route progress.
- Example: a 20-NM leg, 300 simulated seconds at 120 kt, then 240 kt, has 10 estimated NM and 150 simulated seconds remaining. The original schedule is unchanged.
- At the first crossing of the full leg distance, retain the exact simulated expiry timestamp, including crossings within a large advance. Afterward show **Past still-air estimate: m:ss**, based on current simulated time minus that timestamp. Preserve the timestamp as the updated estimated reach time; do not let it drift forward on each render.
- After expiry, speed edits do not restart the count-up or reverse it into a countdown. Pause freezes it. Arrival, checklist completion, starting another leg, and Flight Complete remain manual.
- At 0 kt before expiry, retain accumulated progress and show **Unavailable at 0 kt** for current remaining/reach estimates and next duration. The original schedule stays visible. Resume estimates from retained progress when speed becomes positive. At 0 kt after expiry the count-up still advances with simulated time. Wind drift must never substitute for zero airspeed.
- Non-finite/negative current airspeed or non-finite derived live estimates show **Timing unavailable** and cannot trigger assistance. Preserve the existing session guards against advancing invalid controls; do not present a false zero or alter flight physics to recover from invalid timing arithmetic.
- At mission launch before first Play, show **Not started** for the current leg's live countdown; the original schedule remains readable. Under automatic startup, a leg-1 label and leg-2 duration preview may be shown as preparation, but no elapsed progress is claimed. Under manual startup show **Select a leg to begin timing** until selection; do not infer current/next from checkboxes.
- Next means the immediately following **geometric** leg after the selected leg. Show its full duration at current airspeed, with no elapsed progress and no separately updated arrival forecast. Omit next when there is no following leg. All further legs retain original planning values only.

## Interface contract

- The briefing adds a **Still-air schedule at 260 kt** section, using the actual mission baseline, listing leg number, endpoint labels, distance, planned duration, and planned reach time. Keep existing NAV instructions and wind setup separately readable and scrollable.
- The live mission panel keeps the full original schedule, current updated reach time, Start actions on unselected legs, Restart on the selected leg, and Undo disabled when unavailable. Keep existing checklist, elapsed clock, wind reference, and Flight Complete reachable. Labels refer to **flight time**, not wall-clock time or the computer's local time.
- Add reusable `MissionTimingViews.swift` for the shared schedule, formatting, summary, and controls; do not duplicate Transport-specific timing calculations in SwiftUI.
- A compact **56-point** strip sits between the chart/panel row and the full-width cockpit, spanning the flight surface and remaining visible when the mission panel is hidden. Show the current leg identity and estimated remaining/past time plus the next identity and duration at current airspeed. Include **Still-air**. Full labels can be available in the panel/help when compact labels truncate.
- Give `MapView` a caller-supplied generic flight-status content slot and reserved height, defaulting to empty/0. Subtract that height when calculating chart/panel space and keep existing cockpit sizing. The map draws supplied content; it does not learn mission timing rules or inspect a mission ID. Do not overlay the strip on instruments or chart controls. Free Flight/Practice pass no slot and retain their layout.
- No timing data: omit the strip and controls. Invalid supplied timing: use the reserved strip to show **Timing unavailable**, with a reason in the mission panel, and disable timing/assist. Do not show fake zero values or remove the ordinary mission flow.
- Planned duration/reach values round from unrounded seconds to the nearest second. Current countdown and positive next duration round upward so a positive estimate never displays 0:00. Past-estimate time rounds downward. Use `m:ss`, adding hours when needed; updated reach values are explicitly labeled as elapsed flight times. Existing raw numerical values/tolerances stay unchanged.
- With 0–60 seconds remaining, use a distinct approach style; after expiry use the **Past still-air estimate** label. Neither state means arrival or error. No audio, notifications, map markers, or new arrival rules.
- Verify readability and scrolling at **1100×760** and larger sizes, both panel states, and long/repeated point labels. Visual adjustments to the 56-point height must be recorded with the minimum-window result, not compensated by shrinking cockpit instruments or changing the app minimum size.

## Optional return to 1×

Stage 3 adds **Return to 1× with 1 minute remaining**, off by default. Starting a timed leg and automatic return are separate actions; neither changes the checklist.

### Preference lifetime and one-time behavior

- Keep the enabled choice in the briefing's lifetime, just as the wind draft survives returning from flight. Supply it to the shared runner through a binding/callback; the runner/session must not depend on Transport. The live toggle writes the choice back to its launcher.
- A newly opened briefing starts off. Fly Again and Back to Briefing retain the choice within that briefing; a newly opened briefing and app launch do not restore it. The Debug runner owns an equivalent local choice. No persistent settings storage is added.
- The session owns the effective per-flight enabled flag and the selected context's consumed state. Its fresh-mission operation carries the enabled choice while clearing progress/consumption. Explicitly starting/restarting a leg re-arms its new context.
- Eligible means: valid timing, selected unexpired leg, positive airspeed, Play active, option enabled, return not consumed, playback greater than 1×, and estimated remaining time at most 60 simulated seconds.
- If an eligible leg is already inside that interval when Play resumes, the option is enabled, the speed changes, or faster playback is selected, return to 1× before consuming more accelerated time. This includes legs shorter than one minute. Paused flights wait for Play.
- After an automatic return, mark it consumed for that timing context. The player can accelerate again freely. Option toggles, pause/resume, speed edits, and checklist edits never re-arm it. Undo restores the previous context's consumed state and never replays an already-used return.
- If the option is first enabled after the estimate has expired, show the past-estimate state and do not change playback. Only an explicit new Start/Restart can create a new eligible context. A zero-speed unavailable estimate cannot trigger assistance.
- Passing the threshold at 1× does not consume a return that never occurred. A later selection of faster playback while still unexpired and inside the interval may use that context's single return.

### Split wall time at the threshold

Changing the multiplier after processing an entire update is insufficient. Refactor the existing session advancement into an internal operation that advances a specified simulated duration using the current trajectory, existing compensated clock, recording, and first-exit calculation. Keep `advance(wallElapsed:)` as the public delivery entry point.

1. Validate the input/current controls as today. With timing absent, assistance off, or no eligible upcoming return, retain the ordinary path. Stage 2 must not change wall-to-simulated-time conversion.
2. With an armed current estimate at constant speed during the delivered interval, calculate simulated seconds until its remaining-time estimate becomes 60. Convert that to wall time using the current multiplier.
3. Advance through the earlier of the remaining wall interval or that threshold. For each accepted simulated segment, advance timing and Undo contexts by the **actual** accepted duration. Do not advance them past chart exit or an error.
4. If the flight ended at/before the threshold, completion wins: stop processing remaining wall time, do not emit an extra sample or apply the playback return after completion. Preserve earliest outward crossings, including curved exit/re-entry.
5. Otherwise, at the threshold consume the return and set playback to 1×. Advance any remaining wall time at 1×. An immediate in-threshold return consumes no wall time before switching; its consumed state prevents a zero-length loop.
6. Keep the same integer-second recording schedule across split trajectories, exact ending sample, and existing clock compensation. Expiry may occur within a segment even with assistance off; stamp it analytically from remaining estimated distance and speed.

Independent reference case: a 20-NM leg at 120 kt starts at simulated 0, playback 30×, assist on. A **20-second wall advance** reaches the threshold at **540 simulated seconds / 18 wall seconds**, then advances the remaining 2 wall seconds at 1×. Final elapsed time is **542 simulated seconds**, with **58 estimated seconds remaining** and **543 recording samples** at timestamps 0…542. A naive 600-second result is a failure. Also verify a fractional threshold and a chart exit coincident with the threshold.

This refactor is confined to session advancement and the pure timing model. Do not replace the trajectory, crossing solver, timer delivery task, world calibration, or recorder algorithm. If that wider change becomes necessary, stop and explain options.

## Files to create or change

All paths below are relative to the repository root. No project-membership edits are needed.

| File | Stage | Responsibility |
| --- | --- | --- |
| `Xcode Proj/VOR Vocational/Domain/FlightPlanning/MissionTimingSchedule.swift` (new) | 1 | Timing legs, validation/availability, fixed schedule, explicit startup policy. |
| `Xcode Proj/VOR Vocational/Domain/FlightPlanning/FlightPlanBriefing.swift` | 1 | Attach schedule separately from existing NAV instruction steps; update chart-only comment. |
| `Xcode Proj/VOR Vocational/Domain/FlightPlanning/MissionFlightDefinition.swift` | 1 | Optional timing input and route adapter; preserve generic mission defaults. |
| `Xcode Proj/VOR Vocational/Features/Missions/MissionTimingViews.swift` (new) | 1–3 | Read-only schedule first, then live strip/controls, then assist control. Shared labels/formatting. |
| `Xcode Proj/VOR Vocational/Features/Missions/TransportBriefingView.swift` | 1, 3 | Render schedule; later own retained assist choice and pass it to runner. |
| `Xcode Proj/VOR Vocational/Domain/FlightPlanning/MissionLegTiming.swift` (new) | 2–3 | Selected/Undo contexts, speed-based progress, expiry, next preview, consumed-return state and threshold calculation. |
| `Xcode Proj/VOR Vocational/Features/Flight/FlightSession.swift` | 2–3 | Timing lifecycle and accepted-time updates; later exact playback-return splitting. |
| `Xcode Proj/VOR Vocational/Features/Missions/MissionFlightView.swift` | 2–3 | Shared panel actions/strip, reset flow, assist preference bridge, Debug-only alternate inputs. |
| `Xcode Proj/VOR Vocational/Features/Map/MapView.swift` | 2 | Generic status slot and geometry reservation; leave timer delivery and mode policies intact. |
| `Xcode Proj/VORVocationalTests/NavigationCoreTests.swift` | 1–3 | Meaningful schedule, timing, Undo, lifecycle, event and regression checks in the existing target. |
| `README.md`, `IDEAS.md`, this plan | Each checkpoint | Delivered behavior, verification, trial path, resume state, owner choice. |
| `Explorations/I-011-mission-leg-timing.md` | Planning / material clarification | Link this plan as the resolution of handoff questions; preserve owner decisions. |

`FlightPlan.swift`, the resolver, simulation math/recording files, debrief, surface presets, app scenes, bundled data, and project settings should not need changes. Stop if a necessary change falls outside this file map instead of silently broadening it.

## Stage 1 — Inspect the complete still-air schedule

**State:** Implemented and verified automatically; owner authorized commit and continuation on 2026-10-16. Exact minimum-window and synthetic-preview visual checks remain recorded below.

- [x] Read current records/source, preserve the existing exploration edits, and run the baseline macOS suite before source changes. Record the actual baseline count; the README reports 57 historical passing tests, not a result from this planning turn.
- [x] Add timing input/validation/startup values and derive the schedule from every resolved geometric leg without modifying the route or instruction sequence.
- [x] Carry the same schedule through the briefing and mission definition; no live timer starts in this stage.
- [x] Add the shared schedule view/formatting and expose all five Transport legs in its existing scrollable briefing, alongside unchanged NAV instructions and wind setup.
- [x] Add distinct in-memory schedule previews/tests at 120 kt, with no terminal reference, repeated labels, and invalid timing input. Do not edit bundled content or add a production catalog mission.
- [x] Verify the automated checks below, update README/IDEAS with Stage 1 delivered versus later behavior, and record the result here. Visual review limits are explicit in the execution log.

**Verification:** Full suite and Debug build. Assert Transport's unrounded timed-leg distance sum is **99.18027355 NM** and duration sum is **1373.2653260866 s** at 260 kt using existing 1e-6 expectations; last cumulative arrival equals the total. Assert the final timed leg exists while the terminal instruction still has `nil` distance. Use an independent 20-NM/120-kt schedule (600 seconds) and multi-leg cumulative sums. Invalid/absent input must never generate NaN/infinity/fake zeros or prevent ordinary mission construction. Switching Calm/Steady leaves all planning values identical.

**Visible checkpoint:** Home → Missions → Transport → Briefing. Read durations and flight-time reach values for all five legs, scroll through unchanged NAV guidance/wind, resize to 1100×760, and compare Calm with editable Steady wind. Select the named synthetic schedule previews in Xcode to inspect the 120-kt and unavailable cases.

**Commit point:** Show verification and this trial path, then stop before Stage 2 source changes. Suggested commit: **`Show still-air timing for every mission leg`**. The owner may commit or explicitly choose to proceed without committing; record that choice.

- [x] Owner chose to commit Stage 1: “Commit and then proceed.” No additional visual review result was supplied.
- [x] Owner explicitly authorized Stage 2 with the same instruction.

## Stage 2 — Use current and next timing in flight

**State:** Authorized; begins after the Stage 1 commit.

- [ ] Add the pure timing model and bounded selected/Undo context advancement, exact expiry, zero-speed/unselected/unavailable states, and next-leg preview.
- [ ] Integrate timing startup, controls, accepted-time updates, and retry/completion into `FlightSession`. Preserve the existing movement/clock path; do not add automatic playback return yet.
- [ ] Add the generic MapView status slot and live timing strip; add schedule/current reach and Start/Restart/Undo controls in the mission panel independently of checkboxes.
- [ ] Extend the existing Debug-only Mission Runner Preview with named in-memory presets: **Timed 20-NM route with a 4-NM next leg at 120 kt**, **Manual start away from origin**, **No timing**, and **Invalid timing**. Use a simple development-only preset selector; switching presets visibly resets that preview's flight. Do not change app scenes or production missions.
- [ ] Verify the cases below and minimum-window layout with panel open/hidden. Update docs with implemented timing and the still-pending optional assist.

**Verification:** Full suite and Debug build. Cover first Play versus resume, explicit pre-Play selection/Undo, selecting any geometric leg, paused starts, one-level Undo, speed changes, zero speed, expiry, post-expiry speed edits, final-leg next omission, unavailable timing, completion before Play, Fly Again, and leaving a flight. In particular:

- 20 NM: 300 s at 120 kt then 240 kt gives 10 NM/150 s remaining. A further 150 s reaches expiry at flight time 450; another 45 s displays 45 s past that estimate. Pause adds neither progress nor past time.
- Undo history: start A (20 NM) at 0, fly 300 s at 120 kt, start B (5 NM), fly 60 s at 240 kt, then Undo. A has 6 NM/90 s remaining, not the old 10 NM/150 s snapshot. A separate case must expire the saved A context while B is selected and restore the correct past-estimate time.
- With assistance absent/off, changing heading, wind, or start position inside the chart leaves timing identical for equal speed/simulated-time histories before completion. Changing checklist state or starting/restarting/undoing timing must leave movement, sample timestamps, samples, conditions, and ending unchanged for the same controls.
- Compare regular and irregular advances at 1×, 5×, 10×, 30× over at least one simulated hour with speed changes. New timing distance error must be ≤1e-6 NM and remaining/expiry-time error ≤1e-6 s versus independent piecewise arithmetic; use compensated accumulation if needed. Retain every existing motion, recording, boundary, and debrief acceptance unchanged.

**Visible checkpoint:** Fly Transport, note the countdown and next preview, hide/show the mission panel, change airspeed, pause/resume, and start the next leg without changing checkmarks. Try Restart and Undo, including after speeding up time. Use Debug → Mission Runner Preview and the named presets to inspect the exact 20-NM example, a manual startup, missing data, and invalid data. Read a past estimate; Flight Complete still opens the existing debrief, and Fly Again resets timing.

**Commit point:** Show verification and live trial path, then stop before Stage 3 changes. Suggested commit: **`Add live mission leg estimates and timing controls`**.

- [ ] Owner reviewed Stage 2 and chose whether/how to commit.
- [ ] Owner explicitly authorized Stage 3.

## Stage 3 — Optionally return playback to 1×

**State:** Not started; requires Stage 2 checkpoint decision.

- [ ] Add the retained per-briefing enable choice and its shared-runner bridge; default off. Expose the toggle in the live timing controls with the exact one-minute condition.
- [ ] Add pure threshold/eligibility and per-context consumed state. Preserve one-shot behavior through Undo, pause, speed edits, toggles, and manual overrides; apply the short-leg/in-threshold/expired rules above.
- [ ] Refactor session advancement only as specified to consume a delivered wall interval on both sides of the threshold, honor earlier/coincident endings, and advance timing/Undo from accepted simulated time.
- [ ] Add a **Short leg** development preset to the existing preview, keeping selectable absent/manual/invalid cases. Verify after-the-fact enabling and preference retention without persistent storage.
- [ ] Run the event/regression checks below and full suite, Debug/Release builds, and visual checks; update all delivered-state records and this checkpoint. No optional assist appears in Free Flight/Practice or the debrief.

**Verification:** Prove the 20-wall-second reference produces 542 simulated seconds, 58 s remaining, multiplier 1, and exactly timestamps 0…542. Compare a single large advance against independently partitioned wall advances with the same assist event; include fractional thresholds, a turning trajectory, and recording samples on both sides of the split. Preserve existing endpoint error ≤1e-7 NM for independent analytic geometry, playback partition position error ≤1e-6 NM, heading error ≤1e-7°, and crossing/elapsed error ≤1e-6 s. Do not widen old assertions. Also cover:

- Assist off: a 20-wall-second/30× advance of that flight still gives 600 simulated seconds; enabling no assist must not change the old numerical path.
- An event that returns to 1× once, then manual acceleration that remains selected; explicit Restart re-arms; toggling off/on and Pause do not re-arm a consumed context.
- A short leg and speed jump inside 60 s; enabling while paused; zero airspeed; enabling after expiry; 1× threshold passage followed by a later acceleration; Undo of consumed and unconsumed contexts.
- Chart exit before or exactly at the proposed return: completion wins, no advancement/sample after the actual exit, no post-completion playback action. Exercise a curved exit/re-entry, not just an outside endpoint.
- Fly Again and Back to Briefing retain the enabled choice but reset progress/consumption; a fresh briefing starts off. Wind changes never change any still-air schedule/threshold for the same speed and simulated timing inputs.
- Normal mission truth remains hidden, the final reference remains guidance, and recordings/debrief still describe the flight actually completed. Existing one-hour motion/recording, boundary, and debrief suites remain green.

**Visible checkpoint:** In Transport or the timed Debug preset, leave assistance off and use 30×; repeat with it on and observe the one-minute return. Accelerate again to confirm manual control, start/restart a leg to allow another return, and inspect a short leg and a past estimate. Hide the mission panel during the approach, resize to 1100×760, and confirm the strip and cockpit remain readable. Complete with unchecked instructions and inspect the unchanged debrief; retry/return to briefing to verify choice retention.

**Final commit point:** Show verification, trial path, and any visual review limits, then stop for owner acceptance/commit. Suggested commit: **`Add optional return to normal mission playback`**. Do not accept I-003's separate review or archive this plan before final acceptance.

- [ ] Owner reviewed Stage 3, including the normal minimum window, and chose whether/how to commit.
- [ ] Owner accepted the feature. Ask whether I-011 should remain in the index now that more than half (here all) of its scope is delivered; never remove it without the answer.
- [ ] Update I-011's exact entry with the honest delivered/next state or remove it only if authorized; remove its completed Plan field. Keep deferred wind planning separate. Update README to actual behavior, then move this completed plan to `Plans/Archived/` and repair retained links.

## Verification commands and stopping rules

Use the existing shared scheme/test plan and signing settings from the repository root:

```sh
xcodebuild test -project 'Xcode Proj/VOR Vocational.xcodeproj' \
  -scheme 'VOR Vocational' -destination 'platform=macOS' \
  -derivedDataPath /tmp/VOR-I011-DerivedData

xcodebuild build -project 'Xcode Proj/VOR Vocational.xcodeproj' \
  -scheme 'VOR Vocational' -destination 'platform=macOS' \
  -configuration Debug -derivedDataPath /tmp/VOR-I011-DerivedData

xcodebuild build -project 'Xcode Proj/VOR Vocational.xcodeproj' \
  -scheme 'VOR Vocational' -destination 'platform=macOS' \
  -configuration Release -derivedDataPath /tmp/VOR-I011-DerivedData
```

Run Debug/test checks per stage; Release is required at the final stage. Run the built Debug app at `/tmp/VOR-I011-DerivedData/Build/Products/Debug/VOR Vocational.app`. Record actual commands, results, numerical evidence, trial state, remaining limitations, and the owner's checkpoint decision in this plan. Check `git diff --check` and local document links. Do not claim visual verification from a thumbnail/blank capture; leave an explicit owner review item when tooling cannot show the normal window.

If signing is unavailable in the sandbox, use the ordinary approved local build access; do not disable signing or change project settings. Investigate an unexpected test failure enough to explain it, then stop with options if it lies outside this plan. Also stop for a missing prerequisite, required change to bundled data/fixtures/tolerances/configuration, or an architectural change beyond the timing model, session event splitting, and generic status slot defined here. Do not silently alter the plan to bypass a failure or proceed beyond an owner checkpoint.

## Planning verification and resume log

- [x] Read current project records, the complete I-011 exploration, relevant source/tests, and active plan constraints; record the two baseline documentation discrepancies above.
- [x] Resolve the exploration's engineering handoff: zero/invalid states, startup precedence, bounded Undo, exact expiry, one-time return, short-leg behavior, event priority, preference lifetime, formatting, and visible alternate inputs.
- [x] Check this plan's links/whitespace and update I-011's index entry and linked exploration to Planned. README links to the saved plan; no implementation is claimed.
- [x] Owner chose to begin Stage 1 on 2026-10-16: “Let's begin implementing the I-011 plan.”

Planning checks on 2026-10-16: `git diff --check` passed; all **12 local document links** resolve and all **12 file-map entries** identify existing files or one of the three explicitly new files. No source, test, content, project configuration, or existing active plan changed.

The planning-only change ran no app tests/builds. Stage 1 results follow; later implementation stages and owner checkpoint choices remain pending.

### Stage 1 execution — 2026-10-16

- Preserved the pre-existing exploration, glossary, and document/archive changes. No I-003 plan content or archive location was changed and its separate review remains unaccepted. Two README/IDEAS links still targeted its old location after the owner's existing archive move; repaired those links to the file already in `Plans/Archived/`. Corrected README's development-window menu labels to **Debug**, matching the source.
- Before source changes, ran the test command in **Verification commands** with output at `/tmp/VOR-I011-baseline.log`. The sandbox could not access the existing Mac Development certificate and blocked a test-progress notification. Repeated the identical command using approved local build access: **57 tests, 0 failures**, `TEST SUCCEEDED`; signing settings were not changed.
- Added immutable validated schedule values with ordinal leg identity and explicit startup policy. The route adapter uses the assigned initial/planning airspeed and all geometric legs; generic producers default to manual policy and may omit timing. Invalid supplied input retains an explicit reason with no partial schedule. Added the shared schedule view, read-only formatting, and three named synthetic Xcode previews; Transport renders the schedule separately from wind and NAV guidance.
- Ran `xcodebuild test -project 'Xcode Proj/VOR Vocational.xcodeproj' -scheme 'VOR Vocational' -destination 'platform=macOS' -derivedDataPath /tmp/VOR-I011-DerivedData` using the same approved access: **64 tests, 0 failures**, `TEST SUCCEEDED`. Log: `/tmp/VOR-I011-stage1-test.log`.
- Ran `xcodebuild build -project 'Xcode Proj/VOR Vocational.xcodeproj' -scheme 'VOR Vocational' -destination 'platform=macOS' -configuration Debug -derivedDataPath /tmp/VOR-I011-DerivedData` using the same access: **BUILD SUCCEEDED**. Log: `/tmp/VOR-I011-stage1-debug.log`. Release remains required at Stage 3. Test-build warnings were the existing weak-variable suggestion and AppIntents metadata notice; no new source warning appeared.
- Passing numerical assertions: **5** Transport timing legs; distance sum **99.18027355 NM** and duration/cumulative reach **1373.2653260866 s** at 260 kt, each within **1e-6**. The fifth timed leg ends at Midland, while the fifth instruction remains the Elmstead reference with `nil` distance. Independent 20-NM/120-kt input gives **600 s**; cumulative fractional times use unrounded durations. Repeated labels retain distinct ordinals. Tiny positive input adds no minimum distance. Empty, non-positive, non-finite, overflowing, and unrepresentable timing is unavailable. Invalid/absent timing preserves ordinary movement/recording/completion; Calm/Steady and cockpit speed edits preserve the original schedule.
- Launched `/tmp/VOR-I011-DerivedData/Build/Products/Debug/VOR Vocational.app` and checked **Home → Missions → Transport → Briefing**. Full-resolution full-screen and larger normal-window captures showed readable schedule rows, `7:07`, `5:34`, `5:52`, `4:18`, and `0:03` planned durations, and final reach **22:53 flight time**. Scrolling reaches wind, all five NAV instructions, the final reference text, and Fly Transport. Switching Steady/Calm leaves schedule values identical. Left the app on the Calm briefing schedule.
- **Visual limits:** the first normal-window capture was a distorted thumbnail; a later capture was readable, but attempts to set the exact **1100×760** size did not establish that size. Owner must check minimum-window scrolling/readability. The named **120 kt — 20 NM and 4 NM**, **Repeated long labels — 120 kt**, and **Invalid timing — flight remains available** previews compile but were not rendered for visual acceptance. Select them in Xcode in `MissionTimingViews.swift`; the 120-kt route without a terminal reference is also covered by a passing resolver/adapter test.
- Final checks: `git diff --check` passed, new source files have no trailing whitespace, and all **12 local document links** in README, IDEAS, glossary, this plan, and the I-011 exploration resolve. No Stage 2 source changes, dependency/configuration changes, bundled content edits, fixture/tolerance changes, or commit were made. **Waiting at the Stage 1 commit point for the owner's review and commit/proceed choice.**

- Owner then requested **“Commit and then proceed.”** Stage 1 is authorized for commit and Stage 2 may begin afterward. Pre-existing plan archive moves remain outside the feature commit; their two repaired README/IDEAS link targets remain working-tree edits alongside those moves. The committed documents retain links to the still-tracked plan location until that separate reorganization is committed. I-003 review acceptance remains separate.
