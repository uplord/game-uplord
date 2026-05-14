extends CharacterBody2D
class_name Player

@export var speed := 400

@onready var body = $Base/Model

var animation_tree: AnimationTree
var animation_state: AnimationNodeStateMachinePlayback
var current_anim := ""

var target: Vector2
var has_target := false

var can_teleport := true
var last_portal = null
var movement_enabled := true

var spawn_protection := false


func _ready():
	set_facing(Vector2(1, 0))

	# Wait for dynamic model to be instanced
	await get_tree().process_frame

	var model = body.get_model_root()

	if model == null:
		push_error("Model not loaded yet")
		return

	animation_tree = model.get_node_or_null("AnimationTree")

	if animation_tree == null:
		push_error("AnimationTree not found inside model")
		return

	animation_tree.active = true
	animation_state = animation_tree["parameters/playback"]

	play_anim("idle")


# -------------------------
# ANIMATION HANDLER
# -------------------------
func play_anim(anim_name: String) -> void:
	if animation_state == null:
		return

	if current_anim == anim_name:
		return

	current_anim = anim_name
	animation_state.travel(anim_name)


# -------------------------
# INPUT
# -------------------------
func _input(event):
	if not movement_enabled or spawn_protection:
		return

	if event.is_action_pressed("Click"):
		var hovered = get_viewport().gui_get_hovered_control()
		if hovered:
			return

		target = get_parent().to_local(get_global_mouse_position())
		has_target = true


# -------------------------
# MOVEMENT
# -------------------------
func _physics_process(_delta):
	if not ServerManager.is_ready():
		return

	if not movement_enabled:
		velocity = Vector2.ZERO
		play_anim("idle")
		return

	if has_target and position.distance_to(target) > 10:
		var dir = position.direction_to(target)
		velocity = dir * speed
		move_and_slide()

		var facing = -1 if velocity.x < 0 else 1
		body.scale.x = facing

		play_anim("run")

		ServerManager.send_to_server({
			"type": "c_move_player",
			"position": global_position,
			"direction": facing,
			"stage": SceneManager.current_stage,
			"scene": SceneManager.current_scene,
			"instance": SceneManager.current_instance,
		})
	else:
		velocity = Vector2.ZERO
		play_anim("idle")

	_apply_z_sort()


# -------------------------
# UTILS
# -------------------------
func stop_movement():
	velocity = Vector2.ZERO
	has_target = false


func get_direction() -> int:
	return 1 if body.scale.x >= 0 else -1


func set_facing(direction: Vector2):
	if abs(direction.x) > 0.1:
		body.scale.x = -1 if direction.x < 0 else 1


func set_movement_enabled(enabled: bool):
	movement_enabled = enabled
	if not enabled:
		stop_movement()
		play_anim("idle")


# -------------------------
# RESPAWN
# -------------------------
func respawn(spawn_position: Vector2):
	global_position = spawn_position
	body.scale.x = -1

	await get_tree().create_timer(0.2).timeout

	ServerManager.send_to_server({
		"type": "c_move_player",
		"position": global_position,
		"direction": body.scale.x,
		"stage": SceneManager.current_stage,
		"scene": SceneManager.current_scene,
		"instance": SceneManager.current_instance,
	})


# -------------------------
# TELEPORT CONTROL
# -------------------------
func lock_teleport():
	can_teleport = false


func unlock_teleport():
	can_teleport = true


func reset_teleport_state():
	can_teleport = true
	spawn_protection = false
	last_portal = null


# -------------------------
# Z SORT
# -------------------------
func _apply_z_sort():
	var base = int(global_position.y)

	z_index = base
