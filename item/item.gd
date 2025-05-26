# item.gd
extends Area2D

var isCarried = false
var carrier_ids: Array[int] = []  # Array to hold multiple carrier IDs
var max_carriers: int = 1  # Default to single carrier

@export var item_type: String = "fish"
@export var sprite_frames: SpriteFrames
@export var requires_two_carriers: bool = false  # Mark items that need two carriers

@export var synced_position := Vector2()

# Define which item types require two carriers
const TWO_CARRIER_ITEMS = ["heavy_box", "piano", "couch"]  # Add your item types here

func _ready() -> void:
	synced_position = position

	# Set max carriers based on item type
	if item_type in TWO_CARRIER_ITEMS or requires_two_carriers:
		max_carriers = 2

	if sprite_frames == null:
		sprite_frames = preload("res://item/items/fish.tres")

	if $AnimatedSprite2D and sprite_frames:
		$AnimatedSprite2D.frames = sprite_frames
		$AnimatedSprite2D.play()
	else:
		print("AnimatedSprite2D or sprite_frames not found")

func _physics_process(delta: float) -> void:
	# For items that require two carriers, only move when both carriers are present
	var can_move = true
	if requires_two_carriers and carrier_ids.size() < 2:
		can_move = false
	
	if isCarried and carrier_ids.size() > 0 and can_move:
		$AnimatedSprite2D.stop()
		
		# Calculate position based on carrier(s)
		var target_position = calculate_carried_position()
		
		# Only the server updates synced_position
		if multiplayer.is_server():
			synced_position = target_position
		
		# All peers update their local position
		self.position = target_position
	else:
		$AnimatedSprite2D.play()
		# On clients, follow the synced position from the server
		if not multiplayer.is_server():
			self.position = synced_position

# Calculate position when carried by one or more players
func calculate_carried_position() -> Vector2:
	if carrier_ids.size() == 0:
		return position
		
	var players_node = get_tree().get_root().get_node("Demo1/Players")
	
	if carrier_ids.size() == 1:
		# Single carrier - use existing logic
		var player = players_node.get_node(str(carrier_ids[0]))
		if player:
			var attach_point = player.get_node("Marker2D").global_position
			var offset = get_offset_based_on_facing(player)
			return attach_point + offset
	else:
		# Multiple carriers - position between them
		var total_position = Vector2()
		var valid_carriers = 0
		
		for carrier_id in carrier_ids:
			var player = players_node.get_node(str(carrier_id))
			if player:
				total_position += player.get_node("Marker2D").global_position
				valid_carriers += 1
		
		if valid_carriers > 0:
			return total_position / valid_carriers + Vector2(0, -10)  # Slight offset above
	
	return position

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
	if multiplayer.is_server():
		# Check if item can be carried
		if can_be_carried_by(player_id):
			carry.rpc(player_id)
		else:
			print("Cannot carry item - requirements not met")

# Check if item can be carried by the player
func can_be_carried_by(player_id: int) -> bool:
	# If player is already carrying, don't allow
	if player_id in carrier_ids:
		return false
	
	# For items that require two carriers
	if requires_two_carriers:
		# Only allow carrying if we have space for another carrier
		if carrier_ids.size() < 2:
			return true
		else:
			return false  # Already at capacity
	
	# For regular items (single or optional two carriers)
	if max_carriers == 2 and carrier_ids.size() < 2:
		return true
	elif max_carriers == 1 and carrier_ids.size() == 0:
		return true
	
	return false

# Server authoritative carry execution
@rpc("authority", "call_local")
func carry(player_id: int) -> void:
	print("item carry by player", player_id)
	
	if player_id not in carrier_ids:
		carrier_ids.append(player_id)
	
	# For items that require two carriers, only mark as carried when both are present
	if requires_two_carriers:
		isCarried = (carrier_ids.size() == 2)
	else:
		# For regular items, carried with at least one carrier
		isCarried = (carrier_ids.size() > 0)
	
	print("Item carried by players: ", carrier_ids, " - isCarried: ", isCarried)

# Client calls this to request a release
@rpc("any_peer", "call_local")
func request_release(player_id: int) -> void:
	if player_id in carrier_ids and multiplayer.is_server():
		# Only server fulfills the request
		release.rpc(player_id)

# Server authoritative release execution
@rpc("authority", "call_local")
func release(player_id: int) -> void:
	print("item release by player", player_id)
	
	if player_id in carrier_ids:
		carrier_ids.erase(player_id)
		
		# For items that require two carriers, drop immediately if one player leaves
		if requires_two_carriers:
			isCarried = false
			drop_item_at_center()
		else:
			# For regular items, drop only when no carriers remain
			if carrier_ids.size() == 0:
				isCarried = false
				drop_item_at_single_player(player_id)
			else:
				print("Item still carried by: ", carrier_ids)

# Drop item at the center point between carriers (for two-carrier items)
func drop_item_at_center() -> void:
	var players_node = get_tree().get_root().get_node("Demo1/Players")
	var total_position = Vector2()
	var valid_positions = 0
	
	# Calculate center point from all current and recently released carriers
	for carrier_id in carrier_ids:
		var player = players_node.get_node(str(carrier_id))
		if player:
			total_position += player.get_node("Marker2D").global_position
			valid_positions += 1
	
	# If we have valid positions, use the center
	if valid_positions > 0:
		var drop_point = total_position / valid_positions
		synced_position = drop_point + Vector2(0, 10)  # Slight offset below
	else:
		# Fallback to current position
		synced_position = position
	
	self.position = synced_position
	check_collection_area()

# Drop item at single player's position (for single-carrier items)
func drop_item_at_single_player(player_id: int) -> void:
	var players_node = get_tree().get_root().get_node("Demo1/Players")
	var player = players_node.get_node(str(player_id))
	if player:
		var drop_point = player.get_node("Marker2D").global_position
		synced_position = drop_point + Vector2(0, 0)
		self.position = synced_position
	
	check_collection_area()

# Check if item was dropped in collection area
func check_collection_area() -> void:
	var overlapping_areas = get_overlapping_areas()
	for area in overlapping_areas:
		if area.name == "CollectionArea" and multiplayer.is_server():
			print("Item: ", item_type, " dropped in collection area")
			get_tree().get_root().get_node("Demo1")._on_item_dropped(item_type)
			$ItemCollectedSfx.play()
			await get_tree().create_timer(1.0).timeout
			destroy_item.rpc()

@rpc("authority", "call_local")
func destroy_item() -> void:
	print("Destroying item: ", item_type)
	queue_free()
