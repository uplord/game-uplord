extends Node

@onready var container = $SceneContainer
@onready var ui = $UI

@onready var label_stage = $UI/Labels/LabelStage
@onready var label_scene = $UI/Labels/LabelScene
@onready var label_count = $UI/Labels/LabelStageCount

var stage_loaded := false

func _ready():
	SceneManager.setup(container)
	ui.visible = false
	
	ServerManager.server_lost.connect(_on_server_lost)
	ServerManager.server_ready.connect(_on_server_ready)

	if ServerManager.is_ready():
		_on_server_ready()

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
	update_ui()

func update_ui():
	label_stage.text = "%s-%d" % [
		SceneManager.current_stage,
		SceneManager.current_instance
	]

	label_scene.text = SceneManager.current_scene
	label_count.text = "Players: %d" % SceneManager.instance_player_count
