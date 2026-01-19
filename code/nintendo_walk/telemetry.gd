extends Node
## Telemetry - Time Series Position Tracking for Any Character Type
##
## Standalone autoload that captures position, velocity, and rotation data
## for any Node3D-based character at configurable sample rates.
## Outputs JSONL format for streaming/incremental analysis.

# Configuration
var sample_rate: float = 60.0  # Hz - samples per second
var output_path: String = "res://telemetry.jsonl"
var enabled: bool = true

# Target tracking
var target_node: Node3D = null
var node_type: String = "unknown"

# Sampling state
var sample_interval: float = 1.0 / 60.0  # Computed from sample_rate
var time_accumulator: float = 0.0
var start_time: float = 0.0
var samples: Array = []
var is_recording: bool = false

# For Node3D fallback velocity computation
var last_position: Vector3 = Vector3.ZERO
var last_sample_time: float = 0.0

# Input tracking
var tracked_inputs: Array = [
	"move_forward", "move_backward", "move_left", "move_right",
	"jump", "sprint", "crouch", "interact", "attack", "use"
]

func _ready():
	sample_interval = 1.0 / sample_rate
	print("Telemetry: Initialized (sample_rate=%.1f Hz)" % sample_rate)

func _physics_process(delta: float):
	if not is_recording or not enabled:
		return

	time_accumulator += delta

	# Sample at configured rate
	while time_accumulator >= sample_interval:
		time_accumulator -= sample_interval
		sample_state()

func start_recording(custom_output_path: String = ""):
	"""Start recording telemetry data"""
	if custom_output_path != "":
		output_path = custom_output_path

	# Find and classify target if not already set
	if not target_node:
		find_and_classify_target()

	if not target_node:
		print("Telemetry: Warning - No target node found, recording disabled")
		return

	samples.clear()
	start_time = Time.get_ticks_msec() / 1000.0
	time_accumulator = 0.0
	is_recording = true

	# Initialize last position for velocity computation
	last_position = target_node.global_position
	last_sample_time = start_time

	print("Telemetry: Recording started (type=%s, output=%s)" % [node_type, output_path])

func stop_recording():
	"""Stop recording telemetry data"""
	is_recording = false
	print("Telemetry: Recording stopped (%d samples)" % samples.size())

func find_and_classify_target():
	"""Find the player node and determine its type"""
	# Try common player node paths first
	var search_paths = [
		"/root/Main/Player",
		"/root/Game/Player",
		"/root/World/Player",
		"/root/Player"
	]

	for path in search_paths:
		var node = get_node_or_null(path)
		if node and node is Node3D:
			target_node = node
			node_type = classify_node(node)
			print("Telemetry: Found target at %s (type=%s)" % [path, node_type])
			return

	# Fallback: search for supported physics body types
	var root = get_tree().root
	target_node = find_physics_body_recursive(root)

	if target_node:
		node_type = classify_node(target_node)
		print("Telemetry: Found target via search at %s (type=%s)" % [str(target_node.get_path()), node_type])
	else:
		print("Telemetry: No suitable target found")

func find_physics_body_recursive(node: Node) -> Node3D:
	"""Recursively search for physics body types (in priority order)"""
	# Check in order of specificity
	if node is CharacterBody3D:
		return node
	if node is VehicleBody3D:
		return node
	if node is RigidBody3D:
		return node

	for child in node.get_children():
		var result = find_physics_body_recursive(child)
		if result:
			return result

	return null

func classify_node(node: Node3D) -> String:
	"""Classify the node type for appropriate data extraction"""
	if node is CharacterBody3D:
		return "CharacterBody3D"
	elif node is VehicleBody3D:
		return "VehicleBody3D"
	elif node is RigidBody3D:
		return "RigidBody3D"
	elif node is Node3D:
		return "Node3D"
	return "unknown"

func sample_state():
	"""Sample the current state based on node type"""
	if not target_node or not is_instance_valid(target_node):
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	var t = current_time - start_time

	var sample: Dictionary

	match node_type:
		"CharacterBody3D":
			sample = sample_character_body(t)
		"RigidBody3D":
			sample = sample_rigid_body(t)
		"VehicleBody3D":
			sample = sample_vehicle_body(t)
		_:
			sample = sample_node3d(t)

	# Add input state to all samples
	sample["inputs"] = get_active_inputs()

	samples.append(sample)

func sample_character_body(t: float) -> Dictionary:
	"""Sample CharacterBody3D-specific properties"""
	var body: CharacterBody3D = target_node as CharacterBody3D
	var pos = body.global_position
	var vel = body.velocity
	var rot = body.rotation

	return {
		"t": snapped(t, 0.001),
		"type": "CharacterBody3D",
		"pos": [snapped(pos.x, 0.001), snapped(pos.y, 0.001), snapped(pos.z, 0.001)],
		"vel": [snapped(vel.x, 0.001), snapped(vel.y, 0.001), snapped(vel.z, 0.001)],
		"rot": [snapped(rot.x, 0.001), snapped(rot.y, 0.001), snapped(rot.z, 0.001)],
		"floor": body.is_on_floor()
	}

