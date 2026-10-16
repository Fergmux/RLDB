class_name NetSeat
extends SeatClient
## The local player's seat on a NetSession: commands are forwarded to the session, which
## applies them directly (host) or sends them to the host (client).

## The owning session; set by NetSession right after construction.
var session: NetSession


## Sends a command through the session.
func send(cmd: Dictionary) -> void:
	session.send_from_local(cmd)
