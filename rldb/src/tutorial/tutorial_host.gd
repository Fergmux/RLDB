class_name TutorialHost
extends LocalHost
## Authority of the guided tutorial (F03-15): a LocalHost whose series holds one premade lesson
## game (TutorialSetup), whose learner commands are filtered to the current lesson step before
## they reach the real rules engine, and whose opponent seat is driven by the lesson's fixed
## script (not the bot). Nothing is ever saved: the series' checkpoint is not connected to
## SeriesStore. Normal sessions never create this class.

## A new lesson's game was built (the screen is rebuilt for it). Emitted before its first view.
signal lesson_loaded(index: int)
## The current step changed (index into the lesson's steps).
signal step_changed(index: int)
## Every step of the current lesson is done.
signal lesson_completed(index: int)
## An off-script command was refused; `text` is the hint shown to the learner.
signal hint(text: String)

const HINT_FOLLOW := "Tutorial: follow the highlighted step."
const HINT_READ := "Tutorial: read the guidance, then click Next."
const HINT_WAIT := "Tutorial: watch the Rival's move."
const HINT_CONCEDE := "Use Exit tutorial to leave the lesson."
## A material pick whose costs miss an exact total (Arcane, F03-04): selected, required.
const HINT_TOTAL := "Tutorial: those materials total %d; the summon needs exactly %d."
const REASON_LOCKED := "Not part of this tutorial step."

## Seconds between the scripted opponent's commands (0 = at once, used by tests).
var opp_delay: float = 0.9
## Index of the current lesson.
var lesson_index: int = 0
## The current lesson (TutorialLessons format).
var lesson: Dictionary = {}
## Lesson-local card key -> uid of the current game.
var keys: Dictionary = {}
## Index of the current step; == steps.size() once the lesson is complete.
var step_index: int = 0
## Next opponent script entry.
var opp_index: int = 0
## Commands refused since the lesson started (QA).
var refused: int = 0

var _gen: int = 0
var _opp_scheduled: bool = false


## overrides: {"lesson": index}. Creates both seats and loads the lesson.
func start(overrides: Dictionary) -> void:
	for p in 2:
		var s := LocalHost.LocalSeat.new()
		s.seat = p
		s.host = self
		s.label = TutorialLessons.NAMES[p]
		add_child(s)
		seats.append(s)
	load_lesson(int(overrides.get("lesson", 0)))


## (Re)builds lesson `i` from its premade state: Restart and Next lesson both come here.
func load_lesson(i: int) -> void:
	_gen += 1
	_opp_scheduled = false
	lesson_index = clampi(i, 0, TutorialLessons.count() - 1)
	lesson = TutorialLessons.get_lesson(lesson_index)
	var built := TutorialSetup.build(lesson)
	keys = built["keys"]
	series = _make_series(built["match"])
	step_index = 0
	opp_index = 0
	refused = 0
	for s in seats:
		s.last_view = {}       # the rebuilt screen must not render the previous lesson's view
	lesson_loaded.emit(lesson_index)
	_settle()
	broadcast()


## Restarts the current lesson from its initial state.
func restart() -> void:
	load_lesson(lesson_index)


## True when there is a lesson after the current one.
func has_next_lesson() -> bool:
	return lesson_index + 1 < TutorialLessons.count()


## The current step ({} once the lesson is complete).
func current_step() -> Dictionary:
	var steps: Array = lesson.get("steps", [])
	return steps[step_index] if step_index < steps.size() else {}


## Number of steps in the current lesson.
func step_count() -> int:
	return lesson.get("steps", []).size()


## True once every step of the current lesson is done.
func is_complete() -> bool:
	return not lesson.is_empty() and step_index >= step_count()


## The current game.
func game() -> MatchEngine:
	return series.game


## Next on a read step.
func next_step() -> void:
	if current_step().get("kind", "") != "read":
		return
	_advance()
	broadcast()


## Learner and scripted-opponent commands. Only the learner's are filtered.
func handle(p: int, cmd: Dictionary) -> void:
	var t: String = String(cmd.get("t", ""))
	if t == "forfeit_series":
		return          # Return to menu from the in-game menu: nothing to record or save
	if p != TutorialLessons.PLAYER:
		_submit(p, cmd)
		return
	var why := refusal(cmd)
	if why != "":
		refused += 1
		hint.emit(why)
		seats[p].status_changed.emit(why)
		return
	if _submit(p, cmd):
		var st := current_step()
		if st.get("kind", "") == "do" and TutorialScript.holds(game(), st.get("until", {})):
			_advance()
		_settle()
	broadcast()


## Why the learner may not send `cmd` now ("" when it is the step's expected command).
func refusal(cmd: Dictionary) -> String:
	var t: String = String(cmd.get("t", ""))
	if t in ["concede", "concede_series"]:
		return HINT_CONCEDE
	var st := current_step()
	match String(st.get("kind", "")):
		"read":
			return HINT_READ
		"wait":
			return HINT_WAIT
		"do":
			for pat in st.get("expect", []):
				if TutorialScript.matches(game(), keys, pat, cmd):
					return ""
			var off := total_mismatch(cmd)
			return HINT_TOTAL % off if not off.is_empty() else HINT_FOLLOW
	return HINT_FOLLOW


