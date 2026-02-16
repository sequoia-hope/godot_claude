# Godot 4.x Common Gotchas

This document lists common issues when generating Godot 4.x code and how to fix them.

## Removed/Renamed Classes

| Old (Godot 3.x) | New (Godot 4.x) |
|-----------------|-----------------|
| `ConeMesh` | `CylinderMesh` with `top_radius = 0` |
| `SpatialMaterial` | `StandardMaterial3D` |
| `Spatial` | `Node3D` |
| `KinematicBody` | `CharacterBody3D` |
| `RigidBody` | `RigidBody3D` |
| `Camera` | `Camera3D` |
| `MeshInstance` | `MeshInstance3D` |
| `CollisionShape` | `CollisionShape3D` |
| `DirectionalLight` | `DirectionalLight3D` |
| `Position3D` | `Marker3D` |
| `Particles` | `GPUParticles3D` |

## SurfaceTool Material Application

**Problem**: Procedural meshes render without material (black or invisible).

**Solution**: Call `set_material()` BEFORE adding vertices:

```gdscript
var st = SurfaceTool.new()
st.begin(Mesh.PRIMITIVE_TRIANGLES)

# CORRECT: Set material first
var mat = StandardMaterial3D.new()
mat.albedo_color = Color(0.8, 0.6, 0.4)
st.set_material(mat)  # <-- Before add_vertex!

st.add_vertex(Vector3(0, 0, 0))
st.add_vertex(Vector3(1, 0, 0))
# ...
mesh.mesh = st.commit()
```

## Wheel Orientation and Rotation

**Problem**: Wheels rotate on wrong axis or don't spin correctly.

**Key Insight - CylinderMesh Geometry:**
- CylinderMesh **local Y axis** = cylinder height = **wheel axle**
- The axle is what the wheel spins around

**Physics Rules** - Wheel axle must be:
1. **Perpendicular to direction of travel** - so wheel rolls forward, not sideways
2. **Parallel to the floor** - so wheel stays upright

**For a vehicle facing -Z (Godot default forward):**
- Axle must be along **world X axis** (left-right)
- Need a transform that maps **local Y → world X**

**Correct Setup in .tscn:**
```
# Transform that rotates local Y to world X (90° around Z)
# Left wheels: local Y → world +X
transform = Transform3D(0, -1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0)

# Right wheels: local Y → world -X
transform = Transform3D(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 0, 0)
```

**Correct Spin Animation:**
```gdscript
# Use rotate_object_local to spin around the cylinder's local Y (the axle)
func _animate_wheels(delta: float):
    var spin_delta = speed / wheel_radius * delta

    # Left wheels
    wheel_mesh_left.rotate_object_local(Vector3.UP, spin_delta)

    # Right wheels (opposite direction since axle points opposite way)
    wheel_mesh_right.rotate_object_local(Vector3.UP, -spin_delta)
```

**Common Mistakes:**
```gdscript
# WRONG - Euler angles compose incorrectly with existing transform
mesh.rotation.x = wheel_spin  # Doesn't spin around the axle!
mesh.rotation.y = wheel_spin  # Also wrong!

# WRONG - Using wrong transform (rotates around Y, not Z)
transform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, ...)  # Local Y still points up!

# CORRECT - Use rotate_object_local for the cylinder's local Y axis
mesh.rotate_object_local(Vector3.UP, spin_delta)
```

**Validator checks:**
- Warns if `.rotation.x/y/z = spin` in wheel-related code
- Recommends `rotate_object_local(Vector3.UP, delta)` instead

## Starting Direction Alignment

**Problem**: Player starts facing wrong direction (perpendicular to track/path).

**Godot Rotation Reference** (rotation.y values):
- `0` = Facing -Z (default forward)
- `-PI/2` = Facing +X
- `PI` = Facing +Z
- `PI/2` = Facing -X

**Solution**: Set `get_start_rotation()` based on track direction at start point:

```gdscript
func get_start_rotation() -> float:
    # If track runs along X axis at start, face +X
    return -PI / 2.0  # NOT 0.0

func get_start_position() -> Vector3:
    # Position on the track, facing direction of travel
    return Vector3(-5, 0.5, -25)  # Slightly before start line
```

**Validation**: The validator checks for `get_start_rotation() -> float: return 0.0` in files with track/path code and warns about potential misalignment.

## Type Inference Strict Mode

**Problem**: Docker/CI builds fail with "Warning treated as error" for type inference.

**Cause**: Using `:=` for variable declaration can cause Variant inference warnings in strict mode.

**Solution**: Either use explicit types or disable strict warnings:

```gdscript
# Option 1: Explicit types
var speed: float = 5.0
var name: String = "Player"

# Option 2: Add to project.godot [debug] section
[debug]
gdscript/warnings/inferred_declaration=false
gdscript/warnings/unsafe_property_access=false
```

## Z-Fighting on Ground Surfaces

**Problem**: Track/path flickers against ground plane.

**Solution**: Offset surfaces slightly above ground:

```gdscript
# Ground at y = 0
# Track surface at y = 0.02
# Kerbs/markings at y = 0.03
# Start line at y = 0.04
```

## Camera Setup

**Problem**: Camera not active, scene appears frozen or from wrong angle.

**Solution**: Ensure Camera3D has `current = true`:

```gdscript
# In code
camera.current = true

# In .tscn
[node name="Camera3D" type="Camera3D"]
current = true
```

## Scene Lighting

**Problem**: Scene is completely dark.

**Solution**: Add at least one light source:

```gdscript
var light = DirectionalLight3D.new()
light.rotation_degrees = Vector3(-45, -45, 0)
add_child(light)
```

Or use WorldEnvironment with ambient light.
