extends CharacterBody3D
## First-person player controller with WASD movement and mouse look
## Implements smooth movement, jumping, and camera controls

# Movement parameters
@export var walk_speed := 5.0
@export var jump_velocity := 6.35  # Calculated for ~2m jump height
@export var mouse_sensitivity := 0.003

# Physics parameters
var gravity := 20.0  # Matches ProjectSettings default

# Camera reference
@onready var camera: Camera3D = $Camera3D

# Mouse look state
var rotation_x := 0.0
var rotation_y := 0.0

func _ready() -> void:
	print("Player initialized at position: ", global_position)
	
	# Validate camera setup
	if not camera:
		push_error("Camera3D not found as child of Player!")
		return
	
	print("Player ready - Controls: WASD - Move, Space - Jump, Mouse - Look")

func _input(event: InputEvent) -> void:
	"""Handle mouse movement for camera look"""
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Horizontal rotation (Y-axis)
		rotation_y -= event.relative.x * mouse_sensitivity
		
		# Vertical rotation (X-axis) with clamping
		rotation_x -= event.relative.y * mouse_sensitivity
		rotation_x = clamp(rotation_x, -PI / 2, PI / 2)  # -90 to +90 degrees
		
		# Apply rotations
		rotation.y = rotation_y
		camera.rotation.x = rotation_x

func _physics_process(delta: float) -> void:
	"""Handle movement and physics"""
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	# Get input direction
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.y += 1
	if Input.is_action_pressed("move_backward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
	
	# Normalize input to prevent faster diagonal movement
	input_dir = input_dir.normalized()
	
	# Calculate movement direction relative to player rotation
	var direction := Vector3.ZERO
	if input_dir != Vector2.ZERO:
		# Get the player's forward and right directions
		var forward := -transform.basis.z
		var right := transform.basis.x
		
		# Project onto horizontal plane (no vertical component)
		forward.y = 0
		forward = forward.normalized()
		right.y = 0
		right = right.normalized()
		
		# Calculate final direction
		direction = (forward * input_dir.y + right * input_dir.x).normalized()
	
	# Apply movement
	if direction != Vector3.ZERO:
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
	else:
		# Apply friction
		velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 10)
		velocity.z = move_toward(velocity.z, 0, walk_speed * delta * 10)
	
	# Move the character
	move_and_slide()

func get_camera_global_position() -> Vector3:
	"""Helper to get camera world position"""
	return camera.global_position if camera else global_position

func get_forward_direction() -> Vector3:
	"""Get the direction the player is facing"""
	return -transform.basis.z