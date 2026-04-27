extends Node2D
class_name BaseStage

var player: Player

@export var scene_speed := 600


func set_player(p: Player) -> void:
	player = p
	_on_player_ready()


func _on_player_ready() -> void:
	# override in child scenes if needed
	if player:
		player.speed = scene_speed
