extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@onready var idle: Node2D = $idle
@onready var run: Node2D = $run
@onready var jump: Node2D = $jump
@onready var fall: Node2D = $fall



@onready var head_run: AnimatedSprite2D = $run/head_run
@onready var left_leg_run: AnimatedSprite2D = $"run/left-leg_run"
@onready var right_leg_run: AnimatedSprite2D = $"run/right-leg_run"
@onready var left_arm_run: AnimatedSprite2D = $"run/left-arm_run"
@onready var right_arm_run: AnimatedSprite2D = $run/right_arm_run
@onready var body_run: AnimatedSprite2D = $run/body_run

@onready var body_jump: AnimatedSprite2D = $jump/body_jump
@onready var head_jump: AnimatedSprite2D = $jump/head_jump
@onready var left_leg_jump: AnimatedSprite2D = $"jump/left-leg_jump"
@onready var right_leg_jump: AnimatedSprite2D = $"jump/right-leg_jump"
@onready var left_arm_jump: AnimatedSprite2D = $"jump/left-arm_jump"
@onready var right_arm_jump: AnimatedSprite2D = $jump/right_arm_jump

@onready var body_fall: AnimatedSprite2D = $fall/body_fall
@onready var head_fall: AnimatedSprite2D = $fall/head_fall
@onready var left_leg_fall: AnimatedSprite2D = $"fall/left-leg_fall"
@onready var left_arm_fall: AnimatedSprite2D = $"fall/left-arm_fall"
@onready var right_arm_fall: AnimatedSprite2D = $fall/right_arm_fall


var is_dash := false #player scriptinden de çağırılabilir.
var is_jumping := false



func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
		
		
		
	# Handle jump.
	else:
		jump.visible = false
		idle.visible = true
		is_jumping = false
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		idle.visible = false
		run.visible = false
		fall.visible = false
		jump.visible = true
		
		body_jump.play("jump")
		head_jump.play("jump")
		left_leg_jump.play("jump")
		right_leg_jump.play("jump")
		left_arm_jump.play("jump")
		right_arm_jump.play("jump")
		is_jumping = true
		
		
		
	if velocity.x > 0 and !is_jumping:
		idle.visible = false
		run.visible = true
		body_run.play("run")
		head_run.play("run")
		left_leg_run.play("run")
		right_leg_run.play("run")
		right_arm_run.play("run")
		
		
	elif velocity.x < 0 and !is_jumping:
		idle.visible = false
		run.visible = true

		body_run.play("run")
		head_run.play("run")
		left_leg_run.play("run")
		right_leg_run.play("run")
		right_arm_run.play("run")
	elif velocity.x == 0 and !is_jumping:
		run.visible = false
		idle.visible = true
	if velocity.y > 0:
		jump.visible = false
		idle.visible = false
		run.visible = false
		fall.visible = true
		body_fall.play("fall")
		head_fall.play("fall")
		left_leg_fall.play("fall")
		left_arm_fall.play("fall")
		right_arm_fall.play("fall")
	else:
		fall.visible = false
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	if is_dash: # dash bitişini nasıl anlıcaz??
		pass
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	if direction == 0:
		is_dash = false
	elif direction == 1:
		idle.skew = deg_to_rad(0)
		idle.set_rotation_degrees(0)
		run.skew = deg_to_rad(0)
		run.set_rotation_degrees(0)
		jump.skew = deg_to_rad(0)
		jump.set_rotation_degrees(0)
		fall.skew = deg_to_rad(0)
		fall.set_rotation_degrees(0)
	elif direction == -1:
		idle.skew = deg_to_rad(180)
		idle.set_rotation_degrees(180)
		run.skew = deg_to_rad(180)
		run.set_rotation_degrees(180)
		jump.skew = deg_to_rad(180)
		jump.set_rotation_degrees(180)
		fall.skew = deg_to_rad(180)
		fall.set_rotation_degrees(180)
	if velocity == Vector2.ZERO:
		pass
		print("duruyon")
	else:
		move_and_slide()
		print("AAAA")
