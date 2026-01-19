extends Node3D
## Procedural Nintendo-style terrain with hills, path, and trees

signal world_generated(seed_value: int, path_start: Vector3, path_direction: Vector3)

@export var terrain_size: float = 40.0
@export var hill_count: int = 6
@export var tree_count: int = 15
@export var path_width: float = 2.5
@export var path_samples: int = 40  # Number of segments for smooth curve

# Nintendo-style colors
var grass_color = Color(0.4, 0.75, 0.3)  # Bright green
var hill_color = Color(0.35, 0.7, 0.25)  # Slightly darker green for hills
var path_color = Color(0.76, 0.6, 0.42)  # Warm dirt brown
var trunk_color = Color(0.55, 0.35, 0.2)  # Tree trunk brown
var foliage_color = Color(0.3, 0.65, 0.2)  # Tree foliage green
var foliage_color2 = Color(0.25, 0.55, 0.15)  # Darker foliage variation

var hills: Array = []
var path_points: Array = []  # Sampled points along the smooth curve
var path_control_points: Array = []  # Control points for the spline
var path_start: Vector3 = Vector3.ZERO
var path_end: Vector3 = Vector3.ZERO
var current_seed: int = 0

func _ready():
	# Generate with random seed on first load
	generate_new_world()

func generate_new_world():
	"""Generate a completely new world with a random seed"""
	current_seed = randi()
	regenerate_terrain(current_seed)

func regenerate_terrain(seed_value: int):
	"""Clear and regenerate terrain with specific seed"""
	current_seed = seed_value

	# Clear existing terrain
	clear_terrain()

	# Regenerate
	generate_terrain()

	# Calculate path direction from first two points
	var path_direction = Vector3.FORWARD
	if path_points.size() >= 2:
		path_direction = (path_points[1] - path_points[0]).normalized()
		path_direction.y = 0  # Keep horizontal
		path_direction = path_direction.normalized()

	# Emit signal deferred so parent nodes have time to connect
	call_deferred("_emit_world_generated", current_seed, path_start, path_direction)
	print("Generated world with seed: ", current_seed)

func _emit_world_generated(seed_value: int, start: Vector3, direction: Vector3):
	world_generated.emit(seed_value, start, direction)

func clear_terrain():
	"""Remove all generated terrain objects"""
	hills.clear()
	path_points.clear()
	path_control_points.clear()

	# Remove all children except permanent ones
	for child in get_children():
		child.queue_free()

func generate_terrain():
	create_ground()
	create_path()    # Path first so hills and trees can avoid it
	create_hills()   # Hills avoid the path
	create_trees()   # Trees avoid the path

func create_ground():
	# Main flat ground plane
	var ground = StaticBody3D.new()
	ground.name = "Ground"
	add_child(ground)

	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(terrain_size * 2, 1, terrain_size * 2)
	collision.shape = shape
	collision.position.y = -0.5
	ground.add_child(collision)

	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(terrain_size * 2, 1, terrain_size * 2)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = -0.5

	var material = StandardMaterial3D.new()
	material.albedo_color = grass_color
	material.roughness = 0.9
	mesh_instance.material_override = material
	ground.add_child(mesh_instance)

func create_hills():
	# Create gentle rolling hills using flattened spheres
	var rng = RandomNumberGenerator.new()
	rng.seed = current_seed  # Use current world seed

	var placed_hills = 0
	var attempts = 0

	while placed_hills < hill_count and attempts < 50:
		attempts += 1

		var hill = StaticBody3D.new()
		hill.name = "Hill_" + str(placed_hills)

		# Random position avoiding center (where player spawns)
		var pos = Vector3.ZERO
		pos.x = rng.randf_range(-terrain_size * 0.7, terrain_size * 0.7)
		pos.z = rng.randf_range(-terrain_size * 0.7, terrain_size * 0.7)

		# Skip if too close to center (player spawn)
		if pos.length() < 8.0:
			continue

		# Skip if too close to the path
		var hill_radius = rng.randf_range(6.0, 12.0) / 2.0
		if is_point_near_path(pos, path_width + hill_radius + 2.0):
			continue

		pos.y = 0
		hill.position = pos

		# Random hill size
		var width = rng.randf_range(6.0, 12.0)
		var height = rng.randf_range(1.5, 4.0)

		# Collision - use a box approximation for simplicity
		var collision = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(width * 0.8, height, width * 0.8)
		collision.shape = box_shape
		collision.position.y = height * 0.3
		hill.add_child(collision)

		# Visual mesh - sphere scaled to be a hill
		var mesh_instance = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = width / 2.0
		sphere.height = height * 2.0
		sphere.radial_segments = 16
		sphere.rings = 8
		mesh_instance.mesh = sphere
		mesh_instance.position.y = 0
		mesh_instance.scale = Vector3(1.0, 0.5, 1.0)  # Flatten it

		var material = StandardMaterial3D.new()
		material.albedo_color = hill_color.lerp(grass_color, rng.randf_range(0.0, 0.3))
		material.roughness = 0.9
		mesh_instance.material_override = material
		hill.add_child(mesh_instance)

		add_child(hill)
		hills.append({"position": pos, "radius": width / 2.0, "height": height})
		placed_hills += 1

