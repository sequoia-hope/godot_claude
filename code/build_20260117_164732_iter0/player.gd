extends CharacterBody3D
## First-Person Player Controller
## Handles movement, jumping, camera control for test room navigation

# Movement parameters
const WALK_SPEED: float = 5.0
const JUMP_VELOCITY: float = 6.36  # Calculated for ~2m jump height
const GRAVITY: float = 20.0  # Standard gravity

# Camera parameters
const MOUSE_SENSITIVITY: float = 0.002
const CAMERA_HEIGHT: float = 1.7  # Eye level height

# Look constraints
const LOOK_UP_LIMIT: float = -89.0
const LOOK_DOWN_LIMIT: float = 89.0

# Camera reference
var camera: Camera3D
var camera_rotation_x: float = 0.0

func _ready() -> void:
	# Setup camera as child node
	camera = Camera3D.new()
	camera.position = Vector3(0, CAMERA_HEIGHT, 0)
	camera.fov = 75.0
	add_child(camera)
	
	print("Player initialized at position: ", global_position)
	print("Camera height: %.2fm" % CAMERA_HEIGHT)

func _input(event: InputEvent) -> void:
	# Handle mouse look (only when captured)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_handle_camera_rotation(event)

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	
	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Get input direction
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Calculate movement direction relative to where player is looking
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Apply horizontal movement
	if direction:
		velocity.x = direction.x * WALK_SPEED
		velocity.z = direction.z * WALK_SPEED
	else:
		# Apply friction when not moving
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED * delta * 10.0)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED * delta * 10.0)
	
	# Move the character
	move_and_slide()

## Handles camera rotation based on mouse movement
func _handle_camera_rotation(event: InputEventMouseMotion) -> void:
	# Rotate player body on Y axis (horizontal look)
	rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
	
	# Rotate camera on X axis (vertical look) with limits
	camera_rotation_x -= event.relative.y * MOUSE_SENSITIVITY
	camera_rotation_x = clamp(camera_rotation_x, deg_to_rad(LOOK_UP_LIMIT), deg_to_rad(LOOK_DOWN_LIMIT))
	
	# Apply rotation to camera
	camera.rotation.x = camera_rotation_x

## Returns current camera direction for debugging
func get_look_direction() -> Vector3:
	return -camera.global_transform.basis.z

## Returns current movement speed for debugging
func get_current_speed() -> float:
	return Vector3(velocity.x, 0, velocity.z).length()