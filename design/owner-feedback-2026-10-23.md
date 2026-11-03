# Owner feedback, 23 Oct 2026 (playtest of build 0.3.9)

The owner's words for each item are quoted. Standing instructions from earlier batches still apply (release
quality, no shortcuts, review visually and with tests, take decisions and list them, no pausing).

| ID | Owner text | Group | Status |
|---|---|---|---|
| K1 | "playing a trap/spell fulscreen should have a sound effect" | A fx | done (daa3430) |
| K2 | "remove the basic x3 text above the change basic unit button once a draft is complete, the check tick icons on a completed draft category are not round and the design is flat, make them more fancy and round" | B ui | done (64d1264) |
| K3 | "the dark background on a coin flip does not fill the whole field, it should" | B ui | done (64d1264) |
| K4 | "When a unit declares an attack and is waiting for trap activation, it shouldn't play the attack animation until the trap has resolved" | A fx | done (daa3430) |

## Decisions for review
- K1: the Spell and Trap spotlight cues are set between the everyday board sounds and the big summon climaxes. They were judged by loudness checks only, so the owner should listen.
- K4: while the Trap prompt is open, the attacker only rears back slightly with a soft glow. The strike plays after the Trap resolves, and not at all if the Trap stops the attack or destroys the attacker. In hot-seat, the hand-over waits for the strike or spotlight to finish.

## Blockers and workarounds
