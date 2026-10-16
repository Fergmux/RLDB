# Playtest feedback F04 — implementation and verification checklist

Source: `design/playtest-feedback-04.md` (F04-01..F04-22, 16 Oct 2026).

Quality bar from the user: fancy and production ready, with maximum design quality on every element touched and no shortcuts.

## Work packages (parallel worktrees; the lead reviews every screenshot and merges)

| Pkg | Owner (agent / model) | Items | Files owned |
| --- | --- | --- | --- |
| A | ui-programmer / sonnet | 15, 17, 18, 19, 20, 21 | `deck_builder.gd` |
| B | ui-programmer / sonnet | 08, 09, 10, 11, 12, 14 | `src/tutorial/*`, `main_menu.gd` |
| C | technical-artist / sonnet | 01, 04, 07 | `src/ui/fx/*`, `coin_flip.gd`, `sfx.gd` |
| D | technical-artist / sonnet | 05, 06, 16 | `card_widget.gd`, `src/ui/card/*`, `card_inspector.gd` |
| E | ui-programmer / sonnet | 02, 03, 13 | `game_series_overlay.gd`, `game_reward_panels.gd`, `game_prompt_banner.gd` |
| F | gameplay-programmer / opus | 22 | `src/core/*`, rules tests |

## Items

| Item | Status | Owner | Implementation | Verification |
| --- | --- | --- | --- | --- |
| F04-01 Coin flip readable | In progress | C | | |
| F04-02 Pre-game deck select | In progress | E | | |
| F04-03 Rewards modal | In progress | E | | |
| F04-04 Full-screen victory/defeat | In progress | C | | |
| F04-05 Sharp card names | In progress | D | | |
| F04-06 No colour square before type text | In progress | D | | |
| F04-07 Direct attack and killing blow | In progress | C | | |
| F04-08 Tutorial ring under modals | In progress | B | | |
| F04-09 Play tutorial for new players | In progress | B | | |
| F04-10 Tutorial arrow direction | In progress | B | | |
| F04-11 Tutorial pane buttons at bottom | In progress | B | | |
| F04-12 Formatted tutorial text | In progress | B | | |
| F04-13 Input panel fits and has depth | In progress | E | | |
| F04-14 Lesson complete modal | In progress | B | | |
| F04-15 Deck builder preview formatting | In progress | A | | |
| F04-16 No inspector close hint | In progress | D | | |
| F04-17 Saved-deck list | In progress | A | | |
| F04-18 Deck contents as card grid | In progress | A | | |
| F04-19 Catalogue cells without caption box | In progress | A | | |
| F04-20 Save error near name field | In progress | A | | |
| F04-21 Remove limits note | In progress | A | | |
| F04-22 Fusion materials before costs | In progress | F | | |

## Deviations for user review

| Item | Suggested | Implemented | Why |
| --- | --- | --- | --- |

## Agent ledger

| Task | Role | Model | Result |
| --- | --- | --- | --- |
