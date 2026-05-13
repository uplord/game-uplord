extends Node

class_name InstanceManager

var ServerConfig = preload("res://Config/ServerConfig.gd")

var server_manager: Node
var logger: Node

var instance_population := {}
var used_spawn_ids := {}
var spawn_points_cache := {}


func _ready() -> void:
	pass


func setup(sm: Node, logger_ref: Node) -> void:
	server_manager = sm
	logger = logger_ref


func _get_instance_key(stage: String, instance: int) -> String:
	return "%s::%d" % [stage, instance]


func get_instance_limit(stage: String) -> int:
	var path = "res://Stages/%s/%s.tscn" % [stage, stage]
	var packed = load(path)

	if packed == null:
		logger.warn("Stage not found: %s, using default limit 3" % stage)
		return 3

	var temp = packed.instantiate()

	var limit := 3

	if "player_max" in temp:
		limit = temp.player_max

	temp.queue_free()
	return limit


func find_available_instance(stage: String) -> int:
	var instance := 1
	var limit := get_instance_limit(stage)

	while true:
		var key = _get_instance_key(stage, instance)

		if not instance_population.has(key):
			instance_population[key] = []
			return instance

		if instance_population[key].size() < limit:
			return instance

		instance += 1
		
		# Safety check to prevent infinite loops
		if instance > ServerConfig.MAX_INSTANCES_PER_STAGE:
			logger.warn("Max instances reached for stage: %s" % stage)
			return 1

	return 1


func remove_from_instance(client_id: int) -> void:
	for key in instance_population.keys():
		if instance_population[key].has(client_id):
			instance_population[key].erase(client_id)

			if instance_population[key].is_empty():
				instance_population.erase(key)


func get_spawn_points(stage: String, scene: String) -> Array:
	var key = "%s::%s" % [stage, scene]

	if not spawn_points_cache.has(key):
		spawn_points_cache[key] = SceneManager.get_spawn_points_for_room(stage, scene)

	return spawn_points_cache[key]


func free_spawn(client_id: int) -> void:
	for key in used_spawn_ids.keys():
		if used_spawn_ids[key].has(client_id):
			used_spawn_ids[key].erase(client_id)

			if used_spawn_ids[key].is_empty():
				used_spawn_ids.erase(key)


func get_spawn_position(client_id: int, stage: String, scene: String, instance: int) -> Vector2:
	var key = _get_instance_key(stage, instance)

	if not used_spawn_ids.has(key):
		used_spawn_ids[key] = {}

	var instance_spawns = used_spawn_ids[key]
	var points = get_spawn_points(stage, scene)

	if points.is_empty():
		logger.warn("No spawn points found for %s::%s" % [stage, scene])
		return Vector2.ZERO

	var available := []

	for i in range(points.size()):
		if not instance_spawns.values().has(i):
			available.append(i)

	var chosen: int
	if available.is_empty():
		chosen = randi() % points.size()
	else:
		chosen = available.pick_random()

	instance_spawns[client_id] = chosen
	return points[chosen]


func get_instance_remote_players(stage: String, instance: int) -> Dictionary:
	var result := {}

	for client_id in server_manager.remote_players.keys():
		var p = server_manager.remote_players[client_id]

		if typeof(p) != TYPE_DICTIONARY:
			continue

		if p.get("stage") != stage:
			continue
		if p.get("instance") != instance:
			continue

		result[client_id] = p

	return result
