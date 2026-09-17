# VOR Navigator project direction

## The product in one sentence

VOR Navigator is a Mac and iPad teaching game where players learn real VOR navigation by planning and flying routes through a believable fictional region, using the same limited instrument information a pilot would have.

It should feel like a compact navigation sandbox, not a flight simulator and not a map quiz. The point is to build the player's mental picture of where they are, where they are going, and what the instruments are telling them.

## What must stay true

- The VOR model is real. Radials, OBS selection, CDI deflection, TO/FROM logic, signal range, station identification, DME when equipped, and intercept geometry must behave as they do in the aircraft context being taught.
- The map is a chart, not GPS. In most play, the aircraft's true position and trail stay hidden. The player infers them from NAV1, NAV2, heading, time, and the chart.
- The player manipulates recognisable instruments. They tune frequencies and turn the OBS. The app should not turn these actions into a menu that gives away the answer.
- The game teaches through consequences and explanation. It lets players make a reasonable wrong choice, shows the result, and then explains the geometry in an optional debrief.
- Geography creates navigation decisions. It should never overwhelm the central activity of interpreting and using VOR instruments.

## The core play loop

> Tune -> interpret -> decide -> turn -> intercept -> track -> prepare the next station -> switch -> repeat.

The simulator owns the true aircraft state. Each receiver derives only the indication that its tuned, in-range station would show. The UI renders those indications. Challenge rules decide what chart information and help the player sees.

The initial flight model can stay simple: chosen heading, constant airspeed, continuous movement, and enough altitude/performance data to support the mission. It does not need aerodynamic simulation to teach VOR navigation well.

## Learning and game modes

The modes share one navigation engine. They differ in what the player is asked to do and how much help the chart gives them.

| Mode | Player task | Why it matters |
|---|---|---|
| Learn / Explain | Work through a small concept, with an explanation and optional animation after an answer | Ground-school style teaching of the instrument logic |
| Position Fix | Tune two stations, set OBS courses, read the indications, and place the hidden aircraft on the chart | Makes radial intersections concrete |
| Radial Intercept | Establish and hold a specified radial from one station | Teaches CDI interpretation, TO/FROM, turns, and tracking |
| Route Builder | Plan a VOR route between two airports within stated limits | Turns isolated skills into route reasoning |
| Flight Plan | Fly a supplied multi-leg route, including tuning, intercepts, tracking, and station changes | The main live-navigation experience |
| Navigation Challenge | Fly with fewer hints, controlled time compression, accuracy goals, and a score | Gives practiced players replayable pressure |
| Free Navigation, later | Choose an origin and destination and fly a self-planned route | An open practice space once the core is strong |
| Real World, later | Use maintained real-world NAVAID and geographic data | Transfer practice to actual places without making data maintenance the foundation of the app |

### Lesson and progression path

Progression should add one new responsibility at a time. The order matters more than a large lesson count.

1. Read one VOR: identify a radial, select an OBS course, and understand TO versus FROM.
2. Fix position with two VORs and place the aircraft on the chart.
3. Intercept and track one radial with visible position and generous feedback.
4. Fly a single-leg route with the aircraft hidden.
5. Plan and fly a two-leg route.
6. Manage NAV1 and NAV2, tune and identify the next station, and change stations at the right time.
7. Fly longer multi-leg routes with limited chart help.
8. Work under time and accuracy constraints.
9. Handle realistic complications: wrong frequency, lost identification, out-of-range signal, overhead passage, and a failed NAV receiver.
10. Combine navigation with terrain, aircraft limits, airspace, and eventually weather.

The early lessons can reveal the aircraft and show geometry. Later lessons hide the aircraft, the planned route, or selected chart detail. Difficulty should come from fewer aids and richer decisions, not arbitrary controls.

## NAV1 and NAV2 are part of the game, not duplicate displays

NAV1 normally carries the active leg. NAV2 is the player’s preview and cross-check receiver. It remains a conventional VOR receiver, not a fictional magic distance or bearing display.

While tracking, for example, ABC R-090 on NAV1, the player can tune DEF on NAV2 and set progressively closer OBS values while approaching the next required DEF radial. Centered CDI observations at DEF R-005, R-010, R-012, and R-015 let the player judge their movement around DEF, estimate when the intercept will arrive, and prepare the turn.

This makes the long part of a leg purposeful:

1. Establish the current radial on NAV1.
2. Track it and maintain heading.
3. Tune, identify, and set up the next station on NAV2.
4. Sample useful NAV2 radials and predict the transition.
5. Switch and intercept the next leg.

The player should decide when an observation is useful. A score may reward good predictions and well-timed turns, but it should not force constant OBS fiddling.

## Pacing and time

Real geographic scale is important, but idle minutes are not the lesson. Preserve the rhythm of navigation while compressing quiet periods.

- Use shorter, deliberately designed legs in early training. A roughly 12 NM leg at 120 knots is about six minutes and can still contain an intercept, tracking, preparation, and transition.
- Provide manual simulation speeds such as 1x, 2x, 5x, 10x, and 25x where appropriate.
- In challenge play, automatically accelerate only after the player is established on course and no decision is near. Slow back to real time before a transition or intercept.
- Ask occasional prediction questions only when they teach the next decision, such as what NAV2's CDI should do or when a target radial will be crossed.

The rule is simple: compress low workload, not the navigation logic.

## The world and the chart

