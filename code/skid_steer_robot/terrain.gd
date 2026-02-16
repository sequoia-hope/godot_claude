extends Node3D
## Procedural terrain generator with winding path and patchy texture
##
## World: 100x100 meters
## Path: 0.8m wide, starts 2m from corner, winds to diagonal opposite corner
## Background: Patchy green and blue blobs

signal world_generated(seed_value: int, path_start: Vector3, path_direction: Vector3)

@export var terrain_size: float = 50.0  # 50x50 meters
@export var path_width: float = 0.8  # 0.8 meter wide path
@export var path_samples: int = 60  # Smooth path sampling
@export var corner_offset: float = 2.0  # Path starts 2m from corner
@export var tree_count: int = 25  # Number of redwood trees

# Colors
var path_color = Color(0.6, 0.5, 0.35)  # Dirt/sand path
var green_color = Color(0.2, 0.5, 0.15)  # Dark green patches
var blue_color = Color(0.15, 0.3, 0.5)  # Blue patches
var base_color = Color(0.25, 0.45, 0.2)  # Base green

# Redwood tree colors
var bark_color = Color(0.4, 0.2, 0.15)  # Reddish-brown bark
var bark_color_dark = Color(0.3, 0.15, 0.1)  # Darker bark variation
var foliage_color = Color(0.15, 0.35, 0.12)  # Dark green redwood foliage
var foliage_color_light = Color(0.2, 0.4, 0.15)  # Lighter foliage variation

# State
var path_points: Array = []
var path_control_points: Array = []
var path_start: Vector3 = Vector3.ZERO
var path_end: Vector3 = Vector3.ZERO
var current_seed: int = 0

func _ready():
	generate_new_world()

func generate_new_world():
	current_seed = randi()
	regenerate_terrain(current_seed)

func regenerate_terrain(seed_value: int):
	current_seed = seed_value
	clear_terrain()
	generate_terrain()

	var path_direction = Vector3.FORWARD
	if path_points.size() >= 2:
		path_direction = (path_points[1] - path_points[0]).normalized()
		path_direction.y = 0
		path_direction = path_direction.normalized()

	call_deferred("_emit_world_generated", current_seed, path_start, path_direction)
	print("Generated world with seed: ", current_seed)

func _emit_world_generated(seed_value: int, start: Vector3, direction: Vector3):
	world_generated.emit(seed_value, start, direction)

func clear_terrain():
	path_points.clear()
	path_control_points.clear()
	for child in get_children():
		child.queue_free()

func generate_terrain():
	create_ground_with_texture()
	create_path()
	create_redwood_trees()

func create_ground_with_texture():
	var ground = StaticBody3D.new()
	ground.name = "Ground"
	add_child(ground)

	# Collision shape
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(terrain_size, 1, terrain_size)
	collision.shape = shape
	collision.position.y = -0.5
	ground.add_child(collision)

	# Create ground mesh with patchy texture
	var mesh_instance = MeshInstance3D.new()
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(terrain_size, terrain_size)
	mesh.subdivide_width = 100
	mesh.subdivide_depth = 100
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.01

	# Create shader material for patchy texture
	var material = ShaderMaterial.new()
	material.shader = create_patchy_shader()
	material.set_shader_parameter("base_color", base_color)
	material.set_shader_parameter("green_color", green_color)
	material.set_shader_parameter("blue_color", blue_color)
	material.set_shader_parameter("noise_scale", 0.05)
	material.set_shader_parameter("seed_offset", float(current_seed % 1000))
	mesh_instance.material_override = material

	ground.add_child(mesh_instance)

func create_patchy_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.25, 0.45, 0.2);
uniform vec3 green_color : source_color = vec3(0.2, 0.5, 0.15);
uniform vec3 blue_color : source_color = vec3(0.15, 0.3, 0.5);
uniform float noise_scale = 0.05;
uniform float seed_offset = 0.0;

// Simple hash function for noise
float hash(vec2 p) {
	return fract(sin(dot(p + seed_offset, vec2(127.1, 311.7))) * 43758.5453);
}

