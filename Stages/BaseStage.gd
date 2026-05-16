extends Node2D
class_name BaseStage

var player: Player
var remote_player: RemotePlayer
var enemy: Enemy
var npc: Npc

@export var player_speed := 600
@export var player_scale := 1.0
@export var allow_player_movement := true
@export var player_max := 3


func set_player(p: Player) -> void:
	player = p
	_on_player_ready()


func _on_player_ready() -> void:
	if not player:
		return

	player.speed = player_speed
	player.scale = Vector2(player_scale, player_scale)
	player.set_movement_enabled(allow_player_movement)


func set_remote_player(p: RemotePlayer) -> void:
	remote_player = p
	_on_remote_player_ready()


func _on_remote_player_ready() -> void:
	if not remote_player:
		return

	remote_player.scale = Vector2(player_scale, player_scale)
