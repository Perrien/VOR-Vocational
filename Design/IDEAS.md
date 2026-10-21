# Ideas and next work

Each entry is one individually addressable idea. Refer to its ID—for example, “explore `I-003`,” “explore `I-005`,” or “delete `I-006`.” IDs never change or get reused. The status sections make the list easy to scan; they do not turn a collection of ideas into a project history.

## Active

### I-003 — Mission quality and debrief

**Status:** Wind, recording, and interactive unscored debrief implemented and committed; scoring unexplored
**Type:** Initiative
**Next action:** Confirm the recorded I-003 visual-review items, then explore scoring using recorded flights

**What it is:** Shared mission wind, flight recording, ending, and unscored planned-versus-flown debrief capabilities for authored and generated missions. Silverkeep → Midland is the first test integration. Offer Calm or randomly populated, editable Steady wind; show the debrief on Flight Complete or flying off the map. Mission identity, starting state, route, instructions, and any arrival reference are inputs. Instruction checkmarks remain player assists and never affect scoring.

**Exploration:** [Archived wind, recording, and first debrief design](Archived/Explorations/I-003-mission-quality-and-debrief.md)

**Delivered scope:** [Archived wind, flight recording, and first debrief plan](Archived/Plans/I-003-Wind-Recording-Debrief.md)

### I-005 — Guided lessons and richer Practice

**Status:** In progress — Stage 1 implemented; owner checkpoint pending
**Type:** Initiative
**Next action:** Review Stage 1 of the [moving position and heading challenge plan](Plans/I-005-Moving-Position-And-Heading-Challenge.md), choose whether to commit, then authorize Stage 2

**What it is:** Add a timed, still-air position-and-heading challenge with a precise circle-and-arrow marker and separate distance error, heading error, and elapsed-time results. Reuse the circle without its arrow in the stationary challenge; combined scoring and guided lessons remain later scope.

**Exploration:** [Moving position and heading challenge](Explorations/I-005-moving-position-and-heading-challenge.md)

**Plan:** [Moving position and heading challenge](Plans/I-005-Moving-Position-And-Heading-Challenge.md)

## Later

### I-004 — Self-planned transport flight

**Status:** Later
**Type:** Initiative
**Next action:** `a-explore I-004` when V0.3 and the first debrief are established

**What it is:** Let the player author a transport route using airports, VORs, and two-radial intersections; validate it, save it apart from bundled content, and fly it through the mission loop.

**Already decided:** It should use the same flight-plan geometry as supplied missions.

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
