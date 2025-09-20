extends Node2D

@export var bullet_scene: PackedScene
@export var shoot_force: float = 600.0
@export var fire_rate: float = 0.3  # mermiler arası süre

@onready var player: Node = get_parent().get_parent()  # LeftArm > BodyParts > Player
@onready var fire_timer: Timer = $Timer

var can_fire: bool = true

func _ready():
	fire_timer.wait_time = fire_rate
	fire_timer.one_shot = true
	fire_timer.timeout.connect(_on_fire_timer_timeout)

func shoot():
	if not can_fire:
		return
	
	can_fire = false
	fire_timer.start()
	
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	
	bullet.add_to_group("player_bullets")
	# Mouse pozisyonuna doğru yön hesapla
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	
	print("🎯 Mouse yönlü ateş! Yön: ", direction)
	
	if bullet.has_method("set_direction"):
		bullet.set_direction(direction * shoot_force)
	elif bullet.has_method("set_velocity"):
		bullet.set_velocity(direction * shoot_force)
	
	get_tree().current_scene.add_child(bullet)

func _on_fire_timer_timeout():
	can_fire = true
