class_name CursorSkin
extends RefCounted
## L22 (owner feedback 2026-11-05): the game's own mouse cursors, in the gilded house style, in
## place of the system cursor. A static service like UIStyle and Sfx; main calls `install()` once.
##
## Shapes. Every Control picks its Input.CursorShape (`mouse_default_cursor_shape`); this service
## gives each shape the game's image (SHAPES): the gilded arrow (ARROW), the gauntlet (POINTING_HAND,
## for anything clickable), the rune reticle (CROSS), the barred arrow (FORBIDDEN) and the
## magnifier arrow (HELP, hover to read). The text I-beam and the resize shapes stay the system's.
##
## Modes. A game state can re-skin the arrow everywhere: `set_mode(&"knife")` (sacrifice mode),
## `set_mode(&"target")` (picking a target), then `clear_mode(&"knife")`, or `clear_mode()` for all.
## While a mode is active, ARROW, POINTING_HAND and HELP all show the mode's image (MODE_SHAPES);
## FORBIDDEN, CROSS and the system shapes keep theirs. Modes stack: the most recently set active
## mode shows, and clearing it uncovers the one below (target picking inside sacrifice mode shows
## the reticle, then the knife again). `set_suspended(true)` hides every mode without forgetting it
## (a menu or modal over the board).
##
## Size. The art is baked at 32, 48 and 64 px (src/dev/cursor_bake.gd). `install()` picks the size
## from the window's UI scale and the screen's DPI (ui_scale / size_for_scale) and picks again when
## the window is resized or its DPI changes, so the cursor matches the UI at 1080p, 1440p and 4K.
##
## Setting. "Custom cursor" (Settings > Interface, default on) is saved in the UI settings file
## (TEST_SETTINGS_PATH in automated runs). Off: every custom shape is cleared at once and the system
## cursor is back; on: the images are applied again.
##
## Pointer shapes. `install()` also watches buttons entering the tree (like Sfx's click hook): a
## dropdown or check box that still has the default arrow gets the pointer, and a button that shows
## the pointer shows the plain arrow while it is disabled (and the pointer again once enabled).

## Folder of the baked images (<key>_<size>.png); the SVG sources are in DIR/src.
const DIR := "res://assets/cursors"
## Baked sizes (px, square), smallest first.
const SIZES := [32, 48, 64]
## The design viewport (project.godot window/size): UI scale 1.0.
const BASE_VIEWPORT := Vector2(1600, 1000)
## UI scale below which the smaller size is used: < 1.3 -> 32 px, < 1.75 -> 48 px, else 64 px.
const SIZE_STEPS := [1.3, 1.75]
## The art: hotspot in the 64-unit design grid of the SVG (the pixel the click lands on), and an
## optional glow baked around it.
const ART := {
	&"normal": {"hot": Vector2(3, 3)},
	&"pointer": {"hot": Vector2(23, 3)},
	&"target": {"hot": Vector2(32, 32)},
	&"target_lock": {"hot": Vector2(32, 32), "glow": Color(1.0, 0.85, 0.29, 0.75)},
	&"target_no": {"hot": Vector2(32, 32)},
	&"knife": {"hot": Vector2(4.5, 4.5)},
	&"knife_hot": {"hot": Vector2(4.5, 4.5), "glow": Color(1.0, 0.42, 0.16, 0.8)},
	&"forbidden": {"hot": Vector2(3, 3)},
	&"help": {"hot": Vector2(3, 3)},
}
## Input.CursorShape -> art, with no mode active. Shapes not listed keep the system cursor.
const SHAPES := {
	Input.CURSOR_ARROW: &"normal",
	Input.CURSOR_POINTING_HAND: &"pointer",
	Input.CURSOR_CROSS: &"target",
	Input.CURSOR_FORBIDDEN: &"forbidden",
	Input.CURSOR_HELP: &"help",
}
## The shapes a mode re-skins.
const MODE_SHAPES := [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND, Input.CURSOR_HELP]
## Mode -> the art it shows. `knife`: sacrifice mode (L5), `knife_hot` over a unit a click would
## sacrifice, `deny` over any other card. `target`: picking a target, `target_lock` over a legal
## target, `target_no` over a card that is not one. GameCursor sets these on the game screen.
const MODES := {
	&"knife": &"knife",
	&"knife_hot": &"knife_hot",
	&"deny": &"forbidden",
	&"target": &"target",
	&"target_lock": &"target_lock",
	&"target_no": &"target_no",
}
## Settings file key ([ui] custom_cursor) and the automated-run file.
const SETTINGS_KEY := "custom_cursor"
const TEST_SETTINGS_PATH := "user://test_ui_cursor.cfg"

