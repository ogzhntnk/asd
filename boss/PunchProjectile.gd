extends RigidBody2D
class_name PunchProjectile

enum ProjectileMode {
	FLY_UP,
	TRACKING,
	FALLING
}

@export var damage: int = 10
@onready var sprite = $Sprite2D
@onready var hitbox = $HitBox

var mode = ProjectileMode.FLY_UP
var target_player: CharacterBody2D
var target_x: float
var tracking_speed: float = 250.0
var fall_timer: float = 0.0
var has_started_falling: bool = false

func _ready():
	add_to_group("boss_projectiles")
	gravity_scale = 0

	call_deferred("_setup_hitbox")

func _setup_hitbox():
	# HitBox'ın ready olmasını bekle
	if hitbox == null:
		hitbox = get_node_or_null("HitBox")
	
	if hitbox:
		# Sinyal zaten bağlı mı kontrol et
		if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			hitbox.body_entered.connect(_on_hitbox_body_entered)
		
		# Collision layer ayarları
		set_collision_layer_value(8, true)  # Boss projectile layer
		set_collision_mask_value(1, true)   # Player ile çarpışsın
		
		# HitBox collision ayarları
		hitbox.set_collision_layer_value(16, true)  # Projectile damage layer
		hitbox.set_collision_mask_value(1, true)    # Player detect etsin

	_ready_damage_meta()

func set_fly_up_mode(player_x: float):
	mode = ProjectileMode.FLY_UP
	target_x = player_x
	linear_velocity = Vector2(0, -400)  # Hızlı yukarı uç
	has_started_falling = false

func set_tracking_mode(player: CharacterBody2D):
	mode = ProjectileMode.TRACKING
	target_player = player
	gravity_scale = 0

func _physics_process(delta):
	match mode:
		ProjectileMode.FLY_UP:
			_handle_fly_up_mode()
		ProjectileMode.TRACKING:
			_handle_tracking_mode(delta)
		ProjectileMode.FALLING:
			_handle_falling_mode(delta)
	
	# Ekran dışına çıkma kontrolü
	var viewport_rect = get_viewport_rect()
	
	# Yukarı çıktıktan sonra düşme moduna geç
	if global_position.y < viewport_rect.position.y - 50:
		if mode == ProjectileMode.FLY_UP and not has_started_falling:
			_start_falling()
	
	# Aşağıdan çıkarsa sil
	elif global_position.y > viewport_rect.size.y + 100:
		queue_free()
	
	# Yanlara çok uzaklaşırsa sil (tracking için)
	elif abs(global_position.x) > viewport_rect.size.x + 300:
		queue_free()

func _handle_fly_up_mode():
	# Yukarı uçarken dönme efekti
	rotation += 8.0 * get_physics_process_delta_time()

func _handle_tracking_mode(delta):
	if not target_player or not is_instance_valid(target_player):
		queue_free()
		return
	
	var direction = (target_player.global_position - global_position).normalized()
	linear_velocity = direction * tracking_speed
	rotation = direction.angle() + PI/2  # Yumruk yönünde rotate
	
func _handle_falling_mode(delta):
	fall_timer += delta
	
	if fall_timer > 2.0:  # 2 saniye bekle sonra YAVAS düş
		gravity_scale = 1.5  # DAHA YAVAŞ düşüş (önceden 4'tü)
		
		# X konumunu hedefe doğru BASIT şekilde ayarla
		var x_distance = target_x - global_position.x

		# Sadece X yönünde yavaş hareket
		if abs(x_distance) > 15:  # 15 piksellik tolerans (daha geniş)
			var move_speed = 60.0  # DAHA YAVAŞ yan hareket (önceden 100'dü)
			if x_distance > 0:
				linear_velocity.x = move_speed  # Sağa git
			else:
				linear_velocity.x = -move_speed  # Sola git
		else:
			linear_velocity.x = 0  # Hedefe yeterince yakınsa dur
		
	
func _start_falling():
	mode = ProjectileMode.FALLING
	fall_timer = 0.0
	linear_velocity = Vector2(0, 0)  # Hareketi durdur
	gravity_scale = 0  # Henüz düşme
	has_started_falling = true

func _on_hitbox_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("take_damage_from_source"):
			body.take_damage_from_source(self)
			queue_free()

func _on_body_entered(body):
	_on_hitbox_body_entered(body)  # Aynı logic'i kullan

# Player'ın damage sisteminin yumruktan damage değerini alabilmesi için
func get_damage() -> int:
	return damage

# Meta data ile damage belirleme (alternatif)
func _ready_damage_meta():
	set_meta("damage", damage)
