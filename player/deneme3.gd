extends CharacterBody2D

# --- Parça durumu değişkenleri ---
@export var has_head: bool = true
@export var has_rarm: bool = true
@export var has_larm: bool = true
@export var has_rleg: bool = true
@export var has_lleg: bool = true

# --- Fizik değişkenleri ---
@export var speed: float = 200.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 980.0
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.3

# --- Fırlatma değişkenleri ---
@export var throw_power_multiplier: float = 15.0
@export var max_throw_distance: float = 300.0
@export var min_throw_distance: float = 50.0
@export var trajectory_point_count: int = 20
@export var trajectory_point_spacing: float = 20.0
@export var trajectory_point_scene: PackedScene

# --- Player State Enum ---
enum PlayerState { IDLE, RUN, JUMP, FALL, DASH, ATTACK }
var state: PlayerState = PlayerState.IDLE

# --- Mouse State Enum ---
enum MouseState { IDLE, AIMING, THROWING }
var mouse_state: MouseState = MouseState.IDLE

# --- Zamanlayıcılar ve flagler ---
var dash_timer: float = 0.0
var can_double_jump_flag: bool = true

# --- Seçili parça ---
var selected_part: int = 0  # 0=hiçbiri, 1=head, 2=rarm, 3=larm, 4=rleg, 5=lleg

# --- Input değişkenleri ---
var input_direction: Vector2 = Vector2.ZERO
var is_jumping: bool = false
var is_attacking: bool = false
var is_dashing: bool = false
var is_throwing: bool = false

# --- Oyun duraksama kontrolü ---
var is_game_paused: bool = false

# --- Fırlatma değişkenleri ---
var throw_start_position: Vector2
var current_mouse_position: Vector2
var ghost_part: Node2D = null
var trajectory_points: Array[Vector2] = []
var trajectory_point_nodes: Array[Node2D] = []

# --- Node referansları ---
@onready var body_parts: Node2D = $BodyParts
@onready var body: ColorRect = get_node_or_null("BodyParts/Body/ColorRect")
@onready var head: ColorRect = get_node_or_null("BodyParts/Head/ColorRect")
@onready var r_arm: ColorRect = get_node_or_null("BodyParts/RightArm/ColorRect")
@onready var l_arm: ColorRect = get_node_or_null("BodyParts/LeftArm/ColorRect")
@onready var r_leg: ColorRect = get_node_or_null("BodyParts/RightLeg/ColorRect")
@onready var l_leg: ColorRect = get_node_or_null("BodyParts/LeftLeg/ColorRect")
@onready var shoot_arm: Node2D = get_node_or_null("BodyParts/LeftArm")
@onready var debug_label: Label = get_node_or_null("DebugLabel")

# --- Health System ---
@onready var health_system: Node = $HealthSystem

# --- PackedScene referansları ---
@export var head_scene: PackedScene
@export var rarm_scene: PackedScene
@export var larm_scene: PackedScene
@export var rleg_scene: PackedScene
@export var lleg_scene: PackedScene

# --- Sahnedeki düşen parçalar ---
var dropped_parts := []

# --- UI referansı ---
var ui_canvas: CanvasLayer

func _ready():
	update_body_parts_visibility()
	reset_parts_color()
	# UI referansını bul
	ui_canvas = get_node("../UI")

func _physics_process(delta):
	# Oyun duraksadaysa hiçbir şey yapma (mouse hariç)
	if is_game_paused:
		return
	
	handle_input()
	handle_mouse_input()
	apply_gravity(delta)
	apply_manual_movement()
	apply_skills()
	handle_state(delta)
	handle_throwing_state()
	move_and_slide()
	update_debug_label()

