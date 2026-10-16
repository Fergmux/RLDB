class_name LobbyListPanel
extends PanelContainer
## Public Steam lobbies found by "Browse public lobbies": a Join button per lobby and Back to
## menu. Frees itself before emitting either choice.

signal join_chosen(lobby_id: int)
signal back_chosen

const PANEL_SIZE := Vector2(520, 300)
const PANEL_POS := Vector2(540, 300)


func _init(lobbies: Array) -> void:
	add_theme_stylebox_override("panel", UIStyle.panel_style(Color(0.06, 0.07, 0.09, 0.97)))
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = PANEL_SIZE
	position = PANEL_POS
	var v := VBoxContainer.new()
	add_child(v)
	v.add_child(UIStyle.label("RLDB lobbies", 20, UIStyle.ACCENT))
	if lobbies.is_empty():
		v.add_child(UIStyle.label("No lobbies found. Ask a friend to host and invite you through Steam.", 14, UIStyle.MUTED, true))
	for l in lobbies:
		var b := UIStyle.button("Join %s's lobby (%d/2)" % [l["host"], l["members"]], 14)
		b.pressed.connect(func(): queue_free(); join_chosen.emit(l["id"]))
		v.add_child(b)
	var back := UIStyle.button("Back to menu", 13)
	back.pressed.connect(func(): queue_free(); back_chosen.emit())
	v.add_child(back)
