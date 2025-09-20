extends Node

signal health_changed(current_health: int, max_health: int)
signal player_died()

@export var max_health: int = 100
var current_health: int

func _ready():
	current_health = max_health
	print("❤️ Health System başlatıldı - Can: %d/%d" % [current_health, max_health])

# Düşman/platform script'lerinden hasar al
func take_damage(damage_source: Node):
	var damage_amount: int = 0
	
	# Hasar kaynağından damage değerini oku
	if damage_source.has_method("get_damage"):
		damage_amount = damage_source.get_damage()
	elif damage_source.has_meta("damage"):
		damage_amount = damage_source.get_meta("damage")
	elif "damage" in damage_source:
		damage_amount = damage_source.damage
	else:
		damage_amount = 10  # Default hasar
		print("⚠️ Hasar kaynağı tanımlanamadı, varsayılan hasar: %d" % damage_amount)
	
	# Hasarı uygula
	current_health -= damage_amount
	current_health = max(current_health, 0)
	
	print("💥 Hasar alındı! Kaynak: %s | Hasar: %d | Kalan Can: %d/%d" % 
		[damage_source.name, damage_amount, current_health, max_health])
	
	# Sinyal gönder
	health_changed.emit(current_health, max_health)
	
	# Ölüm kontrolü
	if current_health <= 0:
		die()

func heal(heal_amount: int):
	current_health += heal_amount
	current_health = min(current_health, max_health)
	print("💚 İyileşme! Miktar: %d | Güncel Can: %d/%d" % [heal_amount, current_health, max_health])
	health_changed.emit(current_health, max_health)

func die():
	print("💀 Player öldü!")
	player_died.emit()
	# Game over ekranını göster - deferred call ile
	call_deferred("show_game_over")

func show_game_over():
	# Tree kontrolü ekle
	if not get_tree():
		print("❌ Tree bulunamadı!")
		return
		
	# Oyunu duraklat
	get_tree().paused = true
	
	# Game over sahnesini yükle veya UI göster
	# Örnek basit implementation:
	# var game_over_scene = preload("res://GameOverScreen.tscn")
	# if game_over_scene:
	#     get_tree().change_scene_to_packed(game_over_scene)
	# else:
	print("🎮 GAME OVER! Oyunu yeniden başlatmak için R tuşuna bas...")
		
func reset_health():
	current_health = max_health
	health_changed.emit(current_health, max_health)
	print("🔄 Can sıfırlandı: %d/%d" % [current_health, max_health])

# Debug için
func get_health_info() -> Dictionary:
	return {
		"current": current_health,
		"max": max_health,
		"percentage": float(current_health) / float(max_health) * 100.0
	}
