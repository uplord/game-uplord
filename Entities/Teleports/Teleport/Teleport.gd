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
	if not body.is_in_group("player"):
		return

	var dir := Vector2.RIGHT
	if exit_direction == ExitDirection.LEFT:
		dir = Vector2.LEFT

	get_tree().create_timer(0.0).timeout.connect(func():
		SceneManager.teleport_player(
			target_stage,
			target_scene,
			target_teleport,
			dir
		)
	)
