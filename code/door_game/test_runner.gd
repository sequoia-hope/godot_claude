extends Node
## Dynamic Test Runner for Feature-Driven Development
##
## Loads test definitions from tests.json and executes them dynamically.
## Supports: movement tests, interaction tests, state tests, sequence tests.

# Test configuration - loaded from tests.json
var test_definitions: Array = []
var current_test_index: int = 0
var current_step_index: int = 0
var test_start_time: float = 0.0
var step_start_time: float = 0.0

# Output paths
var output_dir: String = "res://test_output/"
var results_file: String = ""

# Performance tracking
var frame_times: Array = []
var frame_count: int = 0

# Scene references (discovered dynamically)
var player_node: CharacterBody3D = null
var discovered_objects: Dictionary = {}  # group_name -> [nodes]

# Current test state
var current_test: Dictionary = {}
var test_state: Dictionary = {}  # Arbitrary state for multi-step tests

# Results
var test_results: Dictionary = {
	"status": "running",
	"timestamp": "",
	"tests": [],
	"summary": {},
	"errors": []
}

# Test status enum
enum TestStatus { PENDING, RUNNING, PASSED, FAILED, SKIPPED }

func _ready():
	print("DynamicTestRunner initialized")

	# Create output directory
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var output_subdir = output_dir + timestamp + "/"
	results_file = output_subdir + "results.json"
	DirAccess.make_dir_recursive_absolute(output_subdir)

	# Discover scene objects
	await get_tree().process_frame  # Wait for scene to be ready
	discover_scene_objects()

	# Load test definitions
	load_test_definitions()

	# Start tests
	if test_definitions.size() > 0:
		start_next_test()
	else:
		print("No tests defined - running default movement tests")
		load_default_movement_tests()
		start_next_test()

func discover_scene_objects():
	"""Discover all testable objects in the scene"""
	print("Discovering scene objects...")

	# Find player
	player_node = find_player()
	if player_node:
		print("  Found player: " + str(player_node.get_path()))

	# Discover objects by common test groups
	var groups_to_find = [
		"interactable", "pickup", "door", "enemy", "npc",
		"trigger", "checkpoint", "collectible", "obstacle"
	]

	for group_name in groups_to_find:
		var nodes = get_tree().get_nodes_in_group(group_name)
		if nodes.size() > 0:
			discovered_objects[group_name] = nodes
			print("  Found " + str(nodes.size()) + " objects in group '" + group_name + "'")

	# Also discover by script methods (has "interact", "open", "pickup", etc.)
	discover_by_methods()

func discover_by_methods():
	"""Find objects that have specific methods indicating testability"""
	var root = get_tree().root
	var method_groups = {
		"has_interact": [],
		"has_open": [],
		"has_pickup": [],
		"has_damage": [],
		"has_activate": []
	}

	find_objects_with_methods(root, method_groups)

	for group_name in method_groups:
		if method_groups[group_name].size() > 0:
			discovered_objects[group_name] = method_groups[group_name]
			print("  Found " + str(method_groups[group_name].size()) + " objects with " + group_name)

func find_objects_with_methods(node: Node, method_groups: Dictionary):
	"""Recursively find objects with specific methods"""
	if node.has_method("interact"):
		method_groups["has_interact"].append(node)
	if node.has_method("open"):
		method_groups["has_open"].append(node)
	if node.has_method("pickup"):
		method_groups["has_pickup"].append(node)
	if node.has_method("take_damage"):
		method_groups["has_damage"].append(node)
	if node.has_method("activate"):
		method_groups["has_activate"].append(node)

	for child in node.get_children():
		find_objects_with_methods(child, method_groups)

func find_player() -> CharacterBody3D:
	"""Find the player node"""
	var search_paths = [
		"/root/Main/Player",
		"/root/Game/Player",
		"/root/World/Player",
		"/root/Player"
	]

	for path in search_paths:
		var node = get_node_or_null(path)
		if node and node is CharacterBody3D:
			return node

	# Fallback: search for any CharacterBody3D
	return find_character_body_recursive(get_tree().root)

