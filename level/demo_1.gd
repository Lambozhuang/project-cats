# demo1.gd
extends Node

@export var isRegularBgmPlaying := true
var _lastRegularBgmPlaying := true
var is_paused := false

const APPLE_REQUIRED := 5
const BEER_REQUIRED := 5
const FISH_REQUIRED := 5
const FISH_BONE_REQUIRED := 5
const POP_CORN_REQUIRED := 5
const ET_REQUIRED := 1

var item_required_counts := {
	"apple": APPLE_REQUIRED,
	"beer": BEER_REQUIRED,
	"fish": FISH_REQUIRED,
	"fish_bone": FISH_BONE_REQUIRED,
	"pop_corn": POP_CORN_REQUIRED,
	"et": ET_REQUIRED
}

var items := {
	1: "apple",
	2: "beer",
	3: "fish",
	4: "fish_bone",
	5: "pop_corn",
	6: "et"
}

var item_counts := {
	"apple": 0,
	"beer": 0,
	"fish": 0,
	"fish_bone": 0,
	"pop_corn": 0,
	"et": 0
}

@onready var timer: Timer = $Timer
@onready var time_label: Label = $HUD/HUD/Time/Label

func _ready():
	# debug
	if not multiplayer.has_multiplayer_peer():
		multiplayer.set_multiplayer_peer(ENetMultiplayerPeer.new())
		multiplayer.multiplayer_peer.create_server(12345, 32)
		multiplayer.multiplayer_peer.set_unique_id(1)
		GameState.player_name = "Server"
		GameState.players[1] = GameState.player_name
		GameState.player_cats[1] = "cat_1"
	else:
		print("Multiplayer peer already set.")

	timer.timeout.connect(_on_timer_timeout)

	update_item_ui()
	update_timer_ui()

	for item_id in items.keys():
		if item_id < 6:
			var item_icon_texture_rect = get_node("HUD/HUD/ScarpaItem/Item" + str(item_id) + "/TextureRect")
			if item_icon_texture_rect:
				item_icon_texture_rect.texture = ResourceCache.demo1_item_icons[items[item_id]]
		else:
			var item_icon_texture_rect = get_node("HUD/HUD/SpaceshipItem/Item" + str(item_id) + "/TextureRect")
			if item_icon_texture_rect:
				item_icon_texture_rect.texture = ResourceCache.demo1_item_icons[items[item_id]]

	if multiplayer.is_server():
		spawn_players()	
	$RegularBgm.play()

	if has_node("HUD/ScoreBoard/Button"):
		print("Connecting ScoreBoard Button pressed signal.")
		$HUD/ScoreBoard/Button.connect("pressed", _on_continue_pressed)
	if has_node("HUD/ScoreBoard/Button2"):
		$HUD/ScoreBoard/Button.connect("pressed", _on_back_to_menu_pressed)
	if has_node("HUD/PauseMenu/Button"):
		$HUD/PauseMenu/Button.connect("pressed", _on_back_to_menu_pressed)
	if has_node("HUD/PauseMenu/Button2"):
		$HUD/PauseMenu/Button2.connect("pressed", _on_resume_pressed)

func _process(delta):
	update_timer_ui()
	
	if isRegularBgmPlaying != _lastRegularBgmPlaying:
		if isRegularBgmPlaying:
			if not $RegularBgm.playing:
				$RegularBgm.play()
		else:
			$RegularBgm.stop()	

		_lastRegularBgmPlaying = isRegularBgmPlaying

func _input(event):
	if event.is_action_pressed("pause"):
		if is_paused:
			resume_game.rpc()
		else:
			pause_game.rpc()


@rpc("authority", "call_local")
func game_over():
	print("Game Over!")
	# Instead of pausing the entire tree, pause specific gameplay nodes
	$Players.process_mode = Node.PROCESS_MODE_DISABLED
	$Timer.paused = true
	if has_node("NPCs"):
		$NPCs.process_mode = Node.PROCESS_MODE_DISABLED
	
	$HUD/HUD/GameOver.show()
	var hide_timer = Timer.new()
	hide_timer.wait_time = 5.0
	hide_timer.one_shot = true
	add_child(hide_timer)
	hide_timer.start()
	hide_timer.timeout.connect(_on_game_over_hide)

