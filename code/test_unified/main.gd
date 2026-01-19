extends Node3D
## Main scene controller

func _ready():
	print("Game initialized")

	# Capture mouse for first-person control
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	# Release mouse on escape
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
