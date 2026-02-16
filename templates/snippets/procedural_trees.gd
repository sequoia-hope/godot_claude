## Procedural Tree Generator
## Known-good implementation for creating trees in Godot 4.x
##
## Note: ConeMesh does NOT exist in Godot 4.x!
## Use CylinderMesh with top_radius=0 for cone shapes.

## Creates a stylized conifer/redwood tree.
##
## Args:
##   height: float - total tree height
##   trunk_radius: float - base trunk radius
##   trunk_color: Color - trunk material color
##   foliage_color: Color - foliage material color
##   foliage_layers: int - number of cone layers for foliage
##
## Returns:
##   Node3D containing the complete tree
static func create_conifer_tree(
	height: float = 10.0,
	trunk_radius: float = 0.4,
	trunk_color: Color = Color(0.4, 0.25, 0.15),
	foliage_color: Color = Color(0.1, 0.35, 0.15),
	foliage_layers: int = 4
) -> Node3D:
	var tree := Node3D.new()

	# === Trunk ===
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = trunk_radius * 0.7
	trunk_mesh.bottom_radius = trunk_radius
	trunk_mesh.height = height * 0.6

	var trunk := MeshInstance3D.new()
	trunk.mesh = trunk_mesh
	trunk.position.y = height * 0.3  # Center of trunk

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = trunk_color
	trunk_mat.roughness = 0.9
	trunk.material_override = trunk_mat
	tree.add_child(trunk)

	# === Foliage (layered cones) ===
	var foliage_mat := StandardMaterial3D.new()
	foliage_mat.albedo_color = foliage_color
	foliage_mat.roughness = 0.8

	for i in range(foliage_layers):
		var layer_height := height * (0.4 + float(i) * 0.15)
		var layer_radius := (height * 0.25) * (1.0 - float(i) * 0.2)

		# IMPORTANT: Use CylinderMesh with top_radius=0 for cones
		# ConeMesh does NOT exist in Godot 4!
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0  # This makes it a cone
		cone.bottom_radius = layer_radius
		cone.height = height * 0.25

		var foliage := MeshInstance3D.new()
		foliage.mesh = cone
		foliage.position.y = layer_height
		foliage.material_override = foliage_mat
		tree.add_child(foliage)

	return tree


## Creates a deciduous (round-topped) tree.
##
## Args:
##   height: float - total tree height
##   trunk_radius: float - trunk radius
##   canopy_radius: float - foliage sphere radius
##   trunk_color: Color - trunk color
##   foliage_color: Color - foliage color
##
## Returns:
##   Node3D containing the tree
static func create_deciduous_tree(
	height: float = 8.0,
	trunk_radius: float = 0.3,
	canopy_radius: float = 3.0,
	trunk_color: Color = Color(0.35, 0.2, 0.1),
	foliage_color: Color = Color(0.2, 0.45, 0.15)
) -> Node3D:
	var tree := Node3D.new()

	# Trunk
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = trunk_radius * 0.8
	trunk_mesh.bottom_radius = trunk_radius
	trunk_mesh.height = height * 0.5

	var trunk := MeshInstance3D.new()
	trunk.mesh = trunk_mesh
	trunk.position.y = height * 0.25

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = trunk_color
	trunk_mat.roughness = 0.9
	trunk.material_override = trunk_mat
	tree.add_child(trunk)

	# Canopy (sphere)
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = canopy_radius
	canopy_mesh.height = canopy_radius * 1.5

	var canopy := MeshInstance3D.new()
	canopy.mesh = canopy_mesh
	canopy.position.y = height * 0.6

	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = foliage_color
	canopy_mat.roughness = 0.8
	canopy.material_override = canopy_mat
	tree.add_child(canopy)

	return tree


## Scatters trees avoiding specified areas.
##
## Args:
##   container: Node3D - parent node for trees
##   count: int - number of trees to place
##   bounds: Vector2 - world half-size (trees placed in -bounds to +bounds)
##   avoid_check: Callable - func(pos: Vector3) -> bool, returns true if position should be avoided
##   tree_factory: Callable - func() -> Node3D, creates a tree instance
##   min_spacing: float - minimum distance between trees
##
## Returns:
##   int - number of trees actually placed
static func scatter_trees(
	container: Node3D,
	count: int,
	bounds: float,
	avoid_check: Callable,
	tree_factory: Callable,
	min_spacing: float = 3.0
) -> int:
	var placed := 0
	var attempts := 0
	var max_attempts := count * 20
	var positions: Array[Vector3] = []

	while placed < count and attempts < max_attempts:
		attempts += 1

		var pos := Vector3(
			randf_range(-bounds, bounds),
			0,
			randf_range(-bounds, bounds)
		)

		# Check avoidance areas
		if avoid_check.call(pos):
			continue

		# Check spacing from other trees
		var too_close := false
		for existing in positions:
			if pos.distance_to(existing) < min_spacing:
				too_close = true
				break

		if too_close:
			continue

		# Place tree
		var tree: Node3D = tree_factory.call()
		tree.position = pos
		container.add_child(tree)
		positions.append(pos)
		placed += 1

	return placed
