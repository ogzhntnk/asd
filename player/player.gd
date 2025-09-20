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

# --- Player State Enum ---
enum PlayerState { IDLE, RUN, JUMP, FALL, DASH, ATTACK }
var state: PlayerState = PlayerState.IDLE

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

# --- PackedScene referansları (Inspector'dan atanacak) ---
@export var head_scene: PackedScene
@export var rarm_scene: PackedScene
@export var larm_scene: PackedScene
@export var rleg_scene: PackedScene
@export var lleg_scene: PackedScene

# --- Sahnedeki düşen parçalar (PackedScene instance'ları) ---
var dropped_parts := []

# --- Oyuncunun şu anda hangi düşen parçanın Area2D'sinde olduğu ---
var current_area_part: String = ""

func _ready():
	update_body_parts_visibility()
	reset_parts_color()

func _physics_process(delta):
	handle_input()
	apply_gravity(delta)
	apply_manual_movement()
	apply_skills()
	handle_state(delta)
	move_and_slide()
	update_debug_label()

func handle_input():
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

	# Etkileşim (E tuşu)
	if Input.is_action_just_pressed("interact"):
		interact_with_part()

	# Parça seçme
	if Input.is_action_just_pressed("select_head"):
		select_body_part(1)
	elif Input.is_action_just_pressed("select_rarm"):
		select_body_part(2)
	elif Input.is_action_just_pressed("select_larm"):
		select_body_part(3)
	elif Input.is_action_just_pressed("select_rleg"):
		select_body_part(4)
	elif Input.is_action_just_pressed("select_lleg"):
		select_body_part(5)

	# Parçayı bırak (F tuşu - lose_selected_part input map)
	if Input.is_action_just_pressed("lose_selected_part"):
		drop_selected_part()

	# Vücudu tamamla (R tuşu)
	if Input.is_action_just_pressed("reset_all_parts"):
		reset_all_parts()

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

		# PackedScene içindeki Area2D sinyallerini bağla
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
		print("⚠️ Sağ el yok → Fırlatma gücünün %50’si kayboldu!")
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
				print("Hey şuan insan olmayabilirim ama Voldemort da değilim burnum kaşınırsa naısl kaşımamı bekliyorsun ha")
				return false
		"larm":
			if not has_rarm:
				print("Hey şuan insan olmayabilirim ama Voldemort da değilim burnum kaşınırsa naısl kaşımamı bekliyorsun ha!")
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
		debug_label.text = "State: %s" % get_state_name(state)

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
	return "ERRORRRR"

# PackedScene içindeki Area2D sinyalleri
func _connect_part_signals(part_node):
	if part_node.has_signal("player_entered_part_area"):
		part_node.connect("player_entered_part_area", Callable(self, "_on_dropped_part_area_entered"))
	if part_node.has_signal("player_exited_part_area"):
		part_node.connect("player_exited_part_area", Callable(self, "_on_dropped_part_area_exited"))

# Sinyal callback 
func _on_dropped_part_area_entered(part_name: String):
	current_area_part = part_name

func _on_dropped_part_area_exited(part_name: String):
	if current_area_part == part_name:
		current_area_part = ""

func interact_with_part():
	match current_area_part:
		"head":
			if not has_head:
				has_head = true
		"rarm":
			if not has_rarm:
				has_rarm = true
		"larm":
			if not has_larm:
				has_larm = true
		"rleg":
			if not has_rleg:
				has_rleg = true
		"lleg":
			if not has_lleg:
				has_lleg = true

	for part in dropped_parts:
		if part and part.is_inside_tree() and part.part_name == current_area_part:
			part.queue_free()
			dropped_parts.erase(part)
			break


	update_body_parts_visibility()
	play_animation("jump") # burda yerden alıp takıyor uptade diye yeni animasyon yapmaktansa jump animasyonu ile ört bas et gitsin
	await get_tree().create_timer(0.5).timeout
	play_animation("idle")
