# Playtest feedback 05 — look and feel (user feedback, 16 Oct 2026)

Verification: GdUnit 412/412; live driver 73/73 and bot driver 4/4 in the editor and the exported
exe. Evidence: `production/qa/evidence/2026-10-16-fb5/`.

| # | Request | Implementation |
| --- | --- | --- |
| 1 | Card names centred | `CardWidget._name_plate` centres one- and two-line names |
| 2 | Thinner border on the type icon and its circle | Icon outline 0.05 r (was 0.09), pip rim 0.04 r (was 0.08) |
| 3 | No "On Field:" prefix on the card text | `CardWidget.card_text()` drops that caption (others kept); also used by tooltips and the pile list |
| 4 | Darker tooltip | Theme `TooltipPanel`: near-black, gold hairline, shadow; text wrapped to ~58 characters |
| 5 | Juicier buttons and phase tags | `JuicyButton` (gloss, highlight line, hover lift, press-in), drop shadows / hover glow in the theme and on action rows; phase tags are pill shapes with depth, the current one glows |
| 6 | No keyboard shortcuts shown anywhere | "(Esc)", "(Enter)", "press Tab", "Right-click or Esc" removed from buttons and hints |
| 7 | Remove "End" tag; Main 1 / Main 2 -> Setup / Recovery | Phase tags Setup · Battle · Recovery; banners "SETUP PHASE" / "RECOVERY PHASE"; "Go to Recovery"; log and rule messages say Setup / Recovery |
| 8 | Cost tag without "Cost" | "1 AP" with the gem icon; special costs show their text only |
| 9 | Stat change arrow by the resulting number | The up/down marker sits beside the current value; "Base: n" stays plain |
| 10 | Piles as a scrollable list in the details panel | Click your pile: the details panel becomes "Your Spent (n)" with rows (small card, name, kind/cost/race-type/stats, effect text); click a row to select it (Extra Deck rows show Summon buttons, scrolled into view); Close / Esc / clicking the pile again returns to card details |
| 11 | Pile-pick window centred, no extra margin | Grid sized to the cards with equal padding, centred in the play area |
