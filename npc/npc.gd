# NPC.gd
extends CharacterBody2D

@export var wander_speed := 35.0  # Speed when wandering in patrol area
@export var chase_speed := 70.0  # Speed when chasing player
@export var return_speed := 120.0  # Speed when returning to patrol area
@export var detection_range := 100.0
@export var chase_range := 200.0
@export var attack_range := 30.0  # Range to start attacking
@export var attack_hit_range := 40.0  # Range to check for successful hit
@export var attack_duration := 2.0  # How long the attack animation lasts
@export var wander_time := 3.0
@export var sprite_frames: SpriteFrames  # Sprite frames resource to load
@export var patrol_navigation_region: NavigationRegion2D  # Small patrol area
@export var global_navigation_region: NavigationRegion2D  # Whole map for pathfinding
@export var npc_type: String = "npc"
@export var area2d: Area2D  # Area2D node for detecting players

# Synced variables for multiplayer
@export var synced_position := Vector2()
@export var synced_flip_h := false
@export var synced_animation := "walk"
@export var synced_state := "wander"  # "wander", "chase", "return", "attack"

var _players_node: Node
var _closest_player: Node
var _wander_target := Vector2.ZERO
var _return_target := Vector2.ZERO
var _timer := 0.0
var _is_chasing := false
var _is_returning := false
var _is_attacking := false
var _attack_timer := 0.0
var _attack_target: Node  # Player we're attacking
var _was_chasing := false

# Navigation agent for pathfinding
@onready var _navigation_agent: NavigationAgent2D = $NavigationAgent2D

func get_demo_scene() -> Node:
	return get_tree().get_root().get_node("Demo1")


func _ready() -> void:
	if sprite_frames:
		$AnimatedSprite2D.sprite_frames = sprite_frames
	
	call_deferred("_find_players_node")
	call_deferred("_find_navigation_regions")
	$AnimatedSprite2D.play("walk")
	_navigation_agent.navigation_layers |= patrol_navigation_region.navigation_layers
	_navigation_agent.navigation_layers &= ~global_navigation_region.navigation_layers
	
	# Connect to animation finished signal
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	
	# Initialize synced position
	synced_position = global_position

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
	# Only server handles logic and position clamping
	if multiplayer.is_server():
		position = position.clamp(Vector2.ZERO, Vector2(2080, 1408))
		_find_closest_player()
		synced_position = global_position
	else:
		# Clients smoothly interpolate to synced position
		global_position = global_position.lerp(synced_position, delta * 10.0)
	
	# All clients update visual state
	$AnimatedSprite2D.flip_h = synced_flip_h
	if $AnimatedSprite2D.animation != synced_animation:
		$AnimatedSprite2D.play(synced_animation)

func _physics_process(delta: float) -> void:
	# Only server handles movement logic
	if not multiplayer.is_server():
		return
		
	# Handle attack timing
	if _is_attacking:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_stop_attack()
		return  # Don't move while attacking
	
	if not _closest_player:
		if _is_returning:
			return_to_patrol_area(delta)
		else:
			wander_in_area(delta)
		return

	var distance_to_player = global_position.distance_to(_closest_player.global_position)
	
	# Check if close enough to attack
	if _is_chasing and distance_to_player <= attack_range:
		_start_attack()
		return
	
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
		if _was_chasing:
			$ChasingBgm.stop()
			_was_chasing = false
		var demo_scene = get_demo_scene()
		if demo_scene:
			demo_scene.isRegularBgmPlaying = true
	
	if _is_chasing:
		chase_player(delta)
		var demo_scene = get_demo_scene()
		if demo_scene:
			demo_scene.isRegularBgmPlaying = false
		if not _was_chasing:
			$ChasingBgm.play()
			_was_chasing = true
		
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
		# Skip locked up players
		if player.has_method("set_locked_up") and player.is_locked_up:
			continue
			
		var distance = global_position.distance_to(player.global_position)
		if distance < min_distance:
			min_distance = distance
			_closest_player = player

