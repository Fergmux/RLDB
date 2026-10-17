extends GdUnitTestSuite
## Two Windows builds from one export: RLDB.exe records `playtest`, RLDB-dev.exe records `dev`.
## The export plugin (addons/rldb_export) writes the dev copy; TelemetryConfig reads the name.

const ROOT := "user://test_telemetry/dev_build"
const CopyExport := preload("res://addons/rldb_export/dev_copy_export.gd")


func after_test() -> void:
	for d in [ROOT.path_join("windows"), ROOT.path_join("windows-dev"), ROOT]:
		var dir := DirAccess.open(d)
		if dir != null:
			for f in dir.get_files():
				dir.remove(f)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(d))


func test_dev_executable_names() -> void:
	assert_bool(TelemetryConfig.is_dev_executable("C:/x/build/windows-dev/RLDB-dev.exe")).is_true()
	assert_bool(TelemetryConfig.is_dev_executable("C:/x/RLDB-DEV.EXE")).is_true()
	assert_bool(TelemetryConfig.is_dev_executable("C:/x/build/windows-dev/RLDB.exe")).is_false()
	assert_bool(TelemetryConfig.is_dev_executable("C:/x/build/windows/RLDB.exe")).is_false()
	assert_bool(TelemetryConfig.is_dev_executable("C:/x/RLDB-device.exe")).is_false()


func test_export_copy_renames_exe_and_pack_and_keeps_libraries() -> void:
	var src := ProjectSettings.globalize_path(ROOT.path_join("windows"))
	var dst := ProjectSettings.globalize_path(ROOT.path_join("windows-dev"))
	DirAccess.make_dir_recursive_absolute(src)
	for f in ["RLDB.exe", "RLDB.pck", "steam_api64.dll", "steam_appid.txt"]:
		var fa := FileAccess.open(src.path_join(f), FileAccess.WRITE)
		fa.store_string(f)
		fa.close()
	assert_int(CopyExport.copy_build(src, dst, "RLDB")).is_equal(OK)
	var got := Array(DirAccess.get_files_at(dst))
	got.sort()
	assert_array(got).is_equal(["RLDB-dev.exe", "RLDB-dev.pck", "steam_api64.dll", "steam_appid.txt"])
	assert_str(FileAccess.get_file_as_string(dst.path_join("RLDB-dev.pck"))).is_equal("RLDB.pck")
	# A second export overwrites the copy in place.
	var fa := FileAccess.open(src.path_join("RLDB.pck"), FileAccess.WRITE)
	fa.store_string("new pack")
	fa.close()
	assert_int(CopyExport.copy_build(src, dst, "RLDB")).is_equal(OK)
	assert_str(FileAccess.get_file_as_string(dst.path_join("RLDB-dev.pck"))).is_equal("new pack")
