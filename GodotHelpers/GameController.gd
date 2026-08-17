extends Control
class_name GameController

# Manages a simple 1v1 autochess game per spec, vs BasicAI
# Called after Play on main menu

var human: Player
var ai_player: AIPlayer
var state: CombatState

var selected_card: Card = null
var selected_card_idx: int = -1

@onready var ai_info: Label = $VBox/AIInfo
@onready var player_info: Label = $VBox/MainHBox/RightContent/PlayerInfo
@onready var message_label: Label = $VBox/MainHBox/RightContent/Message
@onready var ai_board_container: GridContainer = $VBox/MainHBox/RightContent/AIBoard
@onready var player_board_container: GridContainer = $VBox/MainHBox/RightContent/PlayerBoard
@onready var hand_container: HBoxContainer = $VBox/MainHBox/RightContent/Hand
@onready var ai_label: Label = $VBox/MainHBox/LeftGauges/AIHeader/AILabel
@onready var player_label: Label = $VBox/MainHBox/LeftGauges/PlayerHeader/PlayerLabel
@onready var ai_flag: TextureRect = $VBox/MainHBox/LeftGauges/AIHeader/AIFlag
@onready var player_flag: TextureRect = $VBox/MainHBox/LeftGauges/PlayerHeader/PlayerFlag
@onready var end_turn_btn: Button = $VBox/MainHBox/RightContent/Controls/EndTurn
@onready var menu_btn: Button = $VBox/MainHBox/RightContent/Controls/MenuBtn
@onready var ai_hp_bar: TextureProgressBar = $VBox/MainHBox/LeftGauges/AIGauges/AIGaugeHP/AIHP
@onready var ai_bio_bar: TextureProgressBar = $VBox/MainHBox/LeftGauges/AIGauges/AIGaugeBio/AIBio
@onready var ai_money_bar: TextureProgressBar = $VBox/MainHBox/LeftGauges/AIGauges/AIGaugeMoney/AIMoney
@onready var ai_hp_value: Label = $VBox/MainHBox/LeftGauges/AIGauges/AIGaugeHP/AIHPValue
@onready var ai_bio_value: Label = $VBox/MainHBox/LeftGauges/AIGauges/AIGaugeBio/AIBioValue
@onready var ai_bio_income: Label = $VBox/MainHBox/LeftGauges/AIGauges/AIGaugeBio/AIBioIncome
@onready var ai_money_value: Label = $VBox/MainHBox/LeftGauges/AIGauges/AIGaugeMoney/AIMoneyValue
@onready var ai_money_income: Label = $VBox/MainHBox/LeftGauges/AIGauges/AIGaugeMoney/AIMoneyIncome
@onready var player_hp_bar: TextureProgressBar = $VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeHP/PlayerHP
@onready var player_bio_bar: TextureProgressBar = $VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeBio/PlayerBio
@onready var player_money_bar: TextureProgressBar = $VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeMoney/PlayerMoney
@onready var player_hp_value: Label = $VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeHP/PlayerHPValue
@onready var player_bio_value: Label = $VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeBio/PlayerBioValue
@onready var player_money_value: Label = $VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeMoney/PlayerMoneyValue
@onready var player_bio_income: Label = $VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeBio/PlayerBioIncome
@onready var player_money_income: Label = $VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeMoney/PlayerMoneyIncome
@onready var player_deck_bar: TextureProgressBar = $VBox/MainHBox/LeftGauges/PlayerDeck/PlayerDeckBar
@onready var player_deck_value: Label = $VBox/MainHBox/LeftGauges/PlayerDeck/PlayerDeckValue
@onready var player_deck_icon: Button = $VBox/MainHBox/LeftGauges/PlayerDeck/PlayerDeckIcon
@onready var ai_deck_bar: TextureProgressBar = $VBox/MainHBox/LeftGauges/AIDeck/AIDeckBar
@onready var ai_deck_value: Label = $VBox/MainHBox/LeftGauges/AIDeck/AIDeckValue
@onready var ai_deck_icon: Button = $VBox/MainHBox/LeftGauges/AIDeck/AIDeckIcon
@onready var player_discard_bar: TextureProgressBar = $VBox/MainHBox/RightGauges/PlayerDiscard/PlayerDiscardBar
@onready var player_discard_value: Label = $VBox/MainHBox/RightGauges/PlayerDiscard/PlayerDiscardValue
@onready var player_graveyard_bar: TextureProgressBar = $VBox/MainHBox/RightGauges/PlayerGraveyard/PlayerGraveyardBar
@onready var player_graveyard_value: Label = $VBox/MainHBox/RightGauges/PlayerGraveyard/PlayerGraveyardValue
@onready var ai_discard_bar: TextureProgressBar = $VBox/MainHBox/RightGauges/AIDiscard/AIDiscardBar
@onready var ai_discard_value: Label = $VBox/MainHBox/RightGauges/AIDiscard/AIDiscardValue
@onready var ai_graveyard_bar: TextureProgressBar = $VBox/MainHBox/RightGauges/AIGraveyard/AIGraveyardBar
@onready var ai_graveyard_value: Label = $VBox/MainHBox/RightGauges/AIGraveyard/AIGraveyardValue
@onready var player_discard_icon: Button = $VBox/MainHBox/RightGauges/PlayerDiscard/PlayerDiscardIcon
@onready var player_graveyard_icon: Button = $VBox/MainHBox/RightGauges/PlayerGraveyard/PlayerGraveyardIcon
@onready var ai_discard_icon: Button = $VBox/MainHBox/RightGauges/AIDiscard/AIDiscardIcon
@onready var ai_graveyard_icon: Button = $VBox/MainHBox/RightGauges/AIGraveyard/AIGraveyardIcon
@onready var inspect_popup: PanelContainer = $InspectPopup
@onready var inspect_title: Label = $InspectPopup/VBox/InspectTitle
@onready var inspect_grid: GridContainer = $InspectPopup/VBox/InspectScroll/InspectGrid
@onready var close_btn: Button = $InspectPopup/VBox/CloseBtn
@onready var hover_popup: PanelContainer = $HoverPopup
@onready var hover_label: Label = $HoverPopup/HoverLabel
@onready var bg_rect: TextureRect = $BG
var preview_popup: PanelContainer
var preview_built: bool = false
var debug_popup: PanelContainer
var debug_built: bool = false
var debug_enemy_option: OptionButton
var shop_popup: PanelContainer
var shop_built: bool = false

func _clear_board(player: Player):
	for row in player.Board:
		for sq in row.Squares:
			sq.clear()

