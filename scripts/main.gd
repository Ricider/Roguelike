extends Control

# Main Menu only - launches the 1v1 autochess game

func _ready():
	var play_btn = get_node_or_null("CenterContainer/VBox/PlayButton")
	if play_btn:
		play_btn.grab_focus()
	_wire_buttons()

func _wire_buttons():
	var play = get_node_or_null("CenterContainer/VBox/PlayButton")
	var quit = get_node_or_null("CenterContainer/VBox/QuitButton")
	if play and not play.pressed.is_connected(_on_play_pressed):
		play.pressed.connect(_on_play_pressed)
	if quit and not quit.pressed.is_connected(_on_quit_pressed):
		quit.pressed.connect(_on_quit_pressed)

func _on_play_pressed():
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_quit_pressed():
	get_tree().quit()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
