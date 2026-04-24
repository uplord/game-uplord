extends Node

@onready var container = $SceneContainer
var current_scene

func _ready():
	load_scene("res://scenes/main/Login.tscn")

func load_scene(path: String):
	if current_scene:
		current_scene.queue_free()

	current_scene = load(path).instantiate()
	container.add_child(current_scene)
