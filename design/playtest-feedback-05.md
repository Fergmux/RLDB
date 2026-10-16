# Playtest feedback 05 (F05)

Captured on 17 Oct 2026, after the F04 batch. The F04 quality bar still applies: production-ready design on everything we touch.

`production/stories/playtest-feedback-05.md` is an older, unrelated round. This batch is tracked in `production/stories/playtest-feedback-F05.md`.

## F05-01 — Separate Ritual and Arcane tutorials

- **Wanted:** dedicated lessons for the Ritual summon and the Arcane summon, alongside the existing Fusion lesson. Today Ritual and Arcane are only described in text inside the Fusion lesson.
- **Acceptance:**
  - Each lesson is staged the same way as the others: a premade board, a scripted Rival, and forced steps that use the real rules.
  - The **Ritual** lesson covers Runes on a unit, tributing it for the Ritual unit, and where the material goes.
  - The **Arcane** lesson covers Spent units whose current costs add up to *exactly* the requirement, the picker showing "total X / exactly N", and the materials exhausting.
  - Both lessons can be completed from the menu, and the lesson list, progress and completion card all include them.

## F05-02 — Tutorial under Play

- **Wanted:** move the Tutorial menu option up a level, into **Play**, instead of **Play → Local**.
- **Acceptance:** Play lists the Tutorial entry directly, and Play → Local no longer does. The new-player "Play tutorial" entry still works.

## F05-03 — Card hover scaling without reflow

- **Report:** when a card scales on hover (for example on the draft screen), its text reflows.
- **Wanted:** the text scales smoothly with the card and stays crisp, without reflowing.
- **Background:** this supersedes how F04-05 was done, not its goal. F04-05 swapped the `scale` tween for a real size change so text stayed sharp, but a real size change lays the text out again at every step, which causes the reflow.
- **Acceptance:**
  - At every point of the hover animation the card's line breaks and text proportions match its resting layout.
  - Text stays crisp at the lifted size.
  - The motion is smooth, with no stepping.
  - This holds everywhere cards lift: hand, Field, draft, rewards and the deck builder.

## F05-04 — 30 FPS in the background

- **Wanted:** when the game window is in the background, limit it to 30 FPS.
- **Acceptance:**
  - Losing focus or being minimised caps rendering at 30 FPS.
  - Regaining focus restores the normal rate.
  - Online sessions and timers keep working while in the background.

## F05-05 — No-legal-target notice wording

- **Wanted:** the "no legal target" notification should not say "so this part does nothing".
- **Acceptance:** the notice names the effect and says there is no legal target, without the trailing clause, everywhere it appears (toast and log).
