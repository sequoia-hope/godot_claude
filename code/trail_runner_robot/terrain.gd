extends Node3D
## Procedural Terrain Generator
## Creates: winding path, patchy grass ground, redwood trees

signal world_generated(seed_value: int, start_pos: Vector3, start_dir: Vector3)

const WORLD_SIZE: float = 50.0
const PATH_WIDTH: float = 0.8
const TREE_COUNT: int = 25
const TREE_MIN_DISTANCE_FROM_PATH: float = 2.0

var current_seed: int = 0
var path_points: Array[Vector3] = []
var path_start: Vector3
var path_end: Vector3

var ground_mesh: MeshInstance3D
var path_mesh: MeshInstance3D
var trees_container: Node3D

func _ready() -> void:
	generate_new_world()

func generate_new_world(new_seed: int = -1) -> void:
	if new_seed < 0:
		randomize()
		current_seed = randi()
	else:
		current_seed = new_seed
	seed(current_seed)

	_clear_world()
	_generate_path()
	_generate_ground()
	_generate_trees()

	print("Generated world with seed: ", current_seed)
	world_generated.emit(current_seed, path_start, (path_points[1] - path_points[0]).normalized())

func _clear_world() -> void:
	for child in get_children():
		child.queue_free()
	path_points.clear()

func _generate_path() -> void:
	# Generate control points for Catmull-Rom spline
	var half := WORLD_SIZE / 2.0 - 2.0
	path_start = Vector3(-half, 0.02, half)  # Bottom-left corner (in Godot coords)
	path_end = Vector3(half, 0.02, -half)    # Top-right corner

	var control_points: Array[Vector3] = [path_start]
	var num_controls := randi_range(8, 12)

	for i in range(1, num_controls - 1):
		var t := float(i) / float(num_controls - 1)
		var base_pos := path_start.lerp(path_end, t)
		# Add random perpendicular offset
		var perp := Vector3(path_end.z - path_start.z, 0, path_start.x - path_end.x).normalized()
		var offset := perp * randf_range(-8.0, 8.0)
		var point := base_pos + offset
		# Clamp to world bounds
		point.x = clamp(point.x, -half + 2, half - 2)
		point.z = clamp(point.z, -half + 2, half - 2)
		point.y = 0.02
		control_points.append(point)

	control_points.append(path_end)

	# Generate smooth path using Catmull-Rom
	path_points = _catmull_rom_chain(control_points, 5)

	# Create path mesh
	_create_path_mesh()

func _catmull_rom_chain(points: Array[Vector3], segments_per_curve: int) -> Array[Vector3]:
	var result: Array[Vector3] = []

	for i in range(points.size() - 1):
		var p0 := points[max(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[min(i + 1, points.size() - 1)]
		var p3 := points[min(i + 2, points.size() - 1)]

		for j in range(segments_per_curve):
			var t := float(j) / float(segments_per_curve)
			result.append(_catmull_rom(p0, p1, p2, p3, t))

	result.append(points[points.size() - 1])
	return result

func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		2.0 * p1 +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

func _create_path_mesh() -> void:
	if path_points.size() < 2:
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Material - tan/sand color for dirt path
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.76, 0.70, 0.50)
	mat.roughness = 1.0
	st.set_material(mat)

	for i in range(path_points.size() - 1):
		var p1 := path_points[i]
		var p2 := path_points[i + 1]

		var direction := (p2 - p1).normalized()
		var perp := Vector3(-direction.z, 0, direction.x) * (PATH_WIDTH / 2.0)

		# Match working version vertex order
		var v1 := p1 + perp
		var v2 := p1 - perp
		var v3 := p2 + perp
		var v4 := p2 - perp

		# Ensure above ground
		v1.y = 0.03
		v2.y = 0.03
		v3.y = 0.03
		v4.y = 0.03

		# Two triangles for quad (same winding as working version)
		st.add_vertex(v1)
		st.add_vertex(v2)
		st.add_vertex(v3)

		st.add_vertex(v2)
		st.add_vertex(v4)
		st.add_vertex(v3)

	path_mesh = MeshInstance3D.new()
	path_mesh.mesh = st.commit()
	path_mesh.name = "Path"

	add_child(path_mesh)

func _generate_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(WORLD_SIZE, WORLD_SIZE)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1

	ground_mesh = MeshInstance3D.new()
	ground_mesh.mesh = plane
	ground_mesh.name = "Ground"

	# Create patchy grass shader material
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = _create_grass_shader()
	shader_mat.set_shader_parameter("seed_offset", float(current_seed % 1000))
	ground_mesh.material_override = shader_mat

	add_child(ground_mesh)

	# Add collision
	var static_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WORLD_SIZE, 0.1, WORLD_SIZE)
	collision.shape = shape
	collision.position.y = -0.05
	static_body.add_child(collision)
	ground_mesh.add_child(static_body)

