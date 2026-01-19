extends Node3D
## Main Scene - Test Room MVP
## Controls the test environment, manages room geometry, and UI overlay

# Room dimensions (in meters)
const ROOM_WIDTH: float = 10.0
const ROOM_LENGTH: float = 15.0
const ROOM_HEIGHT: float = 4.0

# Grid texture settings
const GRID_SIZE: float = 1.0  # 1 meter grid

# UI references
var fps_label: Label
var performance_overlay: Control

func _ready() -> void:
	print("Main scene initializing...")
	
	# Capture mouse for first-person control
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Create UI overlay
	_create_ui_overlay()
	
	# Build the test room
	_build_test_room()
	
	# Setup lighting
	_setup_lighting()
	
	print("Main scene ready - Test Room MVP loaded successfully")
	print("Press F12 for screenshot, ESC to release mouse")

func _process(_delta: float) -> void:
	# Update FPS display
	if fps_label:
		var stats = TestRunner.get_performance_stats()
		fps_label.text = "FPS: %d | Avg: %.1f | Min: %.1f | Max: %.1f\nFrames: %d" % [
			Engine.get_frames_per_second(),
			stats.avg_fps,
			stats.min_fps if stats.min_fps != INF else 0.0,
			stats.max_fps,
			stats.total_frames
		]

func _input(event: InputEvent) -> void:
	# Toggle mouse capture with ESC
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Creates the performance monitoring UI overlay
func _create_ui_overlay() -> void:
	performance_overlay = Control.new()
	performance_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	performance_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(performance_overlay)
	
	# FPS counter label
	fps_label = Label.new()
	fps_label.position = Vector2(10, 10)
	fps_label.add_theme_font_size_override("font_size", 18)
	fps_label.add_theme_color_override("font_color", Color.YELLOW)
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 2)
	performance_overlay.add_child(fps_label)
	
	# Instructions label
	var instructions = Label.new()
	instructions.text = "WASD - Move | SPACE - Jump | MOUSE - Look | F12 - Screenshot | ESC - Toggle Mouse"
	instructions.position = Vector2(10, 70)
	instructions.add_theme_font_size_override("font_size", 14)
	instructions.add_theme_color_override("font_color", Color.WHITE)
	instructions.add_theme_color_override("font_outline_color", Color.BLACK)
	instructions.add_theme_constant_override("outline_size", 1)
	performance_overlay.add_child(instructions)

## Builds the test room geometry with grid textures
func _build_test_room() -> void:
	var grid_material = _create_grid_material()
	
	# Floor
	var floor_mesh = _create_plane_mesh(ROOM_WIDTH, ROOM_LENGTH)
	var floor = MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.material_override = grid_material
	floor.position = Vector3(0, 0, 0)
	add_child(floor)
	
	# Floor collision
	var floor_static = StaticBody3D.new()
	floor_static.position = Vector3(0, 0, 0)
	add_child(floor_static)
	
	var floor_collision = CollisionShape3D.new()
	var floor_shape = BoxShape3D.new()
	floor_shape.size = Vector3(ROOM_WIDTH, 0.1, ROOM_LENGTH)
	floor_collision.shape = floor_shape
	floor_collision.position = Vector3(0, -0.05, 0)
	floor_static.add_child(floor_collision)
	
	# Ceiling
	var ceiling = MeshInstance3D.new()
	ceiling.mesh = floor_mesh
	ceiling.material_override = grid_material
	ceiling.position = Vector3(0, ROOM_HEIGHT, 0)
	ceiling.rotation_degrees = Vector3(180, 0, 0)
	add_child(ceiling)
	
	# North Wall (positive Z)
	var wall_mesh_long = _create_plane_mesh(ROOM_WIDTH, ROOM_HEIGHT)
	var north_wall = MeshInstance3D.new()
	north_wall.mesh = wall_mesh_long
	north_wall.material_override = grid_material
	north_wall.position = Vector3(0, ROOM_HEIGHT / 2, ROOM_LENGTH / 2)
	north_wall.rotation_degrees = Vector3(-90, 0, 0)
	add_child(north_wall)
	
	# North wall collision
	var north_static = StaticBody3D.new()
	north_static.position = Vector3(0, ROOM_HEIGHT / 2, ROOM_LENGTH / 2)
	add_child(north_static)
	
	var north_collision = CollisionShape3D.new()
	var north_shape = BoxShape3D.new()
	north_shape.size = Vector3(ROOM_WIDTH, ROOM_HEIGHT, 0.1)
	north_collision.shape = north_shape
	north_static.add_child(north_collision)
	
	# South Wall (negative Z)
	var south_wall = MeshInstance3D.new()
	south_wall.mesh = wall_mesh_long
	south_wall.material_override = grid_material
	south_wall.position = Vector3(0, ROOM_HEIGHT / 2, -ROOM_LENGTH / 2)
	south_wall.rotation_degrees = Vector3(90, 0, 0)
	add_child(south_wall)
	
	# South wall collision
	var south_static = StaticBody3D.new()
	south_static.position = Vector3(0, ROOM_HEIGHT / 2, -ROOM_LENGTH / 2)
	add_child(south_static)
	
	var south_collision = CollisionShape3D.new()
	var south_shape = BoxShape3D.new()
	south_shape.size = Vector3(ROOM_WIDTH, ROOM_HEIGHT, 0.1)
	south_collision.shape = south_shape
	south_static.add_child(south_collision)
	
	# East Wall (positive X)
	var wall_mesh_short = _create_plane_mesh(ROOM_LENGTH, ROOM_HEIGHT)
	var east_wall = MeshInstance3D.new()
	east_wall.mesh = wall_mesh_short
	east_wall.material_override = grid_material
	east_wall.position = Vector3(ROOM_WIDTH / 2, ROOM_HEIGHT / 2, 0)
	east_wall.rotation_degrees = Vector3(-90, 90, 0)
	add_child(east_wall)
	
	# East wall collision
	var east_static = StaticBody3D.new()
	east_static.position = Vector3(ROOM_WIDTH / 2, ROOM_HEIGHT / 2, 0)
	add_child(east_static)
	
	var east_collision = CollisionShape3D.new()
	var east_shape = BoxShape3D.new()
	east_shape.size = Vector3(0.1, ROOM_HEIGHT, ROOM_LENGTH)
	east_collision.shape = east_shape
	east_static.add_child(east_collision)
	
	# West Wall (negative X)
	var west_wall = MeshInstance3D.new()
	west_wall.mesh = wall_mesh_short
	west_wall.material_override = grid_material
	west_wall.position = Vector3(-ROOM_WIDTH / 2, ROOM_HEIGHT / 2, 0)
	west_wall.rotation_degrees = Vector3(90, 90, 0)
	add_child(west_wall)
	
	# West wall collision
	var west_static = StaticBody3D.new()
	west_static.position = Vector3(-ROOM_WIDTH / 2, ROOM_HEIGHT / 2, 0)
	add_child(west_static)
	
	var west_collision = CollisionShape3D.new()
	var west_shape = BoxShape3D.new()
	west_shape.size = Vector3(0.1, ROOM_HEIGHT, ROOM_LENGTH)
	west_collision.shape = west_shape
	west_static.add_child(west_collision)
	
	print("Test room built: %.1fm x %.1fm x %.1fm" % [ROOM_WIDTH, ROOM_LENGTH, ROOM_HEIGHT])

