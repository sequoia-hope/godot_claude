extends StaticBody3D

var is_open: bool = false
var requires_key: bool = true

func _ready():
	add_to_group("door")

func interact(player):
	if is_open:
		print("Door is already open")
		return

	if requires_key and not player.has_item("key"):
		print("Door is locked. You need a key.")
		return

	open_door()

func open_door():
	is_open = true
	print("Door opened!")

	# Animate door opening - move it aside
	var tween = create_tween()
	tween.tween_property(self, "position:x", position.x + 2, 0.5)

	# Also make collision inactive
	$CollisionShape3D.disabled = true
