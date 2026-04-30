extends Button

enum ExitDirection { LEFT, RIGHT }

@export var target_stage: String = ""
@export var target_scene: String = ""
@export var target_teleport: String = "Teleport1"
@export var exit_direction: ExitDirection = ExitDirection.RIGHT

func _pressed():
	var dir := Vector2.RIGHT
	if exit_direction == ExitDirection.LEFT:
		dir = Vector2.LEFT

	SceneManager.teleport_player(
		target_stage,
		target_scene,
		target_teleport,
		dir
	)
