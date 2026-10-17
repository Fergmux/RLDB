# Playtest feedback 08 (owner, 17 Oct 2026)

Owner instruction: address each item one by one, using subagents and skills; look for bugs and UI
inconsistencies; keep changes polished and production ready.

| ID | Feedback (owner's words, condensed) | Owner | Status |
| --- | --- | --- | --- |
| G01 | Leaving from the rewards screen (before or after picking) must not say "quitting will forfeit the match". Say the game can be resumed later, with three buttons: **Save and quit**, **Forfeit and quit**, **Keep playing**. | A | verified |
| G02 | A flash appears when opening or closing a deck's details on the pre-game deck select screen. | A | verified |
| G03 | The input confirmation modal must always show every card it mentions (e.g. "Radablast attacks Basic Monster, activate Damage Conversion?" shows all three). **Pass** always sits below **Activate**. | B | verified |
| G04 | Arcane summon modal (AP dots): remove the small text above the dots and rely on the title and dots. The title in those modals is slightly smaller. | B | verified |
| G05 | After both players have chosen their rewards, show a **Start next duel** button instead of starting the next game automatically. | A | verified |
| G06 | Who-goes-first screen: centre the text and the buttons. | A | verified |
| G07 | Diggie must not attack directly automatically. In the Battle Phase it offers two options: **Attack** and **Attack direct**. | C | verified |
| G08 | Bug: after sacrificing a card for AP, the summon-placement arrow starts from front zone 2 instead of the card being summoned. It must always start from the summoned card. | C | verified |
| G09 | The "no legal target" popup appears above the card that tried to use the effect, not at the top of the screen. | B | verified |
| G10 | After winning a game and returning to the menu, the menu background image is missing. | C | not reproduced; background textures cached |

Progress, decisions and verification: `design/playtest-feedback-08/progress.md`.
