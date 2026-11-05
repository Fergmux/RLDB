class_name DuelControls
extends Control
## The local player's duel controls under their plate (owner feedback 2026-10-22), as forged plates
## in the action row's style (GameActionRow.ActionButton: iron face, gold-leaf rim, rivets and a
## glyph medallion), stacked, as wide as the plate above them (the longest label always fits):
## - J11 / L5 "Sacrifice Unit" (ember flame medallion): toggles sacrifice MODE (GameSacrificeMode):
##   while it is on the plate stays latched in its lit ember state reading "Stop Sacrificing", and a
##   click on a glowing unit sacrifices it at once. Enabled only while a sacrifice is legal (or the
##   mode is on); the tooltip says why it is not. The card action row never offers Sacrifice, so a
##   misclick on a card outside the mode cannot spend a unit.
## - J6 "Trap Prompts" (bell medallion, struck through when off, and a topaz state lamp): each click
##   cycles Usable -> Always -> Off. Usable (the default): asked only when one of their Traps can
##   respond (the pause shows that one can). Always: asked whenever they hold a face-down card some
##   Trap could answer from, so a pause gives nothing away. Off: never asked, their Traps stay down. The choice is the viewer's own: saved in the UI settings file (per seat in hot-seat
##   play) and sent to the authority as the seat's setting, never shown to the opponent.

## The Sacrifice Unit button was pressed (L5: it toggles sacrifice mode).
signal sacrifice_pressed
## The viewer switched their Trap response prompts on or off.
signal prompts_toggled(mode: String)

const SACRIFICE_LABEL := "Sacrifice Unit"
## L5: the latched button's label while sacrifice mode is on.
const SACRIFICE_STOP_LABEL := "Stop Sacrificing"
## L5: the tooltip of the button while the mode can start.
const SACRIFICE_TIP := "Sacrifice mode: click your units to sacrifice each for +1 AP, no confirmation. Click here again (or press Esc) to stop."
const PROMPTS_ON_LABEL := "Trap Prompts: Usable"
const PROMPTS_ALWAYS_LABEL := "Trap Prompts: Always"
const PROMPTS_OFF_LABEL := "Trap Prompts: Off"
const PROMPTS_ON_TIP := "Trap prompts: Usable. You are asked to respond only when one of your Traps can, so your opponent sees you deciding.\n\nClick to change: Usable, Always, Off."
const PROMPTS_ALWAYS_TIP := "Trap prompts: Always. You are asked whenever you hold a face-down card a Trap could answer from, even if none of yours can, so a pause gives nothing away.\n\nClick to change: Usable, Always, Off."
const PROMPTS_OFF_TIP := "Trap prompts: Off. You are never asked to respond and your Traps stay down; your opponent never sees you pause.\n\nClick to change: Usable, Always, Off."
## The order a click cycles the settings in (EffectEngine.TRAP_PROMPT_*).
const PROMPT_CYCLE := [EffectEngine.TRAP_PROMPT_ELIGIBLE, EffectEngine.TRAP_PROMPT_ALWAYS, EffectEngine.TRAP_PROMPT_OFF]
## Gap (px) under the plate and between the two plates, and their height.
const TOP_GAP := 8.0
const GAP := 7.0
const BUTTON_H := 38.0
## Narrowest the plates are drawn (px): the player plate's width, so the column reads as one.
const MIN_W := PlayerPlate.PLATE_W

## Settings section and keys of the Trap prompts choice (kept in the UI settings file).
const PREF_SECTION := "duel"
const PREF_KEY := "trap_prompts"
## Automated runs (GdUnit, -s drivers, --*-shots) keep the choice in this file instead.
const TEST_SETTINGS_PATH := "user://test_ui_duel.cfg"

var sacrifice_btn: GameActionRow.ActionButton
var prompts_btn: GameActionRow.ActionButton
var _prompts_mode: String = EffectEngine.TRAP_PROMPT_ELIGIBLE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sacrifice_btn = GameActionRow.ActionButton.new(SACRIFICE_LABEL, "sacrifice_pick")
	sacrifice_btn.pressed.connect(_on_sacrifice_pressed)
	add_child(sacrifice_btn)
	prompts_btn = GameActionRow.ActionButton.new(PROMPTS_ON_LABEL, "prompts", "on")
	prompts_btn.lamp = 1
	prompts_btn.pressed.connect(_on_prompts_pressed)
	add_child(prompts_btn)
	_layout()


## Width (px) of the plates: the longest label whole.
static func plate_width() -> float:
	return maxf(MIN_W, GameActionRow.label_fit_width([SACRIFICE_LABEL, SACRIFICE_STOP_LABEL, PROMPTS_ON_LABEL, PROMPTS_ALWAYS_LABEL, PROMPTS_OFF_LABEL]) + GameActionRow.ActionButton.LAMP_W)


## Size (px) of the whole block (both plates).
static func block_size() -> Vector2:
	return Vector2(plate_width(), BUTTON_H * 2.0 + GAP)


func _layout() -> void:
	var w := plate_width()
	var h := BUTTON_H
	size = block_size()
	custom_minimum_size = size
	for i in 2:
		var b: Control = [sacrifice_btn, prompts_btn][i]
		b.size = Vector2(w, h)
		b.custom_minimum_size = b.size
		b.position = Vector2(0, float(i) * (h + GAP))


## Tooltip of the Sacrifice Unit button while sacrifice mode is on (L5).
const SACRIFICE_ENGAGED_TIP := "Sacrifice mode is on: click a glowing unit to sacrifice it (+1 AP). Click here again (or press Esc) to stop."
var _sac_engaged := false


