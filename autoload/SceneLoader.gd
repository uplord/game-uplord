extends Node

var container: Node
var current_scene: Node

var player_scene = preload("res://scenes/player/Player.tscn")
var player: Node2D


func setup(scene_container: Node):
	container = scene_container


func load_scene(path: String, spawn_position: Vector2 = Vector2.ZERO):
	if container == null:
		print("SceneLoader error: container has not been set.")
		return null

	if current_scene:
		if player and player.get_parent() == current_scene:
			current_scene.remove_child(player)

		current_scene.queue_free()

	current_scene = load(path).instantiate()
	container.add_child(current_scene)

	spawn_player_at_position(spawn_position)

	return current_scene


func spawn_player_at_position(spawn_position: Vector2):
	if current_scene == null:
		return

	if player == null:
		player = player_scene.instantiate()
		player.add_to_group("player")

	if player.get_parent():
		player.get_parent().remove_child(player)

	current_scene.add_child(player)
	player.global_position = spawn_position

	if "target" in player:
		player.target = player.position
		
	if "player_scale" in current_scene:
		var s = current_scene.player_scale
		player.scale = Vector2(s, s)
	else:
		player.scale = Vector2.ONE


func spawn_player_at_node(spawn_name: String):
	if current_scene == null:
		return

	var spawn_point = current_scene.get_node_or_null(spawn_name)

	if spawn_point == null:
		print("Spawn point not found: ", spawn_name)
		return

	spawn_player_at_position(spawn_point.global_position)


func get_current_scene():
	return current_scene


func get_player():
	return player
