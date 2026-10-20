# Collapsible mission panel

**Status:** Implemented and verified; awaiting owner review  
**Goal:** Put live Transport and Position Challenge instructions and results in a collapsible panel beside the chart, above the full-width heading/NAV1/NAV2 cockpit.

## Decisions and scope

- The flight surface uses a top row containing the chart and optional right-hand panel, with the existing three-instrument cockpit below it.
- Transport opens with its mission panel visible. A **Hide Mission** / **Show Mission** button sits in the upper-right corner beside **Chart**.
- Hiding the panel gives its space back to the chart without resetting the session, instruction, radios, chart preferences, or completion result. Completing a flight shows its result in the same panel; Fly Again starts with the panel open.
- The panel scrolls at smaller window heights so every instruction and action remains reachable.
- Position Challenge also opens with its panel visible, with **Hide Practice** / **Show Practice** beside Chart. Its Start Challenge, Check Placement, and New Challenge actions use the same panel instead of the draggable overlay.
- Practice's checked guess and target reveal must stay on the same chart locations when the panel is collapsed or reopened. Keep normalized reveal positions in the practice wrapper; navigation scoring remains unchanged.
- Free Flight retains its current presentation. The shared flight surface receives optional panel content without learning mission or practice rules.
- Aircraft truth, route visibility, navigation math, mission advancement, and completion measurement remain unchanged.

## Implementation

- [x] Add optional panel content and a visibility binding to `MapView`; calculate chart geometry from the space left beside the panel, and keep the cockpit sized to the whole window.
- [x] Place the panel toggle beside Chart and re-clamp chart panning when the available chart size changes.
- [x] Move Transport's instruction/result content out of its bottom overlay into the panel; reopen the panel for completion and fresh flights.
- [x] Update the README's description of the live Transport layout.
- [x] Move Position Challenge instructions/results into the shared panel and remove the old card dragging state.
- [x] Keep the checked guess/target reveal aligned when panel visibility changes and update the README's practice description.

## Verification and owner checkpoint

- [x] Build and run the full macOS test suite without project, dependency, signing, content-data, or tolerance changes.
- [x] Run Transport at the 1100×760 minimum: show/hide the panel, open Chart, advance instructions, complete the flight, and Fly Again. Check that instruments remain unobscured and that hiding/reopening retains mission state.
- [x] Recheck Free Flight and Position Challenge after the shared layout change.
- [x] Rebuild and rerun the test suite after the practice integration; verify inactive, active, and revealed practice states, hidden-panel guess placement, retained NAV settings, and aligned reveal after collapse/reopen.
- [ ] Show verification results and stop for the owner to choose whether to commit. Suggested commit: `Use collapsible side panels for missions and practice`.

Archive this plan after the owner accepts the completed feature. Stop and explain any unrelated test failure, missing prerequisite, or architectural change outside this scope.

## Verification result

- `xcodebuild test` with the shared macOS scheme: **29 tests passed, 0 failures**. The initial sandboxed build could not access the development signing certificate; the normal local build succeeded with the existing signing settings.
- Live app at the minimum content size: instructions 1–5 and completion results fit beside the chart without covering instruments. Hide/show retained step 2, NAV1 tuned to MSB 117.15, the disabled Airports preference, and elapsed simulated time while flying.
- Completion reported 0:00:10 and 89.50 NM from Midland; collapsing/reopening retained that result. Fly Again restored step 1, a zero clock, and fresh radios.
- Free Flight retained its aircraft marker and full cockpit.
- After practice integration, the full macOS suite passed again: **29 tests, 0 failures**. Inactive instructions, Check Placement, and New Challenge now appear in the side panel with Hide Practice / Show Practice beside Chart; the cockpit remains unobscured and flight controls remain absent.
- Placed a guess while the practice panel was hidden, reopened it, and checked the placement. The 94.0-NM result and NAV1's MSB 117.15 tuning survived collapse/reopen, and the target pin plus checked-guess line stayed aligned with chart features in both sizes. New Challenge cleared the reveal and restored the centered guess.