## Shows the Sacrifice Unit button enabled (`ok`) or not, with `tip` as its tooltip (the reason
## when it is disabled). `engaged` (L5): sacrifice mode is on: the plate stays latched in its lit
## ember state, reads "Stop Sacrificing", and a click ends the mode.
func set_sacrifice(ok: bool, tip: String, engaged: bool = false) -> void:
	_sac_engaged = engaged
	var enabled := ok or engaged
	var t := SACRIFICE_ENGAGED_TIP if engaged else tip
	sacrifice_btn.latched = engaged
	var label := SACRIFICE_STOP_LABEL if engaged else SACRIFICE_LABEL
	if sacrifice_btn.disabled == (not enabled) and sacrifice_btn.tooltip_text == t and sacrifice_btn.text == label:
		return
	sacrifice_btn.text = label
	sacrifice_btn.disabled = not enabled
	sacrifice_btn.tooltip_text = t
	sacrifice_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_FORBIDDEN   # L22
	sacrifice_btn.queue_redraw()


## True while the button shows sacrifice mode on (L5).
func sacrifice_engaged() -> bool:
	return _sac_engaged


func _on_sacrifice_pressed() -> void:
	sacrifice_pressed.emit()     # GameSacrificeMode plays sacrifice_mode_on / _off


## Shows the Trap prompts setting `mode` (EffectEngine.TRAP_PROMPT_*; no signal, no sound).
func set_prompts(mode: String) -> void:
	if not (mode in PROMPT_CYCLE):
		mode = EffectEngine.TRAP_PROMPT_ELIGIBLE
	_prompts_mode = mode
	var off := mode == EffectEngine.TRAP_PROMPT_OFF
	match mode:
		EffectEngine.TRAP_PROMPT_ALWAYS:
			prompts_btn.text = PROMPTS_ALWAYS_LABEL
			prompts_btn.tooltip_text = PROMPTS_ALWAYS_TIP
		EffectEngine.TRAP_PROMPT_OFF:
			prompts_btn.text = PROMPTS_OFF_LABEL
			prompts_btn.tooltip_text = PROMPTS_OFF_TIP
		_:
			prompts_btn.text = PROMPTS_ON_LABEL
			prompts_btn.tooltip_text = PROMPTS_ON_TIP
	prompts_btn.to_stance = "off" if off else "on"
	prompts_btn.lamp = 0 if off else 1
	prompts_btn.queue_redraw()


## The setting the button shows (EffectEngine.TRAP_PROMPT_*).
func prompts_mode() -> String:
	return _prompts_mode


## True unless the button shows prompts off.
func prompts_on() -> bool:
	return _prompts_mode != EffectEngine.TRAP_PROMPT_OFF


## The setting after `mode` in the click cycle (Usable -> Always -> Off -> Usable).
static func next_mode(mode: String) -> String:
	var i := PROMPT_CYCLE.find(mode)
	return PROMPT_CYCLE[(i + 1) % PROMPT_CYCLE.size()] if i != -1 else EffectEngine.TRAP_PROMPT_ELIGIBLE


func _on_prompts_pressed() -> void:
	var mode := next_mode(_prompts_mode)
	set_prompts(mode)
	Sfx.play("toggle_off" if mode == EffectEngine.TRAP_PROMPT_OFF else "toggle_on")
	prompts_toggled.emit(mode)


# ---------------------------------------------------------------- the saved choice

## Where the choice is saved: the UI settings file, or a test file in automated runs.
static func settings_path() -> String:
	return TEST_SETTINGS_PATH if DeckStore.PATH == DeckStore.TEST_PATH else UIStyle.SETTINGS_PATH


## The settings key of the viewer: one per profile, one per seat in hot-seat play (two people
## share the screen and each keeps their own choice).
static func pref_key(hotseat: bool, seat: int) -> String:
	return "%s_seat%d" % [PREF_KEY, seat] if hotseat else PREF_KEY


## Choices read or saved this session (settings path + key -> mode): the board asks on every
## render, so the file is read once per key.
static var _cache: Dictionary = {}


## The viewer's saved Trap prompts setting (EffectEngine.TRAP_PROMPT_*; Usable when never chosen).
## Build 0.3.8 saved a bool (true: on, read as Usable; false: off).
static func load_prompts(key: String) -> String:
	var ck := settings_path() + "#" + key
	if _cache.has(ck):
		return _cache[ck]
	var mode: String = EffectEngine.TRAP_PROMPT_ELIGIBLE
	var cf := ConfigFile.new()
	if cf.load(settings_path()) == OK:
		var v: Variant = cf.get_value(PREF_SECTION, key, EffectEngine.TRAP_PROMPT_ELIGIBLE)
		if v is bool:
			mode = EffectEngine.TRAP_PROMPT_ELIGIBLE if v else EffectEngine.TRAP_PROMPT_OFF
		elif String(v) in PROMPT_CYCLE:
			mode = String(v)
	_cache[ck] = mode
	return mode


## Saves the viewer's Trap prompts setting, keeping the file's other sections.
static func store_prompts(key: String, mode: String) -> void:
	_cache[settings_path() + "#" + key] = mode
	var cf := ConfigFile.new()
	cf.load(settings_path())
	cf.set_value(PREF_SECTION, key, mode)
	cf.save(settings_path())


## Test hook: forgets the session cache (the next load rereads the file).
static func reset_cache() -> void:
	_cache.clear()
