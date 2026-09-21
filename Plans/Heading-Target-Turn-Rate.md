# Heading target and turn rate

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

- Run the VORVocationalTests test suite.
- Run the app and confirm that selecting a new heading moves the bug
  immediately while the compass card and map aircraft turn gradually.

## Commit point

After verification, report the result and ask the owner whether to commit
before starting unrelated work.
