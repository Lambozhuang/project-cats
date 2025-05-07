# Player.gd
extends CharacterBody2D

var canCarry = true
var carried_item: Node = null

@export var speed := 150.0
@export var synced_position := Vector2()

@onready var inputs: Node = $Inputs

func _ready() -> void:
	position = synced_position
	if str(name).is_valid_int():
		print(str(name).to_int())
		$"Inputs/InputsSync".set_multiplayer_authority(str(name).to_int())
		if multiplayer.get_unique_id() == str(name).to_int():
			$Camera2D.make_current()
	
	$AnimatedSprite2D.animation = "idle"
	$AnimatedSprite2D.play()

func _process(delta: float) -> void:
	position = position.clamp(Vector2.ZERO, Vector2(1152, 648))
	if velocity.x != 0:
		$AnimatedSprite2D.flip_h = velocity.x > 0
		$AnimatedSprite2D.animation = "walk"
	elif velocity.y != 0:
		$AnimatedSprite2D.animation = "walk"
	else:
		$AnimatedSprite2D.animation = "idle"

func _physics_process(delta: float) -> void:
	if multiplayer.get_unique_id() != 1:
			print(is_multiplayer_authority())
	if multiplayer.multiplayer_peer == null or str(multiplayer.get_unique_id()) == str(name):
		# The client which this player represent will update the controls state, and notify it to everyone.
		inputs.update()

	if multiplayer.multiplayer_peer == null or is_multiplayer_authority():
		if multiplayer.get_unique_id() != 1:
			print("s->p")
		# The server updates the position that will be notified to the clients.
		synced_position = position
	else:
		if multiplayer.get_unique_id() != 1:
			print("p->s")
		# The client simply updates the position to the last known one.
		position = synced_position
		
	velocity = inputs.motion * speed
	move_and_slide()
	
		# Handle carry logic
	if multiplayer.multiplayer_peer == null or str(multiplayer.get_unique_id()) == str(name):
		if inputs.carry_pressed:
			try_to_carry_item()
		elif inputs.carry_released:
			try_to_release_item()

func try_to_carry_item() -> void:
	if not canCarry:
		return
	print("try to carry")
	for body in $CarryDetector.get_overlapping_areas():
		print(body)
		if body.has_method("request_carry"):
			body.request_carry.rpc(multiplayer.get_unique_id())
			carried_item = body
			canCarry = false
			break

func try_to_release_item() -> void:
	print("try to release")
	if carried_item:
		carried_item.request_release.rpc()
		carried_item = null
		canCarry = true

@rpc("call_local")
func set_player_name(value: String) -> void:
	print("lol")
	print(multiplayer.get_unique_id())
	$Label.text = value
	# Assign a random color to the player based on its name.
	$Label.modulate = gamestate.get_player_color(value)
	#$sprite.modulate = Color(0.5, 0.5, 0.5) + gamestate.get_player_color(value)
