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
var spawn_requested := false

# var label_stage: Label = null
# var label_scene: Label = null
# var label_stage_count: Label = null

var scene_transitioning := false

# ==================================================
# REMOTE PLAYER SYNC STATE (FIX)
# ==================================================
# var remote_players_buffer: Dictionary = {}
# var remote_players_ready := false


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

	var path = "res://Stages/%s/Scenes/%s.tscn" % [current_stage, current_scene]

	var packed_scene = load(path)
	if packed_scene == null:
		print("Failed to load scene: ", path)
		return null

	selected_stage = packed_scene.instantiate()
	container.add_child(selected_stage)

	# CLEAR REMOTE_PLAYERS
	var remote_parent = selected_stage.get_node_or_null("RemotePlayers")
	if remote_parent:
		for child in remote_parent.get_children():
			child.queue_free()

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


	# SPAWN
	if spawn_position == Vector2.INF and not spawn_requested:
		spawn_requested = true
		ServerManager.send_to_server({ "type": "c_spawn_player" })

	# FREE TRANSITION LOCK
	get_tree().create_timer(0.2).timeout.connect(func():
		scene_transitioning = false
	)

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
		current_stage = default_stage
		current_scene = default_scene

		load_stage(Vector2.INF)

# REMOTE PLAYERS

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
