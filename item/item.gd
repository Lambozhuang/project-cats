# item.gd
extends Area2D

var isCarried = false
var carrier_id: int = -1  # ID of the player carrying the item, -1 if none
var is_two_player_item = false  # New: whether this item requires two players
var carriers: Array[int] = []  # New: array to store multiple carrier IDs
var max_carry_distance = 100.0  # New: maximum distance between carriers
var carriers_holding_key: Array[int] = []  # New: track which carriers are holding the key

@export var item_type: String = "fish"
@export var sprite_frames: SpriteFrames
@export var requires_two_players: bool = false  # New: set this for heavy items

@export var synced_position := Vector2()

func _ready() -> void:
	synced_position = position
	is_two_player_item = requires_two_players

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
		
		if is_two_player_item and carriers.size() == 2:
			_handle_two_player_carry()
		elif not is_two_player_item and carrier_id != -1:
			_handle_single_player_carry()
	else:
		$AnimatedSprite2D.play()
		# On clients, follow the synced position from the server
		if not multiplayer.is_server():
			self.position = synced_position

func _handle_single_player_carry():
	var player = get_tree().get_root().get_node("Demo1/Players").get_node(str(carrier_id))
	if player:
		var attach_point = player.get_node("Marker2D").global_position
		var offset = get_offset_based_on_facing(player)
		
		if multiplayer.is_server():
			synced_position = attach_point + offset
		
		self.position = attach_point + offset

func _handle_two_player_carry():
	var player1 = get_tree().get_root().get_node("Demo1/Players").get_node(str(carriers[0]))
	var player2 = get_tree().get_root().get_node("Demo1/Players").get_node(str(carriers[1]))
	
	if player1 and player2:
		var pos1 = player1.get_node("Marker2D").global_position
		var pos2 = player2.get_node("Marker2D").global_position
		var distance = pos1.distance_to(pos2)
		
		# Check if players are too far apart
		if distance > max_carry_distance:
			if multiplayer.is_server():
				print("Players too far apart, dropping item")
				release.rpc()
			return
		
		# New: Check if both players are still holding the carry key
		if multiplayer.is_server():
			var all_holding = true
			for carrier_id in carriers:
				var player = get_tree().get_root().get_node("Demo1/Players").get_node(str(carrier_id))
				if player and not player.is_holding_carry_key:
					all_holding = false
					break
			
			if not all_holding:
				print("Not all players holding carry key, dropping item")
				release.rpc()
				return
		
		# Position item at midpoint between players
		var midpoint = (pos1 + pos2) / 2.0
		var offset = Vector2(0, -10)  # Slightly above midpoint
		
		if multiplayer.is_server():
			synced_position = midpoint + offset
		
		self.position = midpoint + offset

# New: Handle when a carrier releases the carry key
@rpc("any_peer", "call_local")
func carrier_released_key(player_id: int) -> void:
	if multiplayer.is_server() and is_two_player_item and carriers.has(player_id):
		print("Player ", player_id, " released carry key, dropping two-player item")
		release.rpc()

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
		if is_two_player_item:
			# For two-player items, add to carriers array
			if not carriers.has(player_id):
				carriers.append(player_id)
				print("Player ", player_id, " joined carry. Carriers: ", carriers.size(), "/2")
				
				if carriers.size() == 2:
					# Both players are carrying
					carry_two_player.rpc(carriers[0], carriers[1])
				elif carriers.size() == 1:
					# First player, notify them they need a partner
					notify_need_partner.rpc(player_id)
		else:
			# Single player carry
			carry.rpc(player_id)

# New: Notify player they need a partner
@rpc("authority", "call_local")
func notify_need_partner(player_id: int) -> void:
	print("Player ", player_id, " needs a partner to carry this item")
	# You could show a UI message here

# New: Server authoritative two-player carry execution
@rpc("authority", "call_local")
func carry_two_player(player1_id: int, player2_id: int) -> void:
	print("Two-player carry started by players ", player1_id, " and ", player2_id)
	isCarried = true
	carriers = [player1_id, player2_id]
	
	# Update both players' carry state
	var player1 = get_tree().get_root().get_node("Demo1/Players").get_node(str(player1_id))
	var player2 = get_tree().get_root().get_node("Demo1/Players").get_node(str(player2_id))
	
	if player1:
		player1.set_carrying_two_player_item.rpc(true, get_instance_id())
	if player2:
		player2.set_carrying_two_player_item.rpc(true, get_instance_id())

# Server authoritative carry execution (single player)
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
		release.rpc()

# Server authoritative release execution
@rpc("authority", "call_local")
func release() -> void:
	print("item release")
	if isCarried:
		if is_two_player_item and carriers.size() > 0:
			# Handle two-player release
			var drop_point = Vector2.ZERO
			var valid_carriers = 0
			
			for carrier_id in carriers:
				var player = get_tree().get_root().get_node("Demo1/Players").get_node(str(carrier_id))
				if player:
					drop_point += player.get_node("Marker2D").global_position
					valid_carriers += 1
					# Update player state
					player.set_carrying_two_player_item.rpc(false, 0)
			
			if valid_carriers > 0:
				drop_point = drop_point / valid_carriers
				synced_position = drop_point
				self.position = synced_position
			
			carriers.clear()
			carriers_holding_key.clear()  # New: clear holding key tracking
		else:
			# Handle single player release
			var player = get_tree().get_root().get_node("Demo1/Players").get_node(str(carrier_id))
			if player:
				var drop_point = player.get_node("Marker2D").global_position
				var drop_offset = Vector2(0, 0)
				synced_position = drop_point + drop_offset
				self.position = synced_position
		
		isCarried = false
		carrier_id = -1

		# Check if dropped in the collection area
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