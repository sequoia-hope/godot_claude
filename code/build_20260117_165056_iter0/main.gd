extends Node3D
## Main scene controller for Test Room MVP
## Manages environment setup, performance monitoring, and screenshot capture

# Performance monitoring variables
var fps_label: Label
var performance_panel: PanelContainer
var frame_times: Array[float] = []
var max_frame_time_samples := 60

# Screenshot system
var screenshot_counter := 0
var screenshot_dir := "user://screenshots"

func _ready() -> void:
	print("=== Test Room - MVP Milestone ===")
	print("Initializing scene...")
	
	# Set up input mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Create screenshot directory
	_ensure_screenshot_directory()
	
	# Set up performance monitoring UI
	_setup_performance_ui()
	
	# Configure environment
	_setup_environment()
	
	print("Scene initialization complete!")
	print("Controls: WASD - Move, Space - Jump, Mouse - Look, F12 - Screenshot, ESC - Release Mouse")

func _setup_environment() -> void:
	"""Configure rendering environment for optimal performance"""
	# Get or create environment
	var env := Environment.new()
	
	# Set up basic ambient lighting
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.ambient_light_energy = 0.5
	
	# Disable expensive effects for performance
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.glow_enabled = false
	env.volumetric_fog_enabled = false
	
	# Set background to sky color
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.7, 0.8)
	
	# Create WorldEnvironment if it doesn't exist
	var world_env := get_node_or_null("WorldEnvironment")
	if not world_env:
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		add_child(world_env)
	
	world_env.environment = env

func _setup_performance_ui() -> void:
	"""Create and configure the performance monitoring overlay"""
	# Create UI layer
	var canvas := CanvasLayer.new()
	canvas.name = "PerformanceUI"
	add_child(canvas)
	
	# Create panel container
	performance_panel = PanelContainer.new()
	performance_panel.position = Vector2(10, 10)
	canvas.add_child(performance_panel)
	
	# Style the panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.border_color = Color(0.3, 0.3, 0.3)
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	performance_panel.add_theme_stylebox_override("panel", style)
	
	# Create VBox for labels
	var vbox := VBoxContainer.new()
	performance_panel.add_child(vbox)
	
	# FPS Label
	fps_label = Label.new()
	fps_label.add_theme_color_override("font_color", Color.WHITE)
	fps_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(fps_label)
	
	# Additional performance labels
	for stat in ["Memory", "Physics", "Draw Calls"]:
		var label := Label.new()
		label.name = stat.replace(" ", "") + "Label"
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(label)

func _process(delta: float) -> void:
	"""Update performance monitoring each frame"""
	# Track frame times
	frame_times.append(delta)
	if frame_times.size() > max_frame_time_samples:
		frame_times.pop_front()
	
	# Calculate average FPS
	var avg_delta := 0.0
	for ft in frame_times:
		avg_delta += ft
	avg_delta /= frame_times.size()
	var avg_fps := 1.0 / avg_delta if avg_delta > 0 else 0
	
	# Update FPS label with color coding
	var fps_color := Color.GREEN
	if avg_fps < 60:
		fps_color = Color.YELLOW
	if avg_fps < 30:
		fps_color = Color.RED
	
	fps_label.text = "FPS: %.1f (%.2f ms)" % [avg_fps, avg_delta * 1000.0]
	fps_label.add_theme_color_override("font_color", fps_color)
	
	# Update other performance metrics
	var memory_label := performance_panel.get_node_or_null("VBoxContainer/MemoryLabel")
	if memory_label:
		var mem_usage := Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
		memory_label.text = "Memory: %.1f MB" % mem_usage
	
	var physics_label := performance_panel.get_node_or_null("VBoxContainer/PhysicsLabel")
	if physics_label:
		var physics_time := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		physics_label.text = "Physics: %.2f ms" % physics_time
	
	var draw_label := performance_panel.get_node_or_null("VBoxContainer/DrawCallsLabel")
	if draw_label:
		var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		draw_label.text = "Draw Calls: %d" % draw_calls
	
	# Handle screenshot input
	if Input.is_action_just_pressed("screenshot"):
		capture_screenshot()
	
	# Toggle mouse capture with ESC
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _ensure_screenshot_directory() -> void:
	"""Create screenshot directory if it doesn't exist"""
	var dir := DirAccess.open("user://")
	if not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")
	print("Screenshot directory: ", ProjectSettings.globalize_path(screenshot_dir))

func capture_screenshot() -> String:
	"""Capture and save a screenshot, return the file path"""
	# Get viewport image
	var img := get_viewport().get_texture().get_image()
	
	# Generate filename with timestamp
	var time := Time.get_datetime_dict_from_system()
	var filename := "screenshot_%04d%02d%02d_%02d%02d%02d_%03d.png" % [
		time.year, time.month, time.day,
		time.hour, time.minute, time.second,
		screenshot_counter
	]
	screenshot_counter += 1
	
	# Save the image
	var path := screenshot_dir + "/" + filename
	var err := img.save_png(path)
	
	if err == OK:
		var global_path := ProjectSettings.globalize_path(path)
		print("Screenshot saved: ", global_path)
		_show_screenshot_notification(global_path)
		return global_path
	else:
		push_error("Failed to save screenshot: Error code %d" % err)
		return ""

func _show_screenshot_notification(path: String) -> void:
	"""Show a temporary notification that a screenshot was saved"""
	var notification := Label.new()
	notification.text = "Screenshot saved!"
	notification.position = Vector2(
		get_viewport().get_visible_rect().size.x / 2 - 100,
		get_viewport().get_visible_rect().size.y - 100
	)
	notification.add_theme_color_override("font_color", Color.GREEN)
	notification.add_theme_font_size_override("font_size", 20)
	
	var canvas := get_node("PerformanceUI")
	canvas.add_child(notification)
	
	# Remove after 2 seconds
	await get_tree().create_timer(2.0).timeout
	notification.queue_free()

func get_player() -> CharacterBody3D:
	"""Helper function to get player reference"""
	return get_node_or_null("Player")

func get_performance_metrics() -> Dictionary:
	"""Export performance metrics for testing"""
	var avg_delta := 0.0
	for ft in frame_times:
		avg_delta += ft
	if frame_times.size() > 0:
		avg_delta /= frame_times.size()
	
	return {
		"fps": 1.0 / avg_delta if avg_delta > 0 else 0,
		"frame_time_ms": avg_delta * 1000.0,
		"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0,
		"physics_time_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	}