func handle_input():
	# Oyun duraksadaysa input alma
	if is_game_paused:
		return
	
	var new_direction = Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		new_direction.x -= 1
	if Input.is_action_pressed("move_right"):
		new_direction.x += 1
	input_direction = new_direction.normalized()

	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			is_jumping = true
			can_double_jump_flag = true
		elif can_double_jump() and can_double_jump_flag:
			is_jumping = true
			can_double_jump_flag = false
			print("⬆️ Double Jump!")

	if Input.is_action_just_pressed("attack"):
		print("🎯 Shoot input detected")
		var shooter = shoot_arm.get_node_or_null("Shooter")
		if shooter:
			shooter.shoot()
		else:
			print("❌ Shooter node bulunamadı!")

	if Input.is_action_just_pressed("dash") and can_dash() and not is_dashing:
		is_dashing = true
		dash_timer = dash_duration

	# Parça seçme (toggle mantığı) - sadece wheel açık değilse
	if not ui_canvas.get_node("SelectionWheel").visible:
		if Input.is_action_just_pressed("select_head"):
			toggle_body_part(1)
		elif Input.is_action_just_pressed("select_rarm"):
			toggle_body_part(2)
		elif Input.is_action_just_pressed("select_larm"):
			toggle_body_part(3)
		elif Input.is_action_just_pressed("select_rleg"):
			toggle_body_part(4)
		elif Input.is_action_just_pressed("select_lleg"):
			toggle_body_part(5)

	# Parçayı bırak (F tuşu)
	if Input.is_action_just_pressed("lose_selected_part"):
		drop_selected_part()

	# Vücudu tamamla (R tuşu)
	if Input.is_action_just_pressed("reset_all_parts"):
		reset_all_parts()

func handle_mouse_input():
	current_mouse_position = get_global_mouse_position()
	
	# Oyun duraksadaysa fırlatma inputu alma
	if is_game_paused:
		return
	
	# Fırlatma başlat
	if Input.is_action_just_pressed("throw") and selected_part > 0 and mouse_state == MouseState.IDLE:
		start_throwing()
	
	# Fırlatma iptal et
	elif Input.is_action_just_pressed("throw_cancel") and mouse_state == MouseState.AIMING:
		cancel_throwing()
	
	# Fırlat
	elif Input.is_action_just_released("throw") and mouse_state == MouseState.AIMING:
		execute_throw()

# Oyun duraksama kontrolü
func set_game_paused(paused: bool):
	is_game_paused = paused
	if paused:
		# Hareket durur ama mevcut hız korunur
		input_direction = Vector2.ZERO
		is_jumping = false
		is_attacking = false
		print("⏸️ Oyun duraklatıldı (SelectionWheel açık)")
	else:
		print("▶️ Oyun devam ediyor")

# SelectionWheel'den gelen seçimi işle
func on_part_selected_from_wheel(part_index: int):
	selected_part = part_index
	update_selection_visual()
	var part_names = ["HİÇBİRİ", "KAFA", "SAĞ KOL", "SOL KOL", "SAĞ BACAK", "SOL BACAK"]
	print("✅ Wheel'den seçilen parça: ", part_names[part_index])

func get_available_parts() -> Array:
	var available = []
	if has_head:
		available.append(1)
	if has_rarm:
		available.append(2)
	if has_larm:
		available.append(3)
	if has_rleg:
		available.append(4)
	if has_lleg:
		available.append(5)
	return available

# Health system callbacks
func _on_player_died():
	print("💀 Player öldü - Oyun bitiyor!")
	# Burada ek ölüm animasyonları vs. eklenebilir

func _on_health_changed(current_health: int, max_health: int):
	print("❤️ Can değişti: %d/%d (%.1f%%)" % [current_health, max_health, float(current_health)/max_health*100])

# Collision ile hasar alma (Area2D veya RigidBody2D collision)
func _on_damage_area_entered(area: Area2D):
	if health_system:
		health_system.take_damage(area)

func _on_damage_body_entered(body: Node2D):
	if health_system:
		health_system.take_damage(body)

# Manuel hasar alma (script'ten çağrılabilir)
func take_damage_from_source(damage_source: Node):
	if health_system:
		health_system.take_damage(damage_source)

# Diğer fonksiyonlar aynı kalıyor...
func start_throwing():
	if not can_throw_selected_part():
		return
		
	mouse_state = MouseState.AIMING
	throw_start_position = get_selected_part_position()
	create_ghost_part()
	print("🎯 Fırlatma moduna geçildi! Başlangıç pozisyon: ", throw_start_position)

