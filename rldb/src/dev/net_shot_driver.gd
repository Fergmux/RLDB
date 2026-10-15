extends Node
## Development-only: visual check of networked play. Runs an ENet host and an ENet
## client in one process (real sockets on localhost), shows each seat's real
## received view in the UI and saves screenshots of the waiting/response/paused states.
##   godot --path rldb -- --net-shots=<abs dir> --no-steam

const PORT := 24690

var main: Node
var out_dir: String
var host: NetSession
var client: NetSession
var screen: GameScreen


func run(main_node: Node, dir: String) -> void:
	main = main_node
	out_dir = dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	var hroot := Node.new()
	hroot.name = "H"
	add_child(hroot)
	var croot := Node.new()
	croot.name = "C"
	add_child(croot)
	host = NetSession.new()
	hroot.add_child(host)
	client = NetSession.new()
	croot.add_child(client)
	host.host_enet(PORT, {"seed": 7, "best_of": 3, "host_name": "Host"})
	client.join_enet("127.0.0.1", PORT)
	screen = GameScreen.new()
	main.add_child(screen)
	screen.attach(host.local_seat)
	await _until(func(): return host.remote_peer != 0)
	await _frames(5)
	await _shot("net_01_host_deck_select_opponent_joined")
	host.local_seat.send({"t": "pick_starter", "index": 1})
	client.local_seat.send({"t": "pick_starter", "index": 0})
	await _until(func(): return host.series.stage == Series.STAGE_GAME)
	var m: MatchEngine = host.series.game
	# Make it the client's battle turn with a trap waiting on the host's side.
	if m.active == 0:
		host.local_seat.send({"t": "next_phase"})
		host.local_seat.send({"t": "next_phase"})
	else:
		client.local_seat.send({"t": "next_phase"})
		client.local_seat.send({"t": "next_phase"})
		await _until(func(): return m.active == 0)
		for i in 3:
			host.local_seat.send({"t": "next_phase"})
	await _until(func(): return m.active == 1)
	var atk := _put(m, 1, 37, 0)
	_put(m, 0, 28, 0)
	_put(m, 0, 34, 1)
	var trap := m._create_instance(45, 0)
	m.cards[trap]["zone"] = "backrow"
	m.cards[trap]["slot"] = 0
	m.cards[trap]["ctl"] = 0
	m.cards[trap]["set_turn"] = m.turn - 1
	m.players[0]["backrow"][0] = trap
	host._broadcast()
	screen.attach(client.local_seat)
	await _frames(6)
	await _shot("net_02_client_view_over_network")
	client.local_seat.send({"t": "next_phase"})
	await _until(func(): return m.phase == "battle")
	client.local_seat.send({"t": "attack", "uid": atk})
	await _until(func(): return client.local_seat.last_view["match"]["pending"].get("kind", "") == "attack_target")
	var pd: Dictionary = client.local_seat.last_view["match"]["pending"]
	var idx := 0
	for o in pd["options"]:
		if o.has("ref") and o["ref"]["p"] == 0 and o["ref"]["slot"] == 0:
			idx = o["i"]
	client.local_seat.send({"t": "choose", "id": pd["id"], "indices": [idx]})
	await _until(func(): return m.pending.get("kind", "") == "trap_response")
	await _frames(4)
	await _shot("net_03_client_waiting_for_host_trap_response")
	screen.attach(host.local_seat)
	await _frames(4)
	await _shot("net_04_host_trap_response_prompt")
	client.simulate_drop()
	await _until(func(): return host.paused)
	await _frames(4)
	await _shot("net_05_host_paused_after_client_disconnect")
	await _until(func(): return not host.paused, 900)
	await _frames(6)
	await _shot("net_06_host_after_client_reconnected_prompt_intact")
	host.local_seat.send({"t": "choose", "id": m.pending["id"], "indices": [1]})
	await _until(func(): return m.pending.is_empty())
	screen.attach(client.local_seat)
	await _frames(6)
	await _shot("net_07_client_after_resolution_log")
	print("NET SHOTS DONE: ", out_dir)
	get_tree().quit()


func _put(m: MatchEngine, p: int, id: int, slot: int) -> int:
	var uid := m._create_instance(id, p)
	m.cards[uid]["zone"] = "limbo"
	m.place_unit(uid, p, slot, "atk")
	m.cards[uid]["summoned_turn"] = m.turn - 1
	return uid


func _until(cond: Callable, frames: int = 600) -> void:
	for i in frames:
		if cond.call():
			return
		await get_tree().process_frame
	push_warning("net_shot_driver: condition timed out")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)
