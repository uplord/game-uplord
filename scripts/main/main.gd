extends Node

@onready var container = $SceneContainer

func _ready():
	SceneLoader.setup(container)
	SceneLoader.load_scene("res://scenes/maps/StarterTown/Screen1.tscn")
	SceneLoader.spawn_player_at_node("SpawnPoint")