func get_selected_part_position() -> Vector2:
	var base_position: Vector2
	match selected_part:
		1:
			if head:
				base_position = head.get_parent().global_position
				base_position.y -= 20
				return base_position
		2:
			if r_arm:
				return r_arm.get_parent().global_position
		3:
			if l_arm:
				return l_arm.get_parent().global_position
		4:
			if r_leg:
				return r_leg.get_parent().global_position
		5:
			if l_leg:
				return l_leg.get_parent().global_position
	return global_position

func cancel_throwing():
	mouse_state = MouseState.IDLE
	cleanup_throwing_visuals()
	print("❌ Fırlatma iptal edildi!")

func cleanup_throwing_visuals():
	if ghost_part:
		ghost_part.queue_free()
		ghost_part = null
	
	for point_node in trajectory_point_nodes:
		if point_node and point_node.is_inside_tree():
			point_node.queue_free()
	trajectory_point_nodes.clear()

func execute_throw():
	if mouse_state != MouseState.AIMING or not ghost_part:
		return
		
	var throw_vector = throw_start_position - current_mouse_position
	var throw_distance = throw_vector.length()
	var throw_direction = throw_vector.normalized()
	
	if throw_distance < min_throw_distance:
		print("⚠️ Çok az çektiniz! Minimum mesafe: %.0f pixel" % min_throw_distance)
		cancel_throwing()
		return
	
	var actual_power = min(throw_distance, max_throw_distance)
	var final_throw_vector = throw_direction * actual_power
	
	if throw_distance > max_throw_distance:
		print("⚡ Maksimum güç! Açı değişiyor ama güç sabit: %.0f" % max_throw_distance)
	else:
		print("🎯 Fırlatma gücü: %.0f/%.0f" % [throw_distance, max_throw_distance])
	
	convert_ghost_to_real_part(final_throw_vector)
	remove_selected_part_from_player()
	mouse_state = MouseState.IDLE
	cleanup_throwing_visuals()
	print("🚀 Parça başarıyla fırlatıldı!")

func can_throw_selected_part() -> bool:
	if selected_part == 0:
		print("❌ Hiçbir parça seçili değil!")
		return false
		
	var part_name = get_selected_part_name()
	if part_name == "":
		return false
		
	return can_lose_part(part_name)

func get_selected_part_name() -> String:
	match selected_part:
		1:
			return "head" if has_head else ""
		2:
			return "rarm" if has_rarm else ""
		3:
			return "larm" if has_larm else ""
		4:
			return "rleg" if has_rleg else ""
		5:
			return "lleg" if has_lleg else ""
		_:
			return ""

func get_selected_part_scene() -> PackedScene:
	match selected_part:
		1:
			return head_scene
		2:
			return rarm_scene
		3:
			return larm_scene
		4:
			return rleg_scene
		5:
			return lleg_scene
		_:
			return null

func create_ghost_part():
	var part_scene = get_selected_part_scene()
	if not part_scene:
		return
		
	ghost_part = part_scene.instantiate()
	if not ghost_part:
		return
		
	ghost_part.modulate = Color(1, 1, 1, 0.5)
	completely_disable_collisions(ghost_part)
	get_parent().add_child(ghost_part)
	ghost_part.global_position = current_mouse_position

func completely_disable_collisions(node: Node):
	if node.has_method("set_physics_process"):
		node.set_physics_process(false)
	if node.has_method("set_physics_process_mode"):
		node.set_physics_process_mode(Node.PROCESS_MODE_DISABLED)
	
	if node is RigidBody2D:
		var rigid = node as RigidBody2D
		rigid.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		rigid.freeze = true
		rigid.set_collision_layer(0)
		rigid.set_collision_mask(0)
		rigid.gravity_scale = 0
	elif node is StaticBody2D:
		var static_body = node as StaticBody2D
		static_body.set_collision_layer(0)
		static_body.set_collision_mask(0)
	elif node is CharacterBody2D:
		var char_body = node as CharacterBody2D
		char_body.set_collision_layer(0)
		char_body.set_collision_mask(0)
	
	destroy_all_collisions_recursive(node)