func _ready():
	var gs = get_node_or_null("/root/GameState")
	# Roguelike run: use persistent player/enemy sequence per Main Game Rules
	if gs != null and gs.run_started and gs.run_player != null:
		human = gs.run_player
		ai_player = gs.get_current_enemy()
		if ai_player == null:
			# fallback legacy
			ai_player = gs.make_selected_enemy()
		# Fresh board for new battle (clear previous placements but keep deck/influence)
		# Only clear if this is start of a battle (shop closed). The run_player board may still have old placements from previous battle end
		# We keep it empty for now; actual clear will be done on battle start after shop
	else:
		human = Player.new(100, 100, 20, 0, "State Troops", "Middle Eastern town, add some mosques around, don't make the entire thing a desert", 20)
		if gs != null:
			ai_player = gs.make_selected_enemy()
		else:
			ai_player = CardFactory.make_euro_army_player()
		human.display_name = human.display_name if human.display_name != "" else "State Troops"
		if human.DrawPile.is_empty():
			human.DrawPile = CardFactory.make_state_troops_deck()
	_update_background()
	state = CombatState.new(human, ai_player)
	end_turn_btn.pressed.connect(_on_end_turn)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	close_btn.pressed.connect(func(): inspect_popup.visible = false)
	hover_popup.visible = false
	# Hide hover when inspecting or ending turn
	hover_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_preview_popup()
	_ensure_debug_popup()
	_add_debug_button()
	_ensure_shop_popup()
	player_deck_icon.pressed.connect(func(): _inspect_pile("Your Draw Pile", human.DrawPile))
	ai_deck_icon.pressed.connect(func(): _inspect_pile("AI Draw Pile", ai_player.DrawPile))
	player_discard_icon.pressed.connect(func(): _inspect_pile("Your Discard Pile", human.DiscardPile))
	ai_discard_icon.pressed.connect(func(): _inspect_pile("AI Discard Pile", ai_player.DiscardPile))
	player_graveyard_icon.pressed.connect(func(): _inspect_pile("Your Graveyard", human.Graveyard))
	ai_graveyard_icon.pressed.connect(func(): _inspect_pile("AI Graveyard", ai_player.Graveyard))
	_start_new_round()

func _show_hover(text: String):
	if text == "":
		return
	hover_label.text = text
	hover_popup.visible = true
	# position near mouse, clamped to viewport so it never spills
	var vp: Vector2 = get_viewport_rect().size
	var pos: Vector2 = get_global_mouse_position() + Vector2(14, -36)
	var sz: Vector2 = hover_popup.size
	if sz.x < 40:
		sz = Vector2(240, 70)
	pos.x = clamp(pos.x, 4.0, max(4.0, vp.x - sz.x - 4.0))
	pos.y = clamp(pos.y, 4.0, max(4.0, vp.y - sz.y - 4.0))
	hover_popup.global_position = pos
	hover_popup.z_index = 100

func _ensure_preview_popup():
	if preview_built:
		return
	preview_popup = PanelContainer.new()
	preview_popup.visible = false
	preview_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_popup.z_index = 101
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.14, 0.96)
	sb.border_color = Color(0.9, 0.9, 0.95, 1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	preview_popup.add_theme_stylebox_override("panel", sb)
	# Fixed consistent size — never varies, no empty bottom gap, click-through
	preview_popup.custom_minimum_size = Vector2(280, 168)
	preview_popup.size = Vector2(280, 168)
	preview_popup.clip_contents = true
	# Ensure magnifier never blocks clicks to card buttons behind it
	preview_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview_popup)
	preview_built = true

func _set_preview_click_through(node: Control):
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_set_preview_click_through(child as Control)

func _show_card_preview(card: Card):
	_ensure_preview_popup()
	for c in preview_popup.get_children():
		c.queue_free()
	# Consistent fixed height — root fills popup, no variable empty bottom
	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 5)
	root.clip_contents = true
	preview_popup.add_child(root)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	var art := Card.create_sprite_for(card.card_name, Vector2(132, 132))
	art.clip_contents = true
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.custom_minimum_size = Vector2(132, 132)
	top.add_child(art)
	var details := VBoxContainer.new()
	details.alignment = BoxContainer.ALIGNMENT_BEGIN
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 3)
	details.clip_contents = true
	top.add_child(details)
	var name_lbl := Label.new()
	name_lbl.text = card.card_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color(1,1,1))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.clip_contents = true
	# Fixed 1-line height for consistency — Rocket Launcher still fits 15 chars in 124px at 17px, no wrap variation
	name_lbl.custom_minimum_size = Vector2(124, 20)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	details.add_child(name_lbl)
	var hp: int = 0
	var is_unit: bool = card is Unit
	if is_unit:
		hp = (card as Unit).HitPoints
	elif card is Building:
		hp = (card as Building).HitPoints
	# single compact grid: HP | DMG/INC || Money | Bio — uses horizontal space fully
	var grid := HBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_BEGIN
	grid.clip_contents = true
	grid.add_theme_constant_override("separation", 10)
	details.add_child(grid)
	var left_stats := HBoxContainer.new()
	left_stats.alignment = BoxContainer.ALIGNMENT_BEGIN
	left_stats.add_theme_constant_override("separation", 3)
	grid.add_child(left_stats)
	var hp_icon := TextureRect.new()
	hp_icon.texture = load("res://Assets/UI/heart.png") as Texture2D
	hp_icon.custom_minimum_size = Vector2(24, 24)
	hp_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hp_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	left_stats.add_child(hp_icon)
	var hp_lbl := Label.new()
	hp_lbl.text = "%d" % hp
	hp_lbl.add_theme_font_size_override("font_size", 15)
	hp_lbl.add_theme_color_override("font_color", Color(1,1,1))
	left_stats.add_child(hp_lbl)
	if is_unit:
		var sw := TextureRect.new()
		sw.texture = load("res://Assets/UI/sword.png") as Texture2D
		sw.custom_minimum_size = Vector2(24, 24)
		sw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sw.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sw.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		left_stats.add_child(sw)
		var dmg_lbl := Label.new()
		dmg_lbl.text = "%d" % (card as Unit).Damage
		dmg_lbl.add_theme_font_size_override("font_size", 15)
		dmg_lbl.add_theme_color_override("font_color", Color(1,1,1))
		left_stats.add_child(dmg_lbl)
	else:
		var inc_lbl := Label.new()
		inc_lbl.text = "INC %d" % (card as Building).Income
		inc_lbl.add_theme_font_size_override("font_size", 13)
		inc_lbl.add_theme_color_override("font_color", Color(1,1,1))
		left_stats.add_child(inc_lbl)
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(1, 14)
	grid.add_child(sep)
	var costs := HBoxContainer.new()
	costs.alignment = BoxContainer.ALIGNMENT_BEGIN
	costs.add_theme_constant_override("separation", 3)
	grid.add_child(costs)
	var m_icon := TextureRect.new()
	m_icon.texture = load("res://Assets/UI/money_icon.png") as Texture2D
	m_icon.custom_minimum_size = Vector2(20, 20)
	m_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	m_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	m_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	costs.add_child(m_icon)
	var m_lbl := Label.new()
	m_lbl.text = "%d" % card.MoneyCost
	m_lbl.add_theme_font_size_override("font_size", 13)
	m_lbl.add_theme_color_override("font_color", Color(1,1,1))
	costs.add_child(m_lbl)
	var b_icon := TextureRect.new()
	b_icon.texture = load("res://Assets/UI/bio_icon.png") as Texture2D
	b_icon.custom_minimum_size = Vector2(20, 20)
	b_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	b_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	b_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	costs.add_child(b_icon)
	var b_lbl := Label.new()
	b_lbl.text = "%d" % card.BioCost
	b_lbl.add_theme_font_size_override("font_size", 13)
	b_lbl.add_theme_color_override("font_color", Color(1,1,1))
	costs.add_child(b_lbl)
	# effect spans full width below — fixed 32px height for all cards, no variation, clipped if longer
	var eff := Label.new()
	if card.SpecialEffect != "":
		eff.text = card.SpecialEffect
	else:
		eff.text = " "
	eff.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eff.clip_contents = true
	eff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eff.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	eff.custom_minimum_size = Vector2(264, 32)
	eff.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	eff.add_theme_font_size_override("font_size", 11)
	eff.add_theme_color_override("font_color", Color(0.92,0.92,1) if card.SpecialEffect != "" else Color(1,1,1,0))
	root.add_child(eff)
	# filler to ensure root fills fixed popup height with no empty bottom variation — expands only if needed, keeps outer 168 constant
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(filler)
	_set_preview_click_through(root)
	_set_preview_click_through(preview_popup)
	preview_popup.visible = true
	var vp: Vector2 = get_viewport_rect().size
	var sz: Vector2 = Vector2(280, 168)
	preview_popup.size = sz
	preview_popup.custom_minimum_size = sz
	# flip above/beside cursor when near bottom/right edge — prevents hand hover spill at viewport bottom
	var mouse: Vector2 = get_global_mouse_position()
	var pos: Vector2 = mouse + Vector2(16, 16)
	if pos.x + sz.x > vp.x - 8:
		pos.x = mouse.x - sz.x - 16
	if pos.y + sz.y > vp.y - 8:
		pos.y = mouse.y - sz.y - 16
	pos.x = clamp(pos.x, 8.0, max(8.0, vp.x - sz.x - 8.0))
	pos.y = clamp(pos.y, 8.0, max(8.0, vp.y - sz.y - 8.0))
	preview_popup.global_position = pos
	preview_popup.z_index = 101
	preview_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _hide_card_preview():
	if preview_popup != null:
		preview_popup.visible = false

