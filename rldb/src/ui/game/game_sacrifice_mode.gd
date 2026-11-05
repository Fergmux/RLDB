class_name GameSacrificeMode
extends RefCounted
## L5 (owner feedback 2026-11-05): sacrifice MODE. The Sacrifice button under the player plate (the
## first duel control) toggles it. While it is on, a click on one of my units that may be sacrificed
## sacrifices it at once (no pick prompt, no confirmation) and the mode stays on for the next one,
## until the same button is clicked again. It also ends by itself, cleanly, when it can no longer
## apply: Esc (or right-click on the table), a phase or turn change, a prompt taking over, nothing
## left to sacrifice, the game ending or the screen changing seat.
##
## The mode is the viewer's own presentation state: each sacrifice is the ordinary per-unit
## {"t": "sacrifice", "uid"} command (checked by the authority as always), so online play, the bot
## and the tutorial's command filter are unaffected. Outside the mode nothing on the board can
## sacrifice a unit (the card action row never offers it, J11).
##
## While on: the screen edges burn with a pulsing blood-red / ember vignette (SacrificeVignette) with
## a hint pill, the button is latched in its lit ember state, only the sacrificable units are ringed
## in ember (everything else dims, the ready marks go), and the pointer is the ritual knife (L22).
## Sounds: sacrifice_mode_on / sacrifice_mode_off; each sacrifice plays the usual sacrifice cue (its
## effect). Keyboard: Tab / Shift+Tab / arrows walk the sacrificable units, Enter or Space sacrifices
## the focused one, Esc ends the mode.

## The mode turned on (true) or off (false). L22's cursor follows it (the ritual knife).
signal changed(on: bool)

## The ember of the mode (rings, the latched button, the hint).
const EMBER := Color("ff6a2a")
## Message for a click on a card that is not one of my sacrificable units.
const NOT_A_UNIT := "Only your own units on the field can be sacrificed."

## The host screen this component works on.
var gs: GameScreen
## True while the mode is on.
var active: bool = false
## The screen-edge vignette (created on first use).
var vignette: SacrificeVignette
## Keyboard focus among the sacrificable units (-1: none).
var kb_uid: int = -1
## Units sent for sacrifice and the view shown when they were (a second click before the reply is
## ignored, so a quick double click can never send two sacrifices).
var _sent: Dictionary = {}
var _sent_view: Dictionary = {}
## "turn:phase" when the mode started: any phase or turn change ends it.
var _phase_key: String = ""


func _init(screen: GameScreen) -> void:
	gs = screen


## True while sacrifice mode is on (the query the custom cursor uses, L22).
func is_active() -> bool:
	return active


## True while the mode is on and the pointer's card `uid` would be sacrificed by a click (L22: the
## knife's "hot" state over a glowing unit; a deny state elsewhere on a card).
func would_sacrifice(uid: int) -> bool:
	return can_sacrifice(uid) and not gs.locked()


## Why the mode cannot start now ("" when it can): the reason of the plate button's action.
func start_block() -> String:
	if gs.locked():
		return "Not your move."
	for a in gs.mv.get("actions", []):
		if String(a["t"]) == "sacrifice_pick":
			return "" if bool(a["ok"]) else String(a.get("reason", "Not your move."))
	return "Not your move."


## uid -> true for my units that may be sacrificed now (the authority's per-unit actions).
func sacrificable() -> Dictionary:
	var out := {}
	if gs.mv.is_empty():
		return out
	for a in gs.mv.get("actions", []):
		if String(a["t"]) == "sacrifice" and bool(a["ok"]) and a.has("uid"):
			out[int(a["uid"])] = true
	return out


## True while the mode is on and my unit `uid` may be sacrificed now.
func can_sacrifice(uid: int) -> bool:
	return active and sacrificable().has(uid)


## The plate button: starts the mode, or ends it when it is on.
func toggle() -> void:
	if active:
		stop()
	else:
		start()


## Turns the mode on (denied with a sound when no sacrifice is possible now).
func start() -> void:
	if active:
		return
	if start_block() != "":
		Sfx.play("deny")
		return
	gs.selection.deselect()
	gs.acting_uid = -1
	if gs.details.pile_zone != "" and not gs.details.is_drafting():
		gs.details.close_pile()
	active = true
	kb_uid = -1
	_sent = {}
	_phase_key = phase_key()
	Sfx.play("sacrifice_mode_on")
	_show_vignette(true)
	gs.board.render()
	changed.emit(true)


## Turns the mode off; `sound` false for a silent end (the game ended, the screen was reset).
func stop(sound: bool = true) -> void:
	if not active:
		return
	active = false
	kb_uid = -1
	_sent = {}
	if sound:
		Sfx.play("sacrifice_mode_off")
	_show_vignette(false)
	if gs.board != null and not gs.board.slots.is_empty():
		gs.board.render()
	changed.emit(false)


