class_name Sfx
extends Node
## Presentation-only sound effects (F02-13). Never touches game state or network rules.
## Voices live on one lazily created node under the scene-tree root and play on an "SFX"
## bus created at runtime. Sounds are rate-limited so multi-effect sequences stay readable.
## Only public presentation events are mapped (positions/amounts, never card identities).

const DIR := "res://assets/audio/sfx/"
## Asset extensions tried in order (asset_path).
const EXTENSIONS: PackedStringArray = [".wav", ".ogg"]
const BUS := "SFX"
const SETTINGS_PATH := "user://audio_settings.cfg"
const NAMES: PackedStringArray = [
	"card_draw", "card_play", "card_set", "summon", "select", "confirm", "cancel", "deny",
	"attack", "impact", "damage", "heal", "destroy", "buff", "debuff", "turn", "phase",
	"notice", "victory", "defeat", "exhaust", "fuse", "ritual", "arcane", "victory_big",
	"boom", "charge", "click_primary", "click_secondary", "back", "deck_add", "deck_remove", "chat",
	# D8 / B5 / D6 (2026-10-20): the summon set pieces, the Serpents' strike, sacrifice and AP changes.
	"fusion_vortex", "fusion_impact", "ritual_choir", "ritual_impact", "arcane_shimmer", "arcane_impact",
	"card_slam", "serpent_coil", "serpent_strike", "sacrifice", "ap_gain", "ap_loss",
	# H1 WP-1 / WP-3 (design review 1.4.6): UI feedback cues and the low-HP heartbeat. A missing file
	# is silent (_stream_for returns null), so a name may be registered before its sound exists.
	"ui_hover", "panel_open", "panel_close", "tab", "toggle_on", "toggle_off", "hp_low_heartbeat",
	# H1 WP-9 (design review 1.4.6): the card hover (a paper slide), the reward reveal and pick, a
	# tutorial step done, and a toast.
	"card_hover", "reward_reveal", "reward_pick", "step_done",
	# J17 (22 Oct): the new-chat-message pop.
	"chat_pop",
	# K1 (23 Oct): the Spell / Trap spotlight cues (FxSpotlight).
	"spell_cast", "trap_spring",
	# L batch (5 Nov, design/owner-feedback-2026-11-05.md): names reserved up front so every feature
	# agent can call them; the ElevenLabs set supplies the files. Status application, one per status (L8):
	"status_rune", "status_retain", "status_reveal", "status_eternal", "status_burn", "status_pierce",
	"status_cleanse", "status_paralyse", "status_medic", "status_curse", "status_poison",
	"status_infiltrate", "status_blind", "status_nimble", "status_debilitate",
	# A Cleanse / Curse stack stopping an application, a status wearing off, Burn / Poison damage ticks.
	"status_blocked", "status_expire", "burn_tick", "poison_tick",
	# L23 Evolve: the build-up and the transformation burst.
	"evolve_charge", "evolve_burst",
	# L5 sacrifice mode, L7 targeting (the arrow arms, a target locks in).
	"sacrifice_mode_on", "sacrifice_mode_off", "target_arm", "target_lock",
	# L9 Hypnotise and other control changes, L11 Shapeshifter Loak / Mimic copying a Unit's form.
	"control_steal", "control_return", "copy_form",
	# L18 the duel hourglass flipping, the low-time tick and warning; L16 the opponent-responding notice.
	"hourglass_flip", "timer_tick", "timer_warning", "opponent_responding", "prompt_alert",
	# Card movement and battle detail.
	"card_discard", "card_return", "card_shuffle", "card_flip", "stance_attack", "stance_defense",
	"block", "miss", "zone_pick",
	# Series, draft and menus (L3, L26, L28).
	"game_start", "series_point", "draft_reveal", "draft_pick", "coin_flip", "slider_tick",
	"customise_select",
]
## F22 / F25: UI sounds. One user action makes exactly one UI sound: within one frame only the request
## with the highest priority plays (a later, higher one stops the earlier voice, a lower or equal one is
## dropped). So a button's own click and the meaningful sound its handler asks for (confirm, back, a
## deck edit) never both play, wherever either comes from.
const UI_PRIORITY := {
	"select": 0, "click_secondary": 1, "click_primary": 2,
	"tab": 2, "toggle_on": 2, "toggle_off": 2, "panel_open": 3, "panel_close": 3,
	"deck_add": 3, "deck_remove": 3, "cancel": 3, "confirm": 3, "reward_pick": 3, "reward_reveal": 4, "deny": 4, "back": 5,
	"slider_tick": 1, "customise_select": 3, "draft_pick": 3, "sacrifice_mode_on": 4, "sacrifice_mode_off": 4,
}
## Hover cue (design review 1.4.6): at most one per HOVER_MIN_MS, pitch +/- HOVER_JITTER, quiet. It
## is not a UI action sound (it never replaces or blocks a click) and skips the game-sound limiter.
const HOVER_SFX := "ui_hover"
## The card variant of the hover cue (design review #32): a soft paper slide. Shares the limiter.
const CARD_HOVER_SFX := "card_hover"
## L1: the volume-slider step cue (shares the hover limiter).
const SLIDER_SFX := "slider_tick"
const HOVER_MIN_MS := 60
const HOVER_JITTER := 0.04
const HOVER_DB := 0.0
## Button meta: "none" silences a button's hover cue.
const HOVER_META := "sfx_hover"
## Button meta overriding the automatic click: a sound name, or "none" for silence.
const BUTTON_META := "sfx"
## Button meta set by UIStyle.primary_button: the gold family (else gold-filled styles are detected).
const FAMILY_META := "sfx_family"
const DROP := 0
const PLAY := 1
const REPLACE := 2
## L1: the ElevenLabs set pieces ring for 2-4 s, so a busy turn (a set piece, its slam, statuses,
## damage and UI clicks) holds more voices at once than the short procedural set did.
const POOL_SIZE := 16
const MIN_INTERVAL_MS := 70
const BURST_MAX := 4
const BURST_WINDOW_MS := 120
const DEFAULT_VOLUME := 0.5