func _hide_hover():
	hover_popup.visible = false
	_hide_card_preview()

func _update_background():
	if bg_rect == null:
		bg_rect = get_node_or_null("BG") as TextureRect
	if bg_rect == null:
		return
	var path: String = ""
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		path = gs.background_path_for(ai_player.display_name)
	else:
		if ai_player.display_name == "Insurgents":
			path = "res://Assets/Players/Insurgents/background.png"
		elif ai_player.display_name == "Euro Army":
			path = "res://Assets/Players/Euro Army/background.png"
	if path != "" and ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			bg_rect.texture = tex
			bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	# keep overlay visible over background
	_update_flag_textures()

func _update_flag_textures():
	if ai_flag != null:
		var p: String = "res://Assets/Players/Euro Army/flag.png"
		if ai_player.display_name == "Insurgents":
			p = "res://Assets/Players/Insurgents/flag.png"
		if ResourceLoader.exists(p):
			var t := load(p) as Texture2D
			if t != null:
				ai_flag.texture = t

func _ensure_debug_popup():
	if debug_built:
		return
	debug_popup = PanelContainer.new()
	debug_popup.name = "DebugPopup"
	debug_popup.visible = false
	debug_popup.z_index = 102
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.14, 0.97)
	sb.border_color = Color(0.9, 0.85, 0.4, 1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	debug_popup.add_theme_stylebox_override("panel", sb)
	debug_popup.custom_minimum_size = Vector2(340, 160)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	debug_popup.add_child(vbox)
	var title := Label.new()
	title.text = "Debug Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1,1,0.7))
	vbox.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)
	var lbl := Label.new()
	lbl.text = "Enemy:"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1,1,1))
	row.add_child(lbl)
	debug_enemy_option = OptionButton.new()
	debug_enemy_option.custom_minimum_size = Vector2(180, 32)
	debug_enemy_option.add_item("Euro Army", 0)
	debug_enemy_option.add_item("Insurgents", 1)
	var gs2 = get_node_or_null("/root/GameState")
	var cur: String = "Euro Army"
	if gs2 != null:
		cur = gs2.selected_enemy
	debug_enemy_option.selected = 1 if cur == "Insurgents" else 0
	debug_enemy_option.item_selected.connect(func(idx: int):
		var g = get_node_or_null("/root/GameState")
		if g != null:
			g.set_enemy(debug_enemy_option.get_item_text(idx))
	)
	row.add_child(debug_enemy_option)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)
	var restart_btn := Button.new()
	restart_btn.text = "Switch & Restart"
	restart_btn.custom_minimum_size = Vector2(150, 36)
	restart_btn.add_theme_font_size_override("font_size", 15)
	restart_btn.pressed.connect(_restart_game)
	btn_row.add_child(restart_btn)
	var close_dbtn := Button.new()
	close_dbtn.text = "Close"
	close_dbtn.custom_minimum_size = Vector2(80, 36)
	close_dbtn.pressed.connect(func(): debug_popup.visible = false)
	btn_row.add_child(close_dbtn)
	var info := Label.new()
	info.text = "Background: " + (ai_player.BackgroundImage if ai_player.BackgroundImage != "" else ai_player.display_name)
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", Color(0.8,0.8,0.85))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info)
	add_child(debug_popup)
	# center popup
	debug_popup.position = Vector2.ZERO
	debug_built = true

func _add_debug_button():
	var controls = get_node_or_null("VBox/MainHBox/RightContent/Controls")
	if controls == null:
		return
	if controls.has_node("DebugBtn"):
		return
	var btn := Button.new()
	btn.name = "DebugBtn"
	btn.text = "Debug"
	btn.custom_minimum_size = Vector2(90, 40)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(1,1,0.6))
	btn.pressed.connect(func():
		_ensure_debug_popup()
		debug_popup.visible = !debug_popup.visible
		if debug_popup.visible:
			_center_debug_popup()
	)
	controls.add_child(btn)
	# keep MenuBtn last
	var menu = controls.get_node_or_null("MenuBtn")
	if menu:
		controls.move_child(btn, menu.get_index())

func _center_debug_popup():
	if debug_popup == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var sz: Vector2 = debug_popup.size
	if sz.x < 100:
		sz = Vector2(340, 160)
	debug_popup.position = (vp - sz) / 2.0