## Creates a plane mesh with specified dimensions
func _create_plane_mesh(width: float, height: float) -> PlaneMesh:
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(width, height)
	mesh.subdivide_width = int(width / GRID_SIZE)
	mesh.subdivide_depth = int(height / GRID_SIZE)
	return mesh

## Creates the grid material with procedural grid texture
func _create_grid_material() -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	
	# Create grid texture
	var grid_texture = _create_grid_texture()
	material.albedo_texture = grid_texture
	material.uv1_scale = Vector3(ROOM_WIDTH / GRID_SIZE, ROOM_LENGTH / GRID_SIZE, 1.0)
	material.uv1_triplanar = false
	
	# Material properties
	material.albedo_color = Color.WHITE
	material.metallic = 0.0
	material.roughness = 0.8
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	
	return material

## Creates a procedural grid texture (black lines on light gray background)
func _create_grid_texture() -> ImageTexture:
	var size = 128  # Texture resolution
	var line_width = 2  # Width of grid lines in pixels
	
	var img = Image.create(size, size, false, Image.FORMAT_RGB8)
	
	# Background color (light gray)
	var bg_color = Color(0.85, 0.85, 0.85)
	# Grid line color (black)
	var line_color = Color(0.0, 0.0, 0.0)
	
	# Fill with background
	img.fill(bg_color)
	
	# Draw vertical and horizontal grid lines
	for x in range(size):
		for y in range(size):
			# Draw grid lines at edges
			if x < line_width or x >= size - line_width or y < line_width or y >= size - line_width:
				img.set_pixel(x, y, line_color)
	
	var texture = ImageTexture.create_from_image(img)
	texture.set_meta("texture_filter", Texture.TEXTURE_FILTER_NEAREST)
	
	return texture

## Sets up the scene lighting
func _setup_lighting() -> void:
	# Directional light (sun-like)
	var sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.98, 0.95)
	sun.light_energy = 1.0
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.shadow_enabled = false  # Disabled for performance
	add_child(sun)
	
	# Environment with ambient lighting
	var world_env = WorldEnvironment.new()
	var environment = Environment.new()
	
	# Ambient light
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	environment.ambient_light_energy = 0.5
	
	# Background
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.6, 0.7, 0.8)
	
	# Disable advanced features for performance
	environment.ssao_enabled = false
	environment.glow_enabled = false
	environment.volumetric_fog_enabled = false
	
	world_env.environment = environment
	add_child(world_env)
	
	print("Lighting configured - DirectionalLight3D with ambient environment")