func _on_game_over_hide():
	print("Game Over dialog hidden.")
	calculate_and_display_win_state()
	$HUD/HUD.hide()
	$HUD/ScoreBoard.show()

func calculate_and_display_win_state():
	# Calculate total regular items collected and required
	var regular_items_collected = 0
	var regular_items_required = 0
	var spaceship_items_collected = item_counts["et"]
	var spaceship_items_required = ET_REQUIRED
	
	# Sum up all items except ET (spaceship item)
	for item in items.values():
			if item != "et":
					regular_items_collected += item_counts[item]
					regular_items_required += item_required_counts[item]
	
	# Update scoreboard labels
	var regular_label = get_node("HUD/ScoreBoard/RegularItemCollected")
	var spaceship_label = get_node("HUD/ScoreBoard/SpaceshipItemCollected")
	var win_message_label = get_node("HUD/ScoreBoard/TopMessage")
	
	if regular_label:
			regular_label.text = str(regular_items_collected) + "/" + str(regular_items_required)
	
	if spaceship_label:
			spaceship_label.text = str(spaceship_items_collected) + "/" + str(spaceship_items_required)
	
	# Determine win message based on collection status
	if win_message_label:
			if regular_items_collected >= regular_items_required:
					if spaceship_items_collected >= spaceship_items_required:
							win_message_label.text = "PERFECT! MISSION COMPLETE!"
					else:
							win_message_label.text = "GOOD JOB! MISSION SUCCESS!"
			else:
					win_message_label.text = "MISSION FAILED!"
					win_message_label.modulate = Color.RED

func spawn_players() -> void:
	var player_scene: PackedScene = load("res://player/player.tscn")
	var spawn_points := {}
	spawn_points[1] = 0
	var spawn_point_idx := 1
	for p: int in GameState.players:
			spawn_points[p] = spawn_point_idx
			spawn_point_idx += 1

	print("Players: ", GameState.players)
	print("Spawn points: ", spawn_points)

	for p_id: int in spawn_points:
			var spawn_pos: Vector2 = get_node("SpawnPoints/" + str(spawn_points[p_id])).position
			print("Spawning player ", p_id, " at position: ", spawn_pos)
			var player := player_scene.instantiate()
			player.synced_position = spawn_pos
			player.name = str(p_id)
			get_node("Players").add_child(player)
			# The RPC must be called after the player is added to the scene tree.
			# TODOnot important now: maybe transfer the authority to the peer of its player
			#player.set_multiplayer_authority(p_id)
			var name_to_set = GameState.player_name
			var cat_to_set = GameState.player_cat
			if p_id == multiplayer.get_unique_id():
					pass
			else:
					name_to_set = GameState.players[p_id]
					cat_to_set = GameState.player_cats[p_id]
					
			player.set_player_name_and_sprite.rpc(name_to_set, p_id, cat_to_set)

func _on_item_dropped(item_type: String) -> void:
	if items.values().has(item_type):
		update_item_count.rpc(item_type)

@rpc("call_local")
func update_item_count(item_type: String) -> void:
	item_counts[item_type] += 1
	update_item_ui()
	if multiplayer.is_server():
		for item in items.values():
			if item_counts[item] >= item_required_counts[item]:
				print("All required items collected for: ", item)
				# check if all items in all categories are collected
				if all_items_collected():
					print("All items collected! Game Over!")
					game_over.rpc()
					return

func all_items_collected() -> bool:
	for item in items.values():
		if item_counts[item] < item_required_counts[item]:
			return false
	return true

func update_item_ui() -> void:
	# Update the UI with the current item counts
	for item_id in items.keys():
		if item_id < 6:
			var count_label = get_node("HUD/HUD/ScarpaItem/Item" + str(item_id) + "/Label")
			if count_label:
				count_label.text = str(item_counts[items[item_id]]) + "/" + str(item_required_counts[items[item_id]])
		else:
			var count_label = get_node("HUD/HUD/SpaceshipItem/Item" + str(item_id - 5) + "/Label")
			if count_label:
				count_label.text = str(item_counts[items[item_id]]) + "/" + str(item_required_counts[items[item_id]])
	
	# Calculate and display total percentage for regular items (excluding ET)
	var regular_items_collected = 0
	var regular_items_required = 0
	
	for item in items.values():
		if item != "et":  # Exclude spaceship item
			regular_items_collected += item_counts[item]
			regular_items_required += item_required_counts[item]
	
	# Calculate percentage (avoid division by zero)
	var percentage = 0
	if regular_items_required > 0:
		percentage = int((float(regular_items_collected) / float(regular_items_required)) * 100.0)
	
	# Update the progress label
	var progress_label = get_node("HUD/HUD/ScarpaItem/Progress/Label")
	if progress_label:
		progress_label.text = str(percentage) + "%"

