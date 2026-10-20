class_name DuelClock
extends RefCounted
## The duel HUD clock (owner feedback C2): elapsed time of the current game and of the current
## turn, both counting up. Pure presentation state fed from the views the screen renders; the rules
## engine never sees it (the authoritative turn and game times for statistics are measured by the
## telemetry collector and StatsObserver on the process that runs the series).
##
## One clock per game, keyed by series and game number, shared through `clocks` so a hot-seat
## seat switch (a new GameScreen attach) keeps counting. It stops while a network duel is paused
## for a disconnect and freezes when the game is won. `now_ms` is injectable for tests.

## Clocks by game key (static: every screen of this process shares them).
static var clocks: Dictionary = {}
## Games kept (oldest dropped).
const MAX_CLOCKS := 8

var now_ms: Callable = func() -> int: return Time.get_ticks_msec()
var key: String = ""
var started := 0
var turn := -1
var turn_started := 0
var paused_total := 0
var turn_paused := 0
var paused_since := -1
var frozen_at := -1


## The clock of the game in `view` (created on first sight), or null outside a game.
static func for_view(view: Dictionary, now: Callable = Callable()) -> DuelClock:
	var mv: Dictionary = view.get("match", {})
	if mv.is_empty() or String(view.get("stage", "")) != "game":
		return null
	var tel = view.get("tel_ids", {})
	var sid := String(view.get("save_id", ""))
	if sid == "" and tel is Dictionary:
		sid = String(tel.get("series", ""))
	var k := "%s#%d" % [sid, int(view.get("game_no", 0))]
	if not clocks.has(k):
		var c := DuelClock.new()
		if now.is_valid():
			c.now_ms = now
		c.key = k
		c.started = c.now_ms.call()
		c.turn_started = c.started
		clocks[k] = c
		while clocks.size() > MAX_CLOCKS:
			clocks.erase(clocks.keys()[0])
	return clocks[k]


## Follows a new view of this game: a new turn number restarts the turn clock; a disconnect
## pause stops both; the winner freezes them.
func observe(view: Dictionary) -> void:
	var mv: Dictionary = view.get("match", {})
	var now: int = now_ms.call()
	var t := int(mv.get("turn", 0))
	if t != turn:
		turn = t
		turn_started = now
		turn_paused = 0
		if paused_since != -1:
			# A pause running across the turn change: bank it for the game, restart it for the turn.
			paused_total += now - paused_since
			paused_since = now
	var net = view.get("net", {})
	var is_paused: bool = net is Dictionary and bool(net.get("paused", false))
	if is_paused and paused_since == -1:
		paused_since = now
	elif not is_paused and paused_since != -1:
		paused_total += now - paused_since
		turn_paused += now - paused_since
		paused_since = -1
	if int(mv.get("winner", -1)) != -1 and frozen_at == -1:
		frozen_at = now


func _now() -> int:
	return frozen_at if frozen_at != -1 else int(now_ms.call())


func _pause_now() -> int:
	return (_now() - paused_since) if paused_since != -1 else 0


## Elapsed game time in ms (pauses excluded).
func game_ms() -> int:
	return maxi(0, _now() - started - paused_total - _pause_now())


## Elapsed time of the current turn in ms (pauses excluded).
func turn_ms() -> int:
	return maxi(0, _now() - turn_started - turn_paused - _pause_now())


## True while the clock is stopped (pause or game over).
func stopped() -> bool:
	return paused_since != -1 or frozen_at != -1
