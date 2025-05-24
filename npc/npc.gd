# NPC.gd
extends CharacterBody2D

@export var wander_speed := 35.0  # Speed when wandering in patrol area
@export var chase_speed := 70.0  # Speed when chasing player
@export var return_speed := 120.0  # Speed when returning to patrol area
@export var detection_range := 100.0
@export var chase_range := 200.0
@export var wander_time := 3.0
@export var sprite_frames: SpriteFrames  # Sprite frames resource to load
@export var patrol_navigation_region: NavigationRegion2D  # Small patrol area
@export var global_navigation_region: NavigationRegion2D  # Whole map for pathfinding
@export var npc_type: String = "npc"
@export var area2d: Area2D  # Area2D node for detecting players

var _players_node: Node
var _closest_player: Node
var _wander_target := Vector2.ZERO
var _return_target := Vector2.ZERO
var _timer := 0.0
var _is_chasing := false
var _is_returning := false

# Navigation agent for pathfinding
@onready var _navigation_agent: NavigationAgent2D = $NavigationAgent2D

func _ready() -> void:
	if sprite_frames:
		$AnimatedSprite2D.sprite_frames = sprite_frames
	
	call_deferred("_find_players_node")
	call_deferred("_find_navigation_regions")
	$AnimatedSprite2D.play("walk")
	_navigation_agent.navigation_layers |= patrol_navigation_region.navigation_layers
	_navigation_agent.navigation_layers &= ~global_navigation_region.navigation_layers

func _find_navigation_regions() -> void:
	if not patrol_navigation_region:
		push_error("NPC couldn't find patrol NavigationRegion2D")
	if not global_navigation_region:
		push_error("NPC couldn't find whole map NavigationRegion2D")

func _find_players_node() -> void:
	_players_node = get_tree().get_root().get_node("Demo1").find_child("Players", true, false)
	if not _players_node:
		push_error("NPC couldn't find Players node")

func _process(delta: float) -> void:
	position = position.clamp(Vector2.ZERO, Vector2(2080, 1408))
	_find_closest_player()

func _physics_process(delta: float) -> void:
	if not _closest_player:
		if _is_returning:
			return_to_patrol_area(delta)
		else:
			wander_in_area(delta)
		return

	var distance_to_player = global_position.distance_to(_closest_player.global_position)
	
	# Start chasing if player is close
	if (distance_to_player < detection_range) and !_is_returning:
		if not _is_chasing:
			_start_chase()
		_is_returning = false
	
	# Stop chasing if player is too far or we're too far from home
	if _is_chasing and (distance_to_player > chase_range):
		_is_chasing = false
		_is_returning = true
		_start_return_to_patrol()
	
	if _is_chasing:
		chase_player(delta)
	elif _is_returning:
		return_to_patrol_area(delta)
	else:
		wander_in_area(delta)

func _find_closest_player() -> void:
	if not _players_node or _players_node.get_child_count() == 0:
		_closest_player = null
		return
		
	var min_distance := INF
	_closest_player = null
	
	for player in _players_node.get_children():
		var distance = global_position.distance_to(player.global_position)
		if distance < min_distance:
			min_distance = distance
			_closest_player = player

func _start_chase() -> void:
	_is_chasing = true
	print("Setting to global nav layer: ", _navigation_agent.navigation_layers)
	_navigation_agent.navigation_layers &= ~patrol_navigation_region.navigation_layers
	_navigation_agent.navigation_layers |= global_navigation_region.navigation_layers
	
	# # Disable patrol navigation region during chase
	# if patrol_navigation_region:
	# 		patrol_navigation_region.enabled = false
	# 		print("Disabled patrol navigation region for chase")
	
	# # Set navigation agent to use whole map navigation for chasing
	# if global_navigation_region:
	# 		_navigation_agent.set_navigation_map(global_navigation_region.get_navigation_map())

func chase_player(delta: float) -> void:
	if not _closest_player:
		return
	
	# Update target to player's current position
	_navigation_agent.target_position = _closest_player.global_position
	
	# Follow navigation path to player
	if _navigation_agent.is_navigation_finished():
		return
	
	var next_path_position = _navigation_agent.get_next_path_position()
	var direction = (next_path_position - global_position).normalized()
	velocity = direction * chase_speed
	if velocity.x != 0:
		$AnimatedSprite2D.flip_h = velocity.x >= 0
	move_and_slide()

func _start_return_to_patrol() -> void:
	# Re-enable patrol navigation region
	# if patrol_navigation_region:
	# 				patrol_navigation_region.enabled = true
	# 				print("Re-enabled patrol navigation region for return")
	
	# # Set navigation agent to use whole map navigation
	# if global_navigation_region:
	# 				_navigation_agent.set_navigation_map(global_navigation_region.get_navigation_map())
	_return_target = NavigationServer2D.region_get_closest_point(patrol_navigation_region, global_position)
	_navigation_agent.target_position = _return_target

func return_to_patrol_area(delta: float) -> void:
	if _navigation_agent.is_navigation_finished():
			_is_returning = false
			_timer = 0.0
			print("Setting to patrol nav layer: ", _navigation_agent.navigation_layers)
			_navigation_agent.navigation_layers &= ~global_navigation_region.navigation_layers
			_navigation_agent.navigation_layers |= patrol_navigation_region.navigation_layers
			return
	
	var next_path_position = _navigation_agent.get_next_path_position()
	var direction = (next_path_position - global_position).normalized()
	velocity = direction * return_speed
	if velocity.x != 0:
			$AnimatedSprite2D.flip_h = velocity.x >= 0

	move_and_slide()

func wander_in_area(delta: float) -> void:
	_timer -= delta
	
	# Pick a new wander target if timer is up or we've reached our target
	if _timer <= 0.0 or _navigation_agent.is_navigation_finished() or global_position.distance_to(_wander_target) < 2.0:
			await get_tree().process_frame
			_wander_target = NavigationServer2D.map_get_random_point(
				patrol_navigation_region.get_navigation_map(),
				patrol_navigation_region.navigation_layers,
				false
			)
			_navigation_agent.target_position = _wander_target
			_timer = wander_time
	
	# Use navigation agent for pathfinding within patrol area
	if not _navigation_agent.is_navigation_finished():
			var next_path_position = _navigation_agent.get_next_path_position()
			var direction = (next_path_position - global_position).normalized()
			velocity = direction * wander_speed
			if velocity.x != 0:
					$AnimatedSprite2D.flip_h = velocity.x >= 0

			move_and_slide()
