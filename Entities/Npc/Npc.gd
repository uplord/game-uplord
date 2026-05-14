
extends Node2D
class_name Npc

@onready var body = $Base/Model

var animation_tree: AnimationTree
var animation_state: AnimationNodeStateMachinePlayback
var current_anim := ""

func _ready():

	# Wait for dynamic model to be instanced
	await get_tree().process_frame

	var model = body.get_model_root()

	if model == null:
		push_error("Model not loaded yet")
		return

	animation_tree = model.get_node_or_null("AnimationTree")

	if animation_tree == null:
		push_error("AnimationTree not found inside model")
		return

	animation_tree.active = true
	animation_state = animation_tree["parameters/playback"]

	play_anim("run")

# -------------------------
# ANIMATION HANDLER
# -------------------------
func play_anim(anim_name: String) -> void:
	if animation_state == null:
		return

	if current_anim == anim_name:
		return

	current_anim = anim_name
	animation_state.travel(anim_name)

func _physics_process(_delta):
	_apply_z_sort()

func set_direction(dir: int):
	if body == null:
		body = $Base/Model

	body.scale.x = -1 if dir == 0 else 1

func _apply_z_sort():
	var base = int(global_position.y)

	z_index = base
