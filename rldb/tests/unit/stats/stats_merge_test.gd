extends GdUnitTestSuite
## Cross-machine statistics (C1): the merge is a CRDT (commutative, idempotent, no double count),
## old v1 files migrate without losing anything, hostile cloud data is sanitised, two Steam accounts
## on one computer never mix, and the game-time facts (C2).

const HASH_A := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const HASH_B := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"


func before_test() -> void:
	PlayerStats.clear()


func after_test() -> void:
	PlayerStats.clear()


func _row(id: String, t: int, won = true, extra: Dictionary = {}) -> Dictionary:
	var r := {"id": id, "t": t, "s": 0, "mode": "bot", "won": won, "turns": 6, "ms": 300000, "tms": 0, "tn": 0, "deck": "",
		"cards": {}, "plays": {}, "summons": 0, "spells": 0, "damage": 0, "best_hit": 0}
	r.merge(extra, true)
	return r


func _record(device: String, duel_ids: Array, picks: Dictionary, drafts: int) -> Dictionary:
	var d := PlayerStats.empty()
	d["device"] = device
	for i in duel_ids.size():
		d["duels"].append(_row(duel_ids[i], 1760000000 + i * 10))
	d["devices"][device] = {"draft_picks": picks, "drafts_completed": drafts}
	return PlayerStats.sanitize(d)


func test_merge_is_a_union_of_duels_without_double_counting() -> void:
	var a := _record("aaaa000000000001", ["00000000000000a1", "00000000000000c3"], {}, 0)
	var b := _record("bbbb000000000002", ["00000000000000b2", "00000000000000c3"], {}, 0)
	var m := PlayerStats.merge(a, b)
	assert_int(m["duels"].size()).is_equal(3)
	var ids: Array = m["duels"].map(func(r): return r["id"])
	assert_array(ids).contains_exactly_in_any_order(["00000000000000a1", "00000000000000b2", "00000000000000c3"])


func test_merge_is_commutative_and_idempotent() -> void:
	var a := _record("aaaa000000000001", ["00000000000000a1"], {"33": 2}, 1)
	var b := _record("bbbb000000000002", ["00000000000000b2"], {"33": 5, "40": 1}, 3)
	var ab := PlayerStats.merge(a, b)
	var ba := PlayerStats.merge(b, a)
	assert_str(PlayerStats.signature(ab)).is_equal(PlayerStats.signature(ba))
	assert_str(PlayerStats.signature(PlayerStats.merge(ab, ab))).is_equal(PlayerStats.signature(ab))
	assert_str(PlayerStats.signature(PlayerStats.merge(ab, b))).is_equal(PlayerStats.signature(ab))
	# This computer's own device id stays its own.
	assert_str(String(ab["device"])).is_equal("aaaa000000000001")


func test_draft_counters_sum_writers_and_merge_by_maximum() -> void:
	var a := _record("aaaa000000000001", [], {"33": 2}, 1)
	var b := _record("bbbb000000000002", [], {"33": 5}, 3)
	# An older copy of a's own counters (from the cloud) never lowers or doubles them.
	var a_old := _record("aaaa000000000001", [], {"33": 1}, 0)
	var m := PlayerStats.merge(PlayerStats.merge(a, b), a_old)
	assert_int(int(PlayerStats.draft_picks(m)["33"])).is_equal(7)
	assert_int(PlayerStats.drafts_completed(m)).is_equal(4)


func test_merge_keeps_only_the_newest_duels() -> void:
	var a := PlayerStats.empty()
	var b := PlayerStats.empty()
	for i in PlayerStats.MAX_DUELS:
		a["duels"].append(_row("%016x" % (i * 2), 1000 + i * 2))
		b["duels"].append(_row("%016x" % (i * 2 + 1), 1001 + i * 2))
	var m := PlayerStats.merge(a, b)
	assert_int(m["duels"].size()).is_equal(PlayerStats.MAX_DUELS)
	assert_int(int(m["duels"][0]["t"])).is_equal(1000 + PlayerStats.MAX_DUELS)
	assert_int(int(m["duels"][-1]["t"])).is_equal(1000 + PlayerStats.MAX_DUELS * 2 - 1)


