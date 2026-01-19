extends Node
## Screenshot test - captures player view and top-down view for multiple worlds

var worlds_to_capture: int = 10
var current_world: int = 0
var capture_state: int = 0  # 0=wait, 1=player_view, 2=top_down, 3=next
var state_timer: float = 0.0

var terrain: Node3D = null
var player: Node3D = null
var camera: Camera3D = null
var top_down_camera: Camera3D = null

var output_dir: String = "res://screenshots/"

func _ready():
	print("Screenshot Test Starting - Capturing ", worlds_to_capture, " worlds")

	# Create output directory
	DirAccess.make_dir_recursive_absolute(output_dir)

	# Get references
	terrain = get_node_or_null("/root/Main/Terrain")
	player = get_node_or_null("/root/Main/Player")

	if player:
		camera = player.get_node_or_null("CameraPivot/Camera3D")

	# Create top-down camera
	top_down_camera = Camera3D.new()
	top_down_camera.name = "TopDownCamera"
	get_node("/root/Main").add_child(top_down_camera)
	top_down_camera.position = Vector3(0, 80, 0)
	top_down_camera.rotation_degrees = Vector3(-90, 0, 0)
	top_down_camera.fov = 60
	top_down_camera.current = false

	# Start first world
	await get_tree().create_timer(0.2).timeout
	start_next_world()

func _process(delta):
	state_timer -= delta

	if state_timer <= 0:
		match capture_state:
			1:  # Capture player view
				capture_player_view()
				capture_state = 2
				state_timer = 0.3
			2:  # Capture top-down view
				capture_top_down_view()
				capture_state = 3
				state_timer = 0.3
			3:  # Move to next world
				current_world += 1
				if current_world < worlds_to_capture:
					start_next_world()
				else:
					finish_test()

func start_next_world():
	print("\n--- World ", current_world + 1, " of ", worlds_to_capture, " ---")

	if terrain and terrain.has_method("generate_new_world"):
		terrain.generate_new_world()

	# Wait for world to generate and settle
	capture_state = 0
	state_timer = 0.3

	await get_tree().create_timer(0.3).timeout
	capture_state = 1
	state_timer = 0.1

func capture_player_view():
	# Make sure we have valid player reference
	if not player:
		player = get_node_or_null("/root/Main/Player")

	if not player:
		print("WARNING: Player not found!")
		return

	# Position the capture camera behind and above the player (third-person view)
	var camera_pivot = player.get_node_or_null("CameraPivot")
	if camera_pivot:
		# Match the pivot's global transform
		top_down_camera.global_transform = camera_pivot.global_transform
		# Apply the camera offset (0, 4, 8) relative to pivot
		var offset = camera_pivot.global_transform.basis * Vector3(0, 4, 8)
		top_down_camera.global_position = camera_pivot.global_position + offset
		# Look at a point in front of the player
		var look_target = player.global_position + camera_pivot.global_transform.basis * Vector3(0, 1, -10)
		top_down_camera.look_at(look_target, Vector3.UP)
	else:
		# Fallback: position behind player looking toward center
		top_down_camera.global_position = player.global_position + Vector3(0, 5, 10)
		top_down_camera.look_at(player.global_position + Vector3(0, 1, 0), Vector3.UP)

	top_down_camera.fov = 60.0
	top_down_camera.current = true

	# Wait for render
	await get_tree().create_timer(0.1).timeout
	await RenderingServer.frame_post_draw

	var viewport = get_viewport()
	var img = viewport.get_texture().get_image()

	var filename = output_dir + "world_" + str(current_world + 1).pad_zeros(2) + "_player.png"
	img.save_png(filename)
	print("Saved: ", filename)

func capture_top_down_view():
	# Reset camera to top-down position
	top_down_camera.position = Vector3(0, 80, 0)
	top_down_camera.rotation_degrees = Vector3(-90, 0, 0)
	top_down_camera.fov = 60
	top_down_camera.current = true

	# Wait for camera to update and render
	await get_tree().create_timer(0.1).timeout
	await RenderingServer.frame_post_draw

	var viewport = get_viewport()
	var img = viewport.get_texture().get_image()

	var filename = output_dir + "world_" + str(current_world + 1).pad_zeros(2) + "_topdown.png"
	img.save_png(filename)
	print("Saved: ", filename)

func finish_test():
	print("\n" + "=".repeat(50))
	print("Screenshot test complete!")
	print("Captured ", worlds_to_capture, " worlds")
	print("Screenshots saved to: ", output_dir)
	print("=".repeat(50))

	# Write summary
	var summary = {
		"worlds_captured": worlds_to_capture,
		"output_dir": output_dir,
		"files": []
	}

	for i in range(worlds_to_capture):
		var num = str(i + 1).pad_zeros(2)
		summary["files"].append("world_" + num + "_player.png")
		summary["files"].append("world_" + num + "_topdown.png")

	var file = FileAccess.open(output_dir + "summary.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(summary, "\t"))
		file.close()

	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
