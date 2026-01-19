extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const TURN_SPEED = 2.0
const INTERACT_DISTANCE = 3.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var inventory: Array = []

func _physics_process(delta):
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get input direction
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	# Turn
	if Input.is_action_pressed("turn_left"):
		rotate_y(TURN_SPEED * delta)
	if Input.is_action_pressed("turn_right"):
		rotate_y(-TURN_SPEED * delta)

	# Movement relative to player direction
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	# Interact
	if Input.is_action_just_pressed("interact"):
		try_interact()

func try_interact():
	# Find nearby interactables
	var nearest_distance = INTERACT_DISTANCE
	var nearest_target = null

	# Check for pickups first
	for pickup in get_tree().get_nodes_in_group("pickup"):
		var dist = global_position.distance_to(pickup.global_position)
		if dist < nearest_distance:
			nearest_distance = dist
			nearest_target = pickup

	# Check for doors
	for door in get_tree().get_nodes_in_group("door"):
		var dist = global_position.distance_to(door.global_position)
		if dist < nearest_distance:
			nearest_distance = dist
			nearest_target = door

	if nearest_target and nearest_target.has_method("interact"):
		nearest_target.interact(self)

func has_item(item_name: String) -> bool:
	return item_name in inventory

func add_to_inventory(item_name: String):
	inventory.append(item_name)
	print("Picked up: ", item_name)
