# Card database CSV differences — 17 October 2026

Comparison requested by the user. This report enumerates every parsed field difference between the existing repository source CSV and the supplied new export. It does not claim these are all changes still needed in the running game: the importer and runtime already contain separate confirmed corrections.

## Summary

- **Identified cards in old CSV:** 183.
- **Identified cards in new CSV:** 183.
- **Added card IDs:** 0.
- **Removed card IDs:** 0.
- **Cards with at least one changed field:** 101.
- **Completely unchanged cards:** 82.
- **Changed field values:** 319.
- **Removed unidentified source rows:** 3.

Both files have the same 20 headers in the same order and unique nonblank IDs. Identified cards remain in the same physical/logical row positions: no actual card-row moves were found. Twenty `index` values and twenty `card_img` references changed; those are still fully listed below. The new export removes two blank rows and one unassigned effect row, not three playable cards.

## Sources and reproducibility

- Old baseline: `rules/sources/RLDB Master - Card Database.csv`.
- New uploaded file: `C:/Users/fergm/Downloads/RLDB Master - Card Database (1).csv`.
- Preserved new export: `rules/sources/RLDB Master - Card Database (2026-10-17).csv`. The old baseline is unchanged.
- Old SHA-256: `b51f1b38826fb6c97e171e3a620894112dd29f7b4932a06de94443640774b706`.
- New SHA-256: `8ac4a39a70069a8586b1e5139e5999a57aa837e8064e83ef365e91b36d693da3`.
- Both CSVs were decoded as UTF-8 (optional BOM accepted) and parsed using the CSV format, not split by commas or lines. Match cards by stable `id`, never by name, index or image filename. Compare all parsed cell strings exactly, without stripping whitespace or ignoring punctuation.
- CSV row numbers below include the header as row 1. All records in these particular files occupy a single physical line. Raw quoting/BOM/line-ending differences that do not change parsed cells are not treated as card-data changes; this is an exhaustive data diff, not a byte-by-byte text diff.
- Values in detailed tables use JSON string notation: `""` means an empty string; quoted spaces and escaped newlines remain visible. `null` would mean an absent field; neither CSV contains a missing-width record in this comparison.

## Field-change totals

| Field | Changed cards/values |
| --- | ---: |
| `index` | 20 |
| `id` | 0 |
| `sheet` | 0 |
| `name` | 7 |
| `category` | 0 |
| `race` | 0 |
| `type` | 1 |
| `cost` | 3 |
| `atk` | 9 |
| `def` | 6 |
| `keywords` | 9 |
| `condition` | 33 |
| `On Summon/Play` | 50 |
| `On Field` | 49 |
| `On Destruction` | 13 |
| `description` | 89 |
| `image` | 0 |
| `card_img` | 20 |
| `type_icon` | 1 |
| `material` | 9 |
| **Total** | **319** |

Counts include repeated semantic content in `description` and structured effect fields; 319 changed cells is not 319 distinct gameplay changes. Many text edits change punctuation, capitalization or possessives. No such edits are omitted from the detailed section.

## Stat, cost, Type and name changes

| ID | New card name | Field | Old | New |
| --- | --- | --- | --- | --- |
| 6 | Tag Team - L | `name` | <code>&quot;Tag Team - F&quot;</code> | <code>&quot;Tag Team - L&quot;</code> |
| 7 | Tag Team - B | `name` | <code>&quot;Tag Team - J&quot;</code> | <code>&quot;Tag Team - B&quot;</code> |
| 9 | Tag Team - F | `name` | <code>&quot;Tag Team - L&quot;</code> | <code>&quot;Tag Team - F&quot;</code> |
| 9 | Tag Team - F | `cost` | <code>&quot;1&quot;</code> | <code>&quot;2&quot;</code> |
| 9 | Tag Team - F | `def` | <code>&quot;8&quot;</code> | <code>&quot;22&quot;</code> |
| 11 | Tag Team - J | `name` | <code>&quot;Tag Team - B&quot;</code> | <code>&quot;Tag Team - J&quot;</code> |
| 23 | Auric the Divine Father | `atk` | <code>&quot;50&quot;</code> | <code>&quot;30&quot;</code> |
| 23 | Auric the Divine Father | `def` | <code>&quot;50&quot;</code> | <code>&quot;16&quot;</code> |
| 36 | Dante | `atk` | <code>&quot;26&quot;</code> | <code>&quot;28&quot;</code> |
| 69 | Magentric | `atk` | <code>&quot;8&quot;</code> | <code>&quot;20&quot;</code> |
| 69 | Magentric | `def` | <code>&quot;26&quot;</code> | <code>&quot;20&quot;</code> |
| 71 | Faerie Flight | `def` | <code>&quot;18&quot;</code> | <code>&quot;16&quot;</code> |
| 78 | Abraxus Terrormane | `atk` | <code>&quot;26&quot;</code> | <code>&quot;24&quot;</code> |
| 162 | Diggie | `atk` | <code>&quot;2&quot;</code> | <code>&quot;6&quot;</code> |
| 155 | Symbiote Spawn | `name` | <code>&quot;Symbiote - Black&quot;</code> | <code>&quot;Symbiote Spawn&quot;</code> |
| 156 | Symbiote Larva | `name` | <code>&quot;Symbiote - Red&quot;</code> | <code>&quot;Symbiote Larva&quot;</code> |
| 157 | Symbiote Siphonophore  | `name` | <code>&quot;Symbiote - White&quot;</code> | <code>&quot;Symbiote Siphonophore &quot;</code> |
| 95 | Mimic | `cost` | <code>&quot;3R&quot;</code> | <code>&quot;2R&quot;</code> |
| 65 | The Creeping Null | `atk` | <code>&quot;46&quot;</code> | <code>&quot;40&quot;</code> |
| 65 | The Creeping Null | `def` | <code>&quot;42&quot;</code> | <code>&quot;28&quot;</code> |
| 183 | Yamata, Spirit of the Flame | `cost` | <code>&quot;4R&quot;</code> | <code>&quot;3R&quot;</code> |
| 183 | Yamata, Spirit of the Flame | `atk` | <code>&quot;32&quot;</code> | <code>&quot;12&quot;</code> |
| 183 | Yamata, Spirit of the Flame | `def` | <code>&quot;44&quot;</code> | <code>&quot;20&quot;</code> |
| 171 | Flying Sandworm | `atk` | <code>&quot;4&quot;</code> | <code>&quot;6&quot;</code> |
| 177 | The Illusionist | `type` | <code>&quot;Necrotic&quot;</code> | <code>&quot;?&quot;</code> |
| 177 | The Illusionist | `atk` | <code>&quot;20&quot;</code> | <code>&quot;30&quot;</code> |

ID 157’s new name has a trailing space, preserved in the exact-value table. The Tag Team names move among existing IDs; do not migrate gameplay identity by matching the old name to the new name. `?` Type means typeless, not unknown: The Illusionist loses its Necrotic Type.

## Main implementation-impact changes

- **Tag Team cards (ID 6, 7, 9, 10, 11):** Several existing IDs get different names and search effects. ID 9 also changes cost 1→2 and DEF 8→22. Verify each by ID rather than moving effects by suffix/name.
- **Chaos Witch (ID 13):** Changes its own Type and makes all Mage units match it; does not merely declare an unrelated chosen Type. New text excludes typeless selection.
- **Da Mage (ID 15):** Adds optional on-destruction Eternal application to a Mage in the column.
- **Four divine units (ID 21, 22, 23, 161):** On-summon Cleanse reduces from three to one. Auric also changes 50/50 to 30/16.
- **Stormcaller Harbinger (ID 25):** Replaces optional destruction of one Basic unit with destruction of all unprotected Basic units; targeting/mandatory semantics need attention.
- **The Sweeper / Abysslord (ID 29, 59):** Sweeper Reveal selection becomes Spell/Trap-based, and Abysslord destruction selects a Spell or Trap rather than requiring Reveal.
- **Accio the Hermit (ID 30):** Adds on-summon Draw-to-Spent unit movement and Retain application to a Hand unit.
- **Dante (ID 36):** ATK 26→28; applies Burn to all units, expands manual Cleanse/Burn choice and gains ATK from its own Burn count.
- **Solomon, the Captain (ID 37):** Now gains +10 ATK when protected, replacing +8 when protecting. These are different board relationships.
- **Magentric (ID 69):** Stats 8/26→20/20 and adds a tribute-trigger benefit for the resulting Fusion/Ritual summon. Sequence must identify the resulting unit after material use.
- **Faerie Flight / Myth Wukong (ID 71, 72):** Faerie grants Nimble to a unit rather than only itself, grants Medic 3 on its move, and DEF becomes 16. Wukong gains Nimble on summon.
- **Corrupted Narzyl (ID 18):** Summon Paralyse reduces from two to one.
- **Diggie (ID 162):** ATK 2→6 and a persistent cost increase when sacrificed.
- **Symbiote units (ID 155, 156, 157):** Renamed; Larva protected-unit bonus reduces 20→10 and adds draw/discard; Siphonophore adjacency bonus becomes protection-conditional and adds a turn-start draw.
- **Previously confirmed text fixes (ID 90, 183, 97):** Chains explicitly optional, Yamata damage explicitly start-turn, Legendary Swordsman Cleanse moved to On Summon. Some are already implemented via importer corrections.
- **Geolock Colossus (ID 57):** Adds Infiltrate/Nimble on summon and replaces free-zone unit movement with an opponent unprotected-unit stance-change ability.
- **Solomon, the Tyrannical (ID 181):** Replaces exhausting a Warrior from Spent with exhausting the unit it is protecting; preserve source/ownership and once-per-turn checks.
- **The Last Foundation (ID 63):** Adds explicit Reveal on summon targeting Spells/Traps; removes buff-absence condition on Eternal generation and removes movement prohibition.
- **Ritual balance (ID 95, 65, 183):** Mimic 3R→2R; Creeping Null stats 46/42→40/28; Yamata 4R→3R and 32/44→12/20.
- **Arcane entries (ID 170–177):** All eight populate `material` and reword requirement text; actual exact-payment rule is separately confirmed in feedback 03.
- **Flying Sandworm (ID 171):** ATK 4→6; direct-attack text explicitly continuous while on Field.
- **Tyde (ID 172):** Reworked: on-summon Beast search/turn discount plus once-per-turn destroy a Rune-bearing unit; removes sacrifice/Reveal destruction behaviour.
- **The Illusionist (ID 177):** Becomes typeless, ATK 20→30, own-turn bonus +20→+30, and adds optional recovery of a cost-one-or-lower card from Exhaust to Draw. This is an additional card-specific Exhaust-recovery exception to consider alongside Necrovast.

These summaries are a review aid, not a substitute for the exact 319-cell diff. Unlisted wording-only edits and all reference changes still appear below.

## Import hazards, stale source wording and questions for implementation

