extends Node

@export var current_stage: String = "StarterTown"
@export var current_scene: String = "Scene1"

@export var default_stage: String = "StarterTown"
@export var default_scene: String = "Scene1"

var container: Node
var selected_stage: Node

var player_scene = preload("res://Entities/Player/Player.tscn")
var remote_player_scene = preload("res://Entities/RemotePlayer/RemotePlayer.tscn")

var player: Node2D
var available_spawn_points: Array = []

var scene_transitioning := false

# ==================================================
# REMOTE PLAYER SYNC STATE (FIX)
# ==================================================
var remote_players_buffer: Dictionary = {}
var remote_players_ready := false


func setup(scene_container: Node):
	container = scene_container


func unload_stage() -> void:
	if container == null:
		return

	for child in container.get_children():
		child.queue_free()


# ==================================================
# STAGE LOADING
# ==================================================
func load_stage(spawn_position := Vector2.INF):
	print("load_stage")
	if container == null:
		print("SceneLoader error: container has not been set.")
		return null

	if current_stage == "":
		current_stage = default_stage

	if current_scene == "":
		current_scene = default_scene

	scene_transitioning = true

	if selected_stage:
		selected_stage.queue_free()
		selected_stage = null

	var path = "res://Stages/%s/Scenes/%s.tscn" % [current_stage, current_scene]

	var packed_scene = load(path)
	if packed_scene == null:
		print("Failed to load scene: ", path)
		return null

	selected_stage = packed_scene.instantiate()
	container.add_child(selected_stage)

	# reset remote sync state on every stage load
	remote_players_ready = false
	remote_players_buffer.clear() # 🔥 IMPORTANT: prevents stale players leaking across scenes

	# -------------------------
	# PLAYER SETUP
	# -------------------------
	if player == null:
		player = player_scene.instantiate()
		player.add_to_group("player")

	var player_parent = selected_stage.get_node_or_null("Player")
	if player_parent == null:
		player_parent = Node2D.new()
		player_parent.name = "Player"
		selected_stage.add_child(player_parent)

	if player.get_parent():
		player.get_parent().remove_child(player)

	player_parent.add_child(player)
	selected_stage.set_player(player)

	player.reset_teleport_state()

	# -------------------------
	# CLEAR REMOTE PLAYERS (🔥 CRITICAL FIX)
	# -------------------------
	var remote_parent = selected_stage.get_node_or_null("RemotePlayers")
	if remote_parent:
		for child in remote_parent.get_children():
			child.queue_free()

	# -------------------------
	# SPAWN
	# -------------------------
	if spawn_position == Vector2.INF:
		print(5555)
		ServerManager.send_to_server({ "type": "c_spawn_player" })

	# -------------------------
	# TRANSITION UNLOCK
	# -------------------------
	get_tree().create_timer(0.2).timeout.connect(func():
		scene_transitioning = false
	)

	# -------------------------
	# DELAYED REMOTE RESYNC
	# -------------------------
	# immediately try to apply buffered data (no delay)
	remote_players_ready = false

	if remote_players_buffer.size() > 0:
		var filtered := {}

		for id in remote_players_buffer.keys():
			var data = remote_players_buffer[id]

			if data.get("stage", "") == current_stage and data.get("scene", "") == current_scene:
				filtered[id] = data

		_load_remote_players(filtered)
		remote_players_ready = true


	return selected_stage

# ==================================================
# SPAWN SYSTEM
# ==================================================
func spawn_player_random_unused():
	print("spawn_player_random_unused")
	if selected_stage == null:
		return Vector2.ZERO

	var spawn_parent = selected_stage.get_node_or_null("SpawnPoints")
	if spawn_parent == null:
		return Vector2.ZERO

	available_spawn_points.clear()

	for spawn in spawn_parent.get_children():
		if spawn is Area2D:
			var occupied = spawn.occupied
			if not occupied and ServerManager.is_server:
				occupied = _is_spawn_position_used(spawn.global_position)
			if not occupied:
				available_spawn_points.append(spawn)

	if available_spawn_points.is_empty():
		return Vector2.ZERO

	return available_spawn_points.pick_random().global_position


func _is_spawn_position_used(spawn_position: Vector2) -> bool:
	for player_data in ServerManager.remote_players.values():
		if player_data is Dictionary and player_data.has("position"):
			if player_data.position.distance_to(spawn_position) < 32:
				return true
	return false


func respawn_player():
	if not ServerManager.is_ready():
		print("Cannot respawn: server not ready")
		return
		
	# SHOULDNT NEED TO RELOAD SCENE

	current_stage = default_stage
	current_scene = default_scene

	remote_players_ready = false
	load_stage(Vector2.INF)


# ==================================================
# REMOTE PLAYER SYNC (FIXED SYSTEM)
# ==================================================