func _on_timer_timeout():
	print("Time's up! Game Over!")
	if multiplayer.is_server():
		game_over.rpc()

func update_timer_ui():
	var time_left = timer.time_left
	var minutes = int(time_left) / 60
	var seconds = int(time_left) % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]

func handle_npc_attack(attacker_type: String, target_player_id: int) -> void:
	print("NPC Attack - Type: ", attacker_type, " Target: ", target_player_id)
	
	# Handle different types of NPC attacks
	match attacker_type:
		"officer":  # Add variations of officer type names
			teleport_player_to_jail.rpc(target_player_id)
		"npc":
			# Could add different behavior for guards
			pass
		_:
			print("Unknown NPC type: ", attacker_type)

@rpc("authority", "call_local")
func teleport_player_to_jail(player_id: int) -> void:
	var players_node = get_node("Players")
	var player = players_node.get_node(str(player_id))
	
	if player:
		print("Teleporting player ", player_id, " to jail (200, 160)")
		# Set player as locked up
		player.set_locked_up.rpc(true)
		player.synced_position = Vector2(200, 160)
		player.global_position = Vector2(200, 160)
		
		show_jail_message(player_id)

func show_jail_message(player_id: int) -> void:
	# Optional: Show a message that the player was caught
	print("Player ", player_id, " was captured!")
	if player_id == multiplayer.get_unique_id():
		$HUD/HUD/FullScreenMessage/Label.text = "You were captured and locked up!"
		$HUD/HUD/FullScreenMessage.show()
		# Hide after 3 seconds
		var hide_timer = Timer.new()
		hide_timer.wait_time = 3.0
		hide_timer.one_shot = true
		add_child(hide_timer)
		hide_timer.start()
		hide_timer.timeout.connect(func(): 
			$HUD/HUD/FullScreenMessage.hide()
			hide_timer.queue_free()
		)
	else:
		$HUD/HUD/AlertMessage/Label.text = str(GameState.players[player_id]) + " was captured!"
		$HUD/HUD/AlertMessage.show()
		# Hide after 3 seconds
		var hide_timer = Timer.new()
		hide_timer.wait_time = 3.0
		hide_timer.one_shot = true
		add_child(hide_timer)
		hide_timer.start()
		hide_timer.timeout.connect(func(): 
			$HUD/HUD/AlertMessage.hide()
			hide_timer.queue_free()
		)

func _on_continue_pressed():
	print("Continue button pressed, returning to level selection.")
	if multiplayer.is_server():
		return_to_level_selection.rpc()

@rpc("authority", "call_local")
func return_to_level_selection():
	print("Returning to level selection...")
	GameState.return_to_level_selection()

func _on_resume_pressed():
	print("Resume button pressed.")
	if is_paused:
		resume_game.rpc()
	else:
		pause_game.rpc()

@rpc("any_peer", "call_local")
func pause_game():
	print("Game paused by peer: ", multiplayer.get_remote_sender_id())
	is_paused = true
	
	# Pause gameplay elements
	$Players.process_mode = Node.PROCESS_MODE_DISABLED
	$Timer.paused = true
	if has_node("NPCs"):
		$NPCs.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Show pause menu
	if has_node("HUD/PauseMenu"):
		$HUD/PauseMenu.show()
	else:
		print("Warning: HUD/PauseMenu node not found")

@rpc("any_peer", "call_local")
func resume_game():
	print("Game resumed by peer: ", multiplayer.get_remote_sender_id())
	is_paused = false
	
	# Resume gameplay elements
	$Players.process_mode = Node.PROCESS_MODE_INHERIT
	$Timer.paused = false
	if has_node("NPCs"):
		$NPCs.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Hide pause menu
	if has_node("HUD/PauseMenu"):
		$HUD/PauseMenu.hide()

func _on_back_to_menu_pressed():
	print("Back to menu button pressed.")
	back_to_menu.rpc()

@rpc("any_peer", "call_local")
func back_to_menu():
	GameState.return_to_level_selection()
