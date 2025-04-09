# Villain.gd
extends CharacterBody2D

@export var speed := 100.0
@export var detection_range := 200.0  # how close the player must be to trigger chase
@export var wander_time := 2.0       # how long to keep wandering in one direction

var _player
var _wander_direction := Vector2.ZERO
var _timer := 0.0

func _ready() -> void:
	# Optionally find Player if you load everything into the same scene
	# and instance them all under the same parent
	# If the Player is instanced at runtime, you can store a reference via signals or
	# pass it from the outside
	_player = get_tree().get_root().find_child("Player", true, false)

func _physics_process(delta: float) -> void:
	if not _player:
		return

	# If the player is within detection range, chase
	var distance_to_player = global_position.distance_to(_player.global_position)
	if distance_to_player < detection_range:
		chase_player(delta)
	else:
		wander_around(delta)

func chase_player(delta: float) -> void:
	var direction = (_player.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

func wander_around(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		# Pick a new random direction to wander
		# anywhere in a circle (random angle)
		var angle = randf() * TAU  # TAU is 2*PI
		_wander_direction = Vector2(cos(angle), sin(angle))
		_timer = wander_time

	velocity = _wander_direction * (speed * 0.5)  # maybe wander slower
	move_and_slide()
