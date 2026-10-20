# I-011 — Mission leg timing

**Status:** Feature implemented and accepted on 2026-10-20; build plan archived

**Idea:** I-011 — completed entry removed from IDEAS.md at the owner's request on 2026-10-20.

**Build plan:** [Archived mission leg timing plan](../Plans/I-011-Mission-Leg-Timing.md). It records all three implemented stages, verification, and owner acceptance.

**Outcome:** All three stages are complete. The owner accepted the feature, authorized closeout and archival, and chose to remove the completed idea from the active index. The exploration below preserves the original requirements and rationale; wind-aware planning and the other deferred features remain later work.

## Purpose and intended experience

Some mission legs take several minutes or longer without requiring player input. The player needs enough timing information to judge when to use the existing faster playback and when to attend to the next navigation action.

The owner wants a duration for each mission leg and an indication of when in the flight its endpoint should be reached. This information should be available during flight as well as in preparation. Preserve the original flight-plan schedule and supplement it with a running estimate based on airspeed and player-confirmed progress. **All estimates are still-air.** The running estimate updates automatically when airspeed changes while preserving estimated distance already covered.

An illustrative need is knowing that the next action is approximately **7 simulated minutes** away, so the player can temporarily accelerate playback. Seven minutes is an example, not a fixed threshold or notification requirement. An optional return to **1×** with **1 estimated simulated minute remaining** is now settled, off by default.

## Baseline behavior and foundations

Grounded in the source and current project documents on **2026-10-16**:

- The Transport briefing shows route-leg distances and a total still-air estimate at **260 kt**. It does not display individual leg durations or cumulative expected arrival times.
- The live mission panel shows the mission instructions, independent manual checkboxes, elapsed simulated time, and locked wind conditions. It does not show leg distances or timing estimates.
- Airspeed can change during flight. Playback offers **1×, 5×, 10×, and 30×**; playback changes simulated time without changing displayed airspeed. Pause freezes movement and simulated time.
- Calm and fixed Steady wind are supported. Consequently, distance divided by airspeed is a still-air estimate, and wind treatment must be explicit if a different estimate is offered.
- There is no active-leg selection or automatic waypoint arrival detection. Any checkbox can be checked or cleared in any order.
- The shared mission runner accepts route geometry and instructions separately. Timing should be considered for shared mission behavior rather than being tied to the first Transport route.
- An instruction is not necessarily a geometric leg. In the supplied route, the final radial is a position reference near the destination, deliberately has no leg distance, and is separate from the final intersection-to-airport geometry. Timing must not silently treat those as the same event.

## Existing constraints

- Normal mission play hides the actual aircraft position and planned route. A timing feature must make any new use or disclosure of hidden positional information an explicit design choice.
- Checklist checks are player assists and cannot affect flight recording or eventual scoring. The existing I-003 exploration also excludes using checks to select a leg for assessment. A player timing aid must preserve that separation.
- The active I-003 build plan excludes automatic leg selection from its current scope; this exploration does not amend that plan or begin implementation.
- Preserve Myosia data, navigation geometry, and existing tolerances. macOS remains the current target.

## Settled timing approach

Use **the original plan plus a running estimate**, confirmed by the owner on **2026-10-16**.

- Establish planned leg durations and cumulative expected arrival times before flight, and retain that original schedule during flight.
- Supplement the plan with an updated estimate using speed, elapsed simulated time, and player-confirmed progress. The player explicitly starts a leg's timing rather than advancing it through checklist edits.
- Do not use the aircraft's hidden actual position or actual remaining distance to calculate the live estimate. This preserves the VOR navigation task.
- Arrival remains confirmed by the player. Reaching zero on an estimate is not proof of arrival.
- Present remaining time as an estimate, for example **Estimated 7 minutes remaining**. Navigation errors can make it inaccurate; the timer must not correct those errors using hidden position.
- All planned and running estimates deliberately ignore wind. The running estimate automatically reflects airspeed changes without rewriting prior estimated travel or the original schedule.

A fixed schedule alone does not adequately address speed changes and delays. A position-aware estimate would supply navigation information the player has not established, so it is excluded from this direction.

