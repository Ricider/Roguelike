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
var preview_popup: PanelContainer
var preview_built: bool = false

func _ready():
	human = Player.new(100, 100, 20, 0, "JohnDoe")
	# Enemy is Euro Army per updated spec (was Insurgents)
	ai_player = CardFactory.make_euro_army_player()
	# Fallback: if called via manual AIPlayer still set display names
	human.display_name = "JohnDoe"
	ai_player.display_name = "Euro Army"
	human.DrawPile = CardFactory.make_starting_deck()
	# Euro Army deck already set in factory, but ensure shuffle
	# Keep Euro Army board placement (2 Housing +1 Factory already placed)
	state = CombatState.new(human, ai_player)
	end_turn_btn.pressed.connect(_on_end_turn)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	close_btn.pressed.connect(func(): inspect_popup.visible = false)
	hover_popup.visible = false
	# Hide hover when inspecting or ending turn
	hover_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_preview_popup()
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
	ai_info.text = ""
	player_info.text = ""
	ai_info.visible = false
	player_info.visible = false
	# Update flag art and labels for players (custom flags)
	if ai_label != null:
		ai_label.text = ai_player.display_name if ai_player.display_name != "" else "Euro Army"
	if player_label != null:
		player_label.text = human.display_name if human.display_name != "" else "JohnDoe"
	if ai_flag != null:
		var euro_tex := load("res://Assets/Players/Euro Army/flag.png") as Texture2D
		if euro_tex != null:
			ai_flag.texture = euro_tex
	if player_flag != null:
		var john_tex := load("res://Assets/Players/JohnDoe/flag.png") as Texture2D
		if john_tex != null:
			player_flag.texture = john_tex
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
		elif human.MoneySupply < card.MoneyCost or human.BioSupply < card.BioCost:
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
		await get_tree().create_timer(0.32).timeout
	# Brief pause then refresh to show updated HP / deaths
	await get_tree().create_timer(0.15).timeout
	_refresh_ui()

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
	if human.HitPoints <= 0 and ai_player.HitPoints <= 0:
		message_label.text = "Draw! Both fell. [Menu] to restart"
		end_turn_btn.disabled = true
		return true
	elif ai_player.HitPoints <= 0:
		message_label.text = "VICTORY! AI defeated. [Menu] to restart"
		end_turn_btn.disabled = true
		return true
	elif human.HitPoints <= 0:
		message_label.text = "DEFEAT! You fell. [Menu] to restart"
		end_turn_btn.disabled = true
		return true
	return false
