# Player.gd
extends CharacterBody2D

@export var speed := 200.0

func _physics_process(delta: float) -> void:
	var input_vector = Vector2.ZERO

	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	# Normalize so diagonal movement doesn’t exceed speed
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()

	# Apply movement
	velocity = input_vector * speed
	move_and_slide()
