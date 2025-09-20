extends CharacterBody2D

# --- Enemy Stats ---
@export var damage: int = 20
@export var enemy_health: int = 75
@export var move_speed: float = 40.0
@export var attack_range: float = 250.0

# --- Attack Settings ---
@export var fire_rate: float = 2.5
@export var laser_bullet_scene: PackedScene

# --- Patrol Settings ---
@export var patrol_radius: float = 150.0
@export var direction_change_time: float = 3.0

# --- State Machine ---
enum AIState { IDLE, PATROL, CHASE, ATTACK, RETREAT }
var current_state: AIState = AIState.IDLE
var state_timer: float = 0.0

# --- Node References ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_timer: Timer = $AttackTimer
@onready var direction_timer: Timer = $DirectionTimer

# --- AI Variables ---
var player: Node2D = null
var can_attack: bool = true
var patrol_center: Vector2
var current_direction: Vector2

# --- Debug ---
var debug_mode: bool = true

func _ready():
	find_player()
	setup_timers()
	setup_patrol()
	change_state(AIState.IDLE)
	
	if sprite:
		sprite.play("idle")
	
	print("Flying Eye hazır - State Machine sistemi")

func find_player():
	player = get_tree().get_first_node_in_group("player")
	if not player:
		player = get_node_or_null("../Player")
	
	if player:
		print("Player bulundu:", player.name)

func setup_timers():
	# Attack timer
	if attack_timer:
		attack_timer.wait_time = fire_rate
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	# Direction change timer
	if direction_timer:
		direction_timer.wait_time = direction_change_time
		direction_timer.one_shot = false
		direction_timer.timeout.connect(_on_direction_timer_timeout)
		direction_timer.start()

func setup_patrol():
	patrol_center = global_position
	choose_random_direction()

func choose_random_direction():
	# Rastgele yön seç
	var angle = randf() * TAU  # 0 ile 2π arasında
	current_direction = Vector2(cos(angle), sin(angle))
	print("Yeni patrol yönü: ", current_direction)

func _physics_process(delta):
	if not player:
		find_player()
		return

	state_timer += delta
	update_state_machine()
	execute_current_state()
	update_sprite_direction()
	
	move_and_slide()

	if debug_mode:
		debug_info()

# === STATE MACHINE ===

func update_state_machine():
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	match current_state:
		AIState.IDLE:
			if state_timer > 1.0:  # 1 saniye idle sonra patrol
				change_state(AIState.PATROL)
		
		AIState.PATROL:
			if distance_to_player <= attack_range:
				change_state(AIState.CHASE)
		
		AIState.CHASE:
			if distance_to_player <= attack_range * 0.8:  # 200px
				change_state(AIState.ATTACK)
			elif distance_to_player > attack_range * 1.2:  # 300px - çok uzaklaştı
				change_state(AIState.PATROL)
		
		AIState.ATTACK:
			if distance_to_player < attack_range * 0.3:  # 75px - çok yakın
				change_state(AIState.RETREAT)
			elif distance_to_player > attack_range * 1.1:  # 275px - uzaklaştı
				change_state(AIState.CHASE)
		
		AIState.RETREAT:
			if distance_to_player > attack_range * 0.6:  # 150px - yeterli mesafe
				change_state(AIState.ATTACK)

func execute_current_state():
	match current_state:
		AIState.IDLE:
			execute_idle()
		
		AIState.PATROL:
			execute_patrol()
		
		AIState.CHASE:
			execute_chase()
		
		AIState.ATTACK:
			execute_attack()
		
		AIState.RETREAT:
			execute_retreat()

func execute_idle():
	# Yavaşça dur
	velocity = velocity.lerp(Vector2.ZERO, 0.1)

func execute_patrol():
	# Normal patrol hareketi
	patrol_movement()

func execute_chase():
	# Player'a doğru yaklaş
	if not player:
		return
	
	var to_player = (player.global_position - global_position).normalized()
	velocity = to_player * move_speed * 0.8  # Yaklaşma hızı

func execute_attack():
	# Player etrafında hareket et ve ateş et
	attack_movement()
	
	if can_attack:
		shoot_at_player()

func execute_retreat():
	# Player'dan uzaklaş
	if not player:
		return
	
	var away_from_player = (global_position - player.global_position).normalized()
	velocity = away_from_player * move_speed * 1.2  # Hızlı kaçış

func change_state(new_state: AIState):
	if current_state == new_state:
		return
	
	var state_names = ["IDLE", "PATROL", "CHASE", "ATTACK", "RETREAT"]
	print("State değişti: %s -> %s" % [state_names[current_state], state_names[new_state]])
	
	current_state = new_state
	state_timer = 0.0

