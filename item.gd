extends Node2D

var isCarried = false
var carrier_id: int = -1  # ID of the player carrying the item, -1 if none

@export var synced_position := Vector2()

func _ready() -> void:
	synced_position = position

func _physics_process(delta: float) -> void:
	if isCarried:
		var player = get_tree().get_root().get_node("Demo1/Players").get_node(str(carrier_id))
		if player:
			var attach_point = player.get_node("Marker2D").global_position
			var offset = Vector2(0, -20)
			
			# Only the server updates synced_position
			if multiplayer.is_server():
				synced_position = attach_point + offset
			
			# All peers update their local position
			self.position = attach_point + offset
	else:
		# On clients, follow the synced position from the server
		if not multiplayer.is_server():
			self.position = synced_position


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
			var drop_offset = Vector2(0, 20)  # Adjust as needed
			synced_position = drop_point + drop_offset
			self.position = synced_position
		
		isCarried = false
		carrier_id = -1