- Twenty incoming `condition` cells contain literal `temp` (listed below). It appears to be spreadsheet/editorial metadata, not a playable trigger. Do not compile it as a mandatory condition or display it as a valid rule; confirm its intended role if needed.
- Current `tools/import_cards.py` unconditionally moves `condition` into `on_summon` for IDs 63 and 97. In the new CSV these On Summon values are already populated; ID 63 now has condition `temp`. A blind import can prepend `temp` to the real effect. Replace that legacy positional correction with source-aware validation; do not duplicate real summon effects.
- Current importer applies text overrides for IDs 45, 47, 48, 90, 169 and 183. Compare each override with incoming text and latest decisions rather than deleting all corrections or retaining all old text blindly. In particular, keep the confirmed chosen-target Overextend behaviour instead of restoring the CSV’s highest-ATK wording.
- The CSV still uses original Magic Cylinder column wording and Options “draw 5” wording. Their unchanged/still-ambiguous raw text must not undo the confirmed unit-target-only column trigger or per-copy additional draw behaviour. Keep basic-unit display-name cleanup even though the source names still include Types.
- The Illusionist’s new Exhaust recovery adds an exception beyond the earlier “Necrovast is the exception” discussion. It is a clear new card effect in the uploaded CSV, not a reason to make all Exhaust recoverable. Confirm any unresolved ordinary-cost filtering/ownership semantics; never coerce a special Extra Deck requirement into an AP cost.
- Descriptions can contain both meaningful edits and grammar-only changes; apostrophes such as “Unit's” are not new ownership rules by themselves. Structured effects and full description should be reconciled, not executed as two copies of the same ability.
- Twenty `card_img` values change along with `index` values, although physical card-row order is unchanged. Check intended art mapping by stable ID. Do not accidentally assign another card’s artwork because a filename/index was renumbered. Original `image` references are unchanged.
- Changing names must preserve saves, decks, references, tutorial IDs and effect bindings. The four Tag Team renames are especially unsafe to reconcile by display name. Trim display-only trailing whitespace deliberately while preserving the raw export for provenance.
- The removed unassigned row had no ID/name and must not be treated as a deleted playable card. Its effect is preserved below for audit, not reassigned to a card without confirmation.
- This report compares the raw old/new CSVs only. The runtime cards JSON and hand-coded effects may already differ intentionally. Implementation requires a three-way reconciliation: old source → new source → current corrected runtime, with explicit latest user decisions preserved where incoming export does not change them.

Incoming `temp` conditions: ID 6 (Tag Team - L), ID 9 (Tag Team - F), ID 15 (Da Mage), ID 25 (Stormcaller Harbinger), ID 30 (Accio the Hermit), ID 32 (Frost Wyvern), ID 34 (Dragon of the Cave), ID 35 (Enraged Komodo), ID 36 (Dante), ID 37 (Solomon, the Captain), ID 39 (Steadfast Soldier), ID 69 (Magentric), ID 72 (Myth Wukong), ID 76 (Soul Devourer), ID 78 (Abraxus Terrormane), ID 100 (Gaping Crevasse), ID 162 (Diggie), ID 156 (Symbiote Larva), ID 62 (Naturewrath Ascendant), ID 63 (The Last Foundation).

## Added and removed identified cards

None. Both sources contain the same 183 card IDs. No duplicate nonblank IDs or missing-width CSV records were found.

## Removed unidentified rows

### Old CSV row 185

Entire row empty; absent in the new export.

### Old CSV row 186

Entire row empty; absent in the new export.

### Old CSV row 187

No card ID/name. Removed from the new export. Exact nonempty fields:
- `On Field`: <code>&quot;At the start of your turn: Apply 1 Infiltrate to this Unit. If your HP is lower than your opponents, double this Units ATK.&quot;</code>

## Complete field-by-field differences

All changed identified cards follow, in old source order. Each table row is one changed field. Unchanged fields are not repeated; changed `description` text is retained even where it repeats a structured effect change.

### ID 6 — Tag Team - L

Old CSV row 37; new CSV row 37. **4 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `name` | <code>&quot;Tag Team - F&quot;</code> | <code>&quot;Tag Team - L&quot;</code> |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |
| `On Summon/Play` | <code>&quot;If you control another Unit in this Column, add a Unit with the same Race as that Unit from Draw to Hand, that Unit costs -1 AP this turn.&quot;</code> | <code>&quot;If you control another Unit in this Column, you can add a Trap from Draw to Hand, that Trap costs -1 AP this turn.&quot;</code> |
| `description` | <code>&quot;On Summon: If you control another Unit in this Column, add a Unit with the same Race as that Unit from Draw to Hand, that Unit costs -1 AP this turn.&quot;</code> | <code>&quot;On Summon: If you control another Unit in this Column, you can add a Trap from Draw to Hand, that Trap costs -1 AP this turn.&quot;</code> |

### ID 7 — Tag Team - B

Old CSV row 38; new CSV row 38. **4 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `name` | <code>&quot;Tag Team - J&quot;</code> | <code>&quot;Tag Team - B&quot;</code> |
| `keywords` | <code>&quot;Cleanse&quot;</code> | <code>&quot;&quot;</code> |
| `On Summon/Play` | <code>&quot;If you control another Unit in this Column, you can Apply 1 Cleanse to a Unit in this Column.&quot;</code> | <code>&quot;If you control another Unit in this Column, you can add a Spell from Draw to Hand, that Spell costs -1 AP this turn.&quot;</code> |
| `description` | <code>&quot;On Summon: If you control another Unit in this Column, you can Apply 1 Cleanse to a Unit in this Column.&quot;</code> | <code>&quot;On Summon: If you control another Unit in this Column, you can add a Spell from Draw to Hand, that Spell costs -1 AP this turn.&quot;</code> |

### ID 8 — Tag Team - S

Old CSV row 39; new CSV row 39. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;If you control another Unit in this Column, you can Fusion Summon using Units from your Field as Tribute.&quot;</code> | <code>&quot;If you have another Unit in this Column, you can Fusion Summon using Unit&#x27;s from your Field as Tribute.&quot;</code> |
| `description` | <code>&quot;On Summon: If you control another Unit in this Column, you can Fusion Summon using Units from your Field as Tribute.&quot;</code> | <code>&quot;On Summon: If you have another Unit in this Column, you can Fusion Summon using Unit&#x27;s from your Field as Tribute.&quot;</code> |

### ID 9 — Tag Team - F

Old CSV row 40; new CSV row 40. **6 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `name` | <code>&quot;Tag Team - L&quot;</code> | <code>&quot;Tag Team - F&quot;</code> |
| `cost` | <code>&quot;1&quot;</code> | <code>&quot;2&quot;</code> |
| `def` | <code>&quot;8&quot;</code> | <code>&quot;22&quot;</code> |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |
| `On Summon/Play` | <code>&quot;If you control another Unit in this Column, you can add a Unit with the same Cost as that Unit from Draw to Hand.&quot;</code> | <code>&quot;If you have another Unit in this Column, you can add a Unit with the same Cost as that Unit from Draw to Hand, that Unit costs -1 AP this turn.&quot;</code> |
| `description` | <code>&quot;On Summon: If you control another Unit in this Column, you can add a Unit with the same Cost as that Unit from Draw to Hand.&quot;</code> | <code>&quot;On Summon: If you have another Unit in this Column, you can add a Unit with the same Cost as that Unit from Draw to Hand, that Unit costs -1 AP this turn.&quot;</code> |

### ID 10 — Tag Team - W

Old CSV row 41; new CSV row 41. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;If you control another Unit in this Column, you can add a Trap from Draw to Hand, that Trap costs -1 AP this turn.&quot;</code> | <code>&quot;If you have another Unit in this Column, add a Unit with the same Race as that Unit from Draw to Hand, that Unit costs -1 AP this turn.&quot;</code> |
| `description` | <code>&quot;On Summon: If you control another Unit in this Column, you can add a Trap from Draw to Hand, that Trap costs -1 AP this turn. On Destroy: Destroy all facedown cards in this Column.&quot;</code> | <code>&quot;On Summon: If you have another Unit in this Column, add a Unit with the same Race as that Unit from Draw to Hand, that Unit costs -1 AP this turn. On Destroy: Destroy all facedown cards in this Column.&quot;</code> |

### ID 11 — Tag Team - J

Old CSV row 42; new CSV row 42. **3 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `name` | <code>&quot;Tag Team - B&quot;</code> | <code>&quot;Tag Team - J&quot;</code> |
| `On Summon/Play` | <code>&quot;If you control another Unit in this Column, you can add a Spell from Draw to Hand, that Spell costs -1 AP this turn.&quot;</code> | <code>&quot;If you have another Unit in this Column, you can add a Unit with the same Type as that Unit from Draw to Hand, that Unit costs -1 AP this turn.&quot;</code> |
| `description` | <code>&quot;On Summon: If you control another Unit in this Column, you can add a Spell from Draw to Hand, that Spell costs -1 AP this turn. On Destroy: Destroy all card with Reveal in this Column.&quot;</code> | <code>&quot;On Summon: If you have another Unit in this Column, you can add a Unit with the same Type as that Unit from Draw to Hand, that Unit costs -1 AP this turn. On Destroy: Destroy all card with Reveal in this Column.&quot;</code> |

### ID 12 — Tag Team - X

Old CSV row 43; new CSV row 43. **3 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;If you control another Unit in this Column, you can draw a card and gain +1 AP.&quot;</code> | <code>&quot;If you have another Unit in this Column, you can draw a card and gain +1 AP.&quot;</code> |
| `On Field` | <code>&quot;You can lose -2 AP, Summon a Unit from your Spent in this Units Column.&quot;</code> | <code>&quot;You can lose -2 AP, Summon a Unit from your Spent in this Unit&#x27;s Column.&quot;</code> |
| `description` | <code>&quot;On Summon: If you control another Unit in this Column, you can draw a card and gain +1 AP. You can lose -2 AP, Summon a Unit from your Spent in this Units Column.&quot;</code> | <code>&quot;On Summon: If you have another Unit in this Column, you can draw a card and gain +1 AP. You can lose -2 AP, Summon a Unit from your Spent in this Unit&#x27;s Column.&quot;</code> |

### ID 13 — Chaos Witch

Old CSV row 44; new CSV row 44. **3 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;Once per turn: you can declare a Type, whilst this Unit is on the Field: all Mage Units on the Field become that Type.&quot;</code> | <code>&quot;Once per turn: this Unit&#x27;s Type can become any Type (except for ?). All Mage Unit&#x27;s become this Unit&#x27;s Type.&quot;</code> |
| `On Destruction` | <code>&quot;You can change an opponents Unit to a Type of your choosing.&quot;</code> | <code>&quot;You can change an opponent&#x27;s Unit to a Type of your choosing.&quot;</code> |
| `description` | <code>&quot;Once per turn: you can declare a Type, whilst this Unit is on the Field: all Mage Units on the Field become that Type. On Destroy: You can change an opponents Unit to a Type of your choosing.&quot;</code> | <code>&quot;Once per turn: this Unit&#x27;s Type can become any Type (except for ?). All Mage Unit&#x27;s become this Unit&#x27;s Type. On Destroy: You can change an opponent&#x27;s Unit to a Type of your choosing.&quot;</code> |

### ID 15 — Da Mage

Old CSV row 46; new CSV row 46. **4 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `keywords` | <code>&quot;Pierce&quot;</code> | <code>&quot;Eternal, Pierce&quot;</code> |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |
| `On Destruction` | <code>&quot;&quot;</code> | <code>&quot;You can Apply 1 Eternal to a Mage Unit in this Column.&quot;</code> |
| `description` | <code>&quot;Once per turn: you can Apply 1 Pierce to a Unit.&quot;</code> | <code>&quot;Once per turn: you can Apply 1 Pierce to a Unit. On Destroy: You can Apply 1 Eternal to a Mage Unit in this Column.&quot;</code> |

### ID 19 — Shapeshifter Loak

Old CSV row 47; new CSV row 47. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Apply 1 Eternal to an opponents Unprotected Unit in this Column, this Units ATK/DEF/Race becomes the ATK/DEF/Race of that Unit.&quot;</code> | <code>&quot;Apply 1 Eternal to an opponent&#x27;s Unprotected Unit in this Column, this Unit&#x27;s ATK/DEF/Race becomes the ATK/DEF/Race of that Unit.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 1 Eternal to an opponents Unprotected Unit in this Column, this Units ATK/DEF/Race becomes the ATK/DEF/Race of that Unit.&quot;</code> | <code>&quot;On Summon: Apply 1 Eternal to an opponent&#x27;s Unprotected Unit in this Column, this Unit&#x27;s ATK/DEF/Race becomes the ATK/DEF/Race of that Unit.&quot;</code> |

### ID 20 — Spirit Bomb

Old CSV row 48; new CSV row 48. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;This Unit gains +4 ATK/DEF x the number of your opponents Units.&quot;</code> | <code>&quot;This Unit gains +4 ATK/DEF x the number of your opponent&#x27;s Unit&#x27;s.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply every Buff on the Field to this Unit. This Unit gains +4 ATK/DEF x the number of your opponents Units. On Destroy: You can Apply 1 Pierce to a Unit.&quot;</code> | <code>&quot;On Summon: Apply every Buff on the Field to this Unit. This Unit gains +4 ATK/DEF x the number of your opponent&#x27;s Unit&#x27;s. On Destroy: You can Apply 1 Pierce to a Unit.&quot;</code> |

