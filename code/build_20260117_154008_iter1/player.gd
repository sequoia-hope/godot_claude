extends CharacterBody3D

## First-person player controller with WASD movement and mouse look
## Implements physics-based movement with gravity and jumping

# Movement parameters
const WALK_SPEED := 5.0
const JUMP_VELOCITY := 6.5  # Calculated for ~2m jump height
const GRAVITY := 20.0  # Natural-feeling gravity

# Mouse look parameters
const MOUSE_SENSITIVITY := 0.002
const CAMERA_HEIGHT := 1.7

# Camera limits (prevent looking too far up/down)
const CAMERA_LIMIT_UP := -80.0
const CAMERA_LIMIT_DOWN := 80.0

# References
@onready var camera: Camera3D = $Camera3D

# Camera rotation tracking
var camera_rotation: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Position camera at head height
	camera.position.y = CAMERA_HEIGHT
	
	print("Player initialized at position: ", global_position)
	print("Camera height: ", CAMERA_HEIGHT, "m")
	print("Movement speed: ", WALK_SPEED, "m/s")

func _input(event: InputEvent) -> void: