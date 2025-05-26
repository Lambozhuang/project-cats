# Player.gd
extends CharacterBody2D

var is_carrying_item = false 
var carried_item: Node = null
var is_locked_up = false  # New state to track if player is locked up

@export var speed := 140.0
@export var synced_position := Vector2()
@export var synced_locked_up := false  # Synced version for multiplayer

@onready var inputs: Node = $Inputs

func _ready() -> void:
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
	
	# Sync locked up state from server
	if not multiplayer.is_server():
		is_locked_up = synced_locked_up
	
	# Don't update animations if locked up
	if is_locked_up:
		$AnimatedSprite2D.animation = "idle"
		$AnimatedSprite2D.modulate = Color.GRAY  # Visual indication of being locked up
		return
	else:
		$AnimatedSprite2D.modulate = Color.WHITE
	
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
	else:
		position = synced_position
		
	velocity = inputs.motion * speed
	move_and_slide()
	
	# Handle carry logic
	if multiplayer.multiplayer_peer == null or str(multiplayer.get_unique_id()) == str(name):
		if inputs.carry_pressed:
			try_to_carry_item()
		elif inputs.carry_released:
			try_to_release_item()

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

func try_to_carry_item() -> void:
	if is_carrying_item or is_locked_up:
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
	if is_locked_up:
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