### ID 21 — Shen the World Dragon

Old CSV row 49; new CSV row 49. **4 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Apply 1 Eternal and 3 Cleanse to this Unit.&quot;</code> | <code>&quot;Apply 1 Eternal and 1 Cleanse to this Unit.&quot;</code> |
| `On Field` | <code>&quot;This Unit gains +10 ATK/DEF x the number of cards in your Exhaust.&quot;</code> | <code>&quot;While this Unit is on the field: this Unit gains +10 ATK/DEF x the number of cards in your Exhaust.&quot;</code> |
| `On Destruction` | <code>&quot;Increase this cards cost + 1AP.&quot;</code> | <code>&quot;Increase this Unit&#x27;s cost + 1AP.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 1 Eternal and 3 Cleanse to this Unit. This Unit gains +10 ATK/DEF x the number of cards in your Exhaust. On Destroy: Increase this cards cost + 1AP.&quot;</code> | <code>&quot;On Summon: Apply 1 Eternal and 1 Cleanse to this Unit. While this Unit is on the field: this Unit gains +10 ATK/DEF x the number of cards in your Exhaust. On Destroy: Increase this Unit&#x27;s cost + 1AP.&quot;</code> |

### ID 22 — Zorath, Deity of the End

Old CSV row 50; new CSV row 50. **4 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Apply 1 Eternal and 3 Cleanse to this Unit.&quot;</code> | <code>&quot;Apply 1 Eternal and 1 Cleanse to this Unit.&quot;</code> |
| `On Field` | <code>&quot;Whilst this Unit is on the Field: Adjacent Units on the Field cannot declare an Attack.&quot;</code> | <code>&quot;While this Unit is on the Field: Adjacent Unit&#x27;s on the Field cannot declare an Attack.&quot;</code> |
| `On Destruction` | <code>&quot;Increase this cards cost + 1AP.&quot;</code> | <code>&quot;Increase this Unit&#x27;s cost + 1AP.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 1 Eternal and 3 Cleanse to this Unit. Whilst this Unit is on the Field: Adjacent Units on the Field cannot declare an Attack. On Destroy: Increase this cards cost + 1AP.&quot;</code> | <code>&quot;On Summon: Apply 1 Eternal and 1 Cleanse to this Unit. While this Unit is on the Field: Adjacent Unit&#x27;s on the Field cannot declare an Attack. On Destroy: Increase this Unit&#x27;s cost + 1AP.&quot;</code> |

### ID 23 — Auric the Divine Father

Old CSV row 51; new CSV row 51. **5 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `atk` | <code>&quot;50&quot;</code> | <code>&quot;30&quot;</code> |
| `def` | <code>&quot;50&quot;</code> | <code>&quot;16&quot;</code> |
| `On Summon/Play` | <code>&quot;Apply 1 Eternal and 3 Cleanse to this Unit.&quot;</code> | <code>&quot;Apply 1 Eternal and 1 Cleanse to this Unit.&quot;</code> |
| `On Destruction` | <code>&quot;Increase this cards cost + 1AP.&quot;</code> | <code>&quot;Increase this Unit&#x27;s cost + 1AP.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 1 Eternal and 3 Cleanse to this Unit. Once per turn: you can lose -10 HP, either this Unit gains +10 ATK or Destroy a facedown card. On Destroy: Increase this cards cost + 1AP.&quot;</code> | <code>&quot;On Summon: Apply 1 Eternal and 1 Cleanse to this Unit. Once per turn: you can lose -10 HP, either this Unit gains +10 ATK or Destroy a facedown card. On Destroy: Increase this Unit&#x27;s cost + 1AP.&quot;</code> |

### ID 161 — Neva the Divine Mother

Old CSV row 52; new CSV row 52. **3 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Apply 1 Eternal and 3 Cleanse to this Unit.&quot;</code> | <code>&quot;Apply 1 Eternal and 1 Cleanse to this Unit.&quot;</code> |
| `On Destruction` | <code>&quot;Increase this cards cost + 1AP.&quot;</code> | <code>&quot;Increase this Unit&#x27;s cost + 1AP.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 1 Eternal and 3 Cleanse to this Unit. At the start of your turn: Apply 1 Eternal to this Unit. Once per turn: you can Exhaust this Unit, your opponent loses -10 HP x amount of Eternal on this Unit. On Destroy: Increase this cards cost + 1AP.&quot;</code> | <code>&quot;On Summon: Apply 1 Eternal and 1 Cleanse to this Unit. At the start of your turn: Apply 1 Eternal to this Unit. Once per turn: you can Exhaust this Unit, your opponent loses -10 HP x amount of Eternal on this Unit. On Destroy: Increase this Unit&#x27;s cost + 1AP.&quot;</code> |

### ID 25 — Stormcaller Harbinger

Old CSV row 54; new CSV row 54. **3 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |
| `On Summon/Play` | <code>&quot;You can Destroy a Basic Unit.&quot;</code> | <code>&quot;Destroy all Unprotected Basic Unit&#x27;s.&quot;</code> |
| `description` | <code>&quot;On Summon: You can Destroy a Basic Unit.&quot;</code> | <code>&quot;On Summon: Destroy all Unprotected Basic Unit&#x27;s.&quot;</code> |

### ID 29 — The Sweeper

Old CSV row 58; new CSV row 58. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;You can Apply Reveal to a facedown card in this Column.&quot;</code> | <code>&quot;You can Apply Reveal to a Spell or Trap in this Column.&quot;</code> |
| `description` | <code>&quot;On Summon: You can Apply Reveal to a facedown card in this Column. Once per turn: you can spend -1 AP, Destroy a Trap with Reveal.&quot;</code> | <code>&quot;On Summon: You can Apply Reveal to a Spell or Trap in this Column. Once per turn: you can spend -1 AP, Destroy a Trap with Reveal.&quot;</code> |

### ID 30 — Accio the Hermit

Old CSV row 59; new CSV row 59. **4 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `keywords` | <code>&quot;&quot;</code> | <code>&quot;Retain&quot;</code> |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |
| `On Summon/Play` | <code>&quot;&quot;</code> | <code>&quot;You can send a Unit from Draw to Spent, Apply 1 Retain to a Unit in your Hand&quot;</code> |
| `description` | <code>&quot;On Destroy: You can move a Unit from Spent to Draw.&quot;</code> | <code>&quot;On Summon: You can send a Unit from Draw to Spent, Apply 1 Retain to a Unit in your Hand On Destroy: You can move a Unit from Spent to Draw.&quot;</code> |

### ID 32 — Frost Wyvern

Old CSV row 61; new CSV row 61. **1 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |

### ID 34 — Dragon of the Cave

Old CSV row 63; new CSV row 63. **3 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |
| `On Field` | <code>&quot;While this Unit is on the Field, Adjacent Units gain +6 DEF.&quot;</code> | <code>&quot;While this Unit is on the Field, Adjacent Unit&#x27;s gain +6 DEF.&quot;</code> |
| `description` | <code>&quot;While this Unit is on the Field, Adjacent Units gain +6 DEF.&quot;</code> | <code>&quot;While this Unit is on the Field, Adjacent Unit&#x27;s gain +6 DEF.&quot;</code> |

### ID 35 — Enraged Komodo

Old CSV row 64; new CSV row 64. **1 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |

### ID 36 — Dante

Old CSV row 65; new CSV row 65. **5 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `atk` | <code>&quot;26&quot;</code> | <code>&quot;28&quot;</code> |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |
| `On Summon/Play` | <code>&quot;Apply 6 Burn to your opponents Unprotected Units.&quot;</code> | <code>&quot;Apply 6 Burn to all Unit&#x27;s.&quot;</code> |
| `On Field` | <code>&quot;Once per turn: you can Apply 1 Cleanse to this Unit or an Adjacent Unit.&quot;</code> | <code>&quot;Once per turn: you can Apply 1 Cleanse or 10 Burn to a Unit. This Unit gains +1 ATK x the total number of Burn this Unit has.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 6 Burn to your opponents Unprotected Units. Once per turn: you can Apply 1 Cleanse to this Unit or an Adjacent Unit. On Destroy: You can lose -1 AP next turn: at the start of your next turn, Summon this Unit from your Spent to the Zone this Unit was originally in.&quot;</code> | <code>&quot;On Summon: Apply 6 Burn to all Unit&#x27;s. Once per turn: you can Apply 1 Cleanse or 10 Burn to a Unit. This Unit gains +1 ATK x the total number of Burn this Unit has. On Destroy: You can lose -1 AP next turn: at the start of your next turn, Summon this Unit from your Spent to the Zone this Unit was originally in.&quot;</code> |

### ID 37 — Solomon, the Captain

Old CSV row 66; new CSV row 66. **3 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |
| `On Field` | <code>&quot;While this Unit is Protecting a Unit, this Unit gains +8 ATK.&quot;</code> | <code>&quot;While this Unit is Protected by a Unit: this Unit gains +10 ATK.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 2 Pierce to this Unit. While this Unit is Protecting a Unit, this Unit gains +8 ATK. On Destroy: You can add a Warrior Unit from your Spent to Hand.&quot;</code> | <code>&quot;On Summon: Apply 2 Pierce to this Unit. While this Unit is Protected by a Unit: this Unit gains +10 ATK. On Destroy: You can add a Warrior Unit from your Spent to Hand.&quot;</code> |

### ID 38 — The Lone Warrior

Old CSV row 67; new CSV row 67. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;This Unit loses -6 ATK/DEF x the number of your Adjacent Units. This Unit cannot recieve Buffs or gain + ATK/DEF.&quot;</code> | <code>&quot;This Unit loses -6 ATK/DEF x the number of your Adjacent Unit&#x27;s. This Unit cannot recieve Buffs or gain + ATK/DEF.&quot;</code> |
| `description` | <code>&quot;On Summon: You can Destroy a card with Reveal. This Unit loses -6 ATK/DEF x the number of your Adjacent Units. This Unit cannot recieve Buffs or gain + ATK/DEF.&quot;</code> | <code>&quot;On Summon: You can Destroy a card with Reveal. This Unit loses -6 ATK/DEF x the number of your Adjacent Unit&#x27;s. This Unit cannot recieve Buffs or gain + ATK/DEF.&quot;</code> |

### ID 39 — Steadfast Soldier

Old CSV row 68; new CSV row 68. **1 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |

### ID 67 — Void Basilisk

Old CSV row 69; new CSV row 69. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;You can Exhaust this Unit, Fusion Summon using Units from your Field and/or Spent as Tribute.&quot;</code> | <code>&quot;You can Exhaust this Unit, Fusion Summon using Unit&#x27;s from your Field and/or Spent as Tribute.&quot;</code> |
| `description` | <code>&quot;On Summon: You can Apply 2 Paralyse to a Unit in this Column. You can Exhaust this Unit, Fusion Summon using Units from your Field and/or Spent as Tribute.&quot;</code> | <code>&quot;On Summon: You can Apply 2 Paralyse to a Unit in this Column. You can Exhaust this Unit, Fusion Summon using Unit&#x27;s from your Field and/or Spent as Tribute.&quot;</code> |

### ID 68 — Sepukku

Old CSV row 70; new CSV row 70. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;You can Destroy this Unit, Fusion Summon using Units from your Field as Tribute.&quot;</code> | <code>&quot;You can Destroy this Unit, Fusion Summon using Unit&#x27;s from your Field as Tribute.&quot;</code> |
| `description` | <code>&quot;You can Destroy this Unit, Fusion Summon using Units from your Field as Tribute.&quot;</code> | <code>&quot;You can Destroy this Unit, Fusion Summon using Unit&#x27;s from your Field as Tribute.&quot;</code> |

### ID 69 — Magentric