func attack_movement():
	# Player etrafında sürekli hareket et
	if not player:
		return
	
	var to_player = player.global_position - global_position
	var distance = to_player.length()
	
	# Player'dan çok uzaktaysa yaklaş
	if distance > attack_range * 0.8:  # 200 pikselden uzaksa yaklaş
		var approach_direction = to_player.normalized()
		velocity = approach_direction * move_speed * 0.6
	# Player'a çok yakınsa uzaklaş
	elif distance < attack_range * 0.3:  # 75 pikselden yakınsa uzaklaş
		var retreat_direction = -to_player.normalized()
		velocity = retreat_direction * move_speed * 0.8
	else:
		# Optimal mesafede - player etrafında circular motion
		var perpendicular = Vector2(-to_player.y, to_player.x).normalized()
		velocity = perpendicular * move_speed * 0.5  # Yan hareket

func patrol_movement():
	# Patrol merkezi etrafında dolaş
	var distance_from_center = global_position.distance_to(patrol_center)
	
	# Çok uzaklaştıysa merkeze dön
	if distance_from_center > patrol_radius:
		var to_center = (patrol_center - global_position).normalized()
		velocity = to_center * move_speed
		print("Merkeze dönülüyor... Mesafe: ", distance_from_center)
	else:
		# Normal yönde hareket et
		velocity = current_direction * move_speed

func shoot_at_player():
	if not laser_bullet_scene or not can_attack:
		return
	
	can_attack = false
	attack_timer.start()
	
	var bullet = laser_bullet_scene.instantiate()
	if bullet:
		bullet.global_position = global_position
		
		# Player'a yönel
		var direction = (player.global_position - global_position).normalized()
		
		if bullet.has_method("set_velocity"):
			bullet.set_velocity(direction * 400)
		elif bullet.has_method("set_direction"):
			bullet.set_direction(direction * 400)
		
		get_tree().current_scene.add_child(bullet)
		print("Flying Eye ateş etti! Mesafe: ", global_position.distance_to(player.global_position))
		
		# Attack animasyonu - kısa süre sonra idle'a dön
		if sprite:
			sprite.play("laser_attack")
			# 0.3 saniye sonra idle animasyonuna dön
			await get_tree().create_timer(0.3).timeout
			if sprite and is_instance_valid(sprite):
				sprite.play("idle")

func update_sprite_direction():
	if not sprite:
		return
	
	# Her state için sprite yönü
	match current_state:
		AIState.IDLE:
			# Mevcut flip'i koru
			pass
		
		AIState.PATROL, AIState.CHASE:
			# Hareket yönüne bak
			if current_direction.x > 0:
				sprite.flip_h = true
			else:
				sprite.flip_h = false
		
		AIState.ATTACK, AIState.RETREAT:
			# Player'a bak
			if player:
				if player.global_position.x > global_position.x:
					sprite.flip_h = true
				else:
					sprite.flip_h = false

# === TIMER CALLBACKS ===

func _on_attack_timer_timeout():
	can_attack = true

# Eski fonksiyonları kaldır ve timer callback'i güncelle
func _on_direction_timer_timeout():
	if current_state == AIState.PATROL:
		choose_random_direction()

# === DAMAGE & COMBAT ===

func get_damage() -> int:
	return damage

func take_damage_from_bullet(bullet_damage: int):
	enemy_health -= bullet_damage
	print("Flying Eye hasar aldı! Hasar: ", bullet_damage, " | Kalan can: ", enemy_health)
	
	# Hurt efekti
	if sprite:
		sprite.modulate = Color.RED
		await get_tree().create_timer(0.2).timeout
		sprite.modulate = Color.WHITE
	
	if enemy_health <= 0:
		die()

func die():
	print("Flying Eye öldü!")
	
	if sprite:
		# Death animasyonu
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
		await tween.finished
	
	queue_free()

func _on_damage_area_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("take_damage_from_source"):
			body.take_damage_from_source(self)
		print("Flying Eye player'a çarptı!")

# === DEBUG ===

func debug_info():
	if not debug_mode:
		return
	
	var debug_label = get_node_or_null("DebugLabel")
	if debug_label:
		var player_distance = 0.0
		if player:
			player_distance = global_position.distance_to(player.global_position)
		
		var state_names = ["IDLE", "PATROL", "CHASE", "ATTACK", "RETREAT"]
		var current_state_name = state_names[current_state]
		
		var info = "State: %s | HP: %d | Dist: %.0f | Attack: %s | Timer: %.1f" % [
			current_state_name,
			enemy_health,
			player_distance,
			str(can_attack),
			state_timer
		]
		debug_label.text = info
