# I-003 — Mission quality and debrief

**Status:** Stage 1 implemented and behavior-verified; owner review pending

**Idea:** [I-003 in IDEAS.md](../IDEAS.md#i-003--mission-quality-and-debrief)

**Build plan:** [Wind, flight recording, and first debrief](../Plans/I-003-Wind-Recording-Debrief.md). The plan resolves the engineering details identified below and defines implementation stages and owner checkpoints.

**Current focus:** Steady wind, flight recording, and an unscored planned-versus-flown debrief. Scoring design follows after these can be tried with real flights.

## Purpose and scope

Extend the working Silverkeep Strip → Midland Cityport Transport mission so the player can experience wind affecting navigation and inspect the flight they actually flew against the assigned route after the flight ends.

**Owner clarification, 2026-10-15:** This route is the first test mission. Wind, simulation, recording, ending, and debrief must be shared capabilities for other authored and generated missions. Mission identity, starting state, route geometry, instructions, and any arrival reference are supplied as data; none of these capabilities may depend on the Transport mission, its airports, or its bundle resource. The active plan defines that reusable contract and verifies it with alternative in-memory mission inputs. A generator and additional production missions remain separate work.

Explore wind, recording, and the first debrief together because the conditions that move the aircraft must agree with the recorded path and its explanation. Implementation can have separate user-visible landmarks without separating their design.

The bounded direction is:

- A Calm / Steady wind choice. Steady wind populates a random direction and speed within limits; the player can edit both values. The selected conditions are stated in the briefing.
- A record of the aircraft's actual flown path.
- An unscored debrief showing planned and flown paths, the final position, simulated elapsed time, and direct distance from Midland Cityport.
- The live mission continues to hide the actual aircraft position and planned route. Their comparison is revealed when the flight ends.
- Flying completely off the map ends the mission automatically and opens the debrief directly.

## Settled boundaries

### Wind selection

- The player chooses **Calm** or **Steady wind** in the briefing.
- A newly opened Transport briefing defaults to **Calm**, preserving the existing beginner flight unless the player deliberately chooses wind.
- The first selection of Steady wind in a briefing populates a random wind direction and speed within limits, rather than using one fixed preset for every flight.
- The player can edit both the generated direction and generated speed.
- Random distributions and north reference remain planning details.
- The term steady describes the wind during a flight; random population is a setup behavior, not a requirement for gusts or changing weather.

### Randomization and mode switching

- Selecting **Calm** applies no wind but retains the briefing's populated or edited Steady wind values.
- Selecting **Steady wind** again restores those values, including any player edits. Switching modes does not generate a new pair or erase edits.
- An explicit **Randomize** button generates a new direction and speed within the agreed random-generation limits. Both newly populated values remain editable.
- Wind population does not occur again merely because the briefing redraws or because Fly Again is selected.

### Returning to the briefing

- **Back to Briefing** retains the selected Calm / Steady wind mode and the populated or edited Steady wind direction and speed.
- Returning does not generate a new pair. The player can edit or explicitly Randomize the retained values before starting a new flight.
- This retention belongs to the existing briefing; a newly opened Transport briefing still defaults to Calm.
- Wind setup is retained only within the current briefing. It is not saved across app launches in this first version; reopening the app starts with a fresh Calm briefing.

### Wind lock at launch

- Wind settings lock when the player selects **Fly Transport**, before simulated flight begins.
- Neither Calm / Steady wind selection nor direction or speed can be changed within that flight, including while paused.
- The selected conditions apply to the entire flight. The completed result must retain those conditions so the debrief describes the wind that actually applied.
- Changing wind settings requires returning to the briefing and starting a new flight. Existing Back to Briefing behavior discards the current mission session.

### Wind reference during flight

- Keep the locked conditions visible as **read-only information in the live mission panel**, near the simulated clock.
- Show **Calm** or a wind reference such as **Wind from 270° at 15 kt**.
- Viewing the reference does not unlock wind editing. Hiding the mission panel hides this reference with the rest of its content; reopening shows the same flight conditions.
- This lets the player check the conditions without returning to the briefing and discarding the flight.

### Fly Again

- **Fly Again** reuses the completed flight's Calm / Steady wind mode and exact wind direction and speed. It does not generate new conditions.
- It starts a fresh flight session and a fresh recording at the mission origin. Prior elapsed time, checklist state, and completion result are cleared as in the current mission.
- Repeating the same conditions lets the player practise corrections against the same navigation problem.
- Choosing different wind conditions happens in the briefing before starting a new flight.

### Wind-speed limits

- Randomly populated speed is **5–25 kt**, inclusive, in **whole knots**.
- Manually entered speed is **0–40 kt**, inclusive, in **whole knots**.
- The generated range keeps initial conditions moderate; the wider manual range leaves room for stronger-wind experiments.
- Decimal-knot precision is outside the first wind input. Invalid-entry handling follows the agreed correction-before-launch policy.
- Random distribution within the range remains a planning detail.

### Wind direction

- Use the field label **Wind from**.
- Display and enter the direction in whole degrees **000–359°**, inclusive.
- The bearing identifies the direction the wind comes from. **270°** means wind coming from the west and blowing toward the east.
- Random direction distribution, handling of an entered 360°, and the north reference remain open.
- The shared definition is recorded in [Glossary.md](../Glossary.md#wind).

### Wind-entry validation

- With **Steady wind** selected, invalid or out-of-range required wind entries show the allowed range and disable **Fly Transport** until corrected.
- Do not adjust an out-of-range value to the nearest allowed value automatically. For example, **55 kt** requires correction rather than becoming **40 kt**.
- This policy keeps the conditions the player chooses explicit before they are locked for the flight.
- Handling of the equivalent north inputs 360° and 000° remains to be settled; it is separate from adjusting a speed to a range boundary.

### Recording cadence

- Record the flown path every **1 simulated second**, independent of the wall-clock playback speed.
- Retain the exact starting position at simulated time **0 seconds** and the exact position and simulated time when the flight ends, either through **Flight Complete** or automatic off-map termination, including a finish between regular sample times.
- The regular sampling schedule uses the same simulated-time spacing at **1×, 5×, 10×, and 30×**.
- At **260 kt** in calm straight flight, one second corresponds to approximately **0.072 NM**. Wind changes spatial spacing; the sampling interval remains one simulated second.
- Evaluate the motion model at every scheduled recording time crossed by a simulation advance. Recording once per wall-clock second or merely retaining the last position of a long advance would not satisfy this cadence.
- Handling coincident start/finish or regular/finish samples remains open.

### Pause and zero airspeed

- **Pause** freezes aircraft motion, turning, wind drift, simulated elapsed time, and the recording's sample schedule.
- Resuming continues from the current state and simulated time; wall-clock time spent paused is not added to the flight.
- While **Play** is active, setting airspeed to **0 kt** still permits movement from the selected wind. Simulated time and recording continue.
- With Calm and 0 kt airspeed during Play, position remains stationary while simulated time and recording continue. Pause remains the explicit way to stop the simulation.

### Off-map mission ending

- Flying **completely off the map** ends the mission automatically and goes **straight to the debrief**.
- Stop movement and simulated time, finalize the recording with the end position/time, and show the same unscored planned-versus-flown comparison used for manual completion.
- This is an ending condition, rather than a pause from which the player can continue or an indefinitely continuing off-map flight.
- Retain the reason the flight ended so the debrief can distinguish player-selected Flight Complete from leaving the map. The displayed wording remains open; this slice adds no score or penalty.
- The trigger does not depend on checklist progress.
- The boundary is the **full underlying chart extent**, measured in the source chart's normalized coordinates (**x and y from 0 to 1**). Its calibration remains **500 NM wide**, with height **500 × 1254 / 1748 NM**.
- The fixed display crop, current camera pan/zoom, and window size do not change this mission boundary.
- To satisfy the settled immediate-ending and playback-consistency requirements, use the **first outward boundary crossing** within an advance as the end event. Finalize the track and clock at that crossing's position and simulated time, rather than retaining a later frame or sample outside the map. Merely touching the boundary without leaving it does not end the mission.
- The crossing solver and its numerical accuracy criteria remain planning details. This first supplied-mission slice does not add a debrief flow to Free Flight or Position Challenge.

### Playback consistency

- For the same starting state, wind, and control changes at the same **simulated times**, the flown path must be the same at **1×, 5×, 10×, and 30×**.
- Playback changes the rate at which simulated time passes while preserving the flight dynamics and the recording's simulated-time sampling schedule.
- This guarantee concerns equivalent simulated inputs; it does not equate control changes made at the same wall-clock times under different playback speeds.
- The current turn-then-advance calculation uses the latest heading for the whole frame's movement. Its turn approximation depends on the frame's simulated duration, so meeting this requirement needs movement refinement.
- Numerical acceptance criteria remain open. Existing world data, route geometry, and test tolerances must not be changed to hide discrepancies.

### Direct movement calculation

- Use **direct calculations** for the defined constant-turn-rate, steady-wind model rather than approximating turns with small fixed simulated-time steps.
- Retain the existing **3° per simulated second** turn rate, shortest-turn behavior, and consistent right turn for an exactly 180° heading change.
- Calculate the curved motion while turning toward the selected heading and the straight remainder after reaching it. Add the constant wind displacement over the same elapsed simulated time.
- Evaluate that trajectory at recording times so regular samples, the live aircraft state, and an ending position all describe the same motion model.
- This choice calls for careful mathematical verification. Direct calculation describes the defined teaching model; floating-point precision and the boundary-crossing solver still need explicit acceptance criteria.

### Recorded sample contents

- Each sample retains **aircraft position**, **simulated elapsed time in seconds**, **actual heading in degrees**, and **airspeed in knots**.
- Actual heading is the aircraft's current heading, distinct from the selected heading it is turning toward.
- The flight's fixed wind is stored once with the flight conditions rather than repeated in every sample.
- Heading and airspeed provide context for interpreting drift and corrections. Retaining them does not introduce heading or speed scoring; route assessment remains based on planned versus flown geometry.

### Recording lifetime

- Keep only the recording for the current flight and its completed debrief, in memory.
- **Fly Again** clears the previous recording and starts a fresh one with the same wind conditions.
- Leaving the flight/debrief, including **Back to Briefing**, clears that recording. The briefing's retained wind setup is independent of this recording lifetime.
- The first version does not save a flight history or retain recordings across app launches.

### First debrief's scope

- The first debrief is a **static planned-versus-flown chart comparison** of the completed flight.
- The first version shows the **paths and summary only**. Selecting a recorded point to inspect its time, heading, or airspeed is deferred, along with animated replay and a time scrubber.
- Retain the agreed sample contents so these later inspection and replay options remain open.
- Static describes showing the completed paths together rather than replaying them over time. Path styling remains a visual-review detail.
- The existing elapsed-time and direct-arrival-distance measurements remain part of the unscored result, alongside the wind that applied to the flight.

### Debrief screen and initial view

- **Flight Complete** or automatic off-map mission ending opens a dedicated debrief screen with a chart and summary beside it. It replaces the live cockpit layout for the completed result.
- The summary contains the flight's wind, simulated elapsed time, direct arrival distance, and retry/navigation actions.
- The initial map is **zoomed to fit the entire flight**. Include the complete flown path and planned route in the fitted extent so both remain visible for comparison, with space around their endpoints and labels.
- The debrief must display the recorded path throughout the full underlying chart, including portions outside the current live chart's display crop. Its framing must not hide those portions.
- The debrief starts with this fitted view rather than inheriting the live chart's current zoom and pan.
- It presents the completed recording; chart viewing does not resume flight or change the completed path.
- Exact fit margin, zoom limits, and marker styling can be settled through visual review.

### Debrief map interaction

- After the initial fitted overview, the player can **pan and zoom** to inspect individual parts of the flight.
- A **Fit Flight** button restores the overview containing the complete flown path and planned route.
- These interactions change only the view of the completed flight, not its recording or result measurements.

### Checklist independence

The instruction checkmarks are entirely player assists. Their checked state, order, and timing must have no effect on any eventual score. They must not determine which planned leg is used to assess the flown path, whether a route section counts, or whether a flight may be completed.

Future route assessment compares the planned route with what the aircraft actually flew. Recording must remain independent of checklist interaction; checking or clearing an instruction must not start, stop, segment, or reset the recorded path.

### Scoring comes later

This first slice provides observable flight evidence and an unscored comparison. Score formulas, route corridors, arrival thresholds, penalties, grades, and pass/fail rules remain for a later exploration using actual flights.

The existing initiative records route tracking and arrival accuracy as separate measures. The proposed Silverkeep-to-Midland weighting is **35% route tracking / 65% arrival accuracy**. Preserve that as a proposal for later evaluation, not a number to implement in this slice.

### Product constraints

- VOR navigation remains the central task; wind must create a navigation decision rather than introduce aircraft-performance or weather-system complexity.
- Myosia chart data, the supplied route, radial values, and existing tolerances remain authoritative.
- macOS remains the only current target.
- No dependency, project-file, signing, capability, entitlement, or bundle-ID changes are assumed.
- No executable build plan or production changes are part of this exploration.

## App baseline used for planning

This section records the pre-implementation baseline. Stage 1 has since delivered wind and shared model-owned movement; see the active plan and README for current behavior.

The source agreed with the README about the current mission:

- The briefing resolves the bundled route into six chart points and five player-facing NAV instructions. Its distance and time estimate are explicitly still-air planning information.
- The mission has a scrollable, collapsible instruction checklist and manual Flight Complete. The player can complete with any combination of checked instructions.
- Flight Complete pauses the flight and retains simulated elapsed time plus the exact direct distance from the airport. It does not retain a flight path or a completion-position value for drawing a debrief.
- Fly Again creates a fresh flight session and checklist.
- The flight session holds normalized aircraft position, actual and selected heading, speed, playback multiplier, and simulated elapsed time. It has no wind or recording state.
- Movement and elapsed time currently advance together in a view-owned loop. Heading turns toward the selected heading at **3° per simulated second**. Playback options are **1×, 5×, 10×, and 30×**. The agreed model-owned direct calculation replaces the current per-frame turn approximation when this slice is implemented.
- The movement calculation currently clamps position to the **displayed chart crop**, not the full source-artwork extent. `FlatMap.sourcePosition` also rejects positions outside that cropped image rect. Recording this behavior would show tracks pinned to or moving along that presentation boundary.
- Route geometry and a static chart overlay already exist for the briefing. There is no debrief screen or flight-history store.

The earlier reference material in `Design/` assumes an active leg for route scoring and describes an arrival area. The current source uses independent manual checks and raw airport distance. This exploration follows current behavior and the owner's explicit checklist-independence decision. It does not adopt active-leg selection from checks or introduce an arrival area.

## Settled technical direction

- The **flight model** owns aircraft movement, simulated elapsed time, recording, and mission-ending state together. The chart displays that state.
- Chart crop, layout size, camera zoom, and camera pan are presentation inputs; they do not define the physical movement calculation or the mission's full-chart exit boundary.
- Flight calculations use the existing Myosia calibration consistently for movement, receiver readings, recorded positions, and destination distance. Bundled chart or route coordinates do not need to be rewritten.
- The briefing owns editable setup. A launched flight receives its fixed wind conditions and a mission definition, adapted from the resolved supplied route for the first test mission. Other authored and generated missions use the same input contract and shared implementation. Checklist assists remain independent of flight recording and assessment.
- Either ending path must freeze one coherent completed result: the flown recording, wind conditions, final position, simulated elapsed time, and ending reason. The debrief reads that completed result rather than continuing to observe mutable flight movement.
- This requires a focused refactor from the current view-owned movement loop. Direct motion calculation is settled; tick delivery, numerical verification criteria, and the details of the crossing solver remain to be resolved.

## Engineering handoff to the build plan

The purpose, scope, major responsibilities, wind interaction, recording requirements, and first debrief experience were settled by this exploration. The following details were handed off as engineering work rather than new product-scope questions; their decisions are now recorded in the linked build plan:

1. **Numerical verification and clock delivery:** Choose the tick-delivery and boundary-crossing algorithms, then state numerical acceptance criteria for direct motion, scheduled sample positions, and the first crossing's position/time. Verify equivalent simulated input histories across playback speeds. Include a curved trajectory that crosses a boundary within an advance even if its later position would be inside again; checking only the advance's endpoint is insufficient. Existing test tolerances and world/route data remain unchanged.
2. **Recording representation and coincident events:** Retain positions with the existing source-chart calibration. Specify the representation and treatment of coincident regular/finish or start/finish samples so the exact ending state is authoritative, timestamps stay coherent, and the debrief does not fabricate a flown segment. Manual Flight Complete remains available before movement, preserving a zero-time result at the origin with the ordinary direct distance from Midland.
3. **Routine wind-input defaults:** Make the random distributions, common bearing reference, and treatment of an entered 360° concrete. Recommended planning defaults are independent uniform whole-degree and whole-knot draws within the settled ranges, the same north reference as existing headings/VOR radials, and treating an entered 360° as out of range until the player corrects it to 000–359° under the agreed validation rule. Preserve calm behavior for modes or mission inputs that do not supply wind. These recommendations are engineering defaults for plan review, not additional interview decisions.
4. **Visual tuning and ending labels:** Specify distinct planned/flown path styles, a legend, start/destination/finish markers, and wording distinguishing manual completion from an off-map end. Review fit margin, zoom limits, labels, summary placement, and existing retry/navigation actions at the **1100×760** minimum content size. Scoring, sample selection, replay, and history remain outside this slice.
5. **Visible verification:** Give the owner a way to inspect wind and recording before the final debrief is polished, using the existing debug-only diagnostics or a comparably bounded development surface. Normal live missions keep aircraft truth hidden. Representative flights should cover Calm, uncompensated wind drift, a corrected route, pause/resume, different playback speeds, early completion, and an off-map ending.

No blocker to planning has been identified. Stop and explain an unrelated test failure, missing prerequisite, or architectural change beyond the agreed flight-model refactor when implementation is planned or attempted.

## Likely user-visible landmarks

These are user-visible outcomes and their dependencies, not implementation tasks:

1. **Navigate with steady wind:** The player knows the mission conditions and can observe and correct their effect through the existing NAV instruments. Depends on consistent model-owned movement with fixed flight conditions.
2. **Inspect the completed flight:** Flight Complete or flying off the map reveals the assigned route beside the recorded flown path and the existing time/arrival-distance measurements. Depends on a recording contract and result lifecycle that preserve the flight that actually ended.
3. **Explore fair assessment:** Compare representative flights to settle route and arrival scoring separately. Depends on usable wind, recording, and debrief evidence; checklist activity remains excluded throughout.

## Planning handoff

The [active build plan](../Plans/I-003-Wind-Recording-Debrief.md) now turns these settled requirements into three implementation stages: navigating with steady wind, inspecting a recorded flight in a first working debrief, and completing pan/zoom and visual verification. Stage 1 is implemented and behavior-verified. Stop at its owner review/commit checkpoint before Stage 2.

Scoring remains a separate later exploration within I-003, informed by the resulting flight evidence. The 35% / 65% proposal is preserved for that discussion and must not become a score in the first slice. Checkmarks remain excluded from assessment throughout.

This exploration does not automatically start planning, implementation, or a commit.

## Research supporting direction convention

The [FAA Aeronautical Information Manual, Aviation Weather Information](https://www.faa.gov/air_traffic/publications/atpubs/aim_html/chap7_section_1.html) describes reported wind direction as the direction the wind blows **from**. This supports a **Wind from** field label; it does not decide VOR's numeric input precision, display format, or north reference. For example, wind from 270° blows from west toward east.
