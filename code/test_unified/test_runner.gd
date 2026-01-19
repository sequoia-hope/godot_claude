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

# Output paths - use res:// for Docker compatibility
var output_dir: String = "res://test_output/"
var screenshot_dir: String = ""
var results_file: String = ""

# Performance tracking
var frame_times: Array = []
var frame_count: int = 0
var test_duration: float = 5.0  # seconds per test

# Movement tracking
var player_node: CharacterBody3D = null
var position_samples: Array = []  # Array of {time, position, velocity, on_floor}
var current_test_samples: Array = []  # Samples for current test only
var movement_metrics: Dictionary = {}  # Per-test movement analysis

# Results
var test_results: Dictionary = {
	"status": "running",
	"timestamp": "",
	"screenshots": [],
	"performance": {},
	"movement_metrics": {},
	"errors": []
}

func _ready():
	print("TestRunner initialized")

	# Create output directory
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	screenshot_dir = output_dir + timestamp + "/"
	results_file = screenshot_dir + "results.json"

	DirAccess.make_dir_recursive_absolute(screenshot_dir)

	# Find player node for movement tracking
	find_player_node()

	# Define test sequence
	setup_test_sequence()

	# Start tests
	test_start_time = Time.get_ticks_msec() / 1000.0
	print("Starting test sequence...")

func find_player_node():
	"""Find the player CharacterBody3D in the scene tree"""
	# Try common player node paths
	var search_paths = [
		"/root/Main/Player",
		"/root/Game/Player",
		"/root/World/Player",
		"/root/Player"
	]

	for path in search_paths:
		var node = get_node_or_null(path)
		if node and node is CharacterBody3D:
			player_node = node
			print("Found player at: " + path)
			return

	# Fallback: search for any CharacterBody3D
	var root = get_tree().root
	player_node = find_character_body_recursive(root)

	if player_node:
		print("Found player via search: " + str(player_node.get_path()))
	else:
		print("Warning: No player CharacterBody3D found - movement tracking disabled")

func find_character_body_recursive(node: Node) -> CharacterBody3D:
	"""Recursively search for CharacterBody3D"""
	if node is CharacterBody3D:
		return node
	for child in node.get_children():
		var result = find_character_body_recursive(child)
		if result:
			return result
	return null

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

	# Track player position and velocity
	sample_player_state(elapsed)

	# Apply test inputs
	apply_test_inputs(current_test["inputs"])

	# Capture screenshot at test start and end
	if elapsed < 0.1:
		capture_screenshot(current_test["name"] + "_start")
	elif elapsed >= current_test["duration"] - 0.1 and elapsed < current_test["duration"]:
		capture_screenshot(current_test["name"] + "_end")

	# Move to next test when duration expires
	if elapsed >= current_test["duration"]:
		# Analyze movement for this test before moving on
		analyze_test_movement(current_test["name"])
		print("Completed test: " + current_test["name"])
		current_test_index += 1
		test_start_time = Time.get_ticks_msec() / 1000.0

func sample_player_state(elapsed_time: float):
	"""Sample player position and velocity for movement analysis"""
	if not player_node:
		return

	var sample = {
		"time": elapsed_time,
		"position": {
			"x": player_node.global_position.x,
			"y": player_node.global_position.y,
			"z": player_node.global_position.z
		},
		"velocity": {
			"x": player_node.velocity.x,
			"y": player_node.velocity.y,
			"z": player_node.velocity.z
		},
		"on_floor": player_node.is_on_floor() if player_node.has_method("is_on_floor") else false
	}

	current_test_samples.append(sample)
	position_samples.append(sample)

func analyze_test_movement(test_name: String):
	"""Analyze movement samples for the current test and store metrics"""
	if current_test_samples.size() < 2:
		movement_metrics[test_name] = {
			"status": "no_data",
			"reason": "Insufficient samples"
		}
		current_test_samples.clear()
		return

	var first_sample = current_test_samples[0]
	var last_sample = current_test_samples[current_test_samples.size() - 1]

	# Calculate position vectors
	var start_pos = Vector3(
		first_sample["position"]["x"],
		first_sample["position"]["y"],
		first_sample["position"]["z"]
	)
	var end_pos = Vector3(
		last_sample["position"]["x"],
		last_sample["position"]["y"],
		last_sample["position"]["z"]
	)

	# Calculate total distance traveled (cumulative)
	var total_distance: float = 0.0
	var prev_pos = start_pos
	for i in range(1, current_test_samples.size()):
		var sample = current_test_samples[i]
		var curr_pos = Vector3(sample["position"]["x"], sample["position"]["y"], sample["position"]["z"])
		total_distance += prev_pos.distance_to(curr_pos)
		prev_pos = curr_pos

	# Calculate velocities
	var max_velocity: float = 0.0
	var total_velocity: float = 0.0
	var velocity_samples: int = 0
	var left_floor: bool = false
	var floor_samples: int = 0

	for sample in current_test_samples:
		var vel = Vector3(sample["velocity"]["x"], sample["velocity"]["y"], sample["velocity"]["z"])
		var speed = vel.length()
		total_velocity += speed
		velocity_samples += 1
		if speed > max_velocity:
			max_velocity = speed

		if sample["on_floor"]:
			floor_samples += 1

	var avg_velocity = total_velocity / velocity_samples if velocity_samples > 0 else 0.0

	# Determine if player left the floor during this test
	var first_on_floor = first_sample.get("on_floor", true)
	for sample in current_test_samples:
		if first_on_floor and not sample.get("on_floor", true):
			left_floor = true
			break

	# Calculate displacement (direct distance from start to end)
	var displacement = start_pos.distance_to(end_pos)
	var horizontal_displacement = Vector2(end_pos.x - start_pos.x, end_pos.z - start_pos.z).length()
	var vertical_displacement = end_pos.y - start_pos.y

	# Determine movement success based on test type
	var movement_success = evaluate_movement_success(test_name, {
		"total_distance": total_distance,
		"displacement": displacement,
		"horizontal_displacement": horizontal_displacement,
		"vertical_displacement": vertical_displacement,
		"left_floor": left_floor,
		"max_velocity": max_velocity,
		"avg_velocity": avg_velocity
	})

	movement_metrics[test_name] = {
		"status": "success" if movement_success["passed"] else "failed",
		"start_position": first_sample["position"],
		"end_position": last_sample["position"],
		"total_distance": total_distance,
		"displacement": displacement,
		"horizontal_displacement": horizontal_displacement,
		"vertical_displacement": vertical_displacement,
		"max_velocity": max_velocity,
		"avg_velocity": avg_velocity,
		"left_floor": left_floor,
		"floor_time_ratio": float(floor_samples) / float(current_test_samples.size()),
		"sample_count": current_test_samples.size(),
		"success_reason": movement_success["reason"],
		"issues": movement_success.get("issues", [])
	}

	print("Movement analysis for " + test_name + ": " + movement_metrics[test_name]["status"])
	if movement_metrics[test_name]["issues"].size() > 0:
		for issue in movement_metrics[test_name]["issues"]:
			print("  Issue: " + issue)

	# Clear samples for next test
	current_test_samples.clear()

