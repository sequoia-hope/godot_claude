extends Node3D

@onready var terrain: Node3D = $Terrain
@onready var player: CharacterBody3D = $Player

func _ready():
	print("Welcome to Nintendo Walk!")
	print("Controls:")
	print("  WASD - Move")
	print("  Space - Jump")
	print("  Mouse - Look around")
	print("  Q/E - Rotate camera")
	print("  R - Generate new world")
	print("  Escape - Release mouse")

	# Connect to terrain's world_generated signal
	if terrain:
		terrain.world_generated.connect(_on_world_generated)

func _on_world_generated(seed_value: int, path_start: Vector3, path_direction: Vector3):
	"""Called when a new world is generated - move player to path start"""
	if player:
		# Position player at path start, slightly above ground
		player.position = path_start + Vector3(0, 1.0, 0)
		player.velocity = Vector3.ZERO

		# Face player along the trail direction
		# Robot forward is +Z, so we need angle from +Z axis to path_direction
		if path_direction.length() > 0.1:
			var angle = atan2(path_direction.x, path_direction.z)
			player.rotation.y = angle

	print("Player spawned at path start: ", path_start, " facing: ", path_direction)

func _input(event):
	# Generate new world on R press
	if event.is_action_pressed("regenerate"):
		regenerate_world()

func regenerate_world():
	print("\n--- Generating new world ---")

	# Generate new terrain (player position will be set by signal)
	if terrain and terrain.has_method("generate_new_world"):
		terrain.generate_new_world()
