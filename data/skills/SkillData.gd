class_name SkillData
extends Resource

@export var id: String
@export var name: String
@export var description: String

@export var damage_multiplier: float = 1.0
@export var cooldown: float = 1.0
@export var mana_cost: int = 0

@export var skill_type: String # "damage", "buff", "heal"

@export var applies_status: String = "" # burn, slow, etc.
@export var status_duration: float = 0.0

@export var icon: Texture2D