func _restart_game():
	var g = get_node_or_null("/root/GameState")
	if g != null and debug_enemy_option != null:
		g.set_enemy(debug_enemy_option.get_item_text(debug_enemy_option.selected))
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _ensure_shop_popup():
	if shop_built:
		return
	shop_popup = PanelContainer.new()
	shop_popup.name = "ShopPopup"
	shop_popup.visible = false
	shop_popup.z_index = 105
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09,0.09,0.16,0.98)
	sb.border_color = Color(1,0.9,0.4,1)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	shop_popup.add_theme_stylebox_override("panel", sb)
	shop_popup.custom_minimum_size = Vector2(900, 320)
	add_child(shop_popup)
	shop_built = true

func _show_shop():
	_ensure_shop_popup()
	# Clear previous
	for c in shop_popup.get_children():
		c.queue_free()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	shop_popup.add_child(vbox)
	var gs = get_node_or_null("/root/GameState")
	var influence: int = human.Influence if human != null else 0
	if gs != null and gs.run_player != null:
		influence = gs.run_player.Influence
	var title := Label.new()
	title.text = "Shop — Between Battles (Influence: %d)" % influence
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1,0.92,0.5))
	vbox.add_child(title)
	var hint := Label.new()
	hint.text = "Buy 5 cards using Influence (cost = InfluenceCost). Remove a card for 25 Influence (once per shop)."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.85,0.85,0.9))
	vbox.add_child(hint)
	var offer: Array = []
	if gs != null and not gs.shop_offer.is_empty():
		offer = gs.shop_offer
	else:
		offer = CardFactory.random_shop_offer()
		if gs != null:
			gs.shop_offer = offer
			gs.shop_remove_used = false
	var grid := HBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 12)
	vbox.add_child(grid)
	for card in offer:
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.custom_minimum_size = Vector2(150, 180)
		var art := Card.create_sprite_for(card.card_name, Vector2(96,96))
		art.clip_contents = true
		cell.add_child(art)
		var name_lbl := Label.new()
		name_lbl.text = card.card_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(1,1,1))
		cell.add_child(name_lbl)
		var cost_lbl := Label.new()
		cost_lbl.text = "Cost: %d Influence" % card.InfluenceCost
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 11)
		cost_lbl.add_theme_color_override("font_color", Color(1,0.85,0.4))
		cell.add_child(cost_lbl)
		var stats := Label.new()
		if card is Unit:
			stats.text = "HP:%d DMG:%d" % [(card as Unit).HitPoints, (card as Unit).Damage]
		elif card is Building:
			stats.text = "HP:%d INC:%d" % [(card as Building).HitPoints, (card as Building).Income]
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.add_theme_font_size_override("font_size", 10)
		stats.add_theme_color_override("font_color", Color(0.9,0.9,1))
		cell.add_child(stats)
		if card.SpecialEffect != "":
			var eff := Label.new()
			eff.text = card.SpecialEffect
			eff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			eff.custom_minimum_size = Vector2(140, 28)
			eff.add_theme_font_size_override("font_size", 8)
			eff.add_theme_color_override("font_color", Color(0.8,0.8,1))
			cell.add_child(eff)
		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.custom_minimum_size = Vector2(80, 28)
		buy_btn.disabled = influence < card.InfluenceCost
		if buy_btn.disabled:
			buy_btn.modulate = Color(0.6,0.6,0.6)
		var _card_ref: Card = card
		buy_btn.pressed.connect(func(): _buy_shop_card(_card_ref))
		cell.add_child(buy_btn)
		grid.add_child(cell)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)
	var remove_btn := Button.new()
	remove_btn.text = "Remove a card (25 Influence) — once per shop"
	remove_btn.custom_minimum_size = Vector2(260, 32)
	if gs != null and gs.shop_remove_used:
		remove_btn.disabled = true
		remove_btn.text = "Remove used this shop"
	elif influence < 25:
		remove_btn.disabled = true
	remove_btn.pressed.connect(func(): _show_remove_dialog())
	btn_row.add_child(remove_btn)
	var cont_btn := Button.new()
	cont_btn.text = "Continue to Next Battle"
	cont_btn.custom_minimum_size = Vector2(200, 36)
	cont_btn.add_theme_font_size_override("font_size", 14)
	cont_btn.pressed.connect(func(): _continue_from_shop())
	btn_row.add_child(cont_btn)
	shop_popup.visible = true
	var vp: Vector2 = get_viewport_rect().size
	shop_popup.position = (vp - shop_popup.size) / 2.0
	shop_popup.position.y = max(8, shop_popup.position.y)

func _buy_shop_card(card: Card):
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return
	if gs.buy_card(card):
		human.Influence = gs.run_player.Influence
		_show_shop()
		_refresh_ui()

