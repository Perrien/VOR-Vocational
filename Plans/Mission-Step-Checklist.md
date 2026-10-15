# Mission step checklist

**Status:** Implemented and behavior-verified; awaiting owner review  
**Goal:** Show every live Transport instruction in an editable checklist instead of a single forward-only instruction.

## Decisions and scope

- List the briefing's five steps in their existing order, with station, frequency, OBS, TO/FROM guidance, and the final position reference.
- Each step has a native checkbox. The player can check or clear any step independently, including out of order.
- Show the number of completed steps. Checklist edits are manual and do not inspect aircraft position or alter the flight controls.
- Keep the existing scrollable, collapsible mission panel. Hiding and reopening it retains checks; Fly Again starts with all steps unchecked.
- Flight Complete remains available regardless of checklist progress and records the existing unscored result.
- This replaces the instruction-advancement behavior preserved by the earlier Collapsible Mission Panel plan. It does not change that plan's layout.

## Implementation and verification

- [x] Replace the active instruction index with independent completion state.
- [x] Replace the current-step display and Next instruction action with the full checklist.
- [x] Update the existing progress test for independent completion, reopening a step, and a fresh checklist.
- [x] Update README with the player-visible behavior.
- [x] Build and run the full macOS test suite.
- [x] In the running app, check and clear steps out of order, scroll to all guidance/actions, hide/show the panel, finish with unchecked steps, and verify Fly Again clears checks.
- [ ] Owner visual review at the minimum window size; automated UI capture returned only a small Stage Manager thumbnail, so full-size readability could not be verified.

## Verification result

- `xcodebuild test` with the existing shared macOS scheme and signing settings: **29 tests passed, 0 failures**. The sandboxed attempt could not access the existing signing certificate; the build with normal local access succeeded.
- The running app exposed all five native checkboxes and their original NAV guidance. Checking steps 2 and 5 raised the count to 2; clearing step 2 retained step 5 and reduced the count to 1. Hiding/reopening the panel retained that state.
- Checking a step during flight left simulation running. Scrolling reached the final reference and Flight Complete. Completion with unchecked steps paused flight and reported 0:00:14 plus 89.61 NM from Midland. Fly Again restored all five unchecked boxes and 0:00:00.
- The freshly built app is open on a fresh Transport mission. To try it from Home, choose Missions → Transport → Fly Transport.

## Owner checkpoint

Show the verification result and a visible way to try the checklist, then stop for the owner to choose whether to commit before changing more files. Suggested commit: `Show mission instructions as an editable checklist`.

Archive this plan after owner acceptance. Stop and explain any unrelated test failure, missing prerequisite, or architectural choice outside this scope.
