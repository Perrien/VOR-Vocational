# VOR Navigator project direction

## The product in one sentence

VOR Navigator is a Mac-first teaching game where players learn real VOR navigation by planning and flying routes through a believable fictional region, using the same limited instrument information a pilot would have. iPad support is a future direction, not a current target.

It should feel like a compact navigation sandbox, not a flight simulator and not a map quiz. The point is to build the player's mental picture of where they are, where they are going, and what the instruments are telling them.

## What must stay true

- The VOR model is real. Radials, OBS selection, CDI deflection, TO/FROM logic, signal range, station identification, DME when equipped, and intercept geometry must behave as they do in the aircraft context being taught.
- The map is a chart, not GPS. In most play, the aircraft's true position and trail stay hidden. The player infers them from NAV1, NAV2, heading, time, and the chart.
- The player manipulates recognisable instruments. They tune frequencies and turn the OBS. The app should not turn these actions into a menu that gives away the answer.
- The game teaches through consequences and explanation. It lets players make a reasonable wrong choice, shows the result, and then explains the geometry in an optional debrief.
- Geography creates navigation decisions. It should never overwhelm the central activity of interpreting and using VOR instruments.

## The core play loop

> Tune -> interpret -> decide -> turn -> intercept -> track -> prepare the next station -> switch -> repeat.

The simulator owns the true aircraft state. Each receiver derives only the indication that its selected, in-range station would show. The UI renders those indications. Mode rules decide what chart information and help the player sees.

The current flight model is deliberately simple: a selected heading, user-set constant airspeed, continuous movement, and a manual playback multiplier. It has no altitude, aircraft-performance, terrain, or weather model.

## Learning and game modes

A Skill Exercise defines one navigation problem. A Mode defines the rules around it. Learn and Practice use the same Skill Exercises at different levels of guidance. Missions combine several Skill Exercises around a concrete flight objective and always produce a score.

### 1. Learn

Learn introduces one concept or exercise at a time. It is a guided, pausable lesson that tells the player what to observe or do next, then explains why the instrument indication changes. The chart may show the aircraft, selected radials, and other geometry that makes the idea visible.

The player finishes a lesson by completing its required actions, such as centering a CDI or placing a position fix. Learn records completion, not a competitive score. It may show an explanation after a wrong attempt, then let the player retry without penalty.

### 2. Practice

Practice lets the player repeat a named exercise or supplied route with controls for the aids that exercise permits. A Position Fix practice run, for example, can reveal the aircraft, radials, or range rings while the player learns to make a fix. A radial-intercept practice run can show the target course and give feedback after each turn.

The player chooses when to begin another run and may change the available aids between runs. Practice reports the result, such as position error or tracking accuracy, but does not rank the player or impose a time limit unless that limit is part of the exercise itself.

### 3. Missions

Missions put several skills into one scored flight with a concrete objective, such as reaching another airport, visiting named landmarks, or recovering after an equipment failure. Before departure, the app states the objective, available instruments and chart aids, and scoring rules. Once the flight starts, it gives no step-by-step teaching prompt or answer-revealing hint.

Every Mission has a score. Depending on its objective, that score can include position error, tracking accuracy, time, correct station selection, transition timing, checkpoint passage, route efficiency, and successful arrival. The debrief appears only after the run, when it can reveal the true track, the correct solution, and the instrument events that mattered.

Position Fix and Radial Intercept and Track are Skill Exercises. Transport, Sightseeing, and Nav Failure are Missions. Real-world data is a future world-data source that can support any Mode once the app can maintain it.

### Skill Exercises captured so far

This is an unordered list of exercise ideas, not a curriculum or release order.

#### Position Fix

Position Fix asks the player to locate an unseen aircraft on the chart from VOR indications, then click the location they have inferred. After the player checks the answer, the app reveals the true location and reports the position error in NM.

1. **Independent Position Fix.** The player gets the chart and the task to find the aircraft. They must work out which VORs may be in range, select stations to try, use the working receivers to find radial intersections, and click the resulting position. A receiver gives no usable indication for an out-of-range station, so choosing stations is part of the exercise.
2. **Assisted Position Fix.** The app has already selected and tuned working VORs for the hidden location. The player reads the supplied receiver indications, finds their radial intersection, and clicks the chart. This removes station selection and tuning so the player can focus on turning VOR indications into a plotted position.
3. **Tracked Position Fix.** The aircraft moves continuously while the player works. The player first finds two in-range VORs, takes and marks a position fix, then waits for the aircraft to move and takes a second fix. The bearing from the first marked fix to the second is the aircraft's track. The player uses that bearing to set the heading dial. With no wind model, the required heading matches the derived track.