## Player timing controls

Use a separate **Start this leg** action, confirmed by the owner on **2026-10-16**.

- Starting a leg establishes its timing reference at the current simulated flight time. It is the player's declaration that they are beginning that leg, not a position check by the app.
- Checking or clearing an instruction never starts, advances, restarts, or otherwise changes the timer. The player may continue editing checkboxes in any order.
- Starting a timer does not automatically check off an instruction or confirm actual arrival.
- Starting, restarting, or undoing a leg timer does not change aircraft controls, the flown-path recording, flight completion, or eventual scoring. The separately enabled playback assist described below may change the playback multiplier; it never changes heading or airspeed directly.
- For a route mission beginning at its departure point, **first Play automatically starts timing the first leg**, confirmed by the owner on **2026-10-16**. Transport has this known starting condition.
- Pause freezes the timer's elapsed simulated time; resuming preserves its existing timing reference and progress. Automatic first-leg start happens only once in a fresh flight, not on each Play.
- This default must not infer the starting leg from hidden aircraft position. Missions authored to begin away from their planned departure require an explicit timing policy rather than an automatic position lookup.

### Switching, restarting, and mistakes

Use **Undo** and **Restart from now**, confirmed by the owner on **2026-10-16**. Entering a past start time is deferred.

- **Start this leg** selects that leg for the running estimate and establishes a new reference at the current simulated time. Only one leg is timed at once; starting another replaces the selected timing context rather than running concurrent countdowns.
- **Restart from now** starts the selected leg's estimate afresh at the current simulated time, using the full planned leg distance. It does not move the aircraft or claim that the aircraft is actually at the leg's start.
- **Undo** reverses the most recent manual timer start or restart and restores the previous timing context. It changes only the timing aid; it never rewinds the aircraft, flight clock, recording, or checklist. The restored estimate must account for simulated time that passed in the meantime rather than display a frozen old countdown.
- Direct entry or editing of a historical start time, such as declaring that the leg began **2 simulated minutes ago**, is outside the first version. The player can establish a new reference now; a late start can make the estimate inaccurate.
- No multi-step undo history is required. The feature plan should define availability and presentation for the single most recent manual timer action.

## Still-air calculation boundary

**All timing estimates are still-air**, explicitly chosen by the owner on **2026-10-16**.

- This applies to the original schedule, individual leg durations, cumulative expected arrival times, the running estimate, and any forecast for later legs.
- Use planned distance, airspeed, and elapsed simulated time. Do not use wind-adjusted groundspeed or automatically correct timing for the selected flight conditions.
- Choosing Calm or Steady wind does not change timing calculations. Wind still affects actual aircraft movement through the existing simulation, so actual arrival may differ from the estimate.
- Identify estimates as **still-air** in the player-facing presentation, using the existing glossary meaning.
- The deliberate learning boundary is that **accounting for wind is a flight-planning skill**. The owner wants to introduce that skill later; automatic wind correction in this feature would remove that learning opportunity.
- Future wind-aware flight planning remains possible, but its calculation, player controls, and interaction with the still-air baseline are deferred. Do not silently add wind correction to this feature.

### Original planning airspeed

Use **the mission's assigned starting airspeed** for the original preflight schedule, confirmed by the owner on **2026-10-16**.

- Transport's assigned starting and planning airspeed is currently **260 kt**. This is that mission's baseline, not a global requirement for every mission.
- Derive each planned leg duration from its full planned distance and the assigned airspeed. Cumulative planned arrival times are measured from the start of simulated flight.
- Show the baseline airspeed with the still-air schedule so the player can understand what produced it.
- Do not add an editable planning-airspeed field to the briefing in this feature. Player-editable planning speed is deferred to later flight-planning tools.
- Preserve the baseline schedule throughout the launched flight, even when the player changes cockpit airspeed. Running estimates use the actual sequence of airspeed settings and the current airspeed as already settled.

### Automatic updates for airspeed changes

**Automatically update the running estimate when airspeed changes**, confirmed by the owner on **2026-10-16**.

