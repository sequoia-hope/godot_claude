extends Node
## Automated test runner for game validation
##
## This script runs programmatic tests on the game, simulating player input,
## capturing screenshots, and collecting performance metrics.
## Note: Do not use class_name here as this script is loaded as an autoload singleton

# Test configuration
var test_sequence: Array = []
var current_test_index: int = 0
var test_start_time: float = 0.0
var screenshot_index: int = 0

# Output paths
var output_dir: String = "user://test_results/"
var screenshot_dir: String = ""
var results_file: String = ""

# Performance tracking
var frame_times: Array = []
var frame_count: int = 0
var test_duration: float = 5.0  # seconds per test

# Results
var test_results: Dictionary = {
	"status": "running",
	"timestamp": "",
	"screenshots": [],
	"performance": {},
	"errors": []
}

func _ready():
	print("TestRunner initialized")

	# Create output directory
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	screenshot_dir = output_dir + timestamp + "/"
	results_file = screenshot_dir + "results.json"

	DirAccess.make_dir_recursive_absolute(screenshot_dir)

	# Define test sequence
	setup_test_sequence()

	# Start tests
	test_start_time = Time.get_ticks_msec() / 1000.0
	print("Starting test sequence...")

func setup_test_sequence():
	"""Define the sequence of tests to run"""
	test_sequence = [
		{
			"name": "initial_position",
			"description": "Capture starting position",
			"duration": 2.0,
			"inputs": []
		},
		{
			"name": "move_forward",
			"description": "Move player forward",
			"duration": 3.0,
			"inputs": ["move_forward"]
		},
		{
			"name": "move_backward",
			"description": "Move player backward",
			"duration": 3.0,
			"inputs": ["move_backward"]
		},
		{
			"name": "move_left",
			"description": "Strafe left",
			"duration": 2.0,
			"inputs": ["move_left"]
		},
		{
			"name": "move_right",
			"description": "Strafe right",
			"duration": 2.0,
			"inputs": ["move_right"]
		},
		{
			"name": "jump",
			"description": "Test jump mechanics",
			"duration": 2.0,
			"inputs": ["jump"]
		},
		{
			"name": "turn_left",
			"description": "Turn camera left",
			"duration": 2.0,
			"inputs": ["turn_left"]
		},
		{
			"name": "turn_right",
			"description": "Turn camera right",
			"duration": 2.0,
			"inputs": ["turn_right"]
		}
	]

func _process(delta):
	if current_test_index >= test_sequence.size():
		# All tests complete
		if test_results["status"] == "running":
			finalize_tests()
		return

	var current_test = test_sequence[current_test_index]
	var elapsed = (Time.get_ticks_msec() / 1000.0) - test_start_time

	# Track performance
	frame_times.append(delta)
	frame_count += 1

	# Apply test inputs
	apply_test_inputs(current_test["inputs"])

	# Capture screenshot at test start and end
	if elapsed < 0.1:
		capture_screenshot(current_test["name"] + "_start")
	elif elapsed >= current_test["duration"] - 0.1 and elapsed < current_test["duration"]:
		capture_screenshot(current_test["name"] + "_end")

	# Move to next test when duration expires
	if elapsed >= current_test["duration"]:
		print("Completed test: " + current_test["name"])
		current_test_index += 1
		test_start_time = Time.get_ticks_msec() / 1000.0

func apply_test_inputs(inputs: Array):
	"""Simulate player inputs for testing"""
	for input_name in inputs:
		match input_name:
			"move_forward":
				Input.action_press("move_forward")
			"move_backward":
				Input.action_press("move_backward")
			"move_left":
				Input.action_press("move_left")
			"move_right":
				Input.action_press("move_right")
			"jump":
				Input.action_press("jump")
			"turn_left":
				simulate_mouse_movement(Vector2(-10, 0))
			"turn_right":
				simulate_mouse_movement(Vector2(10, 0))

func simulate_mouse_movement(delta_movement: Vector2):
	"""Simulate mouse movement for camera control"""
	var event = InputEventMouseMotion.new()
	event.relative = delta_movement
	Input.parse_input_event(event)

func capture_screenshot(test_name: String):
	"""Capture screenshot of current frame"""
	await RenderingServer.frame_post_draw

	var viewport = get_viewport()
	var img = viewport.get_texture().get_image()

	var screenshot_path = screenshot_dir + "%03d_%s.png" % [screenshot_index, test_name]
	var err = img.save_png(screenshot_path)

	if err == OK:
		print("Screenshot saved: " + screenshot_path)
		test_results["screenshots"].append(screenshot_path)
		screenshot_index += 1
	else:
		print("Error saving screenshot: " + str(err))
		test_results["errors"].append("Failed to save screenshot: " + test_name)

func finalize_tests():
	"""Complete testing and save results"""
	test_results["status"] = "completed"
	test_results["timestamp"] = Time.get_datetime_string_from_system()

	# Calculate performance metrics
	var total_time = 0.0
	for ft in frame_times:
		total_time += ft

	var avg_frame_time = total_time / frame_times.size() if frame_times.size() > 0 else 0.0
	var avg_fps = 1.0 / avg_frame_time if avg_frame_time > 0 else 0.0

	# Find min/max FPS
	var min_frame_time = frame_times.min() if frame_times.size() > 0 else 0.0
	var max_frame_time = frame_times.max() if frame_times.size() > 0 else 0.0
	var max_fps = 1.0 / min_frame_time if min_frame_time > 0 else 0.0
	var min_fps = 1.0 / max_frame_time if max_frame_time > 0 else 0.0

	test_results["performance"] = {
		"avg_fps": avg_fps,
		"min_fps": min_fps,
		"max_fps": max_fps,
		"frame_count": frame_count,
		"total_duration": total_time,
		"avg_memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0
	}

	# Save results to JSON
	save_results()

	print("\n" + "=".repeat(80))
	print("TESTS COMPLETED")
	print("=".repeat(80))
	print("Screenshots: " + str(test_results["screenshots"].size()))
	print("Average FPS: " + str(avg_fps))
	print("Results saved to: " + results_file)
	print("=".repeat(80) + "\n")

	# Exit after tests complete
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func save_results():
	"""Save test results to JSON file"""
	var file = FileAccess.open(results_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(test_results, "\t"))
		file.close()
		print("Results saved to: " + results_file)
	else:
		print("Error: Could not save results file")

func _exit_tree():
	"""Cleanup on exit"""
	# Release all test inputs
	Input.action_release("move_forward")
	Input.action_release("move_backward")
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")
