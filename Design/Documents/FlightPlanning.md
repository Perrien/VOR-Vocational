# Flight planning and scoring

## Purpose

The first complete flight is the reference scenario for the planning screen,
instrument flight screen, wind model, and debrief. The player must be able to
read a plan, mark or create it on the chart, fly it with the NAV instruments,
and receive a useful result at the end.

This document records decisions made during the first-flight design discussion.
It is a product/design note, not a code specification yet.

## Player-facing plan format

The plan tells the player what to do with the installed radios. It does not ask
the player to translate a VOR radial before flight.

Each leg shows:

```text
Leg name
Tune: station ident and frequency
Set OBS: selected course
Confirm: TO or FROM
Fly: short plain-language objective
Transition: the event that activates the next leg
```

Example first flight:

```text
Origin: Silverkeep Strip

Leg 1 - Silverkeep to Mossbarrow
Tune: MSB 117.15
Set OBS: 103 degrees
Confirm: TO
Fly: east-southeast to Mossbarrow VOR
Transition: arrive at MSB

Leg 2 - Depart Mossbarrow
Tune: MSB 117.15
Set OBS: 154 degrees
Confirm: FROM
Fly: southeast to the MSB/MFD intersection
Transition: establish MFD 106 TO

Leg 3 - MSB/MFD intersection to Marrowfield
Tune: MFD 116.25
Set OBS: 106 degrees
Confirm: TO
Fly: east-southeast to Marrowfield VOR
Transition: arrive at MFD

Leg 4 - Depart Marrowfield
Tune: MFD 116.25
Set OBS: 078 degrees
Confirm: FROM
Fly: east toward Midland Cityport
Transition: establish ELS 353 FROM

Leg 5 - Final position check
Tune: ELS 112.00
Set OBS: 353 degrees
Confirm: FROM
Fly: north to Midland Cityport
Transition: mark arrival at Midland Cityport

Destination: Midland Cityport
```

The matching chart geometry remains available in training and debrief views.
It may explain a leg as "MSB R-154 outbound" or "MFD R-078 outbound," but that
is supporting instruction, not the required player-facing action.

## Route model to establish

The player marks an ordered sequence of route points on the map. A route point
can be an airport, a VOR, a radial intersection, or the destination area.

The app derives the information that follows from those points:

- geometry for the route line and each leg;
- distance in nautical miles;
- selected VOR and frequency;
- OBS course and expected TO/FROM state;
- planned still-air time at the selected aircraft's cruise speed.

An ordered list of airports and VORs is enough for direct legs. A radial
intersection needs its own explicit route-point type because it is not the same
thing as flying over either VOR.

The first flight has two intersection route points:

```text
MSB 154 FROM intersect MFD 106 TO
MFD 078 FROM intersect ELS 353 FROM
```

The first intersection is a course change. The player tracks MSB 154 FROM to
the fix, then tracks MFD 106 TO to Marrowfield. The second is the final position
check near Midland Cityport.

The plan must retain the route geometry and navigation instructions separately.
They agree in a valid plan, but they answer different questions: the chart needs
the former; the player needs the latter.

## Distance and time

The Myosia chart is 500 NM wide. Its height is derived from the map artwork's
1748:1254 aspect ratio, approximately 358.7 NM. Distance calculations therefore
use the map's calibrated east-west and north-south extents, not normalized image
coordinates directly.

For the first version:

- show each planned leg's distance and the total route distance on the planning
  chart;
- show a simulated elapsed-flight clock during flight;
- calculate a still-air estimated time from planned distance and cruise speed;
- do not score elapsed time or playback multiplier;
- add forecast wind and a ground-speed ETA only after the steady-wind model is
  in place.

Distance on the plan is chart measurement. It must not be presented as DME when
the selected VOR does not provide DME.

## Scoring

Every mission has two independently weighted measures.

### Route tracking

The mission defines a reference line for each leg and a corridor width in NM.
While that leg is active, the simulation records aircraft samples and measures
cross-track distance from the reference line. This rewards following the
assigned path without requiring an exact heading in wind.

### Arrival accuracy

When the player marks the flight complete, the mission measures the aircraft's
distance from the destination arrival area. The arrival area is a mission-defined
radius around an airport or other destination point.

The first Silverkeep-to-Midland flight should use 35% route tracking and 65%
arrival accuracy. A player who drifts, recognizes it, and navigates back to
Midland should still succeed.

Suggested mission profiles:

| Mission | Route tracking | Arrival accuracy |
| --- | ---: | ---: |
| Flat cross-country | 25% | 75% |
| First Silverkeep-to-Midland flight | 35% | 65% |
| Sightseeing route | 60% | 40% |
| Mountain corridor | 80% | 20% |

The first debrief may report radio/OBS actions as feedback, but it should not
make them a third scored category until the core route and arrival scoring feel
fair.

## Build order

1. Define a canonical flight-plan format and pure route calculations.
2. Add a narrow map route-preview mode: select ordered route points, draw the
   route, and show derived leg distance and still-air time.
3. Render the player-facing instructions from that plan.
4. Add plan-to-flight handoff, active-leg transitions, track recording, and the
   completion action.
5. Add the scoring/debrief view using the recorded track and arrival position.

The map ruler is therefore part of the route-preview feature, not a separate
feature to build first.
