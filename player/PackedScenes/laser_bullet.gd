extends Node2D

@export var damage: int = 15
@export var speed: float = 400.0
@export var lifetime: float = 5.0

var velocity_vector: Vector2 = Vector2.ZERO
var has_hit: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var area: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D
@onready var visible_on_screen: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var lifetime_timer: Timer = Timer.new()

func _ready():
	# Lifetime timer setup
	add_child(lifetime_timer)
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	lifetime_timer.start()

func set_direction(direction_vector: Vector2):
	velocity_vector = direction_vector.normalized() * speed
	
	# Sprite'ı yönüne çevir
	if sprite:
		rotation = direction_vector.angle()
	
	print("🔴 Bullet yönü ayarlandı: ", direction_vector)

func set_velocity(vel: Vector2):
	velocity_vector = vel
	
	# Sprite'ı yönüne çevir
	if sprite:
		rotation = vel.angle()

func get_velocity() -> Vector2:
	return velocity_vector

func _physics_process(delta):
	if has_hit:
		return
	
	# Manual hareket (Node2D olduğu için)
	global_position += velocity_vector * delta

# Area2D collision - Bodies (Player, enemies, platforms)
func _on_area_body_entered(body: Node2D):
	if has_hit:
		return
	
	print("🔴 Bullet collision with body: ", body.name)
	
	if body.name == "Player" or "player" in body.name.to_lower():
		# Player'a hasar ver
		if body.has_method("take_damage_from_source"):
			body.take_damage_from_source(self)
		elif body.has_method("take_damage"):
			body.take_damage(damage)
		
		print("🔴 Laser bullet player'a çarptı! Hasar: ", damage)
		destroy_bullet()
	
	elif body.has_method("take_damage_from_bullet"):
		# Diğer düşmanlara hasar (friendly fire kontrolü yapılabilir)
		body.take_damage_from_bullet(damage)
		print("🔴 Bullet başka düşmana çarptı!")
		destroy_bullet()
	
	elif "enemy" not in body.name.to_lower():
		# Platform/duvar (enemy değilse)
		print("🔴 Laser bullet duvara çarptı!")
		destroy_bullet()

# Area2D collision - Areas (diğer bullet'lar vs.)
func _on_area_area_entered(area_node: Area2D):
	if has_hit:
		return
	
	# Diğer bullet'larla çarpışma (opsiyonel)
	if "bullet" in area_node.get_parent().name.to_lower():
		print("🔴 Bullet çarpışması!")
		destroy_bullet()

func get_damage() -> int:
	return damage

func destroy_bullet():
	if has_hit:
		return
	
	has_hit = true
	
	# Hit efekti
	create_hit_effect()
	
	# Kısa delay sonra yok et (efekt için)
	await get_tree().create_timer(0.1).timeout
	queue_free()

func create_hit_effect():
	# Hit efekti - sprite'ı büyüt ve fade out
	if sprite:
		var tween = create_tween()
		tween.parallel().tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.1)
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.1)
		
		# Velocity'yi durdur
		velocity_vector = Vector2.ZERO

func _on_lifetime_timeout():
	print("🔴 Laser bullet zaman aşımı")
	queue_free()

func _on_screen_exited():
	print("🔴 Laser bullet ekrandan çıktı")
	queue_free()
