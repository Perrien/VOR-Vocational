# Heading target and turn rate

**Status:** Complete

## Outcome

The heading presentation now distinguishes the aircraft's actual heading from
its selected heading. The heading bug responds immediately, while the compass
card and aircraft turn toward it at the bounded, playback-scaled rate.

## Goal

Make heading changes readable and gradual: show both the aircraft's actual
heading and the selected heading, then turn the aircraft toward the selected
heading at a bounded, playback-scaled rate.

## Scope

- Add separate actual and selected heading state to a flight session.
- Let the heading knob select the target via scroll-wheel increments only.
- Show the actual heading digitally in the heading indicator and the selected
  heading beside the knob, with a heading bug on the compass card.
- Turn at 3 degrees per simulated second, using the existing playback
  multiplier.
- Cover the turn-rate math with focused unit tests.

## Verification

- 2026-10-11: Full `VORVocationalTests` suite passed.
- 2026-10-11: Owner confirmed in the app that selecting a heading moves the
  bug immediately while the compass card and map aircraft turn gradually.

## Commit point

Implementation was committed as `16414b8 Heading and selected heading added.`
