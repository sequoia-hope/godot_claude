extends Node
## Main scene controller for Skid Steer Robot Path Follower

@onready var player: CharacterBody3D = $Player
@onready var terrain: Node3D = $Terrain

func _ready():
	# Connect to terrain signals
	if terrain and terrain.has_signal("world_generated"):
		terrain.world_generated.connect(_on_world_generated)

	# Position player at path start after terrain generates
	call_deferred("_position_player_at_start")

func _position_player_at_start():
	if not terrain or not player:
		return

	# Wait a frame for terrain to be ready
	await get_tree().process_frame

	var path_start = terrain.get("path_start")
	if path_start:
		player.global_position = Vector3(path_start.x, 0.2, path_start.z)

		# Orient player to face along path
		# Robot's forward is -Z, so we use atan2 to point -Z toward the path direction
		var path_points = terrain.get("path_points")
		if path_points and path_points.size() >= 2:
			var direction = (path_points[1] - path_points[0]).normalized()
			# atan2(x, z) makes +Z point toward direction
			# We want -Z to point toward direction, so add PI
			var angle = atan2(direction.x, direction.z) + PI
			player.rotation.y = angle

		print("Player positioned at path start: ", player.global_position)

func _on_world_generated(seed_value: int, start: Vector3, direction: Vector3):
	print("World generated with seed: ", seed_value)
	print("Path start: ", start, " direction: ", direction)

func _input(event):
	# Press R to regenerate world
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		regenerate_world()

	# Press Escape to quit
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()

func regenerate_world():
	if terrain and terrain.has_method("generate_new_world"):
		terrain.generate_new_world()
		_position_player_at_start()