#### Radial Intercept and Track

The app places the aircraft at a random point inside a named VOR's service volume and gives the player an outbound radial to fly, such as the 135 radial FROM the station. The player selects the station, sets the OBS to the assigned radial, interprets the CDI and TO/FROM indication, chooses an intercept heading, then turns onto and tracks the radial.

The exercise ends after the player establishes and holds the assigned radial for its required distance or time. Learn can reveal the aircraft and course geometry. Practice can report intercept and tracking results. Missions can use the skill as one scored part of a larger flight.

### Mission types captured so far

This is an unordered list of Mission ideas, not a curriculum or release order.

#### Transport

Transport starts at one airport and asks the player to navigate to another. It turns individual VOR skills into a complete trip with an origin, destination, route, and arrival goal.

1. **Planned Transport.** The app provides the route to fly, including its VOR legs and intended courses. The player flies that plan by selecting stations, setting the OBS, intercepting and tracking each leg, and changing to the next station at the appropriate time.
2. **Self-Planned Transport.** The app provides an origin and destination but no route. Before departure, the player chooses the VOR legs and courses that will take them there, then flies the plan they made. This version tests both route planning and in-flight execution.

#### Sightseeing

Sightseeing starts at a named airport, sends the player through a set of named waypoints, and ends with a return to the departure airport. The player must fly within each waypoint's stated distance while using the chart and NAV instruments to stay oriented.

`SightseeingRegions.json` already defines 11 named Myosia regions with 16 checkpoints. Each checkpoint has a tolerance from 2 to 10 NM. The current app can display those checkpoint areas on the map, but it does not yet run a mission, detect checkpoint passage, or require the return flight.

#### Nav Failure

Nav Failure begins during a flight to a named destination airport when the aircraft's GPS fails. The player must use VOR position-fix skills to determine their current location and track, then choose how to recover.

1. **Emergency diversion.** The player declares an emergency and navigates to the nearest airport.
2. **Continue to destination.** The player charts a new VOR route from the determined position to the original destination airport, then flies it.

The current app has no GPS display, failure state, emergency-declaration flow, or route-mission system. Nav Failure is therefore a future Mission built on Position Fix and Transport.

#### Off-course Recovery

Off-course Recovery begins during a planned flight after the aircraft has drifted away from its active leg. The player determines their present position, chooses a radial and intercept that will rejoin the route, then establishes the aircraft on that route again. The Mission scores the recovery rather than treating the initial error as an automatic failure.

#### One NAV Down

One NAV Down gives the player a flight objective with only one working NAV receiver. The player must fly the route without the usual second receiver for preparing the next station or checking progress. The Mission scores completion of the objective and how well the player manages the single receiver through each station change.

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
- The current simulator exposes manual playback speeds of 1x, 5x, 10x, and 30x.
- In Mission play, automatically accelerate only after the player is established on course and no decision is near. Slow back to real time before a transition or intercept.
- Ask occasional prediction questions only when they teach the next decision, such as what NAV2's CDI should do or when a target radial will be crossed.

The rule is simple: compress low workload, not the navigation logic.

## The world and the chart

The main game should use a fixed fictional training region. The stations, terrain, cities, airports, lakes, coastlines, and passes stay in the same places. Players learn the region as a place: which VOR is the major western hub, which field lies in the valley, and where the mountain pass is.

Missions vary inside that world. The mission system chooses or creates routes that meet intended geometry and constraints, rather than randomly placing VORs or generating a whole new map. This keeps exercises interesting and solvable while providing repeat play.

The visual language should be a simplified VFR sectional, not a street map. It should use clear aviation-inspired symbols for VORs and VORTACs, airports and small fields, cities, terrain/elevation, water, and later special-use airspace. It may offer:

- a clean training chart with high contrast and extra labels;
- a sectional-style chart for normal play;
- a minimal or blind chart for advanced Missions.

The current Myosia chart is 500 NM wide and about 359 NM high, derived from its 1748:1254 artwork aspect ratio. It supports zoom and pan, but it has no separate regional, local, or flight-scale view modes. iPad support remains future work.

### Fictional first, real-world later

