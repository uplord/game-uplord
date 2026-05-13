extends Node

signal server_ready
signal server_lost

var PacketManagerScript = preload("PacketManager.gd")
var InstanceManagerScript = preload("InstanceManager.gd")
var DebugLoggerScript = preload("res://Utilities/Logger.gd")

# Server configuration constants
const HEARTBEAT_INTERVAL = 1.0
const HEARTBEAT_TIMEOUT = 3.0
const SPAWN_RADIUS = 64
const MAX_INSTANCES_PER_STAGE = 10
const INSTANCE_PLAYER_LIMIT = 3
const DEFAULT_PORT = 9000
const DEFAULT_SERVER_IP = "127.0.0.1"

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
var instance_population := {}

var spawn_points_cache: Dictionary = {}
var spawn_radius := 64

var packet_manager: Node
var logger: Node
var instance_manager: Node

# Reconnect tracking
var reconnect_attempts: Dictionary = {}
var max_reconnect_attempts: int = 3
var reconnect_delay: float = 2.0


# -------------------------
# INIT
# -------------------------
func _ready() -> void:
	# Initialize logger
	logger = DebugLoggerScript.new()
	add_child(logger)
	
	is_server = "--server" in OS.get_cmdline_args()

	if is_server:
		logger.info("Starting server...")
		start_server()
	else:
		logger.info("Starting client...")
		start_client()

	hb_timer = Timer.new()
	hb_timer.wait_time = 0.1
	hb_timer.one_shot = false
	hb_timer.autostart = true
	hb_timer.timeout.connect(check_heartbeats)
	add_child(hb_timer)

	# Initialize instance manager
	instance_manager = InstanceManagerScript.new()
	instance_manager.setup(self, logger)
	add_child(instance_manager)

	# Initialize packet manager
	packet_manager = PacketManagerScript.new()
	packet_manager.server_manager = self
	packet_manager.logger = logger
	add_child(packet_manager)


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
			packet_manager.handle_server_packet(client_id, data)
		else:
			var data = peer.get_var()
			packet_manager.handle_client_packet(data)


func is_ready() -> bool:
	return true if is_server else connected


# -------------------------
# HELPERS
# -------------------------
func _send(data: Dictionary, target: int) -> void:
	if peer == null:
		return

	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
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

func broadcast_to_instance(stage: String, instance: int, data: Dictionary):
	var key = "%s::%d" % [stage, instance]

	if not instance_population.has(key):
		return

	# Get filtered list once instead of per-client checks
	var recipients = get_instance_remote_players(stage, instance)
	
	for client_id in recipients.keys():
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
func start_server(port: int = -1) -> void:
	if port == -1:
		port = DEFAULT_PORT
	
	peer = ENetMultiplayerPeer.new()

	var err := peer.create_server(port)
	if err:
		logger.error("Server failed: %s" % error_string(err))
		return

	logger.info("Server started on port %d" % port)
	is_server = true


# ==================================================
# INSTANCE HELPERS
# ==================================================
func _get_instance_key(stage: String, instance: int) -> String:
	return "%s::%d" % [stage, instance]

func get_instance_limit(stage: String) -> int:
	var path = "res://Stages/%s/%s.tscn" % [stage, stage]
	var packed = load(path)

	if packed == null:
		return 3

	var temp = packed.instantiate()

	var limit := 3

	if "player_max" in temp:
		limit = temp.player_max

	temp.queue_free()
	return limit

func find_available_instance(stage: String) -> int:
	var instance := 1
	var limit := get_instance_limit(stage)

	while true:
		var key = _get_instance_key(stage, instance)

		if not instance_population.has(key):
			instance_population[key] = []
			return instance

		if instance_population[key].size() < limit:
			return instance

		instance += 1

	return 1

func _remove_from_instance(client_id: int):
	for key in instance_population.keys():
		if instance_population[key].has(client_id):
			instance_population[key].erase(client_id)

			if instance_population[key].is_empty():
				instance_population.erase(key)


func get_spawn_points(stage: String, scene: String) -> Array:
	var key = "%s::%s" % [stage, scene] # cache should NOT use instance

	if not spawn_points_cache.has(key):
		spawn_points_cache[key] = SceneManager.get_spawn_points_for_room(stage, scene)

	return spawn_points_cache[key]


func _free_spawn(client_id: int):
	for key in used_spawn_ids.keys():
		if used_spawn_ids[key].has(client_id):
			used_spawn_ids[key].erase(client_id)

			if used_spawn_ids[key].is_empty():
				used_spawn_ids.erase(key)

func is_new_stage(client_id: int, stage: String) -> bool:
	return not remote_players.has(client_id) or remote_players[client_id]["stage"] != stage

func get_instance_remote_players(stage: String, instance: int) -> Dictionary:
	var result := {}

	for client_id in remote_players.keys():
		var p = remote_players[client_id]

		if typeof(p) != TYPE_DICTIONARY:
			continue

		if p.get("stage") != stage:
			continue
		if p.get("instance") != instance:
			continue

		result[client_id] = p

	return result


# ==================================================
# SPAWN SYSTEM
# ==================================================
func get_spawn_position(client_id: int, stage: String, scene: String, instance: int) -> Vector2:
	var key = _get_instance_key(stage, instance)

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
# HEARTBEAT / DISCONNECT
# ==================================================
func check_heartbeats():
	for client_id in connected_clients.keys().duplicate():
		connected_clients[client_id] += hb_timer.wait_time

		if connected_clients[client_id] > HEARTBEAT_TIMEOUT:
			handle_disconnect(client_id, "timeout")

func _full_cleanup_client(client_id: int):
	var stage := ""
	var _scene := ""
	var instance := 1

	if remote_players.has(client_id):
		stage = remote_players[client_id].get("stage", "")
		_scene = remote_players[client_id].get("scene", "")
		instance = remote_players[client_id].get("instance", 1)

	_free_spawn(client_id)
	_remove_from_instance(client_id)
	remote_players.erase(client_id)
	connected_clients.erase(client_id)

	if stage != "":
		broadcast_to_instance(stage, instance, {
			"type": "s_remote_players",
			"id": client_id,
			"remote_players": get_instance_remote_players(stage, instance)
		})


func handle_disconnect(client_id: int, reason: String) -> void:
	logger.info("Disconnect: %d - %s" % [client_id, reason])

	_full_cleanup_client(client_id)


func handle_server_disconnect():
	if not connected and not handshake_sent:
		return

	connected = false
	handshake_sent = false
	heartbeat_timer = 0.0

	logger.warn("Lost connection to server")
	server_lost.emit()

	if peer:
		peer.close()
		peer = null


# -------------------------
# CLIENT
# -------------------------
func start_client(ip_address: String = "", port: int = -1) -> void:
	if ip_address == "":
		ip_address = DEFAULT_SERVER_IP
	if port == -1:
		port = DEFAULT_PORT
	
	peer = ENetMultiplayerPeer.new()

	var err := peer.create_client(ip_address, port)
	if err:
		logger.error("Client failed: %s" % error_string(err))
		return

	logger.info("Connecting to %s:%d..." % [ip_address, port])


# -------------------------
# CLEANUP
# -------------------------
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_server and logger:
			logger.info("Server shutting down, disconnecting all clients...")
			for client_id in connected_clients.keys():
				handle_disconnect(client_id, "server shutdown")
		
		if peer:
			peer.close()
			if logger:
				logger.info("Peer connection closed")