func test_a_v1_file_migrates_with_its_duels_and_draft_counters() -> void:
	var v1 := {"version": 1, "duels": [{"t": 1760000000, "mode": "steam", "won": true, "turns": 7, "ms": 1000, "deck": "X",
		"cards": {"5": 2}, "plays": {}, "summons": 1, "spells": 0, "damage": 3, "best_hit": 3}],
		"series": [{"t": 1760000001, "mode": "steam", "won": false, "score": [1, 2]}], "draft_picks": {"33": 4}, "drafts_completed": 2}
	var f := FileAccess.open(PlayerStats.PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(v1))
	f.close()
	PlayerStats.reload()
	var d := PlayerStats.load_data()
	assert_int(d["duels"].size()).is_equal(1)
	assert_int(d["series"].size()).is_equal(1)
	assert_int(int(PlayerStats.draft_picks(d)["33"])).is_equal(4)
	assert_int(PlayerStats.drafts_completed(d)).is_equal(2)
	var id := String(d["duels"][0]["id"])
	assert_str(id).has_length(16)
	# The new ids were saved with the migration: reloading keeps them (no duplicates on sync).
	PlayerStats.reload()
	assert_str(String(PlayerStats.load_data()["duels"][0]["id"])).is_equal(id)
	assert_int(int(PlayerStats.load_data()["version"])).is_equal(2)


func test_hostile_cloud_data_is_sanitised_and_bounded() -> void:
	var bad := {"duels": [
		{"id": "00000000000000a1", "t": 5, "mode": "admin", "won": "yes", "turns": -4, "ms": 1e15, "deck": "x".repeat(500),
			"cards": {"__proto__": 1, "12": 9999999, "-3": 1, "abc": 2}, "plays": "nope"},
		{"t": 6, "mode": "bot"},   # no id: dropped from a cloud copy, never given a new one
		"not a row", 42],
		"series": {"oops": 1}, "devices": {"ZZZ": {"draft_picks": {"1": 1}}, "abcdef0123456789": {"draft_picks": {"7": 3}, "drafts_completed": 1e12}}}
	var d := PlayerStats.sanitize(bad)
	assert_int(d["duels"].size()).is_equal(1)
	var r: Dictionary = d["duels"][0]
	assert_str(String(r["mode"])).is_equal("local")
	assert_that(r["won"]).is_null()
	assert_int(int(r["turns"])).is_equal(0)
	assert_int(int(r["ms"])).is_equal(86400000)
	assert_int(String(r["deck"]).length()).is_equal(40)
	assert_dict(r["cards"]).is_equal({"12": 1000000})
	assert_dict(r["plays"]).is_empty()
	assert_array(d["series"]).is_empty()
	assert_array(d["devices"].keys()).is_equal(["abcdef0123456789"])
	assert_int(int(d["devices"]["abcdef0123456789"]["drafts_completed"])).is_equal(100000)


func test_an_unlinked_record_is_adopted_by_the_first_steam_account() -> void:
	PlayerStats.record_duel({"mode": "bot", "won": true, "turns": 5})
	PlayerStats.use_account(HASH_A)
	assert_str(String(PlayerStats.load_data()["account"])).is_equal(HASH_A)
	assert_int(PlayerStats.load_data()["duels"].size()).is_equal(1)


func test_two_steam_accounts_on_one_computer_keep_separate_records() -> void:
	PlayerStats.use_account(HASH_A)
	PlayerStats.record_duel({"mode": "bot", "won": true, "turns": 5})
	PlayerStats.use_account(HASH_B)
	assert_array(PlayerStats.load_data()["duels"]).is_empty()
	PlayerStats.record_duel({"mode": "bot", "won": false, "turns": 9})
	PlayerStats.record_duel({"mode": "bot", "won": false, "turns": 9})
	PlayerStats.use_account(HASH_A)
	assert_int(PlayerStats.load_data()["duels"].size()).is_equal(1)
	assert_bool(PlayerStats.load_data()["duels"][0]["won"]).is_true()
	PlayerStats.use_account(HASH_B)
	assert_int(PlayerStats.load_data()["duels"].size()).is_equal(2)