func update_remote_players(remote_players: Dictionary) -> void:
	remote_players_buffer = remote_players

	if selected_stage == null:
		return

	# optional safety filter (defensive layer)
	var filtered := {}

	for id in remote_players.keys():
		if remote_players[id].get("stage", "") == current_stage and \
		   remote_players[id].get("scene", "") == current_scene:
			filtered[id] = remote_players[id]

	if not remote_players_ready:
		_load_remote_players(filtered)
		remote_players_ready = true
	else:
		_move_remote_players(filtered)


func _get_remote_parent() -> Node:
	if selected_stage == null:
		return null

	var parent = selected_stage.get_node_or_null("RemotePlayers")

	if parent == null:
		parent = Node2D.new()
		parent.name = "RemotePlayers"
		selected_stage.add_child(parent)

	return parent


func _get_or_create_remote_player(parent: Node, client_id: int) -> Node2D:
	var node_name := "RemotePlayer_%d" % client_id
	var remote_player := parent.get_node_or_null(node_name)

	if remote_player == null:
		remote_player = remote_player_scene.instantiate()
		remote_player.name = node_name
		parent.add_child(remote_player)

	return remote_player


func _apply_remote_player_state(remote_player: Node2D, data: Dictionary) -> void:
	if data.has("position"):
		remote_player.global_position = data.position

	if data.has("direction"):
		remote_player.scale.x = data.direction


# full rebuild (used after respawn / first sync)
func _load_remote_players(remote_players: Dictionary) -> void:
	var parent = _get_remote_parent()
	if parent == null:
		return

	var local_id = ServerManager.get_local_peer_id()

	var valid_ids := {}

	for client_id in remote_players.keys():
		if client_id == local_id:
			continue

		valid_ids[client_id] = true

		var remote_player = _get_or_create_remote_player(parent, client_id)

		_apply_remote_player_state(remote_player, remote_players[client_id])

		# 🔥 FORCE VISUAL STATE (important fix)
		remote_player.visible = true
		remote_player.process_mode = Node.PROCESS_MODE_INHERIT

	# remove stale players
	for child in parent.get_children():
		if child.name.begins_with("RemotePlayer_"):
			var id_str = child.name.replace("RemotePlayer_", "")
			var id = int(id_str)

			if not valid_ids.has(id):
				child.queue_free()


# incremental update (movement only)
func _move_remote_players(remote_players: Dictionary) -> void:
	var parent = _get_remote_parent()
	if parent == null:
		return

	var local_id = ServerManager.get_local_peer_id()

	var valid_ids := {}

	print("remote_players: ", remote_players)

	for client_id in remote_players.keys():
		if client_id == local_id:
			continue

		valid_ids[client_id] = true

		var remote_player = _get_or_create_remote_player(parent, client_id)

		_apply_remote_player_state(remote_player, remote_players[client_id])

		# 🔥 IMPORTANT: ensure visibility even if spawned via move packet
		remote_player.visible = true
		remote_player.process_mode = Node.PROCESS_MODE_INHERIT

	# cleanup stale ones
	for child in parent.get_children():
		if child.name.begins_with("RemotePlayer_"):
			var id_str = child.name.replace("RemotePlayer_", "")
			var id = int(id_str)

			if not valid_ids.has(id):
				child.queue_free()


# ==================================================
# TELEPORT SYSTEM (UNCHANGED)
# ==================================================
func teleport_player(target_stage: String, target_scene: String, target_teleport: String, exit_direction := Vector2.RIGHT):
	if scene_transitioning:
		return

	if player == null:
		return

	if player.spawn_protection or not player.can_teleport:
		return

	player.lock_teleport()
	player.stop_movement()

	var stage = target_stage if target_stage != "" else current_stage
	var scene = target_scene if target_scene != "" else current_scene
	
	if stage != current_stage or scene != current_scene:
		current_stage = stage
		current_scene = scene

		var new_stage = load_stage(Vector2.ZERO) # or any non-INF placeholder
		var pos = resolve_position(new_stage, target_teleport)
		player.global_position = pos
		
	else:
		var pos = resolve_position(selected_stage, target_teleport)
		player.global_position = pos
	
	print('target_stage: ', target_stage)
	print('target_scene: ', target_scene)

	ServerManager.send_to_server({
		"type": "c_move_player",
		"position": player.global_position,
		"direction": player.scale.x,
		"stage": target_stage,
		"scene": target_scene,
	})
	
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	player.unlock_teleport()
	
	
func resolve_position(node: Node, teleport_name: String) -> Vector2:
	print("teleport_name: ", teleport_name)
	if teleport_name == null or teleport_name == "":
		return spawn_player_random_unused()

	var receiver = node.find_child(teleport_name, true, false)
	if receiver:
		return receiver.global_position

	return resolve_fallback_spawn(node)

func resolve_fallback_spawn(node: Node) -> Vector2:
	var spawn_parent = node.get_node_or_null("SpawnPoints")
	if spawn_parent:
		for s in spawn_parent.get_children():
			if s is Area2D:
				return s.global_position

	return Vector2.ZERO


func _is_same_room(data: Dictionary) -> bool:
	return data.has("stage") and data.has("scene") and \
		data.stage == current_stage and data.scene == current_scene
