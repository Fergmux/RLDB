class_name BotPlayer
extends Node
## Drives one LocalHost seat with a BotBrain. It reacts to that seat's view changes, waits a
## human-readable delay (and for the board animations to finish) before every move, thinks on a
## worker thread so the screen never stutters, then submits the move like a player would.

## Emitted after each command the bot sends (dev checks and tests).
signal moved(cmd: Dictionary)

## Pause before a move (seconds); attacks and phase changes get a little longer.
const THINK_DELAY := 0.9
const ATTACK_DELAY := 1.3
const PHASE_DELAY := 0.8
const CHOICE_DELAY := 0.8
const STAGE_DELAY := 1.2
## Safety valve: a turn never takes more bot moves than this.
const MAX_MOVES_PER_TURN := 40

var host: LocalHost
var seat: int = 1
var brain: BotBrain
## The screen whose animations the bot waits for (optional).
var screen: GameScreen

var _running := false
var _turn_key := ""
var _moves_this_turn := 0
var _last_err := ""
## Consecutive refused commands; after a few the bot waits for the next view instead of retrying.
var _refusals := 0
var _thread: Thread


func start(h: LocalHost, bot_seat: int, game_screen: GameScreen = null) -> void:
	host = h
	seat = bot_seat
	screen = game_screen
	brain = BotBrain.new(seat)
	host.seats[seat].view_changed.connect(func(_v): _poke())
	host.error.connect(func(s, t): if s == seat: _last_err = t)
	_poke()


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


func _poke() -> void:
	if _running or not is_inside_tree():
		return
	_running = true
	_step.call_deferred()


func _step() -> void:
	while is_inside_tree():
		var s := host.series
		var cmd := {}
		var delay := STAGE_DELAY
		if s.stage == Series.STAGE_GAME:
			var m := s.game
			if m.winner != -1 or (m.pending.is_empty() and m.active != seat) or (not m.pending.is_empty() and int(m.pending["player"]) != seat):
				break
			var key := "%d:%d" % [s.game_no, m.turn]
			if key != _turn_key:
				_turn_key = key
				_moves_this_turn = 0
			await _wait(0.35)
			await _wait_for_animations()
			cmd = await _think(m)
			if cmd.is_empty():
				break
			if _moves_this_turn >= MAX_MOVES_PER_TURN and m.pending.is_empty():
				cmd = {"t": "next_phase"}
			delay = _delay_for(cmd, m)
		else:
			cmd = brain.series_command(s)
			if cmd.is_empty():
				break
		await _wait(delay)
		if not is_inside_tree() or host.series != s:
			break
		_last_err = ""
		host.handle(seat, cmd)
		moved.emit(cmd)
		_moves_this_turn += 1
		if _last_err != "":
			_refusals += 1
			if _refusals >= 3:
				break
			_recover()
		else:
			_refusals = 0
	_running = false


## A refused command (should not happen): answer or leave the choice simply, else move on.
func _recover() -> void:
	var m := host.series.game if host.series.stage == Series.STAGE_GAME else null
	if m == null:
		return
	if not m.pending.is_empty() and int(m.pending["player"]) == seat:
		if m.pending["options"].is_empty() and not m.pending["cancellable"]:
			return
		if m.pending["cancellable"]:
			host.handle(seat, {"t": "cancel", "id": m.pending["id"]})
		else:
			host.handle(seat, {"t": "choose", "id": m.pending["id"], "indices": range(clampi(int(m.pending["min"]), 1, m.pending["options"].size()))})
	elif m.pending.is_empty() and m.active == seat:
		host.handle(seat, {"t": "next_phase"})


func _delay_for(cmd: Dictionary, m: MatchEngine) -> float:
	match String(cmd.get("t", "")):
		"attack": return ATTACK_DELAY
		"next_phase": return PHASE_DELAY
		"choose", "cancel": return CHOICE_DELAY if m.pending.get("kind", "") != "trap_response" else ATTACK_DELAY
	return THINK_DELAY


## Runs the brain on a worker thread (look-ahead copies the match, which can take a moment). The
## thread gets its own copy, made here on the main thread, so the live match can change meanwhile.
func _think(m: MatchEngine) -> Dictionary:
	_thread = Thread.new()
	_thread.start(brain.decide.bind(m.clone_for_sim()))
	while _thread.is_alive():
		await get_tree().process_frame
	var out: Dictionary = _thread.wait_to_finish()
	_thread = null
	return out


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs * (0.5 if UIStyle.fast_anim else 1.0)).timeout


func _wait_for_animations() -> void:
	var t := 0
	while screen != null and is_instance_valid(screen) and screen.fx != null and screen.fx.busy() and t < 40:
		await get_tree().create_timer(0.1).timeout
		t += 1