func test_rows_recorded_in_the_same_second_keep_their_order() -> void:
	for won in [true, false, true, true]:
		PlayerStats.record_duel({"mode": "bot", "won": won, "turns": 5})
	PlayerStats.reload()
	var w: Array = PlayerStats.load_data()["duels"].map(func(r): return r["won"])
	assert_array(w).is_equal([true, false, true, true])


func test_time_facts_give_totals_averages_and_your_average_turn() -> void:
	var duels := [_row("1", 1, true, {"ms": 600000, "tms": 240000, "tn": 8}), _row("2", 2, false, {"ms": 300000, "tms": 60000, "tn": 4}),
		_row("3", 3, true, {"ms": 0})]   # recorded before the clock existed
	var f := PlayerStats.time_facts(duels)
	assert_str(String(f[0]["label"])).is_equal("Time in duels")
	assert_str(String(f[0]["value"])).is_equal("15 min")
	assert_str(String(f[0]["detail"])).is_equal("2 timed duels")
	assert_str(String(f[1]["label"])).is_equal("Average duel")
	assert_str(String(f[1]["value"])).is_equal("7:30")
	assert_str(String(f[1]["detail"])).is_equal("longest 10:00")
	assert_str(String(f[2]["label"])).is_equal("Average turn")
	assert_str(String(f[2]["value"])).is_equal("0:25")
	assert_str(String(f[2]["detail"])).is_equal("over 12 of your turns")


func test_clock_format() -> void:
	assert_str(PlayerStats.clock(0)).is_equal("0:00")
	assert_str(PlayerStats.clock(59_999)).is_equal("0:59")
	assert_str(PlayerStats.clock(754_000)).is_equal("12:34")
	assert_str(PlayerStats.clock(3_723_000)).is_equal("1:02:03")
	assert_str(PlayerStats.clock(-5)).is_equal("0:00")


func test_observer_records_own_turn_time_with_an_injected_clock() -> void:
	var now := [1000]
	var s := Series.new()
	s.setup({"seed": 11, "best_of": 3})
	StatsObserver.attach(s, "bot", "local")
	(s.stats_observer as StatsObserver).now_ms = func() -> int: return now[0]
	s.submit(0, {"t": "pick_starter", "index": 0})
	s.submit(1, {"t": "pick_starter", "index": 1})
	var obs: StatsObserver = s.stats_observer
	# Turn 1 is seat 0's or seat 1's; drive two synthetic turn changes from the real engine.
	now[0] += 30_000
	obs.on_core_event(s.game, "turn", {"p": 1, "turn": 2})
	now[0] += 10_000
	obs.on_core_event(s.game, "turn", {"p": 0, "turn": 3})
	now[0] += 20_000
	s.game.change_hp(1, -999, " (test)")
	s._on_game_over()
	var d: Dictionary = PlayerStats.load_data()["duels"][0]
	assert_int(int(d["ms"])).is_equal(60_000)
	var first: int = s.first_player
	# Seat 0 played turn 1 if it went first (30 s) and turn 3 (20 s); seat 1's 10 s is not counted.
	assert_int(int(d["tms"])).is_equal(50_000 if first == 0 else 20_000)
	assert_int(int(d["tn"])).is_equal(2 if first == 0 else 1)


func test_network_client_counts_only_its_own_turns() -> void:
	var now := [1_000]
	StatsObserver.client = StatsObserver.new()
	StatsObserver.client.now_ms = func() -> int: return now[0]
	var tel := {"series": "s7", "game": "g1"}
	var base := {"you": 1, "tel_ids": tel, "deck": []}
	for step in [[1_000, 1, 0], [16_000, 2, 1], [41_000, 3, 0]]:
		now[0] = step[0]
		var v := base.duplicate(true)
		v.merge({"stage": "game", "history": [], "match": {"turn": step[1], "active": step[2]}})
		StatsObserver.client_view(v, "lan")
	now[0] = 51_000
	var done := base.duplicate(true)
	done.merge({"stage": "rewards", "history": [{"game": 1, "winner": 1, "turns": 3}]})
	StatsObserver.client_view(done, "lan")
	StatsObserver.client = null
	var d: Dictionary = PlayerStats.load_data()["duels"][0]
	assert_int(int(d["tms"])).is_equal(25_000)
	assert_int(int(d["tn"])).is_equal(1)
	assert_int(int(d["ms"])).is_equal(50_000)
