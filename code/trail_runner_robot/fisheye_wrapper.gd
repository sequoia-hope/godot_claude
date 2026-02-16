extends Node
## Fisheye Effect Wrapper - Runtime scene restructuring for post-processing
##
## This autoload wraps the main scene in a SubViewportContainer to enable
## proper fisheye post-processing without double-rendering artifacts.
##
## How it works:
## 1. On _ready(), finds the main scene root
## 2. Creates a SubViewportContainer with fisheye shader
## 3. Creates a SubViewport inside it
## 4. Reparents all scene content into the SubViewport
## 5. The fisheye shader is applied to the SubViewportContainer

@export var distortion_strength: float = 0.4
@export var vignette_strength: float = 0.3

var viewport_container: SubViewportContainer
var sub_viewport: SubViewport
var shader_material: ShaderMaterial

func _ready():
	# Wait for scene to be fully loaded
	await get_tree().process_frame

	_setup_fisheye_wrapper()

func _setup_fisheye_wrapper():
	var root = get_tree().root

	# Find the main scene (first child of root that isn't an autoload)
	var main_scene: Node = null
	for child in root.get_children():
		# Skip autoloads (they have names starting with @ or are in the autoload list)
		if not child.name.begins_with("@") and child != self and not _is_autoload(child):
			main_scene = child
			break

	if not main_scene:
		push_error("FisheyeWrapper: Could not find main scene to wrap")
		return

	print("FisheyeWrapper: Wrapping scene '", main_scene.name, "' with fisheye effect")

	# Load the fisheye shader
	var shader = load("res://fisheye.gdshader")
	if not shader:
		push_error("FisheyeWrapper: Could not load fisheye.gdshader")
		return

	# Create shader material
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("distortion_strength", distortion_strength)
	shader_material.set_shader_parameter("vignette_strength", vignette_strength)

	# Get viewport size
	var viewport_size = get_viewport().get_visible_rect().size

	# Create SubViewportContainer
	viewport_container = SubViewportContainer.new()
	viewport_container.name = "FisheyeViewportContainer"
	viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	viewport_container.material = shader_material

	# Create SubViewport
	sub_viewport = SubViewport.new()
	sub_viewport.name = "FisheyeSubViewport"
	sub_viewport.handle_input_locally = false
	sub_viewport.size = Vector2i(viewport_size)
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	# Add viewport to container
	viewport_container.add_child(sub_viewport)

	# Remove main scene from root temporarily
	root.remove_child(main_scene)

	# Add main scene to SubViewport
	sub_viewport.add_child(main_scene)

	# Add container to root
	root.add_child(viewport_container)

	# Move container to be first child (behind autoloads)
	root.move_child(viewport_container, 0)

	print("FisheyeWrapper: Scene wrapped successfully")

func _is_autoload(node: Node) -> bool:
	# Check if this node is an autoload by comparing with known autoload names
	var autoload_names = ["FisheyeWrapper", "RLEnv", "TestRunner", "DebugScreenshot"]
	return node.name in autoload_names

func set_distortion(strength: float):
	distortion_strength = strength
	if shader_material:
		shader_material.set_shader_parameter("distortion_strength", strength)

func set_vignette(strength: float):
	vignette_strength = strength
	if shader_material:
		shader_material.set_shader_parameter("vignette_strength", strength)
