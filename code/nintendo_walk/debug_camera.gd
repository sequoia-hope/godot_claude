extends Node
## Debug script to capture screenshots of the current camera view

var output_dir: String = "res://debug_screenshots/"
var frame_count: int = 0
var max_frames: int = 3

func _ready():
	print("Debug Camera Test Starting")
	DirAccess.make_dir_recursive_absolute(output_dir)

	# Print camera info
	var player = get_node_or_null("/root/Main/Player")
	if player:
		print("Player found at: ", player.global_position)

		# Find the camera
		var camera = find_camera(player)
		if camera:
			print("Camera found: ", camera.get_path())
			print("Camera global position: ", camera.global_position)
			print("Camera FOV: ", camera.fov)
			print("Camera is current: ", camera.current)
		else:
			print("ERROR: No camera found!")

	# Wait a moment for the scene to settle
	await get_tree().create_timer(0.5).timeout

func find_camera(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	for child in node.get_children():
		var result = find_camera(child)
		if result:
			return result
	return null

func _process(_delta):
	frame_count += 1

	if frame_count == 10:
		capture_screenshot("frame_01_start")
	elif frame_count == 11:
		# Start moving forward
		Input.action_press("move_forward")
	elif frame_count == 90:
		Input.action_release("move_forward")
		capture_screenshot("frame_02_after_forward")
		var player = get_node_or_null("/root/Main/Player")
		if player:
			print("Player position after forward: ", player.global_position)
	elif frame_count == 100:
		print("\nDebug capture complete!")
		get_tree().quit()

func capture_screenshot(name: String):
	print("Capturing: ", name)

	await RenderingServer.frame_post_draw

	var viewport = get_viewport()
	var img = viewport.get_texture().get_image()

	var filename = output_dir + name + ".png"
	var err = img.save_png(filename)
	if err == OK:
		print("Saved: ", filename)
	else:
		print("ERROR saving screenshot: ", err)
