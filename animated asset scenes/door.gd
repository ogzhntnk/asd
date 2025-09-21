extends AnimatedSprite2D




func _on_area_2d_area_entered(area: Area2D) -> void:
	play("default")


func _on_area_2d_area_exited(area: Area2D) -> void:
	play_backwards("default")


func _on_area_2d_body_entered(body: Node2D) -> void:
	play("default")
	if animation_finished:
		print("kapandı")
func _on_area_2d_body_exited(body: Node2D) -> void:
	play_backwards("default")
