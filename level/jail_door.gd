extends StaticBody2D

@export var is_open: bool = false
@onready var sprite = $Sprite2D
@onready var collision = $CollisionShape2D
@onready var detection_area = $Area2D

var players_in_range: Array[int] = []

func _ready():
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	update_door_state()

func _on_body_entered(body):
	if body.is_in_group("player") or body.has_method("set_locked_up"):
		var player_id = int(str(body.name))
		if not players_in_range.has(player_id):
			players_in_range.append(player_id)
		
		# Check if this is a locked up player passing through an open door
		if is_open and body.is_locked_up:
			print("Player ", player_id, " is being released from jail")
			body.set_locked_up.rpc(false)

func _on_body_exited(body):
	if body.is_in_group("player") or body.has_method("set_locked_up"):
		var player_id = int(str(body.name))
		players_in_range.erase(player_id)

func _input(event):
	if event.is_action_pressed("interact"):
		try_open_door()

func try_open_door():
	# Check if any non-locked player is in range
	for player_id in players_in_range:
		var player = get_node("../../Players/" + str(player_id))
		if player and not player.is_locked_up:
			if player_id == multiplayer.get_unique_id() or multiplayer.multiplayer_peer == null:
				open_door.rpc()
				return

@rpc("any_peer", "call_local")
func open_door():
	if not is_open:
		is_open = true
		update_door_state()
		print("Jail door opened!")
		
		# Optionally close the door after some time
		var close_timer = Timer.new()
		close_timer.wait_time = 10.0  # Door stays open for 10 seconds
		close_timer.one_shot = true
		add_child(close_timer)
		close_timer.start()
		close_timer.timeout.connect(func():
			close_door.rpc()
			close_timer.queue_free()
		)

@rpc("any_peer", "call_local")
func close_door():
	is_open = false
	update_door_state()
	print("Jail door closed!")

func update_door_state():
	if is_open:
		# Make door passable
		collision.disabled = true
		sprite.texture = ResourceCache.jail_door["open"]
	else:
		# Make door solid
		collision.disabled = false
		sprite.texture = ResourceCache.jail_door["closed"]
