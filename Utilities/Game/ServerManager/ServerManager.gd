extends Node

signal server_ready
signal server_lost

const HEARTBEAT_INTERVAL = 1.0
const HEARTBEAT_TIMEOUT = 3.0

var peer: ENetMultiplayerPeer
var is_server: bool = false
var local_peer_id: int = -1

var connected_clients: Dictionary = {}
var remote_players: Dictionary = {}

var hb_timer: Timer
var connected: bool = false
var handshake_sent: bool = false
var heartbeat_timer: float = 0.0

# 🔥 NOW SCOPED PER INSTANCE
var used_spawn_ids: Dictionary = {}
# format:
# {
#   "stage::scene": { client_id: spawn_index }
# }

var spawn_points_cache: Dictionary = {}

var spawn_radius := 64


# -------------------------
# INIT
# -------------------------
func _ready() -> void:
	is_server = "--server" in OS.get_cmdline_args()

	if is_server:
		start_server()
	else:
		start_client()

	hb_timer = Timer.new()
	hb_timer.wait_time = 0.1
	hb_timer.one_shot = false
	hb_timer.autostart = true
	hb_timer.timeout.connect(check_heartbeats)
	add_child(hb_timer)


func _process(delta: float) -> void:
	if peer == null and not is_server:
		start_client()
		return

	if peer == null:
		return

	var status := peer.get_connection_status()

	if connected and status != MultiplayerPeer.CONNECTION_CONNECTED:
		handle_server_disconnect()
		return

	if status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return

	peer.poll()

	# handshake
	if not handshake_sent and status == MultiplayerPeer.CONNECTION_CONNECTED:
		send_to_server({ "type": "c_handshake" })
		handshake_sent = true

	# heartbeat
	if connected:
		heartbeat_timer += delta
		if heartbeat_timer >= HEARTBEAT_INTERVAL:
			heartbeat_timer = 0
			send_to_server({ "type": "c_heartbeat" })

	# packets
	while peer.get_available_packet_count() > 0:
		if is_server:
			var client_id = peer.get_packet_peer()
			var data = peer.get_var()
			handle_server_packet(client_id, data)
		else:
			var data = peer.get_var()
			handle_client_packet(data)


func is_ready() -> bool:
	return true if is_server else connected


# -------------------------
# HELPERS
# -------------------------
func _send(data: Dictionary, target: int) -> void:
	if peer == null:
		return
	peer.set_target_peer(target)
	peer.put_var(data)
	peer.set_target_peer(0)


func send_to_server(data: Dictionary) -> void:
	if peer == null or is_server:
		return
	_send(data, 1)


func send_to_client(client_id: int, data: Dictionary) -> void:
	_send(data, client_id)


func broadcast(data: Dictionary) -> void:
	_send(data, 0)


func broadcast_except(excluded_id: int, data: Dictionary) -> void:
	for client_id in connected_clients.keys():
		if client_id != excluded_id:
			_send(data, client_id)


func get_local_peer_id() -> int:
	if local_peer_id != -1:
		return local_peer_id
	if peer == null:
		return -1
	return peer.get_unique_id()


# -------------------------
# SERVER
# -------------------------
func start_server(port: int = 9000) -> void:
	peer = ENetMultiplayerPeer.new()

	var err := peer.create_server(port)
	if err:
		print("Server failed:", error_string(err))
		return

	print("Server started:", port)
	is_server = true


# ==================================================
# INSTANCE HELPERS
# ==================================================
func _get_instance_key(stage: String, scene: String) -> String:
	return stage + "::" + scene


func get_spawn_points(stage: String, scene: String) -> Array:
	var key = _get_instance_key(stage, scene)

	if not spawn_points_cache.has(key):
		spawn_points_cache[key] = SceneManager.get_spawn_points_for_room(stage, scene)

	return spawn_points_cache[key]


func _free_spawn(client_id: int):
	for key in used_spawn_ids.keys():
		if used_spawn_ids[key].has(client_id):
			used_spawn_ids[key].erase(client_id)

			if used_spawn_ids[key].is_empty():
				used_spawn_ids.erase(key)


# ==================================================
# SPAWN SYSTEM
# ==================================================
func get_spawn_position(client_id: int, stage: String, scene: String) -> Vector2:
	var key = _get_instance_key(stage, scene)

	if not used_spawn_ids.has(key):
		used_spawn_ids[key] = {}

	var instance_spawns = used_spawn_ids[key]
	var points = get_spawn_points(stage, scene)

	if points.is_empty():
		return Vector2.ZERO

	var available := []

	for i in range(points.size()):
		if not instance_spawns.values().has(i):
			available.append(i)

	var chosen: int
	if available.is_empty():
		chosen = randi() % points.size()
	else:
		chosen = available.pick_random()

	instance_spawns[client_id] = chosen
	return points[chosen]


