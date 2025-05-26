extends Node

# -------- Constants --------

# Default game server port. Can be any number between 1024 and 49151.
# Not on the list of registered or common ports as of May 2024:
# https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers
const DEFAULT_PORT = 10567

## The maximum number of players.
const MAX_PEERS = 4

# Cat character list
const CATS := [
	"Bob",
	"Tuna",
	"Kiki",
	"Rupert",
]

# -------- Game State --------
var peer: ENetMultiplayerPeer
var player_name := "Player 1"
var player_cat = null

# other player's cats, id:cat_name
var player_cats := {}
func get_player_cat_list() -> Array:
	return player_cats.values()

# Names for other players in id:name format.
var players := {}
func get_player_list() -> Array:
	return players.values()

# id: true/false
var players_ready := {}
func all_players_ready() -> bool:
	# Check if all players are ready.
	if not players_ready[1]:
		return false
	for p_id: int in players:
		if not players_ready[p_id]:
			return false
	return true


# -------- Signals --------

# Signals to let lobby GUI know what's going on.
signal player_list_changed()
signal connection_failed()
signal connection_succeeded()
signal game_ended()
signal game_error(what: int)
signal return_to_level_selection_requested()

# -------- Callbacks from SceneTree --------

# Callback from SceneTree.
func _player_connected(id: int) -> void:
	# Registration of a client beings here, tell the connected player that we are here.
	print("Player connected with ID: ", id)
	register_player.rpc_id(id, player_name)

# Callback from SceneTree.
func _player_disconnected(id: int) -> void:
	if has_node("/root/World"):
		# Game is in progress.
		if multiplayer.is_server():
			game_error.emit("Player " + players[id] + " disconnected")
			end_game()
	else:
		# Game is not in progress.
		# Unregister this player.
		unregister_player(id)

# Callback from SceneTree, only for clients (not server).
func _connected_ok() -> void:
	# We just connected to a server
	connection_succeeded.emit()

# Callback from SceneTree, only for clients (not server).
func _server_disconnected() -> void:
	game_error.emit("Server disconnected")
	end_game()

# Callback from SceneTree, only for clients (not server).
func _connected_fail() -> void:
	multiplayer.set_network_peer(null) # Remove peer
	connection_failed.emit()


# -------- Lobby Management --------

@rpc("any_peer")
func register_player(new_player_name: String) -> void:
	print("Registering player: ", new_player_name)
	var id := multiplayer.get_remote_sender_id()
	players[id] = new_player_name
	players_ready[id] = false
	player_list_changed.emit()

func unregister_player(id: int) -> void:
	players.erase(id)
	players_ready.erase(id)
	if player_cats.has(id):
		player_cats.erase(id)
	player_list_changed.emit()

func host_game(new_player_name: String) -> void:
	player_name = new_player_name
	peer = ENetMultiplayerPeer.new()
	peer.create_server(DEFAULT_PORT, MAX_PEERS)
	multiplayer.set_multiplayer_peer(peer)
	# players[1] = player_name
	players_ready[1] = false

func join_game(ip: String, new_player_name: String) -> void:
	player_name = new_player_name
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, DEFAULT_PORT)
	multiplayer.set_multiplayer_peer(peer)

func leave_game() -> void:
	if peer:
			peer.close()
			multiplayer.set_multiplayer_peer(null)
			peer = null
	
	players.clear()
	players_ready.clear()
	player_cats.clear()
	player_cat = null

@rpc("call_local")
func load_world() -> void:
	# Change scene.
	var world: Node = load("res://level/demo_1.tscn").instantiate()
	get_tree().get_root().add_child(world)
	get_tree().get_root().get_node("Lobby").hide()

	# Unpause and unleash the game!
	get_tree().paused = false

func begin_game() -> void:
	assert(multiplayer.is_server())
	load_world.rpc()

func end_game() -> void:
	if has_node("/root/Demo1"):
		# If the game is in progress, end it.
		get_node("/root/Demo1").queue_free()

	game_ended.emit()
	players.clear()

func return_to_level_selection() -> void:
	# Clean up current game state
	if has_node("/root/Demo1"):
		get_node("/root/Demo1").queue_free()
	
	# Reset game variables
	players_ready.clear()
	
	# Reset player cats selection
	for player_id in player_cats.keys():
		if player_id != multiplayer.get_unique_id():
			player_cats.erase(player_id)
	
	# Show lobby and emit signal to reset to level selection
	if has_node("/root/Lobby"):
		get_node("/root/Lobby").show()
		return_to_level_selection_requested.emit()
	else:
		get_tree().change_scene_to_file("res://lobby.tscn")
	
	# Unpause the game
	get_tree().paused = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	multiplayer.connected_to_server.connect(_connected_ok)
	multiplayer.connection_failed.connect(_connected_fail)
	multiplayer.server_disconnected.connect(_server_disconnected)


# -------- Utility Functions --------

## Returns an unique-looking player color based on the name's hash.
func get_player_color(p_name: String) -> Color:
	return Color.from_hsv(wrapf(p_name.hash() * 0.001, 0.0, 1.0), 0.6, 1.0)
