class_name DuelControls
extends Control
## The local player's duel controls under their plate (owner feedback 2026-10-22), as forged plates
## in the action row's style (GameActionRow.ActionButton: iron face, gold-leaf rim, rivets and a
## glyph medallion), stacked, as wide as the plate above them (the longest label always fits):
## - J11 "Sacrifice Unit" (ember flame medallion): starts a sacrifice (pick a unit, confirm). Enabled
##   only while a sacrifice is legal; the tooltip says why it is not. The card action row no longer
##   offers Sacrifice, so a misclick on a card cannot spend a unit.
## - J6 "Trap Prompts" toggle (bell medallion, struck through when off, and a topaz state lamp): on,
##   the player is asked to respond whenever they hold a face-down card set before this turn, so the
##   prompt (and the opponent's wait) never shows whether a Trap can respond; off, they are never
##   asked. The choice is the viewer's own: saved in the UI settings file (per seat in hot-seat
##   play) and sent to the authority as the seat's setting, never shown to the opponent.

## The Sacrifice Unit button was pressed (it is enabled: a sacrifice is legal).
signal sacrifice_pressed
## The Sacrifice Unit button was pressed while its own pick / confirmation is open (cancel it).
signal sacrifice_cancel_pressed
## The viewer switched their Trap response prompts on or off.
signal prompts_toggled(on: bool)

const SACRIFICE_LABEL := "Sacrifice Unit"
const PROMPTS_ON_LABEL := "Trap Prompts: On"
const PROMPTS_OFF_LABEL := "Trap Prompts: Off"
const PROMPTS_ON_TIP := "Trap response prompts are on: you are asked to respond whenever you hold a face-down card, even when none can respond, so a prompt never gives your hand away."
const PROMPTS_OFF_TIP := "Trap response prompts are off: you are never asked to respond, and your Traps stay down."
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
var _prompts_on := true


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
	return maxf(MIN_W, GameActionRow.label_fit_width([SACRIFICE_LABEL, PROMPTS_ON_LABEL, PROMPTS_OFF_LABEL]) + GameActionRow.ActionButton.LAMP_W)


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


## Tooltip of the Sacrifice Unit button while its pick or confirmation is open.
const SACRIFICE_ENGAGED_TIP := "Choosing the unit to sacrifice. Click again (or press Esc) to cancel."
var _sac_engaged := false


## Shows the Sacrifice Unit button enabled (`ok`) or not, with `tip` as its tooltip (the reason
## when it is disabled). `engaged`: its own pick / confirmation is open: the plate stays lit and
## a click cancels it.
func set_sacrifice(ok: bool, tip: String, engaged: bool = false) -> void:
	_sac_engaged = engaged
	var enabled := ok or engaged
	var t := SACRIFICE_ENGAGED_TIP if engaged else tip
	sacrifice_btn.set_lit(engaged)
	if sacrifice_btn.disabled == (not enabled) and sacrifice_btn.tooltip_text == t:
		return
	sacrifice_btn.disabled = not enabled
	sacrifice_btn.tooltip_text = t
	sacrifice_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	sacrifice_btn.queue_redraw()


## True while the button shows its own sacrifice flow under way.
func sacrifice_engaged() -> bool:
	return _sac_engaged


func _on_sacrifice_pressed() -> void:
	if _sac_engaged:
		sacrifice_cancel_pressed.emit()     # the cancel sound comes from the selection's cancel
		return
	Sfx.play("confirm")
	sacrifice_pressed.emit()


## Shows the Trap prompts toggle on or off (no signal, no sound).
func set_prompts(on: bool) -> void:
	_prompts_on = on
	prompts_btn.text = PROMPTS_ON_LABEL if on else PROMPTS_OFF_LABEL
	prompts_btn.to_stance = "on" if on else "off"
	prompts_btn.lamp = 1 if on else 0
	prompts_btn.tooltip_text = PROMPTS_ON_TIP if on else PROMPTS_OFF_TIP
	prompts_btn.queue_redraw()


## True while the toggle shows prompts on.
func prompts_on() -> bool:
	return _prompts_on


func _on_prompts_pressed() -> void:
	var on := not _prompts_on
	set_prompts(on)
	Sfx.play("toggle_on" if on else "toggle_off")
	prompts_toggled.emit(on)


# ---------------------------------------------------------------- the saved choice

## Where the choice is saved: the UI settings file, or a test file in automated runs.
static func settings_path() -> String:
	return TEST_SETTINGS_PATH if DeckStore.PATH == DeckStore.TEST_PATH else UIStyle.SETTINGS_PATH


## The settings key of the viewer: one per profile, one per seat in hot-seat play (two people
## share the screen and each keeps their own choice).
static func pref_key(hotseat: bool, seat: int) -> String:
	return "%s_seat%d" % [PREF_KEY, seat] if hotseat else PREF_KEY


## Choices read or saved this session (settings path + key -> bool): the board asks on every
## render, so the file is read once per key.
static var _cache: Dictionary = {}


## The viewer's saved Trap prompts choice (on when never chosen).
static func load_prompts(key: String) -> bool:
	var ck := settings_path() + "#" + key
	if _cache.has(ck):
		return _cache[ck]
	var on := true
	var cf := ConfigFile.new()
	if cf.load(settings_path()) == OK:
		on = bool(cf.get_value(PREF_SECTION, key, true))
	_cache[ck] = on
	return on


## Saves the viewer's Trap prompts choice, keeping the file's other sections.
static func store_prompts(key: String, on: bool) -> void:
	_cache[settings_path() + "#" + key] = on
	var cf := ConfigFile.new()
	cf.load(settings_path())
	cf.set_value(PREF_SECTION, key, on)
	cf.save(settings_path())


## Test hook: forgets the session cache (the next load rereads the file).
static func reset_cache() -> void:
	_cache.clear()


## The authority's setting for a toggle state (EffectEngine.TRAP_PROMPT_*).
static func mode_for(on: bool) -> String:
	return EffectEngine.TRAP_PROMPT_ALWAYS if on else EffectEngine.TRAP_PROMPT_OFF
