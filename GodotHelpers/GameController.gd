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
var debug_summon_card_option: OptionButton
var debug_summon_target_option: OptionButton
var shop_popup: PanelContainer
var shop_built: bool = false
var influence_value_label: Label
var influence_icon_rect: TextureRect

func _style_round_button(btn: Button, primary: bool = true):
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18,0.18,0.27,1) if primary else Color(0.14,0.14,0.20,1)
	sb.border_color = Color(0.95,0.85,0.4,1) if primary else Color(0.35,0.35,0.45,0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0,0,0,0.35)
	sb.shadow_size = 5
	sb.shadow_offset = Vector2(0,2)
	btn.add_theme_stylebox_override("normal", sb)
	var sb_h := StyleBoxFlat.new()
	sb_h.bg_color = Color(0.24,0.24,0.34,1) if primary else Color(0.20,0.20,0.28,1)
	sb_h.border_color = Color(1,0.92,0.55,1)
	sb_h.set_border_width_all(2)
	sb_h.set_corner_radius_all(16)
	sb_h.content_margin_left = 12
	sb_h.content_margin_right = 12
	sb_h.content_margin_top = 6
	sb_h.content_margin_bottom = 6
	sb_h.shadow_color = Color(0,0,0,0.45)
	sb_h.shadow_size = 6
	btn.add_theme_stylebox_override("hover", sb_h)
	var sb_p := StyleBoxFlat.new()
	sb_p.bg_color = Color(0.12,0.12,0.18,1)
	sb_p.border_color = sb.border_color
	sb_p.set_border_width_all(2)
	sb_p.set_corner_radius_all(16)
	sb_p.content_margin_left = 12
	sb_p.content_margin_right = 12
	sb_p.content_margin_top = 6
	sb_p.content_margin_bottom = 6
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_stylebox_override("focus", sb_h)
	btn.add_theme_color_override("font_color", Color(1,1,1))
	if not primary:
		btn.add_theme_color_override("font_color", Color(0.92,0.92,0.95))

func _move_player_piles_to_bottom():
	# Bottom-right vertical: hide opponent piles, keep player discard/graveyard vertically
	var right_content = get_node_or_null("VBox/MainHBox/RightContent")
	var right_gauges = get_node_or_null("VBox/MainHBox/RightGauges")
	var left_gauges = get_node_or_null("VBox/MainHBox/LeftGauges")
	if right_gauges == null:
		return
	# Hide opponent piles: AIDeck (left), AIDiscard, AIGraveyard (right)
	if left_gauges != null:
		var ai_deck = left_gauges.get_node_or_null("AIDeck")
		if ai_deck != null:
			ai_deck.visible = false
	var ai_discard = right_gauges.get_node_or_null("AIDiscard")
	if ai_discard != null:
		ai_discard.visible = false
	var ai_graveyard = right_gauges.get_node_or_null("AIGraveyard")
	if ai_graveyard != null:
		ai_graveyard.visible = false
	# Clean up old centered bottom container if it exists from previous bottom-center version
	if right_content != null:
		var old_bottom = right_content.get_node_or_null("PlayerPilesBottom")
		if old_bottom != null:
			for child in old_bottom.get_children():
				if child.name == "PlayerDiscard" or child.name == "PlayerGraveyard":
					old_bottom.remove_child(child)
					right_gauges.add_child(child)
			old_bottom.queue_free()
	var player_discard = right_gauges.get_node_or_null("PlayerDiscard")
	var player_graveyard = right_gauges.get_node_or_null("PlayerGraveyard")
	if player_discard == null:
		if right_content != null:
			var ob = right_content.get_node_or_null("PlayerPilesBottom")
			if ob != null:
				player_discard = ob.get_node_or_null("PlayerDiscard")
	if player_graveyard == null:
		if right_content != null:
			var ob = right_content.get_node_or_null("PlayerPilesBottom")
			if ob != null:
				player_graveyard = ob.get_node_or_null("PlayerGraveyard")
	if player_discard == null or player_graveyard == null:
		return
	# Ensure RightGauges pushes player piles to bottom: add expanding spacer at top if missing
	var top_spacer = right_gauges.get_node_or_null("TopPushSpacer")
	if top_spacer == null:
		top_spacer = Control.new()
		top_spacer.name = "TopPushSpacer"
		top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		top_spacer.custom_minimum_size = Vector2(0, 0)
		right_gauges.add_child(top_spacer)
		right_gauges.move_child(top_spacer, 0)
	# Create bottom-right vertical column inside RightGauges
	var bottom = right_gauges.get_node_or_null("PlayerPilesBottomRight")
	if bottom == null:
		bottom = VBoxContainer.new()
		bottom.name = "PlayerPilesBottomRight"
		bottom.alignment = BoxContainer.ALIGNMENT_CENTER
		bottom.add_theme_constant_override("separation", 8)
		bottom.custom_minimum_size = Vector2(124, 0)
		right_gauges.add_child(bottom)
	# Ensure bottom is last and visible
	bottom.visible = true
	right_gauges.move_child(bottom, right_gauges.get_child_count() - 1)
	if player_discard.get_parent() != bottom:
		var old_p = player_discard.get_parent()
		if old_p != null:
			old_p.remove_child(player_discard)
		bottom.add_child(player_discard)
		player_discard.visible = true
	if player_graveyard.get_parent() != bottom:
		var old_p2 = player_graveyard.get_parent()
		if old_p2 != null:
			old_p2.remove_child(player_graveyard)
		bottom.add_child(player_graveyard)
		player_graveyard.visible = true
	# Also ensure player deck (draw) stays visible on left as HQ
	if left_gauges != null:
		var pd = left_gauges.get_node_or_null("PlayerDeck")
		if pd != null:
			pd.visible = true
	# Hide old spacer and discard label gaps
	var spacer = right_gauges.get_node_or_null("Spacer2")
	if spacer != null:
		spacer.visible = false
	var disc_lbl = right_gauges.get_node_or_null("DiscardLabel")
	if disc_lbl != null:
		disc_lbl.visible = false

func _hide_hand_label():
	var hl = get_node_or_null("VBox/MainHBox/RightContent/HandLabel")
	if hl != null:
		hl.visible = false
		hl.text = ""

func _setup_influence_at_draw_pile():
	var left = get_node_or_null("VBox/MainHBox/LeftGauges")
	var pd = get_node_or_null("VBox/MainHBox/LeftGauges/PlayerDeck")
	if left == null or pd == null:
		return
	# Hide old player_info (was center)
	var old_info = get_node_or_null("VBox/MainHBox/RightContent/PlayerInfo")
	if old_info != null:
		old_info.visible = false
	# Create bottom row HBox at very bottom of left column, right side of draw pile
	var bottom_row = left.get_node_or_null("BottomRow")
	if bottom_row == null:
		bottom_row = HBoxContainer.new()
		bottom_row.name = "BottomRow"
		bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
		bottom_row.add_theme_constant_override("separation", 10)
		left.add_child(bottom_row)
		# Move PlayerDeck into bottom row (keep its VBox vertical)
		if pd.get_parent() == left:
			left.remove_child(pd)
			bottom_row.add_child(pd)
		# Create influence box to the right of draw pile, at very bottom
		var inf_box := HBoxContainer.new()
		inf_box.name = "InfluenceBox"
		inf_box.alignment = BoxContainer.ALIGNMENT_CENTER
		inf_box.add_theme_constant_override("separation", 6)
		inf_box.custom_minimum_size = Vector2(80, 78)
		inf_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var v_inf := VBoxContainer.new()
		v_inf.alignment = BoxContainer.ALIGNMENT_CENTER
		v_inf.add_theme_constant_override("separation", 2)
		inf_box.add_child(v_inf)
		var lbl := Label.new()
		lbl.text = "Influence"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(1,0.92,0.5,1))
		v_inf.add_child(lbl)
		var h_row := HBoxContainer.new()
		h_row.alignment = BoxContainer.ALIGNMENT_CENTER
		h_row.add_theme_constant_override("separation", 4)
		v_inf.add_child(h_row)
		influence_icon_rect = TextureRect.new()
		influence_icon_rect.texture = load("res://Assets/UI/influence_icon.png") as Texture2D
		influence_icon_rect.custom_minimum_size = Vector2(28,28)
		influence_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		influence_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		influence_icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		h_row.add_child(influence_icon_rect)
		influence_value_label = Label.new()
		influence_value_label.text = "%d" % human.Influence
		influence_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		influence_value_label.add_theme_font_size_override("font_size", 26)
		influence_value_label.add_theme_color_override("font_color", Color(1,1,1))
		h_row.add_child(influence_value_label)
		bottom_row.add_child(inf_box)
	else:
		# Already exists, just ensure influence label exists
		var ib = bottom_row.get_node_or_null("InfluenceBox")
		if ib != null:
			influence_value_label = ib.get_node_or_null("VBox/HBox/Label") as Label
			if influence_value_label == null:
				# fallback find by recursion
				influence_value_label = _find_influence_label(ib)
	_refresh_influence_display()

func _find_influence_label(node: Node) -> Label:
	for c in node.get_children():
		if c is Label and c.text != "Influence":
			return c as Label
		var r := _find_influence_label(c)
		if r != null:
			return r
	return null