- Accumulate estimated travel using each airspeed over the simulated time for which it applied: **airspeed in kt × simulated seconds ÷ 3,600 = estimated NM covered**. Sum these contributions from the selected leg's timing reference.
- Preserve estimated distance already covered at earlier airspeeds. Apply the current airspeed to the estimated distance remaining to obtain the updated time remaining.
- A speed change does not restart the timer, change its start time, or retroactively treat the entire elapsed leg as flown at the new airspeed.
- Keep the original planned leg durations and cumulative arrival schedule unchanged.
- For example, on a **20 NM** leg, **5 simulated minutes at 120 kt** accounts for **10 NM** of still-air estimated travel. Increasing to **240 kt** leaves an estimated **2 minutes 30 seconds** for the remaining **10 NM**.
- This is estimated progress along the selected planned leg, assuming it is being flown correctly. It is not measured route progress and does not consult actual position, wind drift, or navigation-error corrections.
- Playback determines how quickly simulated seconds pass; it must not be applied a second time to the estimated travel calculation. Pause contributes no simulated travel.
- The build plan specifies the zero-airspeed unavailable state, preserving the original recommendation below. When estimated remaining distance reaches zero, use the count-up behavior below; do not infer arrival or advance the leg automatically.

## Route coverage and navigation instructions

Time **the complete planned route**, including the final segment from the last intersection to the destination airport, confirmed by the owner on **2026-10-16**.

- Derive timed legs from consecutive geometric route points, rather than assuming every instruction is a travel leg or every leg has a direct VOR-course instruction.
- For Transport this means **5 timed geometric legs**, including the final intersection-to-Midland Cityport segment. Their planned durations must sum to the original total still-air estimate before presentation rounding.
- The final Elmstead radial remains navigation guidance for locating the destination area. It is not an extra timed leg, an additional distance, or a newly invented literal airport course.
- Preserve the existing route, reference radial, and distinction between planned airport geometry and practical navigation guidance. This feature supplies timing; it does not change the authored navigation problem.
- The player can explicitly start timing the final geometric leg just as with earlier route legs. Neither the final leg's estimated expiry nor a checked final instruction completes the flight automatically.
- Non-travel instructions have no independent travel duration. Current/next timing follows the geometric leg order, independently of checklist edits.

## Timing during flight

Show updated timing for **the current leg and the next leg**, clarified by the owner on **2026-10-16**. Previewing whether the next leg is roughly **2 simulated minutes** or **5 simulated minutes** is useful before the current leg ends.

- Keep every leg's original planned duration and cumulative planned arrival time available during flight.
- For the selected current leg, show still-air estimated time remaining and the updated estimated arrival time measured from flight start.
- For the immediately following route leg, preview its **full still-air duration at the current airspeed**. Recalculate that preview when airspeed changes, so it reflects the speed the player is currently flying.
- The next-leg preview is not a second active countdown. It assumes the next leg will be flown at the current airspeed; its timer starts only when the player explicitly selects **Start this leg**.
- Legs beyond the next leg retain their original planned timing; continuously recalculating forecasts for the entire remaining route is outside the chosen scope.
- When the selected leg has no following route leg, omit the next-leg preview. Do not fabricate a next leg from a non-travel instruction.
- The original planned timing remains distinguishable from the current and next updated estimates. The next leg's updated preview supplies full duration at current airspeed; an additional dynamically forecast arrival time for that unstarted leg is not part of the first display. Its original planned arrival time remains available in the schedule.

### Persistent summary and full mission panel

Keep a **compact current/next timing strip just above the cockpit**, confirmed by the owner on **2026-10-16**.

