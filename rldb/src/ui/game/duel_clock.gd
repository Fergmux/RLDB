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
## L18: the hourglass the clock view draws (kept with the clock, so a hot-seat seat switch keeps its sand).
var glass := Glass.new()


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


## L18 (owner feedback 2026-11-05): the duel hourglass as a physical glass. `top` is the share of the
## sand in the upper bulb (in the glass's own upright frame); it drains through the neck over DRAIN_MS
## of running game time (pauses and a won game stop it). The glass turns over (flip) when the top has
## run dry for EMPTY_HOLD_MS, and at the start of a turn when the top holds less than half, so each turn
## mostly starts with sand to run. Turning it over puts the old bottom on top (top = 1 - top): the sand
## is never refilled or teleported. Pure state: the view advances it every frame and draws it.
class Glass extends RefCounted:
	## Running time (ms) a full top bulb takes to empty.
	const DRAIN_MS := 60000
	## How long (ms) an empty top waits before the glass turns over by itself.
	const EMPTY_HOLD_MS := 1500
	## Seconds a flip takes.
	const FLIP_S := 0.9
	## A new turn turns the glass over when the top holds less than this.
	const TURN_FLIP_BELOW := 0.5

	## Share of the sand in the upper bulb (0..1).
	var top := 1.0
	## Flip progress 0..1 while turning, -1 at rest.
	var flip := -1.0
	## The turn last seen.
	var turn := -1
	## Flips started so far.
	var flips := 0
	var _last_ms := -1
	var _empty_ms := 0

	## Advances to running game time `game_ms` on turn `t`, `dt` real seconds after the last call.
	## `instant` (reduced motion) completes a flip at once. Returns true when a flip starts.
	func advance(game_ms: int, t: int, dt: float, instant: bool = false) -> bool:
		var started := false
		if _last_ms < 0:
			_last_ms = game_ms
			turn = t
		if t != turn:
			turn = t
			if flip < 0.0 and top < TURN_FLIP_BELOW:
				started = _start(instant)
		if flip >= 0.0:
			flip += dt / FLIP_S
			if flip >= 1.0:
				_finish()
		else:
			var d := maxi(0, game_ms - _last_ms)
			top = maxf(0.0, top - float(d) / float(DRAIN_MS))
			if top <= 0.0:
				_empty_ms += d
				if _empty_ms >= EMPTY_HOLD_MS:
					started = _start(instant)
		_last_ms = game_ms
		return started

	## True while the glass is turning over.
	func turning() -> bool:
		return flip >= 0.0

	## The glass's rotation (radians, 0 upright): an eased half turn while flipping, with a slight settle.
	func angle() -> float:
		return 0.0 if flip < 0.0 else PI * ease_flip(flip)

	## Ease of a flip at progress `x` (0..1): a slow lift, a quick turn, a small overshoot settling back.
	static func ease_flip(x: float) -> float:
		x = clampf(x, 0.0, 1.0)
		var c2 := 1.1 * 1.525
		if x < 0.5:
			return (pow(2.0 * x, 2.0) * ((c2 + 1.0) * 2.0 * x - c2)) / 2.0
		return (pow(2.0 * x - 2.0, 2.0) * ((c2 + 1.0) * (x * 2.0 - 2.0) + c2) + 2.0) / 2.0

	func _start(instant: bool) -> bool:
		flip = 0.0
		_empty_ms = 0
		flips += 1
		if instant:
			_finish()
		return true

	func _finish() -> void:
		flip = -1.0
		top = 1.0 - top