func find_character_body_recursive(node: Node) -> CharacterBody3D:
	if node is CharacterBody3D:
		return node
	for child in node.get_children():
		var result = find_character_body_recursive(child)
		if result:
			return result
	return null

func load_test_definitions():
	"""Load tests from tests.json in the project directory"""
	var tests_file = "res://tests.json"

	if not FileAccess.file_exists(tests_file):
		print("No tests.json found, will use defaults")
		return

	var file = FileAccess.open(tests_file, FileAccess.READ)
	if not file:
		print("Could not open tests.json")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("Error parsing tests.json: " + json.get_error_message())
		test_results["errors"].append("Failed to parse tests.json")
		return

	var data = json.get_data()
	if data.has("tests"):
		test_definitions = data["tests"]
		print("Loaded " + str(test_definitions.size()) + " test definitions")

	# Also load any feature-specific metadata
	if data.has("feature"):
		test_results["feature"] = data["feature"]

func load_default_movement_tests():
	"""Load default movement tests if no tests.json exists"""
	test_definitions = [
		{
			"name": "initial_position",
			"type": "movement",
			"description": "Capture starting position",
			"duration": 2.0,
			"steps": [{"action": "wait", "duration": 2.0}]
		},
		{
			"name": "move_forward",
			"type": "movement",
			"description": "Test forward movement",
			"duration": 3.0,
			"steps": [{"action": "input", "inputs": ["move_forward"], "duration": 3.0}],
			"validate": {"min_distance": 0.5}
		},
		{
			"name": "move_backward",
			"type": "movement",
			"description": "Test backward movement",
			"duration": 3.0,
			"steps": [{"action": "input", "inputs": ["move_backward"], "duration": 3.0}],
			"validate": {"min_distance": 0.5}
		},
		{
			"name": "move_left",
			"type": "movement",
			"description": "Test left strafe",
			"duration": 2.0,
			"steps": [{"action": "input", "inputs": ["move_left"], "duration": 2.0}],
			"validate": {"min_distance": 0.5}
		},
		{
			"name": "move_right",
			"type": "movement",
			"description": "Test right strafe",
			"duration": 2.0,
			"steps": [{"action": "input", "inputs": ["move_right"], "duration": 2.0}],
			"validate": {"min_distance": 0.5}
		},
		{
			"name": "jump",
			"type": "movement",
			"description": "Test jump",
			"duration": 2.0,
			"steps": [{"action": "input", "inputs": ["jump"], "duration": 2.0}],
			"validate": {"left_floor": true}
		}
	]

func start_next_test():
	"""Start the next test in the queue"""
	if current_test_index >= test_definitions.size():
		finalize_tests()
		return

	current_test = test_definitions[current_test_index]
	current_step_index = 0
	test_start_time = Time.get_ticks_msec() / 1000.0
	step_start_time = test_start_time

	# Initialize test state
	test_state = {
		"start_position": get_player_position(),
		"start_time": test_start_time,
		"positions": [],
		"events": [],
		"step_results": [],
		"interacted_this_step": false
	}

	print("\nStarting test: " + current_test["name"])
	release_all_inputs()

func _process(delta):
	if current_test_index >= test_definitions.size():
		return

	frame_times.append(delta)
	frame_count += 1

	# Track position
	if player_node:
		test_state["positions"].append({
			"time": Time.get_ticks_msec() / 1000.0 - test_start_time,
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
		})

	# Execute current step
	var steps = current_test.get("steps", [])
	if current_step_index < steps.size():
		var step = steps[current_step_index]
		var step_elapsed = (Time.get_ticks_msec() / 1000.0) - step_start_time
		var step_duration = step.get("duration", 1.0)

		execute_step(step)

		if step_elapsed >= step_duration:
			# Step complete
			complete_step(step)
			current_step_index += 1
			step_start_time = Time.get_ticks_msec() / 1000.0
	else:
		# All steps complete
		complete_test()

