extends GdUnitTestSuite
## A2: the spectator redaction (MatchView.build_spectator), the third view mode. Without permission
## nothing hidden from either player appears anywhere in the view; with a player's permission that
## player's hidden cards appear, in their orientation, and never a prompt or an action.

const SECRET := 34   # Dragon of the Cave: in no structure deck, so its name only appears if leaked


func _board() -> Dictionary:
	var m := TB.make()
	var s0 := TB.card(m, 0, SECRET, "hand")
	var s1 := TB.card(m, 1, SECRET, "hand")
	var trap0 := TB.set_card(m, 0, 45, 0)   # Magic Cylinder, face down
	var trap1 := TB.set_card(m, 1, 45, 1)
	var unit := TB.unit(m, 0, TB.WATER, 0)
	return {"m": m, "s0": s0, "s1": s1, "trap0": trap0, "trap1": trap1, "unit": unit}


## Every uid of a card hidden from everyone but its owner (hands, draw, spent... and set cards).
func _hidden_uids(m: MatchEngine, p: int) -> Array:
	var out := []
	for z in ["hand", "draw", "extra"]:
		out += m.players[p][z]
	for u in m.players[p]["backrow"]:
		if u != -1 and not m.is_face_up(u):
			out.append(u)
	return out


func _leaks(blob: String, uids: Array) -> Array:
	var out := []
	for u in uids:
		if blob.contains("\"uid\":%d," % u) or blob.contains("\"uid\":%d}" % u):
			out.append(u)
	return out


func test_spectator_without_permission_sees_no_hidden_card_of_either_player() -> void:
	var b := _board()
	var m: MatchEngine = b["m"]
	var v := MatchView.build_spectator(m, 0, -1)
	var blob := JSON.stringify(v)
	assert_str(blob).not_contains("Dragon of the Cave")
	assert_str(blob).not_contains("Magic Cylinder")
	assert_array(_leaks(blob, _hidden_uids(m, 0) + _hidden_uids(m, 1))).is_empty()
	for p in 2:
		var pv: Dictionary = v["players"][p]
		for z in ["hand", "spent", "exhaust", "extra", "draw_inspect"]:
			assert_bool(pv.has(z)).is_false()
		assert_int(pv["counts"]["hand"]).is_greater(0)
	# The face-up board stays public.
	assert_int(int(v["players"][0]["units"][0]["uid"])).is_equal(int(b["unit"]))
	assert_bool(v["players"][0]["backrow"][0]["hidden"]).is_true()
	assert_array(v["actions"]).is_empty()
	assert_int(int(v["you"])).is_equal(0)


func test_spectator_permitted_by_seat_sees_that_seat_only_in_its_orientation() -> void:
	var b := _board()
	var m: MatchEngine = b["m"]
	var v := MatchView.build_spectator(m, 0, 1)
	assert_int(int(v["you"])).is_equal(1)
	var hand: Array = v["players"][1]["hand"]
	assert_bool(hand.any(func(c): return int(c["uid"]) == int(b["s1"]))).is_true()
	assert_bool(v["players"][1]["backrow"][1].get("hidden", false)).is_false()
	# Seat 0's secrets stay hidden.
	var blob0 := JSON.stringify(v["players"][0])
	assert_array(_leaks(blob0, _hidden_uids(m, 0))).is_empty()
	assert_str(blob0).not_contains("Dragon of the Cave")
	assert_bool(v["players"][0].has("hand")).is_false()


func test_spectator_pending_never_carries_options_or_mine() -> void:
	var b := _board()
	var m: MatchEngine = b["m"]
	# Open a real choice for seat 0: a trap response window is easiest through an attack; a stance
	# prompt is enough here (summon from hand opens the zone choice).
	var u := TB.card(m, 0, TB.WATER, "hand")
	m.players[0]["ap"] = 20
	assert_str(m.submit(0, {"t": "summon", "uid": u, "stance": "atk"})).is_empty()
	assert_bool(m.pending.is_empty()).is_false()
	for vis in [-1, 0]:
		var pd: Dictionary = MatchView.build_spectator(m, 0, vis)["pending"]
		assert_bool(pd["mine"]).is_false()
		assert_bool(pd.has("options")).is_false()
		assert_str(String(pd["prompt"])).contains("is ")


func test_series_spectator_view_has_no_offers_decks_or_telemetry_ids() -> void:
	var s := Series.new()
	s.setup({"seed": 3, "best_of": 3})
	var v := s.spectator_view(1)
	for k in ["starters", "draft", "rewards", "deck", "deck_name", "tel_ids"]:
		assert_bool(v.has(k)).is_false()
	assert_bool(v["spectator"]).is_true()
	assert_int(int(v["you"])).is_equal(1)
