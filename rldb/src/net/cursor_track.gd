class_name CursorTrack
extends RefCounted
## A2: a watched player's mouse cursor on a spectator's screen. Samples arrive about SEND_HZ times a
## second (unreliable, ordered) in normalised board space; the spectator draws the position as it
## was RENDER_DELAY_MS ago, interpolated between the two samples around that moment, so the motion
## is smooth despite network jitter. A track with no sample for HIDE_AFTER_MS hides.
##
## Board space: (0, 0) is the top-left corner of the unit block (the 3 x 4 grid of unit zones plus
## the Trap/Spell rows), (1, 1) its bottom-right; the board is drawn at a fixed size in every window,
## so the same point lies over the same zone for the player and the spectator. Points beyond the
## block (piles, Powers, the hand) are outside 0..1 and are kept within LIMIT.

## Rate the player's screen sends at (the host relays at most MAX_RELAY_HZ per player).
const SEND_HZ := 18.0
const MAX_RELAY_HZ := 30.0
## Interpolation delay: a little over two send intervals, so one lost sample is bridged.
const RENDER_DELAY_MS := 120
const HIDE_AFTER_MS := 1500
## Samples kept (about one second).
const KEEP := 24
## Normalised coordinates are clamped to -LIMIT .. 1 + LIMIT; anything else means "off the board".
const LIMIT := 1.6

var _samples: Array = []   # [{"t": msec, "p": Vector2}]


## True when `p` is a usable normalised board position (finite and within the limits).
static func valid(p: Vector2) -> bool:
	return is_finite(p.x) and is_finite(p.y) and p.x >= -LIMIT and p.x <= 1.0 + LIMIT and p.y >= -LIMIT and p.y <= 1.0 + LIMIT


## Adds the sample `p` received at `t_ms` (invalid points are ignored).
func push(p: Vector2, t_ms: int) -> void:
	if not valid(p):
		return
	if not _samples.is_empty() and t_ms < int(_samples[-1]["t"]):
		t_ms = int(_samples[-1]["t"])
	_samples.append({"t": t_ms, "p": p})
	if _samples.size() > KEEP:
		_samples.pop_front()


## Forgets every sample (the watched seat changed).
func clear() -> void:
	_samples.clear()


## True when a position should be drawn at `now_ms`.
func visible_at(now_ms: int) -> bool:
	return not _samples.is_empty() and now_ms - int(_samples[-1]["t"]) < HIDE_AFTER_MS


## Interpolated position at `now_ms` (the position RENDER_DELAY_MS earlier); Vector2.ZERO when empty.
func sample(now_ms: int) -> Vector2:
	if _samples.is_empty():
		return Vector2.ZERO
	var t := now_ms - RENDER_DELAY_MS
	if t <= int(_samples[0]["t"]):
		return _samples[0]["p"]
	for i in range(_samples.size() - 1, 0, -1):
		var a: Dictionary = _samples[i - 1]
		var b: Dictionary = _samples[i]
		if t >= int(a["t"]):
			if t >= int(b["t"]):
				return b["p"]
			var span := float(int(b["t"]) - int(a["t"]))
			var k := 0.0 if span <= 0.0 else (t - int(a["t"])) / span
			return (a["p"] as Vector2).lerp(b["p"], k)
	return _samples[-1]["p"]
