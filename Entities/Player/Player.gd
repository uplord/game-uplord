extends CharacterBody2D
class_name Player

@export var speed := 400

@onready var body = $Model/Body

var target: Vector2
var has_target := false

var can_teleport := true
var last_portal = null
var movement_enabled := true

var spawn_protection := false

var is_local := true


func _ready():
	set_facing(Vector2(1, 0))


func _input(event):
	if not movement_enabled or spawn_protection:
		return

	if event.is_action_pressed("Click"):
		var hovered = get_viewport().gui_get_hovered_control()
		if hovered:
			return

		target = get_parent().to_local(get_global_mouse_position())
		has_target = true


func _physics_process(_delta):
	if not ServerManager.is_ready():
		return

	if not movement_enabled:
		velocity = Vector2.ZERO
		return

	if has_target and position.distance_to(target) > 10:
		var dir = position.direction_to(target)
		velocity = dir * speed
		move_and_slide()

		var facing = -1 if velocity.x < 0 else 1
		body.scale.x = facing

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

	_apply_z_sort()


func stop_movement():
	velocity = Vector2.ZERO
	has_target = false

func get_direction() -> int:
	return 1 if body.scale.x >= 0 else -1

# -------------------------
# RESPawn FIXED
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


# -------------------------
# RESET STATE
# -------------------------
func reset_teleport_state():
	can_teleport = true
	spawn_protection = false
	last_portal = null


func set_facing(direction: Vector2):
	if abs(direction.x) > 0.1:
		body.scale.x = -1 if direction.x < 0 else 1


func set_movement_enabled(enabled: bool):
	movement_enabled = enabled
	if not enabled:
		stop_movement()

func _apply_z_sort():
	z_index = int(global_position.y)

	# local player ALWAYS wins ties
	if is_local:
		z_index += 1
