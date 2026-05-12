extends Node

var server_manager: Node

func _ready() -> void:
	pass


# ==================================================
# SERVER PACKETS
# ==================================================
func handle_server_packet(client_id: int, data: Dictionary):
	match data.type:

		"c_handshake":
			server_manager.connected_clients[client_id] = 0.0
			server_manager.remote_players[client_id] = {}

			server_manager.send_to_client(client_id, {
				"type": "s_handshake_ack",
				"client_id": client_id,
			})


		"c_heartbeat":
			if server_manager.connected_clients.has(client_id):
				server_manager.connected_clients[client_id] = 0.0


		"c_leave":
			server_manager.handle_disconnect(client_id, "requested leave")


		"c_spawn_player":
			server_manager._free_spawn(client_id)
			server_manager._remove_from_instance(client_id)

			var stage = SceneManager.current_stage
			var scene = SceneManager.current_scene

			# ALWAYS assign instance based on STAGE ONLY
			var instance = server_manager.find_available_instance(stage)
			var key = server_manager._get_instance_key(stage, instance)

			if not server_manager.instance_population.has(key):
				server_manager.instance_population[key] = []

			server_manager.instance_population[key].append(client_id)

			# print("STAGE: ", stage, "-", instance, " : SCENE: ", scene)

			var spawn_position = server_manager.get_spawn_position(client_id, stage, scene, instance)

			server_manager.remote_players[client_id] = {
				"position": spawn_position,
				"direction": SceneManager.player.get_direction(),
				"stage": stage,
				"scene": scene,
				"instance": instance,
				"instance_count": server_manager.instance_population[key].size()
			}

			server_manager.send_to_client(client_id, {
				"type": "s_spawn_player",
				"spawn_position": spawn_position,
				"instance": instance,
				"instance_count": server_manager.instance_population[key].size()
			})

			server_manager.broadcast_to_instance(stage, instance, {
				"type": "s_remote_players",
				"id": client_id,
				"remote_players": server_manager.get_instance_remote_players(stage, instance)
			})

		"c_move_player":
			var stage = data.stage
			var scene = data.scene
			var instance = data.instance

			# optional: keep spawn validation (your existing logic)
			var key = server_manager._get_instance_key(stage, instance)

			if server_manager.used_spawn_ids.has(key) and server_manager.used_spawn_ids[key].has(client_id):
				var spawn_id = server_manager.used_spawn_ids[key][client_id]
				var spawn_pos = server_manager.get_spawn_points(stage, scene)[spawn_id]

				if data.position.distance_to(spawn_pos) > server_manager.spawn_radius:
					server_manager.used_spawn_ids[key].erase(client_id)

			server_manager.remote_players[client_id] = {
				"position": data.position,
				"direction": data.direction,
				"stage": stage,
				"scene": scene,
				"instance": instance,
				"instance_count": server_manager.instance_population[key].size()
			}

			server_manager.broadcast_to_instance(stage, instance, {
				"type": "s_remote_players",
				"id": client_id,
				"remote_players": server_manager.get_instance_remote_players(stage, instance)
			})

		"c_teleport_player":
			var target_stage = data.stage if data.stage != "" else SceneManager.current_stage
			var target_scene = data.scene if data.scene != "" else SceneManager.current_scene

			server_manager._free_spawn(client_id)
			server_manager._remove_from_instance(client_id)

			# 🔥 NEW RULE: stage change = new instance
			var instance: int
			var old_stage: String = server_manager.remote_players[client_id]["stage"]
			var old_scene: String = server_manager.remote_players[client_id]["scene"]
			var old_instance: int = server_manager.remote_players[client_id]["instance"]

			if server_manager.is_new_stage(client_id, target_stage):
				instance = server_manager.find_available_instance(target_stage)
			else:
				instance = server_manager.remote_players[client_id]["instance"]


			var key = server_manager._get_instance_key(target_stage, instance)
			if not server_manager.instance_population.has(key):
				server_manager.instance_population[key] = []

			server_manager.instance_population[key].append(client_id)

			# print("STAGE: ", target_stage, "-", instance, " : SCENE: ", target_scene)

			var position = SceneManager.resolve_teleport_position(
				target_stage,
				target_scene,
				data.teleport
			)

			if position == Vector2.ZERO:
				position = server_manager.get_spawn_position(client_id, target_stage, target_scene, instance)

			server_manager.remote_players[client_id] = {
				"position": position,
				"direction": data.direction.x,
				"stage": target_stage,
				"scene": target_scene,
				"instance": instance,
				"instance_count": server_manager.instance_population[key].size()
			}

			server_manager.send_to_client(client_id, {
				"type": "s_teleport_player",
				"position": position,
				"direction": data.direction,
				"stage": target_stage,
				"scene": target_scene,
				"instance": instance,
				"instance_count": server_manager.instance_population[key].size()
			})

			server_manager.broadcast_to_instance(old_stage, old_instance, {
				"type": "s_remote_players",
				"id": client_id,
				"remote_players": server_manager.get_instance_remote_players(old_stage, old_instance)
			})

			server_manager.broadcast_to_instance(target_stage, instance, {
				"type": "s_remote_players",
				"id": client_id,
				"remote_players": server_manager.get_instance_remote_players(target_stage, instance)
			})


# ==================================================
# CLIENT PACKETS
# ==================================================
func handle_client_packet(data: Dictionary):
	match data.type:

		"s_remove":
			print("Removed:", data.id)

		"s_spawn_player":
			SceneManager.current_instance = data.instance
			SceneManager.player.reset_teleport_state()
			SceneManager.player.visible = true
			SceneManager.player.respawn(data.spawn_position)
			SceneManager.player.stop_movement()
			SceneManager.player.set_facing(Vector2(1, 0))

			GameManager.update_ui()

		"s_handshake_ack":
			server_manager.connected = true
			server_manager.local_peer_id = data.client_id
			server_manager.server_ready.emit()

		"s_remote_players":
			SceneManager.spawn_remote_players(data.remote_players)

		"s_teleport_player":

			SceneManager.apply_teleport(
				data.stage,
				data.scene,
				data.position,
				data.direction,
				data.instance
			)

			GameManager.update_ui()
