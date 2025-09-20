extends CanvasLayer

@onready var selection_wheel = $SelectionWheel
@onready var label = $Label
@onready var player = get_node("../Player")

func _process(delta):
	if Input.is_action_just_pressed("interact"):
		show_selection_wheel()
	elif Input.is_action_just_released("interact"):
		hide_selection_wheel()

func show_selection_wheel():
	# Mouse pozisyonuna wheel'i konumlandır
	var mouse_pos = get_viewport().get_mouse_position()
	selection_wheel.position = mouse_pos
	selection_wheel.show()
	selection_wheel.update_available_parts()
	
	# Oyunu duraksat (keyboard input'ları kapat)
	if player:
		player.set_game_paused(true)
	
	print("⏸️ SelectionWheel açıldı - Oyun duraklatıldı")

func hide_selection_wheel():
	var selected_part_index = selection_wheel.close()
	
	# Oyun duraksını kaldır
	if player:
		player.set_game_paused(false)
	
	# Seçim işlemi
	if selected_part_index > 0:
		player.on_part_selected_from_wheel(selected_part_index)
		var part_names = ["", "KAFA", "SAĞ KOL", "SOL KOL", "SAĞ BACAK", "SOL BACAK"]
		label.text = "Selected Part: " + part_names[selected_part_index]
		print("✅ Parça seçildi ve oyun devam ediyor: ", part_names[selected_part_index])
	else:
		label.text = "No part selected"
		print("❌ Hiçbir parça seçilmedi, oyun devam ediyor")
	
	print("▶️ SelectionWheel kapatıldı - Oyun devam ediyor")
