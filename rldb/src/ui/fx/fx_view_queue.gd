class_name FxViewQueue
extends RefCounted
## L4 (owner feedback 2026-11-05): "attacking with a unit again quickly after attacking with a unit
## cancels the first animation, we should queue them instead over cancelling/overwriting, this should
## be the case for all animations".
##
## The views (state snapshots with their new log events) that arrive while an earlier view's effects
## still play wait here, in arrival order, and GameScreen shows each one (renders it and plays its
## effects) only once the effects before it have played out. The board therefore never runs ahead of
## what has been animated, and no effect is cut short by the next one.
##
## Rules (pure, so tests can drive them):
## - First in, first out. Nothing is dropped while at most MAX_WAITING views wait.
## - Catch-up: a batch that starts with `n` views still waiting behind it plays speed_for(n) times
##   faster: +SPEED_STEP per waiting view, at most MAX_SPEED (1 behind: x1.25, 2: x1.5, 4 or more: x2).
##   A killing blow is never hurried (FxPlayer).
## - Overflow: beyond MAX_WAITING (a reconnect burst, a long chain of instant plays) the oldest waiting
##   views are shown at once without their effects, so the board never falls far behind.
## - A view of another game (or a reattached seat) is not queued: whatever still waits is shown at once
##   (GameScreen); clear() drops everything.

## Views that may wait before the oldest are shown without their effects.
const MAX_WAITING := 6
## Extra playback speed per waiting view, and the cap.
const SPEED_STEP := 0.25
const MAX_SPEED := 2.0

var _items: Array = []


## Appends a view (it is shown after everything already waiting).
func push(v: Dictionary) -> void:
	_items.append(v)


## Removes and returns the oldest waiting view ({} when none).
func pop() -> Dictionary:
	if _items.is_empty():
		return {}
	return _items.pop_front()


## Views waiting.
func size() -> int:
	return _items.size()


## True when nothing waits.
func is_empty() -> bool:
	return _items.is_empty()


## Drops every waiting view.
func clear() -> void:
	_items.clear()


## The oldest views over MAX_WAITING, removed from the queue, to be shown at once (oldest first).
func take_overflow() -> Array:
	var out := []
	while _items.size() > MAX_WAITING:
		out.append(_items.pop_front())
	return out


## The playback speed of a batch that starts with `waiting` views queued behind it.
static func speed_for(waiting: int) -> float:
	return minf(1.0 + SPEED_STEP * float(maxi(waiting, 0)), MAX_SPEED)
