# Godot 4.x Gotchas and Best Practices

This document captures common issues encountered when generating Godot 4.x code and their solutions.

## Class Renames (Godot 3 → 4)

| Godot 3 | Godot 4 | Notes |
|---------|---------|-------|
| `Spatial` | `Node3D` | |
| `KinematicBody` | `CharacterBody3D` | |
| `RigidBody` | `RigidBody3D` | |
| `Area` | `Area3D` | |
| `Camera` | `Camera3D` | |
| `MeshInstance` | `MeshInstance3D` | |
| `CollisionShape` | `CollisionShape3D` | |
| `SpatialMaterial` | `StandardMaterial3D` | |
| `DirectionalLight` | `DirectionalLight3D` | |
| `OmniLight` | `OmniLight3D` | |
| `SpotLight` | `SpotLight3D` | |
| `Position3D` | `Marker3D` | |
| `Particles` | `GPUParticles3D` | |
| `ProceduralSky` | `ProceduralSkyMaterial` + `Sky` | |

## Non-Existent Classes

### ❌ `ConeMesh` Does NOT Exist!

```gdscript
# WRONG - ConeMesh doesn't exist in Godot 4
var cone = ConeMesh.new()

# CORRECT - Use CylinderMesh with top_radius=0
var cone = CylinderMesh.new()
cone.top_radius = 0.0
cone.bottom_radius = 1.0
cone.height = 2.0
```

## Procedural Mesh Best Practices

### Material Application with SurfaceTool

**Problem**: Meshes created with `SurfaceTool` may not show material when using `material_override`.

**Solution**: Call `set_material()` BEFORE adding vertices:

```gdscript
# CORRECT - Material applied reliably
var st = SurfaceTool.new()
st.begin(Mesh.PRIMITIVE_TRIANGLES)

var mat = StandardMaterial3D.new()
mat.albedo_color = Color(0.8, 0.7, 0.5)
st.set_material(mat)  # BEFORE add_vertex!

st.add_vertex(Vector3(0, 0, 0))
st.add_vertex(Vector3(1, 0, 0))
st.add_vertex(Vector3(0, 0, 1))

var mesh_instance = MeshInstance3D.new()
mesh_instance.mesh = st.commit()
```

```gdscript
# UNRELIABLE - May not work
var st = SurfaceTool.new()
st.begin(Mesh.PRIMITIVE_TRIANGLES)
# ... add vertices ...
var mesh_instance = MeshInstance3D.new()
mesh_instance.mesh = st.commit()
mesh_instance.material_override = mat  # May not apply!
```

### Z-Fighting with Ground Planes

**Problem**: Mesh rendered on or near ground plane causes z-fighting (flickering).

**Solution**: Offset mesh slightly above ground:

```gdscript
# Set Y position above ground (0.02-0.05 works well)
vertex.y = 0.03
```

### Vertex Winding Order

**Problem**: Mesh faces appear invisible (backface culling).

**Solution**: Ensure counter-clockwise winding when viewed from desired side:

```gdscript
# For a quad viewed from above (+Y), vertices should be:
#   v1 ---- v3
#   |       |
#   v2 ---- v4
#
# Triangle 1: v1, v2, v3 (counter-clockwise from above)
# Triangle 2: v2, v4, v3 (counter-clockwise from above)

st.add_vertex(v1)
st.add_vertex(v2)
st.add_vertex(v3)

st.add_vertex(v2)
st.add_vertex(v4)
st.add_vertex(v3)
```

## Camera Setup

### Camera Not Rendering

**Problem**: Camera3D exists but scene shows nothing.

**Solutions**:
1. Set `current = true` on the Camera3D
2. Ensure camera is positioned to see scene content
3. Check camera FOV (90° is good for first-person)

```gdscript
# In .tscn file
[node name="Camera3D" type="Camera3D" parent="Player"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.5, 0)
current = true
fov = 90.0
```

### Camera Can't See Ground/Path

**Problem**: First-person camera looks straight ahead, can't see ground.

**Solution**: Tilt camera down slightly:

```gdscript
# Rotation matrix for 15° downward tilt around X axis
# cos(15°) ≈ 0.966, sin(15°) ≈ 0.259
transform = Transform3D(1, 0, 0, 0, 0.966, 0.259, 0, -0.259, 0.966, 0, 0.35, -0.2)
```

## project.godot Configuration

### Autoload Section Format

**CORRECT**:
```ini
[autoload]

MyAutoload="*res://my_autoload.gd"

[rendering]
```

**WRONG** (entry outside section):
```ini
[input]
...

MyAutoload="*res://my_autoload.gd"

[rendering]
```

### Required Sections

Every project.godot should have:
- `[application]` - with `run/main_scene`
- `[display]` - viewport settings

## GDScript Syntax Changes

### Signals

```gdscript
# Godot 3
signal_name.connect(self, "_on_signal")

# Godot 4
signal_name.connect(_on_signal)
```

### Export Variables

```gdscript
# Godot 3
export var speed = 5.0

# Godot 4
@export var speed: float = 5.0
```

### Onready Variables

```gdscript
# Godot 3
onready var player = $Player

# Godot 4
@onready var player: Node = $Player
```

### Yield/Await

```gdscript
# Godot 3
yield(get_tree().create_timer(1.0), "timeout")

# Godot 4
await get_tree().create_timer(1.0).timeout
```

### Instance/Instantiate

```gdscript
# Godot 3
var instance = scene.instance()

# Godot 4
var instance = scene.instantiate()
```

## Validation

Run the validator on your build:

```bash
python scripts/godot_validator.py ./code/my_build
```

This will check for:
- Removed/renamed classes
- GDScript syntax issues
- SurfaceTool usage
- Scene configuration problems
- project.godot structure
