# VOR Navigator

VOR Navigator is a macOS teaching game for learning real VOR navigation in the fictional Myosia region. The player works from a chart and recognisable NAV instruments to build a mental picture of position and route. It is a compact navigation sandbox, not a full flight simulator or a GPS map quiz.

## Current state

The first V0.3 Transport mission is playable. The app has a Home screen, a working Free Flight mode, stationary Position Challenge and timed Position & Heading Challenge exercises under Practice, and a supplied Transport briefing and live flight under Missions. Learn is still a catalog rather than a lesson. Transport offers Calm or editable Steady wind. Flight Complete or crossing outward through the full chart edge opens an unscored debrief with the planned route, recorded flown path, final position, fixed wind, simulated time, and direct distance from Midland Cityport. The debrief supports pan, pointer-anchored zoom, and Fit Flight. Scoring remains later work.

What can be tried today:

- Fly a heading-and-airspeed simulation with direct 3°/second turns, steady wind drift, pause, and playback controls. Physical movement uses the source chart calibration and is independent of window size, zoom, pan, or the displayed crop. Mission flights end at the first outward full-source chart crossing; Free Flight can move beyond the visible crop without a mission ending.
- Use two frequency-tuned NAV receivers with OBS, CDI display, TO/FROM indications, station range handling, and a NAV1/NAV2 swap.
- Pan and zoom the chart; show airports, VORs, selected-station range rings, radials, a grid, and sightseeing markers.
- Start a Position Challenge, use the instruments to infer a hidden location, drag the precise circle marker to the guess, and see the error in nautical miles. Its center dot marks the exact guess; the circle's interior and surrounding buffer are draggable, and no heading arrow appears in this position-only exercise. Flight simulation cannot move it.
- Start a Position & Heading Challenge, then Begin to launch a hidden aircraft at 260 kt in still air. Tune both NAVs, drag the circle to the current estimated position, and use the heading knob for the estimated heading and arrow. Submit freezes distance error, shortest heading error, and elapsed awake time on the same chart; zoom, pan, and Fit Comparison inspect the exact Estimate/Actual centers and full arrows. Try Again starts a fresh randomized attempt. Back to Practice or Home discards it; reopening starts ready.
- Open Missions → Transport → Briefing to inspect the supplied Silverkeep-to-Midland route, its 99.2-NM still-air plan, and five VOR instructions; then fly it from Silverkeep using the cockpit instruments. The live mission deliberately hides the aircraft's true chart position and planned route.
- Read live Transport or Position Challenge instructions and results in the panel beside the chart, above the full-width cockpit. Use Hide Mission / Show Mission or Hide Practice / Show Practice beside Chart to collapse or reopen it.
- During Transport, scroll through all five instructions and check off each step yourself. Check or clear any step independently; hiding the panel retains your checks, and Fly Again clears them.
- In the Transport briefing, choose Calm or Steady wind. First selecting Steady wind generates editable direction (000–359°) and speed (5–25 kt); Randomize generates another pair. Manual speed accepts 0–40 whole kt. Invalid entries show their ranges and block launch until corrected; switching to Calm retains the Steady entries.
- Wind locks at launch and appears beside the live clock and in the result. While Play is active, 0 kt airspeed still permits wind drift; Pause freezes movement, turning, and simulated time.
- Select Flight Complete whenever you judge you have arrived, including before Play. The dedicated debrief replaces the cockpit and fits the complete planned and flown paths on the full source chart. A zero-time flight shows one start/finish point. Flying off the full chart opens the same debrief automatically with “Left the chart.”
- Mission recordings retain position, actual heading, and airspeed every simulated second, plus exact start and finish states. Pause freezes the clock and recording schedule; checklist edits never affect them. The debrief shows fixed conditions, simulated time, raw destination distance, and distinct planned/flown paths with start, finish, and arrival markers.
- Drag the debrief chart to pan; scroll to zoom around the pointer from 0.5× to 16× the fitted scale. The zoom buttons use the chart centre. Fit Flight restores the complete route/recording comparison, and resizing refits the same snapshot. All full-source edges remain reachable. The orange dashed planned route and dark blue solid flown path have contrasting halos and matching legend styles; screen-sized symbols and separated labels mark Start, Finish, and any named arrival reference. Coincident start/finish points share a marker; overlapping arrival symbols use leaders to their exact positions.
- Fly Again starts a fresh flight and recording with the same wind; Back to Briefing retains the editable wind draft and discards the previous flight. Recordings stay in memory for the current flight/debrief only. A scrollable summary keeps measurements and return actions beside the chart; no cockpit appears in the debrief.