func _create_grass_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;

uniform float seed_offset = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p + seed_offset, vec2(127.1, 311.7))) * 43758.5453);
}

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * 15.0;
	float n = fbm(uv);

	vec3 green1 = vec3(0.2, 0.5, 0.15);
	vec3 green2 = vec3(0.3, 0.6, 0.2);
	vec3 blue_green = vec3(0.15, 0.4, 0.35);

	vec3 color = mix(green1, green2, n);
	float blue_mask = fbm(uv * 0.5 + 100.0);
	color = mix(color, blue_green, smoothstep(0.4, 0.6, blue_mask) * 0.5);

	ALBEDO = color;
	ROUGHNESS = 0.85;
}
"""
	return shader

func _generate_trees() -> void:
	trees_container = Node3D.new()
	trees_container.name = "Trees"
	add_child(trees_container)

	var placed := 0
	var attempts := 0
	var max_attempts := TREE_COUNT * 20
	var half := WORLD_SIZE / 2.0 - 3.0

	while placed < TREE_COUNT and attempts < max_attempts:
		attempts += 1
		var pos := Vector3(
			randf_range(-half, half),
			0,
			randf_range(-half, half)
		)

		if not is_point_near_path(pos, TREE_MIN_DISTANCE_FROM_PATH):
			_create_redwood_tree(pos)
			placed += 1

	print("Placed ", placed, " redwood trees")

func _create_redwood_tree(pos: Vector3) -> void:
	var tree := Node3D.new()
	tree.position = pos

	# Random size variation
	var height := randf_range(8.0, 14.0)
	var trunk_radius := randf_range(0.3, 0.5)

	# Trunk
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = trunk_radius * 0.7
	trunk_mesh.bottom_radius = trunk_radius
	trunk_mesh.height = height * 0.6

	var trunk := MeshInstance3D.new()
	trunk.mesh = trunk_mesh
	trunk.position.y = height * 0.3

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.4, 0.25, 0.15)
	trunk_mat.roughness = 0.9
	trunk.material_override = trunk_mat
	tree.add_child(trunk)

	# Foliage layers
	var foliage_mat := StandardMaterial3D.new()
	foliage_mat.albedo_color = Color(0.1, 0.35, 0.15)
	foliage_mat.roughness = 0.8

	var num_layers := 4
	for i in range(num_layers):
		var layer_height := height * (0.4 + float(i) * 0.15)
		var layer_radius := (height * 0.25) * (1.0 - float(i) * 0.2)

		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = layer_radius
		cone.height = height * 0.25

		var foliage := MeshInstance3D.new()
		foliage.mesh = cone
		foliage.position.y = layer_height
		foliage.material_override = foliage_mat
		tree.add_child(foliage)

	trees_container.add_child(tree)

func is_point_near_path(point: Vector3, tolerance: float) -> bool:
	for path_point in path_points:
		var dist := Vector2(point.x, point.z).distance_to(Vector2(path_point.x, path_point.z))
		if dist < tolerance:
			return true
	return false

func get_nearest_path_index(point: Vector3) -> int:
	var min_dist := INF
	var min_idx := 0
	for i in range(path_points.size()):
		var dist := Vector2(point.x, point.z).distance_to(Vector2(path_points[i].x, path_points[i].z))
		if dist < min_dist:
			min_dist = dist
			min_idx = i
	return min_idx

func get_path_progress(point: Vector3) -> float:
	var idx := get_nearest_path_index(point)
	return float(idx) / float(max(path_points.size() - 1, 1))
