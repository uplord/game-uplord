extends Area2D

@export_file("*.tscn") var target_scene: String
@export var target_spawn_name: String = "SpawnPoint"

var changing_scene := false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if changing_scene:
		return

	if body.is_in_group("player"):
		changing_scene = true
		SceneLoader.load_scene(target_scene)
		SceneLoader.spawn_player_at_node("SpawnPoints/" + target_spawn_name)
