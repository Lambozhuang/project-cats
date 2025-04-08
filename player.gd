# Player.gd
extends CharacterBody2D

@export var speed := 200.0  # Movement speed

func _physics_process(delta: float) -> void:
	var input_vector = Vector2.ZERO

	# Basic WASD or Arrow Key movement
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

	# Normalize so diagonal movement isn't faster
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()

	# MoveAndSlide-like method in Godot 4 => move_and_slide() is replaced by move_and_collide() or velocity approach
	velocity = input_vector * speed
	move_and_slide()