- The strip remains visible whether the mission panel is open or hidden. It is part of the live mission surface rather than content that disappears with the collapsible panel.
- Show the current leg's estimated remaining time and the next leg's full duration at current airspeed. Identify which legs those values refer to and state the still-air basis.
- Keep the full original schedule, cumulative planned arrival times, selected leg's updated arrival time, and explicit timer controls in the mission panel. In the owner's **2026-10-16** Stage 2 review, this was clarified to **one instruction list with timing in each step**, replacing the implemented duplicate NAV/timing lists. The plan applies shared combined cards to briefing and flight, while preserving separate underlying geometry and navigation guidance.
- The briefing presents the full original schedule before flight using the assigned planning airspeed. The live mission retains that schedule for reference.
- Preserve readable cockpit instruments and chart controls, including at the existing **1100×760** minimum content size. Do not place geographic progress or true aircraft position on the chart as part of the timing display.
- Exact typography, spacing, and compact time formatting remain visual-design choices for the bounded feature plan. The persistent-summary placement and information split are settled.

### After the estimate passes

Count upward as **Past still-air estimate: 0:45**, confirmed by the owner on **2026-10-16**.

- At the estimated end of the selected leg, transition from a remaining-time countdown to elapsed simulated time since that estimate was reached. Do not leave the display permanently at **0:00**.
- Retain the current leg selection and next-leg duration preview until the player explicitly selects another leg or restarts the timer.
- Preserve the simulated timestamp when the still-air estimate was reached, so the count-up and displayed estimated arrival refer to that event rather than continually moving arrival forward to the current flight time.
- Pause freezes the count-up; resume continues it. Changing airspeed after the estimate has passed does not restart it or imply arrival.
- Use wording about time **past the still-air estimate**, rather than claiming that the aircraft is late, has overshot, or is at the waypoint. Wind and navigation can make the estimate differ from actual progress.
- Do not advance the selected leg, change checkboxes, complete the flight, or inspect hidden position when the estimate expires.

## Optional return to normal playback

Offer **Return to 1× with 1 minute remaining**, confirmed by the owner on **2026-10-16**. It is **off by default** until the player enables it.

- The threshold is **60 simulated seconds of estimated time remaining** on the current leg. It is not 60 wall-clock seconds and is not based on the next leg's duration.
- The trigger uses only the current still-air running estimate. Do not inspect actual position, distance to a waypoint, wind, or whether the player has flown correctly.
- When enabled and the threshold is reached during accelerated playback, return playback to **1×**. Do not pause the flight or change airspeed or heading.
- At **30×**, 60 simulated seconds passes in **2 wall-clock seconds**. Automatic return gives the player time to attend to the instruments without relying on noticing a late visual reminder.
- The persistent strip should distinguish the approaching estimate visually even when automatic return is disabled. Exact visual treatment remains a design detail; this is a navigation estimate, not an arrival confirmation.
- Arrival, checklist edits, starting another leg, and Flight Complete remain manual. Playback assistance does not validate any of them.
- **Return to 1× at most once per leg start**, confirmed by the owner on **2026-10-16**. After that return, the player may freely select faster playback; the aid must not keep enforcing 1×.
- Explicitly starting or restarting a leg enables another one-time return when the option is enabled. Ordinary pause/resume, airspeed changes, and editing checkboxes do not re-arm a consumed return.
- The build plan resolves enabling inside the threshold and preference retention across Fly Again versus a fresh mission, using the engineering recommendations below.

## Technical shape and responsibilities

- **Mission route information** supplies ordered leg identities, endpoint labels, planned distances, and the assigned planning airspeed. Derive the original schedule from those values. Preserve the separation between route geometry and navigation instructions.
- **The timing aid** owns the player-selected leg, timing reference, estimated distance covered, expiry timestamp, most recent undo context, and whether that leg's one-time playback return has been consumed. Its calculations need airspeed and simulated time, not actual position, heading, wind, or recording samples.
- **The existing flight session and clock** remain authoritative for movement, simulated elapsed time, pause, completion, and recording. Feed timing from the same simulated advances and airspeed changes; do not introduce an independent wall-clock countdown or duplicate flight simulation.
- **Presentation** shows the fixed original schedule, selected-leg estimate, next-leg preview, and explicit timing actions. The optional assist requests a playback change only through the flight's existing playback control.
- **Mission lifecycle** creates fresh timing state on Fly Again and stops live timing with flight completion or departure from the mission. Timing is shared mission capability, not a Silverkeep/Midland special case. Free Flight and Position Challenge do not gain mission timers.
- Keep future player-authored routes and wind-planning tools possible by preserving separate original planning assumptions and running estimates. Do not add either of those deferred features in this slice.

