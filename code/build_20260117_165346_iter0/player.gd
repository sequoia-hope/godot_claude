extends CharacterBody3D
## First-person player controller with WASD movement and mouse look
## Implements smooth physics-based movement with jumping

# Movement parameters
@export var walk_speed: float = 5.0
@export var jump_velocity: float = 6.4  # Calculated for ~2m jump height
@export var mouse_sensitivity: float = 0.002

# Physics parameters
var gravity: float = 20.0  # Natural feeling gravity

# Camera reference
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	print("Player initialized at position: %s" % global_position)

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		print("Player jumped!")
	
	# Get input direction
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Calculate movement direction relative to camera
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
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

func _input(event: InputEvent) -> void:
	# Handle mouse look (only when captured)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Rotate player body for horizontal look
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Rotate camera for vertical look
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		
		# Clamp vertical rotation to prevent flipping
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)