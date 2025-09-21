extends BossState

func enter():
	super()
	boss.animated_sprite.play("idle")
	boss.velocity.x = 0

func process_frame(delta: float):
	super(delta)
	
	if state_timer > 1.0:  # 1 saniye idle
		_choose_next_action()

func _choose_next_action():
	var distance = boss.distance_to_player
	var possible_actions = []

	possible_actions.append("JumpAttackState")
	possible_actions.append("JumpDodgeState")
	
	# Mesafe bazlı + cooldown + logic bazlı saldırı seçimi
	if distance > 300:  # Uzakta
		possible_actions.append("WalkState")
		if boss.can_use_state("PunchRainState"):
			possible_actions.append("PunchRainState")
		if boss.can_use_state("PunchMissileState"):
			possible_actions.append("PunchMissileState")
	elif distance > 150:  # Orta mesafe
		possible_actions.append("WalkState")
		if boss.can_use_state("PunchMissileState"):
			possible_actions.append("PunchMissileState")
		if boss.can_use_state("PunchRainState"):
			possible_actions.append("PunchRainState")
	else:  # Çok yakın - JUMP'LARI FAZLA EKLEYELİM
		possible_actions.append("JumpAttackState")
		possible_actions.append("JumpAttackState")  # Çift eklendi
		possible_actions.append("JumpDodgeState")
		if boss.can_use_state("PunchRainState"):
			possible_actions.append("PunchRainState")
	
	
	# Rastgele seç
	if possible_actions.size() > 0:
		var chosen = possible_actions[randi() % possible_actions.size()]
		boss.update_last_state(chosen)
		state_machine.change_state(chosen)
	else:
		boss.update_last_state("WalkState")
		state_machine.change_state("WalkState")
