extends Node

@export var motion := Vector2():
	set(value):
		# This will be sent by players, make sure values are within limits.
		motion = clamp(value, Vector2(-1, -1), Vector2(1, 1))

func update() -> void:
	var m := Vector2()
	if Input.is_action_pressed(&"move_left"):
		m += Vector2(-1, 0)
	if Input.is_action_pressed(&"move_right"):
		m += Vector2(1, 0)
	if Input.is_action_pressed(&"move_up"):
		m += Vector2(0, -1)
	if Input.is_action_pressed(&"move_down"):
		m += Vector2(0, 1)
		
	# Normalize the motion to ensure consistent speed
	if m.length() > 1:
		m = m.normalized()

	motion = m
