# Ideas and next work

Each entry is one individually addressable idea. Refer to its ID—for example, “explore `I-003`,” “explore `I-005`,” or “delete `I-006`.” IDs never change or get reused. The status sections make the list easy to scan; they do not turn a collection of ideas into a project history.

## Active

### I-011 — Mission leg timing

**Status:** Stage 1 accepted for commit; Stage 2 authorized
**Type:** Feature
**Next action:** Commit Stage 1, then implement and verify Stage 2 live timing through its owner checkpoint

**What it is:** Stage 1 now shows a fixed still-air schedule for every geometric leg in the Transport briefing, separately from NAV guidance, and carries it into the shared mission definition. Live current/next estimates, Start/Restart/Undo, the persistent strip, and optional one-time return to 1× remain later stages. All estimates use airspeed and player-declared progress without hidden aircraft position; wind correction is reserved for a later flight-planning skill.

**Exploration:** [Timing options and open questions](Explorations/I-011-mission-leg-timing.md)

**Plan:** [Mission leg timing](Plans/I-011-Mission-Leg-Timing.md)

### I-003 — Mission quality and debrief

**Status:** Stages 1–2 committed; Stage 3 interactive debrief implemented — final owner review/commit pending
**Type:** Initiative
**Next action:** Review and commit Stage 3; after acceptance, archive the completed build plan and explore scoring using recorded flights

**What it is:** Shared mission wind, flight recording, ending, and unscored planned-versus-flown debrief capabilities for authored and generated missions. Silverkeep → Midland is the first test integration. Offer Calm or randomly populated, editable Steady wind; show the debrief on Flight Complete or flying off the map. Mission identity, starting state, route, instructions, and any arrival reference are inputs. Instruction checkmarks remain player assists and never affect scoring.

**Exploration:** [Wind, recording, and first debrief design](Explorations/I-003-mission-quality-and-debrief.md)

**Build plan:** [Wind, flight recording, and first debrief](Plans/I-003-Wind-Recording-Debrief.md)

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
