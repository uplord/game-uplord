extends Node2D
class_name RemotePlayer

@onready var body = $Model/Body

func _ready():
	pass

func _physics_process(_delta):
	z_index = int(global_position.y)

func set_direction(dir: int):
	if body == null:
		body = $Model/Body

	body.scale.x = dir
