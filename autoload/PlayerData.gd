extends Node

var player_name: String = "Player"

var gold: int = 0
var level: int = 1
var xp: int = 0

var unlocked_classes: Array[ClassData] = []
var equipped_class: ClassData = null

func _ready():
	var knight = load("res://data/classes/darkknight.tres")
	unlock_class(knight)
	equip_class(knight)

func unlock_class(class_data: ClassData):
	if not unlocked_classes.has(class_data):
		unlocked_classes.append(class_data)

func equip_class(class_data: ClassData):
	if class_data == null:
		return

	if not unlocked_classes.has(class_data):
		print("You do not own this class.")
		return

	equipped_class = class_data
	print("Equipped class: ", equipped_class.name)
