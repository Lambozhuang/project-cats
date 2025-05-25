extends Control

func _ready() -> void:
	# Called every time the node is added to the scene.
	GameState.connection_failed.connect(_on_connection_failed)
	GameState.connection_succeeded.connect(_on_connection_success)
	GameState.player_list_changed.connect(refresh_lobby)
	GameState.game_ended.connect(_on_game_ended)
	GameState.game_error.connect(_on_game_error)
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
	$Players.hide()
	$Characters.show()

func _on_find_public_ip_pressed() -> void:
	OS.shell_open("https://icanhazip.com/")


# Characters
func _on_characters_selected(cat_name: String) -> void:
	print("Characters selected: ", cat_name)
	var select_button = get_node("Characters/CharacterHBox/" + cat_name + "/Button")
	select_button.disabled = true
	select_button.text = "Selected"
	# Reset all other buttons
	for cat in GameState.CATS:
		if cat != cat_name:
			var other_button = get_node("Characters/CharacterHBox/" + cat + "/Button")
			other_button.disabled = false
			other_button.text = "Select"
	$Characters/ReadyButton.disabled = false
	GameState.player_cat = cat_name
	print("player_cat: ", GameState.player_cat)

func _on_ready() -> void:
	# Local player ready
	GameState.begin_game()
	pass




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
