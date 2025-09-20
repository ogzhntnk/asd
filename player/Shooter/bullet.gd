# Player Bullet için örnek kod (eğer ayrı bullet kullanıyorsan)
extends Node2D

@export var damage: int = 35
@export var speed: float = 500.0

var velocity_vector: Vector2 = Vector2.ZERO
var has_hit: bool = false

@onready var area: Area2D = $Area2D

func _ready():
	add_to_group("player_bullets")  # Önemli: Group'a ekle
	
	if area:
		area.body_entered.connect(_on_area_body_entered)

func _on_area_body_entered(body: Node2D):
	if has_hit:
		return
	
	print("Player bullet collision: ", body.name)
	
	# Enemy'lere hasar ver
	if body.has_method("take_damage_from_bullet"):
		body.take_damage_from_bullet(damage)
		print("Enemy'e hasar verildi: ", damage)
		destroy_bullet()
	# Platform'lara çarp
	elif not body.is_in_group("player"):
		print("Bullet duvarla/platformla çarptı")
		destroy_bullet()

func set_direction(dir_vector: Vector2):
	velocity_vector = dir_vector
	rotation = dir_vector.angle()

func _physics_process(delta):
	if has_hit:
		return
	global_position += velocity_vector * delta

func destroy_bullet():
	if has_hit:
		return
	has_hit = true
	call_deferred("queue_free")