func destroy_all_collisions_recursive(node: Node):
	for child in node.get_children():
		if child is CollisionShape2D:
			child.disabled = true
			child.set_deferred("disabled", true)
		elif child is Area2D:
			var area = child as Area2D
			area.set_collision_layer(0)
			area.set_collision_mask(0)
			area.set_monitoring(false)
			area.set_monitorable(false)
			for area_child in area.get_children():
				if area_child is CollisionShape2D:
					area_child.disabled = true
		elif child is RigidBody2D:
			var rigid = child as RigidBody2D
			rigid.freeze = true
			rigid.set_collision_layer(0)
			rigid.set_collision_mask(0)
		elif child is StaticBody2D:
			var static_body = child as StaticBody2D
			static_body.set_collision_layer(0)
			static_body.set_collision_mask(0)
		elif child is CharacterBody2D:
			var char_body = child as CharacterBody2D
			char_body.set_collision_layer(0)
			char_body.set_collision_mask(0)
		
		if child.get_child_count() > 0:
			destroy_all_collisions_recursive(child)

func update_ghost_and_trajectory():
	if not ghost_part or mouse_state != MouseState.AIMING:
		return
	
	throw_start_position = get_selected_part_position()
	ghost_part.global_position = throw_start_position
	calculate_trajectory()
	create_trajectory_points()

func calculate_trajectory():
	trajectory_points.clear()
	
	var throw_vector = throw_start_position - current_mouse_position
	var throw_distance = throw_vector.length()
	var throw_direction = throw_vector.normalized()
	
	if throw_distance < min_throw_distance:
		return
	
	var actual_power = min(throw_distance, max_throw_distance)
	var velocity = throw_direction * actual_power * throw_power_multiplier * 0.4
	
	var start_pos = throw_start_position
	var gravity_vec = Vector2(0, gravity)
	
	for i in range(trajectory_point_count):
		var time = i * 0.1
		var pos = start_pos + velocity * time + 0.5 * gravity_vec * time * time
		trajectory_points.append(pos)

func create_trajectory_points():
	for point_node in trajectory_point_nodes:
		if point_node and point_node.is_inside_tree():
			point_node.queue_free()
	trajectory_point_nodes.clear()
	
	if not trajectory_point_scene:
		print("❌ Trajectory point scene atanmamış!")
		return
	
	var throw_distance = (throw_start_position - current_mouse_position).length()
	
	if throw_distance < min_throw_distance:
		return
	
	for i in range(trajectory_points.size()):
		if i % 2 == 0:
			var point_node = trajectory_point_scene.instantiate()
			if point_node:
				get_parent().add_child(point_node)
				point_node.global_position = trajectory_points[i]
				
				var actual_power = min(throw_distance, max_throw_distance)
				var distance_ratio = actual_power / max_throw_distance
				var point_color = Color.WHITE.lerp(Color.RED, distance_ratio)
				point_color.a = 0.7
				
				if point_node.has_method("set_modulate"):
					point_node.modulate = point_color
				elif point_node.get_child_count() > 0:
					var child = point_node.get_child(0)
					if child.has_method("set_modulate"):
						child.modulate = point_color
				
				trajectory_point_nodes.append(point_node)

func convert_ghost_to_real_part(throw_vector: Vector2):
	if not ghost_part:
		return
		
	var throw_position = get_selected_part_position()
	ghost_part.queue_free()
	ghost_part = null
	
	var part_scene = get_selected_part_scene()
	var real_part = part_scene.instantiate()
	
	if not real_part:
		return
		
	setup_thrown_part_physics(real_part)
	get_parent().add_child(real_part)
	real_part.global_position = throw_position
	reactivate_area2d(real_part)
	
	var velocity = throw_vector * throw_power_multiplier * 0.4
	if real_part is RigidBody2D:
		real_part.linear_velocity = velocity
		real_part.gravity_scale = 1.0
		setup_physics_material(real_part)
	
	dropped_parts.append(real_part)
	_connect_part_signals(real_part)

func reactivate_area2d(node: Node):
	for child in node.get_children():
		if child is Area2D:
			var area = child as Area2D
			area.set_collision_layer(1)
			area.set_collision_mask(1)
			area.set_monitoring(true)
			area.set_monitorable(true)
			for area_child in area.get_children():
				if area_child is CollisionShape2D:
					area_child.disabled = false
		
		if child.get_child_count() > 0:
			reactivate_area2d(child)

