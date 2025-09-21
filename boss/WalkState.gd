extends BossState

var movement_pattern: int = 0 
var random_direction: int = 1

func enter():
	super()
	boss.animated_sprite.play("walk")
	movement_pattern = 0 if randf() < 0.7 else 1
	
	if movement_pattern == 1:
		random_direction = 1 if randf() < 0.5 else -1
		print("🚶 WalkState başladı - RASTGELE yön: %s" % ("Sağ" if random_direction == 1 else "Sol"))
	else:
		print("🚶 WalkState başladı - PLAYER'A DOĞRU hareket")

func process_frame(delta: float):
	super(delta)
	
	var direction: int
	
	if movement_pattern == 0:
		var diff = boss.player.global_position.x - boss.global_position.x
		print("Diff: ", diff)
		if abs(diff) < 1.0:
			direction = 0  # Çok yakınsa hareket etme
		else:
			direction = 1 if diff > 0 else -1
	else:
		direction = random_direction

	boss.velocity.x = direction * boss.speed
	
	boss.animated_sprite.flip_h = direction < 0
	
	
	if int(state_timer) != int(state_timer - delta):
		print("🏃 Boss hareket - Pattern: %s, Yön: %d, Velocity: %.1f" % [
			"Player'a doğru" if movement_pattern == 0 else "Rastgele", 
			direction, 
			boss.velocity.x
		])
	
	# 3 saniye yürüme veya çok yaklaşma
	if state_timer > 3.0 or (movement_pattern == 0 and boss.distance_to_player < 100):
		print("✅ WalkState tamamlandı")
		state_machine.change_state("IdleState")

func exit():
	super()
	boss.velocity.x = 0
