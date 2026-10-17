# Playtest feedback F06: implementation and verification checklist

Source: `design/playtest-feedback-06.md` (17 Oct 2026).

| Item | Status | Owner | Implementation | Verification |
| --- | --- | --- | --- | --- |
| F06-01 Modals follow the input-panel design | In progress | ui-programmer / opus (worktree) | | |
| F06-02 Menu and battle playlists | Implemented, needs a listen | lead | `Music` director: two players on the Music bus, playlist `menu` (menu_1, menu_2) and `battle` (battle_1..3); songs in turn, looping; 3 s crossfade between songs and on scene changes. `GameScreen._on_view` picks battle while stage = game, menu otherwise; `_show_menu` picks menu. Tracks converted WAV → Ogg Vorbis q7 (about 20 MB instead of 140 MB). Steady Pulse removed | `music_f06_test.gd` (3): tracks load, playlists cycle, switching crossfades. The mix still needs your ears |
| F06-03 Structure decks replaced | Verified | lead | `data/starter_decks.json`: the 12 decks from the sheet, ids checked against `cards.json`, all fully implemented, Extra Deck cards in Extra | `series_flow_test.gd` (12-card mains, routing); full suite 596/596; f02 driver 74/74; deck select shows all 12 |

## Open questions for the user

| Item | Question |
| --- | --- |
| F06-03 | Deck 10 (Lone Warrior / Revealed): the third Extra Deck card is `#REF!` in the sheet, so the deck has 2 Extra cards. Which card should it be? |
| F06-03 | The sheet's Tag Team names disagree with its ids: it calls 11 "Tag Team - J" and 7 "Tag Team - B", but the database has 7 = Tag Team - J (Water Mage) and 11 = Tag Team - B (Lightning Beast). The ids were kept: Tag Team - B (Beast) in Moving Ocean (Water Beasts) and Tag Team - J (Mage) in Lone Warrior (Lightning Mages) and Dragons Domination. Confirm, or say which you meant. |
| F06-03 | Symbiote - White (157) and Symbiote - Black (155) show as `#N/A` in the sheet. They exist in the database and are included in Basic Beatdown and Bahatia Chaos. |

## Deviations for user review

| Item | Suggested | Implemented | Why |
| --- | --- | --- | --- |
| F06-02 | The supplied WAV files | Shipped as Ogg Vorbis q7 (about 224 kbps). The originals are untouched in Downloads | The WAVs would have added about 140 MB to the build. q7 is transparent for listening |
| F06-02 | Fade between songs and scenes | 3 s crossfade. On game end the music switches to the menu playlist when the rewards stage begins, which is during the victory / defeat presentation | One playlist switch per scene change |