## [selected total, required total] when `cmd` picks materials for an exact-total choice and
## misses the total (an Arcane over- or under-pay), else [].
func total_mismatch(cmd: Dictionary) -> Array:
	var pd: Dictionary = game().pending
	if String(cmd.get("t", "")) != "choose" or not pd.get("total_exact", false):
		return []
	var got = TutorialScript.chosen_indices(game(), cmd)
	if got == null:
		return []
	var total := 0
	for i in got:
		if int(i) >= 0 and int(i) < pd["options"].size():
			total += maxi(int(pd["options"][int(i)].get("value", 0)), 0)
	var need := int(pd["total_required"])
	return [] if total == need else [total, need]


func _submit(p: int, cmd: Dictionary) -> bool:
	var err := series.submit(p, cmd)
	if err != "":
		error.emit(p, err)
		seats[p].status_changed.emit(err)
		if p != TutorialLessons.PLAYER:
			push_warning("Tutorial opponent script command refused: %s (%s)" % [cmd, err])
		return false
	return true


## Redacted views; the learner's actions are limited to the current step's expected ones so the
## UI only offers (and highlights) what the lesson asks for.
func broadcast() -> void:
	for p in 2:
		var v := series.view_for(p)
		if p == TutorialLessons.PLAYER:
			_restrict(v)
		seats[p].deliver(v)
	_schedule_opponent()


func _restrict(v: Dictionary) -> void:
	var mv: Dictionary = v.get("match", {})
	var st := current_step()
	var pats: Array = st.get("expect", []) if st.get("kind", "") == "do" else []
	for a in mv.get("actions", []):
		if not a.get("ok", false):
			continue
		var allowed := false
		for pat in pats:
			if TutorialScript.action_matches(game(), keys, pat, a):
				allowed = true
		if not allowed:
			a["ok"] = false
			a["reason"] = REASON_LOCKED
	v["tutorial"] = {"lesson": lesson_index, "step": step_index}


func _advance() -> void:
	step_index = mini(step_index + 1, step_count())
	if is_complete():
		lesson_completed.emit(lesson_index)
	else:
		step_changed.emit(step_index)


## Ends wait steps whose condition already holds.
func _settle() -> void:
	while not is_complete():
		var st := current_step()
		if st.get("kind", "") != "wait" or not TutorialScript.holds(game(), st.get("until", {})):
			return
		_advance()


# ---------------------------------------------------------------- scripted opponent

## True when the opponent seat must act now.
func opponent_must_act() -> bool:
	var m := game()
	if m == null or m.winner != -1:
		return false
	var opp := TutorialLessons.OPPONENT
	if not m.pending.is_empty():
		return int(m.pending["player"]) == opp
	return m.active == opp and m.stack.is_empty()


func _schedule_opponent() -> void:
	if not opponent_must_act() or _opp_scheduled:
		return
	if opp_delay <= 0.0 or not is_inside_tree():
		_run_opponent_now()
		return
	_opp_scheduled = true
	var gen := _gen
	get_tree().create_timer(opp_delay).timeout.connect(func():
		if gen != _gen:
			return
		_opp_scheduled = false
		if opponent_must_act():
			opponent_step()
			_settle()
			broadcast())


func _run_opponent_now() -> void:
	var guard := 0
	while opponent_must_act() and guard < 64:
		guard += 1
		opponent_step()
	_settle()
	for p in 2:
		var v := series.view_for(p)
		if p == TutorialLessons.PLAYER:
			_restrict(v)
		seats[p].deliver(v)


## Plays the opponent's next scripted command. When the script is exhausted (or a command does
## not apply), the opponent passes: a pending choice gets its "Skip"/first option, otherwise it
## advances the phase, so a lesson can never stall on the opponent.
func opponent_step() -> void:
	var m := game()
	var opp := TutorialLessons.OPPONENT
	var script: Array = lesson.get("opponent", [])
	while opp_index < script.size():
		var cmd := TutorialScript.resolve(m, keys, script[opp_index])
		opp_index += 1
		if cmd.is_empty():
			push_warning("Tutorial opponent script entry %d does not apply here." % (opp_index - 1))
			continue
		if _submit(opp, cmd):
			return
	if not m.pending.is_empty():
		var pass_i := TutorialScript.option_index(m, keys, {"label": EffectEngine.TRAP_SKIP})   # D13: one window only
		_submit(opp, {"t": "choose", "id": int(m.pending["id"]), "indices": [maxi(pass_i, 0)]})
	else:
		_submit(opp, {"t": "next_phase"})


# ---------------------------------------------------------------- series

func _make_series(m: MatchEngine) -> Series:
	var s := Series.new()
	s.cfg = Series.load_mode_config()
	s.cfg.merge({"best_of": 1, "deck_mode": "starter", "mode": "tutorial"}, true)
	s.names = TutorialLessons.NAMES.duplicate()
	s.stage = Series.STAGE_GAME
	s.deck_ready = [true, true]
	s.deck_names = ["Tutorial", "Tutorial"]
	s.game_no = 1
	s.first_player = m.first_turn_player
	s.save_id = "tutorial"
	s.game = m
	s.series_log = ["Tutorial: %s" % lesson["title"]]
	return s
