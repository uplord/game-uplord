extends Node

@export_enum("Humanoid") var model_type: String = "Humanoid"

var selected_model: Node


func _ready() -> void:
	load_model()


func load_model() -> void:
	var model_path = "res://Entities/Models/%s/%s.tscn" % [model_type, model_type]

	var packed_model = load(model_path)

	if packed_model == null:
		print("Failed to load model:", model_path)
		return

	selected_model = packed_model.instantiate()
	add_child(selected_model)


func get_model_root() -> Node:
	return selected_model
