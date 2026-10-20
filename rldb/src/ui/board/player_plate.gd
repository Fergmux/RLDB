class_name PlayerPlate
extends PanelContainer
## Player info plate (match-board.md section 4; design review #17-#21, D4): the F2 gilded frame
## (FrameBox), a faceted gold turn gem and the name (TitleText SECTION), the Vial of Life (HpVial) and
## the topaz AP gems (ApGemRow). Pile chips for the local player are clickable (inspection only).
##
## The active player's plate breathes: its rim glows gold on the `breathe` loop (2.4 s) and a GOLD_HI
## highlight sweeps along its top edge every 6 s; the turn gem pulses with the rim. An inactive plate's
## rim drops to bronze 60%. While the vial is low on HP the rim turns ember (HpVial.LOW_PLATE_BORDER).
## Reduce motion: the active rim and the gem are lit, still.
##
## AP sound (D6): an AP change announced by an effect ("ap" log fx) is voiced by FxPlayer (ap_gain /
## ap_loss); any other change the gems show (a card's cost paid, the turn's AP reset) is voiced once
## by the gems themselves. GameScreen tells the plate which changes the effects announce
## (claim_ap_sound) before it renders, so one AP change never plays two AP sounds.

## HP bar scale floor: the vial is never scaled to less than this maximum.
const DEFAULT_MAX_HP := 60
## Plate width (F03-06: slimmer than before so it keeps a gap from the zones and piles); the vial
## (HpVial.VIAL_SIZE, 228 px) fills it inside the md padding.
const PLATE_W := 252.0
## Rim of an inactive plate (bronze 60%) and of the active one, with the active glow at its peak.
const RIM_IDLE := Color(0.478, 0.353, 0.188, 0.6)
const RIM_ACTIVE := Color(0.831, 0.651, 0.29, 0.95)
const ACTIVE_GLOW := Color(0.941, 0.812, 0.478, 0.34)
const ACTIVE_GLOW_PX := 11.0
## Breathing loop of the active rim and the top sweep (motion tokens `breathe` / `sweep`).
const BREATHE_PERIOD := 2.4
const SWEEP_PERIOD := 6.0
const SWEEP_DURATION := 0.9
## Volume (dB) of the gem's own AP cue (a change no effect announced; quieter than the effect cues).
const GEM_SFX_DB := -6.0


## Faceted gold gem marking the player whose turn it is (design review #18): a 12 px cut diamond
## with lit and shaded facets and a glint, set in a dark socket that shows when it is not lit.
## `glow` (0..1) is the breathing halo, driven by the plate.
class TurnGem extends Control:
	var on: bool = false:
		set(v):
			on = v
			queue_redraw()
	var glow: float = 1.0:
		set(v):
			glow = v
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(16, 20)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var w := 5.0
		var h := 6.5
		var top := c + Vector2(0, -h)
		var right := c + Vector2(w, 0)
		var bottom := c + Vector2(0, h)
		var left := c + Vector2(-w, 0)
		if not on:
			# The empty socket: an engraved diamond outline.
			draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color(0, 0, 0, 0.55), 2.5, true)
			draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color(UIStyle.BRONZE, 0.55), 1.0, true)
			return
		var halo := Color(UIStyle.GOLD_HI, 0.12 + 0.2 * glow)
		draw_circle(c, 8.5 + 1.5 * glow, Color(halo, halo.a * 0.5), true, -1.0, true)
		draw_circle(c, 6.5 + glow, halo, true, -1.0, true)
		var dark := Color("2a1a08")
		draw_colored_polygon(PackedVector2Array([top + Vector2(0, -1), right + Vector2(1, 0), bottom + Vector2(0, 1), left + Vector2(-1, 0)]), dark)
		var lit := UIStyle.GOLD_HI.lerp(Color.WHITE, 0.15 * glow)
		draw_colored_polygon(PackedVector2Array([top, left, c]), lit)
		draw_colored_polygon(PackedVector2Array([top, right, c]), UIStyle.GOLD)
		draw_colored_polygon(PackedVector2Array([left, bottom, c]), UIStyle.GOLD.darkened(0.25))
		draw_colored_polygon(PackedVector2Array([right, bottom, c]), UIStyle.BRONZE)
		draw_circle(c + Vector2(-1.4, -2.6), 1.1, Color(1, 1, 1, 0.9), true, -1.0, true)