Old CSV row 71; new CSV row 71. **5 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `atk` | <code>&quot;8&quot;</code> | <code>&quot;20&quot;</code> |
| `def` | <code>&quot;26&quot;</code> | <code>&quot;20&quot;</code> |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |
| `On Field` | <code>&quot;You can Fusion Summon using Units from your Field as Tribute.&quot;</code> | <code>&quot;You can Fusion Summon using Unit&#x27;s from your Field as Tribute. If this Unit is Tributed, Apply 2 Pierce to the Fusion or Ritual Unit Summoned.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 2 Pierce to an Adjacent Unit. You can Fusion Summon using Units from your Field as Tribute.&quot;</code> | <code>&quot;On Summon: Apply 2 Pierce to an Adjacent Unit. You can Fusion Summon using Unit&#x27;s from your Field as Tribute. If this Unit is Tributed, Apply 2 Pierce to the Fusion or Ritual Unit Summoned.&quot;</code> |

### ID 40 — Aleister the Invoker

Old CSV row 72; new CSV row 72. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;You can spend -1 AP, Fusion Summon using Units from your Field as Tribute.&quot;</code> | <code>&quot;You can spend -1 AP, Fusion Summon using Unit&#x27;s from your Field as Tribute.&quot;</code> |
| `description` | <code>&quot;You can spend -1 AP, Fusion Summon using Units from your Field as Tribute.&quot;</code> | <code>&quot;You can spend -1 AP, Fusion Summon using Unit&#x27;s from your Field as Tribute.&quot;</code> |

### ID 71 — Faerie Flight

Old CSV row 74; new CSV row 74. **3 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `def` | <code>&quot;18&quot;</code> | <code>&quot;16&quot;</code> |
| `On Field` | <code>&quot;Once per turn: you can Apply 1 Nimble to this Unit. If this Unit moves Zone, Apply 2 Medic to this Unit.&quot;</code> | <code>&quot;Once per turn: you can Apply 1 Nimble to a Unit. If this Unit moves Zone, Apply 3 Medic to this Unit.&quot;</code> |
| `description` | <code>&quot;Once per turn: you can Apply 1 Nimble to this Unit. If this Unit moves Zone, Apply 2 Medic to this Unit.&quot;</code> | <code>&quot;Once per turn: you can Apply 1 Nimble to a Unit. If this Unit moves Zone, Apply 3 Medic to this Unit.&quot;</code> |

### ID 72 — Myth Wukong

Old CSV row 75; new CSV row 75. **4 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `keywords` | <code>&quot;&quot;</code> | <code>&quot;Nimble&quot;</code> |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |
| `On Summon/Play` | <code>&quot;&quot;</code> | <code>&quot;Apply 1 Nimble to this Unit.&quot;</code> |
| `description` | <code>&quot;If this Unit is in the front row gain +20 DEF, if it is in the back row gain +20 ATK. At the end of your turn: move this Unit to the other Zone in this Column. On Destroy: You can move a Unit to an Adjacent Zone.&quot;</code> | <code>&quot;On Summon: Apply 1 Nimble to this Unit. If this Unit is in the front row gain +20 DEF, if it is in the back row gain +20 ATK. At the end of your turn: move this Unit to the other Zone in this Column. On Destroy: You can move a Unit to an Adjacent Zone.&quot;</code> |

### ID 16 — Edwin, Initiatus of The Order

Old CSV row 78; new CSV row 78. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;If you Destroy an opponents Unit, Apply 1 Rune to this Unit.&quot;</code> | <code>&quot;If you Destroy an opponent&#x27;s Unit, Apply 1 Rune to this Unit.&quot;</code> |
| `description` | <code>&quot;If you Destroy an opponents Unit, Apply 1 Rune to this Unit.&quot;</code> | <code>&quot;If you Destroy an opponent&#x27;s Unit, Apply 1 Rune to this Unit.&quot;</code> |

### ID 18 — Corrupted Narzyl

Old CSV row 80; new CSV row 80. **3 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;You can Apply 2 Paralyse to a Unit in this Column.&quot;</code> | <code>&quot;You can Apply 1 Paralyse to a Unit in this Column.&quot;</code> |
| `On Field` | <code>&quot;If this Unit Destroys an opponents Unit by battle, Apply 1 Rune to this Unit.&quot;</code> | <code>&quot;If this Unit Destroys an opponent&#x27;s Unit by battle, Apply 1 Rune to this Unit.&quot;</code> |
| `description` | <code>&quot;On Summon: You can Apply 2 Paralyse to a Unit in this Column. If this Unit Destroys an opponents Unit by battle, Apply 1 Rune to this Unit.&quot;</code> | <code>&quot;On Summon: You can Apply 1 Paralyse to a Unit in this Column. If this Unit Destroys an opponent&#x27;s Unit by battle, Apply 1 Rune to this Unit.&quot;</code> |

### ID 75 — Travelwarden

Old CSV row 81; new CSV row 81. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;If one of your Units moves Zone, Apply 1 Rune to this Unit.&quot;</code> | <code>&quot;If one of your Unit&#x27;s moves Zone, Apply 1 Rune to this Unit.&quot;</code> |
| `description` | <code>&quot;If one of your Units moves Zone, Apply 1 Rune to this Unit.&quot;</code> | <code>&quot;If one of your Unit&#x27;s moves Zone, Apply 1 Rune to this Unit.&quot;</code> |

### ID 76 — Soul Devourer

Old CSV row 82; new CSV row 82. **1 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |

### ID 78 — Abraxus Terrormane

Old CSV row 84; new CSV row 84. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `atk` | <code>&quot;26&quot;</code> | <code>&quot;24&quot;</code> |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |

### ID 100 — Gaping Crevasse

Old CSV row 87; new CSV row 87. **1 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |

### ID 102 — Waang, Bender of Elements

Old CSV row 88; new CSV row 88. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;Once per turn: this Units Type can become one of Water, Fire, Earth or Lightning. Once per turn you can Apply 1 Curse to a Unit with the same Type.&quot;</code> | <code>&quot;Once per turn: this Unit&#x27;s Type can become one of Water, Fire, Earth or Lightning. Once per turn you can Apply 1 Curse to a Unit with the same Type.&quot;</code> |
| `description` | <code>&quot;Once per turn: this Units Type can become one of Water, Fire, Earth or Lightning. Once per turn you can Apply 1 Curse to a Unit with the same Type.&quot;</code> | <code>&quot;Once per turn: this Unit&#x27;s Type can become one of Water, Fire, Earth or Lightning. Once per turn you can Apply 1 Curse to a Unit with the same Type.&quot;</code> |

### ID 135 — Dragon Rider

Old CSV row 89; new CSV row 89. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;While this Unit is Protected by a Dragon Unit: that Dragon Unit gains +14 ATK and this Unit cannot declare an attack.&quot;</code> | <code>&quot;While this Unit is Protected by a Dragon Unit: that Dragon Unit gains +14 ATK and this Unit cannot declare an Attack.&quot;</code> |
| `description` | <code>&quot;While this Unit is Protected by a Dragon Unit: that Dragon Unit gains +14 ATK and this Unit cannot declare an attack.&quot;</code> | <code>&quot;While this Unit is Protected by a Dragon Unit: that Dragon Unit gains +14 ATK and this Unit cannot declare an Attack.&quot;</code> |

### ID 162 — Diggie

Old CSV row 91; new CSV row 91. **4 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `atk` | <code>&quot;2&quot;</code> | <code>&quot;6&quot;</code> |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |
| `On Field` | <code>&quot;This Unit can attack your opponent directly.&quot;</code> | <code>&quot;This Unit can attack your opponent directly. If this Unit is Sacrificed, increase this Unit&#x27;s cost +1 AP.&quot;</code> |
| `description` | <code>&quot;This Unit can attack your opponent directly. On Destroy: Apply 1 Blind to the Unit that Destroyed it.&quot;</code> | <code>&quot;This Unit can attack your opponent directly. If this Unit is Sacrificed, increase this Unit&#x27;s cost +1 AP. On Destroy: Apply 1 Blind to the Unit that Destroyed it.&quot;</code> |

### ID 155 — Symbiote Spawn

Old CSV row 92; new CSV row 92. **3 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `name` | <code>&quot;Symbiote - Black&quot;</code> | <code>&quot;Symbiote Spawn&quot;</code> |
| `On Field` | <code>&quot;While this Unit is Protected by a Unit: that Unit gains +10 ATK.&quot;</code> | <code>&quot;If this Unit is Protected by a Unit: that Unit gains +10 ATK.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 1 Eternal to this Unit. While this Unit is Protected by a Unit: that Unit gains +10 ATK.&quot;</code> | <code>&quot;On Summon: Apply 1 Eternal to this Unit. If this Unit is Protected by a Unit: that Unit gains +10 ATK.&quot;</code> |

### ID 156 — Symbiote Larva

Old CSV row 93; new CSV row 93. **4 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `name` | <code>&quot;Symbiote - Red&quot;</code> | <code>&quot;Symbiote Larva&quot;</code> |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |
| `On Field` | <code>&quot;While this Unit is Protected by a Unit: that Unit gains +20 ATK.&quot;</code> | <code>&quot;If this Unit is Protected by a Unit, that Unit gains +10 ATK. At the start of your turn: Draw a card, Discard a card.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 1 Eternal to this Unit. While this Unit is Protected by a Unit: that Unit gains +20 ATK.&quot;</code> | <code>&quot;On Summon: Apply 1 Eternal to this Unit. If this Unit is Protected by a Unit, that Unit gains +10 ATK. At the start of your turn: Draw a card, Discard a card.&quot;</code> |

### ID 157 — Symbiote Siphonophore

Old CSV row 94; new CSV row 94. **3 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `name` | <code>&quot;Symbiote - White&quot;</code> | <code>&quot;Symbiote Siphonophore &quot;</code> |
| `On Field` | <code>&quot;Adjacent Units gain +10 ATK.&quot;</code> | <code>&quot;If this Unit is Protected by a Unit, Adjacent Unit&#x27;s gain +10 ATK. At the start of your turn: Draw a card.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 1 Eternal to this Unit. Adjacent Units gain +10 ATK.&quot;</code> | <code>&quot;On Summon: Apply 1 Eternal to this Unit. If this Unit is Protected by a Unit, Adjacent Unit&#x27;s gain +10 ATK. At the start of your turn: Draw a card.&quot;</code> |

### ID 158 — Divine Serpent - Head

Old CSV row 95; new CSV row 95. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;If you control 2 Adjacent &#x27;Divine Serpent&#x27; Units: Damage your opponent -30 HP.&quot;</code> | <code>&quot;If you control 2 Adjacent &#x27;Divine Serpent&#x27; Unit&#x27;s: Damage your opponent -30 HP.&quot;</code> |
| `description` | <code>&quot;On Summon: If you control 2 Adjacent &#x27;Divine Serpent&#x27; Units: Damage your opponent -30 HP. Once per turn: you can Apply 1 Paralyse to a Unit in this Column.&quot;</code> | <code>&quot;On Summon: If you control 2 Adjacent &#x27;Divine Serpent&#x27; Unit&#x27;s: Damage your opponent -30 HP. Once per turn: you can Apply 1 Paralyse to a Unit in this Column.&quot;</code> |

### ID 159 — Divine Serpent - Body

Old CSV row 96; new CSV row 96. **3 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;If you control 2 Adjacent &#x27;Divine Serpent&#x27; Units: Damage your opponent -30 HP.&quot;</code> | <code>&quot;If you control 2 Adjacent &#x27;Divine Serpent&#x27; Unit&#x27;s: Damage your opponent -30 HP.&quot;</code> |
| `On Field` | <code>&quot;Adjacent Units gain +10 DEF.&quot;</code> | <code>&quot;While this Unit is on the Field: Adjacent Unit&#x27;s gain +10 DEF.&quot;</code> |
| `description` | <code>&quot;On Summon: If you control 2 Adjacent &#x27;Divine Serpent&#x27; Units: Damage your opponent -30 HP. Adjacent Units gain +10 DEF.&quot;</code> | <code>&quot;On Summon: If you control 2 Adjacent &#x27;Divine Serpent&#x27; Unit&#x27;s: Damage your opponent -30 HP. While this Unit is on the Field: Adjacent Unit&#x27;s gain +10 DEF.&quot;</code> |

