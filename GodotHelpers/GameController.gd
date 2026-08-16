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
@onready var end_turn_btn: Button = $VBox/MainHBox/RightContent/Controls/EndTurn
@onready var menu_btn: Button = $VBox/MainHBox/RightContent/Controls/MenuBtn
@onready var ai_hp_bar: TextureProgressBar = $VBox/MainHBox/LeftGauges/AIGauges/AIGaugeHP/AIHP
@onready var ai_bio_bar: TextureProgressBar = $VBox/MainHBox/LeftGauges/AIGauges/AIGaugeBio/AIBio
@onready var ai_money_bar: TextureProgressBar = $VBox/MainHBox/LeftGauges/AIGauges/AIGaugeMoney/AIMoney
@onready var ai_hp_value: Label = $VBox/MainHBox/LeftGauges/AIGauges/AIGaugeHP/AIHPValue
@onready var ai_bio_value: Label = $VBox/MainHBox/LeftGauges/AIGauges/AIGaugeBio/AIBioValue
@onready var ai_money_value: Label = $VBox/MainHBox/LeftGauges/AIGauges/AIGaugeMoney/AIMoneyValue
@onready var ai_money_income: Label = $VBox/MainHBox/LeftGauges/AIGauges/AIGaugeMoney/AIMoneyIncome
@onready var player_hp_bar: TextureProgressBar = $VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeHP/PlayerHP
@onready var player_bio_bar: TextureProgressBar = $VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeBio/PlayerBio
@onready var player_money_bar: TextureProgressBar = $VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeMoney/PlayerMoney
@onready var player_hp_value: Label = $VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeHP/PlayerHPValue
@onready var player_bio_value: Label = $VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeBio/PlayerBioValue
@onready var player_money_value: Label = $VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeMoney/PlayerMoneyValue
@onready var player_money_income: Label = $VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeMoney/PlayerMoneyIncome

func _ready():
	human = Player.new(100, 100, 20)
	ai_player = AIPlayer.new(100, 100, 20)
	human.DrawPile = CardFactory.make_starting_deck()
	ai_player.DrawPile = CardFactory.make_starting_deck()
	state = CombatState.new(human, ai_player)
	end_turn_btn.pressed.connect(_on_end_turn)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	_start_new_round()

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
	ai_info.text = ""
	player_info.text = ""
	ai_info.visible = false
	player_info.visible = false
	# Vertical gauges: HP 0-100, Bio 0-200, Money 0-200 (clamped), white text, income on Money
	var ai_income: int = ai_player.total_money_income()
	var p_income: int = human.total_money_income()
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
	# Income shown right on top of Money symbol (white)
	ai_money_income.text = "+%d" % (10 + ai_income)
	player_money_income.text = "+%d" % (10 + p_income)
	# tint based on low values for contrast (bar color)
	ai_hp_bar.tint_progress = Color(1, 0.35, 0.35) if ai_player.HitPoints < 30 else Color(1,1,1)
	player_hp_bar.tint_progress = Color(1, 0.35, 0.35) if human.HitPoints < 30 else Color(1,1,1)
	# Boards
	_refresh_board(ai_board_container, ai_player, false)
	_refresh_board(player_board_container, human, true)
	# Hand
	_refresh_hand()

func _refresh_board(container: GridContainer, player: Player, is_human: bool):
	for child in container.get_children():
		child.queue_free()
	container.columns = 7
	for r in range(3):
		var row: Row = player.Board[r]
		for c in range(7):
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
				if is_unit:
					btn.modulate = Color(0.15, 0.55, 1.0)
				else:
					btn.modulate = Color(1.0, 0.72, 0.0)
				var hbox := HBoxContainer.new()
				hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hbox.alignment = BoxContainer.ALIGNMENT_CENTER
				hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
				var anim := Card.create_sprite_for(card.card_name, Vector2(48, 48))
				hbox.add_child(anim)
				var vbox := VBoxContainer.new()
				vbox.alignment = BoxContainer.ALIGNMENT_CENTER
				vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
				var name_lbl := Label.new()
				name_lbl.text = card.card_name
				name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				name_lbl.add_theme_font_size_override("font_size", 9)
				name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
				vbox.add_child(name_lbl)
				var stats := HBoxContainer.new()
				stats.alignment = BoxContainer.ALIGNMENT_BEGIN
				var hp_icon := TextureRect.new()
				hp_icon.texture = load("res://Assets/UI/heart.png") as Texture2D
				hp_icon.custom_minimum_size = Vector2(10, 10)
				hp_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				hp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				hp_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				stats.add_child(hp_icon)
				var hp_lbl := Label.new()
				hp_lbl.text = "%d" % hp
				hp_lbl.add_theme_font_size_override("font_size", 9)
				hp_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
				stats.add_child(hp_lbl)
				var dmg_lbl := Label.new()
				dmg_lbl.text = " " + dmg
				dmg_lbl.add_theme_font_size_override("font_size", 8)
				dmg_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
				stats.add_child(dmg_lbl)
				vbox.add_child(stats)
				hbox.add_child(vbox)
				btn.add_child(hbox)
				btn.disabled = true
			container.add_child(btn)

func _refresh_hand():
	for child in hand_container.get_children():
		child.queue_free()
	for idx in range(human.Hand.size()):
		var card: Card = human.Hand[idx]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(68, 54)
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
		# Layout: sprite on top, stats below — avoids text overlapping sprite
		btn.text = ""
		var hand_vbox := VBoxContainer.new()
		hand_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hand_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hand_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hand_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var hand_anim := Card.create_sprite_for(card.card_name, Vector2(48, 48))
		hand_vbox.add_child(hand_anim)
		var hand_lbl := Label.new()
		hand_lbl.text = "%s\nHP %d %s\n$%d B%d" % [card.card_name, hp, extra, card.MoneyCost, card.BioCost]
		hand_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hand_lbl.add_theme_font_size_override("font_size", 10)
		hand_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		hand_vbox.add_child(hand_lbl)
		btn.add_child(hand_vbox)
		if idx == selected_card_idx:
			btn.modulate = Color(1, 0.88, 0.15)
			btn.add_theme_font_size_override("font_size", 14)
			btn.add_theme_color_override("font_color", Color(1, 1, 1))
		elif human.MoneySupply < card.MoneyCost or human.BioSupply < card.BioCost:
			btn.modulate = Color(0.25, 0.25, 0.3)
			btn.add_theme_font_size_override("font_size", 14)
			btn.add_theme_color_override("font_color", Color(1, 1, 1))
			btn.disabled = true
		else:
			btn.modulate = Color(0.2, 0.85, 0.45)
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
	# Check win
	if _check_game_over():
		return
	# Next round
	_start_new_round()
	end_turn_btn.disabled = false

func _get_button_for_square(player: Player, square: Square) -> Button:
	var container: GridContainer = ai_board_container if player == ai_player else player_board_container
	# Squares are stored row-major 3x7, buttons are added same order
	for r in range(player.Board.size()):
		var row: Row = player.Board[r]
		for c in range(row.Squares.size()):
			if row.Squares[c] == square:
				var idx: int = r * 7 + c
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