## Custom cursor on (the setting). Read through is_enabled() so the setting is loaded first.
static var enabled: bool = true
## Tests: a settings file to use instead of settings_path()'s choice ("" = none).
static var settings_path_override: String = ""

static var _loaded := false
static var _modes: Array[StringName] = []
static var _suspended := false
static var _size: int = 32
## Shape -> "<art>@<size>" currently applied ("" = system cursor).
static var _applied: Dictionary = {}
static var _textures: Dictionary = {}
static var _hook: Hook = null


## Tree and window hooks (static functions cannot own signal connections).
class Hook extends RefCounted:
	func on_added(n: Node) -> void:
		CursorSkin.wire_button(n)

	func on_window_changed() -> void:
		CursorSkin.refresh_size()

	func on_button_draw(b: BaseButton) -> void:
		CursorSkin.sync_disabled(b)


# ---------------------------------------------------------------- setup

## Loads the setting, applies the cursors and starts following the window (size, DPI) and new
## buttons. Idempotent; main calls it at start-up.
static func install() -> void:
	load_settings()
	var tree := Engine.get_main_loop() as SceneTree
	if _hook == null and tree != null and tree.root != null:
		_hook = Hook.new()
		tree.node_added.connect(_hook.on_added)
		tree.root.size_changed.connect(_hook.on_window_changed)
		if tree.root.has_signal("dpi_changed"):
			tree.root.connect("dpi_changed", _hook.on_window_changed)
		_wire_tree(tree.root)
	_size = size_for_scale(live_scale())
	apply()


## Tests: drops every hook, mode and applied image and restores the system cursor.
static func uninstall() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if _hook != null and tree != null:
		if tree.node_added.is_connected(_hook.on_added):
			tree.node_added.disconnect(_hook.on_added)
		if tree.root != null:
			if tree.root.size_changed.is_connected(_hook.on_window_changed):
				tree.root.size_changed.disconnect(_hook.on_window_changed)
			if tree.root.has_signal("dpi_changed") and tree.root.is_connected("dpi_changed", _hook.on_window_changed):
				tree.root.disconnect("dpi_changed", _hook.on_window_changed)
	_hook = null
	_modes.clear()
	_suspended = false
	for shape in SHAPES:
		if String(_applied.get(shape, "")) != "":
			Input.set_custom_mouse_cursor(null, shape)
	_applied.clear()
	_loaded = false
	enabled = true
	_size = 32


# ---------------------------------------------------------------- the setting

## Where the setting is saved: the UI settings file, or a test file in automated runs.
static func settings_path() -> String:
	if settings_path_override != "":
		return settings_path_override
	return TEST_SETTINGS_PATH if DeckStore.PATH == DeckStore.TEST_PATH else UIStyle.SETTINGS_PATH


## Reads the setting once (later calls are no-ops). Missing: on.
static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	enabled = true
	if cf.load(settings_path()) == OK:
		enabled = bool(cf.get_value("ui", SETTINGS_KEY, true))


## True while the custom cursor is on.
static func is_enabled() -> bool:
	load_settings()
	return enabled


