extends AnimatedSprite2D



func _on_area_2d_area_entered(area: Area2D) -> void:
	play("default")


func _on_area_2d_area_exited(area: Area2D) -> void:
	play_backwards("default")