func _setup_gauge_and_influence_hovers():
	# Gauge + influence tooltips: click-through, inside window, always on top via _show_hover
	var hp_tip: String = "Hit Points — when a card dies its owner loses HP equal to its BioSupply cost; at 0 you lose"
	var bio_tip: String = "BioSupply — pay BioCost to play cards; grows 10% +5 each Economy phase (+4% per Housing)"
	var money_tip: String = "MoneySupply — pay MoneyCost to play cards; grows +10 + building Income each turn"
	var inf_tip: String = "Influence — spend between battles in the Shop (5 cards offered, or 25 to remove a card)"
	# Helper to bind hover to any Control without duplicating connections
	var bind := func(node: Control, text: String):
		if node == null:
			return
		# make container itself not block clicks to gauges? gauges are non-interactive, but we still want hover
		# Keep STOP for hover detection, but popups themselves are IGNORE
		node.mouse_filter = Control.MOUSE_FILTER_STOP
		# avoid double-connect
		if node.has_meta("hover_bound"):
			return
		node.set_meta("hover_bound", true)
		# single custom hover popup only (no native single-line tooltip)
		var t: String = text
		node.mouse_entered.connect(func(): _show_hover(t))
		node.mouse_exited.connect(func(): _hide_hover())
	# Player + AI gauges (6 total)
	var ai_hp_box := get_node_or_null("VBox/MainHBox/LeftGauges/AIGauges/AIGaugeHP") as Control
	var ai_bio_box := get_node_or_null("VBox/MainHBox/LeftGauges/AIGauges/AIGaugeBio") as Control
	var ai_money_box := get_node_or_null("VBox/MainHBox/LeftGauges/AIGauges/AIGaugeMoney") as Control
	var p_hp_box := get_node_or_null("VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeHP") as Control
	var p_bio_box := get_node_or_null("VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeBio") as Control
	var p_money_box := get_node_or_null("VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeMoney") as Control
	bind.call(ai_hp_box, "AI " + hp_tip)
	bind.call(ai_bio_box, "AI " + bio_tip)
	bind.call(ai_money_box, "AI " + money_tip)
	bind.call(p_hp_box, hp_tip)
	bind.call(p_bio_box, bio_tip)
	bind.call(p_money_box, money_tip)
	# Also bind icons/bars themselves so hover works even if container has gaps — per-gauge tip
	var gauge_pairs: Array = [
		[ai_hp_box, "AI " + hp_tip],
		[ai_bio_box, "AI " + bio_tip],
		[ai_money_box, "AI " + money_tip],
		[p_hp_box, hp_tip],
		[p_bio_box, bio_tip],
		[p_money_box, money_tip],
	]
	for pair in gauge_pairs:
		var n: Control = pair[0] as Control
		var tip: String = pair[1] as String
		if n != null:
			for child in n.get_children():
				if child is Control:
					bind.call(child as Control, tip)
	# Influence symbol (icon + value) — bind to the whole InfluenceBox
	var left := get_node_or_null("VBox/MainHBox/LeftGauges") as Control
	var bottom_row := left.get_node_or_null("BottomRow") as Control if left != null else null
	var inf_box := bottom_row.get_node_or_null("InfluenceBox") as Control if bottom_row != null else null
	if inf_box != null:
		bind.call(inf_box, inf_tip)
		for child in inf_box.get_children():
			if child is Control:
				bind.call(child as Control, inf_tip)
				for grand in (child as Control).get_children():
					if grand is Control:
						bind.call(grand as Control, inf_tip)
	# Fallback direct icons if InfluenceBox not yet built (will be retried next refresh)
	if influence_icon_rect != null:
		bind.call(influence_icon_rect, inf_tip)
	if influence_value_label != null:
		bind.call(influence_value_label as Control, inf_tip)

func _refresh_influence_display():
	if influence_value_label != null and is_instance_valid(influence_value_label):
		influence_value_label.text = "%d" % human.Influence
	# Also hide old info if still visible
	var old_info2 = get_node_or_null("VBox/MainHBox/RightContent/PlayerInfo")
	if old_info2 != null:
		old_info2.visible = false
	# keep influence hover bound after display refresh (in case it was recreated)
	_setup_gauge_and_influence_hovers()

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
	_style_round_button(end_turn_btn, true)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	_style_round_button(menu_btn, false)
	close_btn.pressed.connect(func(): inspect_popup.visible = false)
	_style_round_button(close_btn, false)
	hover_popup.visible = false
	# Hover popup: click-through, inside window, always on top
	hover_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_popup.z_index = 200
	hover_popup.z_as_relative = false
	if hover_popup.has_method("set_as_top_level"):
		hover_popup.top_level = true
	for c in hover_popup.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_preview_popup()
	_ensure_debug_popup()
	_add_debug_button()
	_ensure_shop_popup()
	_setup_gauge_and_influence_hovers()
	player_deck_icon.pressed.connect(func(): _inspect_pile("Your Draw Pile", human.DrawPile))
	ai_deck_icon.pressed.connect(func(): _inspect_pile("AI Draw Pile", ai_player.DrawPile))
	player_discard_icon.pressed.connect(func(): _inspect_pile("Your Discard Pile", human.DiscardPile))
	ai_discard_icon.pressed.connect(func(): _inspect_pile("AI Discard Pile", ai_player.DiscardPile))
	player_graveyard_icon.pressed.connect(func(): _inspect_pile("Your Graveyard", human.Graveyard))
	ai_graveyard_icon.pressed.connect(func(): _inspect_pile("AI Graveyard", ai_player.Graveyard))
	_start_new_round()
	_move_player_piles_to_bottom()
	_setup_influence_at_draw_pile()
	_hide_hand_label()

func _show_hover(text: String):
	if text == "":
		return
	hover_label.text = text
	hover_popup.visible = true
	# click-through, inside window, always on top
	hover_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_popup.z_index = 200
	hover_popup.z_as_relative = false
	if hover_popup.has_method("set_as_top_level"):
		hover_popup.top_level = true
	# position near mouse, clamped to viewport so it never spills
	var vp: Vector2 = get_viewport_rect().size
	var pos: Vector2 = get_global_mouse_position() + Vector2(14, -36)
	var sz: Vector2 = hover_popup.size
	if sz.x < 40:
		sz = Vector2(240, 70)
	pos.x = clamp(pos.x, 4.0, max(4.0, vp.x - sz.x - 4.0))
	pos.y = clamp(pos.y, 4.0, max(4.0, vp.y - sz.y - 4.0))
	hover_popup.global_position = pos
	for c in hover_popup.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ensure_preview_popup():
	if preview_built:
		return
	preview_popup = PanelContainer.new()
	preview_popup.visible = false
	preview_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_popup.z_index = 201
	preview_popup.z_as_relative = false
	if preview_popup.has_method("set_as_top_level"):
		preview_popup.top_level = true
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
	name_lbl.add_theme_font_size_override("font_size", 34)
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
	grid.clip_contents = false
	grid.add_theme_constant_override("separation", 10)
	details.add_child(grid)
	var left_stats := HBoxContainer.new()
	left_stats.alignment = BoxContainer.ALIGNMENT_BEGIN
	left_stats.clip_contents = false
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
	hp_lbl.add_theme_font_size_override("font_size", 30)
	hp_lbl.add_theme_color_override("font_color", Color(1,1,1))
	hp_lbl.clip_contents = false
	hp_lbl.custom_minimum_size = Vector2(0, 30)
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
		dmg_lbl.add_theme_font_size_override("font_size", 30)
		dmg_lbl.add_theme_color_override("font_color", Color(1,1,1))
		dmg_lbl.clip_contents = false
		dmg_lbl.custom_minimum_size = Vector2(0, 30)
		left_stats.add_child(dmg_lbl)
	else:
		var inc_icon := TextureRect.new()
		inc_icon.texture = load("res://Assets/UI/income_icon.png") as Texture2D
		inc_icon.custom_minimum_size = Vector2(24, 24)
		inc_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		inc_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		inc_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		left_stats.add_child(inc_icon)
		var inc_lbl := Label.new()
		inc_lbl.text = "%d" % (card as Building).Income
		inc_lbl.add_theme_font_size_override("font_size", 26)
		inc_lbl.add_theme_color_override("font_color", Color(1,1,1))
		inc_lbl.clip_contents = false
		inc_lbl.custom_minimum_size = Vector2(0, 30)
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
	m_lbl.add_theme_font_size_override("font_size", 26)
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
	b_lbl.add_theme_font_size_override("font_size", 26)
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
	eff.add_theme_font_size_override("font_size", 22)
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
		elif ai_player.display_name == "Coalition Army":
			path = "res://Assets/Players/Coalition Army/background.png"
		elif ai_player.display_name == "Corporate Troops":
			path = "res://Assets/Players/Corporate Troops/background.png"
		elif ai_player.display_name == "State Troops":
			path = "res://Assets/Players/State Troops/background.png"
		elif ai_player.display_name == "Horde":
			path = "res://Assets/Players/Horde/background.png"
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
		var flag_path := "res://Assets/Players/%s/flag.png" % ai_player.display_name
		var p: String = flag_path
		if not ResourceLoader.exists(p):
			p = "res://Assets/Players/Coalition Army/flag.png"
		if not ResourceLoader.exists(p) and ai_player.display_name == "Euro Army":
			p = "res://Assets/Players/Euro Army/flag.png"
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
	debug_popup.custom_minimum_size = Vector2(420, 300)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	debug_popup.add_child(vbox)
	var title := Label.new()
	title.text = "Debug Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1,1,0.7))
	vbox.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)
	var lbl := Label.new()
	lbl.text = "Enemy:"
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(1,1,1))
	row.add_child(lbl)
	debug_enemy_option = OptionButton.new()
	debug_enemy_option.custom_minimum_size = Vector2(180, 32)
	debug_enemy_option.add_item("Coalition Army", 0)
	debug_enemy_option.add_item("Corporate Troops", 1)
	debug_enemy_option.add_item("Euro Army", 2)
	debug_enemy_option.add_item("Insurgents", 3)
	debug_enemy_option.add_item("State Troops", 4)
	debug_enemy_option.add_item("Horde", 5)
	var gs2 = get_node_or_null("/root/GameState")
	var cur: String = "Coalition Army"
	if gs2 != null:
		cur = gs2.selected_enemy
	var cur_idx: int = 0
	for i in range(debug_enemy_option.get_item_count()):
		if debug_enemy_option.get_item_text(i) == cur:
			cur_idx = i
			break
	debug_enemy_option.selected = cur_idx
	debug_enemy_option.item_selected.connect(func(idx: int):
		var g = get_node_or_null("/root/GameState")
		if g != null:
			g.set_enemy(debug_enemy_option.get_item_text(idx))
	)
	row.add_child(debug_enemy_option)
	# Summon any card to battlefield
	var summon_title := Label.new()
	summon_title.text = "Summon Card to Battlefield:"
	summon_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summon_title.add_theme_font_size_override("font_size", 28)
	summon_title.add_theme_color_override("font_color", Color(1,1,1))
	vbox.add_child(summon_title)
	var summon_row := HBoxContainer.new()
	summon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	summon_row.add_theme_constant_override("separation", 8)
	vbox.add_child(summon_row)
	debug_summon_card_option = OptionButton.new()
	debug_summon_card_option.custom_minimum_size = Vector2(180, 32)
	for cname in ["Wall", "Infantry", "Tank", "Artilery", "Rocket Launcher", "Drone", "Fighter Jet", "Factory", "Barracks", "Housing", "Corporation", "Howitzer"]:
		debug_summon_card_option.add_item(cname)
	summon_row.add_child(debug_summon_card_option)
	debug_summon_target_option = OptionButton.new()
	debug_summon_target_option.custom_minimum_size = Vector2(110, 32)
	debug_summon_target_option.add_item("Player", 0)
	debug_summon_target_option.add_item("AI", 1)
	summon_row.add_child(debug_summon_target_option)
	var summon_btn := Button.new()
	summon_btn.text = "Summon"
	summon_btn.custom_minimum_size = Vector2(90, 32)
	summon_btn.add_theme_font_size_override("font_size", 28)
	_style_round_button(summon_btn, true)
	summon_btn.pressed.connect(func():
		var cname2: String = debug_summon_card_option.get_item_text(debug_summon_card_option.selected)
		var target_is_ai: bool = debug_summon_target_option.selected == 1
		_debug_summon_card(cname2, target_is_ai)
	)
	summon_row.add_child(summon_btn)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)
	var restart_btn := Button.new()
	restart_btn.text = "Switch & Restart"
	restart_btn.custom_minimum_size = Vector2(150, 36)
	restart_btn.add_theme_font_size_override("font_size", 30)
	_style_round_button(restart_btn, true)
	restart_btn.pressed.connect(_restart_game)
	btn_row.add_child(restart_btn)
	var close_dbtn := Button.new()
	close_dbtn.text = "Close"
	close_dbtn.custom_minimum_size = Vector2(80, 36)
	_style_round_button(close_dbtn, false)
	close_dbtn.pressed.connect(func(): debug_popup.visible = false)
	btn_row.add_child(close_dbtn)
	var info := Label.new()
	info.text = "Background: " + (ai_player.BackgroundImage if ai_player.BackgroundImage != "" else ai_player.display_name)
	info.add_theme_font_size_override("font_size", 22)
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
	_style_round_button(btn, false)
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
		sz = Vector2(420, 300)
	debug_popup.position = (vp - sz) / 2.0