The training world uses real-world units and terminology, but fictional geography. This protects the core experience from changing NAVAID data and lets routes, terrain, and station spacing be designed for teaching.

Real-world mode is a later companion, not the core. It needs a maintained data pipeline and careful treatment of changing, limited, or decommissioned stations. It should draw on current aeronautical data only when the app is ready to own that responsibility.

## VOR network and map data

The current map data uses normalized coordinates from 0 to 1 relative to the Myosia artwork. `MapView` treats the artwork as 500 NM wide and derives all current distances, VOR reception, coverage rings, flight movement, and Position Challenge scoring from that scale. This is sufficient for the fixed chart, but the artwork and its aspect ratio currently define the coordinate frame.

VOR service volumes should feel plausible and create a useful hierarchy:

| Service volume | Current simulated range | Place in the world |
|---|---:|---|
| High | 100 NM | Major regional navigation hub |
| Low | 40 NM | Local station near an airport, city, or geographic feature |
| Terminal | 25 NM | Local navigation near a terminal area |

The current station data contains 77 VORs: 5 High, 28 Low, and 44 Terminal. Each range comes from its service-volume category. Per-station range overrides and restrictions are not implemented.

```json
{
  "vors": [
    {
      "id": "westmarch",
      "name": "Westmarch",
      "identifier": "WES",
      "frequency": 113.20,
      "location": { "x": 0.16, "y": 0.46 },
      "type": "VOR",
      "serviceVolume": "H",
      "elevationFT": 220,
      "dme": false
    }
  ]
}
```

`id` is the internal key. `identifier` is the displayed three-letter station code. `location` is normalized to the chart image. The model can later add per-station range overrides, identification details, magnetic variation rules, and operating status without changing the central design.

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

The current Position Challenge reports only the distance in NM between the player's placed marker and its hidden target. Its reveal shows the target and a dashed line to the guess. Broader scoring and debrief are future work.

For future route and Mission play, reaching the destination is necessary but not the whole score. Measure the quality of navigation:

- radial tracking accuracy;
- intercept and turn timing;
- time to establish the next course;
- transition prediction;
- correct station tuning and identification;
- route efficiency and constraint compliance;
- time, where the mission calls for it.

After a future flight, reveal the true track beside the planned route and key instrument events. Explain missed or early transitions in terms of the chart and the indications the player had. This is where mistakes become useful instruction.

## Technical shape

The current app is one macOS SwiftUI target. It has no separate shared navigation package and no iPad target. `Simulation/VORNavigation.swift` contains CDI, TO/FROM, station lookup, and distance math; `Simulation/FlightPhysics.swift` advances the plane; and `Simulation/PositionChallenge.swift` creates and scores a hidden position target. `MapView.swift` still owns the live aircraft state, receiver reception checks, coordinate conversion, flight loop, and Position Challenge lifecycle.

The receiver UI currently accepts a three-letter station identifier and resolves it to a station. It displays the matching station's frequency as confirmation, rather than tuning a frequency directly. Each receiver has its own identifier and OBS, and can render either a CDI or HSI. DME is present in station data but is not shown or calculated.

As the app grows, keep world and aircraft truth, receiver and instrument logic, Mode visibility and rules, and SwiftUI presentation separate. Extracting a shared package becomes useful when the project has a second platform or enough non-UI logic to exercise independently.

Keep these layers separate:

```text
World and aircraft truth
        -> receiver and instrument model
        -> Mode visibility and rules
        -> SwiftUI chart and controls
```

Outside Position Challenge, the map shows and lets the player drag the plane. During Position Challenge, the NAV calculations use a hidden target while the plane icon becomes the player's guess marker; checking the answer reveals the target and the error distance.

## Current implementation

- One fixed fictional chart, Myosia, with 77 VORs, airports, sightseeing regions, a toggleable grid, zoom, and pan.
- A heading-based, constant-speed plane simulation with Play and Pause controls plus 1x, 5x, 10x, and 30x playback.
- Two independent NAV receivers with identifier selection, OBS, CDI or HSI presentation, TO/FROM, and service-volume range handling. The receiver displays the station frequency after identifier selection.
- A Position Challenge that selects a random target reachable by at least three in-range VORs, accepts a dragged map guess, and reports its error in NM.
- No radial-intercept mission, route planner, flight plan, persistence, lesson sequence, score beyond position error, debrief, or mode-selection system yet.
- macOS only.

The next work should build on this actual base, not on the earlier compact-chart and cross-platform MVP description.

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