func _show_remove_dialog():
	var gs = get_node_or_null("/root/GameState")
	if gs == null or gs.run_player == null:
		return
	# Simple remove: show deck cards to remove
	_ensure_shop_popup()
	shop_popup.visible = false
	var dlg := PanelContainer.new()
	dlg.z_index = 106
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09,0.09,0.14,0.98)
	sb.border_color = Color(1,0.6,0.6,1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	dlg.add_theme_stylebox_override("panel", sb)
	dlg.custom_minimum_size = Vector2(700, 300)
	add_child(dlg)
	var vbox := VBoxContainer.new()
	dlg.add_child(vbox)
	var title := Label.new()
	title.text = "Choose a card to remove for 25 Influence (once per shop)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 6
	vbox.add_child(grid)
	var all_cards: Array = []
	for pile in [human.DrawPile, human.DiscardPile, human.Graveyard]:
		for c in pile:
			all_cards.append(c)
			if all_cards.size() >= 24:
				break
	for c in all_cards:
		var btn := Button.new()
		btn.text = c.card_name
		btn.custom_minimum_size = Vector2(100, 36)
		btn.add_theme_font_size_override("font_size", 11)
		var _c: Card = c
		btn.pressed.connect(func():
			var g2 = get_node_or_null("/root/GameState")
			if g2 != null and g2.remove_card_from_deck(_c):
				human.Influence = g2.run_player.Influence
				dlg.queue_free()
				_show_shop()
				_refresh_ui()
			else:
				message_label.text = "Cannot remove (already used or insufficient Influence)"
		)
		grid.add_child(btn)
	var close_btn := Button.new()
	close_btn.text = "Cancel"
	close_btn.pressed.connect(func(): dlg.queue_free(); _show_shop())
	vbox.add_child(close_btn)
	dlg.position = (get_viewport_rect().size - dlg.size) / 2.0
	dlg.visible = true

func _continue_from_shop():
	shop_popup.visible = false
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.run_started:
		# Clear boards for fresh battle — human board cleared, ai old board irrelevant
		_clear_board(human)
		# Do not clear next_enemy's board (it has starting placements); old ai_player board already empty after death
		var next_enemy: Player = gs.get_current_enemy()
		if next_enemy != null:
			ai_player = next_enemy
			state = CombatState.new(human, ai_player)
			_update_background()
			_start_new_round()
			# Re-enable end turn after shop → next battle (was disabled on victory)
			end_turn_btn.disabled = false
		else:
			message_label.text = "Run Complete! All enemies defeated! [Menu]"
			end_turn_btn.disabled = true
			shop_popup.visible = false
	else:
		shop_popup.visible = false
		_refresh_ui()
		end_turn_btn.disabled = false

func _start_new_round():
	# Economy phase for both — now owned by Player (via Housing.bio_rate)
	human.economy_phase()
	ai_player.economy_phase()
	# AI builds immediately — now owned by AIPlayer under Classes/AI
	ai_player.take_build_turn()
	selected_card = null
	selected_card_idx = -1
	message_label.text = "Your turn: play cards then press End Turn"
	_refresh_ui()
	_check_game_over()

func _refresh_ui():
	_hide_hover()
	# Show Influence in info labels per spec
	var gs_run = get_node_or_null("/root/GameState")
	if ai_info != null:
		if gs_run != null and gs_run.run_started:
			ai_info.text = "Influence: %d | Diff %d" % [ai_player.Influence, ai_player.Difficulty]
			ai_info.visible = true
		else:
			ai_info.text = ""
			ai_info.visible = false
	if player_info != null:
		player_info.text = "Influence: %d" % human.Influence
		player_info.visible = true
	else:
		ai_info.text = ""
		player_info.text = ""
	# Update flag art and labels for players (custom flags)
	if ai_label != null:
		ai_label.text = ai_player.display_name if ai_player.display_name != "" else "Euro Army"
	if player_label != null:
		player_label.text = human.display_name if human.display_name != "" else "State Troops"
	if ai_flag != null:
		var flag_path: String = "res://Assets/Players/%s/flag.png" % ai_player.display_name
		if ResourceLoader.exists(flag_path):
			var t := load(flag_path) as Texture2D
			if t != null:
				ai_flag.texture = t
		elif ResourceLoader.exists("res://Assets/Players/Euro Army/flag.png"):
			ai_flag.texture = load("res://Assets/Players/Euro Army/flag.png") as Texture2D
	if player_flag != null:
		var p_flag_path: String = "res://Assets/Players/%s/flag.png" % human.display_name
		if ResourceLoader.exists(p_flag_path):
			var pt := load(p_flag_path) as Texture2D
			if pt != null:
				player_flag.texture = pt
		elif ResourceLoader.exists("res://Assets/Players/State Troops/flag.png"):
			player_flag.texture = load("res://Assets/Players/State Troops/flag.png") as Texture2D
	# Vertical gauges: HP 0-100, Bio 0-200, Money 0-200 (clamped), white text, income on Money+Bio
	var ai_income: int = ai_player.total_money_income()
	var p_income: int = human.total_money_income()
	var ai_bio_inc: int = int(ai_player.BioSupply * Housing.bio_rate(ai_player) + 5 + 0.0001) - ai_player.BioSupply
	var p_bio_inc: int = int(human.BioSupply * Housing.bio_rate(human) + 5 + 0.0001) - human.BioSupply
	# AI gauges
	ai_hp_bar.max_value = 100
	ai_bio_bar.max_value = 200
	ai_money_bar.max_value = 200
	player_hp_bar.max_value = 100
	player_bio_bar.max_value = 200
	player_money_bar.max_value = 200
	ai_hp_bar.value = clamp(ai_player.HitPoints, 0, 100)
	ai_bio_bar.value = clamp(ai_player.BioSupply, 0, 200)
	ai_money_bar.value = clamp(ai_player.MoneySupply, 0, 200)
	player_hp_bar.value = clamp(human.HitPoints, 0, 100)
	player_bio_bar.value = clamp(human.BioSupply, 0, 200)
	player_money_bar.value = clamp(human.MoneySupply, 0, 200)
	ai_hp_value.text = "%d/%d" % [max(ai_player.HitPoints, 0), 100]
	ai_bio_value.text = "%d/%d" % [max(ai_player.BioSupply, 0), 200]
	ai_money_value.text = "%d/%d" % [max(ai_player.MoneySupply, 0), 200]
	player_hp_value.text = "%d/%d" % [max(human.HitPoints, 0), 100]
	player_bio_value.text = "%d/%d" % [max(human.BioSupply, 0), 200]
	player_money_value.text = "%d/%d" % [max(human.MoneySupply, 0), 200]
	# Income shown right on top of symbol (white) — Money +10+buildings, Bio 10%+5+4% per Housing
	ai_bio_income.text = "+%d" % ai_bio_inc
	player_bio_income.text = "+%d" % p_bio_inc
	ai_money_income.text = "+%d" % (10 + ai_income)
	player_money_income.text = "+%d" % (10 + p_income)
	# Deck / Discard / Graveyard gauges (33 max per updated spec, sprites under gauges / other side)
	for bar in [ai_deck_bar, player_deck_bar, ai_discard_bar, player_discard_bar, ai_graveyard_bar, player_graveyard_bar]:
		bar.max_value = 33
	ai_deck_bar.value = clamp(ai_player.DrawPile.size(), 0, 33)
	player_deck_bar.value = clamp(human.DrawPile.size(), 0, 33)
	ai_discard_bar.value = clamp(ai_player.DiscardPile.size(), 0, 33)
	player_discard_bar.value = clamp(human.DiscardPile.size(), 0, 33)
	ai_graveyard_bar.value = clamp(ai_player.Graveyard.size(), 0, 33)
	player_graveyard_bar.value = clamp(human.Graveyard.size(), 0, 33)
	ai_deck_value.text = "%d/33" % ai_player.DrawPile.size()
	player_deck_value.text = "%d/33" % human.DrawPile.size()
	ai_discard_value.text = "%d/33" % ai_player.DiscardPile.size()
	player_discard_value.text = "%d/33" % human.DiscardPile.size()
	ai_graveyard_value.text = "%d/33" % ai_player.Graveyard.size()
	player_graveyard_value.text = "%d/33" % human.Graveyard.size()
	# Pulse deck when low
	for pair in [[ai_deck_icon, ai_player.DrawPile.size()], [player_deck_icon, human.DrawPile.size()]]:
		pair[0].modulate = Color(1, 0.4, 0.4) if pair[1] <= 3 else Color(1, 1, 1)
	# tint based on low values for contrast (bar color)
	ai_hp_bar.tint_progress = Color(1, 0.35, 0.35) if ai_player.HitPoints < 30 else Color(1,1,1)
	player_hp_bar.tint_progress = Color(1, 0.35, 0.35) if human.HitPoints < 30 else Color(1,1,1)
	# Boards
	_refresh_board(ai_board_container, ai_player, false)
	_refresh_board(player_board_container, human, true)
	# Hand
	_refresh_hand()

func _refresh_board(container: GridContainer, player: Player, is_human: bool):
	_hide_hover()
	for child in container.get_children():
		child.queue_free()
	container.columns = 10
	for r in range(player.Board.size()):
		var row: Row = player.Board[r]
		for c in range(row.Squares.size()):
			var sq: Square = row.Squares[c]
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(78, 78)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
			if sq.Inhabitant == null:
				btn.text = ""
				btn.modulate = Color(0.12, 0.12, 0.18)
				btn.add_theme_font_size_override("font_size", 14)
				btn.add_theme_color_override("font_color", Color(1, 1, 1))
				if is_human:
					btn.pressed.connect(func(): _on_board_click(r, c))
				else:
					btn.disabled = true
				btn.tooltip_text = ""
			else:
				var card: Card = sq.Inhabitant
				var hp: int = 0
				var dmg: String = ""
				var is_unit: bool = card is Unit
				if is_unit:
					hp = (card as Unit).HitPoints
					dmg = "DMG:%d" % (card as Unit).Damage
				elif card is Building:
					hp = (card as Building).HitPoints
					dmg = "INC:%d" % (card as Building).Income
				btn.text = ""
				btn.icon = null
				btn.modulate = Color(1, 1, 1)
				btn.clip_contents = true
				var hbox := HBoxContainer.new()
				hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hbox.clip_contents = true
				hbox.alignment = BoxContainer.ALIGNMENT_CENTER
				hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
				var anim := Card.create_sprite_for(card.card_name, Vector2(90, 90))
				anim.clip_contents = true
				hbox.add_child(anim)
				var vbox := VBoxContainer.new()
				vbox.alignment = BoxContainer.ALIGNMENT_CENTER
				vbox.clip_contents = true
				vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
				vbox.custom_minimum_size = Vector2(0, 0)
				var name_lbl := Label.new()
				name_lbl.text = card.card_name
				name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				name_lbl.add_theme_font_size_override("font_size", 11)
				name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
				vbox.add_child(name_lbl)
				var stats := HBoxContainer.new()
				stats.alignment = BoxContainer.ALIGNMENT_BEGIN
				stats.clip_contents = true
				var hp_icon := TextureRect.new()
				hp_icon.texture = load("res://Assets/UI/heart.png") as Texture2D
				hp_icon.custom_minimum_size = Vector2(16, 16)
				hp_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				hp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				hp_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				stats.add_child(hp_icon)
				var hp_lbl := Label.new()
				hp_lbl.text = "%d" % hp
				hp_lbl.add_theme_font_size_override("font_size", 11)
				hp_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
				stats.add_child(hp_lbl)
				if is_unit:
					var sword_icon := TextureRect.new()
					sword_icon.texture = load("res://Assets/UI/sword.png") as Texture2D
					sword_icon.custom_minimum_size = Vector2(16, 16)
					sword_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					sword_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					sword_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					stats.add_child(sword_icon)
					var dmg_lbl := Label.new()
					dmg_lbl.text = "%d" % (card as Unit).Damage
					dmg_lbl.add_theme_font_size_override("font_size", 10)
					dmg_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
					stats.add_child(dmg_lbl)
				else:
					var dmg_lbl := Label.new()
					dmg_lbl.text = " " + dmg
					dmg_lbl.add_theme_font_size_override("font_size", 10)
					dmg_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
					stats.add_child(dmg_lbl)
				vbox.add_child(stats)
				hbox.add_child(vbox)
				btn.add_child(hbox)
				# Magnified preview on hover — art + symbols + text enlarged
				var _card_prev: Card = card
				btn.mouse_entered.connect(func(): _show_card_preview(_card_prev))
				btn.mouse_exited.connect(func(): _hide_card_preview())
				# Hover for special effect — custom popup + native tooltip fallback, no inline spill
				if card.SpecialEffect != "":
					btn.tooltip_text = card.SpecialEffect
					var _eff_txt: String = card.SpecialEffect
					btn.mouse_entered.connect(func(): _show_hover(_eff_txt))
					btn.mouse_exited.connect(func(): _hide_hover())
				else:
					btn.tooltip_text = ""
				# Keep enabled so hover shows (occupied squares are not clickable anyway)
				btn.disabled = false
				btn.mouse_filter = Control.MOUSE_FILTER_STOP
			container.add_child(btn)

func _refresh_hand():
	_hide_hover()
	for child in hand_container.get_children():
		child.queue_free()
	for idx in range(human.Hand.size()):
		var card: Card = human.Hand[idx]
		var btn := Button.new()
		btn.clip_contents = true
		btn.custom_minimum_size = Vector2(108, 68)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var hp: int = 0
		var extra: String = ""
		if card is Unit:
			hp = (card as Unit).HitPoints
			extra = "DMG %d" % (card as Unit).Damage
		elif card is Building:
			hp = (card as Building).HitPoints
			extra = "INC %d" % (card as Building).Income
		btn.text = ""
		# Right-side layout: sprite left | details right (uses empty right space efficiently, no overflow)
		var hand_hbox := HBoxContainer.new()
		hand_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hand_hbox.clip_contents = true
		hand_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hand_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hand_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var hand_anim := Card.create_sprite_for(card.card_name, Vector2(72, 72))
		hand_anim.clip_contents = true
		hand_hbox.add_child(hand_anim)
		var details := VBoxContainer.new()
		details.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.clip_contents = true
		details.alignment = BoxContainer.ALIGNMENT_CENTER
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hand_hbox.add_child(details)
		var hand_name := Label.new()
		hand_name.text = card.card_name
		hand_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hand_name.add_theme_font_size_override("font_size", 11)
		hand_name.add_theme_color_override("font_color", Color(1, 1, 1))
		details.add_child(hand_name)
		var hand_stats := HBoxContainer.new()
		hand_stats.alignment = BoxContainer.ALIGNMENT_BEGIN
		hand_stats.clip_contents = true
		var h_heart := TextureRect.new()
		h_heart.texture = load("res://Assets/UI/heart.png") as Texture2D
		h_heart.custom_minimum_size = Vector2(16, 16)
		h_heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h_heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h_heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hand_stats.add_child(h_heart)
		var h_hp := Label.new()
		h_hp.text = "%d" % hp
		h_hp.add_theme_font_size_override("font_size", 10)
		h_hp.add_theme_color_override("font_color", Color(1, 1, 1))
		hand_stats.add_child(h_hp)
		if card is Unit:
			var h_sword := TextureRect.new()
			h_sword.texture = load("res://Assets/UI/sword.png") as Texture2D
			h_sword.custom_minimum_size = Vector2(16, 16)
			h_sword.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			h_sword.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			h_sword.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			hand_stats.add_child(h_sword)
			var h_dmg := Label.new()
			h_dmg.text = "%d" % (card as Unit).Damage
			h_dmg.add_theme_font_size_override("font_size", 10)
			h_dmg.add_theme_color_override("font_color", Color(1, 1, 1))
			hand_stats.add_child(h_dmg)
		else:
			var h_inc := Label.new()
			h_inc.text = " " + extra
			h_inc.add_theme_font_size_override("font_size", 9)
			h_inc.add_theme_color_override("font_color", Color(1, 1, 1))
			hand_stats.add_child(h_inc)
		details.add_child(hand_stats)
		var hand_costs := HBoxContainer.new()
		hand_costs.alignment = BoxContainer.ALIGNMENT_BEGIN
		hand_costs.clip_contents = true
		var m_icon := TextureRect.new()
		m_icon.texture = load("res://Assets/UI/money_icon.png") as Texture2D
		m_icon.custom_minimum_size = Vector2(14, 14)
		m_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		m_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		m_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hand_costs.add_child(m_icon)
		var m_lbl := Label.new()
		m_lbl.text = "%d" % card.MoneyCost
		m_lbl.add_theme_font_size_override("font_size", 9)
		m_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		hand_costs.add_child(m_lbl)
		var b_icon := TextureRect.new()
		b_icon.texture = load("res://Assets/UI/bio_icon.png") as Texture2D
		b_icon.custom_minimum_size = Vector2(14, 14)
		b_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		b_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hand_costs.add_child(b_icon)
		var b_lbl := Label.new()
		b_lbl.text = "%d" % card.BioCost
		b_lbl.add_theme_font_size_override("font_size", 9)
		b_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		hand_costs.add_child(b_lbl)
		details.add_child(hand_costs)
		# Magnified preview on hover — hand card art + symbols + text enlarged
		var _hand_prev: Card = card
		btn.mouse_entered.connect(func(): _show_card_preview(_hand_prev))
		btn.mouse_exited.connect(func(): _hide_card_preview())
		# Hover — custom popup + tooltip fallback, no inline label
		if card.SpecialEffect != "":
			btn.tooltip_text = card.SpecialEffect
			var _eff2_txt: String = card.SpecialEffect
			btn.mouse_entered.connect(func(): _show_hover(_eff2_txt))
			btn.mouse_exited.connect(func(): _hide_hover())
		else:
			btn.tooltip_text = ""
		btn.add_child(hand_hbox)
		if idx == selected_card_idx:
			btn.modulate = Color(1, 1, 1)
			btn.add_theme_font_size_override("font_size", 14)
			btn.add_theme_color_override("font_color", Color(1, 1, 1))
		elif human.get_effective_money_cost(card) > human.MoneySupply or human.BioSupply < card.BioCost:
			btn.modulate = Color(1, 0.45, 0.45)
			btn.add_theme_font_size_override("font_size", 14)
			btn.add_theme_color_override("font_color", Color(1, 1, 1))
			# keep enabled so tooltip still shows on hover (was disabled, blocked hover)
		else:
			btn.modulate = Color(1, 1, 1)
			btn.add_theme_font_size_override("font_size", 14)
			btn.add_theme_color_override("font_color", Color(1, 1, 1))
		var captured_idx: int = idx
		btn.pressed.connect(func(): _on_hand_click(captured_idx))
		hand_container.add_child(btn)
	if human.Hand.is_empty():
		var lbl := Label.new()
		lbl.text = "(Hand empty)"
		hand_container.add_child(lbl)

func _on_hand_click(idx: int):
	if idx < 0 or idx >= human.Hand.size():
		return
	if selected_card_idx == idx:
		selected_card = null
		selected_card_idx = -1
		message_label.text = "Deselected"
	else:
		selected_card = human.Hand[idx]
		selected_card_idx = idx
		message_label.text = "Selected %s - click empty square to place" % selected_card.card_name
	_refresh_hand()

func _on_board_click(r: int, c: int):
	if selected_card == null:
		message_label.text = "Select a card first"
		return
	var ok: bool = human.play_card(selected_card, r, c)
	if ok:
		message_label.text = "Placed %s at [%d,%d]" % [selected_card.card_name, r, c]
		selected_card = null
		selected_card_idx = -1
	else:
		message_label.text = "Cannot place there (cost or occupied)"
	_refresh_ui()

func _on_end_turn():
	end_turn_btn.disabled = true
	# Combat phase with simple per-attack animation: highlight attacker → target
	var log: Array = state.combat_phase()
	if log.is_empty():
		message_label.text = "No attacks this turn"
	else:
		message_label.text = "Combat: %d attacks..." % log.size()
		await _animate_combat(log)
	# Discard remaining hand — now owned by Player
	human.discard_hand()
	ai_player.discard_hand()
	_refresh_ui()
	# Check win
	if _check_game_over():
		return
	# Next round
	_start_new_round()
	end_turn_btn.disabled = false

func _get_button_for_square(player: Player, square: Square) -> Button:
	var container: GridContainer = ai_board_container if player == ai_player else player_board_container
	# Squares are stored row-major 4x10, buttons are added same order
	for r in range(player.Board.size()):
		var row: Row = player.Board[r]
		for c in range(row.Squares.size()):
			if row.Squares[c] == square:
				var idx: int = r * 10 + c
				if idx < container.get_child_count():
					return container.get_child(idx) as Button
	return null

func _animate_combat(log: Array):
	for entry in log:
		var attacker_sq: Square = entry["attacker_sq"]
		var attacker_player: Player = entry["attacker_player"]
		var defender: Player = entry["defender"]
		var target_sq: Square = entry["target_sq"]
		var dmg: int = entry["damage"]
		var is_direct: bool = entry["is_direct"]
		var attacker_card: Card = entry["attacker"]
		var target_card: Card = entry["target"]
		# Resolve buttons (may be null if board refreshed — use current containers)
		var atk_btn: Button = _get_button_for_square(attacker_player, attacker_sq)
		var tgt_btn: Button = null if is_direct else _get_button_for_square(defender, target_sq)
		var tgt_hp_bar: TextureProgressBar = ai_hp_bar if defender == ai_player else player_hp_bar
		# Barracks aura: show +2 buff on attacker if adjacent to Barracks
		if attacker_card is Unit and Barracks.bonus_if_adjacent(attacker_player, attacker_sq) > 0:
			if atk_btn != null:
				_spawn_special_effect(atk_btn, "barracks_aura")
		# Highlight attacker: scale pulse + yellow tint
		if atk_btn != null:
			var tw := create_tween()
			tw.tween_property(atk_btn, "scale", Vector2(1.08, 1.08), 0.12)
			tw.tween_property(atk_btn, "modulate", Color(1, 0.95, 0.4), 0.12)
			tw.tween_property(atk_btn, "scale", Vector2(1.0, 1.0), 0.12)
			tw.tween_property(atk_btn, "modulate", Color(1, 1, 1), 0.12)
			message_label.text = "%s attacks %s for %d" % [attacker_card.card_name, "HP" if is_direct else target_card.card_name, dmg]
		await get_tree().create_timer(0.22).timeout
		# Highlight target
		if is_direct:
			var tw2 := create_tween()
			tw2.tween_property(tgt_hp_bar, "modulate", Color(1, 0.4, 0.4), 0.12)
			tw2.tween_property(tgt_hp_bar, "modulate", Color(1, 1, 1), 0.12)
			# Spawn floating damage number over HP bar
			_spawn_damage_number(tgt_hp_bar, dmg)
		elif tgt_btn != null:
			var tw2 := create_tween()
			tw2.tween_property(tgt_btn, "modulate", Color(1, 0.35, 0.35), 0.10)
			tw2.tween_property(tgt_btn, "position", tgt_btn.position + Vector2(4, 0), 0.05)
			tw2.tween_property(tgt_btn, "position", tgt_btn.position, 0.05)
			tw2.tween_property(tgt_btn, "modulate", Color(1, 1, 1), 0.10)
			_spawn_damage_number(tgt_btn, dmg)
			# Fighter Jet splash: spawn explosion on adjacent tiles
			if attacker_card is FighterJet:
				var adj_sqs: Array = _get_adjacent_squares(defender, target_sq)
				for adj_sq in adj_sqs:
					var adj_btn: Button = _get_button_for_square(defender, adj_sq)
					if adj_btn != null and adj_sq.Inhabitant != null:
						_spawn_special_effect(adj_btn, "fighter_jet_splash")
				# also spawn on main target for splash center
				_spawn_special_effect(tgt_btn, "fighter_jet_splash")
		await get_tree().create_timer(0.32).timeout
	# Brief pause then refresh to show updated HP / deaths
	await get_tree().create_timer(0.15).timeout
	_refresh_ui()

func _get_adjacent_squares(player: Player, center: Square) -> Array:
	var res: Array = []
	var pos = null
	for r in range(player.Board.size()):
		for c in range(player.Board[r].Squares.size()):
			if player.Board[r].Squares[c] == center:
				pos = {"r": r, "c": c}
				break
		if pos != null:
			break
	if pos == null:
		return res
	for dr in [-1,0,1]:
		for dc in [-1,0,1]:
			if dr==0 and dc==0:
				continue
			var nr: int = pos["r"]+dr
			var nc: int = pos["c"]+dc
			if nr<0 or nr>=player.Board.size():
				continue
			if nc<0 or nc>=10:
				continue
			res.append((player.Board[nr] as Row).Squares[nc])
	return res

func _spawn_special_effect(anchor: Control, kind: String):
	var tex_path: String = "res://Assets/Effects/%s.png" % kind
	if not ResourceLoader.exists(tex_path):
		# fallback to single frame if animated not found
		return
	var tex: Texture2D = load(tex_path) as Texture2D
	if tex == null:
		return
	var spr := TextureRect.new()
	spr.texture = tex
	spr.custom_minimum_size = Vector2(64, 64)
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spr.modulate = Color(1,1,1,0.95)
	# center over anchor
	anchor.add_child(spr)
	spr.position = Vector2(anchor.size.x*0.5 -32, anchor.size.y*0.5 -32)
	spr.z_index = 50
	var tw := create_tween()
	tw.tween_property(spr, "scale", Vector2(1.15,1.15), 0.12)
	tw.tween_property(spr, "modulate", Color(1,1,1,0), 0.35)
	tw.tween_callback(func(): spr.queue_free())
	# try animated frames if exist: fighter_jet_splash_0..7 / barracks_aura_0..7
	if kind == "fighter_jet_splash" or kind == "barracks_aura":
		var frames: Array = []
		for i in range(8):
			var p: String = "res://Assets/Effects/%s_%d.png" % [kind, i]
			if ResourceLoader.exists(p):
				frames.append(load(p) as Texture2D)
		if frames.size() > 1:
			var idx: int = 0
			var timer := get_tree().create_timer(0.06)
			# simple frame cycling via tween callback
			for f in frames:
				var f_tex: Texture2D = f
				create_tween().tween_callback(func(): if is_instance_valid(spr): spr.texture = f_tex).set_delay(idx*0.06)
				idx+=1

func _spawn_damage_number(anchor: Control, dmg: int):
	var lbl := Label.new()
	lbl.text = "-%d" % dmg
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1, 0.25, 0.25))
	lbl.z_index = 100
	# Place over anchor
	anchor.add_child(lbl)
	lbl.position = Vector2(anchor.size.x * 0.5 - 10, -8)
	var tw := create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -18), 0.45)
	tw.parallel().tween_property(lbl, "modulate", Color(1, 0.25, 0.25, 0), 0.45)
	tw.tween_callback(func(): lbl.queue_free())

