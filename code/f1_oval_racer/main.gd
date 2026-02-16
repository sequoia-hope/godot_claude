extends Node3D
## Main scene controller for F1 Oval Racer
## Handles third-person camera with lag/smoothing

@onready var player: CharacterBody3D = $Player
@onready var track: Node3D = $Track
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

# Camera smoothing settings
const CAMERA_DISTANCE: float = 8.0
const CAMERA_HEIGHT: float = 3.5
const CAMERA_ROTATION_SPEED: float = 3.0  # Lower = more lag
const CAMERA_POSITION_SPEED: float = 8.0
const CAMERA_LOOK_AHEAD: float = 2.0  # Look slightly ahead of car

var target_rotation: float = 0.0

func _ready() -> void:
	# Position player at track start
	if track and track.has_method("get_start_position"):
		player.global_position = track.get_start_position()
		player.rotation.y = track.get_start_rotation()
		target_rotation = player.rotation.y

	# Initial camera position
	_update_camera_immediate()

func _physics_process(delta: float) -> void:
	_update_camera(delta)

func _update_camera(delta: float) -> void:
	if not player or not camera_pivot:
		return

	# Target rotation follows player with lag
	target_rotation = lerp_angle(target_rotation, player.rotation.y, CAMERA_ROTATION_SPEED * delta)

	# Camera pivot follows player position smoothly
	var target_pos = player.global_position
	camera_pivot.global_position = camera_pivot.global_position.lerp(target_pos, CAMERA_POSITION_SPEED * delta)

	# Apply rotation to pivot
	camera_pivot.rotation.y = target_rotation

	# Camera looks at a point ahead of the car
	var look_target = player.global_position - player.transform.basis.z * CAMERA_LOOK_AHEAD
	look_target.y = player.global_position.y + 0.5
	camera.look_at(look_target)

func _update_camera_immediate() -> void:
	if not player or not camera_pivot:
		return

	camera_pivot.global_position = player.global_position
	camera_pivot.rotation.y = player.rotation.y
	target_rotation = player.rotation.y

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				# Reset car to start
				if track and track.has_method("get_start_position"):
					player.global_position = track.get_start_position()
					player.rotation.y = track.get_start_rotation()
					player.velocity = Vector3.ZERO
					player.current_speed = 0.0
					_update_camera_immediate()
			KEY_ESCAPE:
				get_tree().quit()
