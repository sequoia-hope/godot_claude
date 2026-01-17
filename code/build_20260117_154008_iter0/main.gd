```gdscript
extends Node3D
## Main scene script for Test Room MVP
## Manages room setup, performance monitoring, and screenshot capture

# Performance monitoring
var fps_label: Label
var performance_container: VBoxContainer
var frame_times: Array[float] = []
const MAX_FRAME_SAMPLES := 60

# Screenshot functionality
var screenshot_counter := 0

func _ready() -> void:
	print("=== Test Room MVP Initialized ===")
	print("Room dimensions: 10m x 15m x 4m")
	
	# Setup mouse capture for first-person camera
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Create performance monitoring UI
	_setup_performance_ui()
	
	# Generate grid texture procedurally
	_create_grid_texture()
	
	print("Controls:")
	print("  WASD - Movement")
	print("  Space - Jump")
	print("  Mouse - Look around")
	print("  F12 - Screenshot")
	print("  ESC - Release mouse")

func _setup_performance_ui() -> void:
	"""Create performance monitoring overlay"""
	# Create CanvasLayer for UI
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "PerformanceUI"
	add_child(canvas_layer)
	
	# Container for performance stats
	performance_container = VBoxContainer.new()
	performance_container.position = Vector2(10, 10)
	canvas_layer.add_child(performance_container)
	
	# FPS Label
	fps_label = Label.new()
	fps_label.add_theme_font_size_override("font_size", 20)
	fps_label.add_theme_color_override("font_color", Color.YELLOW)
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 2)
	performance_container.add_child(fps_label)
	
	# Additional performance metrics
	var metrics := ["Frame Time", "Physics Time", "Process Time"]
	for metric in metrics:
		var label := Label.new()
		label.name = metric.replace(" ", "")
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 2)
		performance_container.add_child(label)

func _create_grid_texture() -> void:
	"""Generate procedural grid texture for room surfaces"""
	var image_size := 512
	var grid_size := 512 / 8  # 8 grid squares per texture
	
	# Create image
	var img := Image.create(image_size, image_size, false, Image.FORMAT_RGB8)
	
	# Fill with light gray background
	img.fill(Color(0.9, 0.9, 0.9))
	
	# Draw black grid lines
	var line_thickness := 2
	for i in range(9):  # 9 lines for 8 squares
		var pos := int(i * grid_size)
		
		# Vertical lines
		for y in range(image_size):
			for t in range(line_thickness):
				if pos + t < image_size:
					img.set_pixel(pos + t, y, Color.BLACK)
		
		# Horizontal lines
		for x in range(image_size):
			for t in range(line_thickness):
				if pos + t < image_size:
					img.set_pixel(x, pos + t, Color.BLACK)
	
	# Create texture from image
	var texture := ImageTexture.create_from_image(img)
	
	# Apply to all room meshes
	_apply_texture_to_room(texture)

func _apply_texture_to_room(texture: ImageTexture) -> void:
	"""Apply grid texture to all room surfaces"""
	var room_mesh := $RoomMesh as MeshInstance3D
	if room_mesh:
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.uv1_scale = Vector3(10, 4, 1)  # Scale texture appropriately
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		room_mesh.material_override = material

func _process(_delta: float) -> void:
	"""Update performance metrics each frame"""
	# Calculate FPS
	var fps := Engine.get_frames_per_second()
	fps_label.text = "FPS: %d" % fps
	
	# Update performance metrics
	var frame_time := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_time := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	
	# Update labels
	if performance_container.has_node("FrameTime"):
		performance_container.get_node("FrameTime").text = "Frame: %.2f ms" % frame_time
	if performance_container.has_node("PhysicsTime"):
		performance_container.get_node("PhysicsTime").text = "Physics: %.2f ms" % physics_time
	if performance_container.has_node("ProcessTime"):
		performance_container.get_node("ProcessTime").text = "Nodes: %d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	
	# Color code FPS based on performance target
	if fps >= 60:
		fps_label.add_theme_color_override("font_color", Color.GREEN)
	elif fps >= 30:
		fps_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		fps_label.add_theme_color_override("font_color", Color.RED)

func _input(event: InputEvent) -> void:
	"""Handle global input events"""
	# Toggle mouse capture with ESC
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Screenshot capture
	if Input.is_action_just_pressed("screenshot"):
		capture_screenshot()

func capture_screenshot() -> void:
	"""Capture and save screenshot"""
	await RenderingServer.frame_post_draw
	
	var img := get_viewport().get_texture().get_image()
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "screenshot_%s_%03d.png" % [timestamp, screenshot_counter]
	var path := "user://%s" % filename
	
	var err := img.save_png(path)
	if err == OK:
		screenshot_counter += 1
		print("Screenshot saved: %s" % path)
		print("Full path: %s" % ProjectSettings.globalize_path(path))
	else:
		push_error("Failed to save screenshot: %d" % err)

func get_player() -> CharacterBody3D:
	"""Helper function to get player reference"""
	return $Player as CharacterBody3D
```