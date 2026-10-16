# Playtest feedback 07 (user feedback, 16 Oct 2026)

| # | Request | Implementation | Evidence |
| --- | --- | --- | --- |
| 1 | Fusion units: only the "Fusion Unit" tag | Details panel skips the cost tag for Fusion units | `test_fusion_unit_has_no_separate_fusion_tag` |
| 2 | Offered reward cards centred | Offer row centred in the modal | `production/qa/evidence/2026-10-16-fb7/series/09b_reward_offer.png` |
| 3 | Wabuku prompted on a direct attack with no target | A Trap whose effect opens with a required target choice is only offered when that choice has a legal target (before, only Traps flagged `needs_target` were checked) | `test_trap_without_a_legal_target_is_not_offered` (watched failing), `test_trap_with_a_legal_target_is_offered` |

Verified: GdUnit 417/417; live driver 73/73 on the exported exe.