func setup_physics_material(real_part: Node):
	for child in real_part.get_children():
		if child is CollisionShape2D:
			if not real_part.physics_material_override:
				real_part.physics_material_override = PhysicsMaterial.new()
				real_part.physics_material_override.bounce = 0.6
				real_part.physics_material_override.friction = 0.5
			break

func setup_thrown_part_physics(part_node: Node2D):
	if part_node is StaticBody2D:
		var collision_shape = part_node.get_child(0)
		if collision_shape is CollisionShape2D:
			var new_collision = collision_shape.duplicate()
			var rigid_body = RigidBody2D.new()
			var children_to_move = []
			for child in part_node.get_children():
				children_to_move.append(child)
			
			for child in children_to_move:
				part_node.remove_child(child)
				rigid_body.add_child(child)
			
			var parent = part_node.get_parent()
			var pos = part_node.global_position
			
			if parent:
				parent.remove_child(part_node)
				parent.add_child(rigid_body)
				rigid_body.global_position = pos
				
			part_node = rigid_body

func remove_selected_part_from_player():
	var part_name = get_selected_part_name()
	
	match part_name:
		"head":
			has_head = false
		"rarm":
			has_rarm = false
		"larm":
			has_larm = false
		"rleg":
			has_rleg = false
		"lleg":
			has_lleg = false
	
	selected_part = 0
	update_body_parts_visibility()
	play_animation("hurt")
	await get_tree().create_timer(1.0).timeout
	play_animation("idle")
	
	# UI'ya parça kaybını bildir
	if ui_canvas:
		ui_canvas.get_node("SelectionWheel").update_available_parts()

func handle_throwing_state():
	if mouse_state == MouseState.AIMING:
		update_ghost_and_trajectory()

func _process(delta):
	if mouse_state == MouseState.AIMING:
		update_ghost_and_trajectory()

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

func apply_manual_movement():
	if state == PlayerState.DASH and can_dash():
		velocity.x = dash_speed * sign(input_direction.x if input_direction.x != 0 else 1)
	else:
		velocity.x = input_direction.x * speed

	if is_jumping:
		perform_jump()
		is_jumping = false

func perform_jump():
	velocity.y = jump_velocity
	if input_direction.x != 0:
		velocity.x = input_direction.x * (speed * 1.2)
	print("⬆️ Zıpladı! Velocity: ", velocity)

func handle_state(delta):
	match state:
		PlayerState.IDLE:
			if abs(input_direction.x) > 0.1:
				state = PlayerState.RUN
			elif not is_on_floor():
				state = PlayerState.FALL
			elif is_jumping:
				state = PlayerState.JUMP
			elif is_dashing:
				state = PlayerState.DASH
			elif is_attacking:
				state = PlayerState.ATTACK
			play_animation("idle")

		PlayerState.RUN:
			if input_direction.x == 0:
				state = PlayerState.IDLE
			elif is_jumping:
				state = PlayerState.JUMP
			elif not is_on_floor():
				state = PlayerState.FALL
			elif is_dashing:
				state = PlayerState.DASH
			play_animation("run")

		PlayerState.JUMP:
			if velocity.y > 0:
				state = PlayerState.FALL
			play_animation("jump")

		PlayerState.FALL:
			if is_on_floor():
				state = PlayerState.IDLE
			elif is_dashing:
				state = PlayerState.DASH
			play_animation("fall")

		PlayerState.DASH:
			if dash_timer > 0:
				dash_timer -= delta
				play_animation("dash")
			else:
				is_dashing = false
				state = PlayerState.IDLE

		PlayerState.ATTACK:
			play_animation("attack")
			is_attacking = false
			state = PlayerState.IDLE

func select_body_part(part_index: int):
	selected_part = part_index
	update_selection_visual()

func toggle_body_part(part_index: int):
	if selected_part == part_index:
		selected_part = 0
		print("🔄 Parça seçimi iptal edildi")
	else:
		selected_part = part_index
		var part_names = ["", "KAFA", "SAĞ KOL", "SOL KOL", "SAĞ BACAK", "SOL BACAK"]
		print("✅ Seçilen parça: ", part_names[part_index])
	
	update_selection_visual()

