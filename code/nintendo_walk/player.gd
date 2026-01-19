extends CharacterBody3D
## Tank-style robot controller with first-person fisheye camera

const SPEED = 5.0
const TURN_SPEED = 2.5  # Radians per second for turning

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	# No mouse capture needed - keyboard only controls
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Turning with A/D keys
	if Input.is_action_pressed("turn_left"):
		rotation.y += TURN_SPEED * delta
	if Input.is_action_pressed("turn_right"):
		rotation.y -= TURN_SPEED * delta

	# Forward/backward movement in the direction the robot is facing
	# Robot's forward is +Z axis (where sensor/lens are located)
	var input_dir = 0.0
	if Input.is_action_pressed("move_forward"):
		input_dir = 1.0
	if Input.is_action_pressed("move_backward"):
		input_dir = -1.0

	if abs(input_dir) > 0.1:
		# Move along robot's local +Z axis (forward direction)
		var forward = transform.basis.z
		velocity.x = forward.x * SPEED * input_dir
		velocity.z = forward.z * SPEED * input_dir
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 2 * delta)
		velocity.z = move_toward(velocity.z, 0, SPEED * 2 * delta)

	move_and_slide()
