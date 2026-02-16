extends Node
class_name TrackProgress
## Abstract interface for track/path progress providers
##
## Implementations should provide methods to track agent progress
## along a predefined path or toward a goal.

## Override this to return normalized progress [0.0, 1.0]
## 0.0 = start, 1.0 = finished
func get_progress() -> float:
	push_error("TrackProgress.get_progress() not implemented")
	return 0.0

## Override this to check if agent is on/near the track
func is_on_track() -> bool:
	push_error("TrackProgress.is_on_track() not implemented")
	return true

## Override this to return distance to nearest track point
func get_distance_to_track() -> float:
	push_error("TrackProgress.get_distance_to_track() not implemented")
	return 0.0

## Override this to reset progress tracking for new episode
func reset_progress():
	push_error("TrackProgress.reset_progress() not implemented")

## Override to return the start position for episode reset
func get_start_position() -> Vector3:
	push_error("TrackProgress.get_start_position() not implemented")
	return Vector3.ZERO

## Override to return the start rotation for episode reset
func get_start_rotation() -> Vector3:
	push_error("TrackProgress.get_start_rotation() not implemented")
	return Vector3.ZERO
