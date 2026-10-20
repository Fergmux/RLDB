extends GdUnitTestSuite
## J31 (performance): MatchView.log_for reuses the redacted rows of settled log entries per viewer
## (GameCore.log_view_cache). The cached log must always equal one built from scratch
## (MatchView.log_for_full), for every seat and for a spectator, while the game goes on, while the
## latest entry still gains presentation events, and when a toast's card stops being visible.

const VIEWERS := [0, 1, -1]
const STEPS := 260


func _assert_same_log(m: MatchEngine, where: String) -> void:
	for v in VIEWERS:
		assert_str(var_to_str(MatchView.log_for(m, v))).override_failure_message(
			"log for viewer %d differs from a full rebuild %s" % [v, where]).is_equal(var_to_str(MatchView.log_for_full(m, v)))


## Deterministic driver: answers a prompt with its first options, else takes the legal action at a
## rotating index (so units are summoned, attack and the turns pass).
func _step(m: MatchEngine, i: int) -> void:
	var pd: Dictionary = m.pending
	if not pd.is_empty():
		var p: int = pd["player"]
		var n: int = pd["options"].size()
		var want := n if int(pd.get("min_total", 0)) > 0 else maxi(int(pd["min"]), 1)
		if m.submit(p, {"t": "choose", "id": pd["id"], "indices": range(mini(want, n))}) != "" and pd.get("cancellable", false):
			m.submit(p, {"t": "cancel", "id": pd["id"]})
		return
	var legal: Array = MatchView.actions_for(m, m.active).filter(func(a): return a["ok"])
	if legal.is_empty():
		return
	var a: Dictionary = legal[i % legal.size()]
	var cmd := {"t": a["t"]}
	for k in ["uid", "idx", "mode"]:
		if a.has(k):
			cmd[k] = a[k]
	m.submit(m.active, cmd)


func test_log_for_through_a_long_game_matches_full_rebuild() -> void:
	# Arrange
	var m := TB.make(7, 30)
	# Act / Assert: after every command the cached log equals the from-scratch one.
	for i in STEPS:
		if m.winner != -1:
			break
		_step(m, i)
		_assert_same_log(m, "after step %d" % i)
	assert_int(m.log_entries.size()).is_greater(40)


func test_log_for_fx_added_to_latest_entry_after_a_view_is_shown() -> void:
	# Arrange
	var m := TB.make()
	m.add_log("First.")
	m.add_log("Second.")
	MatchView.log_for(m, 0)
	# Act: the latest entry gains a presentation event after the view was built.
	m.add_fx({"k": "hp", "p": 0, "n": -3})
	# Assert
	_assert_same_log(m, "after add_fx")
	var rows := MatchView.log_for(m, 0)
	assert_int((rows[-1]["fx"] as Array).size()).is_equal(1)


func test_log_for_toast_uid_follows_card_visibility() -> void:
	# Arrange: a toast about a unit on the field (public), then a later entry settles it.
	var m := TB.make()
	var uid := TB.unit(m, 0, TB.FILLER, 0)
	m.add_log("No legal target.")
	m.log_entries[-1]["toast"] = true
	m.log_entries[-1]["toast_src"] = uid
	m.add_log("Later.")
	var before := MatchView.log_for(m, 1).filter(func(r): return r.has("toast"))
	# Act: the card goes back to its owner's hand, hidden from seat 1.
	m.cards[uid]["zone"] = "hand"
	var after := MatchView.log_for(m, 1).filter(func(r): return r.has("toast"))
	# Assert
	assert_int(int(before[0].get("toast_uid", -1))).is_equal(uid)
	assert_bool(after[0].has("toast_uid")).is_false()
	_assert_same_log(m, "after the card was hidden")


func test_log_for_since_returns_only_newer_rows() -> void:
	# Arrange
	var m := TB.make()
	for i in 5:
		m.add_log("Line %d." % i)
	var seq := int(m.log_entries[2]["seq"])
	# Act
	var rows := MatchView.log_for(m, 0, seq)
	# Assert
	assert_str(var_to_str(rows)).is_equal(var_to_str(MatchView.log_for_full(m, 0, seq)))
	assert_bool(rows.all(func(r): return int(r["seq"]) > seq)).is_true()
