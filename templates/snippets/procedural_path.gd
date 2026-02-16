## Procedural Path Mesh Generator
## Known-good implementation for creating path/trail meshes in Godot 4.x
##
## Usage:
##   var path_mesh = create_path_mesh(path_points, width, color)
##   add_child(path_mesh)

## Creates a mesh following a series of points with specified width and color.
## This implementation is tested and handles:
## - Proper material application via SurfaceTool.set_material()
## - Correct vertex winding for visible faces
## - Y position above ground to avoid z-fighting
##
## Args:
##   points: Array[Vector3] - ordered list of path points
##   width: float - path width in meters
##   color: Color - path material color
##   y_offset: float - height above ground (default 0.03 to avoid z-fighting)
##
## Returns:
##   MeshInstance3D with the path mesh
static func create_path_mesh(
	points: Array[Vector3],
	width: float = 0.8,
	color: Color = Color(0.76, 0.70, 0.50),
	y_offset: float = 0.03
) -> MeshInstance3D:
	if points.size() < 2:
		push_error("create_path_mesh requires at least 2 points")
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# IMPORTANT: Set material BEFORE adding vertices
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	st.set_material(mat)

	var half_width := width / 2.0

	for i in range(points.size() - 1):
		var p1 := points[i]
		var p2 := points[i + 1]

		# Calculate perpendicular direction
		var direction := (p2 - p1).normalized()
		var perp := Vector3(-direction.z, 0, direction.x) * half_width

		# Create quad vertices (order matters for face culling!)
		var v1 := p1 + perp
		var v2 := p1 - perp
		var v3 := p2 + perp
		var v4 := p2 - perp

		# Set Y position above ground
		v1.y = y_offset
		v2.y = y_offset
		v3.y = y_offset
		v4.y = y_offset

		# Two triangles forming a quad
		# Winding order: counter-clockwise when viewed from above
		st.add_vertex(v1)
		st.add_vertex(v2)
		st.add_vertex(v3)

		st.add_vertex(v2)
		st.add_vertex(v4)
		st.add_vertex(v3)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = st.commit()
	mesh_instance.name = "PathMesh"

	return mesh_instance


## Creates smooth path points using Catmull-Rom spline interpolation.
##
## Args:
##   control_points: Array[Vector3] - control points to interpolate
##   segments_per_curve: int - smoothness (more = smoother, default 5)
##
## Returns:
##   Array[Vector3] of interpolated points
static func create_smooth_path(
	control_points: Array[Vector3],
	segments_per_curve: int = 5
) -> Array[Vector3]:
	var result: Array[Vector3] = []

	for i in range(control_points.size() - 1):
		var p0 := control_points[max(i - 1, 0)]
		var p1 := control_points[i]
		var p2 := control_points[min(i + 1, control_points.size() - 1)]
		var p3 := control_points[min(i + 2, control_points.size() - 1)]

		for j in range(segments_per_curve):
			var t := float(j) / float(segments_per_curve)
			result.append(_catmull_rom(p0, p1, p2, p3, t))

	result.append(control_points[control_points.size() - 1])
	return result


static func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		2.0 * p1 +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)
