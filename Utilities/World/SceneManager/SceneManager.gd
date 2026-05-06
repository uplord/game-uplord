extends Node

@export var current_stage: String = "StarterTown"
@export var current_scene: String = "Scene1"
@export var current_instance: int = 1

@export var default_stage: String = "StarterTown"
@export var default_scene: String = "Scene1"

var container: Node
var selected_stage: Node

var player_scene = preload("res://Entities/Player/Player.tscn")
var remote_player_scene = preload("res://Entities/RemotePlayer/RemotePlayer.tscn")

var player: Node2D
var spawn_requested := false
var scene_transitioning := false

var last_remote_snapshot: Dictionary = {}

var instance_player_count: int = 0

# { peer_id: Node2D }

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

	var stage_path = "res://Stages/%s/%s.tscn" % [current_stage, current_stage]
	var packed_scene = load(stage_path)

	if packed_scene == null:
		print("Failed to load stage: ", stage_path)
		return null

	selected_stage = packed_scene.instantiate()
	container.add_child(selected_stage)

	# PLAYER
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

	if spawn_position == Vector2.INF:
		player.visible = false

	if spawn_position != Vector2.INF:
		player.global_position = spawn_position

	# SPAWN
	if spawn_position == Vector2.INF and not spawn_requested:
		spawn_requested = true
		ServerManager.send_to_server({ "type": "c_spawn_player" })

	_load_scene(current_scene)

	var remote_parent = Node2D.new()
	remote_parent.name = "RemotePlayers"
	selected_stage.add_child(remote_parent)

	# FREE TRANSITION LOCK
	get_tree().create_timer(0.2).timeout.connect(func():
		scene_transitioning = false
	)

	# print('load_stage UI')
	GameManager.update_ui()

func _load_scene(scene_name: String):
	if selected_stage == null:
		return

	# remove old scenes
	for child in selected_stage.get_children():
		if child.name.begins_with("Scene"):
			child.queue_free()

	var path = "res://Stages/%s/Scenes/%s.tscn" % [current_stage, scene_name]
	var packed = load(path)

	if packed == null:
		print("Failed to load scene: ", path)
		return

	var scene = packed.instantiate()
	scene.name = scene_name
	selected_stage.add_child(scene)

func respawn_player():
	if not ServerManager.is_ready():
		print("Cannot respawn: server not ready")
		return

	var same_location = (
		current_stage == default_stage and
		current_scene == default_scene
	)

	if same_location:
		ServerManager.send_to_server({ "type": "c_spawn_player" })
	else:
		spawn_requested = false
		current_stage = default_stage
		current_scene = default_scene

		load_stage(Vector2.INF)

func apply_teleport(stage: String, scene: String, position: Vector2, exit_direction: Vector2, instance := 1):
	if player == null:
		return

	var stage_changed := stage != current_stage
	var scene_changed := scene != current_scene

	current_stage = stage
	current_scene = scene
	current_instance = instance

	# 🔥 IMPORTANT: reload if EITHER changes
	if stage_changed or scene_changed:
		load_stage(position)
	else:
		player.global_position = position

	player.set_facing(exit_direction)
	player.unlock_teleport()

	GameManager.update_ui()

func teleport_player(target_stage: String, target_scene: String, target_teleport: String, exit_direction := Vector2.RIGHT):
	if scene_transitioning:
		return

	if player == null:
		return

	if player.spawn_protection or not player.can_teleport:
		return

	player.lock_teleport()
	player.stop_movement()

	# send request to server ONLY
	ServerManager.send_to_server({
		"type": "c_teleport_player",
		"stage": target_stage,
		"scene": target_scene,
		"teleport": target_teleport,
		"direction": exit_direction,
	})

func get_spawn_points_for_room(stage: String, scene: String) -> Array:
	var path = "res://Stages/%s/Scenes/%s.tscn" % [stage, scene]
	var packed = load(path)

	if packed == null:
		return []

	var temp_scene = packed.instantiate()

	var spawn_parent = temp_scene.get_node_or_null("SpawnPoints")
	if spawn_parent == null:
		temp_scene.queue_free()
		return []

	var points := []

	for spawn in spawn_parent.get_children():
		if spawn is Area2D:
			points.append(spawn.global_position)

	temp_scene.queue_free()
	return points

func resolve_teleport_position(stage: String, scene: String, teleport_name: String) -> Vector2:
	var path = "res://Stages/%s/Scenes/%s.tscn" % [stage, scene]
	var packed = load(path)

	if packed == null:
		return Vector2.ZERO

	var temp_scene = packed.instantiate()

	if teleport_name != null and teleport_name != "":
		var node = temp_scene.find_child(teleport_name, true, false)
		if node:
			var pos = node.global_position
			temp_scene.queue_free()
			return pos

	temp_scene.queue_free()
	return Vector2.ZERO


func spawn_remote_players(data: Dictionary):
	last_remote_snapshot = data

	var parent = selected_stage.get_node_or_null("RemotePlayers")
	if parent == null:
		return

	# 🔥 HARD RESET (CRITICAL FIX)
	for child in parent.get_children():
		child.queue_free()

	var my_id = ServerManager.get_local_peer_id()

	for client_id in data.keys():

		if client_id == my_id:
			continue

		var p = data[client_id]

		if typeof(p) != TYPE_DICTIONARY:
			continue

		if not p.has("stage") or not p.has("scene") or not p.has("instance") or not p.has("position"):
			continue

		if p.stage != current_stage:
			continue
		if p.scene != current_scene:
			continue
		if p.instance != current_instance:
			continue

		var remote_player = remote_player_scene.instantiate()
		remote_player.name = "RemotePlayer_%d" % client_id
		remote_player.global_position = p.position
		remote_player.set_direction(p.direction)
		parent.add_child(remote_player)

	GameManager.update_ui()

func get_local_instance_count() -> int:
	return _count_from_snapshot(last_remote_snapshot)


func _count_from_snapshot(snapshot: Dictionary) -> int:
	var count := 0

	for client_id in snapshot.keys():

		var p = snapshot[client_id]

		if typeof(p) != TYPE_DICTIONARY:
			continue

		if not p.has("stage") or not p.has("instance"):
			continue

		if p.stage == current_stage \
		and p.instance == current_instance:
			count += 1

	return count
