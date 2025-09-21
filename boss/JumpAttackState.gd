extends BossState

var jump_positions: Array = []
var current_jump_index: int = 0
var jump_timer: Timer
var is_jumping: bool = false
var is_waiting_on_platform: bool = false

# Jump sistemi değişkenleri
var jump_segments: int = 1
var damage_multiplier: float = 1.0
var jump_height_multiplier: float = 1.0

func enter():
	super()
	boss.animated_sprite.play("jump_prepare")
	boss.set_state_cooldown("JumpAttackState", 1.0)
	
	if not jump_timer:
		jump_timer = Timer.new()
		jump_timer.wait_time = 0.5
		jump_timer.one_shot = true
		jump_timer.timeout.connect(Callable(self, "_on_jump_timer_timeout"))
		boss.add_child(jump_timer)
		jump_timer.name = "TimerJump"
	
	current_jump_index = 0
	is_jumping = false
	is_waiting_on_platform = false
	
	_calculate_jump_positions()

func _calculate_jump_positions():
	if not boss.player:
		return
	
	var boss_pos = boss.global_position
	var player_pos = boss.player.global_position
	
	var total_distance = abs(player_pos.x - boss_pos.x)
	
	if total_distance < 200:
		jump_segments = 1
		damage_multiplier = 1.0
		jump_height_multiplier = 0.8
	elif total_distance < 400:
		jump_segments = 2
		damage_multiplier = 1.1
		jump_height_multiplier = 0.9
	elif total_distance < 600:
		jump_segments = 3
		damage_multiplier = 1.2
		jump_height_multiplier = 1.0
	else:
		jump_segments = 4
		damage_multiplier = 1.3
		jump_height_multiplier = 1.1
	
	var x_step = total_distance / float(jump_segments)
	
	jump_positions.clear()
	
	for i in range(jump_segments):
		var segment_number = i + 1
		
		var jump_x: float
		if player_pos.x > boss_pos.x:
			jump_x = boss_pos.x + (x_step * segment_number)
		else:
			jump_x = boss_pos.x - (x_step * segment_number)
		
		var default_y = boss_pos.y
		if boss.is_on_floor():
			default_y = boss.get_floor_position().y if boss.has_method("get_floor_position") else boss_pos.y
		
		var final_y = _find_platform_at_x(jump_x, default_y)
		
		var jump_pos = Vector2(jump_x, final_y)
		jump_positions.append(jump_pos)


func _find_platform_at_x(target_x: float, default_y: float) -> float:
	var space_state = boss.get_world_2d().direct_space_state
	
	var ray_start = Vector2(target_x, default_y - 50)
	var ray_end = Vector2(target_x, default_y + 200)
	
	var query = PhysicsRayQueryParameters2D.new()
	query.from = ray_start
	query.to = ray_end
	query.collision_mask = 1 << 4
	query.exclude = [boss]
	
	var result = space_state.intersect_ray(query)
	
	if result and result.has("position"):
		return result.position.y
	else:
		return default_y

func process_frame(delta: float):
	super(delta)
	
	if state_timer < 1.0:
		boss.velocity.x = 0
	elif state_timer < 1.2 and not is_jumping and not is_waiting_on_platform:
		_perform_current_jump()

func _perform_current_jump():
	if current_jump_index >= jump_positions.size():
		_finish_jump_attack()
		return
	
	var target_pos = jump_positions[current_jump_index]
	var boss_pos = boss.global_position
	
	var horizontal_distance = target_pos.x - boss_pos.x
	
	var direction = 1 if horizontal_distance > 0 else -1
	
	var base_speed = 300
	var horizontal_speed = clamp(abs(horizontal_distance) * 3.0, 150, base_speed)
	
	horizontal_speed *= 0.6
	
	boss.velocity.x = direction * horizontal_speed
	boss.velocity.y = -abs(boss.jump_force) * jump_height_multiplier
	
	boss.animated_sprite.play("jump")
	is_jumping = true

func _physics_process(delta):
	if is_jumping and boss.is_on_floor():
		is_jumping = false
		is_waiting_on_platform = true
		
		boss.velocity.x = 0
		
		if current_jump_index < jump_positions.size() - 1:
			if jump_timer:
				jump_timer.start()
		else:
			_finish_jump_attack()

func _on_jump_timer_timeout():
	current_jump_index += 1
	is_waiting_on_platform = false
	_perform_current_jump()

func _finish_jump_attack():
	var base_damage = boss.jump_attack_damage
	var damage_range = 120 + (jump_segments * 20)
	
	if boss.distance_to_player <= damage_range:
		if boss.player.has_method("take_damage_from_source"):
			boss.player.take_damage_from_source(boss)
	
	boss.animated_sprite.play("land")
	
	await boss.get_tree().create_timer(1.5).timeout
	state_machine.change_state("IdleState")

func exit():
	super()
	jump_positions.clear()
	current_jump_index = 0
	is_jumping = false
	is_waiting_on_platform = false
	boss.velocity.x = 0