func _create_card_by_name(cname: String) -> Card:
	match cname:
		"Wall": return Wall.new()
		"Infantry": return Infantry.new()
		"Tank": return Tank.new()
		"Artilery": return Artilery.new()
		"Rocket Launcher": return RocketLauncher.new()
		"Drone": return Drone.new()
		"Fighter Jet": return FighterJet.new()
		"Factory": return Factory.new()
		"Barracks": return Barracks.new()
		"Housing": return Housing.new()
		"Corporation": return Corporation.new()
		"Howitzer": return Howitzer.new()
		_: return Wall.new()

func _debug_summon_card(cname: String, to_ai: bool):
	var target: Player = ai_player if to_ai else human
	if target == null:
		return
	var empties: Array = target.get_empty_squares()
	if empties.is_empty():
		message_label.text = "No empty squares on %s board!" % ("AI" if to_ai else "Player")
		return
	# pick first empty in row-major (predictable) or random
	empties.shuffle()
	var sq: Square = empties[0] as Square
	# find coords for logging
	var found := false
	for r in range(target.Board.size()):
		for c in range(target.Board[r].Squares.size()):
			if target.Board[r].Squares[c] == sq:
				var card: Card = _create_card_by_name(cname)
				sq.place(card)
				message_label.text = "Summoned %s to %s [%d,%d]" % [cname, "AI" if to_ai else "Player", r, c]
				_refresh_ui()
				found = true
				break
		if found:
			break

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
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)
	var inf_icon_title := TextureRect.new()
	inf_icon_title.texture = load("res://Assets/UI/influence_icon.png") as Texture2D
	inf_icon_title.custom_minimum_size = Vector2(28,28)
	inf_icon_title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inf_icon_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inf_icon_title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	title_row.add_child(inf_icon_title)
	var title := Label.new()
	title.text = "Shop — Between Battles (Influence: %d)" % influence
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1,0.92,0.5))
	title_row.add_child(title)
	var hint := Label.new()
	hint.text = "Buy 5 cards using Influence (cost = InfluenceCost). Remove a card for 25 Influence (once per shop)."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
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
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", Color(1,1,1))
		cell.add_child(name_lbl)
		var cost_row := HBoxContainer.new()
		cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
		cost_row.add_theme_constant_override("separation", 4)
		var cost_icon := TextureRect.new()
		cost_icon.texture = load("res://Assets/UI/influence_icon.png") as Texture2D
		cost_icon.custom_minimum_size = Vector2(20,20)
		cost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cost_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		cost_row.add_child(cost_icon)
		var cost_lbl := Label.new()
		cost_lbl.text = "%d" % card.InfluenceCost
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 22)
		cost_lbl.add_theme_color_override("font_color", Color(1,0.85,0.4))
		cost_row.add_child(cost_lbl)
		cell.add_child(cost_row)
		var stats := Label.new()
		if card is Unit:
			stats.text = "HP:%d DMG:%d" % [(card as Unit).HitPoints, (card as Unit).Damage]
		elif card is Building:
			stats.text = "HP:%d INC:%d" % [(card as Building).HitPoints, (card as Building).Income]
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.add_theme_font_size_override("font_size", 20)
		stats.add_theme_color_override("font_color", Color(0.9,0.9,1))
		cell.add_child(stats)
		if card.SpecialEffect != "":
			var eff := Label.new()
			eff.text = card.SpecialEffect
			eff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			eff.custom_minimum_size = Vector2(140, 28)
			eff.add_theme_font_size_override("font_size", 16)
			eff.add_theme_color_override("font_color", Color(0.8,0.8,1))
			cell.add_child(eff)
		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.custom_minimum_size = Vector2(80, 28)
		_style_round_button(buy_btn, true)
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
	remove_btn.text = "Remove (25 Influence) — once per shop"
	remove_btn.icon = load("res://Assets/UI/influence_icon.png") as Texture2D
	remove_btn.expand_icon = true
	remove_btn.custom_minimum_size = Vector2(300, 32)
	_style_round_button(remove_btn, false)
	if gs != null and gs.shop_remove_used:
		remove_btn.disabled = true
		remove_btn.text = "Remove used this shop"
	elif influence < 25:
		remove_btn.disabled = true
	remove_btn.pressed.connect(func(): _show_remove_dialog())
	btn_row.add_child(remove_btn)
	var cont_btn := Button.new()
	cont_btn.text = "Continue →"
	cont_btn.custom_minimum_size = Vector2(200, 36)
	cont_btn.add_theme_font_size_override("font_size", 28)
	_style_round_button(cont_btn, true)
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
	title.add_theme_font_size_override("font_size", 28)
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
		_style_round_button(btn, false)
		btn.add_theme_font_size_override("font_size", 22)
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
	_style_round_button(close_btn, false)
	close_btn.pressed.connect(func(): dlg.queue_free(); _show_shop())
	vbox.add_child(close_btn)
	dlg.position = (get_viewport_rect().size - dlg.size) / 2.0
	dlg.visible = true

func _continue_from_shop():
	shop_popup.visible = false
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.run_started:
		# Reset player deck/bio/money/board at start of each different encounter per request
		# _clear_board(human) is now handled via reset_player_for_new_encounter (clears and repopulates starting board)
		gs.reset_player_for_new_encounter()
		# Sync local human reference to GameState's run_player (in case instance was replaced)
		human = gs.run_player
		# Do not clear next_enemy's board (it has starting placements); old ai_player board already empty after death
		var next_enemy: AIPlayer = gs.get_current_enemy()
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
	var human_bio_before: int = human.BioSupply
	var human_money_before: int = human.MoneySupply
	var ai_bio_before: int = ai_player.BioSupply
	var ai_money_before: int = ai_player.MoneySupply
	human.economy_phase()
	ai_player.economy_phase()
	_refresh_ui()
	await _animate_opponent_economy(ai_bio_before, ai_money_before, human_bio_before, human_money_before)
	# AI builds with animation
	end_turn_btn.disabled = true
	message_label.text = "Opponent's turn..."
	await _animate_opponent_builds()
	end_turn_btn.disabled = false
	selected_card = null
	selected_card_idx = -1
	message_label.text = "Your turn: play cards then press End Turn"
	_refresh_ui()
	_check_game_over()