static var _instance: Sfx = null
static var _voices: Array[AudioStreamPlayer] = []
static var _streams: Dictionary = {}
static var _last_by_name: Dictionary = {}
static var _recent_starts: Array[int] = []
static var _volume: float = DEFAULT_VOLUME
static var _muted: bool = false
static var _loaded: bool = false
## Names of sounds actually started (bounded; dev/QA verification only).
static var debug_played: Array[String] = []
## UI sounds that won their frame, in order (bounded; also recorded when muted or headless; tests).
static var debug_ui: Array[String] = []
static var _ui_frame: int = -1
static var _ui_prio: int = -1
static var _ui_voice: AudioStreamPlayer = null
static var _hook: ButtonHook = null
static var _last_hover_ms: int = -100000
## Hover cues actually started (bounded; tests).
static var debug_hover: Array[String] = []


## Wires every BaseButton entering the tree to its click (see button_sound). Connected once.
class ButtonHook extends RefCounted:
	func on_added(n: Node) -> void:
		Sfx.wire_button(n)

	func on_pressed(b: BaseButton) -> void:
		if is_instance_valid(b) and not b.disabled:
			Sfx.play(Sfx.button_sound(b), 0.0, 0.03)

	func on_hovered(b: BaseButton) -> void:
		if is_instance_valid(b):
			Sfx.hover(b)


## Plays sound `name` at `volume_db` with random pitch jitter (+/- fraction).
## Safe no-op if muted, unknown, rate-limited, or the scene tree is not available yet.
static func play(name: String, volume_db: float = 0.0, pitch_jitter: float = 0.04) -> void:
	if name == "" or not NAMES.has(name):
		return
	if UI_PRIORITY.has(name):
		_play_ui(name, volume_db, pitch_jitter)
		return
	_start(name, volume_db, pitch_jitter)


## F22 / F25: the coalescing decision for UI sound `name` requested in process frame `frame`: PLAY (first
## UI sound of the frame), REPLACE (outranks the one already playing this frame) or DROP.
static func ui_decide(name: String, frame: int) -> int:
	if frame != _ui_frame:
		return PLAY
	return REPLACE if int(UI_PRIORITY.get(name, 0)) > _ui_prio else DROP


