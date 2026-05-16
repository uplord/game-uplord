extends Area2D

enum Direction { LEFT, RIGHT }
enum NpcState { IDLE, RUN }

@export var npc_name: String = ""
@export var direction: Direction = Direction.RIGHT
@export var npc_state: NpcState = NpcState.IDLE
@export var npc_scale:= 1.0

func get_state_name() -> String:
	return NpcState.keys()[npc_state].to_lower()