func create_path():
	# Create a smooth winding dirt path from one corner to the diagonal opposite
	var path_node = Node3D.new()
	path_node.name = "Path"
	add_child(path_node)

	var rng = RandomNumberGenerator.new()
	rng.seed = current_seed + 500

	# Choose a random starting corner (diagonal pairs)
	var corner_offset = terrain_size * 0.85
	var corners = [
		Vector3(-corner_offset, 0.02, -corner_offset),  # SW
		Vector3(-corner_offset, 0.02,  corner_offset),  # NW
		Vector3( corner_offset, 0.02, -corner_offset),  # SE
		Vector3( corner_offset, 0.02,  corner_offset),  # NE
	]
	var diagonal_opposite = [3, 2, 1, 0]  # Diagonal opposite indices

	var start_idx = rng.randi_range(0, 3)
	var end_idx = diagonal_opposite[start_idx]

	path_start = corners[start_idx]
	path_end = corners[end_idx]

	# Generate control points for the spline
	path_control_points = generate_spline_control_points(path_start, path_end, rng)

	# Sample smooth curve from control points
	path_points = sample_catmull_rom_spline(path_control_points, path_samples)

	# Create smooth path mesh
	create_smooth_path_mesh(path_node)

func generate_spline_control_points(start: Vector3, end: Vector3, rng: RandomNumberGenerator) -> Array:
	"""Generate control points for a smooth meandering spline"""
	var points = []

	# Add phantom point before start for smooth curve at endpoints
	var start_tangent = (end - start).normalized() * terrain_size * 0.3
	points.append(start - start_tangent)
	points.append(start)

	# Number of interior control points
	var num_controls = rng.randi_range(3, 5)

	# Direction from start to end
	var main_direction = (end - start).normalized()
	var perpendicular = Vector3(-main_direction.z, 0, main_direction.x)

	# Track which side we're curving toward
	var side = 1 if rng.randf() > 0.5 else -1

	for i in range(num_controls):
		# Progress along the main path (0 to 1)
		var t = float(i + 1) / float(num_controls + 1)

		# Base position along direct line
		var base_pos = start.lerp(end, t)

		# Meander amount - S-curve shape
		var meander_strength = sin(t * PI) * terrain_size * 0.35

		# Add perpendicular offset
		var offset = perpendicular * side * meander_strength * rng.randf_range(0.5, 1.0)

		var control_point = base_pos + offset
		control_point.y = 0.02

		# Clamp to terrain bounds
		control_point.x = clamp(control_point.x, -terrain_size * 0.8, terrain_size * 0.8)
		control_point.z = clamp(control_point.z, -terrain_size * 0.8, terrain_size * 0.8)

		points.append(control_point)

		# Alternate sides for S-curve
		side = -side

	points.append(end)
	# Add phantom point after end for smooth curve at endpoint
	points.append(end + start_tangent)

	return points

func sample_catmull_rom_spline(control_points: Array, num_samples: int) -> Array:
	"""Sample points along a Catmull-Rom spline"""
	var sampled = []

	if control_points.size() < 4:
		return control_points

	# Number of curve segments (excluding phantom points)
	var num_segments = control_points.size() - 3
	var samples_per_segment = num_samples / num_segments

	for seg in range(num_segments):
		var p0 = control_points[seg]
		var p1 = control_points[seg + 1]
		var p2 = control_points[seg + 2]
		var p3 = control_points[seg + 3]

		var segment_samples = samples_per_segment
		if seg == num_segments - 1:
			segment_samples += 1  # Include endpoint on last segment

		for i in range(segment_samples):
			var t = float(i) / float(samples_per_segment)
			var point = catmull_rom_point(p0, p1, p2, p3, t)
			sampled.append(point)

	return sampled

