extends Area3D

var item_name: String = "key"

func _ready():
	add_to_group("pickup")

func interact(player):
	# Add key to player inventory
	player.add_to_inventory(item_name)

	# Remove key from scene
	queue_free()
	print("Key collected!")
