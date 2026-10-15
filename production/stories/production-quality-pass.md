# Stories — production-quality pass (rules/09)

Epic: reconcile the playable build with the user's decision answers and playtest feedback, then
raise presentation, interaction and verification to production quality. Story types follow
`.claude/docs/coding-standards.md` (evidence rules); `testing.strict` blocks all types.

| ID | Story | Type | Acceptance (measurable) | Status |
| --- | --- | --- | --- | --- |
| PQ-01 | Reconcile engine with P-01..P-31, S-01..S-04, C-03, C-04 | Logic | `rules_decisions_test.gd` passes; each test seen failing on the prior engine | Done (ab59612) |
| PQ-02 | Reworded card texts shown in game (MC, DC, Chains, Options, Yamata) | Config/Data | `cards.json` regenerated; texts match answers | Done |
| PQ-03 | Host may claim current game after 60 s disconnect (game only) | Integration | `test_host_can_claim_current_game_only_after_wait`; series continues | Done |
| PQ-04 | Between-game series save/resume (hot-seat, LAN, Steam host) | Integration | save→JSON→resume test; resume continues to next game; menu lists saves | Done (logic); UI evidence pending |
| PQ-05 | Custom decks (unrestricted) usable in starter-mode series | Logic + UI | `custom_deck` tests; deck builder saves; deck-select lists saved decks | In progress |
| PQ-06 | I-01 board geometry per reference image, seat-relative | UI | Screenshot at 1280x800 / 1600x1000 / 1920x1080 matches reference; both clients bottom = self | In progress |
| PQ-07 | I-02 legal actions on hovered card; details inspection only | UI | Hover shot on hand + field card; no actions in details panel; locked during pending choices | In progress |
| PQ-08 | I-03 art direction, frames, typography, animations, reduced motion | Visual | Before/after shots; mid-animation shot; reduced-motion toggle persists | In progress |
| PQ-09 | Two-client full series incl. nested traps, reconnect during choice, save/resume | Integration | `net_full_series_test`, `net_two_client_test` pass | Pending re-run |
| PQ-10 | Independent QA / UX / security review, fixes re-verified | Integration | Review findings resolved with regression tests | Pending |
| PQ-11 | Steam verification in a real environment | Integration | README two-account checklist executed with evidence | Blocked: needs Steam client + second account |

Performance targets (chosen, not user-specified): ≥60 fps on the board at 1600x1000 on the dev
machine during animations; command-to-view latency on localhost < 100 ms; network view payloads
< 400 KB compressed (warning logged above that).
