extends Control
class_name GameController

# Manages a simple 1v1 autochess game per spec, vs BasicAI
# Called after Play on main menu

var human: Player
var ai_player: Player
var state: CombatState
var ai: BasicAI

var selected_card: Card = null
var selected_card_idx: int = -1

@onready var ai_info: Label = $VBox/AIInfo
@onready var player_info: Label = $VBox/PlayerInfo
@onready var message_label: Label = $VBox/Message
@onready var ai_board_container: GridContainer = $VBox/AIBoard
@onready var player_board_container: GridContainer = $VBox/PlayerBoard
@onready var hand_container: HBoxContainer = $VBox/Hand
@onready var end_turn_btn: Button = $VBox/Controls/EndTurn
@onready var menu_btn: Button = $VBox/Controls/MenuBtn
@onready var ai_hp_bar: TextureProgressBar = $VBox/AIGauges/AIHP
@onready var ai_bio_bar: TextureProgressBar = $VBox/AIGauges/AIBio
@onready var ai_money_bar: TextureProgressBar = $VBox/AIGauges/AIMoney
@onready var player_hp_bar: TextureProgressBar = $VBox/PlayerGauges/PlayerHP
@onready var player_bio_bar: TextureProgressBar = $VBox/PlayerGauges/PlayerBio
@onready var player_money_bar: TextureProgressBar = $VBox/PlayerGauges/PlayerMoney

func _ready():
	human = Player.new(100, 100, 20)
	ai_player = Player.new(100, 100, 20)
	human.DrawPile = GameLogic.make_starting_deck()
	ai_player.DrawPile = GameLogic.make_starting_deck()
	state = CombatState.new(human, ai_player)
	ai = BasicAI.new()
	end_turn_btn.pressed.connect(_on_end_turn)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	_start_new_round()

func _start_new_round():
	# Economy phase for both
	GameLogic.economy_phase(human)
	GameLogic.economy_phase(ai_player)
	# AI builds immediately (simple)
	ai.take_build_turn(ai_player)
	selected_card = null
	selected_card_idx = -1
	message_label.text = "Your turn: play cards then press End Turn"
	_refresh_ui()
	_check_game_over()

func _refresh_ui():
	ai_info.text = "AI  HP:%d  Bio:%d  Money:%d  Deck:%d Hand:%d Grave:%d | Income:+%d" % [ai_player.HitPoints, ai_player.BioSupply, ai_player.MoneySupply, ai_player.DrawPile.size(), ai_player.Hand.size(), ai_player.Graveyard.size(), ai_player.total_money_income()]
	player_info.text = "YOU HP:%d  Bio:%d  Money:%d  Deck:%d Discard:%d Grave:%d | Income:+%d" % [human.HitPoints, human.BioSupply, human.MoneySupply, human.DrawPile.size(), human.DiscardPile.size(), human.Graveyard.size(), human.total_money_income()]
	# Pixel art gauges - HP 0-100, Bio 0-200, Money 0-100 (clamped)
	ai_hp_bar.value = clamp(ai_player.HitPoints, 0, 100)
	ai_bio_bar.value = clamp(ai_player.BioSupply, 0, 200)
	ai_money_bar.value = clamp(ai_player.MoneySupply, 0, 100)
	player_hp_bar.value = clamp(human.HitPoints, 0, 100)
	player_bio_bar.value = clamp(human.BioSupply, 0, 200)
	player_money_bar.value = clamp(human.MoneySupply, 0, 100)
	# tint based on low values for contrast
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
				btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
				if is_human:
					btn.pressed.connect(func(): _on_board_click(r, c))
				else:
					btn.disabled = true
			else:
				var card: Card = sq.Inhabitant
				var hp: int = 0
				var dmg: String = ""
				if card is Unit:
					hp = (card as Unit).HitPoints
					dmg = " DMG:%d" % (card as Unit).Damage
				elif card is Building:
					hp = (card as Building).HitPoints
					dmg = " INC:%d" % (card as Building).Income
				btn.text = "%s\nHP:%d%s" % [card.card_name, hp, dmg]
				if card is Unit:
					btn.modulate = Color(0.15, 0.55, 1.0)
					btn.add_theme_font_size_override("font_size", 13)
					btn.add_theme_color_override("font_color", Color(1, 1, 1))
				else:
					btn.modulate = Color(1.0, 0.72, 0.0)
					btn.add_theme_font_size_override("font_size", 13)
					btn.add_theme_color_override("font_color", Color(0.1, 0.08, 0.0))
				var tex: Texture2D = _sprite_for(card)
				if tex != null:
					btn.icon = tex
					btn.expand_icon = true
					btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				btn.disabled = true
			container.add_child(btn)

func _refresh_hand():
	for child in hand_container.get_children():
		child.queue_free()
	for idx in range(human.Hand.size()):
		var card: Card = human.Hand[idx]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(80, 60)
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
		btn.text = "%s\nHP %d %s\nCost $%d B%d" % [card.card_name, hp, extra, card.MoneyCost, card.BioCost]
		var htex: Texture2D = _sprite_for(card)
		if htex != null:
			btn.icon = htex
			btn.expand_icon = true
			btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if idx == selected_card_idx:
			btn.modulate = Color(1, 0.88, 0.15)
			btn.add_theme_font_size_override("font_size", 14)
			btn.add_theme_color_override("font_color", Color(0.15, 0.12, 0.0))
		elif human.MoneySupply < card.MoneyCost or human.BioSupply < card.BioCost:
			btn.modulate = Color(0.25, 0.25, 0.3)
			btn.add_theme_font_size_override("font_size", 14)
			btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
			btn.disabled = true
		else:
			btn.modulate = Color(0.2, 0.85, 0.45)
			btn.add_theme_font_size_override("font_size", 14)
			btn.add_theme_color_override("font_color", Color(0.05, 0.2, 0.1))
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
	var ok: bool = GameLogic.play_card(human, selected_card, r, c)
	if ok:
		message_label.text = "Placed %s at [%d,%d]" % [selected_card.card_name, r, c]
		selected_card = null
		selected_card_idx = -1
	else:
		message_label.text = "Cannot place there (cost or occupied)"
	_refresh_ui()

func _on_end_turn():
	# Combat phase (both players attack)
	GameLogic.combat_phase(state)
	# Discard remaining hand
	GameLogic.discard_hand(human)
	GameLogic.discard_hand(ai_player)
	# Check win
	if _check_game_over():
		return
	# Next round
	_start_new_round()

func _sprite_for(card: Card) -> Texture2D:
	var name: String = card.card_name
	# Try animated 4-frame sprite first
	var anim := AnimatedTexture.new()
	anim.frames = 4
	var has_anim: bool = false
	for i in range(4):
		var fpath: String = "res://Assets/Cards/%s/sprite_%d.png" % [name, i]
		if ResourceLoader.exists(fpath):
			anim.set_frame_texture(i, load(fpath) as Texture2D)
			anim.set_frame_duration(i, 0.2)
			has_anim = true
	if has_anim:
		anim.pause = false
		return anim
	var path_png: String = "res://Assets/Cards/%s/sprite.png" % name
	if ResourceLoader.exists(path_png):
		return load(path_png) as Texture2D
	var path: String = "res://Assets/Cards/%s/sprite.svg" % name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

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
