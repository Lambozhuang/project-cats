# Villain.gd
extends CharacterBody2D

@export var speed := 80.0
@export var detection_range := 100.0  # how close the player must be to trigger chase
@export var wander_time := 2.0       # how long to keep wandering in one direction

var _players_node: Node
var _closest_player: Node
var _wander_direction := Vector2.ZERO
var _timer := 0.0

func _ready() -> void:
	# Schedule finding players node for after the scene is fully loaded
	call_deferred("_find_players_node")
	
func _find_players_node() -> void:
	# Look for the Players node that contains all player instances
	_players_node = get_tree().get_root().get_node("Demo1").find_child("Players", true, false)
	if not _players_node:
		push_error("Villain couldn't find Players node")
	
func _process(delta: float) -> void:
	position = position.clamp(Vector2.ZERO, Vector2(1920, 1080))
	
	# Find the closest player each frame
	_find_closest_player()

func _physics_process(delta: float) -> void:
	if not _closest_player:
		wander_around(delta)
		return

	# If the closest player is within detection range, chase
	var distance_to_player = global_position.distance_to(_closest_player.global_position)
	if distance_to_player < detection_range:
		chase_player(delta)
	else:
		wander_around(delta)

func _find_closest_player() -> void:
	if not _players_node or _players_node.get_child_count() == 0:
		_closest_player = null
		return
		
	var min_distance := INF
	_closest_player = null
	
	# Loop through all players and find the closest one
	for player in _players_node.get_children():
		var distance = global_position.distance_to(player.global_position)
		if distance < min_distance:
			min_distance = distance
			_closest_player = player

func chase_player(delta: float) -> void:
	var direction = (_closest_player.global_position - global_position).normalized()
	velocity = direction * speed
	if velocity.x != 0:
		$Sprite2D.flip_h = velocity.x < 0
	move_and_slide()

func wander_around(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		# Pick a new random direction to wander
		var angle = randf() * TAU  # TAU is 2*PI
		_wander_direction = Vector2(cos(angle), sin(angle))
		_timer = wander_time

	velocity = _wander_direction * (speed * 0.5)  # maybe wander slower
	if velocity.x != 0:
		$Sprite2D.flip_h = velocity.x < 0
	move_and_slide()
