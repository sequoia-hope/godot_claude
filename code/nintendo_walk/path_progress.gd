extends TrackProgress
## Path-following progress provider for nintendo_walk terrain
##
## Uses terrain.gd's path_points array to track progress along the trail.

var terrain: Node3D = null
var player: CharacterBody3D = null
var off_track_tolerance: float = 3.0

# Cached values
var _last_waypoint_index: int = 0
var _total_waypoints: int = 0
var _path_start: Vector3 = Vector3.ZERO
var _path_direction: Vector3 = Vector3.FORWARD

func _ready():
	# Find terrain node
	terrain = _find_terrain()
	if terrain:
		print("PathProgress: Found terrain at ", terrain.get_path())
		# Connect to world_generated signal if available
		if terrain.has_signal("world_generated"):
			terrain.world_generated.connect(_on_world_generated)
		_cache_path_info()
	else:
		push_warning("PathProgress: No terrain node found")

	# Find player node
	player = _find_player()
	if player:
		print("PathProgress: Found player at ", player.get_path())
	else:
		push_warning("PathProgress: No player node found")

func _find_terrain() -> Node3D:
	# Try common paths
	var paths = [
		"/root/Main/Terrain",
		"/root/Main/terrain",
		"/root/Game/Terrain",
		"/root/Terrain"
	]
	for path in paths:
		var node = get_node_or_null(path)
		if node and node.has_method("is_point_near_path"):
			return node

	# Search recursively for node with path_points
	return _find_terrain_recursive(get_tree().root)

func _find_terrain_recursive(node: Node) -> Node3D:
	if node is Node3D and node.get("path_points") != null:
		return node
	for child in node.get_children():
		var result = _find_terrain_recursive(child)
		if result:
			return result
	return null

func _find_player() -> CharacterBody3D:
	var paths = [
		"/root/Main/Player",
		"/root/Game/Player",
		"/root/Player"
	]
	for path in paths:
		var node = get_node_or_null(path)
		if node is CharacterBody3D:
			return node

	# Recursive search
	return _find_player_recursive(get_tree().root)

func _find_player_recursive(node: Node) -> CharacterBody3D:
	if node is CharacterBody3D:
		return node
	for child in node.get_children():
		var result = _find_player_recursive(child)
		if result:
			return result
	return null

func _on_world_generated(seed_value: int, start: Vector3, direction: Vector3):
	print("PathProgress: World regenerated with seed ", seed_value)
	_cache_path_info()

func _cache_path_info():
	if not terrain:
		return

	var path_points = terrain.get("path_points")
	if path_points:
		_total_waypoints = path_points.size()
		if _total_waypoints > 0:
			_path_start = path_points[0]
		if _total_waypoints > 1:
			_path_direction = (path_points[1] - path_points[0]).normalized()
			_path_direction.y = 0

	_last_waypoint_index = 0
	print("PathProgress: Cached ", _total_waypoints, " waypoints")

func get_progress() -> float:
	if not player or not terrain or _total_waypoints < 2:
		return 0.0

	var path_points = terrain.get("path_points")
	if not path_points or path_points.size() < 2:
		return 0.0

	var player_pos = player.global_position

	# Find nearest waypoint (search forward from last known position for efficiency)
	var best_idx = _last_waypoint_index
	var best_dist = INF

	# Search window around last known position
	var search_start = max(0, _last_waypoint_index - 5)
	var search_end = min(_total_waypoints, _last_waypoint_index + 20)

	for i in range(search_start, search_end):
		var wp = path_points[i]
		var dist = Vector2(player_pos.x - wp.x, player_pos.z - wp.z).length()
		if dist < best_dist:
			best_dist = dist
			best_idx = i

	# Also check if we've made it to a much later waypoint (large jumps)
	for i in range(search_end, _total_waypoints):
		var wp = path_points[i]
		var dist = Vector2(player_pos.x - wp.x, player_pos.z - wp.z).length()
		if dist < off_track_tolerance:
			if i > best_idx:
				best_idx = i
				best_dist = dist

	_last_waypoint_index = best_idx

	# Return normalized progress
	return float(best_idx) / float(_total_waypoints - 1)

func is_on_track() -> bool:
	if not player or not terrain:
		return true  # Assume on track if we can't check

	if terrain.has_method("is_point_near_path"):
		return terrain.is_point_near_path(player.global_position, off_track_tolerance)

	# Fallback: check distance to nearest waypoint
	return get_distance_to_track() <= off_track_tolerance

func get_distance_to_track() -> float:
	if not player or not terrain:
		return 0.0

	var path_points = terrain.get("path_points")
	if not path_points or path_points.size() < 2:
		return 0.0

	var player_pos = player.global_position
	var min_dist = INF

	# Check distance to line segments, not just waypoints
	for i in range(path_points.size() - 1):
		var a = path_points[i]
		var b = path_points[i + 1]
		var dist = _point_to_segment_distance(player_pos, a, b)
		min_dist = min(min_dist, dist)

	return min_dist

func _point_to_segment_distance(point: Vector3, seg_a: Vector3, seg_b: Vector3) -> float:
	# 2D distance in XZ plane
	var p = Vector2(point.x, point.z)
	var a = Vector2(seg_a.x, seg_a.z)
	var b = Vector2(seg_b.x, seg_b.z)

	var ab = b - a
	var ap = p - a

	var len_sq = ab.length_squared()
	if len_sq < 0.0001:
		return p.distance_to(a)

	var t = clamp(ap.dot(ab) / len_sq, 0.0, 1.0)
	var closest = a + ab * t
	return p.distance_to(closest)

func reset_progress():
	_last_waypoint_index = 0

func get_start_position() -> Vector3:
	if terrain:
		var path_start = terrain.get("path_start")
		if path_start:
			# Slightly above ground
			return Vector3(path_start.x, 0.5, path_start.z)
	return Vector3.ZERO

func get_start_rotation() -> Vector3:
	if terrain and _total_waypoints >= 2:
		var path_points = terrain.get("path_points")
		var dir = (path_points[1] - path_points[0]).normalized()
		dir.y = 0
		# Calculate Y rotation to face along path
		var angle = atan2(dir.x, dir.z)
		return Vector3(0, angle, 0)
	return Vector3.ZERO
