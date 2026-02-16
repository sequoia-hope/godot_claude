extends Node3D
## Main scene controller for Trail Runner Robot

@onready var player: CharacterBody3D = $Player
@onready var terrain: Node3D = $Terrain

func _ready() -> void:
	if terrain and terrain.has_signal("world_generated"):
		terrain.world_generated.connect(_on_world_generated)
	call_deferred("_position_player_at_start")

func _position_player_at_start() -> void:
	if not terrain or not player:
		return
	await get_tree().process_frame

	var path_start = terrain.get("path_start")
	if path_start:
		player.global_position = Vector3(path_start.x, 0.2, path_start.z)

		var path_points = terrain.get("path_points")
		if path_points and path_points.size() >= 2:
			var direction = (path_points[1] - path_points[0]).normalized()
			player.rotation.y = atan2(direction.x, direction.z) + PI

		print("Player positioned at path start: ", player.global_position)

func _on_world_generated(seed_value: int, start: Vector3, direction: Vector3) -> void:
	print("World generated with seed: ", seed_value)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				regenerate_world()
			KEY_ESCAPE:
				get_tree().quit()

func regenerate_world() -> void:
	if terrain and terrain.has_method("generate_new_world"):
		terrain.generate_new_world()
		_position_player_at_start()
