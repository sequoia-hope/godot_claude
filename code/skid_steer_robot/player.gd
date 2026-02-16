extends CharacterBody3D
## Skid steer 4WD robot controller
##
## Robot dimensions: 0.8m long
## Speed: 1.5 m/s
## Controls: W/S = forward/back, A/D = turn left/right

const SPEED = 1.5  # meters per second
const TURN_SPEED = 2.0  # radians per second (skid steer turning)

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Skid steer turning with A/D keys
	if Input.is_action_pressed("turn_left"):
		rotation.y += TURN_SPEED * delta
	if Input.is_action_pressed("turn_right"):
		rotation.y -= TURN_SPEED * delta

	# Forward/backward movement in the direction robot is facing
	var input_dir = 0.0
	if Input.is_action_pressed("move_forward"):
		input_dir = 1.0
	if Input.is_action_pressed("move_backward"):
		input_dir = -1.0

	if abs(input_dir) > 0.1:
		# Move along robot's local forward axis (-Z in Godot convention)
		var forward = -transform.basis.z
		velocity.x = forward.x * SPEED * input_dir
		velocity.z = forward.z * SPEED * input_dir
	else:
		# Decelerate when no input
		velocity.x = move_toward(velocity.x, 0, SPEED * 3 * delta)
		velocity.z = move_toward(velocity.z, 0, SPEED * 3 * delta)

	move_and_slide()