# ==================================================
# SERVER PACKETS
# ==================================================
func handle_server_packet(client_id: int, data: Dictionary):
	match data.type:

		"c_handshake":
			connected_clients[client_id] = 0.0
			remote_players[client_id] = {}

			send_to_client(client_id, {
				"type": "s_handshake_ack",
				"client_id": client_id,
			})


		"c_heartbeat":
			if connected_clients.has(client_id):
				connected_clients[client_id] = 0.0


		"c_leave":
			handle_disconnect(client_id, "requested leave")


		"c_spawn_player":
			_free_spawn(client_id)

			var stage = SceneManager.current_stage
			var scene = SceneManager.current_scene

			var spawn_position = get_spawn_position(client_id, stage, scene)

			remote_players[client_id] = {
				"position": spawn_position,
				"direction": SceneManager.player.get_direction(),
				"stage": stage,
				"scene": scene,
			}

			send_to_client(client_id, {
				"type": "s_spawn_player",
				"spawn_position": spawn_position,
			})


		"c_move_player":
			if not remote_players.has(client_id):
				return

			var data_ref = remote_players[client_id]
			var stage = data_ref.stage
			var scene = data_ref.scene

			var key = _get_instance_key(stage, scene)

			if not used_spawn_ids.has(key):
				return

			if not used_spawn_ids[key].has(client_id):
				return

			var spawn_id = used_spawn_ids[key][client_id]
			var spawn_pos = get_spawn_points(stage, scene)[spawn_id]

			if data.position.distance_to(spawn_pos) > spawn_radius:
				used_spawn_ids[key].erase(client_id)


		"c_teleport_player":
			var target_stage = data.stage if data.stage != "" else SceneManager.current_stage
			var target_scene = data.scene if data.scene != "" else SceneManager.current_scene

			_free_spawn(client_id)

			var position = SceneManager.resolve_teleport_position(
				target_stage,
				target_scene,
				data.teleport
			)

			if position == Vector2.ZERO:
				position = get_spawn_position(client_id, target_stage, target_scene)

			remote_players[client_id] = {
				"position": position,
				"direction": data.direction,
				"stage": target_stage,
				"scene": target_scene,
			}

			send_to_client(client_id, {
				"type": "s_teleport_player",
				"position": position,
				"direction": data.direction,
				"stage": target_stage,
				"scene": target_scene,
			})


# ==================================================
# HEARTBEAT / DISCONNECT
# ==================================================
func check_heartbeats():
	for client_id in connected_clients.keys().duplicate():
		connected_clients[client_id] += hb_timer.wait_time

		if connected_clients[client_id] > HEARTBEAT_TIMEOUT:
			handle_disconnect(client_id, "timeout")


func handle_disconnect(client_id: int, reason: String) -> void:
	print("Disconnect:", client_id, reason)

	_free_spawn(client_id)

	remote_players.erase(client_id)
	connected_clients.erase(client_id)

	send_to_client(client_id, {
		"type": "s_remove",
		"id": client_id
	})


func handle_server_disconnect():
	if not connected and not handshake_sent:
		return

	connected = false
	handshake_sent = false
	heartbeat_timer = 0.0

	print("Lost connection to server")
	server_lost.emit()

	if peer:
		peer.close()
		peer = null


# -------------------------
# CLIENT
# -------------------------
func start_client(ip_address: String = "127.0.0.1", port: int = 9000) -> void:
	peer = ENetMultiplayerPeer.new()

	var err := peer.create_client(ip_address, port)
	if err:
		print("Client failed:", error_string(err))
		return

	print("Connecting...")


func handle_client_packet(data: Dictionary):
	match data.type:

		"s_remove":
			print("Removed:", data.id)

		"s_spawn_player":
			SceneManager.player.reset_teleport_state()
			SceneManager.player.visible = true
			SceneManager.player.respawn(data.spawn_position)
			SceneManager.player.stop_movement()
			SceneManager.player.set_facing(Vector2(1, 0))

		"s_handshake_ack":
			connected = true
			local_peer_id = data.client_id
			server_ready.emit()

		"s_remote_players":
			SceneManager._load_remote_players(data.remote_players)

		"s_teleport_player":
			SceneManager.apply_teleport(
				data.stage,
				data.scene,
				data.position,
				data.direction
			)
