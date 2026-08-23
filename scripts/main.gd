# Kraj Main Menu: Key #1 center Play is red zone protected by BGOverlay 0.38; Key #2 spatial battle behind, non-diegetic buttons overlay; Key #3 only relevant chooser shown in menu context; Key #4 eye travel grouped Play->Chooser->Tutorial minimal; Key #5 beige muted weight; Key #6 capped projectiles
extends Control

# Main Menu with Player chooser per Main Game Rules: any Player, State Troops recommended with border
var _selected_player: String = "State Troops"
var _player_buttons: Dictionary = {}
var _flag_rects: Dictionary = {}
var _left_attackers: Array = []
var _right_attackers: Array = []
var _battle_layer: Control = null
var _battle_rng := RandomNumberGenerator.new()

func _ready():
	var play_btn = get_node_or_null("CenterContainer/VBox/PlayButton")
	if play_btn:
		play_btn.grab_focus()
	_wire_buttons()
	_build_player_chooser()
	_add_tutorial_button()
	_add_resume_button()
	_enforce_menu_order()
	_style_menu_buttons()
	_setup_battle_background()

func _setup_battle_background():
	var factions: Array = ["Insurgents", "State Troops", "Fundamentalists", "Mercenaries", "Peace Keepers", "Horde", "Coalition Army", "Corporate Troops"]
	_battle_rng.randomize()
	var pick: String = factions[_battle_rng.randi_range(0, factions.size() - 1)]
	var bg: TextureRect = get_node_or_null("BG") as TextureRect
	if bg != null:
		var tex_path := "res://Assets/Players/%s/background.png" % pick
		if not ResourceLoader.exists(tex_path):
			tex_path = "res://Assets/Players/%s/bg.png" % pick
		if ResourceLoader.exists(tex_path):
			var tex := load(tex_path) as Texture2D
			if tex != null:
				bg.texture = tex
				bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				bg.stretch_mode = TextureRect.STRETCH_SCALE
	# Build armies on top of BG but behind UI
	_create_battle_layer()
	await get_tree().process_frame
	await get_tree().process_frame
	_start_battle_loop()

func _create_battle_layer():
	if _battle_layer != null and is_instance_valid(_battle_layer):
		_battle_layer.queue_free()
		_battle_layer = null
	_left_attackers.clear()
	_right_attackers.clear()
	var layer := Control.new()
	layer.name = "BattleLayer"
	layer.layout_mode = 1
	layer.anchors_preset = 15
	layer.anchor_right = 1.0
	layer.anchor_bottom = 1.0
	layer.grow_horizontal = 2
	layer.grow_vertical = 2
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 1
	# Left army pinned to left side, vertically centered - 2 columns for 8 units
	var left_box := GridContainer.new()
	left_box.name = "LeftArmy"
	left_box.columns = 2
	left_box.layout_mode = 1
	left_box.anchor_left = 0.0
	left_box.anchor_top = 0.5
	left_box.anchor_right = 0.0
	left_box.anchor_bottom = 0.5
	left_box.grow_horizontal = 0
	left_box.grow_vertical = 2
	left_box.position = Vector2(30, -220)
	left_box.size = Vector2(190, 440)
	left_box.add_theme_constant_override("h_separation", 10)
	left_box.add_theme_constant_override("v_separation", 10)
	left_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_box.z_index = 0
	# Right army pinned to right side - flipped horizontally
	var right_box := GridContainer.new()
	right_box.name = "RightArmy"
	right_box.columns = 2
	right_box.layout_mode = 1
	right_box.anchor_left = 1.0
	right_box.anchor_top = 0.5
	right_box.anchor_right = 1.0
	right_box.anchor_bottom = 0.5
	right_box.grow_horizontal = 0
	right_box.grow_vertical = 2
	right_box.position = Vector2(-220, -220)
	right_box.size = Vector2(190, 440)
	right_box.add_theme_constant_override("h_separation", 10)
	right_box.add_theme_constant_override("v_separation", 10)
	right_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_box.z_index = 0
	# Choose card mix for each side - reuse card art, 3 fixed + 5 random each (total 8)
	var left_cards: Array = ["Infantry", "Tank", "Drone", "Interceptor"]
	var right_cards: Array = ["Fighter Jet", "Anti Aircraft", "Howitzer", "Artilery"]
	var unit_pool: Array = ["Infantry", "Tank", "Drone", "Interceptor", "Fighter Jet", "Anti Aircraft", "Howitzer", "Artilery", "Rocket Launcher", "Special Ops"]
	# Build lists: 3 fixed + 5 random
	var left_list: Array = []
	var right_list: Array = []
	for i in range(3):
		left_list.append(left_cards[i % left_cards.size()])
		right_list.append(right_cards[i % right_cards.size()])
	for i in range(5):
		left_list.append(unit_pool[_battle_rng.randi_range(0, unit_pool.size() - 1)])
		right_list.append(unit_pool[_battle_rng.randi_range(0, unit_pool.size() - 1)])
	for i in range(left_list.size()):
		var cname_l: String = left_list[i] as String
		var u_l := _create_army_unit(cname_l, Vector2(84, 84), false)
		left_box.add_child(u_l)
		_left_attackers.append(u_l)
	for i in range(right_list.size()):
		var cname_r: String = right_list[i] as String
		var u_r := _create_army_unit(cname_r, Vector2(84, 84), true)
		right_box.add_child(u_r)
		_right_attackers.append(u_r)
	layer.add_child(left_box)
	layer.add_child(right_box)
	add_child(layer)
	# Ensure BG is behind, layer behind CenterContainer but above BGOverlay
	var bg = get_node_or_null("BG")
	var overlay = get_node_or_null("BGOverlay")
	var center = get_node_or_null("CenterContainer")
	if center != null:
		move_child(layer, center.get_index())
	elif overlay != null:
		move_child(layer, overlay.get_index() + 1)
	elif bg != null:
		move_child(layer, bg.get_index() + 1)
	_battle_layer = layer

