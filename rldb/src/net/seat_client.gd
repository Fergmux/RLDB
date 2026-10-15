class_name SeatClient
extends Node
## What the UI talks to: one player's seat in a series. Implementations deliver the
## authority's redacted view for this seat and forward commands to the authority.
## The UI never touches rules state directly.

signal view_changed(view: Dictionary)
signal status_changed(text: String)

var seat: int = 0
var last_view: Dictionary = {}
var label: String = ""


## Sends a command to the authority. Results arrive as a new view (or an error).
func send(cmd: Dictionary) -> void:
	push_error("SeatClient.send not implemented")


func deliver(view: Dictionary) -> void:
	last_view = view
	view_changed.emit(view)
