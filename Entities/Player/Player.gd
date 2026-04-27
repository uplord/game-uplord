extends CharacterBody2D

@export var speed := 400

@onready var body = $Model/Body

var target: Vector2
var has_target := false

var can_teleport := true
var last_portal = null
var facing_dir := 1

var spawn_protection := false


func _input(event):
	if event.is_action_pressed("Click"):
		var hovered = get_viewport().gui_get_hovered_control()
		if hovered:
			return

		target = get_parent().to_local(get_global_mouse_position())
		has_target = true


func _physics_process(_delta):
	if has_target and position.distance_to(target) > 10:
		var dir = position.direction_to(target)
		velocity = dir * speed
		move_and_slide()

		if abs(dir.x) > 0.1:
			body.scale.x = 1 if dir.x < 0 else -1
	else:
		velocity = Vector2.ZERO


func stop_movement():
	velocity = Vector2.ZERO
	has_target = false


func respawn(spawn_position: Vector2):
	global_position = spawn_position
	velocity = Vector2.ZERO
	has_target = false

	stop_movement()

	spawn_protection = true
	lock_teleport()

	await get_tree().create_timer(0.2).timeout

	spawn_protection = false
	unlock_teleport()


# -------------------------
# TELEPORT CONTROL
# -------------------------

func lock_teleport():
	can_teleport = false


func unlock_teleport():
	can_teleport = true


# -------------------------
# CRITICAL RESET ON SCENE LOAD
# -------------------------
func reset_teleport_state():
	can_teleport = true
	spawn_protection = false
	last_portal = null


func set_facing(direction: Vector2):
	if abs(direction.x) > 0.1:
		body.scale.x = -1 if direction.x < 0 else 1
