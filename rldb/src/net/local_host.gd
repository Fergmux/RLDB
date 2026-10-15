class_name LocalHost
extends Node
## Development harness: both seats in one process (hot-seat). Not a substitute for
## Steam multiplayer; it exercises the same authority and redacted views.

signal error(seat: int, text: String)

var series: Series
var seats: Array = []


func start(overrides: Dictionary) -> void:
	series = Series.new()
	# Hot-seat players share one screen, so hidden response windows (P-27) would only add
	# privacy-screen hand-offs; they stay on for networked play.
	var cfg := overrides.duplicate()
	if not cfg.has("hidden_response_windows"):
		cfg["hidden_response_windows"] = false
	series.setup(cfg)
	for p in 2:
		var s := LocalSeat.new()
		s.seat = p
		s.host = self
		s.label = series.names[p]
		add_child(s)
		seats.append(s)
	broadcast()


func handle(p: int, cmd: Dictionary) -> void:
	var err := series.submit(p, cmd)
	if err != "":
		error.emit(p, err)
		seats[p].status_changed.emit(err)
	broadcast()


func broadcast() -> void:
	for p in 2:
		seats[p].deliver(series.view_for(p))


## The seat whose input the series is currently waiting on (for hot-seat switching).
func acting_seat() -> int:
	match series.stage:
		Series.STAGE_GAME:
			var m := series.game
			if not m.pending.is_empty():
				return m.pending["player"]
			return m.active
		Series.STAGE_FIRST:
			return series.last_loser
		Series.STAGE_DECKS:
			return 0 if not series.deck_ready[0] else 1
		Series.STAGE_REWARDS:
			return 0 if not series.rewards[0]["done"] else 1
	return 0


class LocalSeat:
	extends SeatClient
	var host: LocalHost

	func send(cmd: Dictionary) -> void:
		host.handle(seat, cmd)
