# Flight plan format v0

## Purpose

This format represents the geography of an authored flight. It lets the app
draw a route on the chart, calculate distances and still-air estimates, and
derive the VOR instructions a player sees.

A flight plan contains only an origin, ordered waypoints, and a destination.
Wind, aircraft, starting radio state, scoring, visibility rules, and failure
conditions belong to a separate flight scenario.

## Route shape

```text
FlightPlan
  origin: PlanPoint
  waypoints: [PlanPoint]
  destination: PlanPoint
```

`origin` and `destination` use the same point types as a normal waypoint. A
round trip can therefore use the same airport as both origin and destination.

The complete ordered route is always:

```text
[origin] + waypoints + [destination]
```

## Point types

### Airport

An airport point references the stable ICAO value from `Airports.json`.

```json
{ "kind": "airport", "icao": "GPSK" }
```

### VOR

A VOR point means the route passes over that station. It references the stable
station `id` from `VORStations.json`, not its displayed ident.

```json
{ "kind": "vor", "stationID": "mossbarrow" }
```

### Radial intersection

An intersection point is the meeting point of two VOR radials. Every stored
radial is an outbound radial measured FROM its station. The player-facing
briefing can later translate a radial into a reciprocal OBS course with a TO
indication when the player is approaching that station.

```json
{
  "kind": "intersection",
  "radials": [
    { "stationID": "mossbarrow", "radialDegrees": 154 },
    { "stationID": "marrowfield", "radialDegrees": 286 }
  ]
}
```

The two station IDs must differ. The two radial courses must have a unique,
usable intersection inside the Myosia chart and inside the service range of
both VORs. Coincident or non-intersecting radial rays are invalid.

The app also calculates the angle between the two radials and marks a shallow
angle as a weak position fix. A weak fix remains valid as a route point. It is
often enough to tell a player when to turn during an en-route leg, even though
it cannot locate the aircraft precisely.

## First reference plan

```json
{
  "id": "silverkeep-to-midland",
  "name": "Silverkeep to Midland",
  "origin": { "kind": "airport", "icao": "GPSK" },
  "waypoints": [
    { "kind": "vor", "stationID": "mossbarrow" },
    {
      "kind": "intersection",
      "radials": [
        { "stationID": "mossbarrow", "radialDegrees": 154 },
        { "stationID": "marrowfield", "radialDegrees": 286 }
      ]
    },
    { "kind": "vor", "stationID": "marrowfield" },
    {
      "kind": "intersection",
      "radials": [
        { "stationID": "marrowfield", "radialDegrees": 78 },
        { "stationID": "elmstead", "radialDegrees": 353 }
      ]
    }
  ],
  "destination": { "kind": "airport", "icao": "GPMC" }
}
```

The navigation brief derived from this plan includes the following actions:

```text
Silverkeep -> MSB:       MSB, OBS 103, TO
MSB -> first intersection: MSB, OBS 154, FROM
First intersection -> MFD: MFD, OBS 106, TO
MFD -> second intersection: MFD, OBS 078, FROM
Second intersection -> Midland: ELS, OBS 353, FROM
```

## How the planner uses this format

The map editor creates the same ordered structure. It does not parse a
free-text flight plan.

1. The player selects an origin.
2. The player adds VORs or creates an intersection by choosing two VOR radials.
3. The player selects a destination.
4. The app validates the result and generates the readable briefing, chart line,
   leg distances, total distance, and still-air estimate.

For a direct airport-to-VOR leg, the app calculates the bearing to the VOR and
uses that course with a TO indication. For a leg that leaves a VOR toward an
intersection, it uses that VOR's radial with a FROM indication. For a leg from
an intersection to a VOR, it uses the target VOR's radial reciprocal with a TO
indication. A leg from an intersection to an airport continues along the
radial that leads from the intersection toward that airport.

## Hidden-position starts

A loss-of-position mission still has a real, exact starting coordinate in the
scenario. The flight plan may represent the location as a radial intersection
so the player can rediscover it with the chart and NAV radios.

The scenario retains the exact coordinate for simulation and scoring. It must
not rely only on rounded degree values because rounding both radials can move the
calculated intersection by several NM.

## Validation required before a plan can fly

- Every airport ICAO and VOR station ID resolves to bundled content.
- The route has at least an origin and destination.
- No two consecutive points occupy the same location.
- Every intersection has two different VORs, a unique point within the chart,
  and both VORs in service at that point.
- Every derived leg has a finite length and a valid navigation instruction.

An intersection's quality is not a structural validation rule. The mission that
uses the plan decides whether a weak fix is acceptable:

- An en-route turn may accept a shallow-angle fix and treat it as an approximate
  cue.
- A final destination fix must predict an uncertainty smaller than its required
  arrival radius, or the mission rejects it.

The calculation should use the intersection angle and expected radial-selection
error, rather than a single global "nearly parallel" degree threshold.

## Deliberately deferred

- User-created arbitrary points that are neither a VOR, airport, nor radial
  intersection.
- DME arcs, holds, airways, and altitude constraints.
- Persisting a user-authored plan outside the app bundle.
- Wind-adjusted ETA. Version zero reports a still-air estimate only.