func drop_selected_part():
	if selected_part == 0:
		print("❌ Hiçbir parça seçili değil!")
		return

	var part_name = ""
	var part_scene: PackedScene = null

	match selected_part:
		1:
			if has_head:
				part_name = "head"
				part_scene = head_scene
		2:
			if has_rarm:
				part_name = "rarm"
				part_scene = rarm_scene
		3:
			if has_larm:
				part_name = "larm"
				part_scene = larm_scene
		4:
			if has_rleg:
				part_name = "rleg"
				part_scene = rleg_scene
		5:
			if has_lleg:
				part_name = "lleg"
				part_scene = lleg_scene

	if part_scene == null:
		print("❌ Parça sahnesi atanmadı veya parça yok!")
		return

	if not can_lose_part(part_name):
		return

	var dropped_part = part_scene.instantiate()
	if dropped_part:
		dropped_part.global_position = global_position
		get_parent().add_child(dropped_part)
		dropped_parts.append(dropped_part)
		print("💔 Parça bırakıldı: ", part_name.to_upper())

		_connect_part_signals(dropped_part)

	match part_name:
		"head":
			has_head = false
		"rarm":
			has_rarm = false
		"larm":
			has_larm = false
		"rleg":
			has_rleg = false
		"lleg":
			has_lleg = false

	update_body_parts_visibility()
	play_animation("hurt")
	await get_tree().create_timer(1.0).timeout
	play_animation("idle")
	
	# UI'ya parça kaybını bildir
	if ui_canvas:
		ui_canvas.get_node("SelectionWheel").update_available_parts()

func reset_all_parts():
	has_head = true
	has_rarm = true
	has_larm = true
	has_rleg = true
	has_lleg = true

	for part in dropped_parts:
		if part and part.is_inside_tree():
			part.queue_free()
	dropped_parts.clear()

	update_body_parts_visibility()
	play_animation("jump")
	
	# UI'ya parça değişimini bildir
	if ui_canvas:
		ui_canvas.get_node("SelectionWheel").update_available_parts()

func update_selection_visual():
	reset_parts_color()
	var highlight_color = Color.YELLOW
	match selected_part:
		1:
			if has_head and head:
				head.color = highlight_color
		2:
			if has_rarm and r_arm:
				r_arm.color = highlight_color
		3:
			if has_larm and l_arm:
				l_arm.color = highlight_color
		4:
			if has_rleg and r_leg:
				r_leg.color = highlight_color
		5:
			if has_lleg and l_leg:
				l_leg.color = highlight_color

func play_animation(anim_name: String):
	match anim_name:
		"idle":
			reset_parts_color()
		"run":
			set_parts_color(Color.LIGHT_YELLOW)
		"jump":
			set_parts_color(Color.LIGHT_GREEN)
		"fall":
			set_parts_color(Color.LIGHT_CORAL)
		"attack":
			set_parts_color(Color.ORANGE_RED)
		"hurt":
			set_parts_color(Color.RED)
		"dash":
			set_parts_color(Color.CYAN)
		_:
			reset_parts_color()

	update_selection_visual()

func set_parts_color(tint_color: Color):
	if body:
		body.color = tint_color
	if has_head and head:
		head.color = tint_color
	if has_rarm and r_arm:
		r_arm.color = tint_color
	if has_larm and l_arm:
		l_arm.color = tint_color
	if has_rleg and r_leg:
		r_leg.color = tint_color
	if has_lleg and l_leg:
		l_leg.color = tint_color

func reset_parts_color():
	if body:
		body.color = Color(0.8, 0.8, 0.8)
	if has_head and head:
		head.color = Color(1, 0.8, 0.6)
	if has_rarm and r_arm:
		r_arm.color = Color(1, 0.8, 0.6)
	if has_larm and l_arm:
		l_arm.color = Color(1, 0.8, 0.6)
	if has_rleg and r_leg:
		r_leg.color = Color(0, 0.4, 0.8)
	if has_lleg and l_leg:
		l_leg.color = Color(0, 0.4, 0.8)

func update_body_parts_visibility():
	if head:
		head.visible = has_head
	if r_arm:
		r_arm.visible = has_rarm
	if l_arm:
		l_arm.visible = has_larm
	if r_leg:
		r_leg.visible = has_rleg
	if l_leg:
		l_leg.visible = has_lleg

