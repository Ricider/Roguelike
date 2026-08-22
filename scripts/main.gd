extends Control

# Main Menu with Player chooser per Main Game Rules: any Player, State Troops recommended with border
var _selected_player: String = "State Troops"
var _player_buttons: Dictionary = {}

func _ready():
	var play_btn = get_node_or_null("CenterContainer/VBox/PlayButton")
	if play_btn:
		play_btn.grab_focus()
	_wire_buttons()
	_build_player_chooser()
	_style_menu_buttons()

func _style_menu_buttons():
	for path in ["CenterContainer/VBox/PlayButton", "CenterContainer/VBox/QuitButton"]:
		var b: Button = get_node_or_null(path) as Button
		if b == null:
			continue
		_style_pill_button(b, Color(0.16,0.16,0.26,1), Color(0.22,0.22,0.34,1), Color(0.9,0.85,0.4,0.9))

func _style_pill_button(btn: Button, bg: Color, hover_bg: Color, border: Color):
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0,0,0,0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0,3)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := StyleBoxFlat.new()
	sb_h.bg_color = hover_bg
	sb_h.border_color = Color(1,0.92,0.55,1)
	sb_h.set_border_width_all(2)
	sb_h.set_corner_radius_all(24)
	sb_h.content_margin_left = 18
	sb_h.content_margin_right = 18
	sb_h.content_margin_top = 10
	sb_h.content_margin_bottom = 10
	sb_h.shadow_color = Color(0,0,0,0.45)
	sb_h.shadow_size = 8
	btn.add_theme_stylebox_override("hover", sb_h)
	var sb_p := StyleBoxFlat.new()
	sb_p.bg_color = Color(0.12,0.12,0.18,1)
	sb_p.border_color = border
	sb_p.set_border_width_all(2)
	sb_p.set_corner_radius_all(24)
	sb_p.content_margin_left = 18
	sb_p.content_margin_right = 18
	sb_p.content_margin_top = 10
	sb_p.content_margin_bottom = 10
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_stylebox_override("focus", sb_h)
	btn.add_theme_color_override("font_color", Color(1,1,1))
	btn.add_theme_color_override("font_hover_color", Color(1,1,1))

func _wire_buttons():
	var play = get_node_or_null("CenterContainer/VBox/PlayButton")
	var quit = get_node_or_null("CenterContainer/VBox/QuitButton")
	if play and not play.pressed.is_connected(_on_play_pressed):
		play.pressed.connect(_on_play_pressed)
	if quit and not quit.pressed.is_connected(_on_quit_pressed):
		quit.pressed.connect(_on_quit_pressed)

func _build_player_chooser():
	var vbox = get_node_or_null("CenterContainer/VBox")
	if vbox == null:
		return
	if has_node("CenterContainer/VBox/PlayerChooser"):
		return
	var chooser := VBoxContainer.new()
	chooser.name = "PlayerChooser"
	chooser.alignment = BoxContainer.ALIGNMENT_CENTER
	chooser.add_theme_constant_override("separation", 6)
	var lbl := Label.new()
	lbl.text = "Choose your faction:"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.9,0.9,0.95))
	chooser.add_child(lbl)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	# Center the grid inside the chooser
	var center_wrap := CenterContainer.new()
	center_wrap.add_child(grid)
	chooser.add_child(center_wrap)
	for name in ["Insurgents", "State Troops", "Fundamentalists", "Mercenaries", "Peace Keepers", "Horde", "Coalition Army", "Corporate Troops"]:
		var btn := Button.new()
		btn.text = name
		btn.name = name.replace(" ", "")
		btn.custom_minimum_size = Vector2(160, 64)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(1,1,1))
		btn.pressed.connect(func(): _select_player(name))
		_player_buttons[name] = btn
		grid.add_child(btn)
	var hint := Label.new()
	hint.text = "State Troops recommended"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(1,0.85,0.3))
	chooser.add_child(hint)
	# Insert before PlayButton
	var play = vbox.get_node_or_null("PlayButton")
	if play:
		vbox.add_child(chooser)
		vbox.move_child(chooser, play.get_index())
	else:
		vbox.add_child(chooser)
	_select_player(_selected_player)

func _select_player(name: String):
	_selected_player = name
	for n in _player_buttons.keys():
		var b: Button = _player_buttons[n]
		b.modulate = Color(1,1,1,1) if n == name else Color(1,1,1,0.7)
		b.button_pressed = (n == name)
		# Round pill faction chooser — 18 radius, soft shadow
		if n == name:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.18,0.18,0.26,1)
			sb.border_color = Color(1,0.85,0.2,1)
			sb.set_border_width_all(3)
			sb.set_corner_radius_all(18)
			sb.content_margin_left = 12
			sb.content_margin_right = 12
			sb.content_margin_top = 8
			sb.content_margin_bottom = 8
			sb.shadow_color = Color(0,0,0,0.35)
			sb.shadow_size = 5
			b.add_theme_stylebox_override("normal", sb)
			var sb_hover := StyleBoxFlat.new()
			sb_hover.bg_color = Color(0.22,0.22,0.32,1)
			sb_hover.border_color = Color(1,0.92,0.5,1)
			sb_hover.set_border_width_all(3)
			sb_hover.set_corner_radius_all(18)
			sb_hover.shadow_color = Color(0,0,0,0.4)
			sb_hover.shadow_size = 6
			b.add_theme_stylebox_override("hover", sb_hover)
			b.add_theme_stylebox_override("pressed", sb)
			b.add_theme_stylebox_override("focus", sb)
		else:
			var sb_off := StyleBoxFlat.new()
			sb_off.bg_color = Color(0.12,0.12,0.18,1)
			sb_off.border_color = Color(0,0,0,0)
			sb_off.set_border_width_all(0)
			sb_off.set_corner_radius_all(18)
			sb_off.content_margin_left = 12
			sb_off.content_margin_right = 12
			sb_off.content_margin_top = 8
			sb_off.content_margin_bottom = 8
			sb_off.shadow_color = Color(0,0,0,0.25)
			sb_off.shadow_size = 4
			b.add_theme_stylebox_override("normal", sb_off)
			b.add_theme_stylebox_override("hover", sb_off)
			b.add_theme_stylebox_override("pressed", sb_off)
			b.add_theme_stylebox_override("focus", sb_off)
	# Subtitle stays as title, do not show BackgroundImage text per spec

func _on_play_pressed():
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		gs.start_run(_selected_player)
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_quit_pressed():
	get_tree().quit()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