static func _play_ui(name: String, volume_db: float, pitch_jitter: float) -> void:
	var frame := Engine.get_process_frames()
	var d := ui_decide(name, frame)
	if d == DROP:
		return
	if d == REPLACE:
		if is_instance_valid(_ui_voice) and _ui_voice.playing:
			_ui_voice.stop()
		if not debug_ui.is_empty():
			debug_ui.pop_back()
	_ui_frame = frame
	_ui_prio = int(UI_PRIORITY[name])
	debug_ui.append(name)
	if debug_ui.size() > 200:
		debug_ui.remove_at(0)
	# The rate limiter is for bursts of game sounds; UI is already one per frame and never dropped by FX.
	_ui_voice = _start(name, volume_db, pitch_jitter, false)


## Forgets the UI sound of the current frame (tests).
static func _reset_ui() -> void:
	_ui_frame = -1
	_ui_prio = -1
	_ui_voice = null
	debug_ui.clear()


## The hover cue of button `b` (ui_hover), rate-limited to one per HOVER_MIN_MS. Silent for a
## disabled button or one whose HOVER_META is "none". Returns true when it played.
static func hover(b: BaseButton) -> bool:
	if b.disabled or String(b.get_meta(HOVER_META, "")) == "none":
		return false
	return hover_at(Time.get_ticks_msec())


## The hover rate limit at clock `now_ms` (injectable for tests): true (and records it) when the
## last hover cue is at least HOVER_MIN_MS old; the sound `cue` (ui_hover, or the card variant)
## starts when the tree is available. Every hover cue shares the one limiter.
static func hover_at(now_ms: int, cue: String = HOVER_SFX) -> bool:
	if now_ms - _last_hover_ms < HOVER_MIN_MS:
		return false
	_last_hover_ms = now_ms
	debug_hover.append(cue)
	if debug_hover.size() > 200:
		debug_hover.remove_at(0)
	_start(cue, HOVER_DB, HOVER_JITTER, false)
	return true


## The hover cue of a non-button target (a deck tile, a reward tile): ui_hover, rate-limited.
static func hover_item() -> bool:
	return hover_at(Time.get_ticks_msec())


## The hover cue of a card (hand, draft, rewards, catalogue, pile browser): the paper slide,
## rate-limited with the other hover cues so sweeping across a row never chatters.
static func hover_card() -> bool:
	return hover_at(Time.get_ticks_msec(), CARD_HOVER_SFX)


## L1: a volume slider step: the soft bead click, rate-limited with the hover cues so a fast drag
## never chatters. Returns true when it played.
static func slider_tick() -> bool:
	return hover_at(Time.get_ticks_msec(), SLIDER_SFX)


## Forgets the hover limiter (tests).
static func _reset_hover() -> void:
	_last_hover_ms = -100000
	debug_hover.clear()


## The click a button makes (F25): its BUTTON_META override, toggle_on / toggle_off for check boxes
## and toggle switches, "back" for Back / Cancel / Close / Exit / Leave, the gold "click_primary" for
## primary (gold) buttons and menu items, else "click_secondary".
static func button_sound(b: BaseButton) -> String:
	if b.has_meta(BUTTON_META):
		var v := String(b.get_meta(BUTTON_META))
		return "" if v == "none" else v
	if b is CheckBox or b is CheckButton:
		return "toggle_on" if b.button_pressed else "toggle_off"
	var text := ""
	if b is MenuItem:
		text = (b as MenuItem).label_text
	elif b is Button:
		text = (b as Button).text
	if is_back_text(text):
		return "back"
	if b is MenuItem or String(b.get_meta(FAMILY_META, "")) == "primary" or _is_gold(b):
		return "click_primary"
	return "click_secondary"


## True for the labels of navigation-back controls ("Back", "< Back", "Back to menu", "Cancel", "Close",
## "Exit tutorial", "Leave").
static func is_back_text(text: String) -> bool:
	var s := text.strip_edges().to_lower()
	while s != "" and s[0] in ["<", "‹", "←", "«", "◂", "◀", " "]:
		s = s.substr(1)
	return s.begins_with("back") or s == "cancel" or s == "close" or s.begins_with("exit") or s.begins_with("leave")


