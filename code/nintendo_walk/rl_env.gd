extends Node
## RL Environment wrapper - implements reset/step/observe semantics
##
## This is the main autoload that coordinates RL training.
## It uses RLServer for communication and a TrackProgress implementation
## for reward computation.

# Configuration
var config: Dictionary = {}
var config_path: String = "res://rl_config.json"

# Components
var server: RLServer = null
var progress_provider: TrackProgress = null
var player: CharacterBody3D = null
var terrain: Node3D = null
var observation_viewport: SubViewport = null
var observation_camera: Camera3D = null

# Episode state
var step_count: int = 0
var episode_count: int = 0
var last_progress: float = 0.0
var episode_reward: float = 0.0
var is_episode_active: bool = false

# Action buffer (applied in physics process)
var pending_action: Array = [0.0, 0.0]  # [steer, throttle]
var action_ready: bool = false
var step_response_pending: bool = false

# Observation settings
var obs_width: int = 96
var obs_height: int = 96

func _ready():
	print("RLEnv: Initializing...")

	# Load configuration
	_load_config()

	# Create and start server
	server = RLServer.new()
	add_child(server)
	server.message_received.connect(_on_message_received)
	server.start(config.get("server", {}).get("port", 11008))

	# Setup will be deferred to allow scene to fully load
	call_deferred("_deferred_setup")

func _deferred_setup():
	# Find game components
	_find_components()

	# Create observation viewport
	_setup_observation_viewport()

	# Create progress provider
	_setup_progress_provider()

	print("RLEnv: Ready for connections")

func _load_config():
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file:
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		if err == OK:
			config = json.data
			print("RLEnv: Loaded config from ", config_path)
		file.close()
	else:
		print("RLEnv: Using default config (no ", config_path, " found)")
		config = _default_config()

	# Apply config
	obs_width = config.get("observation", {}).get("width", 96)
	obs_height = config.get("observation", {}).get("height", 96)

func _default_config() -> Dictionary:
	return {
		"server": {"port": 11008},
		"observation": {"width": 96, "height": 96, "grayscale": false},
		"action": {"dimensions": 2},
		"reward": {
			"progress_scale": 5.0,
			"on_track_bonus": 0.05,
			"off_track_penalty": -0.5,
			"success_bonus": 50.0,
			"time_penalty": -0.01
		},
		"episode": {
			"max_steps": 2000,
			"off_track_terminates": true,
			"off_track_tolerance": 3.0
		}
	}

func _find_components():
	# Find player
	var player_paths = ["/root/Main/Player", "/root/Game/Player", "/root/Player"]
	for path in player_paths:
		var node = get_node_or_null(path)
		if node is CharacterBody3D:
			player = node
			print("RLEnv: Found player at ", path)
			break

	if not player:
		player = _find_player_recursive(get_tree().root)
		if player:
			print("RLEnv: Found player via search at ", player.get_path())

	# Find terrain
	var terrain_paths = ["/root/Main/Terrain", "/root/Main/terrain", "/root/Terrain"]
	for path in terrain_paths:
		var node = get_node_or_null(path)
		if node and node.get("path_points") != null:
			terrain = node
			print("RLEnv: Found terrain at ", path)
			break

	if not terrain:
		terrain = _find_terrain_recursive(get_tree().root)
		if terrain:
			print("RLEnv: Found terrain via search at ", terrain.get_path())

func _find_player_recursive(node: Node) -> CharacterBody3D:
	if node is CharacterBody3D:
		return node
	for child in node.get_children():
		var result = _find_player_recursive(child)
		if result:
			return result
	return null

func _find_terrain_recursive(node: Node) -> Node3D:
	if node is Node3D and node.get("path_points") != null:
		return node
	for child in node.get_children():
		var result = _find_terrain_recursive(child)
		if result:
			return result
	return null

func _setup_observation_viewport():
	# Create a SubViewport for capturing observations
	observation_viewport = SubViewport.new()
	observation_viewport.size = Vector2i(obs_width, obs_height)
	observation_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	observation_viewport.transparent_bg = false
	add_child(observation_viewport)

	# Create camera for the viewport
	observation_camera = Camera3D.new()
	observation_camera.fov = 90  # Wide FOV for RL
	observation_viewport.add_child(observation_camera)

	print("RLEnv: Observation viewport created (", obs_width, "x", obs_height, ")")

func _setup_progress_provider():
	# Try to load path_progress.gd
	var script = load("res://path_progress.gd")
	if script:
		progress_provider = script.new()
		add_child(progress_provider)
		print("RLEnv: Using path_progress.gd for progress tracking")
	else:
		push_warning("RLEnv: No progress provider found - rewards will be limited")

func _on_message_received(message: Dictionary):
	var msg_type = message.get("type", "")

	match msg_type:
		"reset":
			_handle_reset(message)
		"step":
			_handle_step(message)
		"close":
			_handle_close(message)
		"get_info":
			_handle_get_info(message)
		_:
			push_warning("RLEnv: Unknown message type: ", msg_type)

func _handle_reset(_message: Dictionary):
	print("RLEnv: Reset requested")

	# Reset episode state
	step_count = 0
	episode_reward = 0.0
	last_progress = 0.0
	is_episode_active = true
	episode_count += 1

	# Reset player position
	if player and progress_provider:
		var start_pos = progress_provider.get_start_position()
		var start_rot = progress_provider.get_start_rotation()

		player.global_position = start_pos
		player.rotation = start_rot
		player.velocity = Vector3.ZERO

		progress_provider.reset_progress()
		print("RLEnv: Player reset to ", start_pos)
	elif terrain and terrain.has_method("generate_new_world"):
		# Regenerate world for variety
		terrain.generate_new_world()

	# Wait a frame for physics to settle, then send observation
	await get_tree().physics_frame
	await get_tree().physics_frame

	_sync_observation_camera()

	# Capture and send observation
	var obs = _get_observation()
	var response = {
		"type": "reset_response",
		"observation": obs,
		"info": {
			"episode": episode_count
		}
	}
	server.send_message(response)