func execute_step(step: Dictionary):
	"""Execute a test step"""
	var action = step.get("action", "wait")

	match action:
		"wait":
			release_all_inputs()

		"input":
			apply_inputs(step.get("inputs", []))

		"move_to":
			# Support both direct target position and target_group
			if step.has("target"):
				move_player_toward(step["target"])
			elif step.has("target_group"):
				var target_pos = get_target_position_from_group(step["target_group"])
				if target_pos != Vector3.ZERO:
					move_player_toward(target_pos)
			else:
				release_all_inputs()

		"interact":
			# Only interact once per step
			if not test_state.get("interacted_this_step", false):
				try_interact_with(step.get("target_group", "interactable"))
				test_state["interacted_this_step"] = true

		"wait_for":
			# Wait for a condition (checked in complete_step)
			pass

		"call_method":
			call_method_on_target(step)

func apply_inputs(inputs: Array):
	"""Apply input actions"""
	release_all_inputs()
	for input_name in inputs:
		if InputMap.has_action(input_name):
			Input.action_press(input_name)

func release_all_inputs():
	"""Release all possible inputs"""
	var actions = ["move_forward", "move_backward", "move_left", "move_right",
				   "jump", "interact", "attack", "use", "crouch", "sprint"]
	for action in actions:
		if InputMap.has_action(action):
			Input.action_release(action)

func get_target_position_from_group(group_name: String) -> Vector3:
	"""Get position of first object in a group"""
	if discovered_objects.has(group_name):
		var objects = discovered_objects[group_name]
		if objects.size() > 0 and is_instance_valid(objects[0]):
			return objects[0].global_position

	# Fallback: search live (in case object was just added)
	var nodes = get_tree().get_nodes_in_group(group_name)
	if nodes.size() > 0:
		return nodes[0].global_position

	return Vector3.ZERO

func move_player_toward(target: Vector3):
	"""Move player toward a target position"""
	if not player_node:
		return

	var direction = (target - player_node.global_position).normalized()
	direction.y = 0  # Keep on ground plane

	# Check if already close enough
	var horizontal_dist = Vector2(player_node.global_position.x - target.x, player_node.global_position.z - target.z).length()
	if horizontal_dist < 2.0:
		release_all_inputs()
		return

	# Simulate directional input based on player's facing
	var forward = -player_node.global_transform.basis.z
	var right = player_node.global_transform.basis.x

	var forward_dot = direction.dot(forward)
	var right_dot = direction.dot(right)

	release_all_inputs()

	# Use threshold of 0.3 instead of 0.5 for more responsive movement
	if forward_dot > 0.3:
		Input.action_press("move_forward")
	elif forward_dot < -0.3:
		Input.action_press("move_backward")

	if right_dot > 0.3:
		Input.action_press("move_right")
	elif right_dot < -0.3:
		Input.action_press("move_left")

func try_interact_with(target_group: String):
	"""Try to interact with nearest object in group"""
	if not player_node:
		return

	if not discovered_objects.has(target_group) and not discovered_objects.has("has_interact"):
		return

	var objects = discovered_objects.get(target_group, [])
	if objects.size() == 0:
		objects = discovered_objects.get("has_interact", [])

	# Filter out invalid (freed) objects
	var valid_objects = []
	for obj in objects:
		if is_instance_valid(obj):
			valid_objects.append(obj)

	# Find nearest valid object
	var nearest = null
	var nearest_dist = INF

	for obj in valid_objects:
		if obj.has_method("interact") or obj.has_method("_on_interact"):
			var dist = player_node.global_position.distance_to(obj.global_position)
			if dist < nearest_dist:
				nearest = obj
				nearest_dist = dist

	if nearest and nearest_dist < 5.0:  # Within interaction range (increased from 3.0)
		if nearest.has_method("interact"):
			# Pass player to interact if the method expects it
			var method_info = nearest.get_method_list()
			var takes_arg = false
			for m in method_info:
				if m["name"] == "interact" and m["args"].size() > 0:
					takes_arg = true
					break

			if takes_arg:
				nearest.interact(player_node)
			else:
				nearest.interact()
			test_state["events"].append({"type": "interact", "target": nearest.name, "time": Time.get_ticks_msec() / 1000.0})

func call_method_on_target(step: Dictionary):
	"""Call a specific method on a target object"""
	var target_path = step.get("target_path", "")
	var method_name = step.get("method", "")
	var args = step.get("args", [])

	var target = get_node_or_null(target_path)
	if target and target.has_method(method_name):
		target.callv(method_name, args)
		test_state["events"].append({"type": "call", "target": target_path, "method": method_name})

func complete_step(step: Dictionary):
	"""Complete a step and record results"""
	# Reset per-step flags
	test_state["interacted_this_step"] = false

	var step_result = {
		"action": step.get("action", "unknown"),
		"completed": true
	}

	# Check step-specific validations
	if step.has("validate"):
		step_result["validation"] = validate_step(step["validate"])

	test_state["step_results"].append(step_result)

func complete_test():
	"""Complete current test and validate results"""
	release_all_inputs()

	var end_position = get_player_position()
	var positions = test_state["positions"]

	# Calculate metrics
	var total_distance = calculate_total_distance(positions)
	var displacement = test_state["start_position"].distance_to(end_position)
	var left_floor = check_left_floor(positions)

	# Validate against test requirements
	var validation = current_test.get("validate", {})
	var passed = true
	var issues = []

	if validation.has("min_distance"):
		if total_distance < validation["min_distance"]:
			passed = false
			issues.append("Distance " + str(total_distance) + " < required " + str(validation["min_distance"]))

	if validation.has("left_floor"):
		if validation["left_floor"] and not left_floor:
			passed = false
			issues.append("Player did not leave floor")

	if validation.has("reached_target"):
		var target = validation["reached_target"]
		if end_position.distance_to(target) > validation.get("tolerance", 1.0):
			passed = false
			issues.append("Did not reach target position")

	if validation.has("near_group"):
		var group_name = validation["near_group"]
		var max_dist = validation.get("max_distance", 3.0) + 0.5  # Add tolerance
		var target_pos = get_target_position_from_group(group_name)
		if target_pos != Vector3.ZERO:
			var dist = end_position.distance_to(target_pos)
			if dist > max_dist:
				passed = false
				issues.append("Not near " + group_name + " (distance: " + str(snapped(dist, 0.1)) + ", required: " + str(max_dist) + ")")

	if validation.has("object_in_group"):
		var group_name = validation["object_in_group"]
		var nodes = get_tree().get_nodes_in_group(group_name)
		if nodes.size() == 0:
			passed = false
			issues.append("No objects found in group: " + group_name)

	if validation.has("state_check"):
		var state_result = check_game_state(validation["state_check"])
		if not state_result["passed"]:
			passed = false
			issues.append(state_result["reason"])

	# Record result
	var result = {
		"name": current_test["name"],
		"type": current_test.get("type", "unknown"),
		"description": current_test.get("description", ""),
		"status": "passed" if passed else "failed",
		"issues": issues,
		"metrics": {
			"total_distance": total_distance,
			"displacement": displacement,
			"left_floor": left_floor,
			"duration": Time.get_ticks_msec() / 1000.0 - test_start_time,
			"start_position": vector_to_dict(test_state["start_position"]),
			"end_position": vector_to_dict(end_position)
		},
		"events": test_state["events"]
	}

	test_results["tests"].append(result)
	print("Test " + current_test["name"] + ": " + result["status"])
	if issues.size() > 0:
		for issue in issues:
			print("  - " + issue)

	# Move to next test
	current_test_index += 1
	if current_test_index < test_definitions.size():
		start_next_test()
	else:
		finalize_tests()