## A gold-filled button style (the yellow family) that was not made by primary_button.
static func _is_gold(b: BaseButton) -> bool:
	if not b.has_theme_stylebox_override("normal"):
		return false
	var sb := b.get_theme_stylebox("normal") as StyleBoxFlat
	if sb == null:
		return false
	var c := sb.bg_color
	return c.a > 0.5 and c.s > 0.4 and c.v > 0.55 and c.h > 0.08 and c.h < 0.17


## Connects every button that enters the scene tree from now on (and those already in it) to its
## click. Idempotent; JuicyButton, MenuItem and main call it.
static func install_button_sounds() -> void:
	if _hook != null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	_hook = ButtonHook.new()
	tree.node_added.connect(_hook.on_added)
	if tree.root != null:
		_wire_tree(tree.root)


static func _wire_tree(n: Node) -> void:
	wire_button(n)
	for c in n.get_children():
		_wire_tree(c)


## Gives button `n` its click once (no-op for other nodes or when already wired).
static func wire_button(n: Node) -> void:
	if not (n is BaseButton) or n.has_meta("_sfx_wired") or _hook == null:
		return
	n.set_meta("_sfx_wired", true)
	(n as BaseButton).pressed.connect(_hook.on_pressed.bind(n))
	(n as BaseButton).mouse_entered.connect(_hook.on_hovered.bind(n))


static func _start(name: String, volume_db: float, pitch_jitter: float, limit: bool = true) -> AudioStreamPlayer:
	if not _loaded:
		load_settings()
	if _muted:
		return null
	var stream: AudioStream = _stream_for(name)
	if stream == null:
		return null
	var voice: AudioStreamPlayer = _free_voice()
	if voice == null:
		return null
	if limit and not _allow(name, Time.get_ticks_msec()):
		return null
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	voice.play()
	debug_played.append(name)
	if debug_played.size() > 200:
		debug_played.remove_at(0)
	return voice


## Maps a public presentation event `e` (a log `fx` entry) to a sound name, or "" for silence.
## `me` is the local player index (used for victory/defeat perspective).
static func for_fx(e: Dictionary, me: int) -> String:
	match String(e.get("k", "")):
		"draw":
			return "card_draw"
		"play":
			return "card_set" if String(e.get("zone", "")) == "backrow" else "card_play"
		"summon":
			return "summon"
		"attack":
			return "attack"
		"hp":
			return "heal" if float(e.get("d", 0)) > 0.0 else "damage"
		"ap":
			var dap := float(e.get("d", 0))
			return "ap_gain" if dap > 0.0 else ("ap_loss" if dap < 0.0 else "")
		"sacrifice":
			return "sacrifice"
		"control":
			# L9: Hypnotise takes a unit, and it goes back at end of turn.
			return "control_return" if bool(e.get("back", false)) else "control_steal"
		"destroy":
			return "exhaust" if String(e.get("dest", "spent")) == "exhaust" else "destroy"
		"exhaust":
			return "exhaust"
		"discard":
			return "card_discard"   # L1: the end-of-turn discard to Spent (a count, never the cards)
		"to_hand":
			return "card_return"    # QA final: a card added to a Hand by an effect (identity redacted per seat)
		"miss":
			return "miss"           # QA final: a declared attack that does not resolve
		"stance":
			return "stance_defense" if String(e.get("to", "")) == "def" else "stance_attack"   # L1
		"stat":
			# L1: ATK / DEF changes were silent; a net gain shimmers up, a net loss sinks.
			var net := float(e.get("atk", 0)) + float(e.get("def", 0))
			return "buff" if net > 0.0 else ("debuff" if net < 0.0 else "")
		"status":
			var s: String = String(e.get("s", ""))
			return "buff" if (s == "rune" or CardDB.is_buff(s)) else "debuff"
		"turn":
			return "turn"
		"phase":
			return "phase"
		"game_over":
			return "victory" if int(e.get("winner", -1)) == me else "defeat"
	return ""


