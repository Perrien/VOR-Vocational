# VOR Navigator

VOR Navigator is a macOS teaching game for learning real VOR navigation in the fictional Myosia region. The player works from a chart and recognisable NAV instruments to build a mental picture of position and route. It is a compact navigation sandbox, not a full flight simulator or a GPS map quiz.

## Current state

The first V0.3 Transport mission is playable. The app has a Home screen, a working Free Flight mode, a working Position Challenge under Practice, and a supplied Transport briefing and live flight under Missions. Learn is still a catalog rather than a lesson. Transport now offers Calm or editable Steady wind. It finishes when the player selects Flight Complete and reports the locked conditions, simulated elapsed time, and direct distance from Midland Cityport; path recording, automatic off-map endings, scoring, and a debrief are still pending.

What can be tried today:

- Fly a heading-and-airspeed simulation with direct 3°/second turns, steady wind drift, pause, and playback controls. Physical movement uses the source chart calibration and is independent of window size, zoom, pan, or the displayed crop. Aircraft can move beyond the visible crop in Free Flight too; there is no automatic chart-exit ending yet.
- Use two frequency-tuned NAV receivers with OBS, CDI display, TO/FROM indications, station range handling, and a NAV1/NAV2 swap.
- Pan and zoom the chart; show airports, VORs, selected-station range rings, radials, a grid, and sightseeing markers.
- Start a Position Challenge, use the instruments to infer a hidden location, drag the aircraft marker to the guess, and see the error in nautical miles. Its stationary guess marker cannot be moved by flight simulation.
- Open Missions → Transport → Briefing to inspect the supplied Silverkeep-to-Midland route, its 99.2-NM still-air plan, and five VOR instructions; then fly it from Silverkeep using the cockpit instruments. The live mission deliberately hides the aircraft's true chart position and planned route.
- Read live Transport or Position Challenge instructions and results in the panel beside the chart, above the full-width cockpit. Use Hide Mission / Show Mission or Hide Practice / Show Practice beside Chart to collapse or reopen it.
- During Transport, scroll through all five instructions and check off each step yourself. Check or clear any step independently; hiding the panel retains your checks, and Fly Again clears them.
- In the Transport briefing, choose Calm or Steady wind. First selecting Steady wind generates editable direction (000–359°) and speed (5–25 kt); Randomize generates another pair. Manual speed accepts 0–40 whole kt. Invalid entries show their ranges and block launch until corrected; switching to Calm retains the Steady entries.
- Wind locks at launch and appears beside the live clock and in the result. While Play is active, 0 kt airspeed still permits wind drift; Pause freezes movement, turning, and simulated time.
- Select Flight Complete whenever you judge you have arrived; the result shows simulated time and direct distance from Midland. Completion locks flight controls. Fly Again starts a fresh flight with the same wind; Back to Briefing retains the wind draft for editing.

[I-003 — Mission quality and debrief](Plans/I-003-Wind-Recording-Debrief.md) has reached its first owner checkpoint: steady wind and model-owned movement are implemented and behavior-verified, with minimum-window visual review pending. Stage 2 adds recording, off-map endings, and a first debrief; Stage 3 completes pan/zoom and visual verification. Scoring follows later. The [settled exploration](Explorations/I-003-mission-quality-and-debrief.md) retains the design requirements.

The shared mission runner accepts identity, starting state, route geometry, variable instructions, optional arrival reference, and fixed conditions as data. Silverkeep → Midland is its first integration; authored and generated missions can use the same runner. Recording and debrief will extend this shared flow in the remaining stages. In a Debug build, Window → Mission Runner Preview opens an alternate in-memory mission without adding a production catalog entry. Window → Flight Diagnostics shows the main live session’s conditions, actual/selected heading, time, and true position over the full source chart.

## How to run it

Open [VOR Vocational.xcodeproj](<Xcode Proj/VOR Vocational.xcodeproj>) in Xcode, choose the shared **VOR Vocational** scheme and a macOS run destination, then Run. Start at Home; Free Flight and Position Challenge are ready to use, and Missions contains the playable Transport flight.

## How the app is arranged

| Area | Main responsibility |
| --- | --- |
| `App/` | Starts the app and switches among Home, Learn, Practice, Missions, and Free Flight. |
| `Features/Home/` | Home screen and mode cards. |
| `Features/Flight/` | A flight session, reusable surface configurations, the Free Flight wrapper, cockpit controls, and diagnostics. |
| `Features/Map/` | Draws and operates the chart: camera, aircraft marker, chart layers, receiver readings, and cockpit composition. |
| `Features/Practice/` | The Position Challenge flow and its result panel. |
| `Features/Learn/` | Presents the not-yet-implemented lesson list. |
| `Features/Missions/` | Mission catalog, Transport content adapter, reusable wind setup, shared live runner, and unscored result. |
| `Domain/Navigation/` | Pure VOR calculations: station lookup, CDI behavior, TO/FROM logic, and distance-related navigation math. |
| `Domain/Simulation/` | Physical chart calibration, wind conditions, direct flight trajectories, and Position Challenge target generation/scoring. |
| `Domain/Models.swift` | Data models for VORs, airports, regions, and receiver readings. |
| `Content/` | Bundled Myosia chart artwork and JSON data for VORs, airports, and sightseeing regions. |
| `VORVocationalTests/` | Automated tests for the navigation core. |

The intended shape is simple: the world and aircraft state feed the receiver/instrument model; a mode decides what the player may see and do; SwiftUI draws the chart and controls. `FlightSession` now owns movement, simulated time, locked conditions, and manual completion. `MapView` delivers monotonic timing and presents the state; future additions should preserve that boundary.

## Product boundaries

- Myosia is a fixed fictional training world. Its geography is designed for learning; live aviation data is not a current dependency.
- The chart supports navigation but should not reveal the answer during normal mission play.
- The current model intentionally has heading, constant airspeed, steady wind, and playback speed only—no altitude, terrain, aircraft performance, gusts, or changing weather.
- The app is Mac-first and remains a single macOS target for the current roadmap.

## Project documents

- `IDEAS.md` is the forward-looking list: active initiatives, ideas, blockers, and next slices.
- `Glossary.md` defines the vocabulary used in discussion and UI.
- `Explorations/` holds each explored idea's linked design, settled requirements, and remaining questions.
- `Plans/` is created when a focused build plan is needed; finished plans are retained in `Plans/Archived/`.
- `Design/` is older reference material. Its flight-planning notes remain useful background, but its ticket, ADR, exploration, and execution-protocol process is retired.
