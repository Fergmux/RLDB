# Owner feedback, 18 October 2026 (afternoon batch)

Online playtest feedback, implemented on `build/rldb-game`. Each item has its own commit and tests.

| # | Request | What changed | Tests |
|---|---|---|---|
| 1 | ATK / DEF indicators are a bit chunky | Narrower shapes (upright diamond, slimmer shield), a gold hairline rim with a dark outline and a soft shadow, a smooth gradient with a fine top highlight. The numbers keep their size. `CardStatBadge` | Headless UI suites. **Screenshot pending** (windowed driver) |
| 2 | Direct attacks should still activate Wabuku | Wabuku is offered on every attack, even with no unit in its column (it then has no target). Other Traps whose first choice has no legal target are still not offered (feedback 07) | `rules_review_regressions_test` |
| 3 | No Fusion / Ritual / Arcane summons in the Battle Phase | Refused in either player's Battle Phase: Ritual / Arcane commands, set Fusion Spells and Fusion abilities give the reason, Fusion methods are hidden, and triggered offers (Bronze Salaman, Tag Team - S) are not made | `rules_battle_extra_summon_test` |
| 4 | A unit with enough Runes gets a Ritual Tribute action | `ritual_tribute` {uid: material, target: Ritual unit}: the same Ritual summon with that material. One "Ritual: <name>" button per Ritual unit when several qualify. The bot keeps the Extra Deck summon | `rules_ritual_tribute_test` |
| 5 | Shimmer Serum (any cost increase) raises Rune and Arcane costs | `GameCore.extra_cost` (printed + permanent + this-turn changes) is used to check, pay and show Ritual / Arcane costs. The gem and details panel show the current cost, red / green when changed | `rules_extra_cost_change_test` |
| 6 | "Host and invite" should just be "Host" | Hosting no longer opens the Steam invite dialog. The deck choice screen has an Invite button while the lobby waits | — |
| 7 | Draft categories in any order | No setup step or order. Each category is a tab with its picks left, drafted in any order (`draft_category`). A category keeps its offer when you switch away, so switching never re-rolls an offer | `series_f06_draft_test`, `draft_category_tabs_test` |
| 8 | Change basics at any point in the draft | `draft_basic` any time until the draft is done; the copies join the deck at the end | `series_f06_draft_test` |
| 9 | "Add an additional basic unit" reward | `reward_extra_basic`: one more copy of the deck's most common basic unit, so it always matches its Type and Race | `series_f06_draft_test` |
| 10 | Status names show their effect on hover; tooltips get an effect section | `StatusHelp`: covers the rules text painted on cards, the details panel, the prompt headline and subject, the game log, the prompt sub-line and tutorial text. Tooltips on cards and on every `UIStyle` button get a separate effect section. Status icon tips add the effect under the name | `status_help_test` |

Also: the host now accepts the attack `mode` field from a remote client (Flying Sandworm could not attack online); Bronze Salaman's deck test follows the deck rename.

Decisions made here, for review:
- **Item 2:** only Wabuku changes. The feedback 07 rule ("a Trap with no legal target is not offered") still applies to other Traps.
- **Item 3:** the Battle Phase lock applies to either player's Battle Phase, so a Trap cannot Fusion summon on the opponent's turn either.
- **Item 7:** the draft opens on the first category with picks left. When a category is finished, the next one opens in display order.
- **Item 9:** with mixed basics (possible after old saves), the most common one is copied.
- **Item 10:** status words are matched only when capitalised, as the card wording writes them, so ordinary words are never caught.
