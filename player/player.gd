# Player.gd
extends CharacterBody2D

var is_carrying_item = false 
var carried_item: Node = null
var is_locked_up = false  # New state to track if player is locked up
var is_knocked_out = false  # New state for knockout animation
var is_knockout_immune = false  # Immunity after being knocked out

@export var speed := 140.0
@export var knockout_duration := 2.0  # How long the knockout lasts
@export var knockout_cooldown := 3.0  # Immunity period after knockout
@export var synced_position := Vector2()
@export var synced_locked_up := false  # Synced version for multiplayer
@export var synced_knocked_out := false  # Synced knockout state
@export var synced_knockout_immune := false  # Synced immunity state

@onready var inputs: Node = $Inputs
var knockout_timer := 0.0
var immunity_timer := 0.0

func _ready() -> void:
	# Add player to a group for easy identification
	add_to_group("player")
	
	position = synced_position
	if str(name).is_valid_int():
		print("Player instance name: ", str(name).to_int())
		$"Inputs/InputsSync".set_multiplayer_authority(str(name).to_int())
		if multiplayer.get_unique_id() == str(name).to_int():
			$Camera2D.make_current()
	
	$AnimatedSprite2D.animation = "idle"
	$AnimatedSprite2D.play()

func _process(delta: float) -> void:
	position = position.clamp(Vector2.ZERO, Vector2(2080, 1408))
	
	# Sync states from server
	if not multiplayer.is_server():
		is_locked_up = synced_locked_up
		is_knocked_out = synced_knocked_out
		is_knockout_immune = synced_knockout_immune
	
	# Handle knockout timer
	if is_knocked_out:
		knockout_timer -= delta
		if knockout_timer <= 0.0 and multiplayer.is_server():
			_end_knockout()
	
	# Handle immunity timer
	if is_knockout_immune:
		immunity_timer -= delta
		if immunity_timer <= 0.0 and multiplayer.is_server():
			_end_immunity()
	
	# Visual effects for different states
	if is_knocked_out:
		return  # Skip animation updates while knocked out
	elif is_locked_up:
		$AnimatedSprite2D.modulate = Color.GRAY  # Visual indication of being locked up
	else:
		$AnimatedSprite2D.modulate = Color.WHITE
	
	# Normal animation logic (only if not knocked out)
	if velocity.x != 0:
		$AnimatedSprite2D.flip_h = velocity.x > 0
		if is_carrying_item:
			$AnimatedSprite2D.animation = "walk_hold"
		else:
			$AnimatedSprite2D.animation = "walk"
	elif velocity.y != 0:
		if is_carrying_item:
			$AnimatedSprite2D.animation = "walk_hold"
		else:
			$AnimatedSprite2D.animation = "walk"
	else:
		if is_carrying_item:
			$AnimatedSprite2D.animation = "hold"
		else:
			$AnimatedSprite2D.animation = "idle"

func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null or str(multiplayer.get_unique_id()) == str(name):
		inputs.update()

	if multiplayer.multiplayer_peer == null or is_multiplayer_authority():
		synced_position = position
		synced_locked_up = is_locked_up  # Sync locked up state
		synced_knocked_out = is_knocked_out  # Sync knockout state
		synced_knockout_immune = is_knockout_immune  # Sync immunity state
	else:
		position = synced_position
		
	# Don't allow movement if knocked out
	if is_knocked_out:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Allow movement even when locked up (they can move within jail)
	velocity = inputs.motion * speed
	move_and_slide()
	
	# Handle carry logic - only if not locked up and not knocked out
	if not is_locked_up and not is_knocked_out and (multiplayer.multiplayer_peer == null or str(multiplayer.get_unique_id()) == str(name)):
		if inputs.carry_pressed:
			try_to_carry_item()
		elif inputs.carry_released:
			try_to_release_item()

@rpc("authority", "call_local")
func set_knocked_out() -> void:
	if is_knocked_out or is_knockout_immune:
		print("Player ", name, " is immune to knockout!")
		return  # Already knocked out or immune
	
	is_knocked_out = true
	synced_knocked_out = true
	knockout_timer = knockout_duration
	
	# Drop any carried item when knocked out
	if is_carrying_item and carried_item:
		carried_item.request_release.rpc()
		carried_item = null
		is_carrying_item = false
	
	# Play knockout animation
	$AnimatedSprite2D.animation = "knockout"
	$AnimatedSprite2D.play()
	print("Player ", name, " has been knocked out!")

func _end_knockout() -> void:
	is_knocked_out = false
	synced_knocked_out = false
	knockout_timer = 0.0
	
	# Start immunity period
	is_knockout_immune = true
	synced_knockout_immune = true
	immunity_timer = knockout_cooldown
	
	print("Player ", name, " has recovered from knockout and is now immune for ", knockout_cooldown, " seconds")

func _end_immunity() -> void:
	is_knockout_immune = false
	synced_knockout_immune = false
	immunity_timer = 0.0
	print("Player ", name, " is no longer immune to knockout")

@rpc("authority", "call_local")
func set_locked_up(locked: bool) -> void:
	is_locked_up = locked
	synced_locked_up = locked
	if locked:
		# Drop any carried item when locked up
		if is_carrying_item and carried_item:
			carried_item.request_release.rpc()
			carried_item = null
			is_carrying_item = false
		print("Player ", name, " is now locked up")
	else:
		print("Player ", name, " has been released from jail")

func try_to_carry_item() -> void:
	if is_carrying_item or is_locked_up or is_knocked_out:
		return
	print("try to carry")
	for body in $CarryDetector.get_overlapping_areas():
		if body.has_method("request_carry"):
			body.request_carry.rpc(multiplayer.get_unique_id())
			carried_item = body
			is_carrying_item = true
			$PickingUpSfx.play()
			break

func try_to_release_item() -> void:
	if is_locked_up or is_knocked_out:
		return
	print("try to release")
	if carried_item:
		carried_item.request_release.rpc()
		carried_item = null
		is_carrying_item = false

@rpc("call_local")
func set_player_name_and_sprite(value: String, peer_id: int, cat: String) -> void:
	$Label.text = value
	$Label.modulate = GameState.get_player_color(value)
	print("Player cat: ", GameState.player_cat)
	$AnimatedSprite2D.sprite_frames = ResourceCache.player_sprites[cat]
	$AnimatedSprite2D.play()