func _inspect_pile(title: String, pile: Array):
	inspect_title.text = "%s (%d)" % [title, pile.size()]
	# Clear previous grid
	for child in inspect_grid.get_children():
		child.queue_free()
	if pile.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "(empty)"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		inspect_grid.add_child(empty_lbl)
	else:
		for card in pile:
			var cname: String = card.card_name if card is Card else str(card)
			var cell := VBoxContainer.new()
			cell.alignment = BoxContainer.ALIGNMENT_CENTER
			cell.clip_contents = true
			cell.custom_minimum_size = Vector2(64, 72)
			# Card art (8-bit, same as board/hand)
			var art := Card.create_sprite_for(cname, Vector2(56, 56))
			art.clip_contents = true
			cell.add_child(art)
			var lbl := Label.new()
			lbl.text = cname
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.add_theme_color_override("font_color", Color(1, 1, 1))
			cell.add_child(lbl)
			if card is Card and (card as Card).SpecialEffect != "":
				var eff3 := Label.new()
				eff3.text = (card as Card).SpecialEffect
				eff3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				eff3.clip_contents = true
				eff3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				eff3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				eff3.custom_minimum_size = Vector2(0, 0)
				eff3.add_theme_font_size_override("font_size", 8)
				eff3.add_theme_color_override("font_color", Color(1, 1, 1))
				cell.add_child(eff3)
			inspect_grid.add_child(cell)
	inspect_popup.visible = true

