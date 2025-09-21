extends CharacterBody2D
class_name Boss

# Hasar değerleri (özelleştirilebilir)
@export_group("Damage Values")
@export var punch_rain_damage: int = 15
@export var punch_missile_damage: int = 12  
@export var jump_attack_damage: int = 25
@export var contact_damage: int = 8

@export_group("Boss Stats")
@export var max_health: int = 200
@export var current_health: int = 200
@export var boss_name: String = "Iron Fist Boss"
@export var speed: float = 100.0
@export var jump_force: float = -600.0
@export var gravity: float = 980.0

@export_group("Projectiles")
@export var left_punch_scene: PackedScene
@export var right_punch_scene: PackedScene

@onready var animated_sprite = $AnimatedSprite2D
@onready var state_machine = $StateMachine
@onready var hitbox = $HitBox
@onready var punch_start_pos1 = $PunchStartPosition1
@onready var punch_start_pos2 = $PunchStartPosition2

# Sinyaller
signal health_changed(current_health: int, max_health: int)
signal boss_died()

@onready var player = get_node_or_null("../Player")
var distance_to_player: float = 0.0

# State cooldown sistemi
var state_cooldowns: Dictionary = {}
var last_state: String = ""
var same_state_count: int = 0

# Aktif projectile takibi
var active_projectiles: Array = []

# Contact damage timer (spam önlemek için)
var contact_damage_timer: float = 0.0
var contact_damage_cooldown: float = 0.5

func _ready():
	add_to_group("boss")
	
	# HitBox sinyalini bağla - boss'un player'a verdiği hasar için
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		hitbox.body_exited.connect(_on_hitbox_body_exited)
	
	# State machine'i başlat
	state_machine.init(self)
	
	# Cooldown'ları başlat
	_reset_cooldowns()
	
	print("🤖 Boss hazır! Can: %d/%d" % [current_health, max_health])

func _reset_cooldowns():
	state_cooldowns = {
		"PunchRainState": 0.0,
		"PunchMissileState": 0.0, 
		"JumpAttackState": 0.0
	}

func _physics_process(delta):
	if not player:
		return
	
	# Player'a olan mesafeyi hesapla
	distance_to_player = global_position.distance_to(player.global_position)
	
	# Cooldown'ları güncelle
	for state_name in state_cooldowns.keys():
		if state_cooldowns[state_name] > 0:
			state_cooldowns[state_name] -= delta
	
	# Contact damage timer'ı güncelle
	if contact_damage_timer > 0:
		contact_damage_timer -= delta
	
	# State machine'i çalıştır
	state_machine.process_frame(delta)
	
	# GRAVITY HER ZAMAN UYGULANSIN
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Hareket uygula - ÖNEMLİ: Bu satır eksik olmamalı!
	move_and_slide()
	
	# Sprite yönlendirmesi
	if player.global_position.x < global_position.x:
		animated_sprite.flip_h = true
	else:
		animated_sprite.flip_h = false
	
	# Aktif projectile'ları temizle
	_clean_inactive_projectiles()

func _clean_inactive_projectiles():
	active_projectiles = active_projectiles.filter(func(proj): return is_instance_valid(proj))

func take_damage_from_bullet(bullet_damage: int):
	current_health -= bullet_damage
	current_health = max(0, current_health)
	
	
	# Hasar efekti
	animated_sprite.modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)
	
	# Sinyal gönder
	health_changed.emit(current_health, max_health)
	
	# Ölüm kontrolü
	if current_health <= 0:
		die()

func die():
	print("💀 Boss öldü!")
	state_machine.change_state("DeathState")
	boss_died.emit()

var player_in_contact: bool = false

func _on_hitbox_body_entered(body):
	if body.is_in_group("player") and body.has_method("take_damage_from_source"):
		player_in_contact = true

func _on_hitbox_body_exited(body):
	if body.is_in_group("player"):
		player_in_contact = false
		contact_damage_timer = 0.0
		
func can_use_state(state_name: String) -> bool:
	if state_cooldowns.has(state_name) and state_cooldowns[state_name] > 0:
		return false
	
	if last_state == state_name and same_state_count >= 2:
		return false

	if state_name == "PunchMissileState" or state_name == "PunchRainState":
		if active_projectiles.size() > 0:
			return false
	
	return true

func set_state_cooldown(state_name: String, cooldown_time: float):
	state_cooldowns[state_name] = cooldown_time

func update_last_state(state_name: String):
	if last_state == state_name:
		same_state_count += 1
	else:
		same_state_count = 1
	last_state = state_name

func spawn_punch_rain():
	if not left_punch_scene or not right_punch_scene or not player:
		return
		
	var left_punch = left_punch_scene.instantiate()
	left_punch.global_position = Vector2(player.global_position.x+35, 0)
	left_punch.damage = punch_rain_damage
	left_punch.set_fly_up_mode(player.global_position.x)
	get_parent().add_child(left_punch)
	active_projectiles.append(left_punch)
	
	var right_punch = right_punch_scene.instantiate()
	right_punch.global_position = Vector2(player.global_position.x-35, 0)
	right_punch.damage = punch_rain_damage
	right_punch.set_fly_up_mode(player.global_position.x)
	get_parent().add_child(right_punch)
	active_projectiles.append(right_punch)

func spawn_punch_missiles():
	if not left_punch_scene or not right_punch_scene or not punch_start_pos1 or not punch_start_pos2 or not player:
		return
	
	# Sol missile - PunchStartPosition1'den
	var left_missile = left_punch_scene.instantiate()
	left_missile.global_position = punch_start_pos1.global_position
	left_missile.damage = punch_missile_damage
	left_missile.set_tracking_mode(player)
	get_parent().add_child(left_missile)
	active_projectiles.append(left_missile)
	
	# Sağ missile - PunchStartPosition2'den
	var right_missile = right_punch_scene.instantiate()
	right_missile.global_position = punch_start_pos2.global_position
	right_missile.damage = punch_missile_damage  
	right_missile.set_tracking_mode(player)
	get_parent().add_child(right_missile)
	active_projectiles.append(right_missile)


func deal_jump_damage():
	if not player:
		return
	
	# Mesafeye göre hasar menzili
	var damage_range = 120.0
	if distance_to_player > 200:
		damage_range = 150.0  # Uzak mesafeden zıpladıysa daha geniş alan
	elif distance_to_player > 400:
		damage_range = 200.0  # Çok uzaktan zıpladıysa çok geniş alan

	if distance_to_player <= damage_range:
		if player.has_method("take_damage_from_source"):
			var jump_damage = jump_attack_damage
			if distance_to_player > 200:
				jump_damage += 5
			
			player.take_damage(self)
		
func get_damage() -> int:
	if has_meta("temp_jump_damage"):
		var temp_damage = get_meta("temp_jump_damage")
		remove_meta("temp_jump_damage")
		return temp_damage
	else:
		return 0