### ID 160 — Divine Serpent - Soul

Old CSV row 97; new CSV row 97. **3 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;If you control 2 Adjacent &#x27;Divine Serpent&#x27; Units: Damage your opponent -30 HP.&quot;</code> | <code>&quot;If you control 2 Adjacent &#x27;Divine Serpent&#x27; Unit&#x27;s: Damage your opponent -30 HP.&quot;</code> |
| `On Field` | <code>&quot;Once per turn: you can make your opponents Units lose -4 ATK&quot;</code> | <code>&quot;Once per turn: you can make your opponent&#x27;s Unit&#x27;s Permanently lose -4 ATK.&quot;</code> |
| `description` | <code>&quot;On Summon: If you control 2 Adjacent &#x27;Divine Serpent&#x27; Units: Damage your opponent -30 HP. Once per turn: you can make your opponents Units lose -4 ATK&quot;</code> | <code>&quot;On Summon: If you control 2 Adjacent &#x27;Divine Serpent&#x27; Unit&#x27;s: Damage your opponent -30 HP. Once per turn: you can make your opponent&#x27;s Unit&#x27;s Permanently lose -4 ATK.&quot;</code> |

### ID 80 — Wings of Aurenthor

Old CSV row 98; new CSV row 98. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Apply 1 Nimble to all Units.&quot;</code> | <code>&quot;Apply 1 Nimble to all Unit&#x27;s.&quot;</code> |
| `description` | <code>&quot;Apply 1 Nimble to all Units.&quot;</code> | <code>&quot;Apply 1 Nimble to all Unit&#x27;s.&quot;</code> |

### ID 81 — Fog of War

Old CSV row 99; new CSV row 99. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Apply 1 Blind to all Units on the Field.&quot;</code> | <code>&quot;Apply 1 Blind to all Unit&#x27;s on the Field.&quot;</code> |
| `description` | <code>&quot;Apply 1 Blind to all Units on the Field.&quot;</code> | <code>&quot;Apply 1 Blind to all Unit&#x27;s on the Field.&quot;</code> |

### ID 82 — Polymerization

Old CSV row 100; new CSV row 100. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Fusion Summon a Unit using Units from your Field.&quot;</code> | <code>&quot;Fusion Summon a Unit using Unit&#x27;s from your Field.&quot;</code> |
| `description` | <code>&quot;Fusion Summon a Unit using Units from your Field.&quot;</code> | <code>&quot;Fusion Summon a Unit using Unit&#x27;s from your Field.&quot;</code> |

### ID 42 — Ambush

Old CSV row 102; new CSV row 102. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Summon as many Basic Units as possible from your Hand and Draw.&quot;</code> | <code>&quot;Summon as many Basic Unit&#x27;s as possible from your Hand and Draw.&quot;</code> |
| `description` | <code>&quot;Summon as many Basic Units as possible from your Hand and Draw.&quot;</code> | <code>&quot;Summon as many Basic Unit&#x27;s as possible from your Hand and Draw.&quot;</code> |

### ID 43 — Freaky Funday

Old CSV row 103; new CSV row 103. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Until the end of this turn, switch the ATK/DEF of all Units currently on the Field.&quot;</code> | <code>&quot;Until the end of this turn, switch the ATK/DEF of all Unit&#x27;s currently on the Field.&quot;</code> |
| `description` | <code>&quot;Until the end of this turn, switch the ATK/DEF of all Units currently on the Field.&quot;</code> | <code>&quot;Until the end of this turn, switch the ATK/DEF of all Unit&#x27;s currently on the Field.&quot;</code> |

### ID 101 — Into the Void

Old CSV row 107; new CSV row 107. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Exhaust a card from your opponents Spent. If this Spell is sent from the Field to Spent, Exhaust this Spell.&quot;</code> | <code>&quot;Exhaust a card from your opponent&#x27;s Spent. If this Spell is sent from the Field to Spent, Exhaust this Spell.&quot;</code> |
| `description` | <code>&quot;Exhaust a card from your opponents Spent. If this Spell is sent from the Field to Spent, Exhaust this Spell.&quot;</code> | <code>&quot;Exhaust a card from your opponent&#x27;s Spent. If this Spell is sent from the Field to Spent, Exhaust this Spell.&quot;</code> |

### ID 104 — Earthquake

Old CSV row 108; new CSV row 108. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Change Stance of your opponents Unprotected Units.&quot;</code> | <code>&quot;Change Stance of your opponent&#x27;s Unprotected Unit&#x27;s.&quot;</code> |
| `description` | <code>&quot;Change Stance of your opponents Unprotected Units.&quot;</code> | <code>&quot;Change Stance of your opponent&#x27;s Unprotected Unit&#x27;s.&quot;</code> |

### ID 136 — Equaliser

Old CSV row 109; new CSV row 109. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Destroy all Units with 20 ATK or more. If this Spell is sent from the Field to Spent, Exhaust this Spell.&quot;</code> | <code>&quot;Destroy all Unit&#x27;s with 20 ATK or more. If this Spell is sent from the Field to Spent, Exhaust this Spell.&quot;</code> |
| `description` | <code>&quot;Destroy all Units with 20 ATK or more. If this Spell is sent from the Field to Spent, Exhaust this Spell.&quot;</code> | <code>&quot;Destroy all Unit&#x27;s with 20 ATK or more. If this Spell is sent from the Field to Spent, Exhaust this Spell.&quot;</code> |

### ID 180 — Hypnotise

Old CSV row 111; new CSV row 111. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Until the end of this turn, take control of an opponents Unit with 20 ATK or less. That Unit cannot be Sacrificed.&quot;</code> | <code>&quot;Until the end of this turn, take control of an opponent&#x27;s Unit with 20 ATK or less. That Unit cannot be Sacrificed.&quot;</code> |
| `description` | <code>&quot;Until the end of this turn, take control of an opponents Unit with 20 ATK or less. That Unit cannot be Sacrificed.&quot;</code> | <code>&quot;Until the end of this turn, take control of an opponent&#x27;s Unit with 20 ATK or less. That Unit cannot be Sacrificed.&quot;</code> |

### ID 86 — Get Well Soon

Old CSV row 115; new CSV row 115. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `condition` | <code>&quot;If your opponent Destroys one of your Units:&quot;</code> | <code>&quot;If your opponent Destroys one of your Unit&#x27;s:&quot;</code> |
| `description` | <code>&quot;If your opponent Destroys one of your Units: Apply 4 Medic to a Unit.&quot;</code> | <code>&quot;If your opponent Destroys one of your Unit&#x27;s: Apply 4 Medic to a Unit.&quot;</code> |

### ID 87 — Shared Fate

Old CSV row 116; new CSV row 116. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Destroy an opponents Unit.&quot;</code> | <code>&quot;Destroy an opponent&#x27;s Unit.&quot;</code> |
| `description` | <code>&quot;If your Unit is Destroyed by an Effect: Destroy an opponents Unit.&quot;</code> | <code>&quot;If your Unit is Destroyed by an Effect: Destroy an opponent&#x27;s Unit.&quot;</code> |

### ID 45 — Magic Cylinder

Old CSV row 117; new CSV row 117. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Your opponents loses HP equal to the Attacking Units ATK. If this card is Activated, increase this card costs +1 AP.&quot;</code> | <code>&quot;Your opponent&#x27;s loses HP equal to the Attacking Unit&#x27;s ATK. If this card is Activated, increase this card costs +1 AP.&quot;</code> |
| `description` | <code>&quot;If your opponent declares an attack in this Column: Your opponents loses HP equal to the Attacking Units ATK. If this card is Activated, increase this card costs +1 AP.&quot;</code> | <code>&quot;If your opponent declares an attack in this Column: Your opponent&#x27;s loses HP equal to the Attacking Unit&#x27;s ATK. If this card is Activated, increase this card costs +1 AP.&quot;</code> |

### ID 46 — Mirror Force

Old CSV row 118; new CSV row 118. **3 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `condition` | <code>&quot;If an opponents declares an attack (whilst they have 4 or more cards on the Field):&quot;</code> | <code>&quot;If an opponent&#x27;s declares an attack (while they have 4 or more cards on the Field):&quot;</code> |
| `On Summon/Play` | <code>&quot;Destroy all your opponents Units in Attack Stance.&quot;</code> | <code>&quot;Destroy all your opponent&#x27;s Unit&#x27;s in Attack Stance.&quot;</code> |
| `description` | <code>&quot;If an opponents declares an attack (whilst they have 4 or more cards on the Field): Destroy all your opponents Units in Attack Stance.&quot;</code> | <code>&quot;If an opponent&#x27;s declares an attack (while they have 4 or more cards on the Field): Destroy all your opponent&#x27;s Unit&#x27;s in Attack Stance.&quot;</code> |

### ID 47 — Damage Conversion

Old CSV row 119; new CSV row 119. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;You gain HP equal to the Attacking Units ATK. If this card is Activated, increase this card costs +1 AP.&quot;</code> | <code>&quot;You gain HP equal to the Attacking Unit&#x27;s ATK. If this Trap is Activated, increase this card&#x27;s cost +1 AP.&quot;</code> |
| `description` | <code>&quot;If your opponent declares an attack in this Column: You gain HP equal to the Attacking Units ATK. If this card is Activated, increase this card costs +1 AP.&quot;</code> | <code>&quot;If your opponent declares an attack in this Column: You gain HP equal to the Attacking Unit&#x27;s ATK. If this Trap is Activated, increase this card&#x27;s cost +1 AP.&quot;</code> |

### ID 48 — Overextend