[I-003 — Mission quality and debrief](Design/Archived/Plans/I-003-Wind-Recording-Debrief.md) has all three implementation stages committed, including interactive inspection in `0541bd7`. Its implementation checkpoint passed 57 tests and Debug and Release builds with the existing settings. The [archived exploration](Design/Archived/Explorations/I-003-mission-quality-and-debrief.md) retains the delivered scope and deferred weighting proposal. Final scoring requires a later exploration; no score formula or grade has been implemented.

I-003's recorded owner review items still include the normal 1100×760 layout and a debrief after a deliberate route correction. Full-resolution review covered the main debrief in full screen; tool capture of the alternate preview window remained unavailable at that checkpoint. Archiving its records does not claim those separate reviews were accepted.

[Mission leg timing](Design/Archived/Plans/I-011-Mission-Leg-Timing.md) is complete and was accepted by the owner on 2026-10-20. The archived plan retains the implementation and verification record. Missions → Transport → Briefing shows one **Mission steps** list: each of the five instruction cards includes its still-air distance, planned duration, and planned reach at 260 kt. The final reference card identifies timing for the intersection-to-airport segment while retaining the Elmstead NAV cue. During flight, first Play starts leg 1 unless the player has already selected another. A 56-point strip above the cockpit shows the current leg's estimated remaining time and the next leg's full duration at current airspeed; it stays visible with the mission panel hidden. The live panel uses that same single list, with NAV guidance, its checkbox, planned timing, and Start this leg / Restart from now together in each card. Current countdown/updated reach and the next-leg preview appear inside the relevant cards. A compact Undo header replaces the duplicate timing list and large timing summary. Use **Start this leg** when beginning each later leg: turning or checking off a step does not switch the selected timer. Timing starts remain independent of the five NAV checkboxes and never confirm arrival.

Speed changes preserve estimated travel already covered. Pause freezes progress; at 0 kt, unexpired estimates are unavailable while retained progress waits for positive airspeed. Expired estimates count time **Past still-air estimate** from their exact simulated expiry. The final leg has no next preview. Fly Again resets timing; Flight Complete and chart exit keep the existing debrief flow. Timing uses airspeed, accepted simulated time, and player-declared starts, without aircraft position, wind, heading, or recording samples. Calm/Steady wind never changes the original schedule.

**Return to 1× with 1 minute remaining** is available in the briefing and live panel, off by default. The return splits delivered wall time at the still-air threshold; later manual acceleration remains available. Each Start/Restart allows one return; Undo restores its prior consumption. Enabling after expiry does nothing, and zero airspeed cannot trigger it. Fly Again and Back to Briefing retain the choice within that briefing; opening a fresh briefing starts off. No persistent setting is stored. Wind planning remains separate later work.

The Debug **Mission Runner Preview** has named presets for a 20-NM/4-NM route at 120 kt, manual start away from origin, **Short leg** (1 NM / 30 seconds at 120 kt), no timing, and invalid timing; choosing a preset resets its flight. Absent timing omits the strip and controls; invalid timing shows **Timing unavailable** with a reason and keeps the mission flyable. That feature’s checkpoint passed **90 tests** and Debug/Release builds with existing settings. Full-screen Transport and the minimum-width Debug preview were visually checked with both panel states, long/repeated labels, scrolling, and an expired estimate. The compact preview also demonstrated the automatic return with the panel hidden, manual reacceleration, restarting a short leg, and enabling after expiry. Transport checks covered preference retention through live edits, retry, and returning to the briefing, plus a new briefing defaulting off. The owner accepted the feature after flight review. Earlier automation did not establish the exact 1100×760 main Transport window; the verified Debug preview's 1100×760 content includes its selector above the shared flight surface.

The shared mission runner accepts identity, starting state, route geometry, variable instructions, optional arrival reference, optional timing schedule, and fixed conditions as data. Silverkeep → Midland is its first integration; authored and generated missions can use the same runner. Recording, chart-exit ending, and debrief use this same shared flow. In a Debug build, Debug → Mission Runner Preview opens an alternate in-memory mission without adding a production catalog entry. Debug → Flight Diagnostics shows the main session’s conditions, heading, time, true position, recorded path, sample count/last timestamp, and ending reason over the full source chart, including after completion. These development windows are also listed in the Window menu.

## How to run it

Open [VOR Vocational.xcodeproj](<Xcode Proj/VOR Vocational.xcodeproj>) in Xcode, choose the shared **VOR Vocational** scheme and a macOS run destination, then Run. Start at Home; Practice offers **Position Challenge** and **Position & Heading Challenge**, Free Flight is ready to use, and Missions contains the playable Transport flight.

## How the app is arranged

