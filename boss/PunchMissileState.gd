extends BossState

var missiles_spawned: bool = false

func enter():
	super()
	#boss.animated_sprite.play("punch_missile_start")
	boss.velocity.x = 0
	missiles_spawned = false

func process_frame(delta: float):
	super(delta)
	
	if state_timer > 0.5 and not missiles_spawned:
		boss.spawn_punch_missiles()
		missiles_spawned = true
		boss.set_state_cooldown("PunchMissileState", 5.0)  # 5 saniye cooldown
	elif state_timer > 2.0:
		state_machine.change_state("IdleState")

func exit():
	super()
	missiles_spawned = false
