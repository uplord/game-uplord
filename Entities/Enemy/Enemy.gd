extends Node2D
class_name Enemy

@onready var body = $Base/Model

var animation_tree: AnimationTree
var animation_state: AnimationNodeStateMachinePlayback
var current_anim := ""
var pending_state := ""

func _ready():

	var model = body.get_model_root()

	if model == null:
		push_error("Model not loaded yet")
		return

	animation_tree = model.get_node_or_null("AnimationTree")

	if animation_tree == null:
		push_error("AnimationTree not found inside model")
		return

	animation_state = animation_tree["parameters/playback"]

	# IMPORTANT:
	# start state BEFORE activation
	if pending_state != "":
		current_anim = pending_state
		animation_state.start(pending_state)

	animation_tree.active = true

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
	$Base.scale.x = -1 if dir == 0 else 1
	
func set_state(state):

	pending_state = state

	# already initialized
	if animation_state != null:
		play_anim(state)

func _apply_z_sort():
	var base = int(global_position.y)

	z_index = base
