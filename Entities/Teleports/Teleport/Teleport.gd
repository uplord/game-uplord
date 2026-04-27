extends Area2D

enum ExitDirection { LEFT, RIGHT }

@export var target_stage: String = ""
@export var target_scene: String = ""
@export var target_teleport: String = "Teleport1"
@export var cooldown_time := 0.3
@export var exit_direction: ExitDirection = ExitDirection.RIGHT


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):
	if SceneManager.scene_transitioning:
		return

	if not body.is_in_group("player"):
		return

	if body.spawn_protection or not body.can_teleport:
		return

	get_tree().create_timer(0.0).timeout.connect(func():
		teleport(body)
	)


func resolve_position(node: Node, teleport_name: String) -> Vector2:
	# -------------------------
	# SAFETY: empty name guard
	# -------------------------
	if teleport_name == null or teleport_name == "":
		return SceneManager.spawn_player_random_unused()

	# -------------------------
	# try teleport target
	# -------------------------
	var receiver = node.find_child(teleport_name, true, false)
	if receiver:
		return receiver.global_position

	# fallback if teleport not found
	return resolve_fallback_spawn(node)


func resolve_fallback_spawn(node: Node) -> Vector2:
	var spawn_parent = node.get_node_or_null("SpawnPoints")
	if spawn_parent:
		for s in spawn_parent.get_children():
			if s is Area2D:
				return s.global_position

	return Vector2.ZERO

func teleport(body):
	body.lock_teleport()
	body.stop_movement()

	set_deferred("monitoring", false)

	# ==================================================
	# RESOLVE TARGET (IMPORTANT FIX)
	# ==================================================
	var stage = target_stage
	var scene = target_scene

	# inherit current values if empty
	if stage == "":
		stage = SceneManager.current_stage

	if scene == "":
		scene = SceneManager.current_scene

	# ==================================================
	# SCENE CHANGE
	# ==================================================
	if stage != SceneManager.current_stage or scene != SceneManager.current_scene:
		SceneManager.current_stage = stage
		SceneManager.current_scene = scene

		var new_stage = SceneManager.load_stage(Vector2.INF)

		var pos = resolve_position(new_stage, target_teleport)
		SceneManager.player.global_position = pos

	# ==================================================
	# SAME SCENE TELEPORT
	# ==================================================
	else:
		var pos = resolve_position(SceneManager.selected_stage, target_teleport)
		body.global_position = pos

	# ==================================================
	# EXIT DIRECTION
	# ==================================================
	var dir_value := -1
	if exit_direction == ExitDirection.LEFT:
		dir_value = 1

	body.set_facing(Vector2(dir_value, 0))

	await get_tree().process_frame
	await get_tree().process_frame

	set_deferred("monitoring", true)

	await get_tree().create_timer(cooldown_time).timeout
	body.unlock_teleport()
