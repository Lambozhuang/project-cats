extends Area2D

var isCarried = false
var carrier_id: int = -1  # ID of the player carrying the item, -1 if none

@export var item_type: String = "fish"
@export var sprite_frames: SpriteFrames

@export var synced_position := Vector2()

func _ready() -> void:
	synced_position = position

	if sprite_frames == null:
		sprite_frames = preload("res://item/items/fish.tres")

	if $AnimatedSprite2D and sprite_frames:
		$AnimatedSprite2D.frames = sprite_frames
		$AnimatedSprite2D.play()
	else:
		print("AnimatedSprite2D or sprite_frames not found")

func _physics_process(delta: float) -> void:
	if isCarried:
		$AnimatedSprite2D.stop()
		var player = get_tree().get_root().get_node("Demo1/Players").get_node(str(carrier_id))
		if player:
			var attach_point = player.get_node("Marker2D").global_position
			
			# Get appropriate offset based on player's facing direction
			var offset = get_offset_based_on_facing(player)
			
			# Only the server updates synced_position
			if multiplayer.is_server():
				synced_position = attach_point + offset
			
			# All peers update their local position
			self.position = attach_point + offset
	else:
		$AnimatedSprite2D.play()
		# On clients, follow the synced position from the server
		if not multiplayer.is_server():
			self.position = synced_position

# Get appropriate offset based on player's facing direction
func get_offset_based_on_facing(player) -> Vector2:
	# Default offset (when player is idle or facing down)
	var offset = Vector2(0, -5)
	
	if not player.get_node("AnimatedSprite2D").flip_h:
		# Item on left side
		offset = Vector2(-5, -5)
	# Player is facing left
	else:
		# Item on right side
		offset = Vector2(5, -5)
		
	return offset


# Client calls this to request a carry
@rpc("any_peer", "call_local")
func request_carry(player_id: int) -> void:
	print("request carry item")
	if not isCarried and multiplayer.is_server():
		# Only server fulfills the request
		carry.rpc(player_id)

# Server authoritative carry execution
@rpc("authority", "call_local")
func carry(player_id: int) -> void:
	print("item carry")
	isCarried = true
	carrier_id = player_id
	print("Item carried by player", player_id)

# Client calls this to request a release
@rpc("any_peer", "call_local")
func request_release() -> void:
	if isCarried and multiplayer.is_server():
		# Only server fulfills the request
		release.rpc()

# Server authoritative release execution
@rpc("authority", "call_local")
func release() -> void:
	print("item release")
	if isCarried:
		var player = get_tree().get_root().get_node("Demo1/Players").get_node(str(carrier_id))
		if player:
			# Drop item just slightly below the attach point (simulates dropping)
			var drop_point = player.get_node("Marker2D").global_position
			var drop_offset = Vector2(0, 0)  # Adjust as needed
			synced_position = drop_point + drop_offset
			self.position = synced_position
		
		isCarried = false
		carrier_id = -1

		# Check if dropped in the collection area
		var overlapping_areas = get_overlapping_areas()
		for area in overlapping_areas:
			print("Item dropped in area: ", area.name)
			if area.name == "CollectionArea":
				print(item_type)
