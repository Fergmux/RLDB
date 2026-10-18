extends GdUnitTestSuite
## Owner feedback 2026-10-18: choosing a Type for Chaos Witch / Waang can be cancelled; nothing
## changes and the ability can be used again.

const CHAOS_WITCH := 13
const WAANG := 102


func test_type_choice_can_be_cancelled_and_changes_nothing() -> void:
	for id in [CHAOS_WITCH, WAANG]:
		var m := TB.make()
		var uid := TB.unit(m, 0, id, 0)
		var before = m.unit_type(uid)
		assert_str(TB.ability(m, uid, 0)).is_empty()
		assert_str(String(m.pending.get("prompt", ""))).is_equal("Choose a Type.")
		assert_bool(bool(m.pending.get("cancellable", false))).override_failure_message("card %d" % id).is_true()
		assert_str(m.submit(0, {"t": "cancel", "id": m.pending["id"]})).is_empty()
		assert_bool(m.pending.is_empty()).is_true()
		assert_str(m.unit_type(uid)).is_equal(before)
		assert_str(m.validate(0, {"t": "ability", "uid": uid, "idx": 0})).is_empty()
