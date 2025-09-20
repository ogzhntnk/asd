@tool
extends Control

const SPRITE_SIZE = Vector2(32,32)
@export var bkg_color: Color
@export var line_color: Color
@export var highlight_color: Color
@export var outer_radius: int = 256
@export var inner_radius: int = 64
@export var line_width: int = 4
@export var options: Array[WheelOption]

# RayCast2D için değişkenler
var raycast: RayCast2D
var selection = 0
var available_parts: Array = []
var player_ref: Node

# Parça isimleri
var part_names = ["HİÇBİRİ", "KAFA", "SAĞ KOL", "SOL KOL", "SAĞ BACAK", "SOL BACAK"]

func _ready():
	# RayCast2D oluştur
	raycast = RayCast2D.new()
	add_child(raycast)
	raycast.enabled = true
	raycast.collision_mask = 1  # Default layer
	
	# Player referansını al
	if not Engine.is_editor_hint():
		player_ref = get_node("../../Player")
		update_available_parts()

func close():
	hide()
	return selection

func update_available_parts():
	if not player_ref:
		return
	
	# Mevcut parçaları al
	available_parts.clear()
	available_parts.append(0)  # Merkez için "hiçbiri" seçeneği
	
	if player_ref.has_head:
		available_parts.append(1)
	if player_ref.has_rarm:
		available_parts.append(2)
	if player_ref.has_larm:
		available_parts.append(3)
	if player_ref.has_rleg:
		available_parts.append(4)
	if player_ref.has_lleg:
		available_parts.append(5)
	
	# Seçimi güncelle
	if selection >= available_parts.size():
		selection = 0
	
	queue_redraw()

func _draw():
	# Arkaplan dairesi
	draw_circle(Vector2.ZERO, outer_radius, bkg_color)
	draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 128, line_color, line_width, true)
	
	if available_parts.size() <= 1:
		return
	
	# Bölümleri çiz (merkez hariç)
	var segment_count = available_parts.size() - 1
	if segment_count >= 1:
		for i in range(segment_count):
			var rads = TAU * i / segment_count
			var point = Vector2.from_angle(rads)
			
			draw_line(
				point * inner_radius,
				point * outer_radius,
				line_color,
				line_width,
				true
			)
	
	# Seçili alanı highlight et
	if selection == 0:
		# Merkez seçili
		draw_circle(Vector2.ZERO, inner_radius, highlight_color)
	elif selection > 0 and selection < available_parts.size():
		# Dış segment seçili
		var segment_index = selection - 1
		var start_rads = (TAU * segment_index) / segment_count
		var end_rads = (TAU * (segment_index + 1)) / segment_count
		
		var points_per_arc = 32
		var points_inner = PackedVector2Array()
		var points_outer = PackedVector2Array()
		
		for j in range(points_per_arc + 1):
			var angle = start_rads + j * (end_rads - start_rads) / points_per_arc
			points_inner.append(inner_radius * Vector2.from_angle(angle))
			points_outer.append(outer_radius * Vector2.from_angle(angle))
		
		points_outer.reverse()
		draw_polygon(
			points_inner + points_outer,
			PackedColorArray([highlight_color])
		)
	
	# Parça isimlerini çiz
	draw_part_labels()

func draw_part_labels():
	var font = ThemeDB.fallback_font
	var font_size = 16
	
	# Merkez etiketi
	if available_parts.size() > 0:
		var center_text = part_names[available_parts[0]]
		var text_size = font.get_string_size(center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, Vector2(-text_size.x/2, font_size/2), center_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	
	# Dış segment etiketleri
	var segment_count = available_parts.size() - 1
	if segment_count > 0:
		for i in range(1, available_parts.size()):
			var segment_index = i - 1
			var mid_rads = (TAU * segment_index + TAU * (segment_index + 1)) / (2 * segment_count)
			var radius_mid = (inner_radius + outer_radius) / 2.0
			
			var draw_pos = radius_mid * Vector2.from_angle(mid_rads)
			var part_text = part_names[available_parts[i]]
			var text_size = font.get_string_size(part_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			
			draw_string(font, draw_pos - text_size/2, part_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func _process(delta):
	if not visible:
		return
	
	var mouse_pos = get_local_mouse_position()
	var mouse_radius = mouse_pos.length()
	
	# RayCast2D'yi mouse pozisyonuna yönlendir
	raycast.target_position = mouse_pos
	raycast.force_raycast_update()
	
	# Seçimi güncelle
	if mouse_radius < inner_radius:
		# Merkez alanı
		selection = 0
	else:
		# Dış segmentler
		var mouse_angle = fposmod(mouse_pos.angle(), TAU)
		var segment_count = available_parts.size() - 1
		
		if segment_count > 0:
			var segment_size = TAU / segment_count
			var segment_index = int(mouse_angle / segment_size)
			selection = min(segment_index + 1, available_parts.size() - 1)
	
	queue_redraw()

func get_selected_part_index() -> int:
	if selection >= 0 and selection < available_parts.size():
		return available_parts[selection]
	return 0
