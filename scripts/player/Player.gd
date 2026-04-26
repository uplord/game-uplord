extends CharacterBody2D

@export var speed = 400
@export var skin_color: Color = Color(0.996, 0.82, 0.518, 1.0)

@onready var body = $Model/Body

var current_class: ClassData
var target: Vector2

var base_sprites: Array = []
var equipment_sprites: Array = []

# --------------------------------------------------
# READY
# --------------------------------------------------
func _ready():
	add_to_group("player")

	if body == null:
		push_error("Body node not found! Check your node path.")
		return

	base_sprites = find_all_base_sprites(body)
	equipment_sprites = find_all_armour_sprites(body)

	apply_class(PlayerData.equipped_class)
	apply_skin_color()

	target = position

# --------------------------------------------------
# FIND BASE SPRITES (for skin color)
# --------------------------------------------------
func find_all_base_sprites(node):
	if node == null:
		return []

	var results: Array = []

	for child in node.get_children():
		if child is Sprite2D and child.name == "Base":
			results.append(child)

		results += find_all_base_sprites(child)

	return results

# --------------------------------------------------
# FIND ALL EQUIPMENT SPRITES
# --------------------------------------------------
func find_all_armour_sprites(node):
	if node == null:
		return []

	var results: Array = []

	for child in node.get_children():
		if child is Sprite2D and child.name == "Armour":
			results.append(child)

		results += find_all_armour_sprites(child)

	return results

# --------------------------------------------------
# APPLY SKIN COLOR
# --------------------------------------------------
func apply_skin_color():
	if base_sprites.is_empty():
		print("No Base sprites found.")
		return

	for sprite in base_sprites:
		var mat = sprite.material
		if mat:
			mat.set_shader_parameter("skin_color", skin_color)

# --------------------------------------------------
# APPLY CLASS
# --------------------------------------------------
func apply_class(class_data: ClassData):
	if class_data == null:
		print("No class equipped.")
		return

	current_class = class_data
	print("Player is now a ", class_data.name)

	apply_equipment_textures(class_data)

# --------------------------------------------------
# APPLY EQUIPMENT TEXTURES (AUTO SYSTEM)
# --------------------------------------------------
func apply_equipment_textures(class_data: ClassData):
	if class_data == null:
		return

	var class_id = class_data.id.to_lower()

	for sprite in equipment_sprites:
		var parent = sprite.get_parent()
		if parent == null:
			continue

		var slot = parent.name.to_lower()
		var item = sprite.name.to_lower()

		var path = "res://resources/items/classes/%s/%s/%s.png" % [class_id, slot, item]

		# ✅ CHECK FILE EXISTS FIRST (prevents engine error)
		if not ResourceLoader.exists(path):
			# silently skip missing gear piece
			continue

		var tex = load(path)
		if tex:
			sprite.texture = tex

# --------------------------------------------------
# INPUT
# --------------------------------------------------
func _input(event):
	if event.is_action_pressed("Click"):
		var hovered = get_viewport().gui_get_hovered_control()
		if hovered:
			return

		if get_parent():
			target = get_parent().to_local(get_global_mouse_position())

# --------------------------------------------------
# MOVEMENT
# --------------------------------------------------
func _physics_process(_delta):
	if position.distance_to(target) > 10:
		var dir = position.direction_to(target)
		velocity = dir * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO

	z_index = int(global_position.y)
