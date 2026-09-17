# Roadmap through V0.5

This is the agreed product path for the next five versions. It is not an execution plan. Before work on a version starts, create and approve a separate plan that satisfies `Execution-Protocol`.

The project stops at V0.5 for this planning cycle. V0.6 and later need a new discussion.

## Product boundaries

VOR stays a Mac-first SwiftUI application with one macOS target. It uses the fictional Myosia chart and teaches or practices VOR navigation through recognizable cockpit instruments. The chart is not a GPS display in normal mission play.

The app does not become a full flight simulator in this roadmap. Altitude, terrain collision, airspace rules, aircraft systems, real-world data, and an iPad target are outside V0.1 through V0.5.

Use a small number of cohesive source files. Do not split every knob, dial, or small view into its own file. Keep the app in one Xcode target rather than introducing a Swift package or a second target.

Bundled missions use JSON. User-authored plans are stored separately from bundled content. The flight-plan structure in `FlightPlanFormat.md` remains the source for plan geometry.

## Foundation before feature work

`Chore-Complete-Execution-Protocol` must be closed before an executable V0.1 plan is written. The current protocol still needs its project declarations for the source tree, validation gates, guardrails, and toolchain. Without them, a plan cannot state its required checks or hard limits honestly.

## Version ladder

### V0.1: Stable core

Add an XCTest target and characterize the current navigation and flight behavior with tests. Reorganize the existing single macOS app into clear, modest source groups while retaining the current app behavior and visible interface.

The end condition is behavioral parity: the present app still works manually, the navigation math has tests, and the source layout makes future work easier to locate. V0.1 does not change the player-facing UI or add route planning.

### V0.2: Cockpit and app shell

Replace the current layout with the durable shell for the app.

- The home screen shows Learn, Practice, Free Flight, and Missions. Only Free Flight works in this version. The other modes appear but are unavailable.
- Free Flight is the existing open-world, unscored experience. The current Position Challenge moves under Practice rather than remaining part of Free Flight.
- The chart sits above a bottom-docked cockpit. The cockpit has three equal bays for heading, NAV1, and NAV2. They scale together within a defined range, with a minimum macOS window size instead of collapsing into unrelated sizes.
- The cockpit uses physical-looking, usable controls. Radios tune by frequency and show the matching ident when one is received. Each NAV receiver has one active frequency. A NAV1 ↔ NAV2 swap exchanges their tuned frequencies and OBS settings.
- Chart-specific controls move into a compact Chart popover. Durable settings go to preferences. Player-visible map-coordinate, signal, playback, and later wind diagnostics move to a separate debug-only window.
- Planner and debrief views are placeholders only.

Validate the layout on a 13-inch Mac display. Keep its proportions suitable for a possible 11-inch iPad later, without adding iPad support now.

### V0.3: First supplied mission

Ship the first complete authored route: Silverkeep Strip to Midland Cityport. The player flow is Home, Missions, briefing, planner, and flight.

The planner loads the bundled JSON flight plan, resolves airports, VORs, and radial intersections, draws the route on the chart, and calculates leg and total distance plus still-air ETA. It renders player instructions such as frequency, OBS course, TO or FROM flag, and transition.

The player can open a read-only Flight Plan panel in both planning and flight. It may cover or sit beside the chart, but it never takes cockpit space. During flight it highlights the active leg. The player flies with the V0.2 controls and marks arrival. The result shows simulated time and distance to Midland Cityport only. There is no wind, score, route replay, or full debrief yet.

### V0.4: Mission quality and debrief

Add a deterministic steady wind for the supplied mission and state it in the briefing. Record the flown track and assess two independent results:

- Route tracking measures adherence to the assigned route.
- Arrival accuracy measures proximity to the intended destination when the player marks arrival.

For the Silverkeep to Midland mission, score route tracking at 35 percent and arrival accuracy at 65 percent. Different missions may use different weights later. The debrief shows the planned and flown paths, the marked arrival point, score breakdown, and flight time.

### V0.5: Self-planned transport flight

Let the player author a transport flight by selecting an origin and destination, then adding direct VOR and two-radial intersection waypoints on the chart. The planner validates and writes the same plan geometry used by bundled missions. It then derives the readable instructions, distances, and ETAs.

The player can save the authored plan outside bundled content and run it through the same planner, flight, arrival, scoring, and debrief loop built in V0.3 and V0.4.

## Deferred until V0.6 or later

- Functional Learn and Practice exercises, including Position Fix and radial-intercept training.
- More supplied missions, mission categories, and parameterized mission generation.
- Standby frequencies for NAV radios.
- DME arcs, arbitrary coordinates, and other waypoint types beyond airports, VORs, and two-radial intersections.
- More complex wind, failures, terrain-focused flight, and richer simulation rules.
- iPad support or a second platform target.

At V0.5 the app has the new cockpit and window layout, working instrument controls, one supplied route the player can fly, and a route the player can author and fly. That is the stopping point for this roadmap.