var name_label: Label
var next_label: Label
## The Vial of Life (HpVial; named hp_bar for the effects that address it).
var hp_bar: HpVial
## The topaz AP gems (ApGemRow).
var ap_gems: ApGemRow
var turn_mark: TurnGem
## The plate's F2 frame (its rim, glow and sweep are live).
var frame: FrameBox
var _max_hp: int = DEFAULT_MAX_HP
var _active: bool = false
var _low: bool = false
var _tween: Tween
## Player shown on this plate at the last update; a different one (seat switch) snaps instead of animating.
var _who: String = ""
## Game (series id + game number) this plate last showed; a new one resets the HP reference.
var _game_key: String = ""
## The next AP change is voiced by an effect (FxPlayer); the gems stay silent for it.
var _ap_claimed: bool = false
## The gems already voiced the current AP change (one cue per change, however many gems move).
var _ap_voiced: bool = false
var _hold_gen: int = 0
## Plays a sound (name, dB); tests inject a recorder.
var play_sfx: Callable = func(n: String, db: float) -> void: Sfx.play(n, db)
## Clock time the active loop started (its sweep phase is measured from it).
var _active_t0: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(PLATE_W, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	frame = FrameBox.make(Color(UIStyle.PANEL, 0.95), "md", "md")   # D5: 12 px floor on every side
	frame.rim = RIM_IDLE
	add_theme_stylebox_override("panel", frame)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # the leather grain tiles
	var v := VBoxContainer.new()
	UIStyle.pad(v, "xs")
	add_child(v)
	var head := HBoxContainer.new()
	UIStyle.pad(head, "xs")
	v.add_child(head)
	turn_mark = TurnGem.new()
	turn_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(turn_mark)
	name_label = UIStyle.label("", 18, UIStyle.TEXT, false, true)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tt := TitleText.apply(name_label, TitleText.Tier.SECTION, 18)
	tt.show_underline = false
	TitleText.apply(name_label, TitleText.Tier.SECTION, 18)   # re-reserve without the underline
	head.add_child(name_label)
	next_label = UIStyle.label("", 13, UIStyle.MUTED)
	next_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(next_label)
	hp_bar = HpVial.new()
	hp_bar.shake_target = self
	hp_bar.low_hp_changed.connect(_on_low_hp)
	v.add_child(hp_bar)
	ap_gems = ApGemRow.new()
	ap_gems.gem_gained.connect(_on_gem.bind(true))
	ap_gems.gem_spent.connect(_on_gem.bind(false))
	v.add_child(ap_gems)
	set_process(false)


## Refreshes the plate from a player view. `mine` is the local player (pile inspection, the low-HP
## heartbeat); `active` is whose turn it is.
func update_from(pv: Dictionary, active: bool, mine: bool, label_suffix: String, next_text: String) -> void:
	name_label.text = String(pv["name"]) + label_suffix
	name_label.add_theme_color_override("font_color", UIStyle.GOLD_HI if active else UIStyle.TEXT)
	turn_mark.on = active
	# HP and AP animate from the previous values (HpVial.set_hp / ApGemRow.set_values); a different
	# player on this plate (hot-seat seat switch, new match) snaps instead.
	var who := String(pv["name"])
	var snap := who != _who
	_who = who
	hp_bar.is_local = mine
	hp_bar.my_turn = mine and active
	_max_hp = maxi(_max_hp, maxi(int(pv["hp"]), DEFAULT_MAX_HP))
	if has_meta(HP_HOLD_META):
		set_meta(HP_HOLD_META, int(pv["hp"]))   # an effect holds the vial: keep the newest real value
		hp_bar.max_hp = _max_hp
	else:
		hp_bar.set_value(int(pv["hp"]), _max_hp, snap)
	var ap := int(pv["ap"])
	_ap_voiced = false
	ap_gems.set_values(ap, int(pv.get("ap_start", ap)), int(pv.get("ap_peak", ap)), snap)
	_ap_claimed = false
	next_label.text = next_text
	if active != _active:
		_active = active
		_active_t0 = _now()
		pulse()
	_refresh_frame()


## The AP change of the coming update is announced by an effect, which plays its sound (D6): the gems
## stay silent for it. GameScreen calls it before rendering a view whose effects include an "ap" event
## for this plate's player.
func claim_ap_sound() -> void:
	_ap_claimed = true


func _on_gem(_index: int, gained: bool) -> void:
	var voice := not _ap_claimed and not _ap_voiced
	_ap_voiced = true   # the rest of this change's gems (staggered) stay silent either way
	if voice:
		play_sfx.call("ap_gain" if gained else "ap_loss", GEM_SFX_DB)


## F03-14: call before update_from with a key unique to the game being shown (series id + game
## number). A different key means a fresh game: the HP reference capacity returns to 60 and the
## next update snaps (no drain animation from last game's healed value). Same key = no change.
func begin_game(key: String) -> void:
	if key == _game_key:
		return
	_game_key = key
	reset_hp_max()
	_who = ""


## Current HP reference capacity (the bar's full scale).
func hp_capacity() -> int:
	return _max_hp


## Resets the HP bar scale to the default (new match).
func reset_hp_max() -> void:
	_max_hp = DEFAULT_MAX_HP


# ---------------------------------------------------------------- HP hold (effects)

## Meta holding the real HP while an effect keeps the vial at an earlier value (B5, the lethal blow).
const HP_HOLD_META := "fx_hp_real"


## Longest an effect may hold the vial (s): a backstop so a lost release never freezes the HP.
const HP_HOLD_MAX := 12.0


## Holds the vial at `shown` HP (the value before a blow the board already shows) until
## release_hp(); the real value is kept and later updates only refresh it. No-op while already held.
## After HP_HOLD_MAX seconds the hold snaps to the real value on its own.
func hold_hp(shown: int) -> void:
	if has_meta(HP_HOLD_META):
		return
	set_meta(HP_HOLD_META, hp_bar.hp)
	hp_bar.set_hp(shown, true)
	_hold_gen += 1
	var gen := _hold_gen
	if is_inside_tree():
		get_tree().create_timer(HP_HOLD_MAX).timeout.connect(func() -> void:
			if is_instance_valid(self) and gen == _hold_gen:
				release_hp(true))


## True while an effect holds the vial.
func hp_held() -> bool:
	return has_meta(HP_HOLD_META)


## Releases a hold: the vial animates to the real HP (the damage trail), or `snap`s to it (a click
## skipped the effect). `shatter` breaks the glass instead when the real HP is 0 (the killing blow).
func release_hp(snap: bool = false, shatter: bool = false) -> void:
	if not has_meta(HP_HOLD_META):
		return
	var real := int(get_meta(HP_HOLD_META))
	remove_meta(HP_HOLD_META)
	_hold_gen += 1
	if shatter and real <= 0 and not snap:
		hp_bar.shatter()
	else:
		hp_bar.set_hp(real, snap)


# ---------------------------------------------------------------- frame

func _on_low_hp(low: bool) -> void:
	_low = low
	_refresh_frame()


## Rim, glow and sweep of the frame now; keeps the breathing loop running only while it shows.
func _refresh_frame() -> void:
	var live := _active and not UIStyle.reduce_motion and is_inside_tree()
	set_process(live)
	_apply_frame(_now())


func _apply_frame(t: float) -> void:
	var base := HpVial.LOW_PLATE_BORDER if _low else (RIM_ACTIVE if _active else RIM_IDLE)
	if not _active:
		frame.rim = base
		frame.glow = Color(0, 0, 0, 0)
		frame.sweep = -1.0
		turn_mark.glow = 0.0
		return
	# breathe() is 1 +/- amp (exactly 1 under reduce motion): k runs 0..1 on the 2.4 s loop.
	var k := clampf((UIStyle.breathe(t - _active_t0, 1.0, UIStyle.dur(BREATHE_PERIOD)) - 0.0) / 2.0, 0.0, 1.0)
	if UIStyle.reduce_motion:
		k = 1.0
	var hi := Color(HpVial.LOW_PLATE_BORDER.lightened(0.35), 1.0) if _low else UIStyle.GOLD_HI
	frame.rim = base.lerp(hi, 0.5 * k)
	frame.glow = Color(Color(HpVial.LOW_PLATE_BORDER, 1.0) if _low else ACTIVE_GLOW, ACTIVE_GLOW.a * (0.55 + 0.45 * k))
	frame.glow_px = ACTIVE_GLOW_PX
	frame.sweep = -1.0 if UIStyle.reduce_motion else TitleText.sweep_phase(TitleText.SWEEP_LOOP, t - _active_t0 - 0.6, SWEEP_PERIOD, UIStyle.dur(SWEEP_DURATION))
	turn_mark.glow = k


func _process(_d: float) -> void:
	_apply_frame(_now())


func _now() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		_refresh_frame.call_deferred()


## Brief highlight (turn change / damage).
func pulse() -> void:
	if UIStyle.reduce_motion:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(hp_bar, "flash", 0.6, UIStyle.dur(0.08))
	_tween.tween_property(hp_bar, "flash", 0.0, UIStyle.dur(0.3))


## Global point for HP change popups: over the right end of the HP vial, never over the player
## name at the top-left of the plate.
func hp_anchor() -> Vector2:
	var r := hp_bar.get_global_rect()
	return Vector2(r.end.x - 56.0, r.get_center().y)


## Global point for AP change popups ("+1 AP"): the free space right of the gems' "AP x/y" label, so
## the floater never covers the label it changes.
func ap_anchor() -> Vector2:
	var r := ap_gems.get_global_rect()
	return Vector2(r.position.x + ap_gems.label_end_x() + float(UIStyle.sp("xl")) + 20.0, r.get_center().y)
