extends Area2D

@onready var sprite: Sprite2D = $Direction

enum ExitDirection { LEFT, RIGHT }
enum TeleportDirection { UP, DOWN, LEFT, RIGHT, UPLEFT, UPRIGHT, DOWNLEFT, DOWNRIGHT }

@export var target_stage: String = ""
@export var target_scene: String = ""
@export var target_teleport: String = "Teleport1"
@export var cooldown_time := 0.3
@export var exit_direction: ExitDirection = ExitDirection.RIGHT
@export var teleport_direction: TeleportDirection = TeleportDirection.UP


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	sprite.texture = get_texture_from_direction(teleport_direction)


func _on_body_entered(body):
	if not body.is_in_group("player"):
		return

	var dir := Vector2.RIGHT
	if exit_direction == ExitDirection.LEFT:
		dir = Vector2.LEFT

	get_tree().create_timer(0.0).timeout.connect(func():
		print("teleport_player")
		#SceneManager.teleport_player(
			#target_stage,
			#target_scene,
			#target_teleport,
			#dir
		#)
	)
	
func get_texture_from_direction(dir: TeleportDirection) -> Texture2D:
	var name_map := {
		TeleportDirection.UP: "Up",
		TeleportDirection.DOWN: "Down",
		TeleportDirection.LEFT: "Left",
		TeleportDirection.RIGHT: "Right",
		TeleportDirection.UPLEFT: "UpLeft",
		TeleportDirection.UPRIGHT: "UpRight",
		TeleportDirection.DOWNLEFT: "DownLeft",
		TeleportDirection.DOWNRIGHT: "DownRight",
	}
	var file_name = name_map.get(dir, "Up")
	return load("res://Entities/Teleports/Teleport/Art/%s.png" % file_name)
