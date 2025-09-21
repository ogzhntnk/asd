extends StaticBody2D

var _animation_finished := false
func _process(delta: float) -> void:
	if _animation_finished:
		set_process_mode(Node.PROCESS_MODE_DISABLED)
