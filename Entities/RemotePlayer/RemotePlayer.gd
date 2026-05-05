extends Node2D
class_name RemotePlayer

@onready var body = $Model/Body

func _ready():
	pass

func _physics_process(_delta):
	z_index = int(global_position.y)

func set_facing(direction: Vector2):
	if abs(direction.x) > 0.1:
		body.scale.x = 1 if direction.x < 0 else -1