func _check_game_over() -> bool:
	var gs = get_node_or_null("/root/GameState")
	var is_run: bool = gs != null and gs.run_started
	if human.HitPoints <= 0 and ai_player.HitPoints <= 0:
		message_label.text = "Draw! Both fell. [Menu] to restart"
		end_turn_btn.disabled = true
		return true
	elif ai_player.HitPoints <= 0:
		if is_run:
			var gained: int = ai_player.Influence
			# Gain starting influence per Main Game Rules
			gs.gain_influence(gained)
			human.Influence = gs.run_player.Influence
			message_label.text = "VICTORY! Defeated %s! Gained %d Influence. Influence: %d" % [ai_player.display_name, gained, human.Influence]
			# Prepare next enemy index (next battle)
			gs.advance_enemy()
			if gs.is_run_complete():
				message_label.text += " — RUN COMPLETE! All enemies defeated! [Menu]"
				end_turn_btn.disabled = true
				_refresh_ui()
				return true
			else:
				# Show shop between battles
				_refresh_ui()
				_show_shop()
				end_turn_btn.disabled = true
				return true
		else:
			message_label.text = "VICTORY! AI defeated. [Menu] to restart"
			end_turn_btn.disabled = true
			return true
	elif human.HitPoints <= 0:
		message_label.text = "DEFEAT! You fell. [Menu] to restart"
		end_turn_btn.disabled = true
		if is_run:
			gs.run_started = false
		return true
	return false
