# hud.gd
extends CanvasLayer

@onready var tutorial_page = $HUD/TutorialPage
@onready var help_button = $HUD/Help

func _ready() -> void:
	if tutorial_page:
		tutorial_page.hide()
	
	if help_button:
		help_button.pressed.connect(_on_help_button_pressed)

func _on_help_button_pressed() -> void:
	if tutorial_page:
		if tutorial_page.visible:
			tutorial_page.hide()
		else:
			tutorial_page.show()
