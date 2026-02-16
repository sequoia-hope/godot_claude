extends CharacterBody3D
## Skid Steer Robot Controller
## Tank steering: W/S forward/back, A/D turn left/right

const SPEED: float = 1.5  # meters per second
const TURN_SPEED: float = 2.0  # radians per second

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Get input
	var forward_input := Input.get_axis("move_backward", "move_forward")
	var turn_input := Input.get_axis("turn_right", "turn_left")

	# Apply tank steering rotation
	if turn_input != 0:
		rotate_y(turn_input * TURN_SPEED * delta)

	# Calculate forward movement in robot's local -Z direction
	var forward_dir := -transform.basis.z
	velocity.x = forward_dir.x * forward_input * SPEED
	velocity.z = forward_dir.z * forward_input * SPEED

	move_and_slide()