// Value noise
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal noise
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	vec2 uv = UV * 100.0 * noise_scale;

	// Multiple noise layers for patchy effect
	float n1 = fbm(uv);
	float n2 = fbm(uv * 1.5 + 50.0);
	float n3 = fbm(uv * 0.7 + 100.0);

	// Create patches
	vec3 color = base_color;

	// Green patches
	float green_mask = smoothstep(0.4, 0.6, n1);
	color = mix(color, green_color, green_mask * 0.7);

	// Blue patches
	float blue_mask = smoothstep(0.5, 0.7, n2) * (1.0 - smoothstep(0.3, 0.5, n3));
	color = mix(color, blue_color, blue_mask * 0.6);

	ALBEDO = color;
	ROUGHNESS = 0.9;
}
"""
	return shader

func create_path():
	var path_node = Node3D.new()
	path_node.name = "Path"
	add_child(path_node)

	var rng = RandomNumberGenerator.new()
	rng.seed = current_seed + 500

	# Define corners (100x100 world, path starts 2m from edge)
	var half_size = terrain_size / 2.0
	var offset = corner_offset

	# Corners at ground level
	var corners = [
		Vector3(-half_size + offset, 0.02, -half_size + offset),  # SW
		Vector3(-half_size + offset, 0.02, half_size - offset),   # NW
		Vector3(half_size - offset, 0.02, -half_size + offset),   # SE
		Vector3(half_size - offset, 0.02, half_size - offset),    # NE
	]
	var diagonal_opposite = [3, 2, 1, 0]  # Diagonal pairs

	# Random starting corner
	var start_idx = rng.randi_range(0, 3)
	var end_idx = diagonal_opposite[start_idx]

	path_start = corners[start_idx]
	path_end = corners[end_idx]

	# Generate control points for winding path
	path_control_points = generate_winding_path(path_start, path_end, rng)

	# Sample the path
	path_points = sample_catmull_rom_spline(path_control_points, path_samples)

	# Create path mesh
	create_path_mesh(path_node)

func generate_winding_path(start: Vector3, end: Vector3, rng: RandomNumberGenerator) -> Array:
	var points = []

	# Phantom point before start for smooth curve
	var main_dir = (end - start).normalized()
	var tangent = main_dir * terrain_size * 0.15
	points.append(start - tangent)
	points.append(start)

	# Number of interior control points (more = more winding)
	var num_controls = rng.randi_range(5, 8)

	# Perpendicular direction for meandering
	var perp = Vector3(-main_dir.z, 0, main_dir.x)

	# Alternate sides for S-curve effect
	var side = 1 if rng.randf() > 0.5 else -1

	for i in range(num_controls):
		var t = float(i + 1) / float(num_controls + 1)
		var base_pos = start.lerp(end, t)

		# Meander strength varies along path (more in middle)
		var meander_strength = sin(t * PI) * terrain_size * 0.25

		# Random offset perpendicular to main direction
		var offset = perp * side * meander_strength * rng.randf_range(0.3, 1.0)

		var control_point = base_pos + offset
		control_point.y = 0.02

		# Keep within bounds
		var half = terrain_size / 2.0 - 5.0
		control_point.x = clamp(control_point.x, -half, half)
		control_point.z = clamp(control_point.z, -half, half)

		points.append(control_point)

		# Alternate sides
		side = -side

	points.append(end)
	points.append(end + tangent)  # Phantom point after end

	return points

func sample_catmull_rom_spline(control_points: Array, num_samples: int) -> Array:
	var sampled = []

	if control_points.size() < 4:
		return control_points

	var num_segments = control_points.size() - 3
	var samples_per_segment = num_samples / num_segments

	for seg in range(num_segments):
		var p0 = control_points[seg]
		var p1 = control_points[seg + 1]
		var p2 = control_points[seg + 2]
		var p3 = control_points[seg + 3]

		var segment_samples = samples_per_segment
		if seg == num_segments - 1:
			segment_samples += 1

		for i in range(segment_samples):
			var t = float(i) / float(samples_per_segment)
			var point = catmull_rom_point(p0, p1, p2, p3, t)
			sampled.append(point)

	return sampled

func catmull_rom_point(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 = t * t
	var t3 = t2 * t

	var result = Vector3.ZERO
	result += p0 * (-0.5 * t3 + t2 - 0.5 * t)
	result += p1 * (1.5 * t3 - 2.5 * t2 + 1.0)
	result += p2 * (-1.5 * t3 + 2.0 * t2 + 0.5 * t)
	result += p3 * (0.5 * t3 - 0.5 * t2)

	result.y = 0.02
	return result

func create_path_mesh(path_node: Node3D):
	if path_points.size() < 2:
		return

	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var material = StandardMaterial3D.new()
	material.albedo_color = path_color
	material.roughness = 1.0
	surface_tool.set_material(material)

	for i in range(path_points.size() - 1):
		var p1 = path_points[i]
		var p2 = path_points[i + 1]

		var direction = (p2 - p1).normalized()
		var perp = Vector3(-direction.z, 0, direction.x) * (path_width / 2.0)

		var v1 = p1 + perp
		var v2 = p1 - perp
		var v3 = p2 + perp
		var v4 = p2 - perp

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
	for i in range(path_points.size() - 1):
		var dist = point_to_segment_distance(pos, path_points[i], path_points[i + 1])
		if dist < min_distance:
			return true
	return false

func point_to_segment_distance(point: Vector3, seg_start: Vector3, seg_end: Vector3) -> float:
	var p = Vector2(point.x, point.z)
	var a = Vector2(seg_start.x, seg_start.z)
	var b = Vector2(seg_end.x, seg_end.z)

	var ab = b - a
	var ap = p - a

	var len_sq = ab.length_squared()
	if len_sq < 0.0001:
		return p.distance_to(a)

	var t = clamp(ap.dot(ab) / len_sq, 0.0, 1.0)
	var closest = a + ab * t
	return p.distance_to(closest)

func get_path_progress(pos: Vector3) -> float:
	if path_points.size() < 2:
		return 0.0

	var best_idx = 0
	var best_dist = INF

	for i in range(path_points.size()):
		var wp = path_points[i]
		var dist = Vector2(pos.x - wp.x, pos.z - wp.z).length()
		if dist < best_dist:
			best_dist = dist
			best_idx = i

	return float(best_idx) / float(path_points.size() - 1)

func create_redwood_trees():
	var rng = RandomNumberGenerator.new()
	rng.seed = current_seed + 2000  # Different seed offset for trees

	var placed_trees = 0
	var attempts = 0
	var max_attempts = tree_count * 5

	# Minimum distance from path (path_width + tree trunk radius + buffer)
	var min_path_distance = path_width + 1.5

	while placed_trees < tree_count and attempts < max_attempts:
		attempts += 1

		# Random position within terrain bounds
		var half = terrain_size / 2.0 - 3.0  # Keep away from edges
		var pos = Vector3(
			rng.randf_range(-half, half),
			0,
			rng.randf_range(-half, half)
		)

		# Skip if too close to path
		if is_point_near_path(pos, min_path_distance):
			continue

		# Create the redwood tree
		create_redwood(pos, rng)
		placed_trees += 1

	print("Placed ", placed_trees, " redwood trees")

func create_redwood(pos: Vector3, rng: RandomNumberGenerator):
	var tree = Node3D.new()
	tree.name = "Redwood"
	tree.position = pos

	# Redwood size variation (scaled for 50m world)
	var scale_factor = rng.randf_range(0.8, 1.4)
	var trunk_height = 8.0 * scale_factor  # Tall trunk
	var trunk_radius_base = 0.4 * scale_factor
	var trunk_radius_top = 0.25 * scale_factor

	# Create trunk (tapered cylinder)
	var trunk = MeshInstance3D.new()
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.bottom_radius = trunk_radius_base
	trunk_mesh.top_radius = trunk_radius_top
	trunk_mesh.height = trunk_height
	trunk_mesh.radial_segments = 12
	trunk.mesh = trunk_mesh
	trunk.position.y = trunk_height / 2.0

	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = bark_color.lerp(bark_color_dark, rng.randf_range(0.0, 0.5))
	trunk_mat.roughness = 0.95
	trunk.material_override = trunk_mat
	tree.add_child(trunk)

	# Redwood foliage - multiple cone-shaped layers
	var foliage_start = trunk_height * 0.4  # Foliage starts partway up
	var num_foliage_layers = rng.randi_range(4, 6)

	for i in range(num_foliage_layers):
		var layer_t = float(i) / float(num_foliage_layers - 1)
		var layer_height = foliage_start + (trunk_height - foliage_start) * layer_t

		# Foliage gets smaller toward top
		var foliage_radius = (2.0 - layer_t * 1.2) * scale_factor
		var foliage_height = 1.5 * scale_factor

		var foliage = MeshInstance3D.new()
		var foliage_mesh = CylinderMesh.new()
		foliage_mesh.bottom_radius = foliage_radius
		foliage_mesh.top_radius = foliage_radius * 0.3
		foliage_mesh.height = foliage_height
		foliage_mesh.radial_segments = 8
		foliage.mesh = foliage_mesh
		foliage.position.y = layer_height

		var foliage_mat = StandardMaterial3D.new()
		foliage_mat.albedo_color = foliage_color.lerp(foliage_color_light, rng.randf_range(0.0, 0.4))
		foliage_mat.roughness = 0.85
		foliage.material_override = foliage_mat
		tree.add_child(foliage)

	# Add collision for trunk (so robot can't drive through)
	var collision_body = StaticBody3D.new()
	var collision_shape = CollisionShape3D.new()
	var cylinder_shape = CylinderShape3D.new()
	cylinder_shape.radius = trunk_radius_base
	cylinder_shape.height = trunk_height
	collision_shape.shape = cylinder_shape
	collision_shape.position.y = trunk_height / 2.0
	collision_body.add_child(collision_shape)
	tree.add_child(collision_body)

	add_child(tree)