## Turns the custom cursor on or off, saves it (keeping the file's other settings) and applies it at
## once: off restores the system cursor for every shape.
static func set_enabled(on: bool) -> void:
	load_settings()
	enabled = on
	var cf := ConfigFile.new()
	cf.load(settings_path())
	cf.set_value("ui", SETTINGS_KEY, on)
	cf.save(settings_path())
	apply()


# ---------------------------------------------------------------- modes

## Shows mode `mode` (a MODES key) in place of the arrow, pointer and help shapes until cleared.
## Setting an active mode again changes nothing. Unknown modes are ignored.
static func set_mode(mode: StringName) -> void:
	if not MODES.has(mode) or _modes.has(mode):
		return
	_modes.append(mode)
	apply()


## Clears mode `mode`, or every mode when empty. The mode below it (if any) shows again.
static func clear_mode(mode: StringName = &"") -> void:
	if mode == &"":
		if _modes.is_empty():
			return
		_modes.clear()
	else:
		if not _modes.has(mode):
			return
		_modes.erase(mode)
	apply()


## True while `mode` is set (even when suspended or covered by a later mode).
static func has_mode(mode: StringName) -> bool:
	return _modes.has(mode)


## The mode shown now: the most recent one, or &"" with none (or while suspended).
static func active_mode() -> StringName:
	if _suspended or _modes.is_empty():
		return &""
	return _modes[_modes.size() - 1]


## Hides every mode while `on` (a menu or modal over the board) without clearing them.
static func set_suspended(on: bool) -> void:
	if _suspended == on:
		return
	_suspended = on
	apply()


## True while the modes are suspended.
static func is_suspended() -> bool:
	return _suspended


# ---------------------------------------------------------------- mapping

## The art shape `shape` shows under mode `mode` (&"" = none): the mode's art for the shapes a mode
## re-skins, else SHAPES' art; &"" for a shape that keeps the system cursor.
static func art_for(shape: int, mode: StringName = &"") -> StringName:
	if mode != &"" and MODES.has(mode) and shape in MODE_SHAPES:
		return MODES[mode]
	return SHAPES.get(shape, &"")


## The art shape `shape` shows right now (&"" when the system cursor shows, e.g. the setting is off).
static func current_art(shape: int) -> StringName:
	if not is_enabled():
		return &""
	return art_for(shape, active_mode())


## The baked size (px) for UI scale `s`.
static func size_for_scale(s: float) -> int:
	for i in SIZE_STEPS.size():
		if s < float(SIZE_STEPS[i]):
			return int(SIZES[i])
	return int(SIZES[SIZES.size() - 1])


## The cursor's UI scale: the larger of the window's content scale (the 1600x1000 design stretched
## to `window_px`) and the screen's DPI scale (`dpi` / 96), both in logical pixels (divided by
## `screen_scale`, 2.0 on a macOS Retina screen), and never below 1.
static func ui_scale(window_px: Vector2, dpi: int, screen_scale: float = 1.0) -> float:
	var ss := maxf(screen_scale, 1.0)
	var ws := 1.0
	if window_px.x > 0.0 and window_px.y > 0.0:
		ws = minf(window_px.x / BASE_VIEWPORT.x, window_px.y / BASE_VIEWPORT.y) / ss
	var ds := float(dpi) / 96.0 / ss if dpi > 0 else 1.0
	return maxf(1.0, maxf(ws, ds))


## ui_scale() of the main window on its current screen.
static func live_scale() -> float:
	if DisplayServer.get_name() == "headless":
		return 1.0
	var scr := DisplayServer.window_get_current_screen()
	return ui_scale(Vector2(DisplayServer.window_get_size()), DisplayServer.screen_get_dpi(scr), DisplayServer.screen_get_scale(scr))


## The size in use (px).
static func current_size() -> int:
	return _size


## Picks the size again (window resized, DPI changed) and re-applies when it changed.
static func refresh_size() -> void:
	var n := size_for_scale(live_scale())
	if n != _size:
		_size = n
		apply()