## Remaining planning decisions and recommended defaults

The main product decisions are settled. The following recommendations were handed off to planning, distinct from the owner-confirmed choices above. The linked build plan now makes them explicit, including the previously open after-expiry enabling case; use the plan for execution rather than reopening these as owner questions. They are retained here as the exploration's design rationale.

1. **Zero or missing timing inputs.** Recommend showing **Unavailable at 0 kt** for a not-yet-expired current estimate and the next-leg preview, retaining accumulated estimated progress and resuming calculation when airspeed becomes positive. Do not show zero remaining, infinity, or a wind-derived substitute. An already expired estimate continues its simulated-time count-up. For a mission without usable route timing, recommend omitting the timing strip/actions while preserving its ordinary instructions and flight; if a supplied timing value is invalid, show an explicit unavailable state and never invent distance or fall back to hidden position. Define validation and handling of zero-length legs in the plan.
2. **Starting, Undo, and lifecycle defaults.** Recommend allowing Start/Restart while paused, with no estimated travel until Play resumes. An explicit selection made before first Play should take precedence over the automatic first-leg default. Undo should restore the previous leg/start/progress/expiry/assist context, account for elapsed simulated time and airspeed changes while that context was inactive, and then become unavailable until another manual start/restart. Undo must not undo a playback change or replay a previously consumed automatic return. A fresh flight clears timing progress, undo context, and per-leg assist consumption.
3. **Short legs, enabling assistance, and preference scope.** Recommend applying the one-time return immediately on accelerated Play if an enabled, unconsumed leg is already within its final 60 estimated simulated seconds, including a short leg or an airspeed change that jumps inside the threshold. Enabling the option inside that interval should have the same effect; paused flights wait until Play. Toggling the option must not re-arm an already consumed return. Recommend retaining the enabled choice for Fly Again and Back to Briefing within the same briefing, starting a newly opened briefing with it off, and adding no cross-launch persistence. The plan must also define behavior if the option is first enabled after the estimate has expired.
4. **Event ordering and precision.** Specify how speed edits, simulated advances, expiry, automatic return, Undo, and completion interact without double-counting time. The optional return must not skip its threshold at 30× or during a large advance. Preserve the existing flight/recording timing guarantees and numerical tolerances. Resolve compact formatting, rounding of cumulative times from unrounded values, and the precise approach/expired visual treatment. These are engineering/visual decisions, not permission to change navigation data.

The current source provides the required route geometry, speed control, simulated clock, and shared mission flow. There is no identified missing prerequisite. The existing I-003 final owner review remains a separate project checkpoint; this exploration does not accept or archive that work.

## User-visible outcomes and next bounded slice

Plan one **mission leg timing** feature using this exploration as its requirements source. Useful visible landmarks are:

- **Read the whole flight's schedule:** In Missions → Transport → Briefing, inspect each geometric leg's distance, planned duration, and cumulative planned arrival time, including the final airport segment. Depends on the existing resolved route and assigned planning airspeed.
- **Manage a flight using current and next timing:** Fly Transport, inspect the persistent strip with the panel open or hidden, change airspeed, pause/resume, explicitly start the next leg, and try Undo/Restart. Enable the optional one-time return to 1× and see an expired estimate count upward. Depends on that same schedule and the authoritative simulated flight clock.

The first supplied route is the owner's visible trial path. Planning should also provide a bounded way to inspect different route/leg counts and absent timing data through the existing development preview or an equivalent shared-mission surface, without adding a production mission solely for testing.

Success means the player can see whether the current leg has several estimated minutes left and whether the next is short or long, use faster playback intentionally, and return attention to the instruments. Timing remains an estimate they navigate with; it never confirms actual progress for them.

Wind correction as a player flight-planning skill, editable planning airspeed, historical timer entry, whole-route live forecasts, automatic arrival detection, and scoring remain later work. No production code, dependency, bundled content, Xcode project, or existing active plan was changed in this exploration.