## L1: the hit sound of an attack into a unit: "block" (a shield clang) when the defender's public
## view `defender` shows Defense stance, else "impact". Units on the field are face up, so the stance
## is public; a missing view (the slot was empty or changed) falls back to "impact".
static func hit_for(defender: Variant) -> String:
	if defender is Dictionary and String((defender as Dictionary).get("stance", "")) == "def":
		return "block"
	return "impact"


## Sets master SFX volume (linear 0..1, clamped) and persists it.
static func set_volume(linear: float) -> void:
	_volume = clampf(linear, 0.0, 1.0)
	_apply_bus()
	_save()


## Returns the master SFX volume (linear 0..1).
static func get_volume() -> float:
	return _volume


## Mutes/unmutes all SFX and persists the choice.
static func set_muted(on: bool) -> void:
	_muted = on
	_apply_bus()
	_save()


## Returns whether SFX are muted.
static func is_muted() -> bool:
	return _muted


## Loads persisted settings (defaults: volume 0.5, unmuted) and applies them to the bus.
static func load_settings() -> void:
	_loaded = true
	_volume = DEFAULT_VOLUME
	_muted = false
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) == OK:
		_volume = clampf(float(cf.get_value("audio", "volume", DEFAULT_VOLUME)), 0.0, 1.0)
		_muted = bool(cf.get_value("audio", "muted", false))
	_apply_bus()


## Rate limiter with injectable clock: false if `name` repeated within MIN_INTERVAL_MS or more
## than BURST_MAX sounds started within BURST_WINDOW_MS. Records the start when allowed.
static func _allow(name: String, now_ms: int) -> bool:
	if _last_by_name.has(name) and now_ms - int(_last_by_name[name]) < MIN_INTERVAL_MS:
		return false
	while not _recent_starts.is_empty() and now_ms - _recent_starts[0] >= BURST_WINDOW_MS:
		_recent_starts.pop_front()
	if _recent_starts.size() >= BURST_MAX:
		return false
	_last_by_name[name] = now_ms
	_recent_starts.append(now_ms)
	return true


## Clears the rate limiter history (tests).
static func _reset_limiter() -> void:
	_last_by_name.clear()
	_recent_starts.clear()


static func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "volume", _volume)
	cf.set_value("audio", "muted", _muted)
	cf.save(SETTINGS_PATH)


static func _ensure_bus() -> int:
	var idx: int = AudioServer.get_bus_index(BUS)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, "Master")
	return idx


static func _apply_bus() -> void:
	var idx: int = _ensure_bus()
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(_volume, 0.0001)))
	AudioServer.set_bus_mute(idx, _muted or _volume <= 0.0)


## The asset path of sound `name`: `<name>.wav`, else `<name>.ogg` (L1: the ElevenLabs set may ship a
## long cue as Ogg Vorbis), or "" when neither exists (the sound is then silent).
static func asset_path(name: String) -> String:
	for ext in EXTENSIONS:
		var path: String = DIR + name + ext
		if ResourceLoader.exists(path):
			return path
	return ""


## True when sound `name` has an asset file (tests and QA).
static func has_asset(name: String) -> bool:
	return asset_path(name) != ""


static func _stream_for(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name] as AudioStream
	var path := asset_path(name)
	var s: AudioStream = null
	if path != "":
		s = load(path) as AudioStream
	_streams[name] = s
	return s


## Creates the voice pool now so the first sounds of a screen are not dropped.
static func warm_up() -> void:
	_free_voice()


## Returns an idle voice from the pool (creating the pool on first use), or null if all busy.
static func _free_voice() -> AudioStreamPlayer:
	if not is_instance_valid(_instance):
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null or tree.root == null:
			return null
		_ensure_bus()
		_instance = Sfx.new()
		_instance.name = "Sfx"
		_voices.clear()
		for i in POOL_SIZE:
			var p := AudioStreamPlayer.new()
			p.bus = BUS
			_instance.add_child(p)
			_voices.append(p)
		tree.root.add_child.call_deferred(_instance)
	if not _instance.is_inside_tree():
		return null   # first frame: the pool joins the tree deferred; drop this sound
	for v in _voices:
		if is_instance_valid(v) and not v.playing:
			return v
	return null
