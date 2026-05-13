extends Node2D
class_name RemotePlayer

@onready var body = $Model/Body

var is_local := false

func _ready():
	pass

func _physics_process(_delta):
	_apply_z_sort()

func set_direction(dir: int):
	if body == null:
		body = $Model/Body

	body.scale.x = dir

func _apply_z_sort():
	var base = int(global_position.y)

	z_index = base