func catmull_rom_point(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	"""Calculate a point on a Catmull-Rom spline"""
	var t2 = t * t
	var t3 = t2 * t

	var result = Vector3.ZERO
	result += p0 * (-0.5 * t3 + t2 - 0.5 * t)
	result += p1 * (1.5 * t3 - 2.5 * t2 + 1.0)
	result += p2 * (-1.5 * t3 + 2.0 * t2 + 0.5 * t)
	result += p3 * (0.5 * t3 - 0.5 * t2)

	result.y = 0.02  # Keep flat
	return result

func create_smooth_path_mesh(path_node: Node3D):
	"""Create a smooth path mesh from sampled points"""
	if path_points.size() < 2:
		return

	# Create mesh using triangle strips for smooth curves
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var material = StandardMaterial3D.new()
	material.albedo_color = path_color
	material.roughness = 1.0
	surface_tool.set_material(material)

	for i in range(path_points.size() - 1):
		var p1 = path_points[i]
		var p2 = path_points[i + 1]

		# Calculate perpendicular direction for width
		var direction = (p2 - p1).normalized()
		var perp = Vector3(-direction.z, 0, direction.x) * (path_width / 2.0)

		# Four corners of this path segment
		var v1 = p1 + perp
		var v2 = p1 - perp
		var v3 = p2 + perp
		var v4 = p2 - perp

		# Small Y offset to prevent z-fighting
		v1.y = 0.02
		v2.y = 0.02
		v3.y = 0.02
		v4.y = 0.02

		# Two triangles for quad
		surface_tool.add_vertex(v1)
		surface_tool.add_vertex(v2)
		surface_tool.add_vertex(v3)

		surface_tool.add_vertex(v2)
		surface_tool.add_vertex(v4)
		surface_tool.add_vertex(v3)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = surface_tool.commit()
	path_node.add_child(mesh_instance)

func is_point_near_path(pos: Vector3, min_distance: float) -> bool:
	"""Check if a point is too close to the path"""
	for i in range(path_points.size() - 1):
		var dist = point_to_segment_distance(pos, path_points[i], path_points[i + 1])
		if dist < min_distance:
			return true
	return false

func point_to_segment_distance(point: Vector3, seg_start: Vector3, seg_end: Vector3) -> float:
	"""Calculate distance from point to line segment (in XZ plane)"""
	var p = Vector2(point.x, point.z)
	var a = Vector2(seg_start.x, seg_start.z)
	var b = Vector2(seg_end.x, seg_end.z)

	var ab = b - a
	var ap = p - a

	var t = clamp(ap.dot(ab) / ab.length_squared(), 0.0, 1.0)
	var closest = a + ab * t

	return p.distance_to(closest)

func create_trees():
	var rng = RandomNumberGenerator.new()
	rng.seed = current_seed + 1000  # Offset from hill seed for variety

	var placed_trees = 0
	var attempts = 0

	while placed_trees < tree_count and attempts < 100:
		attempts += 1

		# Random position
		var pos = Vector3(
			rng.randf_range(-terrain_size * 0.8, terrain_size * 0.8),
			0,
			rng.randf_range(-terrain_size * 0.8, terrain_size * 0.8)
		)

		# Check if too close to center (player spawn)
		if pos.length() < 5.0:
			continue

		# Check if too close to path (trees should not obstruct it)
		if is_point_near_path(pos, path_width + 1.5):
			continue

		# Check height at position (if on a hill)
		var height = get_height_at(pos)
		pos.y = height

		create_tree(pos, rng)
		placed_trees += 1

func get_height_at(pos: Vector3) -> float:
	var height = 0.0
	for hill in hills:
		var dist = Vector2(pos.x - hill.position.x, pos.z - hill.position.z).length()
		if dist < hill.radius:
			var t = 1.0 - (dist / hill.radius)
			height = max(height, hill.height * t * t * 0.5)
	return height

func create_tree(pos: Vector3, rng: RandomNumberGenerator):
	var tree = Node3D.new()
	tree.name = "Tree"
	tree.position = pos

	# Random tree size (Nintendo style - varied sizes)
	var scale_factor = rng.randf_range(0.7, 1.3)
	var trunk_height = 1.5 * scale_factor
	var trunk_radius = 0.2 * scale_factor
	var foliage_radius = 1.2 * scale_factor

	# Trunk
	var trunk = MeshInstance3D.new()
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = trunk_radius * 0.8
	trunk_mesh.bottom_radius = trunk_radius
	trunk_mesh.height = trunk_height
	trunk_mesh.radial_segments = 8
	trunk.mesh = trunk_mesh
	trunk.position.y = trunk_height / 2.0

	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = trunk_color
	trunk_mat.roughness = 0.9
	trunk.material_override = trunk_mat
	tree.add_child(trunk)

	# Foliage - Nintendo style uses round, friendly shapes
	# Main foliage ball
	var foliage = MeshInstance3D.new()
	var foliage_mesh = SphereMesh.new()
	foliage_mesh.radius = foliage_radius
	foliage_mesh.height = foliage_radius * 2.0
	foliage_mesh.radial_segments = 12
	foliage_mesh.rings = 6
	foliage.mesh = foliage_mesh
	foliage.position.y = trunk_height + foliage_radius * 0.6

	var foliage_mat = StandardMaterial3D.new()
	foliage_mat.albedo_color = foliage_color if rng.randf() > 0.5 else foliage_color2
	foliage_mat.roughness = 0.8
	foliage.material_override = foliage_mat
	tree.add_child(foliage)

	# Add a second smaller foliage sphere for fullness
	var foliage2 = MeshInstance3D.new()
	var foliage_mesh2 = SphereMesh.new()
	foliage_mesh2.radius = foliage_radius * 0.7
	foliage_mesh2.height = foliage_radius * 1.4
	foliage2.mesh = foliage_mesh2
	foliage2.position = Vector3(
		rng.randf_range(-0.3, 0.3) * scale_factor,
		trunk_height + foliage_radius * 1.2,
		rng.randf_range(-0.3, 0.3) * scale_factor
	)

	var foliage_mat2 = StandardMaterial3D.new()
	foliage_mat2.albedo_color = foliage_color.lerp(foliage_color2, rng.randf())
	foliage_mat2.roughness = 0.8
	foliage2.material_override = foliage_mat2
	tree.add_child(foliage2)

	add_child(tree)
