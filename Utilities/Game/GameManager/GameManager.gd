extends Node

@onready var container = $SceneContainer
@onready var ui = $UI

var stage_loaded := false

func _ready():
	SceneManager.setup(container)
	
	ui.visible = false
	
	ServerManager.server_lost.connect(_on_server_lost)

	if ServerManager.is_ready():
		SceneManager.load_stage()
		return

	ServerManager.server_ready.connect(_on_server_ready)


func _on_server_ready():
	if stage_loaded:
		return

	stage_loaded = true
	SceneManager.load_stage()
	ui.visible = true

func _on_server_lost():
	stage_loaded = false
	SceneManager.unload_stage()
	ui.visible = false


func _on_repawn_pressed() -> void:
	SceneManager.respawn_player()
