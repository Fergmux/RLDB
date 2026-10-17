@tool
extends EditorExportPlugin
## After every Windows export (editor or `--export-release`), copies the whole export folder to a
## sibling folder named "<folder>-dev" with the executable and pack renamed "<name>-dev". The game
## labels telemetry from an executable whose name ends in "-dev" as `dev` (TelemetryConfig), so
## build/windows/RLDB.exe records `playtest` and build/windows-dev/RLDB-dev.exe records `dev`.
## Both always come from the same export, so they can never drift apart.

const DEV_SUFFIX := "-dev"

var _path := ""


func _get_name() -> String:
	return "RLDBDevCopy"


func _export_begin(features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
	_path = path if "windows" in features and path.get_extension().to_lower() == "exe" else ""


func _export_end() -> void:
	if _path == "" or _path.get_file().get_basename().ends_with(DEV_SUFFIX):
		return
	var src_dir := ProjectSettings.globalize_path(_path).get_base_dir()
	var name := _path.get_file().get_basename()
	var dst_dir := src_dir.rstrip("/\\") + DEV_SUFFIX
	var err := copy_build(src_dir, dst_dir, name)
	if err != OK:
		push_error("RLDB export: could not write the dev copy in %s (%s)" % [dst_dir, error_string(err)])
	else:
		print("RLDB export: dev copy written to %s/%s%s.exe" % [dst_dir, name, DEV_SUFFIX])
	_path = ""


## Copies every file of `src_dir` into `dst_dir`, renaming "<name>.exe" / "<name>.pck" (and any
## other "<name>.*") to "<name>-dev.*". Old "<name>-dev.*" files are replaced.
static func copy_build(src_dir: String, dst_dir: String, name: String) -> Error:
	var err := DirAccess.make_dir_recursive_absolute(dst_dir)
	if err != OK:
		return err
	var dir := DirAccess.open(src_dir)
	if dir == null:
		return DirAccess.get_open_error()
	for f in dir.get_files():
		var out := f
		if f.get_basename() == name:
			out = name + DEV_SUFFIX + "." + f.get_extension()
		err = DirAccess.copy_absolute(src_dir.path_join(f), dst_dir.path_join(out))
		if err != OK:
			return err
	return OK
