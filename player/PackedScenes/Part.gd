extends RigidBody2D

@export var part_name: String = ""

@onready var area: Area2D = $Area2D

signal player_entered_part_area(part_name)
signal player_exited_part_area(part_name)

func _ready():
	area.connect("body_entered", Callable(self, "_on_area_body_entered"))
	area.connect("body_exited", Callable(self, "_on_area_body_exited"))

func _on_area_body_entered(body):
	if body.name == "Player":
		emit_signal("player_entered_part_area", part_name)

func _on_area_body_exited(body):
	if body.name == "Player":
		emit_signal("player_exited_part_area", part_name)
