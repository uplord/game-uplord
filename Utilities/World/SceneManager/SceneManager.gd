extends Node

@export var current_stage: String = "StarterTown"
@export var current_scene: String = "Scene1"

@export var default_stage: String = "StarterTown"
@export var default_scene: String = "Scene1"

var container: Node
var selected_stage: Node

var player_scene = preload("res://Entities/Player/Player.tscn")
var player: Node2D

var scene_transitioning := false


func setup(scene_container: Node):
	container = scene_container


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

	# -------------------------
	# PLAYER SETUP
	# -------------------------
	if player == null:
		player = player_scene.instantiate()
		player.add_to_group("player")

	var player_parent = selected_stage.get_node_or_null("Player")

	if player_parent == null:
		push_warning("Missing Player node in stage: " + current_stage)
		player_parent = selected_stage

	if player.get_parent():
		player.get_parent().remove_child(player)

	player_parent.add_child(player)
	selected_stage.set_player(player)

	player.reset_teleport_state()

	# -------------------------
	# SPAWN
	# -------------------------
	if spawn_position == Vector2.INF:
		spawn_position = spawn_player_random_unused()

	player.global_position = spawn_position

	# unlock after short delay
	get_tree().create_timer(0.2).timeout.connect(func():
		scene_transitioning = false
	)

	return selected_stage


func spawn_player_random_unused():
	if selected_stage == null:
		return Vector2.ZERO

	var spawn_parent = selected_stage.get_node_or_null("SpawnPoints")
	if spawn_parent == null:
		return Vector2.ZERO

	var available = []

	for spawn in spawn_parent.get_children():
		if spawn is Area2D and not spawn.occupied:
			available.append(spawn)

	if available.is_empty():
		return Vector2.ZERO

	return available.pick_random().global_position


func respawn_player():
	current_stage = default_stage
	current_scene = default_scene

	load_stage(Vector2.INF)

	await get_tree().process_frame

	var spawn_pos = spawn_player_random_unused()

	if player:
		player.reset_teleport_state()
		player.respawn(spawn_pos)
		player.stop_movement()
		player.set_facing(Vector2(1, 0))


func get_current_stage():
	return current_stage


func get_current_scene():
	return current_scene