func get_player_position() -> Vector3:
	if player_node:
		return player_node.global_position
	return Vector3.ZERO

func calculate_total_distance(positions: Array) -> float:
	var total = 0.0
	for i in range(1, positions.size()):
		var prev = Vector3(positions[i-1]["position"]["x"], positions[i-1]["position"]["y"], positions[i-1]["position"]["z"])
		var curr = Vector3(positions[i]["position"]["x"], positions[i]["position"]["y"], positions[i]["position"]["z"])
		total += prev.distance_to(curr)
	return total

func check_left_floor(positions: Array) -> bool:
	for pos in positions:
		if not pos.get("on_floor", true):
			return true
	return false

func check_game_state(checks: Dictionary) -> Dictionary:
	"""Check arbitrary game state conditions"""
	# Check for object existence
	if checks.has("object_exists"):
		var path = checks["object_exists"]
		if not get_node_or_null(path):
			return {"passed": false, "reason": "Object not found: " + path}

	# Check object property
	if checks.has("property_equals"):
		var check = checks["property_equals"]
		var obj = get_node_or_null(check["path"])
		if obj and check["property"] in obj:
			if obj.get(check["property"]) != check["value"]:
				return {"passed": false, "reason": "Property mismatch: " + check["property"]}
		else:
			return {"passed": false, "reason": "Property not found: " + check["property"]}

	# Check if object is in group
	if checks.has("in_group"):
		var check = checks["in_group"]
		var obj = get_node_or_null(check["path"])
		if not obj or not obj.is_in_group(check["group"]):
			return {"passed": false, "reason": "Object not in group: " + check["group"]}

	# Check player inventory (if exists)
	if checks.has("has_item"):
		if player_node and player_node.has_method("has_item"):
			if not player_node.has_item(checks["has_item"]):
				return {"passed": false, "reason": "Missing item: " + checks["has_item"]}

	return {"passed": true, "reason": ""}

func validate_step(validation: Dictionary) -> Dictionary:
	"""Validate step-specific conditions"""
	var result = {"passed": true, "checks": []}

	for key in validation:
		var check_result = {"check": key, "passed": true}

		match key:
			"near_target":
				var target_pos = validation[key]
				var dist = get_player_position().distance_to(target_pos)
				check_result["passed"] = dist < 2.0
				check_result["distance"] = dist

		result["checks"].append(check_result)
		if not check_result["passed"]:
			result["passed"] = false

	return result

func vector_to_dict(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}

func finalize_tests():
	"""Finalize and save test results"""
	test_results["status"] = "completed"
	test_results["timestamp"] = Time.get_datetime_string_from_system()

	# Calculate summary
	var passed = 0
	var failed = 0
	var all_issues = []

	for test in test_results["tests"]:
		if test["status"] == "passed":
			passed += 1
		else:
			failed += 1
			all_issues.append_array(test["issues"])

	test_results["summary"] = {
		"total": test_results["tests"].size(),
		"passed": passed,
		"failed": failed,
		"issues": all_issues,
		"overall_status": "passed" if failed == 0 else "failed"
	}

	# Performance metrics
	var total_time = 0.0
	for ft in frame_times:
		total_time += ft
	var avg_fps = frame_count / total_time if total_time > 0 else 0

	test_results["performance"] = {
		"avg_fps": avg_fps,
		"frame_count": frame_count,
		"total_duration": total_time
	}

	# Save results
	save_results()

	print("\n" + "=".repeat(60))
	print("TESTS COMPLETED")
	print("=".repeat(60))
	print("Passed: " + str(passed) + "/" + str(test_results["tests"].size()))
	if failed > 0:
		print("Issues:")
		for issue in all_issues:
			print("  - " + issue)
	print("Results saved to: " + results_file)
	print("=".repeat(60))

	await get_tree().create_timer(1.0).timeout
	get_tree().quit()

func save_results():
	"""Save results to JSON"""
	var file = FileAccess.open(results_file, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(test_results, "\t"))
		file.close()