func _animate_opponent_economy(ai_bio_before: int, ai_money_before: int, _human_bio_before: int, _human_money_before: int):
	# Flash opponent gauges when income ticks
	var bars: Array = [ai_bio_bar, ai_money_bar]
	for bar in bars:
		if bar != null and is_instance_valid(bar):
			bar.pivot_offset = bar.size * 0.5
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(bar, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(bar, "modulate", Color(1, 0.95, 0.4), 0.12)
			tw.set_parallel(false)
			tw.tween_property(bar, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(bar, "modulate", Color(1,1,1), 0.16)
	var delta_bio: int = ai_player.BioSupply - ai_bio_before
	var delta_money: int = ai_player.MoneySupply - ai_money_before
	if delta_bio > 0:
		_spawn_damage_number(ai_bio_bar, delta_bio)
		var m1 := ai_bio_bar as Control
		if m1 != null:
			m1.modulate = Color(0.6, 1, 0.6)
			var f := create_tween()
			f.tween_property(m1, "modulate", Color(1,1,1), 0.4)
	if delta_money > 0:
		_spawn_damage_number(ai_money_bar, delta_money)
	await get_tree().create_timer(0.35).timeout

func _animate_opponent_builds():
	var placed: Array = ai_player.take_build_turn()
	if placed.is_empty():
		message_label.text = "Opponent passes"
		_refresh_ui()
		await get_tree().create_timer(0.4).timeout
		return
	for entry in placed:
		var card: Card = entry["card"] as Card
		var sq: Square = entry["square"] as Square
		message_label.text = "Opponent plays %s" % card.card_name
		# Pulse AI deck icon as card drawn
		if ai_deck_icon != null and is_instance_valid(ai_deck_icon):
			ai_deck_icon.pivot_offset = ai_deck_icon.size * 0.5
			var twd := create_tween()
			twd.tween_property(ai_deck_icon, "scale", Vector2(1.12, 1.12), 0.1).set_trans(Tween.TRANS_BACK)
			twd.tween_property(ai_deck_icon, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_BACK)
		_refresh_ui()
		await get_tree().create_timer(0.18).timeout
		# Zap-in: electric teleport for opponent card
		var btn := _get_button_for_square(ai_player, sq)
		if btn != null and is_instance_valid(btn):
			btn.pivot_offset = btn.size * 0.5
			btn.scale = Vector2(0.1, 0.1)
			btn.modulate = Color(0.7, 0.85, 1.4, 0)
			btn.rotation = 0.0
			# Zap flash overlay
			_spawn_zap_effect(btn)
			var tw := create_tween()
			tw.set_parallel(true)
			# Zap scale: snap open with overbright
			tw.tween_property(btn, "scale", Vector2(1.32, 1.32), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(btn, "modulate", Color(1.2, 1.2, 1.6, 1), 0.09)
			tw.set_parallel(false)
			# Settle with elastic zap decay + chromatic flicker
			var tw2 := create_tween()
			tw2.set_parallel(true)
			tw2.tween_property(btn, "scale", Vector2(0.96, 0.96), 0.07)
			tw2.tween_property(btn, "modulate", Color(0.85, 0.95, 1.3, 1), 0.07)
			tw2.set_parallel(false)
			tw2.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw2.parallel().tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.14)
			# Electric outline flicker
			var flick := create_tween()
			flick.tween_property(btn, "modulate", Color(0.7, 0.85, 1.5, 1), 0.04)
			flick.tween_property(btn, "modulate", Color(1,1,1,1), 0.08)
			await tw.finished
			await tw2.finished
			await get_tree().create_timer(0.08).timeout
		else:
			await get_tree().create_timer(0.25).timeout
	_refresh_ui()
	await get_tree().create_timer(0.2).timeout

func _refresh_ui():
	_hide_hover()
	_hide_hand_label()
	# Influence now at very bottom right of draw pile — hide old labels, update new symbol
	var gs_run = get_node_or_null("/root/GameState")
	if ai_info != null:
		if gs_run != null and gs_run.run_started:
			ai_info.text = "Influence: %d | Diff %d" % [ai_player.Influence, ai_player.Difficulty]
			ai_info.visible = false # moved to draw pile
		else:
			ai_info.text = ""
			ai_info.visible = false
	if player_info != null:
		player_info.visible = false
	_refresh_influence_display()
	# Update flag art and labels for players (custom flags)
	if ai_label != null:
		ai_label.text = ai_player.display_name if ai_player.display_name != "" else "Coalition Army"
	if player_label != null:
		player_label.text = human.display_name if human.display_name != "" else "State Troops"
	if ai_flag != null:
		var flag_path: String = "res://Assets/Players/%s/flag.png" % ai_player.display_name
		if ResourceLoader.exists(flag_path):
			var t := load(flag_path) as Texture2D
			if t != null:
				ai_flag.texture = t
		elif ResourceLoader.exists("res://Assets/Players/Coalition Army/flag.png"):
			ai_flag.texture = load("res://Assets/Players/Coalition Army/flag.png") as Texture2D
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
	# Vertical gauges: HP at player's max, Bio 0-200, Money 0-200 (clamped), white text, income on Money+Bio
	var ai_income: int = ai_player.total_money_income()
	var p_income: int = human.total_money_income()
	var ai_bio_inc: int = int(ai_player.BioSupply * Housing.bio_rate(ai_player) + 5 + 0.0001) - ai_player.BioSupply
	var p_bio_inc: int = int(human.BioSupply * Housing.bio_rate(human) + 5 + 0.0001) - human.BioSupply
	# AI gauges — HP max is player's MaxHitPoints
	var ai_max_hp: int = ai_player.MaxHitPoints if ai_player != null else 100
	var p_max_hp: int = human.MaxHitPoints if human != null else 100
	ai_hp_bar.max_value = ai_max_hp
	ai_bio_bar.max_value = 200
	ai_money_bar.max_value = 200
	player_hp_bar.max_value = p_max_hp
	player_bio_bar.max_value = 200
	player_money_bar.max_value = 200
	ai_hp_bar.value = clamp(ai_player.HitPoints, 0, ai_max_hp)
	ai_bio_bar.value = clamp(ai_player.BioSupply, 0, 200)
	ai_money_bar.value = clamp(ai_player.MoneySupply, 0, 200)
	player_hp_bar.value = clamp(human.HitPoints, 0, p_max_hp)
	player_bio_bar.value = clamp(human.BioSupply, 0, 200)
	player_money_bar.value = clamp(human.MoneySupply, 0, 200)
	ai_hp_value.text = "%d/%d" % [max(ai_player.HitPoints, 0), ai_max_hp]
	ai_bio_value.text = "%d/%d" % [max(ai_player.BioSupply, 0), 200]
	ai_money_value.text = "%d/%d" % [max(ai_player.MoneySupply, 0), 200]
	player_hp_value.text = "%d/%d" % [max(human.HitPoints, 0), p_max_hp]
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
	ai_deck_value.text = "Draw %d/33" % ai_player.DrawPile.size()
	player_deck_value.text = "Draw %d/33" % human.DrawPile.size()
	ai_discard_value.text = "Discard %d/33" % ai_player.DiscardPile.size()
	player_discard_value.text = "Discard %d/33" % human.DiscardPile.size()
	ai_graveyard_value.text = "Graveyard %d/33" % ai_player.Graveyard.size()
	player_graveyard_value.text = "Graveyard %d/33" % human.Graveyard.size()
	# --- Pile building stylization: HQ / Waiting Zone / Graveyard as grid tiles on right side ---
	var hq_tex := load("res://Assets/UI/hq_building.png") as Texture2D
	var hosp_tex := load("res://Assets/UI/waiting_zone_building.png") as Texture2D
	var grave_tex := load("res://Assets/UI/graveyard_building.png") as Texture2D
	for entry in [
		[ai_deck_icon, hq_tex, false],
		[player_deck_icon, hq_tex, true],
		[ai_discard_icon, hosp_tex, false],
		[player_discard_icon, hosp_tex, true],
		[ai_graveyard_icon, grave_tex, false],
		[player_graveyard_icon, grave_tex, true]
	]:
		var btn: Button = entry[0] as Button
		var tex: Texture2D = entry[1] as Texture2D
		var is_human: bool = entry[2] as bool
		if btn != null and tex != null:
			btn.icon = tex
			btn.expand_icon = true
			btn.custom_minimum_size = Vector2(78, 78)
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			# Grid-tile look: same grey as board squares, building icon on top, count below via label
			var bg := StyleBoxFlat.new()
			bg.bg_color = Color(0.32,0.32,0.38,1) if is_human else Color(0.05,0.05,0.08,1)
			bg.set_corner_radius_all(6)
			bg.content_margin_left = 4
			bg.content_margin_right = 4
			bg.content_margin_top = 4
			bg.content_margin_bottom = 4
			bg.border_color = Color(0.6,0.6,0.7,0.6) if is_human else Color(0.3,0.3,0.35,0.5)
			bg.set_border_width_all(1)
			btn.add_theme_stylebox_override("normal", bg)
			btn.add_theme_stylebox_override("hover", bg)
			btn.add_theme_stylebox_override("pressed", bg)
			btn.add_theme_stylebox_override("focus", bg)
			btn.add_theme_stylebox_override("disabled", bg)
	# Make pile bars 78 wide to sit under building tile like grid
	for bar in [ai_deck_bar, player_deck_bar, ai_discard_bar, player_discard_bar, ai_graveyard_bar, player_graveyard_bar]:
		bar.custom_minimum_size = Vector2(78, 8)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		container.remove_child(child)
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
				# Switched grey shades: player tiles (bottom) lighter, AI tiles (top) darker
				if is_human:
					btn.modulate = Color(0.32, 0.32, 0.38) # noticeably lighter - player can place
				else:
					btn.modulate = Color(0.05, 0.05, 0.08) # noticeably darker - AI side
				btn.add_theme_font_size_override("font_size", 28)
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
				btn.clip_contents = false
				# Transparent background for battlefield cards
				btn.flat = true
				var trans_sb := StyleBoxFlat.new()
				trans_sb.bg_color = Color(0, 0, 0, 0)
				trans_sb.border_width_left = 0
				trans_sb.border_width_right = 0
				trans_sb.border_width_top = 0
				trans_sb.border_width_bottom = 0
				btn.add_theme_stylebox_override("normal", trans_sb)
				btn.add_theme_stylebox_override("hover", trans_sb)
				btn.add_theme_stylebox_override("pressed", trans_sb)
				btn.add_theme_stylebox_override("disabled", trans_sb)
				btn.add_theme_stylebox_override("focus", trans_sb)
				# HBox: art extends 2x to right and 2x to bottom beyond tile, indicators on right vertically stacked on top
				var outer_hbox := HBoxContainer.new()
				outer_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
				outer_hbox.clip_contents = false
				outer_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
				outer_hbox.add_theme_constant_override("separation", 2)
				outer_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				outer_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
				var left_vbox := VBoxContainer.new()
				left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
				left_vbox.clip_contents = false
				left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
				left_vbox.add_theme_constant_override("separation", 1)
				left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
				# Art extends 2x to right and 2x to bottom: 128x128 base (2x 64) overflows tile, clipped false lets it spill
				var anim := Card.create_sprite_for(card.card_name, Vector2(128, 128))
				anim.clip_contents = false
				anim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				anim.size_flags_vertical = Control.SIZE_EXPAND_FILL
				anim.custom_minimum_size = Vector2(128, 128)
				anim.z_index = 1
				left_vbox.add_child(anim)
				outer_hbox.add_child(left_vbox)
				# Right side: health / damage / income vertically stacked
				var right_vbox := VBoxContainer.new()
				right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
				right_vbox.clip_contents = true
				right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
				right_vbox.add_theme_constant_override("separation", 3)
				right_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
				right_vbox.custom_minimum_size = Vector2(22, 0)
				# Health stacked
				var hp_col := VBoxContainer.new()
				hp_col.alignment = BoxContainer.ALIGNMENT_CENTER
				hp_col.clip_contents = true
				hp_col.add_theme_constant_override("separation", 0)
				var hp_icon := TextureRect.new()
				hp_icon.texture = load("res://Assets/UI/heart.png") as Texture2D
				hp_icon.custom_minimum_size = Vector2(14, 14)
				hp_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				hp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				hp_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				hp_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				hp_col.add_child(hp_icon)
				var hp_lbl := Label.new()
				hp_lbl.text = "%d" % hp
				hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				hp_lbl.add_theme_font_size_override("font_size", 16)
				hp_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
				hp_lbl.clip_contents = false
				hp_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
				hp_lbl.custom_minimum_size = Vector2(22, 16)
				hp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hp_col.add_child(hp_lbl)
				right_vbox.add_child(hp_col)
				if is_unit:
					var dmg_col := VBoxContainer.new()
					dmg_col.alignment = BoxContainer.ALIGNMENT_CENTER
					dmg_col.clip_contents = true
					dmg_col.add_theme_constant_override("separation", 0)
					var sword_icon := TextureRect.new()
					sword_icon.texture = load("res://Assets/UI/sword.png") as Texture2D
					sword_icon.custom_minimum_size = Vector2(14, 14)
					sword_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					sword_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					sword_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					sword_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
					dmg_col.add_child(sword_icon)
					var dmg_lbl := Label.new()
					dmg_lbl.text = "%d" % (card as Unit).Damage
					dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					dmg_lbl.add_theme_font_size_override("font_size", 16)
					dmg_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
					dmg_lbl.clip_contents = false
					dmg_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
					dmg_lbl.custom_minimum_size = Vector2(22, 16)
					dmg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					dmg_col.add_child(dmg_lbl)
					right_vbox.add_child(dmg_col)
				else:
					var inc_col := VBoxContainer.new()
					inc_col.alignment = BoxContainer.ALIGNMENT_CENTER
					inc_col.clip_contents = true
					inc_col.add_theme_constant_override("separation", 0)
					var inc_icon := TextureRect.new()
					# Use distinct income icon for MoneyIncome
					inc_icon.texture = load("res://Assets/UI/income_icon.png") as Texture2D
					inc_icon.custom_minimum_size = Vector2(14, 14)
					inc_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					inc_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					inc_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					inc_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
					inc_col.add_child(inc_icon)
					var inc_lbl := Label.new()
					inc_lbl.text = "%d" % (card as Building).Income
					inc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					inc_lbl.add_theme_font_size_override("font_size", 16)
					inc_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
					inc_lbl.clip_contents = false
					inc_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
					inc_lbl.custom_minimum_size = Vector2(22, 16)
					inc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					inc_col.add_child(inc_lbl)
					right_vbox.add_child(inc_col)
				outer_hbox.add_child(right_vbox)
				btn.add_child(outer_hbox)
				# Magnified preview on hover — art + symbols + text enlarged
				var _card_prev: Card = card
				btn.mouse_entered.connect(func(): _show_card_preview(_card_prev))
				btn.mouse_exited.connect(func(): _hide_card_preview())
				# No separate hover tooltip for cards — preview already shows effect
				btn.tooltip_text = ""
				# Keep enabled so hover shows (occupied squares are not clickable anyway)
				btn.disabled = false
				btn.mouse_filter = Control.MOUSE_FILTER_STOP
			container.add_child(btn)

func _refresh_hand():
	_hide_hover()
	for child in hand_container.get_children():
		hand_container.remove_child(child)
		child.queue_free()
	for idx in range(human.Hand.size()):
		var card: Card = human.Hand[idx]
		var btn := Button.new()
		btn.clip_contents = false
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
		# Right-side layout: sprite left | details right - income always visible
		var hand_hbox := HBoxContainer.new()
		hand_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hand_hbox.clip_contents = false
		hand_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hand_hbox.add_theme_constant_override("separation", 4)
		hand_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hand_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var hand_anim := Card.create_sprite_for(card.card_name, Vector2(72, 72))
		hand_anim.clip_contents = true
		hand_anim.custom_minimum_size = Vector2(72, 72)
		hand_anim.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hand_anim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hand_hbox.add_child(hand_anim)
		var details := VBoxContainer.new()
		details.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.clip_contents = false
		details.alignment = BoxContainer.ALIGNMENT_CENTER
		details.add_theme_constant_override("separation", 1)
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.size_flags_vertical = Control.SIZE_EXPAND_FILL
		details.custom_minimum_size = Vector2(48, 0)
		hand_hbox.add_child(details)
		var hand_name := Label.new()
		hand_name.text = card.card_name
		hand_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hand_name.add_theme_font_size_override("font_size", 16)
		hand_name.add_theme_color_override("font_color", Color(1, 1, 1))
		hand_name.clip_contents = false
		hand_name.autowrap_mode = TextServer.AUTOWRAP_OFF
		hand_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		hand_name.custom_minimum_size = Vector2(48, 16)
		hand_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_child(hand_name)
		var hand_stats := HBoxContainer.new()
		hand_stats.alignment = BoxContainer.ALIGNMENT_BEGIN
		hand_stats.clip_contents = false
		hand_stats.add_theme_constant_override("separation", 2)
		hand_stats.custom_minimum_size = Vector2(48, 16)
		var h_heart := TextureRect.new()
		h_heart.texture = load("res://Assets/UI/heart.png") as Texture2D
		h_heart.custom_minimum_size = Vector2(10, 10)
		h_heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h_heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h_heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		h_heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hand_stats.add_child(h_heart)
		var h_hp := Label.new()
		h_hp.text = "%d" % hp
		h_hp.add_theme_font_size_override("font_size", 16)
		h_hp.add_theme_color_override("font_color", Color(1, 1, 1))
		h_hp.clip_contents = false
		h_hp.autowrap_mode = TextServer.AUTOWRAP_OFF
		h_hp.custom_minimum_size = Vector2(0, 16)
		hand_stats.add_child(h_hp)
		if card is Unit:
			var h_sword := TextureRect.new()
			h_sword.texture = load("res://Assets/UI/sword.png") as Texture2D
			h_sword.custom_minimum_size = Vector2(10, 10)
			h_sword.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			h_sword.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			h_sword.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			h_sword.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hand_stats.add_child(h_sword)
			var h_dmg := Label.new()
			h_dmg.text = "%d" % (card as Unit).Damage
			h_dmg.add_theme_font_size_override("font_size", 16)
			h_dmg.add_theme_color_override("font_color", Color(1, 1, 1))
			h_dmg.clip_contents = false
			h_dmg.autowrap_mode = TextServer.AUTOWRAP_OFF
			h_dmg.custom_minimum_size = Vector2(0, 16)
			hand_stats.add_child(h_dmg)
		else:
			var h_inc_icon := TextureRect.new()
			h_inc_icon.texture = load("res://Assets/UI/income_icon.png") as Texture2D
			h_inc_icon.custom_minimum_size = Vector2(14, 14)
			h_inc_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			h_inc_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			h_inc_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			h_inc_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h_inc_icon.modulate = Color(1,1,1,1)
			hand_stats.add_child(h_inc_icon)
			var h_inc := Label.new()
			h_inc.text = "%d" % (card as Building).Income
			h_inc.add_theme_font_size_override("font_size", 16)
			h_inc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			h_inc.add_theme_color_override("font_color", Color(1, 1, 1))
			h_inc.modulate = Color(1,1,1,1)
			h_inc.clip_contents = false
			h_inc.autowrap_mode = TextServer.AUTOWRAP_OFF
			h_inc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			h_inc.custom_minimum_size = Vector2(0, 16)
			h_inc.visible = true
			hand_stats.add_child(h_inc)
			hand_stats.modulate = Color(1,1,1,1)
			details.modulate = Color(1,1,1,1)
		details.add_child(hand_stats)
		var hand_costs := HBoxContainer.new()
		hand_costs.alignment = BoxContainer.ALIGNMENT_BEGIN
		hand_costs.clip_contents = false
		hand_costs.add_theme_constant_override("separation", 2)
		hand_costs.custom_minimum_size = Vector2(48, 16)
		var m_icon := TextureRect.new()
		m_icon.texture = load("res://Assets/UI/money_icon.png") as Texture2D
		m_icon.custom_minimum_size = Vector2(10, 10)
		m_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		m_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		m_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		m_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hand_costs.add_child(m_icon)
		var m_lbl := Label.new()
		m_lbl.text = "%d" % card.MoneyCost
		m_lbl.add_theme_font_size_override("font_size", 16)
		m_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		m_lbl.clip_contents = false
		m_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		m_lbl.custom_minimum_size = Vector2(0, 16)
		hand_costs.add_child(m_lbl)
		var b_icon := TextureRect.new()
		b_icon.texture = load("res://Assets/UI/bio_icon.png") as Texture2D
		b_icon.custom_minimum_size = Vector2(10, 10)
		b_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		b_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hand_costs.add_child(b_icon)
		var b_lbl := Label.new()
		b_lbl.text = "%d" % card.BioCost
		b_lbl.add_theme_font_size_override("font_size", 16)
		b_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		b_lbl.clip_contents = false
		b_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		b_lbl.custom_minimum_size = Vector2(0, 16)
		hand_costs.add_child(b_lbl)
		details.add_child(hand_costs)
		# Magnified preview on hover — hand card art + symbols + text enlarged
		var _hand_prev: Card = card
		btn.mouse_entered.connect(func(): _show_card_preview(_hand_prev))
		btn.mouse_exited.connect(func(): _hide_card_preview())
		# No separate hover tooltip for cards — preview already shows effect
		btn.tooltip_text = ""
		btn.add_child(hand_hbox)
		if idx == selected_card_idx:
			btn.modulate = Color(1, 1, 1)
			btn.add_theme_font_size_override("font_size", 28)
			btn.add_theme_color_override("font_color", Color(1, 1, 1))
		elif human.get_effective_money_cost(card) > human.MoneySupply or human.BioSupply < card.BioCost:
			btn.modulate = Color(1, 0.45, 0.45)
			btn.add_theme_font_size_override("font_size", 28)
			btn.add_theme_color_override("font_color", Color(1, 1, 1))
			# keep enabled so tooltip still shows on hover (was disabled, blocked hover)
		else:
			btn.modulate = Color(1, 1, 1)
			btn.add_theme_font_size_override("font_size", 28)
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

func _refresh_gauges_only():
	_hide_hand_label()
	_refresh_influence_display()
	# Vertical gauges: HP at player's max, Bio 0-200, Money 0-200 (clamped), white text, income on Money+Bio
	var ai_income: int = ai_player.total_money_income() if ai_player != null else 0
	var p_income: int = human.total_money_income() if human != null else 0
	var ai_bio_inc: int = int(ai_player.BioSupply * Housing.bio_rate(ai_player) + 5 + 0.0001) - ai_player.BioSupply if ai_player != null else 0
	var p_bio_inc: int = int(human.BioSupply * Housing.bio_rate(human) + 5 + 0.0001) - human.BioSupply if human != null else 0
	var ai_max_hp: int = ai_player.MaxHitPoints if ai_player != null else 100
	var p_max_hp: int = human.MaxHitPoints if human != null else 100
	ai_hp_bar.max_value = ai_max_hp
	ai_bio_bar.max_value = 200
	ai_money_bar.max_value = 200
	player_hp_bar.max_value = p_max_hp
	player_bio_bar.max_value = 200
	player_money_bar.max_value = 200
	ai_hp_bar.value = clamp(ai_player.HitPoints, 0, ai_max_hp) if ai_player != null else 0
	ai_bio_bar.value = clamp(ai_player.BioSupply, 0, 200) if ai_player != null else 0
	ai_money_bar.value = clamp(ai_player.MoneySupply, 0, 200) if ai_player != null else 0
	player_hp_bar.value = clamp(human.HitPoints, 0, p_max_hp) if human != null else 0
	player_bio_bar.value = clamp(human.BioSupply, 0, 200) if human != null else 0
	player_money_bar.value = clamp(human.MoneySupply, 0, 200) if human != null else 0
	ai_hp_value.text = "%d/%d" % [max(ai_player.HitPoints, 0) if ai_player != null else 0, ai_max_hp]
	ai_bio_value.text = "%d/%d" % [max(ai_player.BioSupply, 0) if ai_player != null else 0, 200]
	ai_money_value.text = "%d/%d" % [max(ai_player.MoneySupply, 0) if ai_player != null else 0, 200]
	player_hp_value.text = "%d/%d" % [max(human.HitPoints, 0) if human != null else 0, p_max_hp]
	player_bio_value.text = "%d/%d" % [max(human.BioSupply, 0) if human != null else 0, 200]
	player_money_value.text = "%d/%d" % [max(human.MoneySupply, 0) if human != null else 0, 200]
	ai_bio_income.text = "+%d" % ai_bio_inc
	player_bio_income.text = "+%d" % p_bio_inc
	ai_money_income.text = "+%d" % (10 + ai_income)
	player_money_income.text = "+%d" % (10 + p_income)
	for bar in [ai_deck_bar, player_deck_bar, ai_discard_bar, player_discard_bar, ai_graveyard_bar, player_graveyard_bar]:
		bar.max_value = 33
	ai_deck_bar.value = clamp(ai_player.DrawPile.size(), 0, 33) if ai_player != null else 0
	player_deck_bar.value = clamp(human.DrawPile.size(), 0, 33) if human != null else 0
	ai_discard_bar.value = clamp(ai_player.DiscardPile.size(), 0, 33) if ai_player != null else 0
	player_discard_bar.value = clamp(human.DiscardPile.size(), 0, 33) if human != null else 0
	ai_graveyard_bar.value = clamp(ai_player.Graveyard.size(), 0, 33) if ai_player != null else 0
	player_graveyard_bar.value = clamp(human.Graveyard.size(), 0, 33) if human != null else 0
	ai_deck_value.text = "Draw %d/33" % (ai_player.DrawPile.size() if ai_player != null else 0)
	player_deck_value.text = "Draw %d/33" % (human.DrawPile.size() if human != null else 0)
	ai_discard_value.text = "Discard %d/33" % (ai_player.DiscardPile.size() if ai_player != null else 0)
	player_discard_value.text = "Discard %d/33" % (human.DiscardPile.size() if human != null else 0)
	ai_graveyard_value.text = "Graveyard %d/33" % (ai_player.Graveyard.size() if ai_player != null else 0)
	player_graveyard_value.text = "Graveyard %d/33" % (human.Graveyard.size() if human != null else 0)
	# Keep pile buildings styled as grid tiles (also in live updates)
	var hq_tex2 := load("res://Assets/UI/hq_building.png") as Texture2D
	var hosp_tex2 := load("res://Assets/UI/waiting_zone_building.png") as Texture2D
	var grave_tex2 := load("res://Assets/UI/graveyard_building.png") as Texture2D
	for entry in [
		[ai_deck_icon, hq_tex2, false],
		[player_deck_icon, hq_tex2, true],
		[ai_discard_icon, hosp_tex2, false],
		[player_discard_icon, hosp_tex2, true],
		[ai_graveyard_icon, grave_tex2, false],
		[player_graveyard_icon, grave_tex2, true]
	]:
		var b2: Button = entry[0] as Button
		var t2: Texture2D = entry[1] as Texture2D
		var ih2: bool = entry[2] as bool
		if b2 != null and t2 != null and b2.icon != t2:
			b2.icon = t2
			b2.custom_minimum_size = Vector2(78,78)
	for pair in [[ai_deck_icon, ai_player.DrawPile.size() if ai_player != null else 0], [player_deck_icon, human.DrawPile.size() if human != null else 0]]:
		pair[0].modulate = Color(1, 0.4, 0.4) if pair[1] <= 3 else Color(1, 1, 1)
	ai_hp_bar.tint_progress = Color(1, 0.35, 0.35) if ai_player != null and ai_player.HitPoints < 30 else Color(1,1,1)
	player_hp_bar.tint_progress = Color(1, 0.35, 0.35) if human != null and human.HitPoints < 30 else Color(1,1,1)

func _refresh_boards_only():
	_refresh_board(ai_board_container, ai_player, false)
	_refresh_board(player_board_container, human, true)

func _on_end_turn():
	end_turn_btn.disabled = true
	selected_card = null
	selected_card_idx = -1
	# Live combat: damage is applied and UI refreshed per hit, not deferred to end
	var log: Array = await _execute_combat_live()
	if log.is_empty():
		message_label.text = "No attacks this turn"
	else:
		message_label.text = "Combat: %d attacks done" % log.size()
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

func _execute_combat_live() -> Array:
	# Mirrors CombatState.combat_phase but applies damage incrementally with per-hit animation + UI refresh
	var log: Array = []
	if state == null or human == null or ai_player == null:
		return log
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(state.Players.size()):
		var attacker: Player = state.Players[i]
		var defender: Player = state.Players[1 - i]
		var attackers: Array = []
		for row in attacker.Board:
			for sq in row.Squares:
				if sq.Inhabitant != null and sq.Inhabitant is Unit:
					attackers.append({"card": sq.Inhabitant, "square": sq})
		for info in attackers:
			var unit: Unit = info["card"]
			var sq: Square = info["square"]
			if unit.HitPoints <= 0:
				continue
			var dmg: int = state._effective_damage(attacker, unit, sq)
			var attacks: int = 4 if unit is RocketLauncher or unit is Howitzer else 1
			for a_idx in range(attacks):
				if unit.HitPoints <= 0:
					break
				var target = state._pick_target(defender, unit.HasRange, rng)
				if target == null:
					defender.HitPoints -= dmg
					defender.HitPoints = clamp(defender.HitPoints, 0, defender.MaxHitPoints)
					var entry: Dictionary = {"attacker": unit, "attacker_sq": sq, "attacker_player": attacker, "defender": defender, "target": null, "target_sq": null, "damage": dmg, "is_direct": true}
					log.append(entry)
					await _animate_live_entry(entry)
					# show player HP drop immediately
					_refresh_gauges_only()
					await get_tree().process_frame
					continue
				var target_card: Card = target["card"]
				var target_sq: Square = target["square"]
				var actual_dmg: int = dmg
				if target_card is Unit and (target_card as Unit).Flying and not unit.HasRange:
					actual_dmg = int(actual_dmg / 2)
					if actual_dmg < 1:
						actual_dmg = 1
				if target_card is Unit:
					(target_card as Unit).HitPoints -= actual_dmg
				elif target_card is Building:
					(target_card as Building).HitPoints -= actual_dmg
				if unit is FighterJet:
					state._apply_fighter_splash(defender, target_sq, actual_dmg)
				state._apply_special_effect(unit, target_card)
				var entry2: Dictionary = {"attacker": unit, "attacker_sq": sq, "attacker_player": attacker, "defender": defender, "target": target_card, "target_sq": target_sq, "damage": actual_dmg, "is_direct": false}
				log.append(entry2)
				await _animate_live_entry(entry2)
				state._resolve_deaths(defender)
				# reflect HP bars, card HP/INC labels, and deaths immediately
				_refresh_gauges_only()
				_refresh_boards_only()
				await get_tree().process_frame
				# if target died already handled, next iteration picks new alive target
			state._resolve_deaths(defender)
			_refresh_gauges_only()
			_refresh_boards_only()
			await get_tree().process_frame
	return log

func _animate_live_entry(entry: Dictionary):
	# --- REDONE: layout-safe, pivot-centered, parallel tweens ---
	var attacker_sq: Square = entry["attacker_sq"]
	var attacker_player: Player = entry["attacker_player"]
	var defender: Player = entry["defender"]
	var target_sq: Square = entry["target_sq"]
	var dmg: int = entry["damage"]
	var is_direct: bool = entry["is_direct"]
	var attacker_card: Card = entry["attacker"]
	var target_card: Card = entry["target"]
	var atk_btn: Button = _get_button_for_square(attacker_player, attacker_sq)
	var tgt_btn: Button = null if is_direct else _get_button_for_square(defender, target_sq)
	var tgt_hp_bar: TextureProgressBar = ai_hp_bar if defender == ai_player else player_hp_bar
	# Barracks aura before attack
	if attacker_card is Unit and Barracks.bonus_if_adjacent(attacker_player, attacker_sq) > 0:
		if atk_btn != null and is_instance_valid(atk_btn):
			_spawn_special_effect(atk_btn, "barracks_aura")
	# Attacker punch: scale+modulate in parallel, pivot-centered
	if atk_btn != null and is_instance_valid(atk_btn):
		atk_btn.pivot_offset = atk_btn.size * 0.5
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(atk_btn, "scale", Vector2(1.14, 1.14), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(atk_btn, "modulate", Color(1, 0.92, 0.35), 0.10)
		tw.set_parallel(false)
		tw.tween_property(atk_btn, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(atk_btn, "modulate", Color(1, 1, 1), 0.14)
		message_label.text = "%s attacks %s for %d" % [attacker_card.card_name, "HP" if is_direct else target_card.card_name, dmg]
	await get_tree().create_timer(0.24).timeout
	if is_direct:
		if tgt_hp_bar != null and is_instance_valid(tgt_hp_bar):
			# HP bar flash + shake via modulate, and value already updated live by _execute_combat_live
			var tw2 := create_tween()
			tw2.set_parallel(true)
			tw2.tween_property(tgt_hp_bar, "modulate", Color(1, 0.28, 0.28), 0.08)
			# subtle scale punch on the bar fill
			tgt_hp_bar.pivot_offset = tgt_hp_bar.size * 0.5
			tw2.tween_property(tgt_hp_bar, "scale", Vector2(1.04, 1.04), 0.08)
			tw2.set_parallel(false)
			tw2.tween_property(tgt_hp_bar, "scale", Vector2(1.0, 1.0), 0.10)
			tw2.parallel().tween_property(tgt_hp_bar, "modulate", Color(1, 1, 1), 0.12)
			_spawn_damage_number(tgt_hp_bar, dmg)
	else:
		if tgt_btn != null and is_instance_valid(tgt_btn):
			tgt_btn.pivot_offset = tgt_btn.size * 0.5
			# Red flash + layout-safe shake via rotation/scale (GridContainer overrides position)
			var tw2 := create_tween()
			tw2.tween_property(tgt_btn, "modulate", Color(1, 0.30, 0.30), 0.06)
			var shake := create_tween()
			shake.tween_property(tgt_btn, "rotation", 0.09, 0.05).set_trans(Tween.TRANS_SINE)
			shake.tween_property(tgt_btn, "rotation", -0.09, 0.05)
			shake.tween_property(tgt_btn, "rotation", 0.05, 0.04)
			shake.tween_property(tgt_btn, "rotation", 0.0, 0.04)
			# parallel scale punch for impact
			var punch := create_tween()
			punch.set_parallel(true)
			punch.tween_property(tgt_btn, "scale", Vector2(0.92, 0.92), 0.06)
			punch.set_parallel(false)
			punch.tween_property(tgt_btn, "scale", Vector2(1.0, 1.0), 0.10).set_trans(Tween.TRANS_BACK)
			_spawn_damage_number(tgt_btn, dmg)
			if attacker_card is FighterJet:
				var adj_sqs: Array = _get_adjacent_squares(defender, target_sq)
				for adj_sq in adj_sqs:
					var adj_btn: Button = _get_button_for_square(defender, adj_sq)
					if adj_btn != null and is_instance_valid(adj_btn) and adj_sq.Inhabitant != null:
						_spawn_special_effect(adj_btn, "fighter_jet_splash")
						_spawn_damage_number(adj_btn, dmg)
				_spawn_special_effect(tgt_btn, "fighter_jet_splash")
			# restore modulate after shake
			await shake.finished
			if is_instance_valid(tgt_btn):
				var fade := create_tween()
				fade.tween_property(tgt_btn, "modulate", Color(1, 1, 1), 0.10)
	await get_tree().create_timer(0.18).timeout

func _get_button_for_square(player: Player, square: Square) -> Button:
	var container: GridContainer = ai_board_container if player == ai_player else player_board_container
	if container == null or square == null:
		return null
	# Squares are stored row-major 4x10, buttons are added same order
	for r in range(player.Board.size()):
		var row: Row = player.Board[r]
		for c in range(row.Squares.size()):
			if row.Squares[c] == square:
				var idx: int = r * 10 + c
				# After _refresh_board with remove_child, count is exact; still guard against queued deletions
				if idx < container.get_child_count():
					var btn = container.get_child(idx) as Button
					if btn != null and is_instance_valid(btn) and not btn.is_queued_for_deletion():
						return btn
				# fallback scan for valid button at logical idx ignoring queued (handles timing)
				var valid_idx := 0
				for child in container.get_children():
					if child.is_queued_for_deletion() or not is_instance_valid(child):
						continue
					if valid_idx == idx:
						return child as Button
					valid_idx += 1
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
		# Highlight attacker: scale pulse + yellow tint (pivot-centered, parallel)
		if atk_btn != null and is_instance_valid(atk_btn):
			atk_btn.pivot_offset = atk_btn.size * 0.5
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(atk_btn, "scale", Vector2(1.14, 1.14), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(atk_btn, "modulate", Color(1, 0.92, 0.35), 0.10)
			tw.set_parallel(false)
			tw.tween_property(atk_btn, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(atk_btn, "modulate", Color(1, 1, 1), 0.14)
			message_label.text = "%s attacks %s for %d" % [attacker_card.card_name, "HP" if is_direct else target_card.card_name, dmg]
		await get_tree().create_timer(0.24).timeout
		# Highlight target
		if is_direct:
			if tgt_hp_bar != null and is_instance_valid(tgt_hp_bar):
				var tw2 := create_tween()
				tw2.set_parallel(true)
				tw2.tween_property(tgt_hp_bar, "modulate", Color(1, 0.28, 0.28), 0.08)
				tgt_hp_bar.pivot_offset = tgt_hp_bar.size * 0.5
				tw2.tween_property(tgt_hp_bar, "scale", Vector2(1.04, 1.04), 0.08)
				tw2.set_parallel(false)
				tw2.tween_property(tgt_hp_bar, "scale", Vector2(1.0, 1.0), 0.10)
				tw2.parallel().tween_property(tgt_hp_bar, "modulate", Color(1, 1, 1), 0.12)
				_spawn_damage_number(tgt_hp_bar, dmg)
		elif tgt_btn != null and is_instance_valid(tgt_btn):
			tgt_btn.pivot_offset = tgt_btn.size * 0.5
			var tw2 := create_tween()
			tw2.tween_property(tgt_btn, "modulate", Color(1, 0.30, 0.30), 0.06)
			var shake2 := create_tween()
			shake2.tween_property(tgt_btn, "rotation", 0.09, 0.05).set_trans(Tween.TRANS_SINE)
			shake2.tween_property(tgt_btn, "rotation", -0.09, 0.05)
			shake2.tween_property(tgt_btn, "rotation", 0.05, 0.04)
			shake2.tween_property(tgt_btn, "rotation", 0.0, 0.04)
			var punch2 := create_tween()
			punch2.set_parallel(true)
			punch2.tween_property(tgt_btn, "scale", Vector2(0.92, 0.92), 0.06)
			punch2.set_parallel(false)
			punch2.tween_property(tgt_btn, "scale", Vector2(1.0, 1.0), 0.10).set_trans(Tween.TRANS_BACK)
			_spawn_damage_number(tgt_btn, dmg)
			# Fighter Jet splash: spawn explosion on adjacent tiles
			if attacker_card is FighterJet:
				var adj_sqs: Array = _get_adjacent_squares(defender, target_sq)
				for adj_sq in adj_sqs:
					var adj_btn: Button = _get_button_for_square(defender, adj_sq)
					if adj_btn != null and is_instance_valid(adj_btn) and adj_sq.Inhabitant != null:
						_spawn_special_effect(adj_btn, "fighter_jet_splash")
				# also spawn on main target for splash center
				_spawn_special_effect(tgt_btn, "fighter_jet_splash")
			await shake2.finished
			if is_instance_valid(tgt_btn):
				var fade := create_tween()
				fade.tween_property(tgt_btn, "modulate", Color(1, 1, 1), 0.10)
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
	if anchor == null or not is_instance_valid(anchor):
		return
	# Collect frames: try 0..7 first, fallback to base png
	var frames: Array = []
	for i in range(8):
		var p: String = "res://Assets/Effects/%s_%d.png" % [kind, i]
		if ResourceLoader.exists(p):
			var tex2: Texture2D = load(p) as Texture2D
			if tex2 != null:
				frames.append(tex2)
	if frames.is_empty():
		var base_path: String = "res://Assets/Effects/%s.png" % kind
		if ResourceLoader.exists(base_path):
			var base_tex: Texture2D = load(base_path) as Texture2D
			if base_tex != null:
				frames.append(base_tex)
		else:
			return
	if frames.is_empty():
		return
	var spr := TextureRect.new()
	spr.texture = frames[0]
	# High-res polished: larger crisp effect (256 source downscaled with linear mipmaps)
	spr.custom_minimum_size = Vector2(140, 140)
	spr.size = Vector2(140, 140)
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spr.modulate = Color(1,1,1,1)
	spr.z_index = 400
	# Add as overlay to GameController to avoid clip_contents of Button
	add_child(spr)
	# Center over anchor using global rect -> local (handle zero-size anchors)
	var anchor_rect: Rect2 = anchor.get_global_rect()
	if anchor_rect.size == Vector2.ZERO:
		anchor_rect = Rect2(anchor.get_global_position(), Vector2(80, 80))
	var center: Vector2 = anchor_rect.get_center()
	var local_center: Vector2 = center - get_global_rect().position
	spr.position = local_center - spr.size * 0.5
	spr.pivot_offset = spr.size * 0.5
	spr.scale = Vector2(0.55, 0.55)
	# Polished pop-in + fade + scale out — smoother cubic/back easing, high-res glow
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(spr, "scale", Vector2(1.08, 1.08), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "modulate", Color(1,1,1,1), 0.14)
	tw.set_parallel(false)
	tw.tween_property(spr, "scale", Vector2(1.42, 1.42), 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(spr, "modulate", Color(1,1,1,0), 0.38)
	tw.tween_callback(func(): if is_instance_valid(spr): spr.queue_free())
	# Animate frames if more than one
	if frames.size() > 1:
		for i in range(1, frames.size()):
			var tex: Texture2D = frames[i]
			var delay: float = i * 0.06
			create_tween().tween_callback(func(t: Texture2D = tex): if is_instance_valid(spr): spr.texture = t).set_delay(delay)

func _spawn_zap_effect(anchor: Control):
	if anchor == null or not is_instance_valid(anchor):
		return
	var anchor_rect: Rect2 = anchor.get_global_rect()
	if anchor_rect.size == Vector2.ZERO:
		anchor_rect = Rect2(anchor.get_global_position(), Vector2(80, 80))
	var center: Vector2 = anchor_rect.get_center()
	var local_center: Vector2 = center - get_global_rect().position
	# Electric ring
	var ring := PanelContainer.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.z_index = 399
	ring.custom_minimum_size = Vector2(90, 90)
	ring.size = Vector2(90, 90)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.5, 1.0, 0.0)
	sb.border_color = Color(0.6, 0.85, 1.0, 1)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0.3, 0.6, 1.0, 0.6)
	sb.shadow_size = 12
	ring.add_theme_stylebox_override("panel", sb)
	add_child(ring)
	ring.position = local_center - ring.size * 0.5
	ring.pivot_offset = ring.size * 0.5
	ring.scale = Vector2(0.3, 0.3)
	ring.modulate = Color(1,1,1,1)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(1.35, 1.35), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate", Color(1,1,1,0), 0.14)
	tw.set_parallel(false)
	tw.tween_callback(func(): if is_instance_valid(ring): ring.queue_free())
	# Zap flash
	var flash := ColorRect.new()
	flash.color = Color(0.8, 0.9, 1.0, 0.85)
	flash.custom_minimum_size = Vector2(96, 96)
	flash.size = Vector2(96, 96)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 401
	add_child(flash)
	flash.position = local_center - flash.size * 0.5
	flash.pivot_offset = flash.size * 0.5
	var tw2 := create_tween()
	tw2.tween_property(flash, "modulate", Color(0.8, 0.9, 1.0, 0), 0.12).set_delay(0.02)
	tw2.tween_callback(func(): if is_instance_valid(flash): flash.queue_free())
	# Lightning streaks (3 lines fanning)
	for i in range(3):
		var line := ColorRect.new()
		line.color = Color(0.7, 0.85, 1.0, 0.9)
		line.custom_minimum_size = Vector2(3, 44)
		line.size = Vector2(3, 44)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.z_index = 402
		add_child(line)
		var ang: float = -30 + i * 30
		line.position = local_center - line.size * 0.5
		line.pivot_offset = line.size * 0.5
		line.rotation_degrees = ang
		var tw3 := create_tween()
		tw3.set_parallel(true)
		tw3.tween_property(line, "scale", Vector2(1, 1.6), 0.07)
		tw3.tween_property(line, "modulate", Color(0.7, 0.85, 1.0, 0), 0.07).set_delay(0.03)
		tw3.tween_callback(func(): if is_instance_valid(line): line.queue_free())

func _spawn_damage_number(anchor: Control, dmg: int):
	if anchor == null or not is_instance_valid(anchor):
		return
	if dmg <= 0:
		return
	var lbl := Label.new()
	lbl.text = "-%d" % dmg
	# High-res polished: larger, crisper outline for 1080p/4k
	lbl.add_theme_font_size_override("font_size", 52)
	lbl.add_theme_color_override("font_color", Color(1, 0.16, 0.16))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.z_index = 300
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate = Color(1, 0.16, 0.16, 1)
	# Overlay on GameController so board refresh doesn't free the label mid-tween
	add_child(lbl)
	# Use global center of anchor, convert to local; GameController covers viewport so subtract its global pos
	var anchor_rect: Rect2 = anchor.get_global_rect()
	if anchor_rect.size == Vector2.ZERO:
		anchor_rect = Rect2(anchor.get_global_position(), Vector2(80, 80))
	var center: Vector2 = anchor_rect.get_center()
	var local_center: Vector2 = center - get_global_rect().position
	lbl.position = local_center + Vector2(-18, -10)
	# polished pop-in scale then float up and fade — snappier back + cubic
	lbl.scale = Vector2(0.65, 0.65)
	lbl.pivot_offset = lbl.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position", local_center + Vector2(-18, -32), 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate", Color(1, 0.16, 0.16, 0), 0.48).set_delay(0.20)
	tw.set_parallel(false)
	tw.tween_callback(func(): if is_instance_valid(lbl): lbl.queue_free())

func _inspect_pile(title: String, pile: Array):
	inspect_title.text = "%s (%d)" % [title, pile.size()]
	# Clear previous grid
	for child in inspect_grid.get_children():
		inspect_grid.remove_child(child)
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
			lbl.add_theme_font_size_override("font_size", 20)
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
				eff3.add_theme_font_size_override("font_size", 16)
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
