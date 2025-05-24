extends Node

@export var motion := Vector2():
	set(value):
		motion = clamp(value, Vector2(-1, -1), Vector2(1, 1))

var carry_pressed := false
var carry_released := false

func update() -> void:
	var m := Vector2()
	if Input.is_action_pressed("move_left"):
		m += Vector2(-1, 0)
	if Input.is_action_pressed("move_right"):
		m += Vector2(1, 0)
	if Input.is_action_pressed("move_up"):
		m += Vector2(0, -1)
	if Input.is_action_pressed("move_down"):
		m += Vector2(0, 1)
	
	if m.length() > 1:
		m = m.normalized()
	motion = m

	# Capture carry input state
	carry_pressed = Input.is_action_just_pressed("carry")
	carry_released = Input.is_action_just_released("carry")
