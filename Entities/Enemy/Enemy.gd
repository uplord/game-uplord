extends Node2D
class_name Enemy

@onready var body = $Base/Model


func _physics_process(_delta):
	_apply_z_sort()
	
func set_direction(dir: int):
	if body == null:
		body = $Base/Model

	body.scale.x = -1 if dir == 0 else 1

func _apply_z_sort():
	var base = int(global_position.y)

	z_index = base
