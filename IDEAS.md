# Ideas and next work

Each entry is one individually addressable idea. Refer to its ID—for example, “plan `I-002`,” “explore `I-005`,” or “delete `I-006`.” IDs never change or get reused. The status sections make the list easy to scan; they do not turn a collection of ideas into a project history.

## Ready to plan

### I-002 — First supplied mission: Silverkeep to Midland

**Status:** Planned
**Type:** Initiative
**Plan:** `Plans/I-002-V0.3a-Flight-Plan-Foundation.md`
**Next action:** Build the V0.3a flight-plan foundation.

**What it is:** Create the first complete authored flight: Home → Missions → briefing/planner → flight → arrival result. The route is Silverkeep Strip to Midland Cityport, with VOR legs and two radial-intersection fixes.

**Already decided:** Reuse the existing cockpit and Myosia data rather than replacing them. V0.3 excludes wind, route scoring, a full debrief, user-authored plans, iPad support, and expanded flight simulation. Position Challenge established `FlightSurfaceConfiguration`, so this plan should give the mission its explicit chart-aid and cockpit-control choices when its rules are defined.

**Likely landmarks:**

1. **V0.3a — Flight-plan foundation:** a small, testable model for origins, destinations, VOR/airport/intersection points, route distances, still-air estimate, and readable NAV instructions.
2. **V0.3b — Plan preview:** show the supplied plan on the chart and in a read-only Flight Plan panel.
3. **V0.3c — Mission loop:** hand the plan into a flight, identify the active leg, allow arrival marking, and show simulated time plus distance from Midland.

**Open questions:** The first plan should decide the smallest data model and the most useful observable way to inspect its calculations. `Design/Documents/FlightPlanning.md` and `Design/Documents/FlightPlanFormat.md` are background reference, not active plans.

## Needs exploration

### I-003 — Mission quality and debrief

**Status:** Needs exploration
**Type:** Initiative
**Next action:** `a-explore I-003`

**What it is:** Add a deterministic steady wind to the supplied mission, record the flown path, and show planned versus actual track in a debrief.

**Already decided:** Route tracking and arrival accuracy should remain separate measures. The Silverkeep-to-Midland mission's proposed weighting is 35% route tracking and 65% arrival accuracy.

**Open questions:** What a fair beginner-facing score and debrief should show, and what V0.3 needs to record now so that later work remains straightforward.

## Later

### I-004 — Self-planned transport flight

**Status:** Later
**Type:** Initiative
**Next action:** `a-explore I-004` when V0.3 and the first debrief are established

**What it is:** Let the player author a transport route using airports, VORs, and two-radial intersections; validate it, save it apart from bundled content, and fly it through the mission loop.

**Already decided:** It should use the same flight-plan geometry as supplied missions.

### I-005 — Guided lessons and richer Practice

**Status:** Later
**Type:** Initiative
**Next action:** `a-explore I-005`

**What it is:** Add guided lessons for reading a VOR, finding position with two VORs, and intercepting/tracking a radial.

**Already decided:** Difficulty should come from fewer aids and better decisions, not arbitrary controls. Position Challenge is the first working Practice activity.

### I-006 — Sightseeing mission

**Status:** Later
**Type:** Initiative
**Next action:** `a-explore I-006`

**What it is:** Fly from a named airport through a group of named Myosia sightseeing checkpoints and return to the departure airport.

**Already decided:** The bundled region data already has named checkpoints and tolerances. The mission should use VOR navigation rather than turn into a map scavenger hunt.

### I-007 — Off-course recovery mission

**Status:** Later
**Type:** Feature
**Next action:** `a-idea I-007` to capture a concrete starting situation before exploring it

**What it is:** Start a planned flight after the aircraft has moved off its active leg. The player finds their position, chooses a way to rejoin the route, and is scored on the recovery.

**Already decided:** Recovery should reward correcting an error rather than treating the drift as an automatic failure.

### I-008 — One NAV receiver failure mission

**Status:** Later
**Type:** Feature
**Next action:** `a-explore I-008`

**What it is:** Give the player a flight objective with only one working NAV receiver, so they must manage station changes and progress checks without NAV2.

**Already decided:** It must remain a conventional VOR-navigation problem, not add a fictional shortcut instrument.

### I-009 — Terrain and aircraft constraints

**Status:** Later
**Type:** Initiative
**Next action:** `a-explore I-009`

**What it is:** Add terrain, passes, and modest aircraft limits so route selection can become part of VOR planning.

**Already decided:** This belongs only after the core navigation loop is established. Every generated mission must have a feasible route.

### I-010 — iPad support

**Status:** Later
**Type:** Initiative
**Next action:** `a-explore I-010` when it becomes an active goal

**What it is:** Add an iPad version with interactions and layout appropriate to that screen size.

**Already decided:** Do not add an iPad target yet. It is a future direction, not a current implementation target.