| Area | Main responsibility |
| --- | --- |
| `App/` | Starts the app and switches among Home, Learn, Practice, Missions, and Free Flight. |
| `Features/Home/` | Home screen and mode cards. |
| `Features/Flight/` | A flight session, reusable surface configurations, the Free Flight wrapper, cockpit controls, and diagnostics. |
| `Features/Map/` | Draws and operates the chart: camera, aircraft marker, chart layers, receiver readings, and cockpit composition. |
| `Features/Practice/` | Both Practice exercises, moving-attempt ownership, precise result comparison, and the Debug preview. |
| `Features/Learn/` | Presents the not-yet-implemented lesson list. |
| `Features/Missions/` | Mission catalog, Transport content adapter, reusable wind setup, shared live runner, and shared unscored debrief. |
| `Domain/Navigation/` | Pure VOR calculations: station lookup, CDI behavior, TO/FROM logic, and distance-related navigation math. |
| `Domain/Simulation/` | Physical chart calibration, wind conditions, direct flight trajectories, chart-exit calculations, recordings, stationary targets, and moving-scenario validity/raw measurements. |
| `Domain/Models.swift` | Data models for VORs, airports, regions, and receiver readings. |
| `Content/` | Bundled Myosia chart artwork and JSON data for VORs, airports, and sightseeing regions. |
| `VORVocationalTests/` | Automated tests for the navigation core. |

The intended shape is simple: the world and aircraft state feed the receiver/instrument model; a mode decides what the player may see and do; SwiftUI draws the chart and controls. For Free Flight and missions, `FlightSession` owns movement, simulated time, locked conditions, recording, and both ending paths; `MapView` delivers monotonic timing. The mission debrief reads an immutable completed-flight snapshot. Moving Practice uses its own `MovingPositionChallengeSession` and SuspendingClock for hidden truth and elapsed awake time; its ordinary chart session only holds camera, chart aids, and receiver settings. Its immutable result is independent of comparison-camera changes.

## Product boundaries

- Myosia is a fixed fictional training world. Its geography is designed for learning; live aviation data is not a current dependency.
- The chart supports navigation but should not reveal the answer during normal mission play.
- The current model intentionally has heading, constant airspeed, steady wind, and playback speed only—no altitude, terrain, aircraft performance, gusts, or changing weather.
- The app is Mac-first and remains a single macOS target for the current roadmap.

The [I-005 moving position and heading challenge](Design/Archived/Explorations/I-005-moving-position-and-heading-challenge.md) is implemented in the normal Practice catalog and was accepted by the owner on 2026-10-21 after final review. Its three stages are committed through `9ed6913`; the [archived plan](Design/Archived/Plans/I-005-Moving-Position-And-Heading-Challenge.md) preserves verification and owner confirmation. **105 tests** and Debug/Release builds passed with existing settings. Guided lessons and combined scoring remain later work.

The moving exercise's status strip keeps Elapsed and Submit available with the panel hidden. Retry resets tuning, OBS, estimate, timer, and camera while retaining chart aids. Each generated scenario proves two-station coverage continuously for the first 600 seconds and a chart-exit buffer of at least that duration; finite failure offers retry without starting a flight. An attempt runs at fixed 1× while awake, including app switching/minimization, until Submit or first full-chart exit. SuspendingClock excludes system sleep; the archived plan records the owner’s final review confirmation.

**Debug → Practice Preview** (also **Window → Practice Preview**) offers **Random valid attempt** plus review fixtures. **Known eastbound attempt** validates the fixed 260-NM-east/150-NM-south, 090° example normally. **Generation unavailable** exercises retry failure, and **Near-exit attempt** deliberately bypasses the ten-minute/radio guarantee to reach the boundary in five seconds. **Truth** and **Use truth as estimate** are Debug-only review aids, off by default. Static Marker drag and tiny/coincident/wide/full-chart-edge presets remain available for marker and camera inspection. Normal ready/active/result layouts were checked at 1100×760 content and full screen, with both panel states, keyboard tuning, direct dragging, heading scroll, OBS rotation, and frozen inputs.

## Project documents

- [Design/IDEAS.md](Design/IDEAS.md) is the forward-looking list of active initiatives, ideas, blockers, and next slices.
- [Design/Glossary.md](Design/Glossary.md) defines the vocabulary used in discussion and UI.
- `Design/Explorations/` holds active design discussions, settled requirements, and remaining questions.
- `Design/Plans/` holds focused implementation plans while they are being worked.
- `Design/Archived/Explorations/` and `Design/Archived/Plans/` retain completed or superseded work. Update links when moving a record; preserve its decisions, verification, and any unaccepted review limits.
- `Design/Documents/` holds background references. The earlier ticket, ADR, execution-protocol, and glossary records remain under `Design/Archived/`; they do not define the current workflow.
