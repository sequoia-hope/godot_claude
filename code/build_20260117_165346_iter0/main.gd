extends Node3D
## Main scene controller for Test Room MVP
## Handles room setup, performance monitoring, and screenshot capture

# Performance monitoring variables
var fps_label: Label
var performance_panel: PanelContainer
var frame_times: Array[float] = []
var max_frame_time_samples: int = 60

func _ready() -> void:
	print("=== Test Room MVP Initializing ===")
	
	# Set up mouse capture for first-person camera control
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Create performance UI
	_setup_performance_ui()
	
	# Create grid materials
	_create_grid_materials()
	
	print("=== Test Room MVP Ready ===")
	print("Controls:")
	print("  WASD - Movement")
	print("  Space - Jump")
	print("  Mouse - Look around")
	print("  F12 - Screenshot")
	print("  ESC - Release/Capture mouse")

func _setup_performance_ui() -> void:
	"""Create FPS counter and performance monitoring UI"""
	# Create canvas layer for UI
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "PerformanceUI"
	add_child(canvas_layer)
	
	# Create panel container
	performance_panel = PanelContainer.new()
	performance_panel.position = Vector2(10, 10)
	canvas_layer.add_child(performance_panel)
	
	# Style the panel
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0, 0, 0, 0.7)
	style_box.set_corner_radius_all(5)
	style_box.content_margin_left = 10
	style_box.content_margin_right = 10
	style_box.content_margin_top = 5
	style_box.content_margin_bottom = 5
	performance_panel.add_theme_stylebox_override("panel", style_box)
	
	# Create VBox for labels
	var vbox := VBoxContainer.new()
	performance_panel.add_child(vbox)
	
	# FPS Label
	fps_label = Label.new()
	fps_label.add_theme_font_size_override("font_size", 16)
	fps_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(fps_label)

func _create_grid_materials() -> void:
	"""Create procedural grid texture materials for room surfaces"""
	var grid_texture := _generate_grid_texture()
	
	# Apply to all MeshInstance3D nodes
	for child in get_children():
		if child is MeshInstance3D and child.name.begins_with("Room"):
			var material := StandardMaterial3D.new()
			material.albedo_texture = grid_texture
			material.uv1_scale = Vector3(1, 1, 1)
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			child.material_override = material

func _generate_grid_texture() -> ImageTexture:
	"""Generate a 1-meter grid pattern texture"""
	var size := 512
	var grid_size := 64  # Pixels per grid square (512/8 = 64 for 8x8 grid)
	var line_width := 2
	
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	
	# Fill with light gray background
	image.fill(Color(0.9, 0.9, 0.9))
	
	# Draw vertical lines
	for x in range(0, size + 1, grid_size):
		for y in range(size):
			for lw in range(line_width):
				if x + lw < size:
					image.set_pixel(x + lw, y, Color.BLACK)
	
	# Draw horizontal lines
	for y in range(0, size + 1, grid_size):
		for x in range(size):
			for lw in range(line_width):
				if y + lw < size:
					image.set_pixel(x, y + lw, Color.BLACK)
	
	return ImageTexture.create_from_image(image)

func _process(_delta: float) -> void:
	"""Update performance metrics each frame"""
	# Update FPS counter
	var fps := Engine.get_frames_per_second()
	var frame_time := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	
	# Track frame times
	frame_times.append(frame_time)
	if frame_times.size() > max_frame_time_samples:
		frame_times.pop_front()
	
	# Calculate average frame time
	var avg_frame_time := 0.0
	for ft in frame_times:
		avg_frame_time += ft
	avg_frame_time /= frame_times.size()
	
	# Get memory usage
	var memory_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
	
	# Update label
	fps_label.text = "FPS: %d (%.2f ms avg)\nMemory: %.1f MB" % [fps, avg_frame_time, memory_mb]
	
	# Handle screenshot
	if Input.is_action_just_pressed("screenshot"):
		capture_screenshot()
	
	# Handle mouse capture toggle
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func capture_screenshot() -> void:
	"""Capture and save a screenshot"""
	await RenderingServer.frame_post_draw
	
	var image := get_viewport().get_texture().get_image()
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "user://screenshot_%s.png" % timestamp
	
	var error := image.save_png(filename)
	if error == OK:
		print("Screenshot saved: %s" % filename)
		print("Actual path: %s" % ProjectSettings.globalize_path(filename))
	else:
		print("Failed to save screenshot: Error %d" % error)