func apply_skills():
	if not has_rarm:
		print("⚠️ Sağ el yok → Fırlatma gücünün %50'si kayboldu!")
	if not has_larm:
		print("⚠️ Sol el yok → Silah sıkma özelliği devre dışı!")
	if not has_rleg:
		is_dashing = false
		print("⚠️ Sağ bacak yok → Dash yapılamaz!")
	if not has_lleg:
		print("⚠️ Sol bacak yok → Double Jump yapılamaz!")

func can_double_jump() -> bool:
	return has_lleg

func can_dash() -> bool:
	return has_rleg

func can_lose_part(part_name: String) -> bool:
	match part_name:
		"rarm":
			if not has_larm:
				print("Hey şuan insan olmayabilirim ama Voldemort da değilim burnum kaşınırsa naısl kaşımamı bekliyorsun ha")
				return false
		"larm":
			if not has_rarm:
				print("Hey şuan insan olmayabilirim ama Voldemort da değilim burnum kaşınırsa naısl kaşımamı bekliyorsun ha!")
				return false
		"rleg":
			if not has_lleg:
				print("Bu hayatta yeterince süründüm bi daha asla...")
				return false
		"lleg":
			if not has_rleg:
				print("Bu hayatta yeterince süründüm bi daha asla...")
				return false
		"head":
			handle_camera_on_head_loss()
	return true

func gain_body_part(part_name: String):
	match part_name:
		"head":
			if has_head:
				return
			has_head = true
		"rarm":
			if has_rarm:
				return
			has_rarm = true
		"larm":
			if has_larm:
				return
			has_larm = true
		"rleg":
			if has_rleg:
				return
			has_rleg = true
		"lleg":
			if has_lleg:
				return
			has_lleg = true

	for part in dropped_parts:
		if part and part.is_inside_tree() and part.has_method("part_name") and part.part_name == part_name:
			part.queue_free()
			dropped_parts.erase(part)
			break

	update_body_parts_visibility()
	play_animation("jump")
	await get_tree().create_timer(1.0).timeout
	play_animation("idle")

func handle_camera_on_head_loss():
	for part in dropped_parts:
		if part and part.part_name == "head" and part.is_inside_tree():
			var head_camera = part.get_node_or_null("HeadCamera")
			if head_camera:
				head_camera.current = true
				print("🎥 Kamera kafaya geçti!")
			return

func update_debug_label():
	if debug_label:
		var mouse_state_text = ""
		match mouse_state:
			MouseState.IDLE:
				mouse_state_text = "IDLE"
			MouseState.AIMING:
				var throw_distance = (throw_start_position - current_mouse_position).length()
				var actual_power = min(throw_distance, max_throw_distance)
				var distance_percentage = (actual_power / max_throw_distance) * 100.0
				mouse_state_text = "AIMING (%.0f%% | %.0f/%.0f)" % [distance_percentage, actual_power, max_throw_distance]
			MouseState.THROWING:
				mouse_state_text = "THROWING"
		
		var health_info = ""
		if health_system:
			var info = health_system.get_health_info()
			health_info = " | HP: %d/%d (%.1f%%)" % [info.current, info.max, info.percentage]
		
		debug_label.text = "State: %s | Mouse: %s | Selected: %s | Paused: %s%s" % [
			get_state_name(state), mouse_state_text, selected_part, is_game_paused, health_info
		]

func get_state_name(state_val: PlayerState) -> String:
	match state_val:
		PlayerState.IDLE:
			return "IDLE"
		PlayerState.RUN:
			return "RUN"
		PlayerState.JUMP:
			return "JUMP"
		PlayerState.FALL:
			return "FALL"
		PlayerState.DASH:
			return "DASH"
		PlayerState.ATTACK:
			return "ATTACK"
		_:
			return "UNKNOWN"

# PackedScene içindeki Area2D sinyalleri
func _connect_part_signals(part_node):
	if part_node.has_signal("player_entered_part_area"):
		part_node.connect("player_entered_part_area", Callable(self, "_on_dropped_part_area_entered"))
	if part_node.has_signal("player_exited_part_area"):
		part_node.connect("player_exited_part_area", Callable(self, "_on_dropped_part_area_exited"))