## Ends the mode at once without a sound and without its fade (a new seat or game on this screen).
func reset() -> void:
	var was := active
	active = false
	kb_uid = -1
	_sent = {}
	if vignette != null and is_instance_valid(vignette):
		vignette.set_on(false, true)
	if was:
		changed.emit(false)


## "turn:phase" of the board shown.
func phase_key() -> String:
	return "%d:%s" % [int(gs.mv.get("turn", 0)), String(gs.mv.get("phase", ""))] if not gs.mv.is_empty() else ""


## Called on every board render: ends the mode once it can no longer apply. A Spell spotlight or
## the authority resolving is a pause, not an end (the board shows the old state meanwhile).
func sync() -> void:
	if not active:
		return
	var why := end_reason()
	if why == "":
		if kb_uid != -1 and not sacrificable().has(kb_uid):
			kb_uid = -1
		return
	stop(why != "game_over")


## Why the mode must end now ("" while it still applies): "game_over", "seat", "phase", "prompt",
## "paused" or "none_left".
func end_reason() -> String:
	var mv := gs.mv
	if mv.is_empty() or String(gs.view.get("stage", "")) != "game" or gs.is_spectator():
		return "seat"
	if int(mv.get("winner", -1)) != -1 or gs.game_ending():
		return "game_over"
	if int(mv.get("active", -1)) != gs.me() or phase_key() != _phase_key 			or not (String(mv.get("phase", "")) in [MatchEngine.PHASE_MAIN1, MatchEngine.PHASE_MAIN2]):
		return "phase"
	if not mv.get("pending", {}).is_empty():
		return "prompt"
	if bool(gs.view.get("net", {}).get("paused", false)):
		return "paused"
	if bool(mv.get("resolving", false)):
		return ""
	if sacrificable().is_empty():
		return "none_left"
	return ""


## A click on a card while the mode is on (GameSelection routes every card click here first).
## Returns true when the click was taken by the mode (always, while it is on).
func on_widget(w: CardWidget) -> bool:
	if not active:
		return false
	var v := w.view
	if v.is_empty() or v.get("hidden", false) or not v.has("uid"):
		return true             # an empty zone or a face-down card: nothing
	try_sacrifice(int(v["uid"]))
	return true


## Sacrifices my unit `uid` if the mode is on and it may be sacrificed now; otherwise a deny with
## the reason over the card. Returns true when the command was sent.
func try_sacrifice(uid: int) -> bool:
	if not active:
		return false
	if not is_same(_sent_view, gs.view):
		_sent = {}
	if _sent.has(uid):
		return false            # already on its way
	if gs.locked() or gs.game_ending():
		Sfx.play("deny")
		return false
	if not sacrificable().has(uid):
		Sfx.play("deny")
		gs.prompt.show_toast(reason_for(uid), UIStyle.BAD, 2.0, {"uid": uid})
		return false
	_sent[uid] = true
	_sent_view = gs.view
	if kb_uid == uid:
		kb_uid = -1
	gs.hover.clear()
	gs.send({"t": "sacrifice", "uid": uid})    # the sacrifice cue plays with its effect
	return true


## Why my card `uid` cannot be sacrificed now (the authority's reason when it is one of my units).
func reason_for(uid: int) -> String:
	for a in gs.mv.get("actions", []):
		if String(a["t"]) == "sacrifice" and int(a.get("uid", -1)) == uid and not bool(a["ok"]):
			var r := String(a.get("reason", ""))
			if r != "":
				return r
	return NOT_A_UNIT


## Tab / Shift+Tab / arrows: moves the keyboard focus to the next / previous sacrificable unit (in
## Field order).
func cycle(dir: int) -> void:
	var list: Array = []
	for k in GameBoardView.ZONE_SLOTS["unit"]:
		var it: Dictionary = gs.board.slot_item(gs.me(), "unit", k)
		var w: CardWidget = it.get("widget")
		if w != null and w.visible and not w.view.is_empty() and can_sacrifice(int(w.view.get("uid", -1))):
			list.append(int(w.view["uid"]))
	if list.is_empty():
		return
	var cur := list.find(kb_uid)
	kb_uid = list[(0 if dir > 0 else list.size() - 1) if cur == -1 else wrapi(cur + dir, 0, list.size())]
	Sfx.play("select")
	gs.board.render()


func _show_vignette(on: bool) -> void:
	if vignette == null or not is_instance_valid(vignette):
		if not on:
			return
		vignette = SacrificeVignette.new()
		gs.add_child(vignette)
	vignette.set_on(on)
