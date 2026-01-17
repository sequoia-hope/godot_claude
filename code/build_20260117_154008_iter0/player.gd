```gdscript
extends CharacterBody3D
## First-person player controller
## Features: WASD movement, mouse look, jumping, smooth camera control

# Movement parameters
@export var walk_speed := 5.0
@export var jump_velocity := 6.3  # Calculated for ~2m jump height
@export var mouse_sensitivity := 0.003

# Camera parameters
@export var camera_height := 1.7

# Internal state
var gravity := 18.0  # Natural feeling gravity
var camera: Camera3D
var rotation_helper: Node3D

func _ready() -> void:
	# Setup rotation helper for camera pitch
	rotation_helper = Node3D.new()
	rotation_helper.name = "RotationHelper"
	add_child(rotation_helper)
	
	# Create and setup camera
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position.y = camera_height
	rotation_helper.add_child(camera)
	
	# Configure camera settings
	camera.fov = 75.0
	camera.near = 0.05
	camera.far = 1000.0
	
	print("Player initialized at position: %v" % global_position)

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		print("Player jumped")
	
	# Get input direction
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Calculate movement direction relative to player rotation
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Apply movement
	if direction:
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
	else:
		# Smooth deceleration
		velocity.x = move_toward(velocity.x, 0, walk_speed * delta * 10.0)
		velocity.z = move_toward(velocity.z, 0, walk_speed * delta * 10.0)
	
	# Move the player
	move_and_slide()

func _input(event: InputEvent) -> void:
	# Handle mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Rotate player body horizontally
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Rotate camera vertically (with clamping)
		rotation_helper.rotate_x(-event.relative.y * mouse_sensitivity)
		rotation_helper.rotation.x = clamp(rotation_helper.rotation.x, -PI/2, PI/2)

func get_camera() -> Camera3D:
	"""Get camera reference for external access"""
	return camera
```