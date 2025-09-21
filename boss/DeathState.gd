extends BossState

func enter():
	super()
	boss.animated_sprite.play("death")  
	boss.velocity.x = 0
	
	# Collision'ı kapat
	boss.set_collision_layer_value(2, false)
	boss.hitbox.set_collision_layer_value(4, false)

func process_frame(delta: float):
	super(delta)
	if state_timer > 3.0:
		boss.queue_free()