## Tests and the gallery: uses size `n` (one of SIZES) and re-applies.
static func force_size(n: int) -> void:
	_size = n
	apply()


## Hotspot of art `key` in the 64-unit design grid.
static func hotspot_units(key: StringName) -> Vector2:
	return ART.get(key, {}).get("hot", Vector2.ZERO)


## The hotspot pixel of a design point `units` at size `n`: the pixel the point falls in.
static func hotspot_px(units: Vector2, n: int) -> Vector2i:
	var p := units * float(n) / 64.0
	return Vector2i(floori(p.x + 0.0001), floori(p.y + 0.0001))


## How far (design units) the bake shifts the art at size `n` so the design point `units` lands on
## the centre of its hotspot pixel: the tip of the arrow is then sharp at every size.
static func snap_shift(units: Vector2, n: int) -> Vector2:
	var p := units * float(n) / 64.0
	var h := hotspot_px(units, n)
	return (Vector2(h) + Vector2(0.5, 0.5) - p) * 64.0 / float(n)


## The baked image of `key` at size `n` (null when missing).
static func texture(key: StringName, n: int) -> Texture2D:
	var k := "%s_%d" % [key, n]
	if not _textures.has(k):
		var path := "%s/%s.png" % [DIR, k]
		_textures[k] = load(path) if ResourceLoader.exists(path) else null
	return _textures[k]


# ---------------------------------------------------------------- applying

## Sets every SHAPES cursor to its current art at the current size (only the shapes that changed),
## or clears them all when the setting is off.
static func apply() -> void:
	for shape in SHAPES:
		var key := current_art(shape)
		var tag := "" if key == &"" else "%s@%d" % [key, _size]
		if String(_applied.get(shape, "")) == tag:
			continue
		var tex: Texture2D = null if key == &"" else texture(key, _size)
		if key != &"" and tex == null:
			push_warning("CursorSkin: missing %s_%d" % [key, _size])
			tag = ""
		if tex == null:
			Input.set_custom_mouse_cursor(null, shape)
		else:
			Input.set_custom_mouse_cursor(tex, shape, Vector2(hotspot_px(hotspot_units(key), _size)))
		_applied[shape] = tag


## Shape -> "<art>@<size>" now applied ("" or missing = the system cursor). Tests and drivers.
static func applied() -> Dictionary:
	return _applied.duplicate()


# ---------------------------------------------------------------- buttons

static func _wire_tree(n: Node) -> void:
	wire_button(n)
	for c in n.get_children():
		_wire_tree(c)


## Gives button `n` the pointer where it lacks one (dropdowns and check boxes left on the default
## arrow) and keeps a disabled button off the pointer. No-op for other nodes; once per button.
static func wire_button(n: Node) -> void:
	if not (n is BaseButton) or n.has_meta(&"_cursor_wired"):
		return
	var b := n as BaseButton
	b.set_meta(&"_cursor_wired", true)
	if (b is OptionButton or b is CheckBox or b is CheckButton) and b.mouse_default_cursor_shape == Control.CURSOR_ARROW:
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _hook != null:
		b.draw.connect(_hook.on_button_draw.bind(b))
	sync_disabled(b)


## A disabled button shows the arrow instead of the pointer; enabled again, the pointer. Buttons that
## chose another shape are left alone. (Disabling redraws a button, which calls this.)
static func sync_disabled(b: BaseButton) -> void:
	if not is_instance_valid(b):
		return
	if b.disabled and b.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND:
		b.mouse_default_cursor_shape = Control.CURSOR_ARROW
		b.set_meta(&"_cursor_off", true)
	elif not b.disabled and b.has_meta(&"_cursor_off"):
		b.remove_meta(&"_cursor_off")
		if b.mouse_default_cursor_shape == Control.CURSOR_ARROW:
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
