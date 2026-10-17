extends SceneTree
## Screenshot of the main-menu Settings panel with the "Share anonymous gameplay statistics" row
## (UI evidence). Windowed run from rldb/:
##   godot --path . -s res://src/dev/telemetry_settings_shot.gd -- --no-steam --telemetry-off
## Saves production/qa/evidence/2026-10-17-a3-telemetry/main_menu_settings.png.

const OUT := "res://../production/qa/evidence/2026-10-17-a3-telemetry"

var _main: Node
var _t := 0.0
var _stage := 0


func _initialize() -> void:
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)


func _process(delta: float) -> bool:
	_t += delta
	if _stage == 0 and _t > 1.5:
		_stage = 1
		_main.menu.pick("settings")
	elif _stage == 1 and _t > 3.5:
		_stage = 2
		var dir := ProjectSettings.globalize_path(OUT)
		DirAccess.make_dir_recursive_absolute(dir)
		var path := dir.path_join("main_menu_settings.png")
		var err := root.get_texture().get_image().save_png(path)
		print("saved %s (%d)" % [path, err])
		quit(0)
	elif _t > 15.0:
		quit(1)
	return false
