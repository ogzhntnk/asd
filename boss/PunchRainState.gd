extends BossState

var spawned_left: bool = false
var spawned_right: bool = false

func enter():
	super()
	boss.animated_sprite.play("punch_rain_start")
	boss.velocity.x = 0
	spawned_left = false
	spawned_right = false

func process_frame(delta: float):
	super(delta)
	
	if state_timer > 0.5 and not spawned_left:
		boss.spawn_punch_rain()
		spawned_left = true
		spawned_right = true 
		boss.set_state_cooldown("PunchRainState", 3.0)
	
	elif state_timer > 2.0:
		state_machine.change_state("IdleState")

func exit():
	super()
	spawned_left = false
	spawned_right = false
