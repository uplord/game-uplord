extends Node2D
class_name BaseStage

var player: Player
var remote_player: RemotePlayer

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

	# apply gameplay values
	player.speed = player_speed
	player.scale = Vector2(player_scale, player_scale)
	player.set_movement_enabled(allow_player_movement)

	#var canvas_group := player.get_node_or_null("CanvasGroup")
	#if canvas_group and canvas_group.material is ShaderMaterial:
		#var mat := canvas_group.material as ShaderMaterial
		#mat.set_shader_parameter("scale_factor", player_scale)

func set_remote_player(p: RemotePlayer) -> void:
	remote_player = p
	_on_remote_player_ready()


func _on_remote_player_ready() -> void:
	if not remote_player:
		return

	remote_player.scale = Vector2(player_scale, player_scale)
	
	#var canvas_group := remote_player.get_node_or_null("CanvasGroup")
	#if canvas_group and canvas_group.material is ShaderMaterial:
		#var mat := canvas_group.material as ShaderMaterial
		#mat.set_shader_parameter("scale_factor", player_scale)
