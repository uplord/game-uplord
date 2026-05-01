extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func teleport_player(target_stage: String, target_scene: String, target_teleport: String, exit_direction := Vector2.RIGHT):
	print("teleport_player")
	#if scene_transitioning:
		#return
#
	#if player == null:
		#return
#
	#if player.spawn_protection or not player.can_teleport:
		#return
#
	#player.lock_teleport()
	#player.stop_movement()
#
	#var stage = target_stage if target_stage != "" else current_stage
	#var scene = target_scene if target_scene != "" else current_scene
	#
	#ServerManager.send_to_server({
		#"type": "c_msg",
		#"text": "Teleport - %s - %s" % [stage, scene]
	#})
#
	## -------------------------
	## SCENE CHANGE
	## -------------------------
	#if stage != current_stage or scene != current_scene:
		#current_stage = stage
		#current_scene = scene
#
		#var new_stage = load_stage(Vector2.INF)
#
		#var pos = resolve_position(new_stage, target_teleport)
		#player.global_position = pos
#
	## -------------------------
	## SAME SCENE TELEPORT
	## -------------------------
	#else:
		#var pos = resolve_position(selected_stage, target_teleport)
		#player.global_position = pos
#
	## -------------------------
	## EXIT DIRECTION
	## -------------------------
	#player.set_facing(exit_direction)
#
	#await get_tree().process_frame
#
	#await get_tree().create_timer(0.3).timeout
	#player.unlock_teleport()


#func resolve_position(node: Node, teleport_name: String) -> Vector2:
	#if teleport_name == null or teleport_name == "":
		#return spawn_player_random_unused()
#
	#var receiver = node.find_child(teleport_name, true, false)
	#if receiver:
		#return receiver.global_position
#
	#return resolve_fallback_spawn(node)


#func resolve_fallback_spawn(node: Node) -> Vector2:
	#var spawn_parent = node.get_node_or_null("SpawnPoints")
	#if spawn_parent:
		#for s in spawn_parent.get_children():
			#if s is Area2D:
				#return s.global_position
#
	#return Vector2.ZERO