func _start_chase() -> void:
	_is_chasing = true
	synced_state = "chase"
	print("Setting to global nav layer: ", _navigation_agent.navigation_layers)
	_navigation_agent.navigation_layers &= ~patrol_navigation_region.navigation_layers
	_navigation_agent.navigation_layers |= global_navigation_region.navigation_layers
	

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
		synced_flip_h = velocity.x >= 0
	move_and_slide()

func _start_attack() -> void:
	_is_attacking = true
	_attack_timer = attack_duration
	_attack_target = _closest_player  # Store the target we're attacking
	velocity = Vector2.ZERO  # Stop moving
	synced_state = "attack"
	
	# Face the player
	if _closest_player:
		var direction_to_player = _closest_player.global_position - global_position
		synced_flip_h = direction_to_player.x >= 0
	
	# Sync attack animation
	synced_animation = "attack"
	print("NPC attacking!")

func _stop_attack() -> void:
	_is_attacking = false
	_attack_target = null
	synced_state = "wander"
	# Return to walking animation
	synced_animation = "walk"

func _on_animation_finished() -> void:
	# Only server handles attack logic
	if not multiplayer.is_server():
		return
		
	# Only check for hit when attack animation finishes
	print("Animation finished: ", $AnimatedSprite2D.animation)
	if $AnimatedSprite2D.animation == "attack" and _is_attacking and _attack_target:
		_check_attack_hit()

func _check_attack_hit() -> void:
	if not _attack_target:
		return
	
	var distance_to_target = global_position.distance_to(_attack_target.global_position)
	print("Attack target: ", _attack_target.name, " at distance: ", distance_to_target)
	if distance_to_target <= attack_hit_range:
		_on_attack_hit(_attack_target)
	else:
		_on_attack_miss(_attack_target)

func _on_attack_hit(target: Node) -> void:
	print("Attack HIT! Target: ", target.name, " at distance: ", global_position.distance_to(target.global_position))
	# Sync attack hit to all clients
	# attack_hit.rpc(target.name)

	# Call knockout on the target player
	if target.has_method("set_knocked_out"):
		target.set_knocked_out.rpc()

	var demo_scene = get_tree().get_root().get_node("Demo1")
	if demo_scene and demo_scene.has_method("handle_npc_attack"):
		demo_scene.handle_npc_attack(npc_type, target.name.to_int())
	else:
		push_error("Demo scene does not have handle_npc_attack method")

func _on_attack_miss(target: Node) -> void:
	print("Attack MISSED! Target: ", target.name, " at distance: ", global_position.distance_to(target.global_position))
	# Sync attack miss to all clients
	# attack_miss.rpc(target.name)

# @rpc("authority", "call_local")
# func attack_hit(target_name: String) -> void:
# 	print("Attack HIT synced! Target: ", target_name)

# @rpc("authority", "call_local") 
# func attack_miss(target_name: String) -> void:
# 	print("Attack MISSED synced! Target: ", target_name)

func _start_return_to_patrol() -> void:
	synced_state = "return"
	_return_target = NavigationServer2D.region_get_closest_point(patrol_navigation_region, global_position)
	_navigation_agent.target_position = _return_target

func return_to_patrol_area(delta: float) -> void:
	if _navigation_agent.is_navigation_finished():
			_is_returning = false
			_timer = 0.0
			synced_state = "wander"
			print("Setting to patrol nav layer: ", _navigation_agent.navigation_layers)
			_navigation_agent.navigation_layers &= ~global_navigation_region.navigation_layers
			_navigation_agent.navigation_layers |= patrol_navigation_region.navigation_layers
			return
	
	var next_path_position = _navigation_agent.get_next_path_position()
	var direction = (next_path_position - global_position).normalized()
	velocity = direction * return_speed
	if velocity.x != 0:
			synced_flip_h = velocity.x >= 0

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
					synced_flip_h = velocity.x >= 0

			move_and_slide()
