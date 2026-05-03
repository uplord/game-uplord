extends Node2D

@onready var body = $Model/Body

func _ready():
	pass

func _physics_process(_delta):
	z_index = int(global_position.y)
