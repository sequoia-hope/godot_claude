extends Node3D
## Main scene controller for Test Room MVP
## Manages room creation, player spawn, lighting, and performance monitoring

## Reference to the player node
@onready var player: CharacterBody3D = $Player
## Reference to performance monitor UI
@onready var performance_monitor: Control = $PerformanceMonitor

## Room dimensions in meters
const ROOM_WIDTH: float = 10.0
const ROOM_LENGTH: float = 15.0
const ROOM_HEIGHT: float = 4.0
const GRID_SIZE: float = 1.0

## Grid texture material
var grid_material: StandardMaterial3D

func _ready() -> void:
	print("=== Test Room MVP - Initializing ===")
	
	# Setup mouse capture for first-person control
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Create grid material
	_create_grid_material()
	
	# Build the room
	_build_room()
	
	# Setup lighting
	_setup_lighting()
	
	# Initialize performance monitoring
	_setup_performance_monitor()
	
	print("=== Test Room MVP - Ready ===")
	print("Controls: WASD - Move, Space - Jump, Mouse - Look, F12 - Screenshot, ESC - Release Mouse")

func _create_grid_material() -> void:
	"""Creates a procedural grid material for room surfaces"""
	grid_material = StandardMaterial3D.new()
	
	# Create grid texture programmatically
	var grid_texture := _generate_grid_texture()
	
	grid_material.albedo_texture = grid_texture
	grid_material.albedo_color = Color(0.95, 0.95, 0.95)
	grid_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	grid_material.uv1_scale = Vector3(1, 1, 1)
	grid_material.metallic = 0.0
	grid_material.roughness = 0.9

func _generate_grid_texture() -> ImageTexture:
	"""Generates a 1-meter grid pattern texture"""
	var size := 512
	var grid_width := 4  # Width of grid lines in pixels
	
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	
	# Fill with light gray background
	image.fill(Color(0.95, 0.95, 0.95))
	
	# Draw black grid lines
	for x in range(size):
		for y in range(size):
			# Vertical lines
			if x % (size / 10) < grid_width:
				image.set_pixel(x, y, Color.BLACK)
			# Horizontal lines
			if y % (size / 10) < grid_width:
				image.set_pixel(x, y, Color.BLACK)
	
	return ImageTexture.create_from_image(image)

func _build_room() -> void:
	"""Constructs the room geometry with floor, ceiling, and walls"""
	print("Building room: %.1f x %.1f x %.1f meters" % [ROOM_WIDTH, ROOM_LENGTH, ROOM_HEIGHT])
	
	# Create floor
	_create_surface("Floor", 
		Vector3(0, 0, 0),
		Vector3(ROOM_WIDTH, 0.1, ROOM_LENGTH),
		Vector3(ROOM_WIDTH / GRID_SIZE, 1, ROOM_LENGTH / GRID_SIZE))
	
	# Create ceiling
	_create_surface("Ceiling",
		Vector3(0, ROOM_HEIGHT, 0),
		Vector3(ROOM_WIDTH, 0.1, ROOM_LENGTH),
		Vector3(ROOM_WIDTH / GRID_SIZE, 1, ROOM_LENGTH / GRID_SIZE))
	
	# Create walls
	# North wall (+Z)
	_create_surface("WallNorth",
		Vector3(0, ROOM_HEIGHT / 2, ROOM_LENGTH / 2),
		Vector3(ROOM_WIDTH, ROOM_HEIGHT, 0.1),
		Vector3(ROOM_WIDTH / GRID_SIZE, ROOM_HEIGHT / GRID_SIZE, 1))
	
	# South wall (-Z)
	_create_surface("WallSouth",
		Vector3(0, ROOM_HEIGHT / 2, -ROOM_LENGTH / 2),
		Vector3(ROOM_WIDTH, ROOM_HEIGHT, 0.1),
		Vector3(ROOM_WIDTH / GRID_SIZE, ROOM_HEIGHT / GRID_SIZE, 1))
	
	# East wall (+X)
	_create_surface("WallEast",
		Vector3(ROOM_WIDTH / 2, ROOM_HEIGHT / 2, 0),
		Vector3(0.1, ROOM_HEIGHT, ROOM_LENGTH),
		Vector3(1, ROOM_HEIGHT / GRID_SIZE, ROOM_LENGTH / GRID_SIZE))
	
	# West wall (-X)
	_create_surface("WallWest",
		Vector3(-ROOM_WIDTH / 2, ROOM_HEIGHT / 2, 0),
		Vector3(0.1, ROOM_HEIGHT, ROOM_LENGTH),
		Vector3(1, ROOM_HEIGHT / GRID_SIZE, ROOM_LENGTH / GRID_SIZE))

func _create_surface(surface_name: String, pos: Vector3, dimensions: Vector3, uv_scale: Vector3) -> void:
	"""Creates a single room surface with collision"""
	var static_body := StaticBody3D.new()
	static_body.name = surface_name
	static_body.position = pos
	
	# Create visual mesh
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = dimensions
	mesh_instance.mesh = box_mesh
	
	# Apply grid material with appropriate UV scaling
	var surface_material := grid_material.duplicate()
	surface_material.uv1_scale = uv_scale
	mesh_instance.material_override = surface_material
	
	# Create collision shape
	var collision_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = dimensions
	collision_shape.shape = box_shape
	
	# Assemble hierarchy
	static_body.add_child(mesh_instance)
	static_body.add_child(collision_shape)
	add_child(static_body)

func _setup_lighting() -> void:
	"""Sets up the scene lighting"""
	# Create directional light
	var directional_light := DirectionalLight3D.new()
	directional_light.name = "DirectionalLight"
	directional_light.position = Vector3(3, 5, 3)
	directional_light.rotation_degrees = Vector3(-45, 30, 0)
	directional_light.light_energy = 0.8
	directional_light.light_color = Color(1.0, 0.98, 0.95)
	directional_light.shadow_enabled = false  # Disabled for performance
	add_child(directional_light)
	
	# Create ambient light using WorldEnvironment
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.8, 0.85, 0.9)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.9, 0.9, 0.9)
	environment.ambient_light_energy = 0.6
	world_env.environment = environment
	add_child(world_env)
	
	print("Lighting setup complete")

func _setup_performance_monitor() -> void:
	"""Initializes the performance monitoring UI"""
	if performance_monitor:
		performance_monitor.visible = true
		print("Performance monitor active")

func _input(event: InputEvent) -> void:
	"""Handles global input events"""
	# Toggle mouse capture with ESC
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Screenshot capture
	if event.is_action_pressed("screenshot"):
		_capture_screenshot()

func _capture_screenshot() -> void:
	"""Captures and saves a screenshot"""
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "user://screenshot_%s.png" % timestamp
	image.save_png(filename)
	print("Screenshot saved: %s" % filename)
