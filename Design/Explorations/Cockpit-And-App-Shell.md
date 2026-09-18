# Cockpit And App Shell — Exploration

Status: **CLOSED 2026-09-18**
Started: 2026-09-18 · via /a-explore
IDs: **S** = scope · **I** = implementation · **U** = UI/UX

## Grounding

- The app opens straight into the map: `Xcode Proj/VOR Vocational/App/ContentView.swift:12` (`MapView()`).
- `MapView` currently reserves a right-side control panel and a fixed bottom panel: `Xcode Proj/VOR Vocational/Features/Map/MapView.swift:84-85` (`geometry.size.width - controlPanelWidth`, `geometry.size.height - panelHeight`).
- The bottom panel contains flight controls and two NAV instruments: `Xcode Proj/VOR Vocational/Features/Map/MapView.swift:112-136` (`PlaneControlView(...)`, `NavRadioView(...)`).
- Its receiver state is station identifiers plus OBS values: `Xcode Proj/VOR Vocational/Features/Map/MapView.swift:21-28` (`nav1Ident`, `nav2Ident`, `nav1OBS`, `nav2OBS`).
- Station data includes each receiver frequency and a formatted label: `Xcode Proj/VOR Vocational/Domain/Models.swift:48-75` (`frequency`, `frequencyLabel`).
- The always-visible map panel currently exposes chart configuration and Position Challenge actions: `Xcode Proj/VOR Vocational/Features/Map/MapView.swift:144-156` (`MapControlPanel(...)`).
- The glossary defines the player-facing terms Mode, Free Flight, Skill Exercise, and Mission.
- `Roadmap-V0.1-V0.5` describes the intended V0.2 cockpit and app shell; it supplies context for this exploration, not execution instructions.
- No existing exploration covers this shell. There is no `Design/Tickets/` folder, so no tickets were swept or folded in (0 untriaged).

## Tickets folded in

- none.

## Scope & purpose

- **S1** — V0.2 opens on a home screen that presents Learn, Practice, Free Flight, and Missions as four large horizontal, artwork-led Mode cards. Every card has its Mode label. Free Flight enters the new chart-and-cockpit screen directly. Learn, Practice, and Missions each enter a separate list screen.
- **S2** — Position Challenge is a Practice Skill Exercise and is available from the Practice list in V0.2.
- **S3** — The V0.2 Learn and Missions lists show named, visibly unavailable future entries rather than an empty state. Their entries draw on the established concepts in `NorthStar`.
- **S4** — The Learn list shows Position Fix and Radial Intercept and Track as unavailable future Skill Exercises. The Missions list shows Transport, Sightseeing, Nav Failure, Off-course Recovery, and One NAV Down as unavailable future Missions. These entries remain in place so later versions can activate them without restructuring the Mode lists.
- **S5** — Every home-screen Mode card includes one concise descriptive phrase beneath its label. The Learn, Practice, and Missions list screens do not repeat descriptions; they focus on their named entries.
- **S6** — Free Flight retains all current flight and chart functionality inside a reorganized, cleaned-up interface. Its NAV radios are functional physical controls: the player tunes by frequency and sees the matching station identifier when that station is received.

### Non-goals

- The unavailable future entries must not contain working V0.2 activities.
- Apart from Position Challenge in Practice, V0.2 does not add functional Learn exercises or Missions.
- V0.2 does not change the existing flight model, scoring, or introduce a mission system; it reorganizes the existing interface and radio operation.

## Implementation

- **I1** — Free Flight is the baseline chart-and-cockpit flight surface. Future Mission flight screens reuse that surface and add mission-only functionality, such as route planning; V0.2 does not implement those additions.
- **I2** — Leaving Free Flight returns the player to the home screen. Entering Free Flight again starts a fresh session with new aircraft and instrument state; V0.2 does not resume a prior session.
- **I3** — V0.2 extracts a reusable baseline flight surface from `MapView`; Free Flight is a thin wrapper that supplies its plain configuration. Future Mission screens reuse that surface and layer mission-only panels and rules around it rather than switching optional behavior throughout one all-purpose screen.
- **I4** — Each NAV receiver tunes the full 108.00–117.95 MHz band in 0.05 MHz channels. The selected frequency is always displayed; the matching station identifier and usable navigation indication appear only while the station is received. Tuning provides separate coarse MHz and fine 0.05 MHz adjustment.
- **I5** — Each NAV receiver presents paired physical-looking rotary knobs: one changes whole MHz and one changes 0.05 MHz channels. V0.2 does not use a concentric knob or frequency-display selection state.
- **I6** — The whole-MHz knob stops at 108 and 117. The 0.05 MHz knob wraps within .00–.95 without changing the whole-MHz value.
- **I7** — Each entry into Free Flight constructs one per-flight session object containing the shared flight state. The reusable flight surface operates on that object; future Mission screens create the same base object and add mission-only state around it.
- **I8** — A dedicated NAV1 ↔ NAV2 control exchanges the receivers’ active frequencies and OBS settings together. It does not change aircraft state or any other flight setting.

## UI / UX

- **U1** — Home, the Mode lists, and Free Flight replace one another in the primary app window. Player-visible diagnostics open only in a separate debug-only window.
- **U2** — A persistent, clearly labelled Home control sits in the upper-left of each Mode list and the Free Flight screen. It is a small, clear Liquid Glass button that expands slightly on mouse hover.
- **U3** — An unavailable future Learn or Missions entry is a non-selectable row with a small, discreet “Coming soon” label. It does not show a preview or react to selection.
- **U4** — Home arranges the four large, horizontal Mode cards in a two-by-two grid.
- **U5** — Home uses the Myosia map as a subtly blurred background. Each Mode card uses an SF Symbol for its V0.2 artwork cue; bespoke Mode artwork is deferred for later refinement.
- **U6** — Learn, Practice, and Missions list screens retain the blurred Myosia-map background and place their entries on high-contrast reading panels.
- **U7** — Position Challenge is the only actionable Practice-list row and has a clear Start affordance. All future Practice entries remain non-selectable rows with the discreet “Coming soon” label.
- **U8** — Free Flight places the chart above a bottom-docked cockpit of three equal horizontal bays: heading, NAV1, and NAV2. All bays scale together; a minimum macOS window size prevents a reflow into unrelated compact layouts.
- **U9** — The cockpit is one continuous dark aircraft panel with subtle dividers between the heading, NAV1, and NAV2 bays; it is not three separately raised cards.
- **U10** — Playback speed is a primary normal-flight control and remains in the heading bay; it does not move to debug.
- **U11** — Each cockpit bay uses a vertical arrangement: its primary dial occupies the upper portion and a horizontal row of related controls occupies the lower portion.
- **U12** — The heading bay’s primary dial is the Heading Indicator: the complete black compass display with the aircraft reference and directional markings. Its lower row contains a Heading Knob that replaces the current paired heading buttons; turning left decreases the heading and turns the aircraft left, while turning right increases it and turns the aircraft right.
- **U13** — Play/Pause sits with airspeed, playback speed, and the Heading Knob in the heading bay’s lower row.
- **U14** — Each NAV bay places its VOR Indicator in the upper portion, with its OBS Dial at the lower-left of that instrument. The lower portion is that receiver’s Radio Panel, containing its frequency, received station identifier, and related radio information.
- **U15** — V0.2 uses the CDI-style VOR Indicator in both NAV bays. The HSI presentation is deferred for a later advanced-instrument version.
- **U16** — Each NAV Radio Panel’s lower row contains the selected frequency, received station identifier, and paired whole-MHz and fine 0.05-MHz tuning knobs. Its OBS Dial remains visually attached to the VOR Indicator above it.
- **U17** — A fresh Free Flight session starts NAV1 and NAV2 at 108.00 MHz with no received station identifier. The player tunes both receivers deliberately.
- **U18** — A fresh Free Flight begins paused at Midland Cityport with heading 000° and airspeed 260 knots.
- **U19** — A fresh Free Flight starts both OBS Dials at 000°.
- **U20** — The Chart popover contains player-facing visibility controls for VOR stations and service-volume filters, airports, selected radials, grid and grid scale, and sightseeing regions. The debug-only window contains true position, reception and signal details, CDI scale, and future wind diagnostics. Position Challenge controls move to Practice.
- **U21** — The Chart popover opens from a small, persistent Liquid Glass Chart button in the chart’s upper-right, opposite the Home control in the upper-left.
- **U22** — V0.2 has no custom player Preferences. Chart and flight choices are per-session; durable preferences are deferred.
- **U23** — Flight Diagnostics exists only in Debug builds and opens from a Debug menu item. It is absent from Release builds and normal player navigation.
- **U24** — Flight Diagnostics live-updates aircraft position and receiver/signal values as read-only diagnostics. CDI scale is its sole editable control.
- **U25** — The primary app window has a minimum size of 1100 × 760 points.

## ADR candidates

- Extracting the reusable baseline flight surface and putting one per-flight session object at each Mode boundary — this is a hard-to-reverse structural trade-off that keeps future Mission behavior out of the shared cockpit. `a-create-plan` writes the ADR if the design proceeds.

## Open — queued, in ask order

- none.

## Notes

- V0.1 is complete. This exploration concerns the substantial V0.2 UI change.
