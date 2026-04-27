extends Area2D

var occupied := false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		occupied = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		occupied = false
