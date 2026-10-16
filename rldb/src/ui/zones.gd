class_name Zones
extends RefCounted
## Board zone vocabulary shared by the board renderer and the effect player.

## Board zone -> key of the player view list it renders.
const KEY := {"unit": "units", "backrow": "backrow", "power": "powers"}
## Board zone -> CardWidget kind.
const KIND := {"unit": "board", "backrow": "trap", "power": "power"}