The main game should use a fixed fictional training region. The stations, terrain, cities, airports, lakes, coastlines, and passes stay in the same places. Players learn the region as a place: which VOR is the major western hub, which field lies in the valley, and where the mountain pass is.

Missions vary inside that world. The mission system chooses or creates routes that meet intended geometry and constraints, rather than randomly placing VORs or generating a whole new map. This keeps exercises interesting and solvable while providing repeat play.

The visual language should be a simplified VFR sectional, not a street map. It should use clear aviation-inspired symbols for VORs and VORTACs, airports and small fields, cities, terrain/elevation, water, and later special-use airspace. It may offer:

- a clean training chart with high contrast and extra labels;
- a sectional-style chart for normal play;
- a minimal or blind chart for advanced challenges.

Support regional, local, and flight-scale views so a large world remains usable on Mac and iPad. A 500 by 500 NM regional view, a roughly 100 by 100 NM local view, and a close flight view are useful targets, not rigid map sizes.

### Fictional first, real-world later

The training world uses real-world units and terminology, but fictional geography. This protects the core experience from changing NAVAID data and lets routes, terrain, and station spacing be designed for teaching.

Real-world mode is a later companion, not the core. It needs a maintained data pipeline and careful treatment of changing, limited, or decommissioned stations. It should draw on current aeronautical data only when the app is ready to own that responsibility.

## VOR network and map data

Use nautical-mile coordinates as the authoritative fictional-world coordinate system. The chart artwork is a rendering of this data, not the source of navigation truth. Distances and coverage circles then work directly without pixel conversion.

VOR service volumes should feel plausible and create a useful hierarchy:

| Service volume | Typical simulated range | Place in the world |
|---|---:|---|
| High | 120 NM | Major regional navigation hub |
| Medium | about 80 NM | Regional route station |
| Low | 40 NM | Local station near an airport, city, or geographic feature |

Ranges and restrictions remain configurable per station. Station density should be sparse enough to require planning, but rich enough to offer more than one route in the larger region.

```json
{
  "vors": [
    {
      "id": "RAV",
      "name": "Raven",
      "identifier": "RAV",
      "frequency": 113.6,
      "location": { "xNM": 142.5, "yNM": 287.0 },
      "type": "VOR",
      "serviceVolume": "high",
      "rangeNM": 120,
      "elevationFT": 1840,
      "dme": false
    }
  ]
}
```

`id` is the internal key. `identifier` is the displayed three-letter station code. The model can later add station restrictions, identification details, magnetic variation rules, and operating status without changing the central design.

## Terrain, aircraft, and constraints

Terrain should create route problems. A trainer with a 12,500-foot ceiling may need to use a 7,500-foot pass instead of crossing a 14,000-foot range directly. A higher-performing aircraft may have a different viable route. This turns terrain into a VOR planning problem rather than a visual obstacle course.

Introduce these in layers, after the player is comfortable with core VOR work:

- terrain elevation and mountain passes;
- aircraft cruise speed, operating ceiling, and range;
- airspace that cannot be crossed;
- time windows or arrival goals;
- weather and density-altitude effects.

Each mission generator result must be feasible for the chosen aircraft and constraints. The app should never ask the player to find a route that does not exist.

## Scoring and debrief

Reaching the destination is necessary, but it is not the whole score. Measure the quality of navigation:

- radial tracking accuracy;
- intercept and turn timing;
- time to establish the next course;
- transition prediction;
- correct station tuning and identification;
- route efficiency and constraint compliance;
- time, where the mission calls for it.

After a flight, reveal the true track beside the planned route and key instrument events. Explain missed or early transitions in terms of the chart and the indications the player had. This is where mistakes become useful instruction.

## Technical shape

Build one shared Swift navigation package, independent of SwiftUI and platform presentation. Its responsibilities include navigation math, station data, aircraft state, signal/reception rules, receiver indications, route and mission logic, simulation clock, and scoring.

The iOS and macOS apps share the package and SwiftUI views where practical, then adapt controls for touch and mouse or keyboard. On iPad, a landscape cockpit can pair chart and instruments. Mac can give the chart more room.

Keep these layers separate:

```text
World and aircraft truth
        -> receiver and instrument model
        -> challenge visibility and rules
        -> SwiftUI chart and controls
```

The UI asks what NAV1 or NAV2 would show. It does not query the aircraft's position to draw a hidden answer.

## MVP

Ship a small complete simulator before building the larger world.

- One compact fictional chart with 5 to 10 VORs and a destination.
- A constant-speed, heading-based aircraft simulation.
- Two independent NAV receivers with frequency tuning, OBS, CDI, TO/FROM, range handling, and station identification.
- Position Fix missions with a hidden aircraft and a map-tap answer.
- One-radial intercept and tracking missions.
- Clear scoring plus an explain/debrief view.
- A shared core that Mac and iPad both use.

The next release can add a fixed larger region, multi-leg flight plans, NAV2 transition practice, time controls, and procedural missions on the designed network.

## Later work

- More chart detail and scales.
- Route Builder and Free Navigation.
- Terrain, aircraft limits, airspace, time, then weather.
- Failure and degraded-signal scenarios.
- Real-world regions backed by maintained aeronautical data.

## Guardrails

- Do not make the core product dependent on live FAA data.
- Do not make the chart a substitute for the instruments or show the aircraft position by default.
- Do not make NAV2 more capable than the receiver model supports merely to fill downtime.
- Do not randomise the core geography. Generate missions within a designed world.
- Do not add flight-simulator complexity unless it creates a navigation decision worth teaching.

