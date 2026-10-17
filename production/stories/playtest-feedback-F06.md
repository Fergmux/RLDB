# Playtest feedback F06: implementation and verification checklist

Source: `design/playtest-feedback-06.md` (17 Oct 2026).

| Item | Status | Owner | Implementation | Verification |
| --- | --- | --- | --- | --- |
| F06-01 Modals follow the input-panel design | Verified | ui-programmer / opus + lead | `HousePanel` (`src/ui/widgets/house_panel.gd`) extracted from PromptPlate (header strip with pip, title and tag; gradient body with weave; gold accent bar; corner flourishes; rounded inner layers; appear / attend animations) and used by the input panel, the card select tray, ConfirmDialog, the in-game menu and settings, the pause veil, the series modal, the deck popup, the card inspector, the pile browser, the lobby list, the privacy screen, the tutorial completion cards and the main-menu panels. The lead removed the pile browser close hint | Suite 596/596; f02 74/74; tutorial driver 211/211; `2026-10-17-f06/modals/` (20 shots including the inspector and pile browser) |
| F06-02 Menu and battle playlists | Implemented, needs a listen | lead | `Music` director: two players on the Music bus, playlist `menu` (menu_1, menu_2) and `battle` (battle_1..3); songs in turn, looping; 3 s crossfade between songs and on scene changes. `GameScreen._on_view` picks battle while stage = game, menu otherwise; `_show_menu` picks menu. Tracks converted WAV → Ogg Vorbis q7 (about 20 MB instead of 140 MB). Steady Pulse removed | `music_f06_test.gd` (3): tracks load, playlists cycle, switching crossfades. The mix still needs your ears |
| F06-03 Structure decks replaced | Verified | lead | `data/starter_decks.json`: the 12 decks from the sheet, ids checked against `cards.json`, all fully implemented, Extra Deck cards in Extra | `series_flow_test.gd` (12-card mains, routing); full suite 596/596; f02 driver 74/74; deck select shows all 12 |
| F06-04 Change basic units reward (all together) | Verified | gameplay-programmer / opus | "Change basic units": pick one Type and one Race, and every basic unit in the deck becomes that card in one step, for one pick; a no-op is refused without spending a pick; `{"t": "reward_basic", "to_type", "to_race"}` (the old `from_id` form is still accepted); shared `BasicUnitPicker` | `series_f06_draft_test.gd`; series driver: disabled no-op Confirm, change applied; `draft/draft_11`, `draft_12` |
| F06-05 Choose the draft category order | Verified | gameplay-programmer / opus + lead | Per-seat draft setup (HousePanel): order rows with drag-and-drop and up/down buttons (keyboard focus follows), a pick-sequence bar, "Start drafting", and the other seat's progress. The authority refuses an order that is not exactly the configured categories; bot, LAN and Steam supported. Lead: drop logic covered by a cursor-independent test | `series_f06_draft_test.gd`; `draft_order_drop_f06_test.gd`; series driver 26/26; `draft/draft_01..07` |
| F06-06 Choose basic unit in the draft; no basic count | Verified | gameplay-programmer / opus | Basic Unit removed from the composition steppers, categories and `mode_config.json`; "Choose basic unit" opens the Type x Race picker with a live card; the draft starts with `basic_copies` (3) copies | `series_f06_draft_test.gd`; `draft/draft_04`, `draft_06` |

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
| F06-01 | (strip text not specified) | Header strip titles and tags chosen by the implementer (e.g. "Concede", "Series · Rewards" / "Best of 3", "Card details" / the kind); modals glow gold instead of a dark shadow; main-menu panels opaque | Matches the input panel |
| F06-04 | Change basic units | The `basic_change_all_copies` setting was removed (changing all basics is now the only behaviour) | Follows F06-04 |
| F06-05 | Order every category | Only categories with at least one pick appear in the order | The authority requires exactly that set |
| F06-05 | Pick sequence | The summary sits under the order list, not across the full width | At full width the modal overflowed at 1600x900 |
| F06-02 | Fade between songs and scenes | 3 s crossfade. On game end the music switches to the menu playlist when the rewards stage begins, which is during the victory / defeat presentation | One playlist switch per scene change |

Final verification (F06): GdUnit 614/614, series driver 26/26, f02 driver 74/74.
