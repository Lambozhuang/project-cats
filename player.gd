# Player.gd
extends CharacterBody2D

var canCarry = true

@export var speed := 200.0
@export var synced_position := Vector2()

@onready var inputs: Node = $Inputs

func _ready() -> void:
	position = synced_position
	if str(name).is_valid_int():
		$"Inputs/InputsSync".set_multiplayer_authority(str(name).to_int())
	
	$AnimatedSprite2D.animation = "idle"
	$AnimatedSprite2D.play()

func _process(delta: float) -> void:
	position = position.clamp(Vector2.ZERO, Vector2(1152, 648))
	if velocity.x != 0 || velocity.y != 0:
		$AnimatedSprite2D.animation = "walk"
		$AnimatedSprite2D.flip_h = velocity.x > 0
	else:
		$AnimatedSprite2D.animation = "idle"

func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null or str(multiplayer.get_unique_id()) == str(name):
		# The client which this player represent will update the controls state, and notify it to everyone.
		inputs.update()

	if multiplayer.multiplayer_peer == null or is_multiplayer_authority():
		# The server updates the position that will be notified to the clients.
		synced_position = position
	else:
		# The client simply updates the position to the last known one.
		position = synced_position
		
	velocity = inputs.motion * speed
	move_and_slide()

@rpc("call_local")
func set_player_name(value: String) -> void:
	$Label.text = value
	# Assign a random color to the player based on its name.
	$Label.modulate = gamestate.get_player_color(value)
	#$sprite.modulate = Color(0.5, 0.5, 0.5) + gamestate.get_player_color(value)