func evaluate_movement_success(test_name: String, metrics: Dictionary) -> Dictionary:
	"""Evaluate if movement succeeded based on test type"""
	var passed = false
	var reason = ""
	var issues: Array = []

	# Thresholds for movement detection
	var MIN_DISTANCE = 0.1  # Minimum distance to consider "movement occurred"
	var MIN_JUMP_HEIGHT = 0.2  # Minimum vertical displacement for jump

	match test_name:
		"initial_position":
			# No movement expected
			passed = true
			reason = "Initial position captured"

		"move_forward", "move_backward", "move_left", "move_right":
			if metrics["total_distance"] > MIN_DISTANCE:
				passed = true
				reason = "Player moved %.2f units" % metrics["total_distance"]
			else:
				passed = false
				reason = "No significant movement detected"
				issues.append("Player did not move during " + test_name + " test (distance: %.3f)" % metrics["total_distance"])
				if metrics["max_velocity"] < 0.01:
					issues.append("Velocity stayed near zero - check movement input handling")

		"jump":
			if metrics["left_floor"]:
				passed = true
				reason = "Player left floor (vertical: %.2f)" % metrics["vertical_displacement"]
			elif metrics["vertical_displacement"] > MIN_JUMP_HEIGHT:
				passed = true
				reason = "Vertical displacement detected: %.2f" % metrics["vertical_displacement"]
			else:
				passed = false
				reason = "Jump not detected"
				issues.append("Player did not leave floor during jump test")
				if metrics["max_velocity"] < 0.1:
					issues.append("No upward velocity - check jump implementation")

		"turn_left", "turn_right":
			# Camera turns don't necessarily move player position
			passed = true
			reason = "Camera rotation test (position change not required)"

		_:
			# Generic movement check
			if metrics["total_distance"] > MIN_DISTANCE:
				passed = true
				reason = "Movement detected: %.2f units" % metrics["total_distance"]
			else:
				passed = false
				reason = "No movement detected"
				issues.append("No movement during " + test_name)

	return {"passed": passed, "reason": reason, "issues": issues}

func release_all_inputs():
	"""Release all test inputs"""
	Input.action_release("move_forward")
	Input.action_release("move_backward")
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("jump")

func apply_test_inputs(inputs: Array):
	"""Simulate player inputs for testing"""
	# First release all inputs to prevent conflicts
	release_all_inputs()

	# Then press the requested inputs
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

	# Include movement metrics in results
	test_results["movement_metrics"] = movement_metrics

	# Calculate overall movement summary
	var movement_summary = calculate_movement_summary()
	test_results["movement_summary"] = movement_summary

	# Save results to JSON
	save_results()

	print("\n" + "=".repeat(80))
	print("TESTS COMPLETED")
	print("=".repeat(80))
	print("Screenshots: " + str(test_results["screenshots"].size()))
	print("Average FPS: " + str(avg_fps))
	print("Movement Status: " + movement_summary["overall_status"])
	print("Movement Issues: " + str(movement_summary["total_issues"]))
	print("Results saved to: " + results_file)
	print("=".repeat(80) + "\n")

	# Exit after tests complete
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func calculate_movement_summary() -> Dictionary:
	"""Calculate overall movement health summary"""
	var passed_tests: int = 0
	var failed_tests: int = 0
	var all_issues: Array = []
	var no_player_found = player_node == null

	for test_name in movement_metrics:
		var metrics = movement_metrics[test_name]
		if metrics.get("status") == "success":
			passed_tests += 1
		elif metrics.get("status") == "failed":
			failed_tests += 1
			all_issues.append_array(metrics.get("issues", []))

	var overall_status = "healthy"
	if no_player_found:
		overall_status = "no_player"
		all_issues.append("No CharacterBody3D player node found in scene")
	elif failed_tests > 0:
		overall_status = "issues_detected"
	elif passed_tests == 0 and movement_metrics.size() > 0:
		overall_status = "no_data"

	return {
		"overall_status": overall_status,
		"passed_tests": passed_tests,
		"failed_tests": failed_tests,
		"total_issues": all_issues.size(),
		"issues": all_issues,
		"player_found": not no_player_found
	}

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
