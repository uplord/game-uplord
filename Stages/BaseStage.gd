extends Node2D
class_name BaseStage

var player: Player

@export var player_speed := 600
@export var player_scale := 1.0
@export var allow_player_movement := true
@export var player_max := 2


func set_player(p: Player) -> void:
	player = p
	_on_player_ready()

  
func _on_player_ready() -> void:
	# override in child scenes if needed
	if player:
		player.speed = player_speed
		player.scale = Vector2(player_scale, player_scale)
		player.set_movement_enabled(allow_player_movement)
