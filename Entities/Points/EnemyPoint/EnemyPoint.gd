extends Area2D

enum Direction { LEFT, RIGHT }
enum EnemyState { IDLE, RUN }

@export var enemy_name: String = ""
@export var direction: Direction = Direction.RIGHT
@export var enemy_state: EnemyState = EnemyState.IDLE
@export var enemy_scale:= 1.0

func get_state_name() -> String:
	return EnemyState.keys()[enemy_state].to_lower()
