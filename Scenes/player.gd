extends CharacterBody2D

@export var speed: float = 400
@export var base_jump_force: float = 900
@export var base_gravity: float = 2500
@export var max_jump_time: float = 0.3
@export var extra_jump_force: float = 500
@export var fast_fall_multiplier: float = 1.5
@export var jump_buffer_time: float = 0.5

var hp = 100
var killed: bool = false
var paused: bool = false

# Internals
var jump_timer: float = 0.0
var is_jumping: bool = false
var jump_buffer: float = 0.0
var gravity_dir: int = 1 # 1 = normal gravity, -1 = upside-down

func _ready() -> void:
	print("cha read")

func _process(_delta: float) -> void:
	if paused:
		return
	
	# Sprint zoom
	if Input.is_action_pressed("sprint"): 
		var tween = $Camera2D.create_tween()
		tween.tween_property($Camera2D, "zoom", Vector2(0.94, 0.94), 0.5)
		tween.parallel().tween_property($Camera2D, "position_smoothing_speed", 11, 0.75)
		speed = 550 * 1.82
	else:
		var tween = $Camera2D.create_tween()
		tween.tween_property($Camera2D, "zoom", Vector2(0.8, 0.8), 0.5)
		tween.parallel().tween_property($Camera2D, "position_smoothing_speed", 4, 0.75)
		speed = 550

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("switch"):
		switch_gravity()
	
	if event.is_action_pressed("fast_switch"):
		f_switch()
	
	if event.is_action_pressed("f_switch_up"):
		f_switch(1)
	
	if event.is_action_pressed("f_switch_down"):
		f_switch(-1)

# normal gravity switch
func switch_gravity():
	print("SWITCHED (normal)")
	gravity_dir *= -1

func f_switch(dir: int = 0): # if dir is 1 force up raycast if dir is -1 force down raycast
	print("FAST SWITCH")

	var target_ray: RayCast2D
	if dir == 0 and gravity_dir == 1:
		target_ray = $down # normal gravity find platform below
	elif dir == 0 and gravity_dir == -1:
		target_ray = $up # upside down find platform above
	elif dir == 1:
		gravity_dir = -1
		target_ray = $up
		print("force up")
	elif dir == -1:
		gravity_dir = 1
		target_ray = $down
		print("force down")

	target_ray.force_raycast_update()

	if target_ray.is_colliding():
		var hit_pos: Vector2 = target_ray.get_collision_point()
		var collider = target_ray.get_collider()

		# Align with the hit position
		global_position.y = hit_pos.y
		print("Teleported to new platform:", collider)
	else:
		print("No platform found by RayCast!")

func _physics_process(delta: float) -> void:
	if killed or paused:
		return

	# buffer
	if Input.is_action_just_pressed("up"):
		jump_buffer = jump_buffer_time
	elif jump_buffer > 0:
		jump_buffer -= delta

	# if down is pressed u go down a bit faster
	if not is_on_floor_custom():
		var grav = base_gravity * gravity_dir
		if Input.is_action_pressed("down"):
			grav *= fast_fall_multiplier
		velocity.y += grav * delta

		# the longer u hold the higher u hump
		if is_jumping:
			jump_timer += delta
			if Input.is_action_pressed("up") and jump_timer < max_jump_time:
				velocity.y -= extra_jump_force * delta * gravity_dir
			else:
				is_jumping = false
	else:
		is_jumping = false
		jump_timer = 0.0

		# Jump (gd type buffer)
		if jump_buffer > 0 or Input.is_action_just_pressed("up"):
			velocity.y = -base_jump_force * gravity_dir
			print("Jump triggered")
			is_jumping = true
			jump_timer = 0.0
			jump_buffer = 0.0

	# side to side move
	var input_direction = Input.get_axis("left", "right")
	velocity.x = input_direction * speed
	
	move_and_slide()

	# face sprite
	if input_direction != 0:
		var facing = sign(input_direction)
		$sprite.scale.x = abs($sprite.scale.x) * facing
		$hitbox.scale.x = abs($hitbox.scale.x) * facing


# Custom check for floor based on gravity direction
func is_on_floor_custom() -> bool:
	if gravity_dir == 1:
		return is_on_floor()
	else:
		return is_on_ceiling()
