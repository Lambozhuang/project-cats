extends Node2D

var isCarried = false
var carrier_id: int = -1  # ID of the player carrying the item, -1 if none

@export var synced_position := Vector2()

func _ready() -> void:
	synced_position = position

func _physics_process(delta: float) -> void:
	if isCarried and multiplayer.is_server():
		var player = get_tree().get_root().get_node("Demo1/Players").get_node(str(carrier_id))
		if player:
			var attach_point = player.get_node("Marker2D").global_position
			var offset = Vector2(0, -20)
			synced_position = attach_point + offset
			self.position = synced_position
	else:
		# On clients, follow the synced position from the server
		if not multiplayer.is_server():
			self.position = synced_position


@rpc("call_local", "any_peer")
func carry(player_id: int) -> void:
	print("item carry")
	if not isCarried:
		isCarried = true
		carrier_id = player_id
		print("Item carried by player", player_id)

@rpc("call_local", "any_peer")
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
			print(synced_position)
			print(position)
		
		isCarried = false
		carrier_id = -1
