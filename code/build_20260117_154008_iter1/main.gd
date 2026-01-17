extends Node3D

## Main scene controller for Test Room
## Handles room generation, lighting setup, and performance monitoring

# Room dimensions
const ROOM_WIDTH := 10.0
const ROOM_LENGTH := 15.0
const ROOM_HEIGHT := 4.0
const GRID_SIZE := 1.0

# Performance monitoring
var fps_label: Label
var performance_label: Label
var frame_times: Array[float] = []
const MAX_FRAME_SAMPLES := 60

func _ready() -> void:
	# Capture mouse for first-person camera control
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Build the room
	_create_room()
	
	# Setup UI for performance monitoring
	_setup_performance_ui()
	
	# Allow escape to quit
	set_process_input(true)
	
	print("Test Room initialized successfully")
	print("Room dimensions: ", ROOM_WIDTH, "m x ", ROOM_LENGTH, "m x ", ROOM_HEIGHT, "m")

func _input(event: InputEvent) -> void:
	# Toggle mouse capture with Escape
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Screenshot capture
	if event.is_action_pressed("screenshot"):
		_capture_screenshot()

func _process(delta: float) -> void:
	_update_performance_stats(delta)

func _create_room() -> void:
	"""Create the test room with walls, floor, and ceiling"""
	var grid_material := _create_grid_material()
	
	# Floor
	_create_plane("Floor", Vector3(0, 0, 0), Vector3(ROOM_WIDTH, 1, ROOM_LENGTH), grid_material)
	
	# Ceiling
	_create_plane("Ceiling", Vector3(0, ROOM_HEIGHT, 0), Vector3(ROOM_WIDTH, 1, ROOM_LENGTH), grid_material, true)
	
	# Back wall (along Z axis)
	_create_plane("WallBack", Vector3(0, ROOM_HEIGHT/2, -ROOM_LENGTH/2), Vector3(ROOM_WIDTH, ROOM_HEIGHT, 1), grid_material, false, Vector3(90, 0, 0))
	
	# Front wall
	_create_plane("WallFront", Vector3(0, ROOM_HEIGHT/2, ROOM_LENGTH/2), Vector3(ROOM_WIDTH, ROOM_HEIGHT, 1), grid_material, false, Vector3(-90, 0, 0))
	
	# Left wall (along X axis)
	_create_plane("WallLeft", Vector3(-ROOM_WIDTH/2, ROOM_HEIGHT/2, 0), Vector3(1, ROOM_HEIGHT, ROOM_LENGTH), grid_material, false, Vector3(0, 0, -90))
	
	# Right wall
	_create_plane("WallRight", Vector3(ROOM_WIDTH/2, ROOM_HEIGHT/2, 0), Vector3(1, ROOM_HEIGHT, ROOM_LENGTH), grid_material, false, Vector3(0, 0, 90))

func _create_plane(plane_name: String, pos: Vector3, size: Vector3, material: StandardMaterial3D, flip_normal := false, rotation_deg := Vector3.ZERO) -> void:
	"""Create a plane mesh for walls, floor, or ceiling"""
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = plane_name
	
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(size.x, size.z if size.z > 1 else size.y)
	
	# Create custom mesh with UVs for proper grid texture tiling
	var arrays := plane_mesh.get_mesh_arrays()
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Create quad with proper UV mapping for grid texture
	var half_width := plane_mesh.size.x / 2.0
	var half_height := plane_mesh.size.y / 2.0
	var uv_scale_x := plane_mesh.size.x / GRID_SIZE
	var uv_scale_y := plane_mesh.size.y / GRID_SIZE
	
	if flip_normal:
		surface_tool.set_normal(Vector3.DOWN)
	else:
		surface_tool.set_normal(Vector3.UP)
	
	# Bottom-left
	surface_tool.set_uv(Vector2(0, uv_scale_y))
	surface_tool.add_vertex(Vector3(-half_width, 0, half_height))
	
	# Bottom-right
	surface_tool.set_uv(Vector2(uv_scale_x, uv_scale_y))
	surface_tool.add_vertex(Vector3(half_width, 0, half_height))
	
	# Top-right
	surface_tool.set_uv(Vector2(uv_scale_x, 0))
	surface_tool.add_vertex(Vector3(half_width, 0, -half_height))
	
	# Top-left
	surface_tool.set_uv(Vector2(0, 0))
	surface_tool.add_vertex(Vector3(-half_width, 0, -half_height))
	
	if flip_normal:
		surface_tool.add_index(0)
		surface_tool.add_index(2)
		surface_tool.add_index(1)
		surface_tool.add_index(0)
		surface_tool.add_index(3)
		surface_tool.add_index(2)
	else:
		surface_tool.add_index(0)
		surface_tool.add_index(1)
		surface_tool.add_index(2)
		surface_tool.add_index(0)
		surface_tool.add_index(2)
		surface_tool.add_index(3)
	
	surface_tool.set_material(material)
	mesh_instance.mesh = surface_tool.commit()
	
	# Add collision
	var static_body := StaticBody3D.new()
	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 0.1, size.z if size.z > 1 else size.y)
	collision_shape.shape = shape
	static_body.add_child(collision_shape)
	mesh_instance.add_child(static_body)
	
	# Set position and rotation
	mesh_instance.position = pos
	mesh_instance.rotation_degrees = rotation_deg
	
	add_child(mesh_instance)

