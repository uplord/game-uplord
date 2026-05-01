extends Node2D

@onready var body = $Model/Body

func _ready():
	pass

func _physics_process(delta):
	z_index = int(global_position.y)