func _create_army_unit(card_name: String, size: Vector2, flip_h: bool = false) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_meta("card_name", card_name)
	# Reuse Card animated 20-frame idle (512x512 @10fps)
	var sprite_ctrl := Card.create_sprite_for(card_name, size) as Control
	if sprite_ctrl != null:
		sprite_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if flip_h:
			for child in sprite_ctrl.get_children():
				if child is AnimatedSprite2D:
					(child as AnimatedSprite2D).scale.x *= -1
		# sprite_ctrl already has centered AnimatedSprite scaled to size
		holder.add_child(sprite_ctrl)
		# slight sway animation for idle
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(sprite_ctrl, "position:y", 4.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(sprite_ctrl, "position:y", -4.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return holder

func _get_menu_projectile_frames(card_name: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("fly")
	sf.set_animation_loop("fly", true)
	sf.set_animation_speed("fly", 10.0)
	for i in range(20):
		var fpath: String = "res://Assets/Projectiles/%s/sprite_%d.png" % [card_name, i]
		if ResourceLoader.exists(fpath):
			var tex := load(fpath) as Texture2D
			if tex != null:
				sf.add_frame("fly", tex)
	if sf.get_frame_count("fly") == 0:
		for i in range(20):
			var f2: String = "res://Assets/Cards/%s/attack/sprite_%d.png" % [card_name, i]
			if ResourceLoader.exists(f2):
				var tex2 := load(f2) as Texture2D
				if tex2 != null:
					sf.add_frame("fly", tex2)
	return sf

func _card_name_for_attacker(ctrl: Control) -> String:
	if ctrl != null and ctrl.has_meta("card_name"):
		return ctrl.get_meta("card_name") as String
	return "Infantry"

func _fire_menu_projectile(from_ctrl: Control, to_ctrl: Control):
	if from_ctrl == null or to_ctrl == null or not is_instance_valid(from_ctrl) or not is_instance_valid(to_ctrl):
		return
	var cname: String = _card_name_for_attacker(from_ctrl)
	var sf := _get_menu_projectile_frames(cname)
	if sf.get_frame_count("fly") == 0:
		return
	var start_rect: Rect2 = from_ctrl.get_global_rect()
	var end_rect: Rect2 = to_ctrl.get_global_rect()
	var start_pos: Vector2 = start_rect.get_center()
	var end_pos: Vector2 = end_rect.get_center()
	# add slight vertical jitter so volleys fan
	end_pos.y += _battle_rng.randf_range(-12, 12)
	end_pos.x += _battle_rng.randf_range(-8, 8)
	# Burst count per card (reuse GameController burst logic)
	var burst: int = 1
	if cname == "Interceptor":
		burst = 2
	elif cname == "Howitzer" or cname == "Anti Aircraft":
		burst = 2
	elif cname == "Rocket Launcher":
		burst = 3
	for b in range(burst):
		var proj := Control.new()
		proj.mouse_filter = Control.MOUSE_FILTER_IGNORE
		proj.z_index = 50
		proj.z_as_relative = false
		if proj.has_method("set_as_top_level"):
			proj.top_level = true
		var asp := AnimatedSprite2D.new()
		asp.sprite_frames = sf
		asp.animation = "fly"
		asp.centered = true
		asp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var base: float = 128.0
		if sf.get_frame_count("fly") > 0:
			var tex: Texture2D = sf.get_frame_texture("fly", 0)
			if tex != null:
				base = float(tex.get_width())
				if base < 8:
					base = 128.0
		var scale_f: float = 38.0 / base
		if cname == "Tank":
			scale_f = 50.0 / base
		elif cname == "Interceptor":
			scale_f = 34.0 / base
		elif cname == "Fighter Jet":
			scale_f = 42.0 / base
		elif cname == "Infantry":
			scale_f = 36.0 / base
		asp.scale = Vector2(scale_f, scale_f)
		# face direction: left->right is 0 rad, right->left is PI
		if end_pos.x < start_pos.x:
			asp.scale.x *= -1
		proj.add_child(asp)
		asp.position = Vector2.ZERO
		asp.play("fly")
		var offset: Vector2 = Vector2.ZERO
		if burst > 1:
			offset = Vector2(0, (b - (burst - 1) * 0.5) * 10)
		proj.position = start_pos + offset
		add_child(proj)
		var duration: float = 0.45
		if cname == "Infantry":
			duration = 0.32
		elif cname == "Tank":
			duration = 0.50
		elif cname == "Artilery" or cname == "Howitzer":
			duration = 0.55
		elif cname == "Rocket Launcher":
			duration = 0.60
		elif cname == "Interceptor":
			duration = 0.38
		duration += b * 0.07
		duration += _battle_rng.randf_range(-0.06, 0.06)
		var tw := create_tween()
		tw.tween_property(proj, "position", end_pos + offset, duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
		# fade tail and free
		tw.tween_callback(func(): if is_instance_valid(proj): proj.queue_free())
		# muzzle flash on attacker
		_spawn_muzzle_flash(from_ctrl)

func _spawn_muzzle_flash(anchor: Control):
	var rect: Rect2 = anchor.get_global_rect()
	var p: Vector2 = rect.get_center()
	# move outward toward enemy
	var is_left: bool = _left_attackers.has(anchor)
	p.x += 46 if is_left else -46
	var flash := ColorRect.new()
	flash.color = Color(1, 0.95, 0.55, 0.85)
	flash.size = Vector2(10, 10)
	flash.position = p - flash.size * 0.5
	flash.z_index = 55
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if flash.has_method("set_as_top_level"):
		flash.top_level = true
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.12)
	tw.tween_callback(func(): if is_instance_valid(flash): flash.queue_free())

func _start_battle_loop():
	while is_instance_valid(self):
		await get_tree().create_timer(_battle_rng.randf_range(0.5, 0.9)).timeout
		if _left_attackers.is_empty() or _right_attackers.is_empty():
			continue
		if not is_instance_valid(_battle_layer):
			break
		var left = _left_attackers[_battle_rng.randi_range(0, _left_attackers.size() - 1)] as Control
		var right = _right_attackers[_battle_rng.randi_range(0, _right_attackers.size() - 1)] as Control
		_fire_menu_projectile(left, right)
		await get_tree().create_timer(0.14).timeout
		var right2 = _right_attackers[_battle_rng.randi_range(0, _right_attackers.size() - 1)] as Control
		var left2 = _left_attackers[_battle_rng.randi_range(0, _left_attackers.size() - 1)] as Control
		_fire_menu_projectile(right2, left2)

func _style_menu_buttons():
	for path in ["CenterContainer/VBox/PlayButton", "CenterContainer/VBox/QuitButton", "CenterContainer/VBox/TutorialButton", "CenterContainer/VBox/ResumeButton"]:
		var b: Button = get_node_or_null(path) as Button
		if b == null:
			continue
		_style_pill_button(b, Color(0.16,0.16,0.26,1), Color(0.22,0.22,0.34,1), Color(0.82,0.78,0.70,0.85))

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
	sb_h.border_color = Color(0.88,0.84,0.72,1)
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

func _add_tutorial_button():
	var vbox = get_node_or_null("CenterContainer/VBox")
	if vbox == null:
		return
	if vbox.has_node("TutorialButton"):
		return
	var tbtn := Button.new()
	tbtn.name = "TutorialButton"
	tbtn.text = "Tutorial"
	# Horizontal size must match Play/Quit exactly (both 340×72 in Main.tscn)
	var _play_ref = vbox.get_node_or_null("PlayButton") as Button
	var _quit_ref = vbox.get_node_or_null("QuitButton") as Button
	var _w: float = 340
	var _h: float = 72
	if _play_ref != null:
		_w = _play_ref.custom_minimum_size.x
		_h = _play_ref.custom_minimum_size.y
	elif _quit_ref != null:
		_w = _quit_ref.custom_minimum_size.x
		_h = _quit_ref.custom_minimum_size.y
	tbtn.custom_minimum_size = Vector2(_w, _h)
	tbtn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tbtn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tbtn.add_theme_font_size_override("font_size", 26)
	tbtn.pressed.connect(_on_tutorial_pressed)
	# Put at bottom (below Quit, just before MessageLabel if present)
	var quit = vbox.get_node_or_null("QuitButton")
	var msg = vbox.get_node_or_null("MessageLabel")
	vbox.add_child(tbtn)
	if msg != null:
		vbox.move_child(tbtn, msg.get_index())
	elif quit != null:
		vbox.move_child(tbtn, quit.get_index() + 1)
	_style_pill_button(tbtn, Color(0.14,0.18,0.32,1), Color(0.18,0.24,0.40,1), Color(0.4,0.75,1.0,0.9))
	_enforce_menu_order()

func _on_tutorial_pressed():
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		gs.start_tutorial()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _enforce_menu_order():
	var vbox = get_node_or_null("CenterContainer/VBox")
	if vbox == null:
		return
	# Desired order top→bottom: New Game (Play), Resume, Tutorial, Quit (Exit) at bottom - all 340x72
	var order = ["PlayButton", "ResumeButton", "TutorialButton", "QuitButton"]
	var to_place: Array = []
	for name in order:
		var btn = vbox.get_node_or_null(name)
		if btn != null:
			to_place.append(btn)
	for btn in to_place:
		btn.custom_minimum_size = Vector2(340, 72)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Anchor: place buttons directly after Spacer/PlayerChooser so gap is above, not between Quit and Tutorial
	var anchor = vbox.get_node_or_null("PlayerChooser")
	if anchor == null:
		anchor = vbox.get_node_or_null("Spacer")
	if anchor == null:
		anchor = vbox.get_node_or_null("SubtitleLabel")
	var anchor_idx = anchor.get_index() if anchor != null else 1
	# Remove buttons temporarily to avoid index shifting, then re-insert in correct top→bottom order
	for btn in to_place:
		if btn.get_parent() == vbox:
			vbox.remove_child(btn)
	# Re-add in order: Play first (top), Quit last (bottom) just before MessageLabel
	var msg = vbox.get_node_or_null("MessageLabel")
	var insert_idx = msg.get_index() if msg != null else vbox.get_child_count()
	# If anchor still exists, insert after anchor, otherwise before msg
	if anchor != null and is_instance_valid(anchor) and anchor.get_parent() == vbox:
		insert_idx = anchor.get_index() + 1
		# If MessageLabel is before anchor (should not), fall back to before MessageLabel
		if msg != null and insert_idx > msg.get_index():
			insert_idx = msg.get_index()
	for btn in to_place:
		vbox.add_child(btn)
		vbox.move_child(btn, insert_idx)
		insert_idx += 1

func _add_resume_button():
	var vbox = get_node_or_null("CenterContainer/VBox")
	if vbox == null:
		return
	var gs = get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("has_save") or not gs.has_save():
		# Remove existing resume if save deleted
		var existing = vbox.get_node_or_null("ResumeButton")
		if existing != null:
			existing.queue_free()
		return
	if vbox.has_node("ResumeButton"):
		return
	var rbtn := Button.new()
	rbtn.name = "ResumeButton"
	rbtn.text = "Resume"
	var _play_ref = vbox.get_node_or_null("PlayButton") as Button
	var _w: float = 340
	var _h: float = 72
	if _play_ref != null:
		_w = _play_ref.custom_minimum_size.x
		_h = _play_ref.custom_minimum_size.y
	rbtn.custom_minimum_size = Vector2(_w, _h)
	rbtn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rbtn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rbtn.add_theme_font_size_override("font_size", 26)
	rbtn.pressed.connect(_on_resume_pressed)
	var quit = vbox.get_node_or_null("QuitButton")
	var tutorial = vbox.get_node_or_null("TutorialButton")
	vbox.add_child(rbtn)
	# Place resume between Quit and Tutorial (Quit -> Resume -> Tutorial)
	if quit != null and tutorial != null:
		vbox.move_child(rbtn, tutorial.get_index())
		# Ensure order is Quit, Resume, Tutorial -> if resume ended up after tutorial, swap
		if rbtn.get_index() > tutorial.get_index():
			vbox.move_child(rbtn, tutorial.get_index())
	elif quit != null:
		vbox.move_child(rbtn, quit.get_index() + 1)
	elif tutorial != null:
		vbox.move_child(rbtn, tutorial.get_index())
	_style_pill_button(rbtn, Color(0.16,0.32,0.18,1), Color(0.22,0.42,0.24,1), Color(0.4,0.9,0.5,0.9))
	_enforce_menu_order()

func _on_resume_pressed():
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.has_method("load_game"):
		if gs.load_game():
			get_tree().change_scene_to_file("res://scenes/Game.tscn")
		else:
			var msg = get_node_or_null("CenterContainer/VBox/MessageLabel") as Label
			if msg != null:
				msg.text = "No save found or failed to load."
	else:
		var msg2 = get_node_or_null("CenterContainer/VBox/MessageLabel") as Label
		if msg2 != null:
			msg2.text = "Resume not available."


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
	chooser.add_theme_constant_override("separation", 4)
	var lbl := Label.new()
	lbl.text = "Choose your faction:"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.9,0.9,0.95))
	chooser.add_child(lbl)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	var center_wrap := CenterContainer.new()
	center_wrap.add_child(grid)
	chooser.add_child(center_wrap)
	for name in ["Insurgents", "State Troops", "Fundamentalists", "Mercenaries", "Peace Keepers", "Horde", "Coalition Army", "Corporate Troops"]:
		var entry := VBoxContainer.new()
		entry.alignment = BoxContainer.ALIGNMENT_CENTER
		entry.add_theme_constant_override("separation", 4)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var flag := TextureRect.new()
		flag.custom_minimum_size = Vector2(68, 68)
		flag.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var flag_path := "res://Assets/Players/%s/flag.png" % name
		if ResourceLoader.exists(flag_path):
			var tex := load(flag_path) as Texture2D
			if tex != null:
				flag.texture = tex
		else:
			flag.texture = null
		flag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		entry.add_child(flag)
		var btn := Button.new()
		btn.text = name
		btn.name = name.replace(" ", "")
		btn.custom_minimum_size = Vector2(140, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_color_override("font_color", Color(1,1,1))
		btn.pressed.connect(func(): _select_player(name))
		flag.gui_input.connect(func(event: InputEvent): if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: _select_player(name))
		flag.mouse_filter = Control.MOUSE_FILTER_STOP
		_flag_rects[name] = flag
		_player_buttons[name] = btn
		entry.add_child(btn)
		grid.add_child(entry)
	var hint := Label.new()
	hint.text = "State Troops recommended"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(1,0.85,0.3))
	chooser.add_child(hint)
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
		var flag_rect: TextureRect = _flag_rects.get(n, null) as TextureRect
		if flag_rect != null:
			flag_rect.modulate = Color(1,1,1,1) if n == name else Color(1,1,1,0.78)
			flag_rect.material = null
		b.modulate = Color(1,1,1,1) if n == name else Color(1,1,1,0.7)
		b.button_pressed = (n == name)
		if n == name:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.18,0.18,0.26,1)
			sb.border_color = Color(0.82,0.78,0.70,1)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(18)
			sb.content_margin_left = 12
			sb.content_margin_right = 12
			sb.content_margin_top = 8
			sb.content_margin_bottom = 8
			sb.shadow_color = Color(0,0,0,0.35)
			sb.shadow_size = 3
			b.add_theme_stylebox_override("normal", sb)
			var sb_hover := StyleBoxFlat.new()
			sb_hover.bg_color = Color(0.22,0.22,0.32,1)
			sb_hover.border_color = Color(0.88,0.84,0.72,1)
			sb_hover.set_border_width_all(3)
			sb_hover.set_corner_radius_all(18)
			sb_hover.shadow_color = Color(0,0,0,0.4)
			sb_hover.shadow_size = 4
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
