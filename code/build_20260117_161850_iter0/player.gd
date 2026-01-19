extends CharacterBody3D
## First-Person Player Controller
## Handles WASD movement, mouse look, and jumping

# Movement parameters
@export var walk_speed: float = 5.0
@export var jump_velocity: float = 6.3  # Calculated for ~2m jump height
@export var mouse_sensitivity: float = 0.002

# Physics parameters
var gravity: float = 20.0  # Natural feeling gravity

# Camera reference
@onready var camera: Camera3D = $Camera3D

# Camera rotation
var camera_rotation: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Capture mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("Player initialized at position: ", global_position)


func _input(event: InputEvent) -> void:
	# Handle mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rotation.x -= event.relative.y * mouse_sensitivity
		camera_rotation.y -= event.relative.x * mouse_sensitivity
		
		# Clamp vertical rotation to prevent over-rotation
		camera_rotation.x = clamp(camera_rotation.x, -PI/2, PI/2)
		
		# Apply rotation
		camera.rotation.x = camera_rotation.x
		rotation.y = camera_rotation.y
	
	# Toggle mouse capture with Escape
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	# Get input direction
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Calculate movement direction relative to camera
	var direction := Vector3.ZERO
	if input_dir != Vector2.ZERO:
		direction = transform.basis * Vector3(input_dir.x, 0, input_dir.y)
		direction = direction.normalize