Old CSV row 120; new CSV row 120. **3 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `condition` | <code>&quot;If your opponent Summons a Unit (and now has 3 or more Units on the Field):&quot;</code> | <code>&quot;If your opponent Summons a Unit (and now has 3 or more Unit&#x27;s on the Field):&quot;</code> |
| `On Summon/Play` | <code>&quot;Your opponents Unit with the highest ATK loses -20 ATK.&quot;</code> | <code>&quot;Your opponent&#x27;s Unit with the highest ATK loses -20 ATK.&quot;</code> |
| `description` | <code>&quot;If your opponent Summons a Unit (and now has 3 or more Units on the Field): Your opponents Unit with the highest ATK loses -20 ATK.&quot;</code> | <code>&quot;If your opponent Summons a Unit (and now has 3 or more Unit&#x27;s on the Field): Your opponent&#x27;s Unit with the highest ATK loses -20 ATK.&quot;</code> |

### ID 51 — Rushed Recklessly

Old CSV row 123; new CSV row 123. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Until the end of this turn: your Units in this Column gain +8 DEF.&quot;</code> | <code>&quot;Until the end of this turn: your Unit&#x27;s in this Column gain +8 DEF.&quot;</code> |
| `description` | <code>&quot;If your opponent declares an attack: Until the end of this turn: your Units in this Column gain +8 DEF.&quot;</code> | <code>&quot;If your opponent declares an attack: Until the end of this turn: your Unit&#x27;s in this Column gain +8 DEF.&quot;</code> |

### ID 53 — Power of Normal

Old CSV row 132; new CSV row 132. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;All your Basic Units gain +8 ATK.&quot;</code> | <code>&quot;All your Basic Unit&#x27;s gain +8 ATK.&quot;</code> |
| `description` | <code>&quot;All your Basic Units gain +8 ATK.&quot;</code> | <code>&quot;All your Basic Unit&#x27;s gain +8 ATK.&quot;</code> |

### ID 54 — Strength in Unity

Old CSV row 133; new CSV row 133. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;Units you control gain +4 ATK / DEF for each unique Race you have on the Field.&quot;</code> | <code>&quot;Unit&#x27;s you control gain +4 ATK / DEF for each unique Race you have on the Field.&quot;</code> |
| `description` | <code>&quot;Units you control gain +4 ATK / DEF for each unique Race you have on the Field.&quot;</code> | <code>&quot;Unit&#x27;s you control gain +4 ATK / DEF for each unique Race you have on the Field.&quot;</code> |

### ID 89 — Nether Portal

Old CSV row 134; new CSV row 134. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;Once per turn you can spend 1 AP to Fusion Summon using Units on your Field.&quot;</code> | <code>&quot;Once per turn: you can spend 1 AP to Fusion Summon using Unit&#x27;s on your Field.&quot;</code> |
| `description` | <code>&quot;Once per turn you can spend 1 AP to Fusion Summon using Units on your Field.&quot;</code> | <code>&quot;Once per turn: you can spend 1 AP to Fusion Summon using Unit&#x27;s on your Field.&quot;</code> |

### ID 55 — Spy

Old CSV row 135; new CSV row 135. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;Once per turn, you can lose -2 HP, Apply Reveal to a facedown card.&quot;</code> | <code>&quot;Once per turn: you can lose -2 HP, Apply Reveal to a facedown card.&quot;</code> |
| `description` | <code>&quot;Once per turn, you can lose -2 HP, Apply Reveal to a facedown card.&quot;</code> | <code>&quot;Once per turn: you can lose -2 HP, Apply Reveal to a facedown card.&quot;</code> |

### ID 90 — Chains of Binding

Old CSV row 136; new CSV row 136. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;Once per turn, Apply 1 Paralyse to a Unit.&quot;</code> | <code>&quot;Once per turn: you can Apply 1 Paralyse to a Unit.&quot;</code> |
| `description` | <code>&quot;Once per turn, Apply 1 Paralyse to a Unit.&quot;</code> | <code>&quot;Once per turn: you can Apply 1 Paralyse to a Unit.&quot;</code> |

### ID 137 — Unstable Fusions

Old CSV row 139; new CSV row 139. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;You can now use Units from your Hand as Tribute for a Fusion Summon. Exhaust Units used from your Hand.&quot;</code> | <code>&quot;You can now use Unit&#x27;s from your Hand as Tribute for a Fusion Summon. Exhaust Unit&#x27;s used from your Hand.&quot;</code> |
| `description` | <code>&quot;You can now use Units from your Hand as Tribute for a Fusion Summon. Exhaust Units used from your Hand.&quot;</code> | <code>&quot;You can now use Unit&#x27;s from your Hand as Tribute for a Fusion Summon. Exhaust Unit&#x27;s used from your Hand.&quot;</code> |

### ID 149 — Marked by the Abyss

Old CSV row 141; new CSV row 141. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;You cannot Activate this Power if your Deck contains a 0 Cost card. Whilst you have a card in your Exhaust, gain +1 AP.&quot;</code> | <code>&quot;You cannot Activate this Power if your Deck contains a 0 Cost card. While you have a card in your Exhaust: gain +1 AP.&quot;</code> |
| `description` | <code>&quot;You cannot Activate this Power if your Deck contains a 0 Cost card. Whilst you have a card in your Exhaust, gain +1 AP.&quot;</code> | <code>&quot;You cannot Activate this Power if your Deck contains a 0 Cost card. While you have a card in your Exhaust: gain +1 AP.&quot;</code> |

### ID 178 — Reinforcements

Old CSV row 147; new CSV row 147. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;If only your opponent controls a Unit, your Units now cost -1 AP.&quot;</code> | <code>&quot;If only your opponent controls a Unit, your Unit&#x27;s now cost -1 AP.&quot;</code> |
| `description` | <code>&quot;If only your opponent controls a Unit, your Units now cost -1 AP.&quot;</code> | <code>&quot;If only your opponent controls a Unit, your Unit&#x27;s now cost -1 AP.&quot;</code> |

### ID 179 — Tyrants Lantern

Old CSV row 148; new CSV row 148. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;Your Fire Units gain + 12 ATK. If your Fire Unit is Destroyed, you lose -6 HP and then your opponent loses -6 HP.&quot;</code> | <code>&quot;Your Fire Unit&#x27;s gain + 12 ATK. If your Fire Unit is Destroyed, you lose -6 HP and then your opponent loses -6 HP.&quot;</code> |
| `description` | <code>&quot;Your Fire Units gain + 12 ATK. If your Fire Unit is Destroyed, you lose -6 HP and then your opponent loses -6 HP.&quot;</code> | <code>&quot;Your Fire Unit&#x27;s gain + 12 ATK. If your Fire Unit is Destroyed, you lose -6 HP and then your opponent loses -6 HP.&quot;</code> |

### ID 56 — Razeon Storm

Old CSV row 150; new CSV row 150. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Destruction` | <code>&quot;Apply 1 Paralyse to all Units.&quot;</code> | <code>&quot;Apply 1 Paralyse to all Unit&#x27;s.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply Reveal to all facedown cards. On Destroy: Apply 1 Paralyse to all Units.&quot;</code> | <code>&quot;On Summon: Apply Reveal to all facedown cards. On Destroy: Apply 1 Paralyse to all Unit&#x27;s.&quot;</code> |

### ID 57 — Geolock Colossus

Old CSV row 151; new CSV row 151. **4 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `keywords` | <code>&quot;&quot;</code> | <code>&quot;Infiltrate, Nimble&quot;</code> |
| `On Summon/Play` | <code>&quot;&quot;</code> | <code>&quot;You can Apply 1 Infiltrate and 1 Nimble to your Unit&#x27;s.&quot;</code> |
| `On Field` | <code>&quot;Once per turn: you can move one of your Units to any other free Zone on your Field.&quot;</code> | <code>&quot;Once per turn: You can Change Stance of your opponent&#x27;s Unprotected Unit&#x27;s.&quot;</code> |
| `description` | <code>&quot;Once per turn: you can move one of your Units to any other free Zone on your Field.&quot;</code> | <code>&quot;On Summon: You can Apply 1 Infiltrate and 1 Nimble to your Unit&#x27;s. Once per turn: You can Change Stance of your opponent&#x27;s Unprotected Unit&#x27;s.&quot;</code> |

### ID 58 — Infernogate the Three-Fanged

Old CSV row 152; new CSV row 152. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;Once per turn: you can Apply 10 Burn to all Units.&quot;</code> | <code>&quot;Once per turn: you can Apply 10 Burn to all Unit&#x27;s.&quot;</code> |
| `description` | <code>&quot;On Summon: You can Destroy a Power. Once per turn: you can Apply 10 Burn to all Units.&quot;</code> | <code>&quot;On Summon: You can Destroy a Power. Once per turn: you can Apply 10 Burn to all Unit&#x27;s.&quot;</code> |

### ID 59 — Abysslord the Tidecaller

Old CSV row 153; new CSV row 153. **3 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `keywords` | <code>&quot;Reveal, Paralyse, Infiltrate&quot;</code> | <code>&quot;Paralyse, Infiltrate&quot;</code> |
| `On Summon/Play` | <code>&quot;You can Destroy a card with Reveal.&quot;</code> | <code>&quot;You can Destroy a Spell or Trap.&quot;</code> |
| `description` | <code>&quot;On Summon: You can Destroy a card with Reveal. Once per turn: you can Apply 1 Paralyse to a Unit. Once per turn you can Apply 1 Infiltrate to a Unit.&quot;</code> | <code>&quot;On Summon: You can Destroy a Spell or Trap. Once per turn: you can Apply 1 Paralyse to a Unit. Once per turn you can Apply 1 Infiltrate to a Unit.&quot;</code> |

### ID 94 — Mirrorflesh Construct

Old CSV row 157; new CSV row 157. **4 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `condition` | <code>&quot;2 Units with the same Type&quot;</code> | <code>&quot;2 Unit&#x27;s with the same Type&quot;</code> |
| `On Summon/Play` | <code>&quot;This Units ATK/DEF/Type becomes the combined ATK/DEF/Type of the Units Tributed.&quot;</code> | <code>&quot;This Unit&#x27;s ATK/DEF/Type becomes the combined ATK/DEF/Type of the Unit&#x27;s Tributed.&quot;</code> |
| `description` | <code>&quot;On Summon: This Units ATK/DEF/Type becomes the combined ATK/DEF/Type of the Units Tributed. On Destroy: Destroy a Unit with the same Type as this Unit.&quot;</code> | <code>&quot;On Summon: This Unit&#x27;s ATK/DEF/Type becomes the combined ATK/DEF/Type of the Unit&#x27;s Tributed. On Destroy: Destroy a Unit with the same Type as this Unit.&quot;</code> |
| `material` | <code>&quot;2 Units with the same Type&quot;</code> | <code>&quot;2 Unit&#x27;s with the same Type&quot;</code> |

### ID 141 — Bahatia

Old CSV row 158; new CSV row 158. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;Once per turn: this Units Type can become one of Physical, Heavenly or Necrotic. Your opponent cannot summon Unit&#x27;s with the same Type as this Unit.&quot;</code> | <code>&quot;Once per turn: this Unit&#x27;s Type can become one of Physical, Heavenly or Necrotic. Your opponent cannot summon Unit&#x27;s with the same Type as this Unit.&quot;</code> |
| `description` | <code>&quot;Once per turn: this Units Type can become one of Physical, Heavenly or Necrotic. Your opponent cannot summon Unit&#x27;s with the same Type as this Unit. On Destroy: You can make a Unit with the same Type as this Unit lose -30 ATK/DEF.&quot;</code> | <code>&quot;Once per turn: this Unit&#x27;s Type can become one of Physical, Heavenly or Necrotic. Your opponent cannot summon Unit&#x27;s with the same Type as this Unit. On Destroy: You can make a Unit with the same Type as this Unit lose -30 ATK/DEF.&quot;</code> |

### ID 143 — Typhoon Simorgh

Old CSV row 160; new CSV row 160. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Field` | <code>&quot;Once per turn, you can Apply 1 Nimble to all your Units. Once per turn, you can Apply 1 Blind to all your opponents Units.&quot;</code> | <code>&quot;Once per turn, you can Apply 1 Nimble to all your Unit&#x27;s. Once per turn, you can Apply 1 Blind to all your opponent&#x27;s Unit&#x27;s.&quot;</code> |
| `description` | <code>&quot;Once per turn, you can Apply 1 Nimble to all your Units. Once per turn, you can Apply 1 Blind to all your opponents Units.&quot;</code> | <code>&quot;Once per turn, you can Apply 1 Nimble to all your Unit&#x27;s. Once per turn, you can Apply 1 Blind to all your opponent&#x27;s Unit&#x27;s.&quot;</code> |

### ID 145 — Trigonam

Old CSV row 162; new CSV row 162. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Apply 10 Burn to all Units.&quot;</code> | <code>&quot;Apply 10 Burn to all Unit&#x27;s.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 10 Burn to all Units. Once per turn: you can spend -1 AP, gain +10 HP.&quot;</code> | <code>&quot;On Summon: Apply 10 Burn to all Unit&#x27;s. Once per turn: you can spend -1 AP, gain +10 HP.&quot;</code> |

### ID 146 — Akiramari

Old CSV row 163; new CSV row 163. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Apply 5 Medic to all Basic Units.&quot;</code> | <code>&quot;Apply 5 Medic to all Basic Unit&#x27;s.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 5 Medic to all Basic Units. On Destroy: You can Summon a Basic Unit from your Spent or Draw to the Zone this Unit was originally in.&quot;</code> | <code>&quot;On Summon: Apply 5 Medic to all Basic Unit&#x27;s. On Destroy: You can Summon a Basic Unit from your Spent or Draw to the Zone this Unit was originally in.&quot;</code> |

### ID 147 — Demented Apparition

Old CSV row 164; new CSV row 164. **4 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `On Summon/Play` | <code>&quot;Apply 2 Paralyse to all your opponents Unprotected Units.&quot;</code> | <code>&quot;Apply 2 Paralyse to all your opponent&#x27;s Unprotected Unit&#x27;s.&quot;</code> |
| `On Field` | <code>&quot;At the start of your turn: your opponents Units lose -8 DEF. If your opponents Unit attacks, then it must attack this Unit.&quot;</code> | <code>&quot;At the start of your turn: your opponent&#x27;s Unit&#x27;s lose -8 DEF. If your opponent&#x27;s Unit attacks, then it must attack this Unit.&quot;</code> |
| `On Destruction` | <code>&quot;Change Stance of all Units.&quot;</code> | <code>&quot;Change Stance of all Unit&#x27;s.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 2 Paralyse to all your opponents Unprotected Units. At the start of your turn: your opponents Units lose -8 DEF. If your opponents Unit attacks, then it must attack this Unit. On Destroy: Change Stance of all Units.&quot;</code> | <code>&quot;On Summon: Apply 2 Paralyse to all your opponent&#x27;s Unprotected Unit&#x27;s. At the start of your turn: your opponent&#x27;s Unit&#x27;s lose -8 DEF. If your opponent&#x27;s Unit attacks, then it must attack this Unit. On Destroy: Change Stance of all Unit&#x27;s.&quot;</code> |

### ID 181 — Solomon, the Tyrannical

Old CSV row 165; new CSV row 165. **4 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;163&quot;</code> | <code>&quot;164&quot;</code> |
| `On Field` | <code>&quot;Once per turn: you can Exhaust a Warrior Unit from your Spent, Apply 1 Eternal to this Unit and gain +1 AP.&quot;</code> | <code>&quot;Once per turn: While this Unit is Protecting a Unit: you can Exhaust that Unit, Apply 1 Eternal to this Unit and gain +1 AP.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 2 Pierce to this Unit. Once per turn: you can Exhaust a Warrior Unit from your Spent, Apply 1 Eternal to this Unit and gain +1 AP. On Destroy: You lose -12 HP.&quot;</code> | <code>&quot;On Summon: Apply 2 Pierce to this Unit. Once per turn: While this Unit is Protecting a Unit: you can Exhaust that Unit, Apply 1 Eternal to this Unit and gain +1 AP. On Destroy: You lose -12 HP.&quot;</code> |
| `card_img` | <code>&quot;163.png&quot;</code> | <code>&quot;164.png&quot;</code> |

### ID 151 — Ultimate Dragon

Old CSV row 166; new CSV row 166. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;164&quot;</code> | <code>&quot;165&quot;</code> |
| `card_img` | <code>&quot;164.png&quot;</code> | <code>&quot;165.png&quot;</code> |

### ID 98 — Raging Inferno

Old CSV row 167; new CSV row 167. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;165&quot;</code> | <code>&quot;166&quot;</code> |
| `card_img` | <code>&quot;165.png&quot;</code> | <code>&quot;166.png&quot;</code> |

### ID 62 — Naturewrath Ascendant

Old CSV row 168; new CSV row 168. **3 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;166&quot;</code> | <code>&quot;168&quot;</code> |
| `condition` | <code>&quot;&quot;</code> | <code>&quot;temp&quot;</code> |
| `card_img` | <code>&quot;166.png&quot;</code> | <code>&quot;168.png&quot;</code> |

### ID 63 — The Last Foundation

Old CSV row 169; new CSV row 169. **8 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;167&quot;</code> | <code>&quot;169&quot;</code> |
| `keywords` | <code>&quot;Eternal&quot;</code> | <code>&quot;Reveal, Eternal&quot;</code> |
| `condition` | <code>&quot;Apply Reveal to all facedown cards.&quot;</code> | <code>&quot;temp&quot;</code> |
| `On Summon/Play` | <code>&quot;&quot;</code> | <code>&quot;Apply Reveal to all Spells and Traps.&quot;</code> |
| `On Field` | <code>&quot;At the end of your turn: if this Unit doesn&#x27;t have a Buff, Apply 1 Eternal to this Unit. This Unit cannot Move Zone.&quot;</code> | <code>&quot;At the end of your turn: Apply 1 Eternal to this Unit.&quot;</code> |
| `On Destruction` | <code>&quot;Destroy your opponents Unit with the lowest ATK.&quot;</code> | <code>&quot;Destroy your opponent&#x27;s Unit with the lowest ATK.&quot;</code> |
| `description` | <code>&quot;At the end of your turn: if this Unit doesn&#x27;t have a Buff, Apply 1 Eternal to this Unit. This Unit cannot Move Zone. On Destroy: Destroy your opponents Unit with the lowest ATK.&quot;</code> | <code>&quot;On Summon: Apply Reveal to all Spells and Traps. At the end of your turn: Apply 1 Eternal to this Unit. On Destroy: Destroy your opponent&#x27;s Unit with the lowest ATK.&quot;</code> |
| `card_img` | <code>&quot;167.png&quot;</code> | <code>&quot;169.png&quot;</code> |

### ID 64 — Necrovast the Undying

Old CSV row 170; new CSV row 170. **4 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;168&quot;</code> | <code>&quot;170&quot;</code> |
| `On Field` | <code>&quot;This Unit gains +6 ATK/DEF x the number of cards in your Exhaust.&quot;</code> | <code>&quot;While this Unit is on the Field: this Unit gains +6 ATK/DEF x the number of cards in your Exhaust.&quot;</code> |
| `description` | <code>&quot;This Unit gains +6 ATK/DEF x the number of cards in your Exhaust. On Destroy: You can move a card from Exhaust to Draw.&quot;</code> | <code>&quot;While this Unit is on the Field: this Unit gains +6 ATK/DEF x the number of cards in your Exhaust. On Destroy: You can move a card from Exhaust to Draw.&quot;</code> |
| `card_img` | <code>&quot;168.png&quot;</code> | <code>&quot;170.png&quot;</code> |

### ID 66 — Nyxthral, Beyond Reason

Old CSV row 171; new CSV row 171. **2 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;169&quot;</code> | <code>&quot;171&quot;</code> |
| `card_img` | <code>&quot;169.png&quot;</code> | <code>&quot;171.png&quot;</code> |

### ID 95 — Mimic

Old CSV row 172; new CSV row 172. **6 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;170&quot;</code> | <code>&quot;172&quot;</code> |
| `cost` | <code>&quot;3R&quot;</code> | <code>&quot;2R&quot;</code> |
| `On Summon/Play` | <code>&quot;Apply 2 Paralyse to an opponents Unprotected Unit in this Column, this Units ATK/DEF/Type becomes the ATK/DEF/Type of that Unit.&quot;</code> | <code>&quot;Apply 2 Paralyse to an opponent&#x27;s Unprotected Unit in this Column, this Unit&#x27;s ATK/DEF/Type becomes the ATK/DEF/Type of that Unit.&quot;</code> |
| `On Destruction` | <code>&quot;Double all Debuffs on your opponents Units.&quot;</code> | <code>&quot;Double all Debuffs on your opponent&#x27;s Unit&#x27;s.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 2 Paralyse to an opponents Unprotected Unit in this Column, this Units ATK/DEF/Type becomes the ATK/DEF/Type of that Unit. On Destroy: Double all Debuffs on your opponents Units.&quot;</code> | <code>&quot;On Summon: Apply 2 Paralyse to an opponent&#x27;s Unprotected Unit in this Column, this Unit&#x27;s ATK/DEF/Type becomes the ATK/DEF/Type of that Unit. On Destroy: Double all Debuffs on your opponent&#x27;s Unit&#x27;s.&quot;</code> |
| `card_img` | <code>&quot;170.png&quot;</code> | <code>&quot;172.png&quot;</code> |

### ID 65 — The Creeping Null

Old CSV row 173; new CSV row 173. **6 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;171&quot;</code> | <code>&quot;173&quot;</code> |
| `atk` | <code>&quot;46&quot;</code> | <code>&quot;40&quot;</code> |
| `def` | <code>&quot;42&quot;</code> | <code>&quot;28&quot;</code> |
| `On Summon/Play` | <code>&quot;Apply 1 Paralyse to your opponents Units.&quot;</code> | <code>&quot;Apply 1 Paralyse to your opponent&#x27;s Unit&#x27;s.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 1 Paralyse to your opponents Units. Once per turn: you can Apply 1 Debilitate to a Unit.&quot;</code> | <code>&quot;On Summon: Apply 1 Paralyse to your opponent&#x27;s Unit&#x27;s. Once per turn: you can Apply 1 Debilitate to a Unit.&quot;</code> |
| `card_img` | <code>&quot;171.png&quot;</code> | <code>&quot;173.png&quot;</code> |

### ID 97 — The Legendary Swordsman

Old CSV row 174; new CSV row 174. **7 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;172&quot;</code> | <code>&quot;174&quot;</code> |
| `keywords` | <code>&quot;Rune, Infiltrate&quot;</code> | <code>&quot;Rune, Cleanse, Infiltrate&quot;</code> |
| `condition` | <code>&quot;Apply 3 Cleanse to this Unit.&quot;</code> | <code>&quot;&quot;</code> |
| `On Summon/Play` | <code>&quot;&quot;</code> | <code>&quot;Apply 3 Cleanse to this Unit.&quot;</code> |
| `On Field` | <code>&quot;Once per turn: you can Apply 1 Infiltrate to this Unit. Whilst your HP is lower than your opponents, this Unit gains +30 ATK.&quot;</code> | <code>&quot;Once per turn: you can Apply 1 Infiltrate to this Unit. While your HP is lower than your opponent&#x27;s, this Unit gains +30 ATK.&quot;</code> |
| `description` | <code>&quot;Once per turn: you can Apply 1 Infiltrate to this Unit. Whilst your HP is lower than your opponents, this Unit gains +30 ATK. On Destroy: You can Apply 2 Rune to a Warrior Unit.&quot;</code> | <code>&quot;On Summon: Apply 3 Cleanse to this Unit. Once per turn: you can Apply 1 Infiltrate to this Unit. While your HP is lower than your opponent&#x27;s, this Unit gains +30 ATK. On Destroy: You can Apply 2 Rune to a Warrior Unit.&quot;</code> |
| `card_img` | <code>&quot;172.png&quot;</code> | <code>&quot;174.png&quot;</code> |

### ID 183 — Yamata, Spirit of the Flame

Old CSV row 175; new CSV row 175. **7 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;173&quot;</code> | <code>&quot;175&quot;</code> |
| `cost` | <code>&quot;4R&quot;</code> | <code>&quot;3R&quot;</code> |
| `atk` | <code>&quot;32&quot;</code> | <code>&quot;12&quot;</code> |
| `def` | <code>&quot;44&quot;</code> | <code>&quot;20&quot;</code> |
| `On Field` | <code>&quot;Once per turn: your opponent loses -6 HP.&quot;</code> | <code>&quot;At the start of your turn: your opponent loses -6 HP.&quot;</code> |
| `description` | <code>&quot;On Summon: Apply 8 Eternal to this Unit. Once per turn: your opponent loses -6 HP. On Destroy: You can add a Power from Spent or Draw to Hand.&quot;</code> | <code>&quot;On Summon: Apply 8 Eternal to this Unit. At the start of your turn: your opponent loses -6 HP. On Destroy: You can add a Power from Spent or Draw to Hand.&quot;</code> |
| `card_img` | <code>&quot;173.png&quot;</code> | <code>&quot;175.png&quot;</code> |

### ID 96 — Roma, Exhile of The Order

Old CSV row 176; new CSV row 176. **4 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;174&quot;</code> | <code>&quot;176&quot;</code> |
| `On Field` | <code>&quot;Once per turn: you can lose -10 HP, Destroy a Unit with ATK lower than this Units ATK.&quot;</code> | <code>&quot;Once per turn: you can lose -10 HP, Destroy a Unit with ATK lower than this Unit&#x27;s ATK.&quot;</code> |
| `description` | <code>&quot;On Summon: This Unit becomes +12 ATK/DEF x the amount of Runes used for it&#x27;s Summon. Once per turn: you can lose -10 HP, Destroy a Unit with ATK lower than this Units ATK.&quot;</code> | <code>&quot;On Summon: This Unit becomes +12 ATK/DEF x the amount of Runes used for it&#x27;s Summon. Once per turn: you can lose -10 HP, Destroy a Unit with ATK lower than this Unit&#x27;s ATK.&quot;</code> |
| `card_img` | <code>&quot;174.png&quot;</code> | <code>&quot;176.png&quot;</code> |

### ID 170 — Grandmother Kaya

Old CSV row 177; new CSV row 177. **4 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;175&quot;</code> | <code>&quot;177&quot;</code> |
| `condition` | <code>&quot;Exhaust Units of equivilant cost from Spent&quot;</code> | <code>&quot;Exhaust Unit&#x27;s from Spent with Cost equivilant to Arcane.&quot;</code> |
| `card_img` | <code>&quot;175.png&quot;</code> | <code>&quot;177.png&quot;</code> |
| `material` | <code>&quot;&quot;</code> | <code>&quot;Exhaust Unit&#x27;s from Spent with Cost equivilant to Arcane.&quot;</code> |

### ID 171 — Flying Sandworm

Old CSV row 178; new CSV row 178. **7 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;176&quot;</code> | <code>&quot;179&quot;</code> |
| `atk` | <code>&quot;4&quot;</code> | <code>&quot;6&quot;</code> |
| `condition` | <code>&quot;Exhaust Units of equivilant cost from Spent&quot;</code> | <code>&quot;Exhaust Unit&#x27;s from Spent with Cost equivilant to Arcane.&quot;</code> |
| `On Field` | <code>&quot;At the start of your turn: gain +6 ATK. This Unit can attack your opponent directly.&quot;</code> | <code>&quot;At the start of your turn: gain +6 ATK. While this Unit is on the Field: this Unit can attack your opponent directly.&quot;</code> |
| `description` | <code>&quot;At the start of your turn: gain +6 ATK. This Unit can attack your opponent directly. On Destroy: Exhaust this Unit.&quot;</code> | <code>&quot;At the start of your turn: gain +6 ATK. While this Unit is on the Field: this Unit can attack your opponent directly. On Destroy: Exhaust this Unit.&quot;</code> |
| `card_img` | <code>&quot;176.png&quot;</code> | <code>&quot;179.png&quot;</code> |
| `material` | <code>&quot;&quot;</code> | <code>&quot;Exhaust Unit&#x27;s from Spent with Cost equivilant to Arcane.&quot;</code> |

### ID 172 — Tyde, Councillor of The Order

Old CSV row 179; new CSV row 179. **8 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;177&quot;</code> | <code>&quot;180&quot;</code> |
| `keywords` | <code>&quot;Reveal&quot;</code> | <code>&quot;Rune&quot;</code> |
| `condition` | <code>&quot;Exhaust Units of equivilant cost from Spent&quot;</code> | <code>&quot;Exhaust Unit&#x27;s from Spent with Cost equivilant to Arcane.&quot;</code> |
| `On Summon/Play` | <code>&quot;&quot;</code> | <code>&quot;You can add a Beast Unit from Draw to Hand, that Unit costs -1 AP this turn.&quot;</code> |
| `On Field` | <code>&quot;If this Unit is Sacrificed, you can Destroy a card with Reveal.&quot;</code> | <code>&quot;Once per turn: you can Destroy a Unit with a Rune.&quot;</code> |
| `description` | <code>&quot;If this Unit is Sacrificed, you can Destroy a card with Reveal.&quot;</code> | <code>&quot;On Summon: You can add a Beast Unit from Draw to Hand, that Unit costs -1 AP this turn. Once per turn: you can Destroy a Unit with a Rune.&quot;</code> |
| `card_img` | <code>&quot;177.png&quot;</code> | <code>&quot;180.png&quot;</code> |
| `material` | <code>&quot;&quot;</code> | <code>&quot;Exhaust Unit&#x27;s from Spent with Cost equivilant to Arcane.&quot;</code> |

### ID 173 — Thunderclap Dragon

Old CSV row 180; new CSV row 180. **7 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;178&quot;</code> | <code>&quot;181&quot;</code> |
| `condition` | <code>&quot;Exhaust Units of equivilant cost from Spent&quot;</code> | <code>&quot;Exhaust Unit&#x27;s from Spent with Cost equivilant to Arcane.&quot;</code> |
| `On Summon/Play` | <code>&quot;Your opponent loses -4 HP x the amount of your opponents Units.&quot;</code> | <code>&quot;Your opponent loses -4 HP x the amount of your opponent&#x27;s Unit&#x27;s.&quot;</code> |
| `On Destruction` | <code>&quot;Apply 1 Paralyse to all Units.&quot;</code> | <code>&quot;Apply 1 Paralyse to all Unit&#x27;s.&quot;</code> |
| `description` | <code>&quot;On Summon: Your opponent loses -4 HP x the amount of your opponents Units. On Destroy: Apply 1 Paralyse to all Units.&quot;</code> | <code>&quot;On Summon: Your opponent loses -4 HP x the amount of your opponent&#x27;s Unit&#x27;s. On Destroy: Apply 1 Paralyse to all Unit&#x27;s.&quot;</code> |
| `card_img` | <code>&quot;178.png&quot;</code> | <code>&quot;181.png&quot;</code> |
| `material` | <code>&quot;&quot;</code> | <code>&quot;Exhaust Unit&#x27;s from Spent with Cost equivilant to Arcane.&quot;</code> |

### ID 174 — Cliff the Flying Bison

Old CSV row 181; new CSV row 181. **4 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;179&quot;</code> | <code>&quot;182&quot;</code> |
| `condition` | <code>&quot;Exhaust Units of equivilant cost from Spent&quot;</code> | <code>&quot;Exhaust Unit&#x27;s from Spent with Cost equivilant to Arcane.&quot;</code> |
| `card_img` | <code>&quot;179.png&quot;</code> | <code>&quot;182.png&quot;</code> |
| `material` | <code>&quot;&quot;</code> | <code>&quot;Exhaust Unit&#x27;s from Spent with Cost equivilant to Arcane.&quot;</code> |

### ID 175 — Boom, Councillor of The Order

Old CSV row 182; new CSV row 182. **7 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;180&quot;</code> | <code>&quot;184&quot;</code> |
| `condition` | <code>&quot;Exhaust Units of equivilant cost from Spent&quot;</code> | <code>&quot;Exhaust Unit&#x27;s from Spent with Cost equivilant to Arcane.&quot;</code> |
| `On Summon/Play` | <code>&quot;Change Stance of your opponents Units.&quot;</code> | <code>&quot;Change Stance of your opponent&#x27;s Unit&#x27;s.&quot;</code> |
| `On Destruction` | <code>&quot;You can make your Units gain +10 DEF.&quot;</code> | <code>&quot;You can make your Unit&#x27;s gain +10 DEF.&quot;</code> |
| `description` | <code>&quot;On Summon: Change Stance of your opponents Units. Once per turn you can Apply 1 Debilitate to a Unit. On Destroy: You can make your Units gain +10 DEF.&quot;</code> | <code>&quot;On Summon: Change Stance of your opponent&#x27;s Unit&#x27;s. Once per turn you can Apply 1 Debilitate to a Unit. On Destroy: You can make your Unit&#x27;s gain +10 DEF.&quot;</code> |
| `card_img` | <code>&quot;180.png&quot;</code> | <code>&quot;184.png&quot;</code> |
| `material` | <code>&quot;&quot;</code> | <code>&quot;Exhaust Unit&#x27;s from Spent with Cost equivilant to Arcane.&quot;</code> |

### ID 176 — Tritu, Heir to the Ocean Tribe

Old CSV row 183; new CSV row 183. **7 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;181&quot;</code> | <code>&quot;185&quot;</code> |
| `condition` | <code>&quot;Exhaust Units of equivilant cost from Spent&quot;</code> | <code>&quot;Exhaust Unit&#x27;s from Spent with Cost equivilant to Arcane.&quot;</code> |
| `On Summon/Play` | <code>&quot;This Units ATK becomes the combined ATK of all Water Units on the Field.&quot;</code> | <code>&quot;This Unit&#x27;s ATK becomes the combined ATK of all Water Unit&#x27;s on the Field.&quot;</code> |
| `On Field` | <code>&quot;Once per turn: you can Apply 2 Medic to Adjacent Units.&quot;</code> | <code>&quot;Once per turn: you can Apply 2 Medic to Adjacent Unit&#x27;s.&quot;</code> |
| `description` | <code>&quot;On Summon: This Units ATK becomes the combined ATK of all Water Units on the Field. Once per turn: you can Apply 2 Medic to Adjacent Units.&quot;</code> | <code>&quot;On Summon: This Unit&#x27;s ATK becomes the combined ATK of all Water Unit&#x27;s on the Field. Once per turn: you can Apply 2 Medic to Adjacent Unit&#x27;s.&quot;</code> |
| `card_img` | <code>&quot;181.png&quot;</code> | <code>&quot;185.png&quot;</code> |
| `material` | <code>&quot;&quot;</code> | <code>&quot;Exhaust Unit&#x27;s from Spent with Cost equivilant to Arcane.&quot;</code> |

### ID 177 — The Illusionist

Old CSV row 184; new CSV row 184. **10 changed fields.**

| Field | Old exact value | New exact value |
| --- | --- | --- |
| `index` | <code>&quot;182&quot;</code> | <code>&quot;186&quot;</code> |
| `type` | <code>&quot;Necrotic&quot;</code> | <code>&quot;?&quot;</code> |
| `atk` | <code>&quot;20&quot;</code> | <code>&quot;30&quot;</code> |
| `condition` | <code>&quot;Exhaust Units of equivilant cost from Spent&quot;</code> | <code>&quot;Exhaust Unit&#x27;s from Spent with Cost equivilant to Arcane.&quot;</code> |
| `On Field` | <code>&quot;Whilst it is your turn, this Unit gains + 20 ATK. This Units attacks do not inflict Damage.&quot;</code> | <code>&quot;While it is your turn: this Unit gains + 30 ATK. This Unit&#x27;s attacks do not inflict Damage.&quot;</code> |
| `On Destruction` | <code>&quot;&quot;</code> | <code>&quot;You can move a 1 cost or lower card from Exhaust to Draw.&quot;</code> |
| `description` | <code>&quot;Whilst it is your turn, this Unit gains + 20 ATK. This Units attacks do not inflict Damage.&quot;</code> | <code>&quot;While it is your turn: this Unit gains + 30 ATK. This Unit&#x27;s attacks do not inflict Damage. On Destroy: You can move a 1 cost or lower card from Exhaust to Draw.&quot;</code> |
| `card_img` | <code>&quot;182.png&quot;</code> | <code>&quot;186.png&quot;</code> |
| `type_icon` | <code>&quot;Card/types/necrotic.png&quot;</code> | <code>&quot;Card/types/unknown.png&quot;</code> |
| `material` | <code>&quot;&quot;</code> | <code>&quot;Exhaust Unit&#x27;s from Spent with Cost equivilant to Arcane.&quot;</code> |

## Unchanged card IDs

82 identified cards have no parsed field changes: 1, 2, 3, 4, 5, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 14, 24, 26, 27, 28, 31, 33, 70, 73, 74, 17, 77, 79, 99, 150, 41, 154, 83, 84, 138, 182, 152, 85, 49, 50, 103, 140, 153, 163, 164, 52, 165, 88, 91, 92, 148, 139, 166, 167, 168, 169, 44, 60, 61, 93, 142, 144.

## Coverage verification

- Matched/common IDs: 183; changed 101 + unchanged 82 = 183.
- Detailed field rows emitted: 319, equal to the sum of per-column counts.
- Headers equal; ID sets equal; duplicate-ID sets empty; all record widths equal the 20-column schema.
- Original baseline, uploaded CSV and runtime game data were not edited. Only this report, its companion implementation prompt and an unchanged dated copy of the uploaded source are deliverables of the task.

Implementation prompt: [implement-card-database-update-2026-10-17.md](implement-card-database-update-2026-10-17.md).
