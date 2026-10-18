# Card database update — 18 October 2026

The owner supplied a new export (`RLDB Master - Card Database (2)`, preserved unchanged as
`rules/sources/RLDB Master - Card Database (2026-10-18).csv`) with a change list "that may not be
completely comprehensive", and asked for it to be compared with the previous export and
implemented to the new rules, stats and wording. The exhaustive cell diff is
`design/card-database-diff-2026-10-18.md`; this record says what each change means for the game,
how it was implemented and how it is verified.

Statuses: Implemented — verified (tests and live run), unless a row says otherwise.

## Sources

- New: `rules/sources/RLDB Master - Card Database (2026-10-18).csv`, SHA-256
  `85bb97c947df5459ea68d0246a05a3cac643dbab975c6c1e9bbe8b007e73c5bc`, 188 cards (5 new IDs, none removed).
- Previous: `rules/sources/RLDB Master - Card Database (2026-10-17).csv` (kept as history, never imported).
- `tools/import_cards.py` now imports the 18 October file only (pinned hash); `python -I tools/import_cards.py --check`
  proves `rldb/data/cards.json` is current. Every cell the importer changes is kept under `source.raw`.

## The owner's list, item by item

| Owner's item | Found in the CSV | Implementation |
| --- | --- | --- |
| Tag team units updated wording, no effect change | Yes (6–12) | Wording only, except the two items below. |
| God cards destruction wording, no effect change | Yes (21, 22, 23, 161: "Permanently costs +1AP") | Wording only. |
| Shimmer effect change: the affected card's cost increases, not the Spell | Yes (182), plus Infiltrate, +20 ATK (was +16) | The target unit's cost rises by 1 for the game; the Spell's own cost no longer changes. |
| Divine Serpent units destroy all the Divine Serpent units | Yes (158–160) | After the 30 Damage, every Divine Serpent you control (the new one too) is destroyed. |
| Chaos Witch no longer ongoing; default Dark | Yes (13) | One-shot Type change on itself and every Mage on the Field (both sides); the ongoing aura is removed. Dark by default. |
| Waang wording, no effect change | Yes (102) | Wording only. |
| Heavenly and Necrotic become Light and Dark, everywhere | Yes (30 cards, the materials of 61/141/147, Bahatia's Type list) | Renamed in the Type cycle (Light beats Dark beats Physical beats Light), card data, Type icons and colours, the draft basic picker, structure-deck themes, the tutorial, tests and dev tools. Saved decks and series store card IDs, so nothing saved breaks. |
| Basic units' bracketed Type suffix removed | Yes (35 basic units) | Already the case in game (F03-09); the importer's suffix rule now finds nothing to strip. |
| "Facedown" replaced with "Spell/Trap" everywhere | Yes (10, 23, 26, 55, 56, 79, 98) | Card text from the CSV; ability labels, prompts, the log ("a set Spell/Trap is destroyed"), target labels, the battle preview risk note and the response panel. "Set face down" as the action of setting a card is unchanged. Where "destroy a Spell/Trap" now also hits a revealed set card (10, 23, 26), that is implemented and tested. |
| "Have cards on your field" becomes "control cards" | Yes | Wording only (Mirror Force, Strength in Unity, the Fusion methods). |
| Tag Team F, W, J On Destruction effects | Yes | F: destroys every unit in its column with current cost 1 or lower. W: every Spell/Trap in its column. J: destroys a Power. |
| Spend AP becomes Lose AP | Yes | Card text, ability labels ("Lose 1 AP: …"), and the log for ability costs ("loses 1 AP"). Playing a card still "pays" its cost. |
| Lose/gain HP becomes take Damage / Heal, including statuses; Sneaky Snunday no longer affects HP | Yes | Card text, the log ("takes 6 Damage", "heals 4 HP"), Burn/Poison/Medic help text, battle previews, the tutorial and ability labels. Sneaky Snunday no longer reverses any Damage or Healing (card effects and Plan B); ATK/DEF, AP and cost gains/losses still flip. |
| Sneaky Snunday wording, no effect change | Yes | Wording only, apart from the HP rule above. |
| Magic Cylinder, Damage Conversion wording | Yes | Wording only. The confirmed "attack on one of your Units in this Column" correction (C-03) is kept. |
| Tactical Arrangements: draw before discard | Yes, and cost 2 → 1 | Draws, then discards (so it works from an empty Hand); cost 1. |
| Reinforcements wording; "the draw now happens at the start of your turn" | The draw change is on **Options** (169), not Reinforcements | Options: each copy draws a card as a start-of-turn effect, after the normal draw. Reinforcements' own changes (cost 3 → 2, units cost **-2** AP, not -1) are not in the list; implemented as exported. |
| Added Counter Transmutation | Yes (184) | New Trap; see below. "Sell/Trap" typo corrected. |
| You/Your/Opponent keyword capitalisation removed | Yes | Data only (the game does not style these words). |
| Arcane units stat changes | Yes (170, 172, 173, 174, 175, 176) | New stats. Tutorial lesson 7 now reads 32 against 8 and 24 Damage (Boom is 26 ATK). Tritu's DEF is now combined too. |
| "All your" becomes "your" | Yes | Wording only. |
| Necrovast wording | Yes (64) | Wording only (aura unchanged). |
| "On Field" wording replaced | Yes | Wording only (continuous effects were already Field-only). |
| Trap hole condition | Yes (49) | Any summon by the opponent (the 2-cost minimum is gone). |
| Various capitalisation changes | Yes | Data only. |
| New cards: Fence of the Marked Claw, Bronze Salaman, Necro, the Loathsome | Yes (187, 186, 188) | See below. |
| Lone Warrior structure deck gains Bronze Salaman | — | Added to its Extra Deck (now 3 cards like every other structure deck). |

### Changes the list did not mention

- **Drako, Councillor of The Order (185)** — a fifth new card (Arcane 3, Dragon, Physical, 24/16).
- **Energy Dispel (140)** — "Negate the activation and Destroy that card" is now "Destroy that card", and
  "Exhaust this Trap" is now "this Trap Permanently costs +1AP". Implemented as written: no negation. See
  *Questions for the owner*.
- **Elemental Mastery (88)** — "is now +12" became "gains +6". One copy is still 12; two copies are now 18
  (P-19 had made them 24).
- **Fusion Ceremony (82)** was Polymerization; **Fusion Laboratory (89)** was Nether Portal and costs 1 (was 2).
- **Draw Virus (44)** costs 2 (was 3). **Reinforcements (178)** see above.
- **Boom (175)** On Destroy is no longer optional. **Corrupted Narzyl (18)** no longer says "by battle" (it has no
  destroying effect, so in play it is unchanged). **Auric (23)** and **Brinekeeper (26)** now also destroy revealed Spells/Traps.
- Index and art-reference columns: several rows now share an `index` (163, 167, 178) and a `card_img`
  (163, 167, 178, 183 each used twice). The game has no card art yet, so nothing displays wrongly; the catalogue
  order breaks ties by ID. Flagged so the sheet can be fixed before art is wired in.

## New cards

| ID | Card | Rules as implemented |
| --- | --- | --- |
| 184 | Counter Transmutation (Trap, 1) | When any Spell/Trap is destroyed (either side), during the opponent's turn like every Trap: put a Power from your own Spent into a free Power zone. No cost is paid. Only offered when you have such a Power and a free Power zone. Marked by the Abyss keeps its own 0-cost-deck limit. Used or ordinary "to Spent" moves are not destruction. |
| 185 | Drako, Councillor of The Order (Arcane 3) | On Summon you can add a Power from Draw or Spent to Hand; it costs 1 AP less this turn. Once per turn: destroy any Power; gain 1 AP if it was yours. |
| 186 | Bronze Salaman (Ritual 1R, Light Dragon 20/20) | On Summon you can Fusion Summon with units you control (only offered when one is possible). When it is sacrificed or tributed (undebilitated) you can apply 1 Retain to a card in your Hand. |
| 187 | Fence of the Marked Claw (Arcane 1, Fire Warrior 6/14) | On Summon you can add a Monster unit from Draw to Hand; it costs 1 AP less this turn. Whenever a Spell is activated (either player's, cast or set), you can apply 1 Rune to any unit. |
| 188 | Necro, the Loathsome (Fusion: Mage + Debuffed unit; Dark Mage 32/0) | On Summon it takes a copy of every Debuff on the other units (a copied Debilitate suppresses its own ability until it wears off). Once per turn, while it has a Debuff: double its Debuffs, then apply those doubled stacks to an opponent's unit (that unit's Cleanse can stop each one). |

## Text corrections the importer applies (with provenance in `source.raw`)

- Kept rule corrections: Magic Cylinder / Damage Conversion (C-03, "an attack on one of your Units in this
  Column"); Overextend (F03-19, "Choose one of your opponent's Units, it Permanently loses -20 ATK"); the Arcane
  exact-total requirement (F03-04), now on 185 and 187 too.
- Dropped as obsolete: Options (the export now says "At the start of your turn: draw a card") and Overextend's condition.
- New: typos and the export's own new house style on rows it missed — "this Units Column/Type/cost" back to
  "this Unit's" (12, 73, 102, 162), Aleister's "using you Control" (40, missing "Units"), Bahatia's
  sentence-initial "Your" (141), "Sell/Trap" (184), Bronze Salaman's "Units from your Field" → "Units you
  Control" (186), Fence's "Apply" → "apply" (187), "opponents Unit" → "opponent's Unit" (188). Arcane
  councillors keep the export's own "that Unit costs -1 AP this turn" phrasing.
- Extra Deck descriptions now leave out the summon requirement, like the export's own descriptions.

## Engine and presentation changes

- `card_scripts.gd`: every behaviour above; removed the Chaos Witch aura, Shimmer's own-cost flag, Options' draw
  flag, Energy Dispel's negation and exhaust, Trap hole's cost condition.
- New effect-language pieces: `fusion_possible`, `copy_all_debuffs`, `spread_debuffs`, `put_power`, the
  `spell_activated` event, the `st_destroyed` response window, `sum_def`, and the `var_owned`,
  `self_has_debuff`, `free_power_zone`, `event_card_destroyable` and `playable` conditions.
- A resolving Spell can be destroyed (Energy Dispel); a destroyed face-down Energy Dispel's cost change is logged
  privately so its identity stays hidden.
- Two copies of the same trigger on the same event (two Options) resolve without asking for an order.
- `GameCore.change_hp` logs Damage/Healing; the game log colours them as before.
- Tutorial: Fusion Ceremony, Damage wording, lesson 7 numbers.

## Questions for the owner (implemented as the text reads; easy to change)

1. **Energy Dispel** no longer says "Negate". As written, it destroys the activating card but the effect still
   resolves (so it is weak against a Spell cast from the Hand). Was dropping the negation intended?
2. **Elemental Mastery** "gains +6": two copies give 18 now (P-19 gave 24). Keep 18?
3. **Counter Transmutation**: "Play a Power from Spent" is implemented as free (no AP) and from your own Spent. Right?
4. **Necro, the Loathsome**: "apply the same Debuffs" gives the target the *doubled* stacks. Or should it get the
   stacks from before the doubling?
5. **Reinforcements** cost 2 and -2 AP were not on the list — confirm they are intended.

## Per-card ledger

Every ID whose 18 October row differs from 17 October (index/art moves included). "Wording" means the
effect script is unchanged and its existing tests still pass; the text the player reads comes from the CSV.
| ID | Card | Changed cells | Class | Implementation | Evidence |
| --- | --- | --- | --- | --- | --- |
| 1 | Basic Mage | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 2 | Basic Dragon | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 3 | Basic Warrior | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 4 | Basic Beast | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 5 | Basic Monster | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 6 | Tag Team - L | on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 7 | Tag Team - B | on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 8 | Tag Team - S | on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 9 | Tag Team - F | on summon, on destroy | behaviour | New On Destroy: destroys every unit in its column (both sides) with current cost 1 or lower. | test_c009_tag_team_f_destroyed_takes_every_cheap_unit_in_its_column_with_it, test_c009_tag_team_f_on_destroy_spares_extra_deck_units |
| 10 | Tag Team - W | type, on summon, on destroy, icon | behaviour | Search now optional; On Destroy hits every Spell/Trap in its column (revealed ones too). Dark. | test_c010_tag_team_w_search_is_now_optional, test_c010_tag_team_w_destroyed_destroys_every_spell_trap_in_its_column |
| 11 | Tag Team - J | keywords, on summon, on destroy | behaviour | On Destroy now destroys a chosen Power (was: every card with Reveal in its column); Reveal keyword gone. | test_c011_tag_team_j_destroyed_destroys_a_chosen_power, test_c011_tag_team_j_destroyed_with_no_power_does_nothing, test_c011_tag_team_j_destroy_no_longer_hits_revealed_cards |
| 12 | Tag Team - X | type, on summon, on field, icon | wording | Type Heavenly -> Light; wording only: same effect script | existing tests unchanged and passing |
| 13 | Chaos Witch | type, on field, icon | behaviour | Dark by default (was typeless). Type change is one-shot on itself and every Mage on the Field; the ongoing aura is removed. | test_c013_chaos_witch_is_dark_by_default_and_imposes_nothing_until_it_acts, test_c013_chaos_witch_type_change_is_one_shot_and_survives_the_witch, test_c013_a_second_witch_can_change_the_mages_again |
| 14 | Avatar of the Flame Spirit | on summon, on field, on destroy | wording | wording only: same effect script | existing tests unchanged and passing |
| 15 | Da Mage | on field, on destroy | wording | wording only: same effect script | existing tests unchanged and passing |
| 16 | Edwin, Initiatus of The Order | type, on field, icon | wording | Type Heavenly -> Light; wording only: same effect script | existing tests unchanged and passing |
| 17 | Accursed Zealot | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 18 | Corrupted Narzyl | type, on summon, on field, icon | behaviour | "Destroys an opponent's Unit" without "by battle": listens to any destruction it causes (it has no destroying effect, so in practice still battle). | test_c018_corrupted_narzyl_still_gains_a_rune_when_it_destroys_by_battle |
| 20 | Spirit Bomb | type, on summon, on field, on destroy, icon | wording | Type Heavenly -> Light; wording only: same effect script | existing tests unchanged and passing |
| 21 | Shen the World Dragon | on field, on destroy | wording | wording only: same effect script | existing tests unchanged and passing |
| 22 | Zorath, Deity of the End | on field, on destroy | wording | wording only: same effect script | existing tests unchanged and passing |
| 23 | Auric the Divine Father | on field, on destroy | behaviour | "Destroy a Spell/Trap card": a revealed set card is now a legal target. | test_c023_auric_can_destroy_a_revealed_spell_trap_now |
| 25 | Stormcaller Harbinger | on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 26 | Brinekeeper Summoner | on summon, on destroy | behaviour | On Destroy: all your Spell/Trap cards, revealed or not. | test_c026_brinekeeper_destroyed_takes_all_your_spell_traps_revealed_or_not |
| 28 | Guardian of the Forest | type, icon | type rename | Type Heavenly -> Light | existing tests unchanged and passing |
| 29 | The Sweeper | on summon, on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 30 | Accio the Hermit | on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 31 | Cosmic Dragon | type, on destroy, icon | wording | Type Heavenly -> Light; wording only: same effect script | existing tests unchanged and passing |
| 32 | Frost Wyvern | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 33 | Fledgling Drake | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 34 | Dragon of the Cave | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 35 | Enraged Komodo | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 36 | Dante | on summon, on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 38 | The Lone Warrior | type, on field, icon | wording | Type Necrotic -> Dark; wording only: same effect script | existing tests unchanged and passing |
| 39 | Steadfast Soldier | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 40 | Aleister the Invoker | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 42 | Ambush | on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 43 | Freaky Funday | on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 44 | Draw Virus | cost | balance | Cost 3 -> 2. | test_renamed_and_recosted_powers_and_spells |
| 45 | Magic Cylinder | on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 46 | Mirror Force | condition, on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 47 | Damage Conversion | on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 48 | Overextend | condition, on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 49 | Trap hole | condition | behaviour | Any summon by the opponent (2-cost minimum removed). | test_c049_trap_hole_now_answers_a_one_cost_summon, test_c049_trap_hole_answers_a_one_cost_summon_too |
| 51 | Rushed Recklessly | on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 53 | Power of Normal | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 54 | Strength in Unity | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 55 | Spy | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 56 | Razeon Storm | on summon, on destroy | wording | wording only: same effect script | existing tests unchanged and passing |
| 57 | Geolock Colossus | on summon, on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 58 | Infernogate the Three-Fanged | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 59 | Abysslord the Tidecaller | on summon, on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 60 | Rotmaw Risen | type, on field, icon | wording | Type Necrotic -> Dark; wording only: same effect script | existing tests unchanged and passing |
| 61 | Sanctified Blade | type, condition, on summon, on field, icon, material | wording | Type Heavenly -> Light; wording only: same effect script | existing tests unchanged and passing |
| 62 | Naturewrath Ascendant | on field, on destroy | wording | wording only: same effect script | existing tests unchanged and passing |
| 63 | The Last Foundation | type, on summon, on field, icon | wording | Type Necrotic -> Dark; wording only: same effect script | existing tests unchanged and passing |
| 64 | Necrovast the Undying | type, on field, icon | wording | Type Necrotic -> Dark; wording only: same effect script | existing tests unchanged and passing |
| 65 | The Creeping Null | on summon, on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 66 | Nyxthral, Beyond Reason | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 67 | Void Basilisk | type, on summon, on field, icon | wording | Type Necrotic -> Dark; wording only: same effect script | existing tests unchanged and passing |
| 68 | Sepukku | type, on field, icon | wording | Type Necrotic -> Dark; wording only: same effect script | existing tests unchanged and passing |
| 69 | Magentric | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 71 | Faerie Flight | type, on field, icon | wording | Type Heavenly -> Light; wording only: same effect script | existing tests unchanged and passing |
| 73 | Mans Best Friend | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 74 | Sparky | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 75 | Travelwarden | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 76 | Soul Devourer | type, on field, icon | wording | Type Necrotic -> Dark; wording only: same effect script | existing tests unchanged and passing |
| 77 | Radablast | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 78 | Abraxus Terrormane | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 79 | Akakaijū | on field, on destroy | wording | wording only: same effect script | existing tests unchanged and passing |
| 80 | Wings of Aurenthor | on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 81 | Fog of War | on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 82 | Fusion Ceremony | name, on summon | identity | Renamed Polymerization -> Fusion Ceremony (tutorial, labels and tests follow). | test_renamed_and_recosted_powers_and_spells |
| 85 | Energy Capture | condition | wording | wording only: same effect script | existing tests unchanged and passing |
| 86 | Get Well Soon | condition | wording | wording only: same effect script | existing tests unchanged and passing |
| 88 | Elemental Mastery | on field | behaviour | "gains +6" per copy on the base +6: one copy 12 (unchanged), two 18 (P-19 gave 24). | test_c088_elemental_mastery_adds_6_per_copy, test_p19_two_elemental_masteries_give_18_advantage |
| 89 | Fusion Laboratory | name, cost, on field | identity, balance | Renamed Nether Portal -> Fusion Laboratory; cost 2 -> 1. | test_renamed_and_recosted_powers_and_spells |
| 90 | Chains of Binding | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 91 | Ritual Sanct | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 92 | Preservation Jar | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 93 | Bastion Wyrm | references only | reference | index / art reference only | existing tests unchanged and passing |
| 94 | Mirrorflesh Construct | condition, on summon, material | wording | wording only: same effect script | existing tests unchanged and passing |
| 95 | Mimic | on destroy | wording | wording only: same effect script | existing tests unchanged and passing |
| 96 | Roma, Exhile of The Order | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 97 | The Legendary Swordsman | on field, on destroy | wording | wording only: same effect script | existing tests unchanged and passing |
| 98 | Raging Inferno | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 102 | Waang, Bender of Elements | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 104 | Earthquake | on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 105 | Basic Mage | name, type, icon | type rename | Type Heavenly -> Light; name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 106 | Basic Dragon | name, type, icon | type rename | Type Heavenly -> Light; name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 107 | Basic Warrior | name, type, icon | type rename | Type Heavenly -> Light; name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 108 | Basic Beast | name, type, icon | type rename | Type Heavenly -> Light; name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 109 | Basic Monster | name, type, icon | type rename | Type Heavenly -> Light; name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 110 | Basic Mage | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 111 | Basic Dragon | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 112 | Basic Warrior | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 113 | Basic Beast | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 114 | Basic Monster | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 115 | Basic Mage | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 116 | Basic Dragon | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 117 | Basic Warrior | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 118 | Basic Beast | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 119 | Basic Monster | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 120 | Basic Mage | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 121 | Basic Dragon | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 122 | Basic Warrior | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 123 | Basic Beast | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 124 | Basic Monster | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 125 | Basic Mage | name, type, icon | type rename | Type Necrotic -> Dark; name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 126 | Basic Dragon | name, type, icon | type rename | Type Necrotic -> Dark; name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 127 | Basic Warrior | name, type, icon | type rename | Type Necrotic -> Dark; name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 128 | Basic Beast | name, type, icon | type rename | Type Necrotic -> Dark; name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 129 | Basic Monster | name, type, icon | type rename | Type Necrotic -> Dark; name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 130 | Basic Mage | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 131 | Basic Dragon | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 132 | Basic Warrior | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 133 | Basic Beast | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 134 | Basic Monster | name | name suffix | name suffix dropped (already dropped in game, F03-09) | existing tests unchanged and passing |
| 136 | Equaliser | on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 137 | Unstable Fusions | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 139 | Magical Council | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 140 | Energy Dispel | on summon | behaviour | No negation: destroys the activated card (Field, or a Spell resolving) and the effect still resolves; Field -> Spent gives it +1 cost for the game instead of exhausting it. | test_c140_energy_dispel_destroys_the_activating_unit_but_does_not_negate, test_c140_energy_dispel_destroys_a_resolving_spell_and_the_spell_still_resolves, test_c140_energy_dispel_is_not_offered_for_a_card_that_already_left_the_field, test_c140_energy_dispel_destroyed_face_down_keeps_its_name_private |
| 141 | Bahatia | condition, on field, material | wording | wording only: same effect script | existing tests unchanged and passing |
| 142 | Gojirun | references only | reference | index / art reference only | existing tests unchanged and passing |
| 143 | Typhoon Simorgh | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 144 | Stone Guardian | on summon, on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 145 | Trigonam | on summon, on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 146 | Akiramari | on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 147 | Demented Apparition | type, condition, on summon, on field, on destroy, icon, material | wording | Type Necrotic -> Dark; wording only: same effect script | existing tests unchanged and passing |
| 148 | Martyrdom | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 149 | Marked by the Abyss | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 151 | Ultimate Dragon | on field, on destroy | wording | wording only: same effect script | existing tests unchanged and passing |
| 153 | Hot Stove | on summon | wording | wording only: same effect script | existing tests unchanged and passing |
| 154 | Sneaky Snunday | on summon | behaviour | Damage and Healing are no longer reversed (user note); ATK/DEF, AP and cost changes still are. | test_c154_sneaky_snunday_no_longer_reverses_damage_or_healing, test_c154_sneaky_snunday_still_reverses_stat_gains, test_plan_b_healing_is_not_reversed_by_sneaky_snunday, test_c154_sneaky_snunday_reverses_gains_this_turn_only_but_never_damage |
| 155 | Symbiote Spawn | type, on field, icon | wording | Type Heavenly -> Light; wording only: same effect script | existing tests unchanged and passing |
| 156 | Symbiote Larva | type, icon | type rename | Type Heavenly -> Light | existing tests unchanged and passing |
| 157 | Symbiote Siphonophore | type, on field, icon | wording | Type Heavenly -> Light; wording only: same effect script | existing tests unchanged and passing |
| 158 | Divine Serpent - Head | on summon, on field | behaviour | After the 30 Damage, every Divine Serpent you control is destroyed. | test_divine_serpents_deal_30_damage_then_destroy_every_serpent_you_control, test_divine_serpent_without_two_adjacent_serpents_does_nothing |
| 159 | Divine Serpent - Body | on summon, on field | behaviour | As 158. | as 158 |
| 160 | Divine Serpent - Soul | on summon, on field | behaviour | As 158. | as 158 |
| 161 | Neva the Divine Mother | on field, on destroy | wording | wording only: same effect script | existing tests unchanged and passing |
| 162 | Diggie | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 163 | Plan B | on summon | behaviour | Heal is never reversed by Sneaky Snunday (wording otherwise). | test_plan_b_healing_is_not_reversed_by_sneaky_snunday |
| 166 | Saboteurs Guild | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 167 | Shaman's Snunday Brew | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 168 | Tactical Arrangements | cost, on field | behaviour, balance | Draw first, then discard (usable from an empty Hand); cost 2 -> 1. | test_c168_tactical_arrangements_costs_1_and_draws_before_the_discard, test_c168_tactical_arrangements_works_from_an_empty_hand |
| 169 | Options | on field | behaviour | A start-of-turn draw trigger per copy, after the normal draw (was: part of the draw). Identical triggers no longer ask for an order. | test_c169_options_draws_one_card_per_copy_at_the_start_of_your_turn, test_p19_two_options_draw_six |
| 170 | Grandmother Kaya | atk, condition, on summon, on destroy, material | balance | ATK 16 -> 4. | test_arcane_units_carry_the_new_stats |
| 171 | Flying Sandworm | condition, on field, material | wording | wording only: same effect script | existing tests unchanged and passing |
| 172 | Tyde, Councillor of The Order | atk, condition, material | balance | ATK 24 -> 18. | test_arcane_units_carry_the_new_stats |
| 173 | Thunderclap Dragon | atk, condition, on summon, on destroy, material | balance | ATK 22 -> 20. | test_arcane_units_carry_the_new_stats |
| 174 | Cliff the Flying Bison | atk, def, condition, material | balance | ATK/DEF 16/28 -> 8/18. | test_arcane_units_carry_the_new_stats |
| 175 | Boom, Councillor of The Order | atk, condition, on summon, on field, on destroy, material | balance, behaviour | ATK 30 -> 26 (tutorial lesson 7 numbers updated); On Destroy +10 DEF no longer optional. | test_arcane_units_carry_the_new_stats, test_c175_boom_destroyed_gives_your_units_10_def_without_asking, test_arcane_lesson_exact_total_exhausts_materials |
| 176 | Tritu, Heir to the Ocean Tribe | def, condition, on summon, on field, material | balance, behaviour | DEF 18 -> ? : DEF is the combined DEF of the other Water units too. | test_c176_tritu_becomes_the_combined_atk_and_def_of_the_other_water_units |
| 177 | The Illusionist | condition, on field, on destroy, material | wording | wording only: same effect script | existing tests unchanged and passing |
| 178 | Reinforcements | cost, on field | behaviour, balance | Cost 3 -> 2; units cost -2 AP (was -1) while only the opponent controls a unit. | test_c178_reinforcements_costs_2_and_cuts_unit_costs_by_2, test_c178_reinforcements_discounts_units_when_only_opponent_has_units |
| 179 | Tyrants Lantern | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 181 | Solomon, the Tyrannical | on field, on destroy | wording | wording only: same effect script | existing tests unchanged and passing |
| 182 | Shimmer Serum | keywords, on summon | behaviour | Blind and Infiltrate; +20 ATK this turn (was +16); the target unit's cost rises by 1 for the game (was the Spell's own cost). | test_c182_shimmer_serum_raises_the_targets_cost_not_its_own, test_c182_shimmer_serum_atk_gain_lasts_this_turn_only, test_c182_shimmer_serum_target_cost_keeps_rising_and_persists_in_spent |
| 183 | Yamata, Spirit of the Flame | on field | wording | wording only: same effect script | existing tests unchanged and passing |
| 184 | Counter Transmutation | new card | new | Trap: when any Spell/Trap is destroyed, put a Power from your Spent into a free Power zone at no cost. | test_c184_* (6 tests) |
| 185 | Drako, Councillor of The Order | new card | new | Arcane 3: optional Power search (Draw or Spent, -1 AP this turn); once per turn destroy a Power, +1 AP if it was yours. | test_c185_* (3 tests) |
| 186 | Bronze Salaman | new card | new | Ritual 1R: optional Fusion Summon as it lands (only offered when possible); optional Retain when sacrificed or tributed. Added to the Lone Warrior structure deck. | test_c186_* (4 tests), test_no_fusion_prompt_when_no_fusion_summon_is_possible |
| 187 | Fence of the Marked Claw | new card | new | Arcane 1: optional Monster search (-1 AP this turn); an optional Rune whenever any Spell is activated. | test_c187_* (4 tests) |
| 188 | Necro, the Loathsome | new card | new | Fusion (Mage + debuffed unit): copies every Debuff on the other units on summon; once per turn doubles its Debuffs and gives them to an opponent's unit. | test_c188_* (6 tests) |

