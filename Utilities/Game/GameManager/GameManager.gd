extends Node

@onready var container = $SceneContainer

func _ready():
	SceneManager.setup(container)
	SceneManager.load_stage()
