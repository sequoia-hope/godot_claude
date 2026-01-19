extends CharacterBody3D
## First-person player controller with WASD movement and mouse look
## Implements physics-based movement with jumping and gravity

## Reference to the camera node
@onready var camera: Camera3D = $Camera3D

## Movement parameters
@export var walk_speed: float = 5.0
@export var jump_velocity: float = 6.26  # Calculated for ~2m jump height
@export var mouse_sensitivity: float = 0.003

## Camera parameters
@export var camera_height: float = 1.7
@export var min_pitch: float = -89.0
@export var max_pitch: float = 89.0

## Physics parameters
var gravity: float = 15.0  # Slightly higher than default for snappier feel

## Camera rotation storage
var camera_rotation: Vector3 = Vector3.ZERO

func _ready() -> void:
	"""Initializes the player controller"""
	# Position camera at head height
	if camera:
		camera.position.y = camera_height
	
	print("Player initialized at position: %s" % global_position)

func _input(event: InputEvent) -> void:
	"""Handles mouse input for camera control"""
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_handle_mouse_look(event.relative)

func _handle_mouse_look(mouse_delta: Vector2) -> void:
	"""Processes mouse movement for camera rotation"""
	# Rotate player body horizontally (yaw)
	rotate_y(-mouse_delta.x * mouse_sensitivity)
	
	# Rotate camera vertically (pitch)
	camera_rotation.x -= mouse_delta.y * mouse_sensitivity
	camera_rotation.x = clamp(camera_rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	
	if camera:
		camera.rotation.x = camera_rotation.x

func _physics_process(delta: float) -> void:
	"""Handles player movement and physics"""
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	# Get input direction
	var input_dir := _get_input_direction()
	
	# Calculate movement direction relative to where player is facing
	var direction := _calculate_movement_direction(input_dir)
	
	# Apply movement
	if direction:
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
	else:
		# Apply friction when not moving
		velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 10)
		velocity.z = move_toward(velocity.z, 0, walk_speed * delta * 10)
	
	# Move the player
	move_and_slide()

func _get_input_direction() -> Vector2:
	"""Gets normalized input direction from WASD keys"""
	var input_dir := Vector2.ZERO

	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	return input_dir.normalized()

func _calculate_movement_direction(input_dir: Vector2) -> Vector3:
	"""Transforms 2D input direction to 3D world direction based on player facing"""
	var direction := Vector3.ZERO
	direction += transform.basis.z * input_dir.y  # Forward/backward
	direction += transform.basis.x * input_dir.x  # Left/right
	return direction.normalized() if direction.length() > 0 else Vector3.ZERO