extends Control

# Main Menu only - cross-platform (keyboard, gamepad, touch)
# No dungeon generation - just menu

func _ready():
	# Focus first button for gamepad/keyboard navigation
	var play_btn = get_node_or_null("CenterContainer/VBox/PlayButton")
	if play_btn:
		play_btn.grab_focus()
	# Wire buttons if not wired via signal in tscn
	_wire_buttons()

func _wire_buttons():
	var play = get_node_or_null("CenterContainer/VBox/PlayButton")
	var quit = get_node_or_null("CenterContainer/VBox/QuitButton")
	if play and not play.pressed.is_connected(_on_play_pressed):
		play.pressed.connect(_on_play_pressed)
	if quit and not quit.pressed.is_connected(_on_quit_pressed):
		quit.pressed.connect(_on_quit_pressed)

func _on_play_pressed():
	var label = get_node_or_null("CenterContainer/VBox/MessageLabel")
	if label:
		label.text = "Play pressed! (Game would start here)"
	print("Play pressed")

func _on_quit_pressed():
	get_tree().quit()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
