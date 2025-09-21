extends BossState

var has_jumped: bool = false

func enter():
	super()
	has_jumped = false
	boss.velocity.x = 0

func process_frame(delta: float):
	super(delta)
	
	if not has_jumped and state_timer < 0.2:
		# Player'dan UZAĞA zıplama yönü hesapla
		var player_direction = sign(boss.player.global_position.x - boss.global_position.x)
		var escape_direction = -player_direction  # Ters yöne kaç
		
		# Daha düşük ve uzaklaşan zıplama
		boss.velocity.x = escape_direction * boss.speed * 1.2  # Yatay kaçış hızı
		boss.velocity.y = boss.jump_force * 0.5  # YARIM yükseklik (AttackJump'ın yarısı)
		boss.animated_sprite.play("jump")
		has_jumped = true
		

	elif has_jumped:
		# Yere inme kontrolü
		if boss.is_on_floor() and state_timer > 0.5:
			state_machine.change_state("IdleState")
		elif state_timer > 2.0:
			state_machine.change_state("IdleState")

func exit():
	super()
	has_jumped = false
	boss.velocity.x = 0