func _handle_step(message: Dictionary):
	var action = message.get("action", [0.0, 0.0])

	# Store action to be applied in physics process
	pending_action = action
	action_ready = true
	step_response_pending = true

func _handle_close(_message: Dictionary):
	print("RLEnv: Close requested")
	server.send_message({"type": "close_response", "status": "ok"})

	# Clean shutdown
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

func _handle_get_info(_message: Dictionary):
	var info = {
		"type": "info_response",
		"observation_space": {
			"type": "Box",
			"shape": [obs_height, obs_width, 3],
			"low": 0,
			"high": 255,
			"dtype": "uint8"
		},
		"action_space": {
			"type": "Box",
			"shape": [2],
			"low": [-1.0, -1.0],
			"high": [1.0, 1.0],
			"dtype": "float32"
		}
	}
	server.send_message(info)

func _physics_process(_delta):
	if not action_ready or not step_response_pending:
		return

	action_ready = false

	# Apply action to player
	_apply_action(pending_action)

	# Wait for physics to process
	await get_tree().physics_frame

	# Compute step results
	step_count += 1

	_sync_observation_camera()

	var obs = _get_observation()
	var reward = _compute_reward()
	var terminated = _check_terminated()
	var truncated = _check_truncated()

	episode_reward += reward

	var info = {
		"step": step_count,
		"progress": progress_provider.get_progress() if progress_provider else 0.0,
		"on_track": progress_provider.is_on_track() if progress_provider else true,
		"episode_reward": episode_reward
	}

	if terminated or truncated:
		is_episode_active = false
		info["terminal_observation"] = obs

	var response = {
		"type": "step_response",
		"observation": obs,
		"reward": reward,
		"terminated": terminated,
		"truncated": truncated,
		"info": info
	}
	server.send_message(response)
	step_response_pending = false

func _apply_action(action: Array):
	if not player:
		return

	var steer = clamp(action[0] if action.size() > 0 else 0.0, -1.0, 1.0)
	var throttle = clamp(action[1] if action.size() > 1 else 0.0, -1.0, 1.0)

	# Apply as simulated inputs (works with player.gd tank controls)
	# Steer: negative = left, positive = right
	# Throttle: positive = forward, negative = backward

	Input.action_release("turn_left")
	Input.action_release("turn_right")
	Input.action_release("move_forward")
	Input.action_release("move_backward")

	if steer < -0.1:
		Input.action_press("turn_left", -steer)
	elif steer > 0.1:
		Input.action_press("turn_right", steer)

	if throttle > 0.1:
		Input.action_press("move_forward", throttle)
	elif throttle < -0.1:
		Input.action_press("move_backward", -throttle)

func _sync_observation_camera():
	if not observation_camera or not player:
		return

	# Position camera at player's eye level, looking forward
	var player_cam = player.get_node_or_null("Camera3D")
	if player_cam:
		observation_camera.global_transform = player_cam.global_transform
	else:
		observation_camera.global_position = player.global_position + Vector3(0, 1.7, 0)
		observation_camera.rotation = player.rotation

func _get_observation() -> Array:
	if not observation_viewport:
		return []

	# Wait for render
	await RenderingServer.frame_post_draw

	var img = observation_viewport.get_texture().get_image()
	if not img:
		return []

	# Ensure correct size
	if img.get_width() != obs_width or img.get_height() != obs_height:
		img.resize(obs_width, obs_height, Image.INTERPOLATE_BILINEAR)

	# Convert to RGB array
	img.convert(Image.FORMAT_RGB8)
	var data = img.get_data()

	# Return as flat array of uint8 values
	var result = []
	result.resize(data.size())
	for i in range(data.size()):
		result[i] = data[i]

	return result

func _compute_reward() -> float:
	var reward_config = config.get("reward", {})
	var reward = 0.0

	if not progress_provider:
		return reward

	var progress = progress_provider.get_progress()
	var delta_progress = progress - last_progress
	last_progress = progress

	# Progress reward
	var progress_scale = reward_config.get("progress_scale", 5.0)
	reward += clamp(delta_progress, -0.1, 0.1) * progress_scale

	# On/off track bonus/penalty
	if progress_provider.is_on_track():
		reward += reward_config.get("on_track_bonus", 0.05)
	else:
		reward += reward_config.get("off_track_penalty", -0.5)

	# Time penalty (encourages speed)
	reward += reward_config.get("time_penalty", -0.01)

	# Success bonus
	if progress >= 1.0:
		reward += reward_config.get("success_bonus", 50.0)

	return reward

func _check_terminated() -> bool:
	if not progress_provider:
		return false

	var episode_config = config.get("episode", {})

	# Success: completed track
	if progress_provider.get_progress() >= 1.0:
		print("RLEnv: Episode terminated - track completed!")
		return true

	# Failure: off track (if configured)
	if episode_config.get("off_track_terminates", true):
		if not progress_provider.is_on_track():
			print("RLEnv: Episode terminated - off track")
			return true

	return false

func _check_truncated() -> bool:
	var episode_config = config.get("episode", {})
	var max_steps = episode_config.get("max_steps", 2000)

	if step_count >= max_steps:
		print("RLEnv: Episode truncated - max steps reached")
		return true

	return false

func _exit_tree():
	# Clean up
	Input.action_release("turn_left")
	Input.action_release("turn_right")
	Input.action_release("move_forward")
	Input.action_release("move_backward")

	if server:
		server.stop()
