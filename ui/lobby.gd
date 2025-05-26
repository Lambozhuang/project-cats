extends Control

func _ready() -> void:
	# Called every time the node is added to the scene.
	GameState.connection_failed.connect(_on_connection_failed)
	GameState.connection_succeeded.connect(_on_connection_success)
	GameState.player_list_changed.connect(refresh_lobby)
	GameState.game_ended.connect(_on_game_ended)
	GameState.game_error.connect(_on_game_error)
	GameState.return_to_level_selection_requested.connect(_on_return_to_level_selection)
	# Set the player name according to the system username. Fallback to the path.
	if OS.has_environment("USERNAME"):
		$Connect/Name.text = OS.get_environment("USERNAME")
	else:
		var desktop_path := OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).replace("\\", "/").split("/")
		$Connect/Name.text = desktop_path[desktop_path.size() - 2]

func _process(delta: float) -> void:
	if $Start.visible:
		$BackButton.hide()
	else:
		$BackButton.show()

# Start
func _on_menu_start_pressed() -> void:
	$Start.hide()
	$Connect.show()


# Connect
func _on_host_pressed() -> void:
	if $Connect/Name.text == "":
		$Connect/ErrorLabel.text = "Invalid name!"
		return

	$Connect.hide()
	$Players.show()
	$Connect/ErrorLabel.text = ""

	var player_name: String = $Connect/Name.text
	GameState.host_game(player_name)
	get_window().title = ProjectSettings.get_setting("application/config/name") + ": Server (%s)" % $Connect/Name.text
	refresh_lobby()

func _on_join_pressed() -> void:
	if $Connect/Name.text == "":
		$Connect/ErrorLabel.text = "Invalid name!"
		return

	var ip: String = $Connect/IPAddress.text
	if not ip.is_valid_ip_address():
		$Connect/ErrorLabel.text = "Invalid IP address!"
		return

	$Connect/ErrorLabel.text = ""
	$Connect/Host.disabled = true
	$Connect/Join.disabled = true

	var player_name: String = $Connect/Name.text
	GameState.join_game(ip, player_name)
	get_window().title = ProjectSettings.get_setting("application/config/name") + ": Client (%s)" % $Connect/Name.text


# Players
func _on_start_pressed() -> void:
	# GameState.begin_game()
	switch_to_characters.rpc()

func _on_cancel_pressed() -> void:
	$Players.hide()
	$Characters.hide()
	$Maps.hide()
	$Levels.hide()
	$Start.show()
	$Connect/ErrorLabel.text = ""
	$Connect/Host.disabled = false
	$Connect/Join.disabled = false
	GameState.leave_game()

@rpc("call_local")
func switch_to_characters() -> void:
	$Players.hide()
	$Characters.show()

func _on_find_public_ip_pressed() -> void:
	OS.shell_open("https://icanhazip.com/")


# Characters
func _on_characters_selected(cat_name: String) -> void:
	print("Characters selected: ", cat_name)
	var select_button = get_node("Characters/CharacterHBox/" + cat_name + "/Button")
	$Characters/CharacterHBox.get_node(cat_name + "/PlayerLabel").text = "You"
	select_button.disabled = true
	select_button.text = "Selected"
	# Reset all other buttons if not taken by other players
	for cat in GameState.CATS:
		if cat != cat_name and not GameState.get_player_cat_list().has(cat):
			var other_button = get_node("Characters/CharacterHBox/" + cat + "/Button")
			other_button.disabled = false
			other_button.text = "Select"
			var other_player_label = get_node("Characters/CharacterHBox/" + cat + "/PlayerLabel")
			other_player_label.text = "Not selected"
	$Characters/ReadyButton.disabled = false
	GameState.player_cat = cat_name
	print("Player id: ", multiplayer.get_unique_id(), " selected cat: ", cat_name)
	set_player_cat.rpc(cat_name)

@rpc("any_peer")
func set_player_cat(cat_name: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	GameState.player_cats[id] = cat_name
	# update ui
	$Characters/CharacterHBox.get_node(cat_name + "/Button").disabled = true
	$Characters/CharacterHBox.get_node(cat_name + "/PlayerLabel").text = GameState.players[id]
	for cat in GameState.CATS:
		if cat != cat_name and not GameState.get_player_cat_list().has(cat) and not GameState.player_cat == cat:
			print("Resetting button for cat: ", cat)
			print(GameState.get_player_cat_list())
			var other_button = get_node("Characters/CharacterHBox/" + cat + "/Button")
			other_button.disabled = false
			other_button.text = "Select"
			var other_player_label = get_node("Characters/CharacterHBox/" + cat + "/PlayerLabel")
			other_player_label.text = "Not selected"

func _on_ready() -> void:
	# Local player ready
	player_ready.rpc()
	$Characters/ReadyButton.disabled = true

@rpc("any_peer", "call_local")
func player_ready() -> void:
	if multiplayer.is_server():
		var id := multiplayer.get_remote_sender_id()
		GameState.players_ready[id] = true
		if GameState.all_players_ready():
			print("All players are ready, switching to maps.")
			switch_to_maps.rpc()

@rpc("call_local")
func switch_to_maps() -> void:
	$Characters.hide()
	$Maps.show()
	print("Switching to maps.")

# Maps
func _on_map_selected(map_id: int) -> void:
	if multiplayer.is_server():
		print("Map selected: ", map_id)
		switch_to_levels.rpc()

@rpc("call_local")
func switch_to_levels() -> void:
	$Maps.hide()
	$Levels.show()
	print("Switching to levels.")

# Levels
func _on_level_play(level_number: int) -> void:
	if multiplayer.is_server():
		print("Level play: ", level_number)
		GameState.begin_game()






func _on_connection_success() -> void:
	$Connect.hide()
	$Players.show()

func _on_connection_failed() -> void:
	$Connect/Host.disabled = false
	$Connect/Join.disabled = false
	$Connect/ErrorLabel.set_text("Connection failed.")


func _on_game_ended() -> void:
	show()
	$Connect.show()
	$Players.hide()
	$Connect/Host.disabled = false
	$Connect/Join.disabled = false

func _on_game_error(errtxt: String) -> void:
	$ErrorDialog.dialog_text = errtxt
	$ErrorDialog.popup_centered()
	$Connect/Host.disabled = false
	$Connect/Join.disabled = false


func refresh_lobby() -> void:
	var players := GameState.get_player_list()
	players.sort()
	$Players/VBoxContainer/List.clear()
	$Players/VBoxContainer/List.add_item(GameState.player_name + " (you)")
	for p: String in players:
		$Players/VBoxContainer/List.add_item(p)

	$Players/VBoxContainer/Start.disabled = not multiplayer.is_server()
	print("Players in lobby: ", GameState.players)


func _on_return_to_level_selection() -> void:
	# Reset lobby state and show level selection
	$Start.hide()
	$Connect.hide()
	$Players.hide()
	$Characters.hide()
	$Maps.hide()
	$Levels.show()  # Show level selection directly
	
	# Reset character selection states
	for cat in GameState.CATS:
		var button = get_node("Characters/CharacterHBox/" + cat + "/Button")
		button.disabled = false
		button.text = "Select"
		var player_label = get_node("Characters/CharacterHBox/" + cat + "/PlayerLabel")
		player_label.text = "Not selected"
	
	$Characters/ReadyButton.disabled = true
	
	# Clear ready states
	GameState.players_ready.clear()
