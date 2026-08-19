extends Control

func _ready():
	var back = get_node_or_null("CenterContainer/VBox/BackButton")
	if back and not back.pressed.is_connected(_on_back):
		back.pressed.connect(_on_back)
	var b2 = get_node_or_null("Header/BackButtonTop")
	if b2 and not b2.pressed.is_connected(_on_back):
		b2.pressed.connect(_on_back)

func _on_back():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_back()
