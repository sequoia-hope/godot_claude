extends CharacterBody3D
## F1 Car Controller
## Arcade-style racing with visual wheel rotation

const MAX_SPEED: float = 25.0  # m/s (~90 km/h for fun oval racing)
const ACCELERATION: float = 15.0
const BRAKE_FORCE: float = 25.0
const FRICTION: float = 5.0
const TURN_SPEED: float = 2.5  # rad/s at max speed
const MIN_TURN_SPEED: float = 0.5  # Minimum steering when slow
const MAX_STEER_ANGLE: float = 0.4  # Front wheel visual turn angle (radians)

var current_speed: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Wheel references for animation
var wheel_fl: Node3D  # Front left
var wheel_fr: Node3D  # Front right
var wheel_bl: Node3D  # Back left
var wheel_br: Node3D  # Back right

func _ready() -> void:
	# Find wheel nodes
	wheel_fl = get_node_or_null("WheelFL")
	wheel_fr = get_node_or_null("WheelFR")
	wheel_bl = get_node_or_null("WheelBL")
	wheel_br = get_node_or_null("WheelBR")

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Get input
	var accel_input: float = Input.get_action_strength("accelerate")
	var brake_input: float = Input.get_action_strength("brake")
	var steer_input: float = Input.get_axis("steer_right", "steer_left")

	# Acceleration and braking
	if accel_input > 0:
		current_speed += ACCELERATION * accel_input * delta
	elif brake_input > 0:
		current_speed -= BRAKE_FORCE * brake_input * delta
	else:
		# Natural friction/drag
		current_speed = move_toward(current_speed, 0, FRICTION * delta)

	# Clamp speed
	current_speed = clamp(current_speed, -MAX_SPEED * 0.3, MAX_SPEED)

	# Steering (more responsive at lower speeds)
	var speed_factor: float = clamp(abs(current_speed) / MAX_SPEED, 0.1, 1.0)
	var effective_turn_speed: float = lerpf(TURN_SPEED * 1.5, TURN_SPEED * 0.7, speed_factor)

	if abs(current_speed) > 0.5:  # Only steer when moving
		var turn_direction: float = 1.0 if current_speed > 0 else -1.0
		rotate_y(steer_input * effective_turn_speed * turn_direction * delta)

	# Apply movement in car's forward direction (-Z is forward)
	var forward: Vector3 = -transform.basis.z
	velocity.x = forward.x * current_speed
	velocity.z = forward.z * current_speed

	move_and_slide()

	# Animate wheels
	_animate_wheels(delta, steer_input)

func _animate_wheels(delta: float, steer_input: float) -> void:
	# Calculate spin delta based on speed
	# Wheel circumference = 2 * PI * radius (0.3m) ≈ 1.88m
	# Radians per second = speed / radius
	var wheel_radius: float = 0.3
	var spin_delta: float = (current_speed / wheel_radius) * delta

	# Front wheels: steering (Y rotation on parent) + spin (around local Y - the cylinder's axis)
	if wheel_fl:
		wheel_fl.rotation.y = steer_input * MAX_STEER_ANGLE
		var mesh: Node3D = wheel_fl.get_node_or_null("WheelMesh") as Node3D
		if mesh:
			# Rotate around local Y (cylinder height axis = wheel axle)
			mesh.rotate_object_local(Vector3.UP, spin_delta)
	if wheel_fr:
		wheel_fr.rotation.y = steer_input * MAX_STEER_ANGLE
		var mesh: Node3D = wheel_fr.get_node_or_null("WheelMesh") as Node3D
		if mesh:
			# Right side wheel: spin opposite direction (axle points -X)
			mesh.rotate_object_local(Vector3.UP, -spin_delta)

	# Rear wheels: just spin around local Y
	if wheel_bl:
		var mesh: Node3D = wheel_bl.get_node_or_null("WheelMesh") as Node3D
		if mesh:
			mesh.rotate_object_local(Vector3.UP, spin_delta)
	if wheel_br:
		var mesh: Node3D = wheel_br.get_node_or_null("WheelMesh") as Node3D
		if mesh:
			mesh.rotate_object_local(Vector3.UP, -spin_delta)

func get_speed_kmh() -> float:
	return current_speed * 3.6  # Convert m/s to km/h