func _create_grid_material() -> StandardMaterial3D:
	"""Create a procedural grid texture material"""
	var material := StandardMaterial3D.new()
	
	# Create grid texture
	var grid_texture := _generate_grid_texture()
	material.albedo_texture = grid_texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.uv1_scale = Vector3(1, 1, 1)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	return material

func _generate_grid_texture() -> ImageTexture:
	"""Generate a 1-meter grid texture procedurally"""
	const TEXTURE_SIZE := 128
	const LINE_WIDTH := 2
	
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGB8)
	
	# Fill with light gray background
	image.fill(Color(0.9, 0.9, 0.9))
	
	# Draw black grid lines
	for x in range(TEXTURE_SIZE):
		for y in range(TEXTURE_SIZE):
			# Vertical lines
			if x < LINE_WIDTH or x >= TEXTURE_SIZE - LINE_WIDTH:
				image.set_pixel(x, y, Color.BLACK)
			# Horizontal lines
			if y < LINE_WIDTH or y >= TEXTURE_SIZE - LINE_WIDTH:
				image.set_pixel(x, y, Color.BLACK)
	
	return ImageTexture.create_from_image(image)

func _setup_performance_ui() -> void:
	"""Setup performance monitoring UI overlay"""
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "PerformanceUI"
	add_child(canvas_layer)
	
	var container := VBoxContainer.new()
	container.position = Vector2(10, 10)
	canvas_layer.add_child(container)
	
	# FPS counter
	fps_label = Label.new()
	fps_label.add_theme_font_size_override("font_size", 20)
	fps_label.text = "FPS: 0"
	container.add_child(fps_label)
	
	# Performance stats
	performance_label = Label.new()
	performance_label.add_theme_font_size_override("font_size", 16)
	performance_label.text = "Performance: OK"
	container.add_child(performance_label)
	
	# Instructions
	var instructions := Label.new()
	instructions.add_theme_font_size_override("font_size", 14)
	instructions.text = "WASD: Move | Space: Jump | Mouse: Look | ESC: Toggle Mouse | F12: Screenshot"
	instructions.position = Vector2(10, DisplayServer.window_get_size().y - 40)
	canvas_layer.add_child(instructions)

func _update_performance_stats(delta: float) -> void:
	"""Update performance monitoring labels"""
	var current_fps := Engine.get_frames_per_second()
	fps_label.text = "FPS: %d" % current_fps
	
	# Track frame times
	frame_times.append(delta)
	if frame_times.size() > MAX_FRAME_SAMPLES:
		frame_times.pop_front()
	
	# Calculate average frame time
	var avg_frame_time := 0.0
	for ft in frame_times:
		avg_frame_time += ft
	avg_frame_time /= frame_times.size()
	
	var avg_fps := 1.0 / avg_frame_time if avg_frame_time > 0 else 0
	
	# Update performance label
	var status := "OK" if avg_fps >= 60 else "WARNING"
	var color_code := "[color=green]" if avg_fps >= 60 else "[color=yellow]"
	
	performance_label.text = "Avg FPS: %.1f | Status: %s%s[/color]" % [avg_fps, color_code, status]
	performance_label.set("theme_override_colors/font_color", Color.GREEN if avg_fps >= 60 else Color.YELLOW)

func _capture_screenshot() -> void:
	"""Capture and save a screenshot"""
	var image := get_viewport().get_texture().get_image()
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "screenshot_%s.png" % timestamp
	var path := "user://%s" % filename
	
	image.save_png(path)
	print("Screenshot saved: ", ProjectSettings.globalize_path(path))