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
var scene_data: Dictionary = {} 

var hb_timer: Timer
var connected: bool = false
var handshake_sent: bool = false
var heartbeat_timer: float = 0.0


# -------------------------
# INIT
# -------------------------
func _ready() -> void:
	print("READY")

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

	# Always detect disconnect FIRST
	if connected and status != MultiplayerPeer.CONNECTION_CONNECTED:
		handle_server_disconnect()
		return

	# Only poll if still active
	if status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return

	peer.poll()

	# CLIENT → SERVER handshake trigger
	if not handshake_sent and status == MultiplayerPeer.CONNECTION_CONNECTED:
		if status == MultiplayerPeer.CONNECTION_CONNECTED:
			if not handshake_sent:
				send_to_server({ "type": "c_handshake" })
				handshake_sent = true
		else:
			handshake_sent = false

	# heartbeat
	if connected:
		heartbeat_timer += delta
		if heartbeat_timer >= HEARTBEAT_INTERVAL:
			heartbeat_timer = 0
			send_to_server({ "type": "c_heartbeat" })

	# packet processing
	while peer.get_available_packet_count() > 0:
		if is_server:
			var client_id = peer.get_packet_peer()
			var data = peer.get_var()
			handle_server_packet(client_id, data)
		else:
			var data = peer.get_var()
			handle_client_packet(data)


func is_ready() -> bool:
	if is_server:
		return true
	return connected


# -------------------------
# NETWORK HELPERS
# -------------------------
func _send(data: Dictionary, target: int) -> void:
	if peer == null:
		return
	peer.set_target_peer(target)
	peer.put_var(data)
	peer.set_target_peer(0)


# CLIENT → SERVER
func send_to_server(data: Dictionary) -> void:
	if peer == null or is_server:
		return
	_send(data, 1)


# SERVER → ONE CLIENT
func send_to_client(client_id: int, data: Dictionary) -> void:
	_send(data, client_id)


# SERVER → ALL CLIENTS
func broadcast(data: Dictionary) -> void:
	_send(data, 0)

# SERVER → ALL CLIENTS EXCEPT ONE
func broadcast_except(excluded_id: int, data: Dictionary) -> void:
	if peer == null:
		return

	for client_id in connected_clients.keys():
		if client_id == excluded_id:
			continue

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


func handle_server_packet(client_id: int, data: Dictionary):
	match data.type:

		"c_handshake":
			print("Handshake: ", client_id)
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
			print("Client requested leave: ", client_id)
			handle_disconnect(client_id, "requested leave")

		"c_spawn_player":
			var spawn_position = SceneManager.spawn_player_random_unused()
			print("c_spawn_player", data)
			remote_players[client_id] = {
				"position": spawn_position,
				"direction": SceneManager.player.get_direction()
			}

			send_to_client(client_id, {
				"type": "s_spawn_player",
				"spawn_position": spawn_position,
			})
			
			broadcast({
				"type": "s_remote_players",
				"remote_players": remote_players,
			})


		"c_move_player":
			remote_players[client_id] = {
				"position": data.position,
				"direction": data.direction,
			}
			
			broadcast({
				"type": "s_remote_move",
				"remote_players": remote_players,
			})


func check_heartbeats():
	for client_id in connected_clients.keys().duplicate():
		connected_clients[client_id] += hb_timer.wait_time

		if connected_clients[client_id] > HEARTBEAT_TIMEOUT:
			handle_disconnect(client_id, "heartbeat timeout")


func handle_disconnect(client_id: int, reason: String) -> void:
	if connected_clients.has(client_id):
		connected_clients.erase(client_id)

	print("Client removed: ", client_id, " | Reason: ", reason)

	broadcast({
		"type": "s_remove",
		"id": client_id,
		"reason": reason
	})

func handle_server_disconnect():
	if not connected and not handshake_sent:
		return

	connected = false
	handshake_sent = false
	heartbeat_timer = 0.0

	print("Lost connection to server")

	server_lost.emit()

	# IMPORTANT: allow reconnect
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

	print("Connecting to server...")


func handle_client_packet(data: Dictionary):
	match data.type:

		"s_remove":
			print("Server removed peer: ", data.id)
		
		"s_spawn_player":
			SceneManager.player.reset_teleport_state()
			SceneManager.player.respawn(data.spawn_position)
			SceneManager.player.stop_movement()
			SceneManager.player.set_facing(Vector2(1, 0))

		"s_handshake_ack":
			connected = true
			print("Handshake confirmed!")
			if data.has("client_id"):
				local_peer_id = data.client_id
			emit_signal("server_ready")

		"s_remote_players":
			print("remote_players: ", data.remote_players)
			SceneManager.load_remote_players(data.remote_players)

		"s_remote_move":
			SceneManager.move_remote_players(data.remote_players)
