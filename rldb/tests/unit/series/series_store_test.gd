extends GdUnitTestSuite
## SeriesStore / Series.from_save robustness (review fixes): malformed files never hide the good
## saves, finished saves are cleaned up, and only between-game checkpoints can be restored.

const DIR := "user://test_saves_store"


func before_test() -> void:
	SeriesStore.DIR = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	for fn in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, fn])


func after_test() -> void:
	for fn in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, fn])


func _checkpoint_series(seed_value: int = 1) -> Series:
	var s := Series.new()
	s.setup({"seed": seed_value, "best_of": 3, "deck_mode": "starter"})
	s.submit(0, {"t": "pick_starter", "index": 0})
	s.submit(1, {"t": "pick_starter", "index": 1})
	s.submit(s.game.active, {"t": "concede"})            # -> rewards checkpoint
	return s


func _write(name: String, text: String) -> void:
	var f := FileAccess.open("%s/%s" % [DIR, name], FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_list_skips_malformed_files_and_keeps_valid_saves() -> void:
	SeriesStore.save(_checkpoint_series())
	_write("array.json", "[1, 2]")
	_write("number.json", "42")
	_write("partial.json", JSON.stringify({"save_id": "x", "stage": "rewards"}))
	_write("garbage.json", "{not json")
	assert_int(SeriesStore.list().size()).is_equal(1)


func test_finished_series_saves_are_deleted_by_list() -> void:
	var s := _checkpoint_series()
	s.forfeit(0, "test")
	SeriesStore.save(s)
	assert_bool(FileAccess.file_exists("%s/%s.json" % [DIR, s.save_id])).is_true()
	assert_int(SeriesStore.list().size()).is_equal(0)
	assert_bool(FileAccess.file_exists("%s/%s.json" % [DIR, s.save_id])).is_false()


func test_mid_game_save_is_refused_instead_of_crashing_later() -> void:
	var s := Series.new()
	s.setup({"seed": 2, "best_of": 3, "deck_mode": "starter"})
	s.submit(0, {"t": "pick_starter", "index": 0})
	s.submit(1, {"t": "pick_starter", "index": 1})        # stage "game": not a checkpoint
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_save()))
	assert_bool(Series.is_valid_save(d)).is_false()
	_write("%s.json" % s.save_id, JSON.stringify(d))
	assert_object(SeriesStore.load_series(s.save_id)).is_null()


func test_valid_checkpoint_round_trips() -> void:
	var s := _checkpoint_series(5)
	SeriesStore.save(s)
	var r := SeriesStore.load_series(s.save_id)
	assert_object(r).is_not_null()
	assert_str(r.stage).is_equal(Series.STAGE_REWARDS)
	assert_array(r.scores).is_equal(s.scores)


## Automated runs never default to the player's real saves (test runs once wiped real data).
func test_automated_runs_default_to_a_test_save_directory() -> void:
	assert_str(SeriesStore._default_dir()).is_not_equal(SeriesStore.PLAYER_DIR)
	assert_str(SeriesStore.dir_for(PackedStringArray(["--headless", "-s", "res://x.gd"]), PackedStringArray())).is_equal(SeriesStore.TEST_DIR)
	assert_str(SeriesStore.dir_for(PackedStringArray(["res://addons/gdUnit4/bin/GdUnitCmdTool.gd"]), PackedStringArray())).is_equal(SeriesStore.TEST_DIR)
	assert_str(SeriesStore.dir_for(PackedStringArray(["--path", "."]), PackedStringArray(["--f04-series-shots=out"]))).is_equal(SeriesStore.DEV_DIR)
	assert_str(SeriesStore.dir_for(PackedStringArray(["--path", "."]), PackedStringArray(["--no-steam"]))).is_equal(SeriesStore.PLAYER_DIR)