func sample_rigid_body(t: float) -> Dictionary:
	"""Sample RigidBody3D-specific properties"""
	var body: RigidBody3D = target_node as RigidBody3D
	var pos = body.global_position
	var vel = body.linear_velocity
	var ang_vel = body.angular_velocity
	var rot = body.rotation

	return {
		"t": snapped(t, 0.001),
		"type": "RigidBody3D",
		"pos": [snapped(pos.x, 0.001), snapped(pos.y, 0.001), snapped(pos.z, 0.001)],
		"vel": [snapped(vel.x, 0.001), snapped(vel.y, 0.001), snapped(vel.z, 0.001)],
		"rot": [snapped(rot.x, 0.001), snapped(rot.y, 0.001), snapped(rot.z, 0.001)],
		"ang_vel": [snapped(ang_vel.x, 0.001), snapped(ang_vel.y, 0.001), snapped(ang_vel.z, 0.001)]
	}

func sample_vehicle_body(t: float) -> Dictionary:
	"""Sample VehicleBody3D-specific properties"""
	var body: VehicleBody3D = target_node as VehicleBody3D
	var pos = body.global_position
	var vel = body.linear_velocity
	var ang_vel = body.angular_velocity
	var rot = body.rotation

	return {
		"t": snapped(t, 0.001),
		"type": "VehicleBody3D",
		"pos": [snapped(pos.x, 0.001), snapped(pos.y, 0.001), snapped(pos.z, 0.001)],
		"vel": [snapped(vel.x, 0.001), snapped(vel.y, 0.001), snapped(vel.z, 0.001)],
		"rot": [snapped(rot.x, 0.001), snapped(rot.y, 0.001), snapped(rot.z, 0.001)],
		"ang_vel": [snapped(ang_vel.x, 0.001), snapped(ang_vel.y, 0.001), snapped(ang_vel.z, 0.001)],
		"steering": snapped(body.steering, 0.001),
		"engine_force": snapped(body.engine_force, 0.001),
		"brake": snapped(body.brake, 0.001)
	}

func sample_node3d(t: float) -> Dictionary:
	"""Sample generic Node3D with computed velocity"""
	var pos = target_node.global_position
	var rot = target_node.rotation

	# Compute velocity from position delta
	var current_time = Time.get_ticks_msec() / 1000.0
	var dt = current_time - last_sample_time
	var vel = Vector3.ZERO

	if dt > 0:
		vel = (pos - last_position) / dt

	last_position = pos
	last_sample_time = current_time

	return {
		"t": snapped(t, 0.001),
		"type": "Node3D",
		"pos": [snapped(pos.x, 0.001), snapped(pos.y, 0.001), snapped(pos.z, 0.001)],
		"vel": [snapped(vel.x, 0.001), snapped(vel.y, 0.001), snapped(vel.z, 0.001)],
		"rot": [snapped(rot.x, 0.001), snapped(rot.y, 0.001), snapped(rot.z, 0.001)]
	}

func get_active_inputs() -> Array:
	"""Get list of currently pressed inputs"""
	var active: Array = []
	for input_name in tracked_inputs:
		if InputMap.has_action(input_name) and Input.is_action_pressed(input_name):
			active.append(input_name)
	return active

func save_telemetry():
	"""Save telemetry data to JSONL file"""
	if samples.size() == 0:
		print("Telemetry: No samples to save")
		return

	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if not file:
		print("Telemetry: Error - Could not open %s for writing" % output_path)
		return

	# Write each sample as a JSON line
	for sample in samples:
		file.store_line(JSON.stringify(sample))

	file.close()
	print("Telemetry: Saved %d samples to %s" % [samples.size(), output_path])

func get_samples() -> Array:
	"""Get the raw samples array for direct access"""
	return samples

func get_summary() -> Dictionary:
	"""Generate a summary of the telemetry data"""
	if samples.size() == 0:
		return {"status": "no_data"}

	var first = samples[0]
	var last = samples[samples.size() - 1]

	# Calculate total distance
	var total_distance: float = 0.0
	for i in range(1, samples.size()):
		var prev_pos = Vector3(samples[i-1]["pos"][0], samples[i-1]["pos"][1], samples[i-1]["pos"][2])
		var curr_pos = Vector3(samples[i]["pos"][0], samples[i]["pos"][1], samples[i]["pos"][2])
		total_distance += prev_pos.distance_to(curr_pos)

	# Calculate displacement
	var start_pos = Vector3(first["pos"][0], first["pos"][1], first["pos"][2])
	var end_pos = Vector3(last["pos"][0], last["pos"][1], last["pos"][2])
	var displacement = start_pos.distance_to(end_pos)

	# Velocity stats
	var max_speed: float = 0.0
	var total_speed: float = 0.0
	for sample in samples:
		var vel = Vector3(sample["vel"][0], sample["vel"][1], sample["vel"][2])
		var speed = vel.length()
		total_speed += speed
		if speed > max_speed:
			max_speed = speed
	var avg_speed = total_speed / samples.size()

	return {
		"status": "ok",
		"type": node_type,
		"sample_count": samples.size(),
		"duration": last["t"] - first["t"],
		"total_distance": total_distance,
		"displacement": displacement,
		"max_speed": max_speed,
		"avg_speed": avg_speed,
		"start_pos": first["pos"],
		"end_pos": last["pos"]
	}

func set_target(node: Node3D):
	"""Manually set the target node to track"""
	target_node = node
	node_type = classify_node(node)
	print("Telemetry: Target set to %s (type=%s)" % [str(node.get_path()), node_type])

func set_sample_rate(hz: float):
	"""Set the sample rate in Hz"""
	sample_rate = hz
	sample_interval = 1.0 / hz
	print("Telemetry: Sample rate set to %.1f Hz" % hz)

func set_output_path(path: String):
	"""Set the output file path"""
	output_path = path
	print("Telemetry: Output path set to %s" % path)
