extends CharacterBody2D

# --- Stats ---
@export var max_health: int = 60
@export var melee_damage: int = 15
@export var base_speed: float = 50.0
@export var gravity: float = 800.0
@export var aggro_distance: float = 150.0  # player yakınsa hız artır

# --- Hurt & Death ---
@export var invuln_time: float = 0.4
@export var hurt_flash_time: float = 0.18

# --- Nodes ---
@onready var floor_detection: RayCast2D = $FloorDetection
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var damage_area: Area2D = $DamageArea

# --- Internal ---
var health: int
var invulnerable: bool = false
var _dying: bool = false

func _ready() -> void:
	health = max_health

	if damage_area and not damage_area.is_connected("body_entered", Callable(self, "_on_damage_area_body_entered")):
		damage_area.body_entered.connect(_on_damage_area_body_entered)

	if floor_detection and not floor_detection.enabled:
		floor_detection.enabled = true

	if animated_sprite_2d:
		animated_sprite_2d.play("idle")   #WALK

func _physics_process(delta: float) -> void:
	var speed = base_speed

	# Playera yakınsa hız artışı
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist < aggro_distance:
			speed *= 1.3  # %30 hız artışı

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Hareket yönü
	velocity.x = speed if animated_sprite_2d.flip_h else -speed

	move_and_slide()

	# Zemin / duvar kontrolü RayCast2D ile
	if not floor_detection.is_colliding() or is_on_wall():
		flip_me()

	# Animasyon kontrol
	if animated_sprite_2d:
		if velocity.length() > 1.0:
			if not animated_sprite_2d.is_playing():
				animated_sprite_2d.play("idle")  #WALK
		else:
			if not animated_sprite_2d.is_playing():
				animated_sprite_2d.play("idle")

func flip_me() -> void:
	animated_sprite_2d.flip_h = !animated_sprite_2d.flip_h
	floor_detection.position.x = -floor_detection.position.x

# --- Player Damage ---
func _on_damage_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage_from_source"):
			body.take_damage_from_source(self)
		elif body.has_method("take_damage"):
			body.take_damage(melee_damage)
		elif body.has_variable("health"):
			body.health -= melee_damage
		_apply_hit_recoil_to_self(body)

func _apply_hit_recoil_to_self(body: Node) -> void:
	if not body:
		return
	var dir = (global_position - body.global_position).normalized()
	velocity += dir * 40.0

# --- Damage & Death ---
func take_damage_from_bullet(damage: int) -> void:
	if invulnerable or _dying:
		return
	health -= damage

	if animated_sprite_2d:
		await _hurt_flash()

	invulnerable = true
	var t := Timer.new()
	t.wait_time = invuln_time
	t.one_shot = true
	add_child(t)
	t.start()
	await t.timeout
	invulnerable = false

	if health <= 0:
		await _death_sequence()

func _hurt_flash() -> void:
	if not animated_sprite_2d:
		return
	animated_sprite_2d.modulate = Color(1,0.4,0.4)
	var t := Timer.new()
	t.wait_time = hurt_flash_time
	t.one_shot = true
	add_child(t)
	t.start()
	await t.timeout
	if is_instance_valid(animated_sprite_2d):
		animated_sprite_2d.modulate = Color(1,1,1,1)

func _death_sequence() -> void:
	if _dying:
		return
	_dying = true
	if animated_sprite_2d:
		var tween = create_tween()
		tween.tween_property(animated_sprite_2d, "modulate:a", 0.0, 0.9)
		tween.tween_property(animated_sprite_2d, "scale", animated_sprite_2d.scale * 0.6, 0.9)
		await tween.finished
	queue_free()
