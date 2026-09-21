# VOR Navigator

VOR Navigator is a macOS teaching game for learning real VOR navigation in the fictional Myosia region. The player works from a chart and recognisable NAV instruments to build a mental picture of position and route. It is a compact navigation sandbox, not a full flight simulator or a GPS map quiz.

## Current state

The V0.2 foundation is in place. The app has a Home screen, a working Free Flight mode, and a working Position Challenge under Practice. Learn and Missions have their own screens but are not functional lessons or flights yet.

What can be tried today:

- Fly a simple heading-and-speed simulation over the Myosia chart, with pause and playback-speed controls.
- Use two frequency-tuned NAV receivers with OBS, CDI display, TO/FROM indications, station range handling, and a NAV1/NAV2 swap.
- Pan and zoom the chart; show airports, VORs, selected-station range rings, radials, a grid, and sightseeing markers.
- Start a Position Challenge, use the instruments to infer a hidden location, drag the aircraft marker to the guess, and see the error in nautical miles. Its stationary guess marker cannot be moved by flight simulation.

## How to run it

Open [VOR Vocational.xcodeproj](<Xcode Proj/VOR Vocational.xcodeproj>) in Xcode, choose the shared **VOR Vocational** scheme and a macOS run destination, then Run. Start at Home; Free Flight is ready to use, and Practice contains Position Challenge.

## How the app is arranged

| Area | Main responsibility |
| --- | --- |
| `App/` | Starts the app and switches among Home, Learn, Practice, Missions, and Free Flight. |
| `Features/Home/` | Home screen and mode cards. |
| `Features/Flight/` | A flight session, reusable surface configurations, the Free Flight wrapper, cockpit controls, and diagnostics. |
| `Features/Map/` | Draws and operates the chart: camera, aircraft marker, chart layers, receiver readings, and cockpit composition. |
| `Features/Practice/` | The Position Challenge flow and its result panel. |
| `Features/Learn/`, `Features/Missions/` | Present the not-yet-implemented mode lists. |
| `Domain/Navigation/` | Pure VOR calculations: station lookup, CDI behavior, TO/FROM logic, and distance-related navigation math. |
| `Domain/Simulation/` | Flight movement and Position Challenge target generation/scoring. |
| `Domain/Models.swift` | Data models for VORs, airports, regions, and receiver readings. |
| `Content/` | Bundled Myosia chart artwork and JSON data for VORs, airports, and sightseeing regions. |
| `VORVocationalTests/` | Automated tests for the navigation core. |

The intended shape is simple: the world and aircraft state feed the receiver/instrument model; a mode decides what the player may see and do; SwiftUI draws the chart and controls. `MapView` still carries more live-session work than is ideal, so future additions should avoid making it a catch-all.

## Product boundaries

- Myosia is a fixed fictional training world. Its geography is designed for learning; live aviation data is not a current dependency.
- The chart supports navigation but should not reveal the answer during normal mission play.
- The current model intentionally has heading, constant airspeed, and playback speed only—no altitude, terrain, aircraft performance, or weather yet.
- The app is Mac-first and remains a single macOS target for the current roadmap.

## Project documents

- `IDEAS.md` is the forward-looking list: active initiatives, ideas, blockers, and next slices.
- `Glossary.md` defines the vocabulary used in discussion and UI.
- `Plans/` is created when a focused build plan is needed; finished plans are retained in `Plans/Archived/`.
- `Design/` is older reference material. Its flight-planning notes remain useful background, but its ticket, ADR, exploration, and execution-protocol process is retired.
