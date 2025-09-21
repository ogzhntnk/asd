extends Node2D

@export var flying_enemy_scene: PackedScene
@export var ground_enemy_scene: PackedScene
@export var win_scene: PackedScene  # Kazandınız.tscn

@onready var boss: Node2D = $Boss
@onready var ground_enemy_marker: Node2D = $GroundEnemyMarker
@onready var flying_enemy_marker: Node2D = $FlyingEnemyMarker
@onready var boss_health_bar: ProgressBar = $BossUI/BossHealthBar/HealthBar

var ground_enemy_timer: Timer
var flying_enemy_timer: Timer

func _ready():
	if not boss:
		push_error("Boss sahnede bulunamadı!")
		return

	# Timer oluştur
	ground_enemy_timer = Timer.new()
	flying_enemy_timer = Timer.new()
	add_child(ground_enemy_timer)
	add_child(flying_enemy_timer)

	ground_enemy_timer.one_shot = true
	flying_enemy_timer.one_shot = true

	ground_enemy_timer.timeout.connect(_spawn_ground_enemy)
	flying_enemy_timer.timeout.connect(_spawn_flying_enemy)

	# Boss health bar ayarları
	boss_health_bar.max_value = boss.get("max_health")
	boss_health_bar.value = boss.get("current_health")

	# Boss sinyallerini bağla (boss scriptinde tanımlanmış olmalı)
	if boss.has_signal("health_changed"):
		boss.connect("health_changed", Callable(self, "_on_boss_health_changed"))
	if boss.has_signal("boss_died"):
		boss.connect("boss_died", Callable(self, "_on_boss_died"))

func _on_boss_health_changed(current_health: int, max_health: int):
	boss_health_bar.value = current_health

	var health_percent = float(current_health) / float(max_health)
	if health_percent > 0.6:
		boss_health_bar.modulate = Color.GREEN
	elif health_percent > 0.3:
		boss_health_bar.modulate = Color.YELLOW
	else:
		boss_health_bar.modulate = Color.RED

	# Enemy spawn tetikleme
	if health_percent <= 0.8 and ground_enemy_timer.is_stopped():
		ground_enemy_timer.wait_time = randf_range(3.0, 5.0)
		ground_enemy_timer.start()

	if health_percent <= 0.6 and flying_enemy_timer.is_stopped():
		flying_enemy_timer.wait_time = randf_range(4.0, 6.0)
		flying_enemy_timer.start()

func _spawn_ground_enemy():
	if not ground_enemy_scene or not ground_enemy_marker:
		return

	var enemy = ground_enemy_scene.instantiate()
	# Marker çevresinde hafif random pozisyon
	enemy.global_position = ground_enemy_marker.global_position + Vector2(randf_range(-20,20), 0)
	get_parent().add_child(enemy)

	# Timer tekrar başlat
	ground_enemy_timer.wait_time = randf_range(3.0, 5.0)
	ground_enemy_timer.start()

func _spawn_flying_enemy():
	if not flying_enemy_scene or not flying_enemy_marker:
		return

	var enemy = flying_enemy_scene.instantiate()
	enemy.global_position = flying_enemy_marker.global_position + Vector2(randf_range(-20,20), 0)
	get_parent().add_child(enemy)

	flying_enemy_timer.wait_time = randf_range(4.0, 6.0)
	flying_enemy_timer.start()

func _on_boss_died():
	# Timer’ları durdur
	if ground_enemy_timer:
		ground_enemy_timer.stop()
	if flying_enemy_timer:
		flying_enemy_timer.stop()

	if win_scene:
		get_tree().change_scene_to_packed(win_scene)
