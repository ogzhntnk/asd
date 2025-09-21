extends AnimatedSprite2D


@export var _button_count : int
@export var _door : AnimatedSprite2D
@onready var static_body_2d: StaticBody2D = $StaticBody2D


func _on_area_2d_area_entered(area: Area2D) -> void:
	play("default")
	_door.play("default")


func _on_area_2d_area_exited(area: Area2D) -> void:
	play_backwards("default")
	_door.play_backwards("default")

func _on_area_2d_body_entered(body: Node2D) -> void:
	play("default")
	_door.play("default")
	if _door.animation_finished:
		pass


func _on_area_2d_body_exited(body: Node2D) -> void:
	play_backwards("default")
	_door.play_backwards("default")
