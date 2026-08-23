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
@onready var end_turn_btn: Button = $VBox/Controls/EndTurn
@onready var menu_btn: Button = $VBox/Controls/MenuBtn
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
var gauge_grid_bg_sprite: AnimatedSprite2D
@onready var inspect_popup: PanelContainer = $InspectPopup
@onready var inspect_title: Label = $InspectPopup/VBox/InspectTitle
@onready var inspect_grid: GridContainer = $InspectPopup/VBox/InspectScroll/InspectGrid
@onready var close_btn: Button = $InspectPopup/VBox/CloseBtn
@onready var hover_popup: PanelContainer = $HoverPopup
@onready var hover_label: Label = $HoverPopup/HoverLabel
@onready var bg_rect: TextureRect = $BG
var preview_popup: PanelContainer
var _preview_eff_scroll: ScrollContainer = null
var preview_built: bool = false
var preview_traits_root: Control = null
var preview_traits_vbox: VBoxContainer = null
var preview_traits_built: bool = false
var _preview_traits_gen: int = 0
var _preview_traits_tween: Tween = null
var debug_popup: PanelContainer
var debug_built: bool = false
var debug_enemy_option: OptionButton
var debug_summon_card_option: OptionButton
var debug_summon_target_option: OptionButton
var _debug_timestamps: Array = []
var _debug_unlocked: bool = false
var shop_popup: PanelContainer
var shop_built: bool = false
var influence_value_label: Label
var influence_icon_rect: TextureRect
var hover_arrow: Control = null
var hover_arrow_target: Control = null
var modifiers_stack: Control = null
var is_tutorial: bool = false
var tutorial_step: int = 0
var tutorial_overlay: PanelContainer = null
var tutorial_label: RichTextLabel = null
var tutorial_highlight_tween: Tween = null
# Mighty Bear Tutorial Revamp (Best Friends Cafe) — Learning to Teach
# Identify the need: fresh playtest without onboarding showed pain points = upgrade/modifier confusion, adjacency buff, HasRange/Flying; intuitive = drag-to-place. Focus tutorial there.
# Toolset (simple + consistent): 3 tools only — (1) Text box (tutorial_overlay RichTextLabel), (2) Highlight (hand/board/EndTurn glow + tween), (3) Custom level (preset enemy placements). Miro-style flow planned before code.
# Context: board-game rulebook style — goal first, then explain as it comes up. Player trusts tutorial, files unknowns as 'later'. Don't dump shop/modifiers here.
# Iteration setup: sequences = trigger + actions editable by designers without engineering. Below TUTORIAL_SEQUENCES table drives messages + highlights; triggers are card selections/placements.
# Break it until it works: each trigger logs analytics if expected but missed; custom levels preset so Bugs from limiting input are caught.
# Do it all over again: not every pain point gets flow — VFX (damage numbers), UI weight already fixed elsewhere.
const TUTORIAL_SEQUENCES: Array = [
	# Narrator — verbose, goal-first, phases-first — generic, no specific card names (as requested)
	{"step": 0, "trigger": "select_any", "highlight": "hand:any", "title": "Welcome, commander", "text": "Welcome, commander — settle in. I'm your field narrator and I'll talk you through this war like we're sat across a table.\n\n[b]Your goal is simple and urgent:[/b] the [color=#ff8888]opposing force has exactly 20 HP in this tutorial[/color] — first side to 0 HP loses. You start at 100 HP. Everything we do is to protect yours and grind theirs down.\n\n[b]How a turn flows — three phases, every turn, for both sides:[/b]\n[color=#88ff88]1) Economy[/color] — you collect: [color=#88ff88]Bio = 10% of your current Bio +5, plus 8 for every supply-generating building you own[/color] and [color=#ffd700]Money = 10 plus the sum of all building Incomes[/color] (some buildings give a little Money each turn, others give much more). Then you draw — you always try to hold [color=#88ff88]10 cards[/color]; if your Draw pile empties we shuffle your Discard back in and keep drawing. Finally, some modifiers heal HP here.\n[color=#88ff88]2) Build[/color] — you spend Bio and Money (see the green and gold gauges left side) to play cards from your hand onto your half of the board — bottom four rows, 10 wide, 40 squares. Enemy owns top four; together 8×10. One card per square.\n[color=#ff6666]3) Combat[/color] — automatic. Every card you (and the enemy) have that has Damage fires [color=#ff6666]once[/color] at a random enemy among those [color=#88ff88]closest by Manhattan distance[/color] (rows+columns). If the attacker has [color=#ffd700]HasRange = true[/color] it can pick any row; without it, it can only reach the enemy's front row closest to you. If the target has [color=#88ccff]Flying[/color], it takes [color=#88ff88]half damage[/color] from attackers without HasRange (rounded down, min 1). When a card is destroyed its owner's HP drops by its [color=#88ff88]BioCost[/color] and it goes to Graveyard.\n\nLeave [color=#ffd700]Influence (yellow)[/color] for later — it's the Shop currency between battles.\n\nTo begin supply, tap the [color=#ffcc66]highlighted card[/color] in your hand — it's a building that gives [color=#ff8888]50 HP[/color], [color=#ffd700]+2 Money/turn[/color] and [color=#88ff88]+8 Bio/turn[/color], costing [color=#88ff88]30 Bio[/color] and [color=#ffd700]20 Money[/color]."},
	{"step": 1, "trigger": "place_any", "highlight": "board:empty", "title": "Where to build — your ground", "text": "Good — card in hand. Listen, placement is permanent until destroyed, so where matters.\n\nYour ground is the [color=#88ff88]bottom four rows[/color] — that's 40 squares just for you, highlighted in soft green. The opposing force mirrors you up top. Combined you make that 8×10 chess-like field. Every card needs its own square; you can't stack, you can't play on the enemy half, and you can't play if you can't pay the Bio/Money cost up front.\n\nPick any glowing empty square down here. Think of it as founding a little settlement — a quiet back row is safest, but anywhere empty will do for this lesson. Tap to place."},
	{"step": 2, "trigger": "end_turn", "highlight": "endturn", "title": "Close the turn — watch Economy", "text": "That's a settlement planted. To let it tick, you need to close your Build Phase.\n\nHit [color=#ffcc66]End Turn[/color]. Here's what will happen in sequence so you can follow: first [color=#88ff88]your Economy[/color] (10% Bio+5+8 per supply building and 10+incomes — watch your left gauges jump), then [color=#88ff88]enemy Economy[/color] same, then you both [color=#ff6666]Combat[/color] automatically with whatever's on board. After that the enemy gets its own Build where it will place something.\n\nDiscard happens at end of turn too — leftover cards in hand go to Discard and you'll draw back to 10 at next Economy. Ready? End Turn and watch the numbers."},
	{"step": 3, "trigger": "auto_drones", "highlight": "none", "title": "Enemy contact — what just happened", "text": "Contact — and this is exactly why we went verbose. The opposing force air-dropped [color=#ff8888]two flying units[/color] onto their front row, right across from your new building. Let's read the idea together: each is [color=#ff8888]low HP, modest Damage, Flying = true, HasRange = false[/color], costing [color=#88ff88]0 Bio[/color] and [color=#ffd700]a little Money[/color]. Cheap, fragile, airborne.\n\nIn the Combat that just fired, both flyers were closest to your building, so they each rolled to hit it. Look at the left gauge — your new building just lost HP. Every turn that Combat repeats: each Damaging card fires once, picks a random closest enemy, checks HasRange vs Flying for half-damage, applies adjacency and modifier bonuses, then destroys and bills BioCost to HP. That's the loop. Breathe — we're about to answer it."},
	{"step": 4, "trigger": "select_any", "highlight": "hand:any", "title": "Meet your troops — read the card fully", "text": "We need a lineholder. Tap the next [color=#ffcc66]highlighted card[/color] in your hand — it's a basic unit. I'm going to read this type fully so there's no ambiguity:\n[color=#ff8888]Moderate HP[/color] — can soak several hits. [color=#ff6666]Low Damage[/color] — hits for a little each Combat (before bonuses). [color=#ffd700]HasRange = false[/color] — only the front row. [color=#88ccff]Flying = false[/color] — takes full damage. Costs [color=#88ff88]some Bio[/color] and [color=#ffd700]a little Money[/color] and can be bought with Influence in the Shop later (not now). No special text on this one.\n\nHP is endurance; Damage is once-per-Combat output. Tap the highlighted card to pick it up."},
	{"step": 5, "trigger": "place_any", "highlight": "board:empty", "title": "Posting troops — range and targeting, spelled out", "text": "Where you post this unit decides who it can even touch.\n\nWithout HasRange, think [color=#88ff88]frontline only[/color]: your unit looks at the enemy board, finds the smallest Manhattan distance (row steps + column steps) to any enemy card, then can only hit those in the [color=#88ff88]closest row to you[/color] among them — the front. With HasRange that front-row restriction vanishes — any row at minimal distance qualifies. Either way, if several targets tie for closest, the game picks [color=#88ff88]randomly among ties[/color] — not always the same square.\n\nAnd the other side: [color=#88ccff]Flying[/color] targets take [color=#88ff88]half damage (rounded down, minimum 1)[/color] from any attacker that lacks HasRange. So a low-damage unit will plink a flyer for just 1. That's intended. Place your highlighted unit on any glowing empty square — anywhere works for the lesson."},
	{"step": 6, "trigger": "end_turn", "highlight": "endturn", "title": "See it fire — step by step", "text": "Orders set — now watch the sequence you just learned, in order. Hit [color=#ffcc66]End Turn[/color] and narrate it with me: [color=#88ff88]Economy[/color] ticks (Bio +10%+5+8, Money +10+incomes, draw to 10), then [color=#ff6666]your Combat[/color] — your new unit scans for closest, sees the two flyers tied at distance 4-5, rolls one, fires (halved vs Flying if lacking HasRange), then [color=#ff6666]enemy Combat[/color] — flyers hit your building, then enemy Build. Don't worry about the exact numbers — watch the flash and the HP bars tick. End Turn."},
	{"step": 7, "trigger": "auto_wall", "highlight": "none", "title": "They wall up — why", "text": "They're digging in — classic defensive play. A [color=#aaaaaa]protective structure[/color] just rose on their front row: read the pattern with me — [color=#ff8888]moderate HP[/color], [color=#ffd700]0 Income[/color], costs [color=#ffd700]a little Money[/color] and [color=#88ff88]0 Bio[/color], no special, cheap in Shop. Why front row always? This type is programmed to only ever occupy the [color=#88ff88]row closest to you[/color] — it's in their AI. Cheap, tough, no punch, but it now sits as the closest target, so your non-HasRange units will be forced to chew through it before they can reach the flyers behind it. That's screening."},
	{"step": 8, "trigger": "select_any", "highlight": "hand:any", "title": "Force multiplier — adjacency spelled out", "text": "We answer screening with synergy. Tap the next [color=#ffcc66]highlighted card[/color] in hand — it's a support building. Let's be verbose and unambiguous: [color=#ff8888]solid HP, modest Money income each Economy[/color], costs [color=#ffd700]some Money[/color] and [color=#88ff88]some Bio[/color] (paid in Shop with Influence). SpecialEffect verbatim: [color=#88ff88]Friendly units in adjacent squares have +2 damage[/color]. Adjacent means [color=#88ff88]all 8 squares around it — up, down, left, right and the four diagonals[/color]. Not your whole board, not a row — just the ring. If a unit sits in that ring when Combat fires, its base Damage gets +2 that hit. The support itself still hits for 0. Tap the highlighted card."},
	{"step": 9, "trigger": "place_adjacent_any", "highlight": "board:adjacent:any", "title": "Adjacency — place it right", "text": "This is the precision moment. That +2 only works if the support building ends up [color=#88ff88]immediately next to[/color] the unit it should buff. Your earlier unit is already on the field — the glowing squares are exactly the eight around it. Put the support on any glowing tile (diagonal counts!) and the moment it lands, the neighbouring unit's damage will tick up by 2 in Combat. Miss by one square and the bonus is zero — that's not a bug, it's the rule. Place the highlighted support adjacent."},
	{"step": 10, "trigger": "end_turn", "highlight": "endturn", "title": "Bring it home — the loop closed", "text": "Beautiful — line held, bonuses linked. Hit [color=#ffcc66]End Turn[/color] and let's close the loop verbosely so you own it: [color=#88ff88]Economy[/color] — your supply building gives +8 Bio, support and supply give +2 Money each, plus 10 and 10% Bio+5; you draw back to 10, shuffled if needed. [color=#ff6666]Combat[/color] — your unit now scans closest, still sees the wall-like structure as closest (front row rule), fires with +2 into it; flyers still halve vs non-HasRange if you later hit them, but the wall isn't Flying so full damage. Keep your eyes left on the gauges ticking, centre on the 8×10 field staying clear — that's your critical focus — and remember destroyed cards bill their BioCost to owner's HP. Grind that 20 HP down."},
	{"step": 11, "trigger": "free_play", "highlight": "none", "title": "You're clear, commander — go win", "text": "You're clear, commander — [color=#88ff88]tutorial complete[/color]. Verbosely, here's your standing orders for free play: draw to 10 each Economy (10 (+ discard shuffle), not 5), play what you can afford, respect HasRange vs Flying, use support rings, and watch Building incomes stack. You now visualize the three phases — [color=#88ff88]Economy → Build → Combat[/color] — every turn, for both sides, automatic after End Turn. The opposing force is still at 20 HP total in this skirmish; real campaigns go longer and Shop (Influence) appears between battles. You've got this. End Turn when ready and finish the fight — good luck."},
]

func _tutorial_sequence_for_step(s: int) -> Dictionary:
	for seq in TUTORIAL_SEQUENCES:
		if seq["step"] == s:
			return seq
	return {}

func _log_tutorial_analytics(event: String, step: int, expected: String, got: String = ""):
	# Break-it analytics: if a trigger should have fired but didn't, log for diagnosis (Simonas: analytics for missing sequences)
	if OS.is_debug_build():
		print("[TutorialAnalytics] step %d %s expected=%s got=%s" % [step, event, expected, got])

# ---



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
	_ensure_modifiers_stack()
	_refresh_modifiers_stack()

func _setup_tutorial():
	human.Board = []
	for i in range(4):
		human.Board.append(Row.new())
	ai_player.Board = []
	for i in range(4):
		ai_player.Board.append(Row.new())
	human.HitPoints = 100
	human.MaxHitPoints = 100
	human.BioSupply = 150
	human.MoneySupply = 150
	human.Influence = 0
	human.DrawPile.clear()
	human.DiscardPile.clear()
	human.Graveyard.clear()
	human.Hand.clear()
	# Tutorial hand: Housing, Infantry, Barracks in order - plus 2 filler for spacing
	human.Hand.append(Housing.new())
	human.Hand.append(Infantry.new())
	human.Hand.append(Barracks.new())
	# Add 2 filler cards to make hand look full but not needed for tutorial
	human.Hand.append(Wall.new())
	human.Hand.append(Tank.new())
	ai_player.HitPoints = 20
	ai_player.MaxHitPoints = 20
	ai_player.BioSupply = 150
	ai_player.MoneySupply = 150
	ai_player.Board = []
	for i in range(4):
		ai_player.Board.append(Row.new())
	ai_player.Hand.clear()
	ai_player.DrawPile.clear()
	ai_player.DiscardPile.clear()
	tutorial_step = 0
	_setup_tutorial_overlay()
	_update_tutorial_message()
	_refresh_ui()
	_highlight_tutorial()

func _setup_tutorial_overlay():
	if tutorial_overlay != null and is_instance_valid(tutorial_overlay):
		tutorial_overlay.queue_free()
	var overlay := PanelContainer.new()
	overlay.name = "TutorialOverlay"
	overlay.z_index = 300
	overlay.z_as_relative = false
	if overlay.has_method("set_as_top_level"):
		overlay.top_level = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.custom_minimum_size = Vector2(720, 0)
	overlay.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.14, 0.96)
	sb.border_color = Color(0.9, 0.85, 0.4, 1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	overlay.add_theme_stylebox_override("panel", sb)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	overlay.add_child(vbox)
	var title := Label.new()
	title.text = "TUTORIAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vbox.add_child(title)
	# Scroll wrapper prevents overflow off the top — verbose step 0 (~300 words) stays inside viewport
	var scroll := ScrollContainer.new()
	scroll.name = "TutorialScroll"
	scroll.custom_minimum_size = Vector2(700, 80)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tutorial_label = RichTextLabel.new()
	tutorial_label.bbcode_enabled = true
	tutorial_label.fit_content = true
	tutorial_label.scroll_active = false
	tutorial_label.custom_minimum_size = Vector2(680, 0)
	tutorial_label.add_theme_font_size_override("normal_font_size", 15)
	tutorial_label.add_theme_color_override("default_color", Color(1, 1, 1))
	scroll.add_child(tutorial_label)
	vbox.add_child(scroll)
	add_child(overlay)
	# Anchor to top-center but clamp height to viewport so it never spills upward
	overlay.anchor_left = 0.5
	overlay.anchor_top = 0.02
	overlay.anchor_right = 0.5
	overlay.anchor_bottom = 0.02
	overlay.offset_left = -360
	overlay.offset_right = 360
	overlay.offset_top = 12
	# Dynamic height: fit content up to 45% of viewport, then scroll. Grow only downward.
	var vp_h: float = get_viewport_rect().size.y
	if vp_h < 100:
		vp_h = 720.0
	var max_h: float = clamp(vp_h * 0.45, 140.0, 380.0)
	overlay.offset_bottom = overlay.offset_top + max_h
	overlay.grow_horizontal = 2
	overlay.grow_vertical = 0
	tutorial_overlay = overlay
	# Re-clamp on viewport resize
	if not has_meta("tutorial_resize_connected"):
		set_meta("tutorial_resize_connected", true)
		get_viewport().size_changed.connect(func(): _clamp_tutorial_overlay())

func _clamp_tutorial_overlay():
	if tutorial_overlay == null or not is_instance_valid(tutorial_overlay):
		return
	var vp_h2: float = get_viewport_rect().size.y
	if vp_h2 < 100:
		vp_h2 = 720.0
	var max_h2: float = clamp(vp_h2 * 0.45, 140.0, 380.0)
	tutorial_overlay.offset_bottom = tutorial_overlay.offset_top + max_h2
	var scroll2 := tutorial_overlay.get_node_or_null("VBox/TutorialScroll") as ScrollContainer
	if scroll2 != null:
		scroll2.custom_minimum_size = Vector2(700, clamp(max_h2 - 40.0, 80.0, 340.0))

func _update_tutorial_message():
	if tutorial_label == null or not is_instance_valid(tutorial_label):
		return
	# Iteration-friendly: designers edit TUTORIAL_SEQUENCES table, no code dive (Best Friends Cafe sequences = trigger + actions)
	var seq := _tutorial_sequence_for_step(tutorial_step)
	var msg: String = seq.get("text", "") as String
	if msg == "":
		msg = ""
	# Analytics: if sequence missing where we expected one, log (“should have started but wasn’t able”)
	if seq.is_empty() and tutorial_step <= 11:
		_log_tutorial_analytics("missing_sequence", tutorial_step, "has_message", "")
	tutorial_label.text = msg
	_apply_kraj_efficient_ui()
	_highlight_tutorial()

func _highlight_tutorial():
	_clear_tutorial_highlights()
	if tutorial_overlay == null:
		return
	# Simple + consistent toolset: only highlights as glow (Miro plan: keep 3 tools, same format). Designers change via TUTORIAL_SEQUENCES highlight field.
	var seq := _tutorial_sequence_for_step(tutorial_step)
	var hl: String = seq.get("highlight", "") as String
	if hl == "":
		return
	if hl.begins_with("hand:"):
		var target: String = hl.substr(5)
		if target == "any":
			# Generic: highlight first selectable card in hand (no card name needed)
			if human.Hand.size() > 0:
				var any_name: String = (human.Hand[0] as Card).card_name
				_highlight_hand_card(any_name)
			elif hand_container.get_child_count() > 0:
				for child in hand_container.get_children():
					if child is Button:
						(child as Button).modulate = Color(1, 0.92, 0.4)
			else:
					_highlight_board_empty()
		else:
			_highlight_hand_card(target)
	elif hl == "board:empty":
		_highlight_board_empty()
	elif hl == "endturn":
		_highlight_end_turn()
	elif hl.begins_with("board:adjacent:"):
		var adj_target: String = hl.substr(15)
		if adj_target == "any":
			# Generic adjacency: highlight around any existing friendly unit
			var found: String = ""
			for row in human.Board:
				for sq in row.Squares:
					if sq.Inhabitant != null and sq.Inhabitant is Unit:
						found = sq.Inhabitant.card_name
						break
				if found != "":
					break
			if found != "":
				_highlight_board_adjacent_to(found)
			else:
				_highlight_board_empty()
		else:
			_highlight_board_adjacent_to(adj_target)
	elif hl == "none":
		pass
	else:
		_log_tutorial_analytics("unknown_highlight", tutorial_step, hl, "")

func _clear_tutorial_highlights():
	if tutorial_highlight_tween != null and is_instance_valid(tutorial_highlight_tween):
		tutorial_highlight_tween.kill()
		tutorial_highlight_tween = null
	for child in hand_container.get_children():
		if child is Button:
			(child as Button).modulate = Color(1,1,1)
			(child as Button).scale = Vector2(1,1)
	for cont in [ai_board_container, player_board_container]:
		if cont != null:
			for child in cont.get_children():
				if child is Button:
					(child as Button).modulate = Color(1,1,1)
					(child as Button).scale = Vector2(1,1)
	if end_turn_btn != null:
		end_turn_btn.modulate = Color(1,1,1)
		end_turn_btn.scale = Vector2(1,1)

func _highlight_hand_card(card_name: String):
	if tutorial_highlight_tween != null and is_instance_valid(tutorial_highlight_tween):
		tutorial_highlight_tween.kill()
		tutorial_highlight_tween = null
	for i in range(hand_container.get_child_count()):
		var child = hand_container.get_child(i)
		if child is Button:
			var idx: int = i
			if idx < human.Hand.size() and (human.Hand[idx] as Card).card_name == card_name:
				(child as Button).modulate = Color(1, 0.92, 0.4)
				var tw := create_tween()
				tw.set_loops()
				tw.tween_property(child, "scale", Vector2(1.06, 1.06), 0.4)
				tw.tween_property(child, "scale", Vector2(1.0, 1.0), 0.4)
				tutorial_highlight_tween = tw

func _highlight_board_empty():
	for cont in [player_board_container]:
		if cont == null:
			continue
		for child in cont.get_children():
			if child is Button:
				var btn := child as Button
				if btn.text == "" and not btn.disabled:
					btn.modulate = Color(0.9, 1.0, 0.9)

func _highlight_board_adjacent_to(card_name: String):
	var infantry_pos = null
	for r in range(human.Board.size()):
		for c in range(human.Board[r].Squares.size()):
			var sq: Square = human.Board[r].Squares[c]
			if sq.Inhabitant != null and sq.Inhabitant.card_name == card_name:
				infantry_pos = {"r": r, "c": c}
				break
	if infantry_pos == null:
		_highlight_board_empty()
		return
	for r in range(human.Board.size()):
		for c in range(human.Board[r].Squares.size()):
			var sq: Square = human.Board[r].Squares[c]
			if sq.is_empty():
				var dr: int = abs(r - infantry_pos["r"])
				var dc: int = abs(c - infantry_pos["c"])
				if dr <= 1 and dc <= 1 and not (dr==0 and dc==0):
					var btn := _get_button_for_square(human, sq)
					if btn != null and is_instance_valid(btn):
						btn.modulate = Color(0.9, 1.0, 0.9)

func _highlight_end_turn():
	if end_turn_btn != null:
		if tutorial_highlight_tween != null and is_instance_valid(tutorial_highlight_tween):
			tutorial_highlight_tween.kill()
		end_turn_btn.modulate = Color(1, 0.92, 0.4)
		end_turn_btn.scale = Vector2(1,1)
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(end_turn_btn, "scale", Vector2(1.08, 1.08), 0.35)
		tw.tween_property(end_turn_btn, "scale", Vector2(1.0, 1.0), 0.35)
		tutorial_highlight_tween = tw


# === Kraj Efficient UI Revamp (Feb 24 2020) ===
# Key #1 Critical focus: board center (AIBoard+PlayerBoard) is red zone - keep permanent heavy UI in green safe corners (LeftGauges/RightGauges). Never overlay center.
# Key #2 Four categories:
#   Non-Diegetic: HP/Bio/Money bars + Influence (overlay, always readable, independent of camera)
#   Diegetic: Card art + HP text on board tiles (exists on board, in-world fantasy)
#   Spatial: targeting arrows / damage numbers anchored in world (hover_arrow, combat VFX)
#   Meta: HQ/Waiting-zone/Graveyard building icons at piles - overlay but in-world buildings fantasy
# Key #3 Only relevant info: AC Origins hides health outside combat - we dim AI gauges on player turn, hide AIDeck/AIGrave outside inspect, mute HandLabel/Message when empty
# Key #4 Minimum eye travel: group PlayerGauges + Hand + EndTurn near bottom (player flow: check resources -> pick card -> place on closest row -> EndTurn), AI gauges stay top near AI board
# Key #5 Weight: Half-Life 2 minimal beige - desaturate fills, thin bars, low-contrast backgrounds, small fonts
# Key #6 Worst-case: clamp piles at 33, message at 120 chars, boards 10 cols max, hand scrolls after 10

func _apply_kraj_efficient_ui():
	# Protect critical focus - ensure boards have margin and sidebars don't encroach center
	var main = get_node_or_null("VBox/MainHBox") as HBoxContainer
	if main != null:
		main.add_theme_constant_override("separation", 14)
		main.alignment = BoxContainer.ALIGNMENT_CENTER
	# Weight: make bars thin + desaturated (Half-Life 2 beige), backgrounds low contrast
	var hp_fill_muted := Color(0.82, 0.78, 0.70, 0.95) # beige
	var bio_fill_muted := Color(0.72, 0.80, 0.68, 0.95)
	var money_fill_muted := Color(0.84, 0.80, 0.55, 0.95)
	for bar in [ai_hp_bar, player_hp_bar]:
		if bar != null and is_instance_valid(bar):
			bar.tint_progress = hp_fill_muted if bar.value >= 30 else Color(0.92, 0.45, 0.45, 0.98)
			bar.custom_minimum_size = Vector2(26, 180)
			bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for bar in [ai_bio_bar, player_bio_bar]:
		if bar != null and is_instance_valid(bar):
			bar.tint_progress = bio_fill_muted
			bar.custom_minimum_size = Vector2(26, 180)
	for bar in [ai_money_bar, player_money_bar]:
		if bar != null and is_instance_valid(bar):
			bar.tint_progress = money_fill_muted
			bar.custom_minimum_size = Vector2(26, 180)
	# LeftGauges / RightGauges as safe green zones - narrow, low opacity bg
	var left = get_node_or_null("VBox/MainHBox/LeftGauges") as Control
	var right = get_node_or_null("VBox/MainHBox/RightGauges") as Control
	if left != null:
		left.custom_minimum_size = Vector2(124, 0)
		left.modulate = Color(1, 1, 1, 0.96)
	if right != null:
		right.custom_minimum_size = Vector2(124, 0)
	# Eye travel: push PlayerGauges + PlayerDeck toward bottom near Hand (group flow)
	if left != null:
		var spacer = left.get_node_or_null("Spacer") as Control
		if spacer != null:
			spacer.custom_minimum_size = Vector2(0, 8)
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var aigauges = left.get_node_or_null("AIGauges") as Control
		var pgauges = left.get_node_or_null("PlayerGauges") as Control
		if aigauges != null:
			aigauges.add_theme_constant_override("separation", 8)
		if pgauges != null:
			pgauges.add_theme_constant_override("separation", 8)
	# Only relevant info: dim opposing gauges depending on tutorial step / turn
	var player_turn: bool = true
	if state != null and state.has_method("get_current_turn"):
		pass
	# Use tutorial_step to infer - even steps player acts, odd enemy acts (approx)
	if is_tutorial:
		player_turn = tutorial_step in [0, 1, 2, 4, 5, 6, 8, 9, 10]
	# On player flow, AI gauges 40% alpha, player gauges 100%; reverse on enemy flow
	var ai_mod := Color(1, 1, 1, 0.78) if player_turn else Color(1, 1, 1, 1.0)
	var p_mod := Color(1, 1, 1, 1.0) if player_turn else Color(1, 1, 1, 0.45)
	var ai_header = left.get_node_or_null("AIHeader") if left != null else null
	var p_header = left.get_node_or_null("PlayerHeader") if left != null else null
	var aig = left.get_node_or_null("AIGauges") if left != null else null
	var pg = left.get_node_or_null("PlayerGauges") if left != null else null
	if aig != null: aig.modulate = ai_mod
	if pg != null: pg.modulate = p_mod
	if ai_header != null: ai_header.modulate = ai_mod
	if p_header != null: p_header.modulate = p_mod
	var ai_deck_box = left.get_node_or_null("AIDeck") as Control if left != null else null
	if ai_deck_box != null: ai_deck_box.modulate = Color(1,1,1,0.92) if player_turn else Color(1,1,1,1.0)
	# Hide non-critical labels when empty (overpaint test: if we painted this bright ugly, would game still be playable?)
	if ai_info != null: ai_info.visible = false
	if player_info != null: player_info.visible = false
	var hand_lbl = get_node_or_null("VBox/MainHBox/RightContent/HandLabel") as Label
	if hand_lbl != null: hand_lbl.visible = false
	# Key #3 overpaint test + worst-case: Battleborn ugliest-color test - we desaturated and ensure nothing covers board
	# Mistake #1 S&F: not every sign needs UI - damage uses spatial floating numbers + shake, not extra icon. Mistake #2: not everything all time.
	# Worst-case safeguards
	if message_label != null:
		var txt: String = message_label.text
		if txt.length() > 120:
			message_label.text = txt.substr(0, 117) + "..."
		message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message_label.custom_minimum_size = Vector2(0, 18)
		message_label.modulate = Color(1,1,1, 0.92) if txt.length() > 0 else Color(1,1,1,0.45)
	# Hide empty piles (only relevant info) - collapse to avoid worst-case stack overflow like Black Desert chat
	var pile_nodes: Array = [get_node_or_null("VBox/MainHBox/LeftGauges/AIDeck"), get_node_or_null("VBox/MainHBox/RightGauges/AIDiscard"), get_node_or_null("VBox/MainHBox/RightGauges/AIGraveyard"), get_node_or_null("VBox/MainHBox/RightGauges/PlayerDiscard"), get_node_or_null("VBox/MainHBox/RightGauges/PlayerGraveyard"), get_node_or_null("VBox/MainHBox/LeftGauges/PlayerDeck")]
	for pn in pile_nodes:
		if pn != null and pn is Control:
			var bar = pn.get_node_or_null("AIDeckBar") if pn.name=="AIDeck" else pn.get_node_or_null("PlayerDeckBar") if pn.name=="PlayerDeck" else pn.get_node_or_null("AIDiscardBar") if pn.name=="AIDiscard" else pn.get_node_or_null("AIGraveyardBar") if pn.name=="AIGraveyard" else pn.get_node_or_null("PlayerDiscardBar") if pn.name=="PlayerDiscard" else pn.get_node_or_null("PlayerGraveyardBar")
			var v: int = int(bar.value) if bar != null and bar is TextureProgressBar else 0
			# Keep piles visible but dim if empty (overpaint: would empty pile still block board? no)
			(pn as Control).modulate = Color(1,1,1,0.35) if v==0 else Color(1,1,1,1)
	# Hand flow: keep cards grouped, wrap if >10 via scroll already in InspectPopup, main Hand cap is 10
	if hand_container != null:
		hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
		hand_container.add_theme_constant_override("separation", 6)
		# Worst-case: if hand >10 (shouldn't happen, draw caps at 10), ensure no overflow by scaling down
		if hand_container.get_child_count() > 7:
			hand_container.add_theme_constant_override("separation", 2)
	# BGOverlay lower weight so board (critical) stays readable
	var overlay = get_node_or_null("BGOverlay") as ColorRect
	if overlay != null:
		overlay.color = Color(0.04, 0.04, 0.08, 0.38)

func _tutorial_advance():
	var prev: int = tutorial_step
	tutorial_step += 1
	_log_tutorial_analytics("advance", prev, "to_%d" % tutorial_step, "")
	_update_tutorial_message()
	_highlight_tutorial()
	if tutorial_step == 3:
		# After first placement + end turn, enemy drones - schedule after a short delay
		await get_tree().create_timer(0.4).timeout
		_tutorial_ai_drones()
	elif tutorial_step == 7:
		await get_tree().create_timer(0.3).timeout
		_tutorial_ai_wall()

func _tutorial_ai_drones():
	# Place 2 Drones at AI front row same column as player's Housing to ensure they attack it
	var housing_pos = null
	for r in range(human.Board.size()):
		for c in range(human.Board[r].Squares.size()):
			var sq: Square = human.Board[r].Squares[c]
			if sq.Inhabitant != null and sq.Inhabitant is Housing:
				housing_pos = {"r": r, "c": c}
	var col: int = 5
	if housing_pos != null:
		col = housing_pos["c"]
	var col2: int = clamp(col+1, 0, 9)
	var ai_front: int = 3
	var sq1: Square = ai_player.Board[ai_front].Squares[col]
	var sq2: Square = ai_player.Board[ai_front].Squares[col2]
	if sq1.is_empty():
		sq1.place(Drone.new())
	if sq2.is_empty():
		sq2.place(Drone.new())
	_refresh_ui()
	_update_tutorial_message()
	# Message for step 3 already set, next expects Infantry click
	tutorial_step = 4
	_update_tutorial_message()

func _tutorial_ai_wall():
	var front: int = 3
	var col: int = 5
	# Place wall at front center
	var sq: Square = ai_player.Board[front].Squares[col]
	if sq.is_empty():
		sq.place(Wall.new())
	else:
		for c in range(10):
			var s2: Square = ai_player.Board[front].Squares[c]
			if s2.is_empty():
				s2.place(Wall.new())
				break
	_refresh_ui()
	tutorial_step = 8
	_update_tutorial_message()


func _ensure_modifiers_stack():
	# Top-right of screen, overlay (not inside RightGauges) — vertical stack (now ScrollContainer)
	var existing = get_node_or_null("ModifiersTopRight")
	if existing != null and (existing is ScrollContainer or existing is VBoxContainer):
		modifiers_stack = existing as Control
		modifiers_stack.visible = true
		_clamp_modifiers_stack()
		return
	# Remove old RightGauges stack if it exists (migration)
	var right_gauges = get_node_or_null("VBox/MainHBox/RightGauges")
	if right_gauges != null:
		var old = right_gauges.get_node_or_null("ModifiersStack")
		if old != null:
			old.queue_free()
	# Scroll-wrapped top-right stack — 4th modifier no longer pushes first out top (clamped to viewport)
	var scroll := ScrollContainer.new()
	scroll.name = "ModifiersTopRight"
	scroll.custom_minimum_size = Vector2(118, 0)
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_END
	scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.clip_contents = true
	scroll.z_index = 50
	scroll.z_as_relative = false
	if scroll.has_method("set_as_top_level"):
		scroll.top_level = true
	# Anchor to top-right, clamp height to 70% viewport so 4th stays scrollable inside
	var vp_h: float = get_viewport_rect().size.y
	if vp_h < 100:
		vp_h = 720.0
	var max_h: float = clamp(vp_h * 0.70, 280.0, 520.0)
	scroll.anchor_left = 1.0
	scroll.anchor_top = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 0.0
	scroll.offset_left = -118
	scroll.offset_top = 12
	scroll.offset_right = -12
	scroll.offset_bottom = 12 + max_h
	scroll.grow_horizontal = 0
	scroll.grow_vertical = 0
	var stack := VBoxContainer.new()
	stack.name = "ModifiersInner"
	stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	stack.add_theme_constant_override("separation", 8)
	stack.custom_minimum_size = Vector2(102, 0)
	stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(stack)
	add_child(scroll)
	scroll.visible = true
	modifiers_stack = scroll
	# Keep legacy var pointing to inner for size checks if needed
	if not has_meta("modifiers_inner"):
		set_meta("modifiers_inner", stack)
	else:
		set_meta("modifiers_inner", stack)
	# Re-clamp on resize
	if not has_meta("modifiers_resize_connected"):
		set_meta("modifiers_resize_connected", true)
		get_viewport().size_changed.connect(func(): _clamp_modifiers_stack())

func _clamp_modifiers_stack():
	if modifiers_stack == null or not is_instance_valid(modifiers_stack):
		return
	var vp_h: float = get_viewport_rect().size.y
	if vp_h < 100:
		vp_h = 720.0
	var max_h: float = clamp(vp_h * 0.70, 280.0, 520.0)
	modifiers_stack.offset_bottom = modifiers_stack.offset_top + max_h

func _refresh_modifiers_stack():
	if modifiers_stack == null or not is_instance_valid(modifiers_stack):
		_ensure_modifiers_stack()
		if modifiers_stack == null:
			return
	_clamp_modifiers_stack()
	var inner := modifiers_stack.get_node_or_null("ModifiersInner") as VBoxContainer
	if inner == null:
		# Legacy path where modifiers_stack was VBox directly
		for c in modifiers_stack.get_children():
			c.queue_free()
	else:
		for c in inner.get_children():
			c.queue_free()
	var src: Player = human
	var gs = get_node_or_null("/root/GameState")
	if gs != null and gs.run_player != null:
		src = gs.run_player
	if src == null or src.Modifiers.is_empty():
		# hide when empty to not take space
		modifiers_stack.visible = false
		return
	modifiers_stack.visible = true
	var target_box: Control = modifiers_stack.get_node_or_null("ModifiersInner") as Control
	if target_box == null:
		target_box = modifiers_stack
	for mod in src.Modifiers:
		if mod == null:
			continue
		var m: Modifier = mod as Modifier
		if m == null:
			continue
		var spr := Modifier.create_sprite_for(m.modifier_name, Vector2(102, 102))
		spr.custom_minimum_size = Vector2(102, 102)
		spr.size = Vector2(102, 102)
		# hover shows Effect, click-through
		spr.mouse_filter = Control.MOUSE_FILTER_STOP
		var eff: String = m.Effect
		spr.mouse_entered.connect(func(): _show_hover(eff))
		spr.mouse_exited.connect(func(): _hide_hover())
		for child in spr.get_children():
			if child is Control:
				(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		target_box.add_child(spr)

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

func _get_gauge_grid_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 10.0)
	for i in range(20):
		var fpath: String = "res://Assets/UI/gauge_grid_bg/sprite_%d.png" % i
		if ResourceLoader.exists(fpath):
			var tex := load(fpath) as Texture2D
			if tex != null:
				sf.add_frame("idle", tex)
	if sf.get_frame_count("idle") == 0:
		# fallback single frame if not yet imported
		var fb: String = "res://Assets/UI/gauge_grid_bg/sprite.png"
		if ResourceLoader.exists(fb):
			var tex2 := load(fb) as Texture2D
			if tex2 != null:
				sf.add_frame("idle", tex2)
	return sf

func _setup_gauge_grid_background():
	var left_gauges = get_node_or_null("VBox/MainHBox/LeftGauges")
	if left_gauges == null:
		return
	var main_hbox = left_gauges.get_parent()
	if main_hbox == null:
		return
	if get_node_or_null("VBox/MainHBox/GaugeGridPanel") != null:
		return
	var panel := PanelContainer.new()
	panel.name = "GaugeGridPanel"
	# Only bound the gauge side, not the board: shrink to LeftGauges content
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.clip_contents = false
	panel.custom_minimum_size = Vector2(0, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	# Background control that fills panel behind gauges, clipped to panel
	var bg_control := Control.new()
	bg_control.name = "GaugeGridBG"
	bg_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_control.clip_contents = true
	bg_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sf := _get_gauge_grid_frames()
	var asp := AnimatedSprite2D.new()
	asp.name = "GaugeGridAnim"
	asp.sprite_frames = sf
	asp.animation = "idle"
	asp.autoplay = "idle"
	asp.centered = true
	asp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	asp.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	# Blurry soft edges: shader fades+blurs texture within 18% of border
	if ResourceLoader.exists("res://Assets/Shaders/gauge_blur.gdshader"):
		var shd := load("res://Assets/Shaders/gauge_blur.gdshader") as Shader
		if shd != null:
			var mat := ShaderMaterial.new()
			mat.shader = shd
			mat.set_shader_parameter("edge_soft", 0.18)
			mat.set_shader_parameter("blur_radius", 0.012)
			asp.material = mat
	bg_control.add_child(asp)
	gauge_grid_bg_sprite = asp
	panel.add_child(bg_control)
	var idx: int = main_hbox.get_children().find(left_gauges)
	main_hbox.remove_child(left_gauges)
	panel.add_child(left_gauges)
	main_hbox.add_child(panel)
	main_hbox.move_child(panel, idx)
	left_gauges.z_index = 1
	bg_control.z_index = 0
	asp.play("idle")
	panel.resized.connect(_update_gauge_grid_bg_transform)
	left_gauges.resized.connect(_update_gauge_grid_bg_transform)
	call_deferred("_update_gauge_grid_bg_transform")

func _update_gauge_grid_bg_transform():
	if gauge_grid_bg_sprite == null:
		return
	var panel = get_node_or_null("VBox/MainHBox/GaugeGridPanel")
	if panel == null:
		return
	var left_gauges = get_node_or_null("VBox/MainHBox/GaugeGridPanel/LeftGauges")
	if left_gauges == null:
		left_gauges = get_node_or_null("VBox/MainHBox/LeftGauges")
	var sz: Vector2 = panel.size
	if left_gauges != null and left_gauges.size.x > 10 and left_gauges.size.y > 10:
		sz = left_gauges.size + Vector2(12, 12)
	if sz.x < 10 or sz.y < 10:
		sz = Vector2(268, 560)
	# Clamp to not exceed left side: never wider than LeftGauges + margins
	sz.x = min(sz.x, 280)
	panel.custom_minimum_size = sz
	panel.size = sz
	gauge_grid_bg_sprite.position = sz * 0.5
	var base: float = 512.0
	var sf: SpriteFrames = gauge_grid_bg_sprite.sprite_frames
	if sf != null and sf.get_frame_count("idle") > 0:
		var tex: Texture2D = sf.get_frame_texture("idle", 0)
		if tex != null:
			base = float(tex.get_width())
			if base < 64:
				base = 512.0
	# Fit exactly to panel bounds (separate x/y) so it never spills onto board
	var scale_x: float = sz.x / base
	var scale_y: float = sz.y / base
	gauge_grid_bg_sprite.scale = Vector2(scale_x, scale_y)

func _enforce_uniform_gauge_width():
	# Kraj Key #5 weight + Key #1 safe zone: thin beige bars, narrow green zone
	var w: float = 26
	var h: float = 180
	var gw: float = 80
	for gauge in [get_node_or_null("VBox/MainHBox/LeftGauges/AIGauges/AIGaugeHP"), get_node_or_null("VBox/MainHBox/LeftGauges/AIGauges/AIGaugeBio"), get_node_or_null("VBox/MainHBox/LeftGauges/AIGauges/AIGaugeMoney"), get_node_or_null("VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeHP"), get_node_or_null("VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeBio"), get_node_or_null("VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeMoney")]:
		if gauge != null:
			gauge.custom_minimum_size = Vector2(gw, 0)
			gauge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for bar in [ai_hp_bar, ai_bio_bar, ai_money_bar, player_hp_bar, player_bio_bar, player_money_bar]:
		if bar != null:
			bar.custom_minimum_size = Vector2(w, h)
			bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for lbl in [ai_hp_value, ai_bio_value, ai_money_value, player_hp_value, player_bio_value, player_money_value, ai_bio_income, ai_money_income, player_bio_income, player_money_income, get_node_or_null("VBox/MainHBox/LeftGauges/AIGauges/AIGaugeHP/AIHPIncome"), get_node_or_null("VBox/MainHBox/LeftGauges/PlayerGauges/PlayerGaugeHP/PlayerHPIncome")]:
		if lbl != null:
			lbl.custom_minimum_size = Vector2(gw, 12)
			lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for hbar in [ai_deck_bar, player_deck_bar, ai_discard_bar, player_discard_bar, ai_graveyard_bar, player_graveyard_bar]:
		if hbar != null:
			hbar.custom_minimum_size = Vector2(32, 6)

func _setup_gauge_and_influence_hovers():
	_enforce_uniform_gauge_width()
	# Gauge + influence tooltips: click-through, inside window, always on top via _show_hover
	var hp_tip: String = "Hit Points — when a card dies its owner loses HP equal to its BioSupply cost; at 0 you lose"
	var bio_tip: String = "BioSupply — pay BioCost to play cards; grows 10% +5 each Economy phase"
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
	_apply_kraj_efficient_ui()
	state = CombatState.new(human, ai_player)
	# Tutorial check
	var gs_tut = get_node_or_null("/root/GameState")
	if gs_tut != null and gs_tut.is_tutorial:
		is_tutorial = true
		_setup_tutorial()
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
	_add_save_button()
	_add_debug_button()
	_ensure_shop_popup()
	_setup_gauge_grid_background()
	_setup_gauge_and_influence_hovers()
	_ensure_modifiers_stack()
	_refresh_modifiers_stack()
	player_deck_icon.pressed.connect(func(): _inspect_pile("Your Draw Pile", human.DrawPile))
	ai_deck_icon.pressed.connect(func(): _inspect_ai_full_deck())
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
	preview_popup.custom_minimum_size = Vector2(320, 218)
	preview_popup.size = Vector2(320, 218)
	preview_popup.clip_contents = true
	# Ensure magnifier never blocks clicks to card buttons behind it
	preview_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preview_popup)
	preview_built = true
	# Trait side boxes container (half-width, stacked vertically to the right of hover)
	if preview_traits_built and preview_traits_root != null:
		return
	preview_traits_root = Control.new()
	preview_traits_root.visible = false
	preview_traits_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_traits_root.z_index = 202
	preview_traits_root.z_as_relative = false
	if preview_traits_root.has_method("set_as_top_level"):
		preview_traits_root.top_level = true
	preview_traits_root.clip_contents = false
	preview_traits_root.custom_minimum_size = Vector2(160, 0)
	preview_traits_root.size = Vector2(160, 0)
	preview_traits_vbox = VBoxContainer.new()
	preview_traits_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_traits_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	preview_traits_vbox.add_theme_constant_override("separation", 6)
	preview_traits_vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	preview_traits_vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	preview_traits_vbox.clip_contents = false
	preview_traits_root.add_child(preview_traits_vbox)
	add_child(preview_traits_root)
	preview_traits_built = true

func _set_preview_click_through(node: Control):
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_set_preview_click_through(child as Control)

func _show_card_preview(card: Card, is_player_card: bool = true, anchor: Control = null):
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
	# Fixed 1-line — 320 wide fits Rocket Launcher (15 chars at 34px) in one line
	name_lbl.custom_minimum_size = Vector2(164, 20)
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
	# Fixed-size hover: 3 lines (~78px at 22px) before scroll (no overflow, fixed 280x218 outer)
	var eff_scroll := ScrollContainer.new()
	eff_scroll.custom_minimum_size = Vector2(304, 78)
	eff_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eff_scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	eff_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	eff_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	eff_scroll.clip_contents = true
	eff_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	var eff := RichTextLabel.new()
	eff.bbcode_enabled = true
	eff.fit_content = true
	eff.scroll_active = false
	var _eff_str: String = _effect_with_traits(card)
	if _eff_str != "":
		eff.text = _eff_str
	else:
		eff.text = " "
	eff.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eff.clip_contents = false
	eff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eff.size_flags_vertical = Control.SIZE_EXPAND_FILL
	eff.custom_minimum_size = Vector2(304, 0)
	eff.add_theme_font_size_override("normal_font_size", 22)
	eff.add_theme_color_override("default_color", Color(0.92,0.92,1) if _eff_str.strip_edges() != "" else Color(1,1,1,0))
	eff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eff_scroll.add_child(eff)
	root.add_child(eff_scroll)
	_preview_eff_scroll = eff_scroll
	# filler to ensure root fills fixed popup height with no empty bottom variation — expands only if needed, keeps outer 168 constant
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(filler)
	_set_preview_click_through(root)
	_set_preview_click_through(preview_popup)
	preview_popup.visible = true
	var vp: Vector2 = get_viewport_rect().size
	var sz: Vector2 = Vector2(320, 218)
	preview_popup.size = sz
	preview_popup.custom_minimum_size = sz
	# Keep hover fixed size - scroll handles overflow, outer never expands
	preview_popup.clip_contents = true
	# Position relative to anchor card: player card => above, opponent => below; fallback to mouse
	var pos: Vector2
	if anchor != null and is_instance_valid(anchor):
		var rect: Rect2 = anchor.get_global_rect()
		if rect.size == Vector2.ZERO:
			rect = Rect2(anchor.get_global_position(), Vector2(78, 78))
		if is_player_card:
			# Above: centered horizontally on card, 8px gap above top
			pos = Vector2(rect.get_center().x - sz.x * 0.5, rect.position.y - sz.y - 8)
		else:
			# Below: centered horizontally, 8px gap below bottom
			pos = Vector2(rect.get_center().x - sz.x * 0.5, rect.position.y + rect.size.y + 8)
		# Clamp horizontally, and if above goes off-top, flip below (and vice versa)
		pos.x = clamp(pos.x, 8.0, max(8.0, vp.x - sz.x - 8.0))
		if is_player_card and pos.y < 8:
			pos.y = rect.position.y + rect.size.y + 8
		elif not is_player_card and pos.y + sz.y > vp.y - 8:
			pos.y = rect.position.y - sz.y - 8
		pos.y = clamp(pos.y, 8.0, max(8.0, vp.y - sz.y - 8.0))
	else:
		# Fallback: near mouse (e.g. shop, no anchor)
		var mouse: Vector2 = get_global_mouse_position()
		pos = mouse + Vector2(16, 16)
		if pos.x + sz.x > vp.x - 8:
			pos.x = mouse.x - sz.x - 16
		if pos.y + sz.y > vp.y - 8:
			pos.y = mouse.y - sz.y - 16
		pos.x = clamp(pos.x, 8.0, max(8.0, vp.x - sz.x - 8.0))
		pos.y = clamp(pos.y, 8.0, max(8.0, vp.y - sz.y - 8.0))
	preview_popup.global_position = pos
	preview_popup.z_index = 101
	preview_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# --- Trait side boxes (half-width, stacked vertically) ---
	_ensure_preview_popup()
	if preview_traits_root != null and preview_traits_vbox != null:
		# Immediate removal (not deferred queue_free alone) — quick switch would otherwise leave old boxes queued and double stack_h, pushing y too high
		for c in preview_traits_vbox.get_children():
			preview_traits_vbox.remove_child(c)
			c.queue_free()
		if card is Unit:
			var is_flying: bool = (card as Unit).Flying
			var has_range: bool = (card as Unit).HasRange
			# Orange bracket portion via BBCode, keep boxes strictly outside grey hover rect
			var flying_text: String = "[color=#FF9500][Flying][/color]: This card takes half damage from melee or grounded enemies" if is_flying else "[color=#FF9500][Grounded][/color]: This card deals half damage to flying units"
			var range_text: String = "[color=#FF9500][HasRange][/color]: This card attacks a random enemy at the end of the turn" if has_range else "[color=#FF9500][Melee][/color]: This card attacks the closest enemy at the end of turn"
			var trait_gap: int = 6
			var box_w: float = 160.0 # half width of hover (320)
			# Create trait boxes inline (avoid Variant lambda inference) — RichTextLabel for orange brackets, Panel outside hover
			var box_flying: PanelContainer = PanelContainer.new()
			box_flying.custom_minimum_size = Vector2(box_w, 0)
			box_flying.size = Vector2(box_w, 0)
			box_flying.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			box_flying.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			box_flying.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box_flying.clip_contents = false
			var sbox_f: StyleBoxFlat = StyleBoxFlat.new()
			sbox_f.bg_color = Color(0.08, 0.08, 0.14, 0.96)
			sbox_f.border_color = Color(0.9, 0.9, 0.95, 0.85)
			sbox_f.set_border_width_all(1)
			sbox_f.set_corner_radius_all(8)
			sbox_f.content_margin_left = 6
			sbox_f.content_margin_right = 6
			sbox_f.content_margin_top = 5
			sbox_f.content_margin_bottom = 5
			box_flying.add_theme_stylebox_override("panel", sbox_f)
			var lbl_f: RichTextLabel = RichTextLabel.new()
			lbl_f.bbcode_enabled = true
			lbl_f.text = flying_text
			lbl_f.fit_content = true
			lbl_f.scroll_active = false
			lbl_f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl_f.clip_contents = false
			lbl_f.custom_minimum_size = Vector2(box_w - 12, 0)
			lbl_f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl_f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			lbl_f.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl_f.add_theme_font_size_override("normal_font_size", 13)
			lbl_f.add_theme_color_override("default_color", Color(1, 1, 1))
			box_flying.add_child(lbl_f)
			var box_range: PanelContainer = PanelContainer.new()
			box_range.custom_minimum_size = Vector2(box_w, 0)
			box_range.size = Vector2(box_w, 0)
			box_range.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			box_range.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			box_range.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box_range.clip_contents = false
			var sbox_r: StyleBoxFlat = StyleBoxFlat.new()
			sbox_r.bg_color = Color(0.08, 0.08, 0.14, 0.96)
			sbox_r.border_color = Color(0.9, 0.9, 0.95, 0.85)
			sbox_r.set_border_width_all(1)
			sbox_r.set_corner_radius_all(8)
			sbox_r.content_margin_left = 6
			sbox_r.content_margin_right = 6
			sbox_r.content_margin_top = 5
			sbox_r.content_margin_bottom = 5
			box_range.add_theme_stylebox_override("panel", sbox_r)
			var lbl_r: RichTextLabel = RichTextLabel.new()
			lbl_r.bbcode_enabled = true
			lbl_r.text = range_text
			lbl_r.fit_content = true
			lbl_r.scroll_active = false
			lbl_r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl_r.clip_contents = false
			lbl_r.custom_minimum_size = Vector2(box_w - 12, 0)
			lbl_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl_r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			lbl_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl_r.add_theme_font_size_override("normal_font_size", 13)
			lbl_r.add_theme_color_override("default_color", Color(1, 1, 1))
			box_range.add_child(lbl_r)
			preview_traits_vbox.add_child(box_flying)
			preview_traits_vbox.add_child(box_range)
			# Force layout update to get stack height before positioning — measure after adding; defer correction next frame if estimated
			_preview_traits_gen += 1
			var _this_gen: int = _preview_traits_gen
			if _preview_traits_tween != null and is_instance_valid(_preview_traits_tween):
				_preview_traits_tween.kill()
				_preview_traits_tween = null
			preview_traits_root.visible = true
			var stack_h: float = preview_traits_vbox.get_combined_minimum_size().y
			var _stack_h_fallback_used: bool = false
			if stack_h <= 4:
				# Fallback estimate if not yet laid out (RichTextLabel fit_content needs a frame)
				stack_h = 2 * 48 + trait_gap
				_stack_h_fallback_used = true
			# Trait stack to the left of hover grey bounding box (8px gap), vertically centered — stays outside grey rect
			var traits_x: float = pos.x - box_w - 8
			traits_x = clamp(traits_x, 8.0, max(8.0, vp.x - box_w - 8.0))
			# If left would go off left edge, flip to right side as fallback
			if traits_x < pos.x - box_w - 9:
				# Already clamped but hover near left edge could still push inside; keep left placement
				pass
			if pos.x - box_w - 8 < 8 and traits_x == 8:
				# Hover near left edge — fallback to right side to stay outside
				traits_x = pos.x + sz.x + 8
				traits_x = clamp(traits_x, 8.0, max(8.0, vp.x - box_w - 8.0))
			var traits_y: float = pos.y + (sz.y - stack_h) * 0.5
			traits_y = clamp(traits_y, 8.0, max(8.0, vp.y - stack_h - 8.0))
			preview_traits_root.global_position = Vector2(traits_x, traits_y)
			preview_traits_root.size = Vector2(box_w, stack_h)
			preview_traits_root.custom_minimum_size = Vector2(box_w, stack_h)
			preview_traits_root.z_index = 102
			preview_traits_root.visible = true
			_set_preview_click_through(preview_traits_root)
			# Next-frame correction: real height after RichTextLabel layout can differ by ~10-20px, causing 1-frame high offset
			if _stack_h_fallback_used:
				var _hover_pos: Vector2 = pos
				var _hover_sz: Vector2 = sz
				var _is_player: bool = is_player_card
				var _box_w: float = box_w
				var _trait_gap: int = trait_gap
				# Defer one frame to get true height, then nudge correctly (no Variant lambda)
				_preview_traits_tween = create_tween()
				_preview_traits_tween.tween_interval(0.02)
				_preview_traits_tween.tween_callback(func():
					if _this_gen != _preview_traits_gen: return
					if preview_traits_root == null or not is_instance_valid(preview_traits_root): return
					if not preview_traits_root.visible: return
					if preview_traits_vbox == null or not is_instance_valid(preview_traits_vbox): return
					var _real_h: float = preview_traits_vbox.get_combined_minimum_size().y
					if _real_h <= 4: return
					if abs(_real_h - stack_h) < 1.5: return
					var _real_traits_x: float = _hover_pos.x - _box_w - 8
					_real_traits_x = clamp(_real_traits_x, 8.0, max(8.0, vp.x - _box_w - 8.0))
					if _hover_pos.x - _box_w - 8 < 8 and _real_traits_x == 8:
						_real_traits_x = _hover_pos.x + _hover_sz.x + 8
						_real_traits_x = clamp(_real_traits_x, 8.0, max(8.0, vp.x - _box_w - 8.0))
					var _real_traits_y: float = _hover_pos.y + (_hover_sz.y - _real_h) * 0.5
					_real_traits_y = clamp(_real_traits_y, 8.0, max(8.0, vp.y - _real_h - 8.0))
					preview_traits_root.global_position = Vector2(_real_traits_x, _real_traits_y)
					preview_traits_root.size = Vector2(_box_w, _real_h)
					preview_traits_root.custom_minimum_size = Vector2(_box_w, _real_h)
				)
				_preview_traits_tween.tween_interval(0.02)
				_preview_traits_tween.tween_callback(func():
					if _this_gen != _preview_traits_gen: return
					# Second frame check for RichTextLabel word-wrap settling
					if preview_traits_root == null or not is_instance_valid(preview_traits_root): return
					if not preview_traits_root.visible: return
					if preview_traits_vbox == null or not is_instance_valid(preview_traits_vbox): return
					var _real_h2: float = preview_traits_vbox.get_combined_minimum_size().y
					if _real_h2 <= 4: return
					var _cur_h: float = preview_traits_root.size.y
					if abs(_real_h2 - _cur_h) < 1.5: return
					var _rx: float = _hover_pos.x - _box_w - 8
					_rx = clamp(_rx, 8.0, max(8.0, vp.x - _box_w - 8.0))
					if _hover_pos.x - _box_w - 8 < 8 and _rx == 8:
						_rx = _hover_pos.x + _hover_sz.x + 8
						_rx = clamp(_rx, 8.0, max(8.0, vp.x - _box_w - 8.0))
					var _ry: float = _hover_pos.y + (_hover_sz.y - _real_h2) * 0.5
					_ry = clamp(_ry, 8.0, max(8.0, vp.y - _real_h2 - 8.0))
					preview_traits_root.global_position = Vector2(_rx, _ry)
					preview_traits_root.size = Vector2(_box_w, _real_h2)
					preview_traits_root.custom_minimum_size = Vector2(_box_w, _real_h2)
				)
		else:
			preview_traits_root.visible = false

func _effect_with_traits(card: Card) -> String:
	if card == null:
		return ""
	var prefix: String = ""
	if card is Unit:
		var hasR: bool = (card as Unit).HasRange
		var fly: bool = (card as Unit).Flying
		var r_str: String = "HasRange" if hasR else "Melee"
		var f_str: String = "Flying" if fly else "Grounded"
		# Orange prefix for traits
		prefix = "[color=#FF9500][%s] [%s][/color] " % [r_str, f_str]
	else:
		prefix = ""
	var base: String = card.SpecialEffect
	if base == "":
		return prefix.strip_edges()
	return prefix + base

func _hide_card_preview():
	_preview_eff_scroll = null
	_preview_traits_gen += 1
	if _preview_traits_tween != null and is_instance_valid(_preview_traits_tween):
		_preview_traits_tween.kill()
		_preview_traits_tween = null
	if preview_popup != null:
		preview_popup.visible = false
	if preview_traits_root != null:
		preview_traits_root.visible = false
		if preview_traits_vbox != null:
			for c in preview_traits_vbox.get_children():
				preview_traits_vbox.remove_child(c)
				c.queue_free()
	_hide_attack_arrow()

func _hide_hover():
	hover_popup.visible = false
	_hide_card_preview()

func _show_attack_arrow(attacker: Player, attacker_sq: Square, defender: Player):
	if attacker == null or attacker_sq == null or defender == null:
		return
	var unit = attacker_sq.Inhabitant
	if unit == null or not (unit is Unit):
		return
	if (unit as Unit).HasRange:
		return
	_hide_attack_arrow()
	var cs := CombatState.new(human, ai_player)
	if cs.Players.size() < 2 or cs.Players[0] == null:
		cs.Players = [attacker, defender]
	# Use same Manhattan logic as combat (deterministic first to match combat)
	var pred: Dictionary = cs.predict_target(attacker, attacker_sq, defender)
	var best_sq: Square = pred.get("square", null) as Square
	if best_sq == null:
		return
	var tgt_btn: Button = _get_button_for_square(defender, best_sq)
	if tgt_btn == null or not is_instance_valid(tgt_btn):
		return
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 400
	root.z_as_relative = false
	if root.has_method("set_as_top_level"):
		root.top_level = true
	root.custom_minimum_size = Vector2(160, 190)
	root.size = Vector2(160, 190)
	root.modulate = Color(1, 1, 1, 0)
	# Red crosshair with black outline - same size (160 outer, 144/128 circles, 112x6/6x112 cross)
	var outer_circle := PanelContainer.new()
	outer_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_circle.custom_minimum_size = Vector2(144, 144)
	outer_circle.size = Vector2(144, 144)
	outer_circle.position = Vector2(8, 8)
	var osb := StyleBoxFlat.new()
	osb.bg_color = Color(0, 0, 0, 0)
	osb.border_color = Color(0, 0, 0, 1)
	osb.set_border_width_all(6)
	osb.set_corner_radius_all(72)
	outer_circle.add_theme_stylebox_override("panel", osb)
	root.add_child(outer_circle)
	var circle := PanelContainer.new()
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.custom_minimum_size = Vector2(128, 128)
	circle.size = Vector2(128, 128)
	circle.position = Vector2(16, 16)
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0, 0, 0, 0)
	csb.border_color = Color(1, 0.18, 0.18, 1)
	csb.set_border_width_all(6)
	csb.set_corner_radius_all(64)
	circle.add_theme_stylebox_override("panel", csb)
	root.add_child(circle)
	var h_bg := ColorRect.new()
	h_bg.color = Color(0, 0, 0, 1)
	h_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h_bg.custom_minimum_size = Vector2(116, 10)
	h_bg.size = Vector2(116, 10)
	h_bg.position = Vector2(22, 75)
	root.add_child(h_bg)
	var h := ColorRect.new()
	h.color = Color(1, 0.18, 0.18, 1)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.custom_minimum_size = Vector2(112, 6)
	h.size = Vector2(112, 6)
	h.position = Vector2(24, 77)
	root.add_child(h)
	var v_bg := ColorRect.new()
	v_bg.color = Color(0, 0, 0, 1)
	v_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v_bg.custom_minimum_size = Vector2(10, 116)
	v_bg.size = Vector2(10, 116)
	v_bg.position = Vector2(75, 22)
	root.add_child(v_bg)
	var v := ColorRect.new()
	v.color = Color(1, 0.18, 0.18, 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.custom_minimum_size = Vector2(6, 112)
	v.size = Vector2(6, 112)
	v.position = Vector2(77, 24)
	root.add_child(v)
	var dot := PanelContainer.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.custom_minimum_size = Vector2(16, 16)
	dot.size = Vector2(16, 16)
	dot.position = Vector2(72, 72)
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(1, 0.18, 0.18, 1)
	dsb.border_color = Color(0, 0, 0, 1)
	dsb.set_border_width_all(2)
	dsb.set_corner_radius_all(8)
	dot.add_theme_stylebox_override("panel", dsb)
	root.add_child(dot)
	# Damage preview on top of crosshair (amount target would actually take)
	var pred_dmg: int = 0
	var pred_is_direct: bool = false
	if best_sq != null and best_sq.Inhabitant != null:
		var tgt_card_pred: Card = best_sq.Inhabitant
		# Base effective damage (includes Barracks, Guerilla, Aerial Supremacy etc via effective_damage_for)
		pred_dmg = cs._effective_damage(attacker, unit as Unit, attacker_sq) if (unit is Unit) else 0
		var att_has_range_pred: bool = (unit as Unit).HasRange if (unit is Unit) else false
		if attacker.has_method("has_range_for") and (unit is Unit):
			att_has_range_pred = attacker.has_range_for(unit)
		# Special Ops vs non-flying +100% (x2), Anti Aircraft vs flying +200% (x3)
		if (unit is SpecialOps) and (tgt_card_pred is Unit) and not (tgt_card_pred as Unit).Flying:
			pred_dmg *= 2
		elif (unit is AntiAircraft) and (tgt_card_pred is Unit) and (tgt_card_pred as Unit).Flying:
			pred_dmg *= 3
		# Flying half-damage from non-ranged (except Anti Aircraft vs flying)
		if (tgt_card_pred is Unit) and (tgt_card_pred as Unit).Flying and not att_has_range_pred and not ((unit is AntiAircraft) and (tgt_card_pred as Unit).Flying):
			pred_dmg = int(pred_dmg / 2)
			if pred_dmg < 1:
				pred_dmg = 1
		# Interceptor halving (adjacent friendly Interceptor) - uses same helper as combat
		if (tgt_card_pred is Unit) or (tgt_card_pred is Building):
			pred_dmg = Interceptor.apply_interception(defender, best_sq, tgt_card_pred, unit as Unit, attacker, pred_dmg)
	else:
		pred_is_direct = true
		pred_dmg = cs._effective_damage(attacker, unit as Unit, attacker_sq) if (unit is Unit) else 0
	var dmg_label := Label.new()
	dmg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dmg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dmg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dmg_label.add_theme_font_size_override("font_size", 22)
	dmg_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	# Black outline via shadow
	dmg_label.add_theme_color_override("font_shadow_color", Color(0,0,0,1))
	dmg_label.add_theme_constant_override("shadow_offset_x", 2)
	dmg_label.add_theme_constant_override("shadow_offset_y", 2)
	# Background panel for readability
	var dmg_bg := PanelContainer.new()
	dmg_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dmg_bg.custom_minimum_size = Vector2(56, 26)
	dmg_bg.size = Vector2(56, 26)
	dmg_bg.position = Vector2(52, 67)
	var bg_sb := StyleBoxFlat.new()
	bg_sb.bg_color = Color(0,0,0,0.78)
	bg_sb.set_corner_radius_all(6)
	bg_sb.set_border_width_all(2)
	bg_sb.border_color = Color(0,0,0,1)
	dmg_bg.add_theme_stylebox_override("panel", bg_sb)
	if pred_is_direct:
		dmg_label.text = "-%d HP" % pred_dmg
	else:
		dmg_label.text = "-%d" % pred_dmg
	dmg_label.custom_minimum_size = Vector2(56, 26)
	dmg_label.size = Vector2(56, 26)
	dmg_bg.add_child(dmg_label)
	root.add_child(dmg_bg)
	add_child(root)
	var tgt_rect: Rect2 = tgt_btn.get_global_rect()
	if tgt_rect.size.x < 4:
		tgt_rect = Rect2(tgt_btn.get_global_position(), Vector2(78, 78))
	var sz: Vector2 = Vector2(160, 190)
	root.size = sz
	root.custom_minimum_size = sz
	var center: Vector2 = tgt_rect.get_center()
	var crosshair_center: Vector2 = Vector2(80, 80)
	var pos: Vector2 = center - crosshair_center
	var vp: Vector2 = get_viewport_rect().size
	pos.x = clamp(pos.x, 4.0, vp.x - sz.x - 4.0)
	pos.y = clamp(pos.y, 4.0, vp.y - sz.y - 4.0)
	root.global_position = pos
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in root.get_children():
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fade in and looping fade in/out - half speed (was 0.35/0.55)
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(root, "modulate:a", 1.0, 0.70).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(root, "modulate:a", 0.25, 1.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Store tween so hide can kill it
	root.set_meta("fade_tween", tw)
	hover_arrow = root
	hover_arrow_target = tgt_btn

func _hide_attack_arrow():
	if hover_arrow != null and is_instance_valid(hover_arrow):
		if hover_arrow.has_meta("extra_arrows"):
			for p in hover_arrow.get_meta("extra_arrows") as Array:
				if p != null and is_instance_valid(p as Control):
					(p as Control).queue_free()
		# Stop looping fade and fade out smoothly before freeing
		if hover_arrow.has_meta("fade_tween"):
			var ft = hover_arrow.get_meta("fade_tween")
			if ft != null and is_instance_valid(ft as Tween):
				(ft as Tween).kill()
		var to_free: Control = hover_arrow as Control
		hover_arrow = null
		hover_arrow_target = null
		var tw2 := create_tween()
		tw2.tween_property(to_free, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw2.tween_callback(func(): if is_instance_valid(to_free): to_free.queue_free())
		return
	hover_arrow = null
	hover_arrow_target = null

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
	debug_popup.z_as_relative = false
	if debug_popup.has_method("set_as_top_level"):
		debug_popup.top_level = true
	debug_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.14, 0.97)
	sb.border_color = Color(0.9, 0.85, 0.4, 1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	debug_popup.add_theme_stylebox_override("panel", sb)
	# Responsive: cap to 90% of viewport, ScrollContainer for overflow
	var vp: Vector2 = get_viewport_rect().size
	if vp.x < 100:
		vp = Vector2(1920, 1080)
	var max_w: float = min(520.0, vp.x - 40.0)
	var max_h: float = min(560.0, vp.y - 40.0)
	max_w = max(max_w, 360.0)
	max_h = max(max_h, 320.0)
	debug_popup.custom_minimum_size = Vector2(max_w, 0)
	debug_popup.size = Vector2(max_w, 0)
	var scroll := ScrollContainer.new()
	scroll.name = "DebugScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(max_w - 20, min(520.0, max_h - 20))
	debug_popup.add_child(scroll)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.add_child(vbox)
	var title := Label.new()
	title.text = "Debug Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1,1,0.7))
	vbox.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(row)
	var lbl := Label.new()
	lbl.text = "Enemy:"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1,1,1))
	lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(lbl)
	debug_enemy_option = OptionButton.new()
	debug_enemy_option.custom_minimum_size = Vector2(150, 28)
	debug_enemy_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_enemy_option.add_theme_font_size_override("font_size", 16)
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
	summon_title.add_theme_font_size_override("font_size", 20)
	summon_title.add_theme_color_override("font_color", Color(1,1,1))
	summon_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(summon_title)
	var summon_row := HBoxContainer.new()
	summon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	summon_row.add_theme_constant_override("separation", 6)
	summon_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(summon_row)
	debug_summon_card_option = OptionButton.new()
	debug_summon_card_option.custom_minimum_size = Vector2(150, 28)
	debug_summon_card_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_summon_card_option.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	debug_summon_card_option.add_theme_font_size_override("font_size", 16)
	for cname in ["Wall", "Infantry", "Tank", "Artilery", "Rocket Launcher", "Drone", "Fighter Jet", "Factory", "Barracks", "Housing", "Corporation", "Howitzer", "Special Ops", "Anti Aircraft", "Interceptor"]:
		debug_summon_card_option.add_item(cname)
	summon_row.add_child(debug_summon_card_option)
	debug_summon_target_option = OptionButton.new()
	debug_summon_target_option.custom_minimum_size = Vector2(90, 28)
	debug_summon_target_option.add_theme_font_size_override("font_size", 16)
	debug_summon_target_option.add_item("Player", 0)
	debug_summon_target_option.add_item("AI", 1)
	summon_row.add_child(debug_summon_target_option)
	var summon_btn := Button.new()
	summon_btn.text = "Summon"
	summon_btn.custom_minimum_size = Vector2(80, 28)
	summon_btn.add_theme_font_size_override("font_size", 18)
	_style_round_button(summon_btn, true)
	summon_btn.pressed.connect(func():
		var cname2: String = debug_summon_card_option.get_item_text(debug_summon_card_option.selected)
		var target_is_ai: bool = debug_summon_target_option.selected == 1
		_debug_summon_card(cname2, target_is_ai)
	)
	summon_row.add_child(summon_btn)
	# Debug: end battle in victory and go to shop
	var victory_row := HBoxContainer.new()
	victory_row.alignment = BoxContainer.ALIGNMENT_CENTER
	victory_row.add_theme_constant_override("separation", 6)
	victory_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(victory_row)
	var victory_btn := Button.new()
	victory_btn.text = "Victory → Shop"
	victory_btn.custom_minimum_size = Vector2(140, 30)
	victory_btn.add_theme_font_size_override("font_size", 18)
	_style_round_button(victory_btn, true)
	victory_btn.pressed.connect(func():
		_debug_victory_to_shop()
		debug_popup.visible = false
	)
	victory_row.add_child(victory_btn)
	var victory_hint := Label.new()
	victory_hint.text = "(ends battle, grants Influence)"
	victory_hint.add_theme_font_size_override("font_size", 14)
	victory_hint.add_theme_color_override("font_color", Color(0.8,0.8,0.85))
	victory_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	victory_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	victory_row.add_child(victory_hint)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 8)
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(btn_row)
	var restart_btn := Button.new()
	restart_btn.text = "Switch & Restart"
	restart_btn.custom_minimum_size = Vector2(130, 30)
	restart_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_btn.add_theme_font_size_override("font_size", 18)
	_style_round_button(restart_btn, true)
	restart_btn.pressed.connect(_restart_game)
	btn_row.add_child(restart_btn)
	var close_dbtn := Button.new()
	close_dbtn.text = "Close"
	close_dbtn.custom_minimum_size = Vector2(70, 30)
	close_dbtn.add_theme_font_size_override("font_size", 18)
	_style_round_button(close_dbtn, false)
	close_dbtn.pressed.connect(func(): debug_popup.visible = false)
	btn_row.add_child(close_dbtn)
	var info := Label.new()
	info.text = "Background: " + (ai_player.BackgroundImage if ai_player.BackgroundImage != "" else ai_player.display_name)
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_color", Color(0.8,0.8,0.85))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(info)
	add_child(debug_popup)
	# center popup clamped to viewport
	_center_debug_popup()
	debug_built = true

func _reveal_debug_ui():
	var controls = get_node_or_null("VBox/Controls")
	if controls == null:
		return
	var btn = controls.get_node_or_null("DebugBtn")
	if btn != null:
		btn.visible = true

func _unhandled_input(event: InputEvent):
	# Forward mouse wheel to preview effect scroll when hovering over card (preview visible)
	if event is InputEventMouseButton and preview_popup != null and preview_popup.visible and _preview_eff_scroll != null:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var delta: int = -20 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 20
			var sb = _preview_eff_scroll.get_v_scroll_bar()
			var maxv: int = int(sb.max_value) if sb != null else 0
			if maxv == 0:
				# Fallback: estimate from content (RichTextLabel height - container height)
				var content = _preview_eff_scroll.get_child(0) as Control
				if content != null:
					maxv = int(max(0, content.size.y - _preview_eff_scroll.size.y))
			_preview_eff_scroll.scroll_vertical = clamp(_preview_eff_scroll.scroll_vertical + delta, 0, maxv)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		var is_backtick: bool = false
		if event.keycode == KEY_QUOTELEFT:
			is_backtick = true
		elif event.unicode == 96 or event.unicode == 126:
			is_backtick = true
		if is_backtick:
			var now: int = Time.get_ticks_msec()
			_debug_timestamps.append(now)
			# prune older than 2000ms
			var pruned: Array = []
			for t in _debug_timestamps:
				if now - int(t) <= 2000:
					pruned.append(t)
			_debug_timestamps = pruned
			if not _debug_unlocked and _debug_timestamps.size() >= 5:
				_debug_unlocked = true
				_reveal_debug_ui()
				_debug_timestamps.clear()
				# consume to prevent typing
				get_viewport().set_input_as_handled()

func _add_save_button():
	var controls = get_node_or_null("VBox/Controls")
	if controls == null:
		return
	if controls.has_node("SaveBtn"):
		return
	var sbtn := Button.new()
	sbtn.name = "SaveBtn"
	sbtn.text = "Save"
	sbtn.custom_minimum_size = Vector2(140, 40)
	sbtn.add_theme_font_size_override("font_size", 16)
	sbtn.add_theme_color_override("font_color", Color(0.6,1,0.6))
	_style_round_button(sbtn, false)
	sbtn.pressed.connect(func():
		var gs = get_node_or_null("/root/GameState")
		if gs != null and gs.has_method("save_game"):
			var ok: bool = gs.save_game()
			message_label.text = "Game saved." if ok else "Save failed."
		else:
			message_label.text = "Save not available."
	)
	controls.add_child(sbtn)
	var menu = controls.get_node_or_null("MenuBtn")
	if menu:
		controls.move_child(sbtn, menu.get_index())

func _add_debug_button():
	var controls = get_node_or_null("VBox/Controls")
	if controls == null:
		return
	if controls.has_node("DebugBtn"):
		return
	var btn := Button.new()
	btn.name = "DebugBtn"
	btn.text = "Debug"
	btn.visible = _debug_unlocked
	btn.custom_minimum_size = Vector2(140, 40)
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
	if vp.x < 100:
		vp = Vector2(1920, 1080)
	var sz: Vector2 = debug_popup.size
	if sz.x < 100 or sz.y < 100:
		sz = debug_popup.custom_minimum_size
		if sz.x < 100:
			sz = Vector2(520, 360)
	# Clamp to viewport with margin so it always fits
	sz.x = min(sz.x, vp.x - 40.0)
	sz.y = min(sz.y, vp.y - 40.0)
	debug_popup.size = sz
	var scroll := debug_popup.get_node_or_null("DebugScroll") as ScrollContainer
	if scroll != null:
		scroll.custom_minimum_size = Vector2(sz.x - 20, min(520.0, vp.y - 60.0))
	debug_popup.position = (vp - sz) / 2.0
	# Final clamp to keep inside screen
	debug_popup.position.x = clamp(debug_popup.position.x, 10.0, vp.x - sz.x - 10.0)
	debug_popup.position.y = clamp(debug_popup.position.y, 10.0, vp.y - sz.y - 10.0)

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
		"Special Ops": return SpecialOps.new()
		"Anti Aircraft": return AntiAircraft.new()
		"Interceptor": return Interceptor.new()
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

func _debug_victory_to_shop():
	if ai_player == null or human == null:
		message_label.text = "Debug: no battle active"
		return
	if ai_player.HitPoints <= 0:
		message_label.text = "Debug: battle already won"
		# still ensure shop shows
		_check_game_over()
		return
	ai_player.HitPoints = 0
	message_label.text = "Debug: forced victory over %s" % ai_player.display_name
	_check_game_over()

func _restart_game():
	var g = get_node_or_null("/root/GameState")
	if g != null and debug_enemy_option != null:
		g.set_enemy(debug_enemy_option.get_item_text(debug_enemy_option.selected))
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

# Kraj Shop: #1 popup centered not covering board red zone, #2 card art diegetic + cost non-diegetic, #3 only buyable matter (dim Owned), #4 vertical per-column grouping minimizes travel, #5 beige light weight, #6 fixed 5+3 grid worst-case
func _ensure_shop_popup():
	if shop_built:
		return
	shop_popup = PanelContainer.new()
	shop_popup.name = "ShopPopup"
	shop_popup.visible = false
	shop_popup.z_index = 105
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11,0.11,0.14,0.96)
	sb.border_color = Color(0.82,0.78,0.70,0.88)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	shop_popup.add_theme_stylebox_override("panel", sb)
	shop_popup.custom_minimum_size = Vector2(860, 560)
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
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1,0.92,0.5))
	title_row.add_child(title)
	var hint := Label.new()
	hint.text = "Buy 5 cards + 3 modifiers using Influence (cost = InfluenceCost). Remove a card for 25 Influence (once per shop)."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.78,0.78,0.84))
	vbox.add_child(hint)
	var offer: Array = []
	if gs != null and not gs.shop_offer.is_empty():
		offer = gs.shop_offer
	else:
		offer = CardFactory.random_shop_offer()
		if gs != null:
			gs.shop_offer = offer
			gs.shop_remove_used = false
	# Modifiers offer: 3 modifiers on separate row (persistent)
	var mod_offer: Array = []
	if gs != null and not gs.shop_modifier_offer.is_empty():
		mod_offer = gs.shop_modifier_offer
		# Filter any owned modifiers that may have been saved before the fix
		if gs.run_player != null:
			var _owned_mods: Array = []
			for mm in gs.run_player.Modifiers:
				if mm is Modifier:
					_owned_mods.append((mm as Modifier).modifier_name)
			var _filtered: Array = []
			for mm2 in mod_offer:
				if mm2 is Modifier and (mm2 as Modifier).modifier_name not in _owned_mods:
					_filtered.append(mm2)
			if _filtered.size() != mod_offer.size():
				mod_offer = _filtered
				gs.shop_modifier_offer = mod_offer
	else:
		var _owned2: Array = []
		if gs != null and gs.run_player != null:
			for mm in gs.run_player.Modifiers:
				if mm is Modifier:
					_owned2.append((mm as Modifier).modifier_name)
		mod_offer = CardFactory.random_modifier_offer_excluding(_owned2)
		if gs != null:
			gs.shop_modifier_offer = mod_offer
	# --- CARDS GRID: 5 rows (titles / art / bio+money / description / buy) x 5 cols - fixed to prevent shift on buy ---
	var card_grid := GridContainer.new()
	var _card_cols: int = 5
	card_grid.columns = _card_cols
	card_grid.add_theme_constant_override("h_separation", 12)
	card_grid.add_theme_constant_override("v_separation", 6)
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(card_grid)
	var _offer_sz: int = offer.size()
	# Row 1: titles
	for card in offer:
		var c := card as Card
		var name_lbl := Label.new()
		name_lbl.text = c.card_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(1,1,1))
		name_lbl.custom_minimum_size = Vector2(150, 28)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_grid.add_child(name_lbl)
	for i in range(_card_cols - _offer_sz):
		var _pad := Control.new()
		_pad.custom_minimum_size = Vector2(150, 28)
		_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_grid.add_child(_pad)
	# Row 2: art (96 centered in 150 col)
	for card in offer:
		var c2 := card as Card
		var art_center := CenterContainer.new()
		art_center.custom_minimum_size = Vector2(150, 96)
		art_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var art_wrap := Control.new()
		art_wrap.custom_minimum_size = Vector2(96, 96)
		art_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var art := Card.create_sprite_for(c2.card_name, Vector2(96,96))
		art.clip_contents = true
		art.custom_minimum_size = Vector2(96, 96)
		art.size = Vector2(96, 96)
		art.position = Vector2.ZERO
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art_wrap.add_child(art)
		art_center.add_child(art_wrap)
		card_grid.add_child(art_center)
	for i in range(_card_cols - _offer_sz):
		var _pad2 := Control.new()
		_pad2.custom_minimum_size = Vector2(150, 96)
		_pad2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_grid.add_child(_pad2)
	# Row 3: BioSupplyCost + MoneySupplyCost (new)
	for card in offer:
		var c_res := card as Card
		var res_row := HBoxContainer.new()
		res_row.alignment = BoxContainer.ALIGNMENT_CENTER
		res_row.add_theme_constant_override("separation", 8)
		res_row.custom_minimum_size = Vector2(150, 22)
		res_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bio_ic := TextureRect.new()
		bio_ic.texture = load("res://Assets/UI/bio_icon.png") as Texture2D
		bio_ic.custom_minimum_size = Vector2(18, 18)
		bio_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bio_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bio_ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		res_row.add_child(bio_ic)
		var bio_lbl := Label.new()
		bio_lbl.text = "%d" % c_res.BioCost
		bio_lbl.add_theme_font_size_override("font_size", 16)
		bio_lbl.add_theme_color_override("font_color", Color(0.6, 1, 0.4))
		res_row.add_child(bio_lbl)
		var sep := Label.new()
		sep.text = "|"
		sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sep.add_theme_font_size_override("font_size", 16)
		sep.add_theme_color_override("font_color", Color(0.6,0.6,0.6))
		res_row.add_child(sep)
		var mon_ic := TextureRect.new()
		mon_ic.texture = load("res://Assets/UI/money_icon.png") as Texture2D
		mon_ic.custom_minimum_size = Vector2(18, 18)
		mon_ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mon_ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mon_ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		res_row.add_child(mon_ic)
		var mon_lbl := Label.new()
		mon_lbl.text = "%d" % c_res.MoneyCost
		mon_lbl.add_theme_font_size_override("font_size", 16)
		mon_lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.35))
		res_row.add_child(mon_lbl)
		card_grid.add_child(res_row)
	for i in range(_card_cols - _offer_sz):
		var _pad3 := Control.new()
		_pad3.custom_minimum_size = Vector2(150, 22)
		_pad3.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_grid.add_child(_pad3)
	# Row 4: descriptions (influence cost + stats + effect stacked, fixed height per col)
	for card in offer:
		var c3 := card as Card
		var desc := VBoxContainer.new()
		desc.alignment = BoxContainer.ALIGNMENT_CENTER
		desc.add_theme_constant_override("separation", 2)
		desc.custom_minimum_size = Vector2(150, 92)
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cost_row := HBoxContainer.new()
		cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
		cost_row.add_theme_constant_override("separation", 4)
		var cost_icon := TextureRect.new()
		cost_icon.texture = load("res://Assets/UI/influence_icon.png") as Texture2D
		cost_icon.custom_minimum_size = Vector2(18,18)
		cost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cost_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		cost_row.add_child(cost_icon)
		var cost_lbl := Label.new()
		cost_lbl.text = "%d" % c3.InfluenceCost
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 16)
		cost_lbl.add_theme_color_override("font_color", Color(1,0.85,0.4))
		cost_row.add_child(cost_lbl)
		desc.add_child(cost_row)
		var stats := Label.new()
		if c3 is Unit:
			stats.text = "HP:%d DMG:%d" % [(c3 as Unit).HitPoints, (c3 as Unit).Damage]
		elif c3 is Building:
			stats.text = "HP:%d INC:%d" % [(c3 as Building).HitPoints, (c3 as Building).Income]
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.add_theme_font_size_override("font_size", 12)
		stats.add_theme_color_override("font_color", Color(0.9,0.9,1))
		stats.custom_minimum_size = Vector2(150, 18)
		desc.add_child(stats)
		var eff := RichTextLabel.new()
		eff.bbcode_enabled = true
		eff.fit_content = true
		eff.text = _effect_with_traits(c3 as Card)
		eff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		eff.custom_minimum_size = Vector2(150, 36)
		eff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eff.add_theme_font_size_override("normal_font_size", 11)
		eff.add_theme_color_override("default_color", Color(0.8,0.8,1))
		desc.add_child(eff)
		card_grid.add_child(desc)
	for i in range(_card_cols - _offer_sz):
		var _pad4 := Control.new()
		_pad4.custom_minimum_size = Vector2(150, 92)
		_pad4.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_grid.add_child(_pad4)
	# Row 5: buy buttons
	for card in offer:
		var c4 := card as Card
		var btn_center := CenterContainer.new()
		btn_center.custom_minimum_size = Vector2(150, 32)
		btn_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.custom_minimum_size = Vector2(80, 28)
		_style_round_button(buy_btn, true)
		buy_btn.disabled = influence < c4.InfluenceCost
		if buy_btn.disabled:
			buy_btn.modulate = Color(0.6,0.6,0.6)
		var _card_ref: Card = c4
		buy_btn.pressed.connect(func(): _buy_shop_card(_card_ref))
		btn_center.add_child(buy_btn)
		card_grid.add_child(btn_center)
	for i in range(_card_cols - _offer_sz):
		var _pad5 := Control.new()
		_pad5.custom_minimum_size = Vector2(150, 32)
		_pad5.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_grid.add_child(_pad5)
	# --- MODIFIERS GRID: same 4-row setup, 3 cols, right below cards ---
	var mod_label := Label.new()
	mod_label.text = "Modifiers (permanent until reset)"
	mod_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mod_label.add_theme_font_size_override("font_size", 14)
	mod_label.add_theme_color_override("font_color", Color(1,0.85,0.4))
	vbox.add_child(mod_label)
	var mod_grid := GridContainer.new()
	var _mod_cols: int = 3
	mod_grid.columns = _mod_cols
	mod_grid.add_theme_constant_override("h_separation", 14)
	mod_grid.add_theme_constant_override("v_separation", 6)
	mod_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(mod_grid)
	var _mod_sz: int = mod_offer.size()
	# Row 1: modifier titles
	for mod in mod_offer:
		var m := mod as Modifier
		var mname := Label.new()
		mname.text = m.modifier_name
		mname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mname.add_theme_font_size_override("font_size", 16)
		mname.add_theme_color_override("font_color", Color(1,0.92,0.6))
		mname.custom_minimum_size = Vector2(220, 28)
		mname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mname.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mod_grid.add_child(mname)
	for i in range(_mod_cols - _mod_sz):
		var _mpad := Control.new()
		_mpad.custom_minimum_size = Vector2(220, 28)
		_mpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mod_grid.add_child(_mpad)
	# Row 2: modifier art
	for mod in mod_offer:
		var m2 := mod as Modifier
		var mart_center := CenterContainer.new()
		mart_center.custom_minimum_size = Vector2(220, 128)
		mart_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mart_wrap := Control.new()
		mart_wrap.custom_minimum_size = Vector2(96, 96)
		mart_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mart := Modifier.create_sprite_for(m2.modifier_name, Vector2(96, 96))
		mart.custom_minimum_size = Vector2(96, 96)
		mart.size = Vector2(96, 96)
		mart.position = Vector2.ZERO
		mart_wrap.add_child(mart)
		mart_center.add_child(mart_wrap)
		mod_grid.add_child(mart_center)
	for i in range(_mod_cols - _mod_sz):
		var _mpad2 := Control.new()
		_mpad2.custom_minimum_size = Vector2(220, 128)
		_mpad2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mod_grid.add_child(_mpad2)
	# Row 3: modifier descriptions (effect + cost)
	for mod in mod_offer:
		var m3 := mod as Modifier
		var mdesc := VBoxContainer.new()
		mdesc.alignment = BoxContainer.ALIGNMENT_CENTER
		mdesc.add_theme_constant_override("separation", 3)
		mdesc.custom_minimum_size = Vector2(220, 88)
		mdesc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var meff := Label.new()
		meff.text = m3.Effect
		meff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		meff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		meff.custom_minimum_size = Vector2(220, 64)
		meff.add_theme_font_size_override("font_size", 11)
		meff.add_theme_color_override("font_color", Color(0.85,0.85,1))
		mdesc.add_child(meff)
		var mcost_row := HBoxContainer.new()
		mcost_row.alignment = BoxContainer.ALIGNMENT_CENTER
		mcost_row.add_theme_constant_override("separation", 4)
		var mcost_icon := TextureRect.new()
		mcost_icon.texture = load("res://Assets/UI/influence_icon.png") as Texture2D
		mcost_icon.custom_minimum_size = Vector2(18,18)
		mcost_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mcost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mcost_row.add_child(mcost_icon)
		var mcost_lbl := Label.new()
		mcost_lbl.text = "%d" % m3.InfluenceCost
		mcost_lbl.add_theme_font_size_override("font_size", 14)
		mcost_lbl.add_theme_color_override("font_color", Color(1,0.85,0.4))
		mcost_row.add_child(mcost_lbl)
		mdesc.add_child(mcost_row)
		mod_grid.add_child(mdesc)
	for i in range(_mod_cols - _mod_sz):
		var _mpad3 := Control.new()
		_mpad3.custom_minimum_size = Vector2(220, 88)
		_mpad3.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mod_grid.add_child(_mpad3)
	# Row 4: modifier buy buttons
	for mod in mod_offer:
		var m4 := mod as Modifier
		var mbtn_center := CenterContainer.new()
		mbtn_center.custom_minimum_size = Vector2(220, 32)
		mbtn_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mbuy := Button.new()
		mbuy.text = "Buy"
		mbuy.custom_minimum_size = Vector2(80, 28)
		_style_round_button(mbuy, true)
		var already_owned: bool = false
		if human != null:
			for om in human.Modifiers:
				if om is Modifier and (om as Modifier).modifier_name == m4.modifier_name:
					already_owned = true
					break
		mbuy.disabled = already_owned or influence < m4.InfluenceCost
		if mbuy.disabled:
			mbuy.modulate = Color(0.6,0.6,0.6)
			if already_owned:
				mbuy.text = "Owned"
		var _mod_ref: Modifier = m4
		mbuy.pressed.connect(func(): _buy_shop_modifier(_mod_ref))
		mbtn_center.add_child(mbuy)
		mod_grid.add_child(mbtn_center)
	for i in range(_mod_cols - _mod_sz):
		var _mpad4 := Control.new()
		_mpad4.custom_minimum_size = Vector2(220, 32)
		_mpad4.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mod_grid.add_child(_mpad4)
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

func _buy_shop_modifier(mod: Modifier):
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return
	if gs.buy_modifier(mod):
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
	if is_tutorial and tutorial_step <= 10:
		# Tutorial controls economy/hand manually - just refresh
		_refresh_ui()
		_highlight_tutorial()
		return
	# Economy phase for both — now owned by Player (via Housing.bio_rate)
	var human_bio_before: int = human.BioSupply
	var human_money_before: int = human.MoneySupply
	var ai_bio_before: int = ai_player.BioSupply
	var ai_money_before: int = ai_player.MoneySupply
	var human_hp_before: int = human.HitPoints
	var ai_hp_before: int = ai_player.HitPoints
	human.economy_phase()
	ai_player.economy_phase()
	_refresh_ui()
	await _animate_economy_gain(human_bio_before, human_money_before, human_hp_before, ai_bio_before, ai_money_before, ai_hp_before)
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
	# Legacy shim — redirects to new combined economy animation
	await _animate_economy_gain(_human_bio_before, _human_money_before, human.HitPoints, ai_bio_before, ai_money_before, ai_player.HitPoints)

func _animate_economy_gain(human_bio_before: int, human_money_before: int, human_hp_before: int, ai_bio_before: int, ai_money_before: int, ai_hp_before: int):
	# Human + AI income gain high-detail animations every turn
	var human_bio_gain: int = human.BioSupply - human_bio_before
	var human_money_gain: int = human.MoneySupply - human_money_before
	var ai_bio_gain: int = ai_player.BioSupply - ai_bio_before
	var ai_money_gain: int = ai_player.MoneySupply - ai_money_before
	var human_hp_gain: int = human.HitPoints - human_hp_before
	var ai_hp_gain: int = ai_player.HitPoints - ai_hp_before
	# Flash gauges
	for bar in [player_bio_bar, ai_bio_bar, player_money_bar, ai_money_bar, player_hp_bar, ai_hp_bar]:
		if bar != null and is_instance_valid(bar):
			bar.pivot_offset = bar.size * 0.5
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(bar, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(bar, "modulate", Color(1, 0.95, 0.4), 0.12)
			tw.set_parallel(false)
			tw.tween_property(bar, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(bar, "modulate", Color(1,1,1), 0.16)
	# Human Bio/Money/HP
	if human_bio_gain > 0:
		_spawn_income_effect(player_bio_bar, "bio", human_bio_gain)
	if human_money_gain > 0:
		_spawn_income_effect(player_money_bar, "money", human_money_gain)
	if human_hp_gain > 0:
		_spawn_heal_number(player_hp_bar, human_hp_gain)
		_spawn_special_effect(player_hp_bar, "income_bio")
	# AI Bio/Money/HP
	if ai_bio_gain > 0:
		_spawn_income_effect(ai_bio_bar, "bio", ai_bio_gain)
	if ai_money_gain > 0:
		_spawn_income_effect(ai_money_bar, "money", ai_money_gain)
	if ai_hp_gain > 0:
		_spawn_heal_number(ai_hp_bar, ai_hp_gain)
		_spawn_special_effect(ai_hp_bar, "income_bio")
	# Per-building income pulses — high detail: each building with Income>0 spawns +Income over its tile
	for player_entry in [[human, player_board_container], [ai_player, ai_board_container]]:
		var pl: Player = player_entry[0] as Player
		var cont: GridContainer = player_entry[1] as GridContainer
		if pl == null or cont == null:
			continue
		for r in range(pl.Board.size()):
			for c in range(pl.Board[r].Squares.size()):
				var sq: Square = pl.Board[r].Squares[c] as Square
				if sq.Inhabitant != null and sq.Inhabitant is Building:
					var inc: int = (sq.Inhabitant as Building).Income
					if inc > 0:
						var btn: Button = _get_button_for_square(pl, sq)
						if btn != null and is_instance_valid(btn):
							_spawn_income_effect(btn, "money", inc)
							btn.pivot_offset = btn.size*0.5
							var btw := create_tween()
							btw.tween_property(btn, "scale", Vector2(1.06,1.06), 0.08).set_trans(Tween.TRANS_BACK)
							btw.tween_property(btn, "scale", Vector2(1.0,1.0), 0.12).set_trans(Tween.TRANS_BACK)
							await get_tree().create_timer(0.04).timeout
	await get_tree().create_timer(0.45).timeout

func _animate_opponent_builds():
	var placed: Array = ai_player.take_build_turn(human)
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
	_apply_kraj_efficient_ui()
	_hide_hover()
	_hide_hand_label()
	_refresh_modifiers_stack()
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
	var ai_bio_inc: int = ai_player.predicted_bio_gain() if ai_player != null else 0
	var p_bio_inc: int = human.predicted_bio_gain() if human != null else 0
	var ai_income: int = ai_player.predicted_money_gain() if ai_player != null else 0
	var p_income: int = human.predicted_money_gain() if human != null else 0
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
	# Income shown on top — now includes Housing +8, building Income, Conscription/Corruption modifiers (mirrors economy_phase)
	ai_bio_income.text = "+%d" % ai_bio_inc
	player_bio_income.text = "+%d" % p_bio_inc
	ai_money_income.text = "+%d" % ai_income
	player_money_income.text = "+%d" % p_income
	# Deck / Discard / Graveyard gauges (33 max per updated spec, sprites under gauges / other side)
	for bar in [ai_deck_bar, player_deck_bar, ai_discard_bar, player_discard_bar, ai_graveyard_bar, player_graveyard_bar]:
		bar.max_value = 33
	ai_deck_bar.value = clamp(ai_player.DrawPile.size(), 0, 33)
	player_deck_bar.value = clamp(human.DrawPile.size(), 0, 33)
	ai_discard_bar.value = clamp(ai_player.DiscardPile.size(), 0, 33)
	player_discard_bar.value = clamp(human.DiscardPile.size(), 0, 33)
	ai_graveyard_bar.value = clamp(ai_player.Graveyard.size(), 0, 33)
	player_graveyard_bar.value = clamp(human.Graveyard.size(), 0, 33)
	ai_deck_value.text = "Opponent Pile %d/33" % ai_player.DrawPile.size()
	player_deck_value.text = "Draw %d/33" % human.DrawPile.size()
	ai_discard_value.text = "Discard %d/33" % ai_player.DiscardPile.size()
	player_discard_value.text = "Discard %d/33" % human.DiscardPile.size()
	ai_graveyard_value.text = "Graveyard %d/33" % ai_player.Graveyard.size()
	player_graveyard_value.text = "Graveyard %d/33" % human.Graveyard.size()
	# --- Pile animated art: 512x512 20fps square, rounded 44, no pulse, twice-detailed like Modifiers/Cards ---
	for entry in [
		[ai_deck_icon, "Draw", false],
		[player_deck_icon, "Draw", true],
		[ai_discard_icon, "Discard", false],
		[player_discard_icon, "Discard", true],
		[ai_graveyard_icon, "Graveyard", false],
		[player_graveyard_icon, "Graveyard", true]
	]:
		var btn: Button = entry[0] as Button
		var pile: String = entry[1] as String
		var is_human: bool = entry[2] as bool
		if btn == null:
			continue
		# Clear static icon, use animated PileArt inside button (keeps click/hover)
		btn.icon = null
		btn.text = ""
		btn.expand_icon = false
		btn.custom_minimum_size = Vector2(78, 78)
		btn.clip_contents = true
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		# No grey/black tile background — transparent button, sprite itself has rounded 44 and frame
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0,0,0,0)
		bg.set_corner_radius_all(6)
		bg.content_margin_left = 0
		bg.content_margin_right = 0
		bg.content_margin_top = 0
		bg.content_margin_bottom = 0
		bg.border_width_left = 0
		bg.border_width_right = 0
		bg.border_width_top = 0
		bg.border_width_bottom = 0
		bg.border_color = Color(0,0,0,0)
		btn.add_theme_stylebox_override("normal", bg)
		btn.add_theme_stylebox_override("hover", bg)
		btn.add_theme_stylebox_override("pressed", bg)
		btn.add_theme_stylebox_override("focus", bg)
		btn.add_theme_stylebox_override("disabled", bg)
		btn.flat = true
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Center the pile VBox above its bar (Icon centered horizontally over 78-wide bar)
		var pile_box := btn.get_parent() as VBoxContainer if btn.get_parent() != null else null
		if pile_box != null:
			pile_box.alignment = BoxContainer.ALIGNMENT_CENTER
			pile_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			pile_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Replace or create animated child
		var existing := btn.get_node_or_null("PileAnim") as Control
		if existing != null:
			existing.queue_free()
		# Clean any leftover static icon children from old code
		for c in btn.get_children():
			if c is Control and c.name != "PileAnim":
				if c.get_class() != "Control" or c.custom_minimum_size == Vector2(78,78):
					pass
		var anim := PileArt.create_sprite_for(pile, Vector2(78, 78))
		anim.name = "PileAnim"
		# AI draw pile label should read Opponent Pile instead of Draw
		if pile == "Draw" and btn == ai_deck_icon:
			for ch in anim.get_children():
				if ch is Label:
					(ch as Label).text = "Opponent Pile"
					(ch as Label).add_theme_font_size_override("font_size", int(78 * 0.10))
					break
		anim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		anim.clip_contents = true
		for ch in anim.get_children():
			if ch is Control:
				(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(anim)
	# Make pile bars 78 wide centered under 78-wide icon (Icon centered above Bar)
	for bar in [ai_deck_bar, player_deck_bar, ai_discard_bar, player_discard_bar, ai_graveyard_bar, player_graveyard_bar]:
		bar.custom_minimum_size = Vector2(78, 8)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Center pile value labels under bars
	for lbl in [ai_deck_value, player_deck_value, ai_discard_value, player_discard_value, ai_graveyard_value, player_graveyard_value]:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
				var hp_col_c: Color = player.get_hp_color(card) if player != null and player.has_method("get_hp_color") else Color(1,1,1)
				hp_lbl.add_theme_color_override("font_color", hp_col_c)
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
					# Show effective damage on field (with Barracks/Guerilla/Aerial) colored vs base
					var eff_dmg_board: int = player.effective_damage_for(card as Unit, sq) if player != null and player.has_method("effective_damage_for") else (card as Unit).Damage
					dmg_lbl.text = "%d" % eff_dmg_board
					dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					dmg_lbl.add_theme_font_size_override("font_size", 16)
					var dmg_col_c: Color = player.get_dmg_color(card, sq) if player != null and player.has_method("get_dmg_color") else Color(1,1,1)
					dmg_lbl.add_theme_color_override("font_color", dmg_col_c)
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
				# High-detail Barracks + Interceptor circular auras — cover full card art (128x128 anim), not top-left corner
				# Use circular PanelContainers centered over the 128 art, sized to fully cover it, with pulsing + rotation
				var is_barracks_adj: bool = card is Unit and Barracks.bonus_if_adjacent(player, sq) > 0
				var is_intercepted_idle: bool = player.MoneySupply >= 6 and not Interceptor.find_adjacent_interceptors(player, sq).is_empty()
				if is_barracks_adj or is_intercepted_idle:
					var aura_size: Vector2 = Vector2(148,148) # covers 128 art + spill, circular
					var aura := PanelContainer.new()
					aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
					aura.custom_minimum_size = aura_size
					aura.size = aura_size
					aura.clip_contents = false
					# Circular via half-radius
					var aura_sb := StyleBoxFlat.new()
					if is_barracks_adj and is_intercepted_idle:
						# Both effects: slightly more transparent as requested
						aura_sb.bg_color = Color(0.65,0.72,0.55,0.05)
						aura_sb.border_color = Color(0.75,0.80,0.60,0.42)
					elif is_barracks_adj:
						aura_sb.bg_color = Color(1,0.72,0.15,0.05)
						aura_sb.border_color = Color(1,0.78,0.25,0.48)
					else:
						aura_sb.bg_color = Color(0.35,0.75,1.0,0.05)
						aura_sb.border_color = Color(0.45,0.85,1.0,0.38)
					aura_sb.set_border_width_all(2)
					aura_sb.set_corner_radius_all(74) # fully circular (half of 148)
					if is_barracks_adj:
						aura_sb.shadow_color = Color(1,0.6,0.1,0.16)
					else:
						aura_sb.shadow_color = Color(0.2,0.5,1.0,0.18)
					aura_sb.shadow_size = 8
					aura.add_theme_stylebox_override("panel", aura_sb)
					aura.z_index = 2
					# Centered on square — use anchor-center so it stays centered even when button stretches via SIZE_EXPAND_FILL
					# Aura 148 covers full 128 art spill, circular
					btn.add_child(aura)
					aura.set_anchors_preset(Control.PRESET_CENTER)
					aura.offset_left = -aura_size.x * 0.5
					aura.offset_top = -aura_size.y * 0.5
					aura.offset_right = aura_size.x * 0.5
					aura.offset_bottom = aura_size.y * 0.5
					aura.pivot_offset = aura_size * 0.5
					# Circular animate: pulse scale + gentle rotation + modulate
					var atw := create_tween()
					atw.set_loops()
					atw.set_trans(Tween.TRANS_SINE)
					atw.set_ease(Tween.EASE_IN_OUT)
					atw.tween_property(aura, "scale", Vector2(1.06,1.06), 0.85)
					atw.tween_property(aura, "scale", Vector2(0.96,0.96), 0.85)
					var atw2 := create_tween()
					atw2.set_loops()
					atw2.tween_property(aura, "rotation", 0.18, 2.2).set_trans(Tween.TRANS_SINE)
					atw2.tween_property(aura, "rotation", -0.18, 2.2)
					var atw3 := create_tween()
					atw3.set_loops()
					atw3.set_trans(Tween.TRANS_SINE)
					atw3.tween_property(aura, "modulate", Color(1,1,1,0.85), 0.9)
					atw3.tween_property(aura, "modulate", Color(1,1,1,1), 0.9)
					if is_barracks_adj:
						# Add inner amber ring — slightly more transparent
						var inner := PanelContainer.new()
						inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
						inner.custom_minimum_size = Vector2(118,118)
						inner.size = Vector2(118,118)
						var inner_sb := StyleBoxFlat.new()
						inner_sb.bg_color = Color(1,0.72,0.15,0.0)
						inner_sb.border_color = Color(1,0.85,0.45,0.28)
						inner_sb.set_border_width_all(2)
						inner_sb.set_corner_radius_all(59)
						inner.add_theme_stylebox_override("panel", inner_sb)
						aura.add_child(inner)
						inner.position = (aura_size - Vector2(118,118))*0.5
						inner.pivot_offset = Vector2(59,59)
						var itw := create_tween()
						itw.set_loops()
						itw.tween_property(inner, "rotation", 6.28, 3.0).set_trans(Tween.TRANS_LINEAR)
					if is_intercepted_idle:
						var inner2 := PanelContainer.new()
						inner2.mouse_filter = Control.MOUSE_FILTER_IGNORE
						inner2.custom_minimum_size = Vector2(126,126)
						inner2.size = Vector2(126,126)
						var inner2_sb := StyleBoxFlat.new()
						inner2_sb.bg_color = Color(0.35,0.75,1.0,0.0)
						inner2_sb.border_color = Color(0.45,0.85,1.0,0.18)
						inner2_sb.set_border_width_all(2)
						inner2_sb.set_corner_radius_all(63)
						inner2.add_theme_stylebox_override("panel", inner2_sb)
						aura.add_child(inner2)
						inner2.position = (aura_size - Vector2(126,126))*0.5
						inner2.pivot_offset = Vector2(63,63)
						var i2tw := create_tween()
						i2tw.set_loops()
						i2tw.tween_property(inner2, "rotation", -6.28, 3.5).set_trans(Tween.TRANS_LINEAR)
				# Magnified preview on hover — flipped for middle rows: top 2 of player -> bottom, lower 2 of opponent -> top
				var _card_prev: Card = card
				var _row_for_hover: int = r
				var _is_player_board: bool = is_human
				# Invert hover side for middle confrontation rows (closest to center)
				# Human front row is 0 near middle (distance small), AI front is 3 near middle
				if is_human and _row_for_hover < 2:
					_is_player_board = false # top 2 rows of player (r=0,1 near middle) -> pop bottom
				elif not is_human and _row_for_hover >= 1:
					_is_player_board = true # lower 3 rows of opponent (r=1,2,3 includes second lowest) -> pop upwards
					# r=1 is second lowest from top (third from bottom) but visual second lowest is r=2; cover both by >=1
				var _anchor_board: Control = btn
				btn.mouse_entered.connect(func(): _show_card_preview(_card_prev, _is_player_board, _anchor_board))
				btn.mouse_exited.connect(func(): _hide_card_preview())
				# Non-random target arrow: show which enemy will be attacked (Manhattan closest)
				if card is Unit and not (card as Unit).HasRange:
					var attacker_player_ref: Player = player
					var defender_ref: Player = ai_player if player == human else human
					var sq_ref: Square = sq
					btn.mouse_entered.connect(func(): _show_attack_arrow(attacker_player_ref, sq_ref, defender_ref))
					btn.mouse_exited.connect(func(): _hide_attack_arrow())
				# No separate hover tooltip for cards — preview already shows effect
				btn.tooltip_text = ""
				# Keep enabled so hover shows (occupied squares are not clickable anyway)
				btn.disabled = false
				btn.mouse_filter = Control.MOUSE_FILTER_STOP
			container.add_child(btn)

func _refresh_hand():
	_hide_hover()
	if hand_container != null:
		hand_container.clip_contents = false
		var _rc := hand_container.get_parent()
		if _rc != null:
			_rc.clip_contents = false
	for child in hand_container.get_children():
		hand_container.remove_child(child)
		child.queue_free()
	# Display sorted alphabetically and stacked by identical card_name (count badge), keep Hand's random draw order intact
	var hand_sorted: Array = []
	for i in range(human.Hand.size()):
		hand_sorted.append({"card": human.Hand[i], "idx": i})
	hand_sorted.sort_custom(func(a, b): return (a["card"].card_name if a["card"] is Card else str(a["card"])) < (b["card"].card_name if b["card"] is Card else str(b["card"])))
	# Group identical cards for stacking
	var hand_grouped: Array = []
	var _last_name: String = ""
	var _group: Dictionary = {}
	for entry in hand_sorted:
		var cname: String = (entry["card"] as Card).card_name if entry["card"] is Card else str(entry["card"])
		if _group.is_empty() or cname != _last_name:
			if not _group.is_empty():
				hand_grouped.append(_group)
			_group = {"card": entry["card"], "idx": entry["idx"], "count": 1, "name": cname}
			_last_name = cname
		else:
			_group["count"] = (_group["count"] as int) + 1
	if not _group.is_empty():
		hand_grouped.append(_group)
	for _g in hand_grouped:
		var idx: int = _g["idx"] as int
		var card: Card = _g["card"] as Card
		var _stack_count: int = _g["count"] as int
		var btn := Button.new()
		btn.clip_contents = false
		btn.custom_minimum_size = Vector2(108, 68)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Determine effective vs base for coloring (green increased, red decreased)
		var base_hp: int = 0
		var base_dmg: int = 0
		var base_money: int = card.MoneyCost
		var base_bio: int = card.BioCost
		var eff_hp: int = 0
		var eff_dmg: int = 0
		var eff_money: int = human.get_effective_money_cost(card)
		var eff_bio: int = card.BioCost
		if card is Unit:
			base_hp = (card as Unit).HitPoints
			base_dmg = (card as Unit).Damage
			eff_hp = human.effective_hitpoints_for(card)
			# Effective dmg in hand: base + Guerilla/Aerial (no Barracks adjacency)
			var dmg: int = base_dmg
			if human.has_modifier("Guerilla Warfare") and card.BioCost > card.MoneyCost:
				dmg *= 2
			if human.has_modifier("Aerial Supremacy") and (card as Unit).Flying:
				dmg += 2
			eff_dmg = dmg
		elif card is Building:
			base_hp = (card as Building).HitPoints
			eff_hp = human.effective_hitpoints_for(card)
		var hp: int = base_hp
		var extra: String = ""
		if card is Unit:
			hp = base_hp
			extra = "DMG %d" % base_dmg
		elif card is Building:
			hp = base_hp
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
		h_hp.text = "%d" % eff_hp if eff_hp != 0 else "%d" % hp
		h_hp.add_theme_font_size_override("font_size", 16)
		var hp_col: Color = Color(1,1,1)
		if eff_hp != 0 and eff_hp != base_hp:
			hp_col = Color(0.35, 0.9, 0.35) if eff_hp > base_hp else Color(1, 0.35, 0.35)
		h_hp.add_theme_color_override("font_color", hp_col)
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
			h_dmg.text = "%d" % eff_dmg
			h_dmg.add_theme_font_size_override("font_size", 16)
			var dmg_col: Color = Color(1,1,1)
			if eff_dmg != base_dmg:
				dmg_col = Color(0.35, 0.9, 0.35) if eff_dmg > base_dmg else Color(1, 0.35, 0.35)
			h_dmg.add_theme_color_override("font_color", dmg_col)
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
		m_lbl.text = "%d" % eff_money
		m_lbl.add_theme_font_size_override("font_size", 16)
		var money_col: Color = Color(1,1,1)
		if eff_money != base_money:
			money_col = Color(1, 0.35, 0.35) if eff_money > base_money else Color(0.35, 0.9, 0.35)
		m_lbl.add_theme_color_override("font_color", money_col)
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
		b_lbl.text = "%d" % eff_bio
		b_lbl.add_theme_font_size_override("font_size", 16)
		var bio_col: Color = Color(1,1,1)
		if eff_bio != base_bio:
			bio_col = Color(1, 0.35, 0.35) if eff_bio > base_bio else Color(0.35, 0.9, 0.35)
		b_lbl.add_theme_color_override("font_color", bio_col)
		b_lbl.clip_contents = false
		b_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		b_lbl.custom_minimum_size = Vector2(0, 16)
		hand_costs.add_child(b_lbl)
		details.add_child(hand_costs)
		# Magnified preview on hover — hand card art + symbols + text enlarged
		var _hand_prev: Card = card
		var _anchor_hand: Control = btn
		btn.mouse_entered.connect(func(): _show_card_preview(_hand_prev, true, _anchor_hand))
		btn.mouse_exited.connect(func(): _hide_card_preview())
		# No separate hover tooltip for cards — preview already shows effect
		btn.tooltip_text = ""
		btn.add_child(hand_hbox)
		# Stack count badge pinned to bottom-right of grey rounded rect (Button's background) — bigger in hand
		if _stack_count > 1:
			var _badge_wrap := Control.new()
			_badge_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_badge_wrap.custom_minimum_size = Vector2(36, 28)
			_badge_wrap.size = Vector2(36, 28)
			_badge_wrap.z_index = 10
			# Anchor to bottom-right so it stays pinned when Button stretches horizontally with hand size
			_badge_wrap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			_badge_wrap.anchor_left = 1.0
			_badge_wrap.anchor_top = 1.0
			_badge_wrap.anchor_right = 1.0
			_badge_wrap.anchor_bottom = 1.0
			_badge_wrap.offset_left = -36 - 4
			_badge_wrap.offset_top = -28 - 4
			_badge_wrap.offset_right = -4
			_badge_wrap.offset_bottom = -4
			_badge_wrap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			_badge_wrap.grow_vertical = Control.GROW_DIRECTION_BEGIN
			var _badge_bg := PanelContainer.new()
			_badge_bg.custom_minimum_size = Vector2(36, 28)
			_badge_bg.size = Vector2(36, 28)
			_badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var _sb := StyleBoxFlat.new()
			_sb.bg_color = Color(0.92, 0.22, 0.22, 1)
			_sb.set_corner_radius_all(14)
			_sb.border_color = Color(1,1,1,0.9)
			_sb.set_border_width_all(2)
			_badge_bg.add_theme_stylebox_override("panel", _sb)
			var _badge_lbl := Label.new()
			_badge_lbl.text = "X%d" % _stack_count
			_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_badge_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_badge_lbl.add_theme_font_size_override("font_size", 16)
			_badge_lbl.add_theme_color_override("font_color", Color(1,1,1))
			_badge_lbl.add_theme_color_override("font_outline_color", Color(0,0,0,0.9))
			_badge_lbl.add_theme_constant_override("outline_size", 5)
			_badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_badge_bg.add_child(_badge_lbl)
			_badge_wrap.add_child(_badge_bg)
			btn.add_child(_badge_wrap)
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
	if is_tutorial:
		# Generic tutorial: any highlighted card is acceptable (no specific names)
		var expected: String = ""
		var seq := _tutorial_sequence_for_step(tutorial_step)
		var trig: String = seq.get("trigger", "") as String
		if trig == "select_any":
			expected = ""  # any card allowed
		elif trig.begins_with("select_"):
			expected = trig.substr(7)
			if expected == "any":
				expected = ""
		if expected != "" and (human.Hand[idx] as Card).card_name != expected:
			_log_tutorial_analytics("wrong_card_tap", tutorial_step, expected, (human.Hand[idx] as Card).card_name)
			message_label.text = "Tutorial: Please click the highlighted card"
			tutorial_label.text = "Please tap the [color=#ffcc66]highlighted card[/color] in your hand!"
			return
	if selected_card_idx == idx:
		selected_card = null
		selected_card_idx = -1
		message_label.text = "Deselected"
	else:
		selected_card = human.Hand[idx]
		selected_card_idx = idx
		message_label.text = "Selected %s - click empty square to place" % selected_card.card_name
		if is_tutorial and tutorial_step == 0:
			tutorial_step = 1
			_update_tutorial_message()
		elif is_tutorial and tutorial_step == 4:
			tutorial_step = 5
			_update_tutorial_message()
		elif is_tutorial and tutorial_step == 8:
			tutorial_step = 9
			_update_tutorial_message()
	_refresh_hand()

func _on_board_click(r: int, c: int):
	if selected_card == null:
		message_label.text = "Select a card first"
		return
	if is_tutorial:
		if tutorial_step == 9:
			# Generic adjacency: must be next to any friendly unit already on board
			var anchor_pos = null
			for rr in range(human.Board.size()):
				for cc in range(human.Board[rr].Squares.size()):
					var sq2: Square = human.Board[rr].Squares[cc]
					if sq2.Inhabitant != null and sq2.Inhabitant is Unit:
						anchor_pos = {"r": rr, "c": cc}
						break
				if anchor_pos != null:
					break
			if anchor_pos != null:
				var dr: int = abs(r - anchor_pos["r"])
				var dc: int = abs(c - anchor_pos["c"])
				if not (dr <=1 and dc <=1 and not (dr==0 and dc==0)):
					_log_tutorial_analytics("wrong_placement", tutorial_step, "adjacent_any", "%d,%d" % [r,c])
					message_label.text = "Tutorial: Place next to your unit!"
					tutorial_label.text = "Place on a [color=#88ff88]glowing adjacent square[/color] next to your unit."
					return
			elif tutorial_step not in [1,5,9]:
				message_label.text = "Tutorial: Not the right step for placement"
				return
	var ok: bool = human.play_card(selected_card, r, c)
	if ok:
		message_label.text = "Placed %s at [%d,%d]" % [selected_card.card_name, r, c]
		var placed_name: String = selected_card.card_name
		selected_card = null
		selected_card_idx = -1
		if is_tutorial:
			# Generic placement advance - any card placed at correct generic step
			if tutorial_step == 1:
				tutorial_step = 2
				_update_tutorial_message()
			elif tutorial_step == 5:
				tutorial_step = 6
				_update_tutorial_message()
			elif tutorial_step == 9:
				tutorial_step = 10
				_update_tutorial_message()
	else:
		message_label.text = "Cannot place there (cost or occupied)"
	_refresh_ui()

func _refresh_gauges_only():
	_hide_hand_label()
	_refresh_influence_display()
	# Vertical gauges: HP at player's max, Bio 0-200, Money 0-200 (clamped), white text, income on Money+Bio
	var ai_bio_inc: int = ai_player.predicted_bio_gain() if ai_player != null else 0
	var p_bio_inc: int = human.predicted_bio_gain() if human != null else 0
	var ai_income: int = ai_player.predicted_money_gain() if ai_player != null else 0
	var p_income: int = human.predicted_money_gain() if human != null else 0
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
	ai_money_income.text = "+%d" % ai_income
	player_money_income.text = "+%d" % p_income
	for bar in [ai_deck_bar, player_deck_bar, ai_discard_bar, player_discard_bar, ai_graveyard_bar, player_graveyard_bar]:
		bar.max_value = 33
	ai_deck_bar.value = clamp(ai_player.DrawPile.size(), 0, 33) if ai_player != null else 0
	player_deck_bar.value = clamp(human.DrawPile.size(), 0, 33) if human != null else 0
	ai_discard_bar.value = clamp(ai_player.DiscardPile.size(), 0, 33) if ai_player != null else 0
	player_discard_bar.value = clamp(human.DiscardPile.size(), 0, 33) if human != null else 0
	ai_graveyard_bar.value = clamp(ai_player.Graveyard.size(), 0, 33) if ai_player != null else 0
	player_graveyard_bar.value = clamp(human.Graveyard.size(), 0, 33) if human != null else 0
	ai_deck_value.text = "Opponent Pile %d/33" % (ai_player.DrawPile.size() if ai_player != null else 0)
	player_deck_value.text = "Draw %d/33" % (human.DrawPile.size() if human != null else 0)
	ai_discard_value.text = "Discard %d/33" % (ai_player.DiscardPile.size() if ai_player != null else 0)
	player_discard_value.text = "Discard %d/33" % (human.DiscardPile.size() if human != null else 0)
	ai_graveyard_value.text = "Graveyard %d/33" % (ai_player.Graveyard.size() if ai_player != null else 0)
	player_graveyard_value.text = "Graveyard %d/33" % (human.Graveyard.size() if human != null else 0)
	# Keep pile animated (ensure PileAnim exists in live updates too, no re-load of static pngs)
	for entry in [
		[ai_deck_icon, "Draw"],
		[player_deck_icon, "Draw"],
		[ai_discard_icon, "Discard"],
		[player_discard_icon, "Discard"],
		[ai_graveyard_icon, "Graveyard"],
		[player_graveyard_icon, "Graveyard"]
	]:
		var b2: Button = entry[0] as Button
		var pile2: String = entry[1] as String
		if b2 != null and b2.get_node_or_null("PileAnim") == null:
			b2.icon = null
			b2.custom_minimum_size = Vector2(78,78)
			b2.clip_contents = true
			var anim2 := PileArt.create_sprite_for(pile2, Vector2(78,78))
			anim2.name = "PileAnim"
			if pile2 == "Draw" and b2 == ai_deck_icon:
				for ch in anim2.get_children():
					if ch is Label:
						(ch as Label).text = "Opponent Pile"
						(ch as Label).add_theme_font_size_override("font_size", int(78 * 0.10))
						break
			anim2.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for ch in anim2.get_children():
				if ch is Control:
					(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			b2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var pile_box2 := b2.get_parent() as VBoxContainer if b2.get_parent() != null else null
			if pile_box2 != null:
				pile_box2.alignment = BoxContainer.ALIGNMENT_CENTER
			b2.add_child(anim2)
	for pair in [[ai_deck_icon, ai_player.DrawPile.size() if ai_player != null else 0], [player_deck_icon, human.DrawPile.size() if human != null else 0]]:
		pair[0].modulate = Color(1, 0.4, 0.4) if pair[1] <= 3 else Color(1, 1, 1)
	ai_hp_bar.tint_progress = Color(1, 0.35, 0.35) if ai_player != null and ai_player.HitPoints < 30 else Color(1,1,1)
	player_hp_bar.tint_progress = Color(1, 0.35, 0.35) if human != null and human.HitPoints < 30 else Color(1,1,1)

func _refresh_boards_only():
	_refresh_board(ai_board_container, ai_player, false)
	_refresh_board(player_board_container, human, true)

func _on_end_turn():
	if is_tutorial:
		if tutorial_step == 2:
			# First End Turn - Housing placed, AI plays 2 drones
			end_turn_btn.disabled = true
			selected_card = null
			selected_card_idx = -1
			message_label.text = "Ending turn..."
			tutorial_step = 3
			_update_tutorial_message()
			await get_tree().create_timer(0.6).timeout
			_tutorial_ai_drones()
			# Combat with drones vs housing
			var log: Array = await _execute_combat_live()
			if log.is_empty():
				message_label.text = "Drones attacked your Housing!"
			else:
				message_label.text = "Drones dealt %d attacks!" % log.size()
			_refresh_ui()
			# Keep hand (don't discard tutorial cards) - just refresh
			end_turn_btn.disabled = false
			return
		elif tutorial_step == 6:
			end_turn_btn.disabled = true
			selected_card = null
			selected_card_idx = -1
			message_label.text = "Ending turn... watch Infantry targeting"
			tutorial_step = 7
			_update_tutorial_message()
			# Infantry will attack now, then AI wall
			var log2: Array = await _execute_combat_live()
			_refresh_ui()
			await get_tree().create_timer(0.5).timeout
			_tutorial_ai_wall()
			# After wall, don't do combat yet, just refresh
			end_turn_btn.disabled = false
			return
		elif tutorial_step == 10:
			end_turn_btn.disabled = true
			selected_card = null
			selected_card_idx = -1
			tutorial_step = 11
			_update_tutorial_message()
			var log3: Array = await _execute_combat_live()
			_refresh_ui()
			if _check_game_over():
				return
			# Tutorial complete - switch to free play
			await get_tree().create_timer(1.0).timeout
			if tutorial_overlay != null and is_instance_valid(tutorial_overlay):
				tutorial_overlay.visible = false
			is_tutorial = false
			var gs := get_node_or_null("/root/GameState")
			if gs != null:
				gs.is_tutorial = false
			message_label.text = "Tutorial complete! Free play - defeat the Insurgents!"
			end_turn_btn.disabled = false
			return
		else:
			message_label.text = "Tutorial: Please follow the highlighted steps"
			_update_tutorial_message()
			return
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
				var has_range: bool = unit.HasRange
				if attacker.has_method("has_range_for"):
					has_range = attacker.has_range_for(unit)
				var target = state._pick_target_manhattan(defender, attacker, sq, has_range, rng)
				if target == null:
					defender.HitPoints -= dmg
					defender.HitPoints = clamp(defender.HitPoints, 0, defender.MaxHitPoints)
					var entry: Dictionary = {"attacker": unit, "attacker_sq": sq, "attacker_player": attacker, "defender": defender, "target": null, "target_sq": null, "damage": dmg, "is_direct": true}
					log.append(entry)
					await _animate_live_entry(entry)
					# show player HP drop immediately
					_refresh_gauges_only()
					if get_tree() != null:
						await get_tree().process_frame
					continue
				var target_card: Card = target["card"]
				var target_sq: Square = target["square"]
				var actual_dmg: int = dmg
				var att_has_range: bool = unit.HasRange
				if attacker.has_method("has_range_for"):
					att_has_range = attacker.has_range_for(unit)
				if unit is SpecialOps and target_card is Unit and not (target_card as Unit).Flying:
					actual_dmg *= 2
				elif unit is AntiAircraft and target_card is Unit and (target_card as Unit).Flying:
					actual_dmg *= 3
				if target_card is Unit and (target_card as Unit).Flying and not att_has_range and not (unit is AntiAircraft and (target_card as Unit).Flying):
					actual_dmg = int(actual_dmg / 2)
					if actual_dmg < 1:
						actual_dmg = 1
				var dmg_before_intercept: int = actual_dmg
				var intercepted: bool = false
				var intercept_src_sq: Square = null
				if target_card is Unit or target_card is Building:
					var before: int = actual_dmg
					actual_dmg = Interceptor.apply_interception(defender, target_sq, target_card, unit, attacker, actual_dmg)
					if actual_dmg < before:
						intercepted = true
						var srcs: Array = Interceptor.find_adjacent_interceptors(defender, target_sq)
						if not srcs.is_empty():
							intercept_src_sq = srcs[0] as Square
				if target_card is Unit:
					(target_card as Unit).HitPoints -= actual_dmg
				elif target_card is Building:
					(target_card as Building).HitPoints -= actual_dmg
				if unit is FighterJet:
					state._apply_fighter_splash(defender, target_sq, actual_dmg)
				state._apply_special_effect(unit, target_card)
				var entry2: Dictionary = {"attacker": unit, "attacker_sq": sq, "attacker_player": attacker, "defender": defender, "target": target_card, "target_sq": target_sq, "damage": actual_dmg, "is_direct": false, "intercepted": intercepted, "intercept_src_sq": intercept_src_sq, "dmg_before_intercept": dmg_before_intercept}
				log.append(entry2)
				await _animate_live_entry(entry2)
				# apply interceptor HP/Money drift immediately if it survived
				if intercepted:
					if intercept_src_sq != null:
						var ib: Button = _get_button_for_square(defender, intercept_src_sq)
						if ib != null and is_instance_valid(ib):
							_spawn_special_effect(ib, "interceptor_intercept")
							_spawn_damage_number(ib, 2)
					# money flicker on interceptor owner bar
					var bar: TextureProgressBar = ai_money_bar if defender == ai_player else player_money_bar
					if bar != null and is_instance_valid(bar):
						bar.modulate = Color(1, 0.4, 0.4)
						var ft := create_tween()
						ft.tween_property(bar, "modulate", Color(1,1,1), 0.4)
				state._resolve_deaths(defender)
				# reflect HP bars, card HP/INC labels, and deaths immediately
				_refresh_gauges_only()
				_refresh_boards_only()
				if get_tree() != null:
					await get_tree().process_frame
				# if target died already handled, next iteration picks new alive target
			state._resolve_deaths(defender)
			_refresh_gauges_only()
			_refresh_boards_only()
			if get_tree() != null:
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
	# Barracks buff has no special attack animation (removed per request)
	# Projectile: unique per-card 20-frame high-rectangle derived from regular sprite
	_spawn_attack_projectile(attacker_card, atk_btn, tgt_btn if not is_direct else tgt_hp_bar)
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
			# High-detail interceptor shield if this hit was intercepted
			var was_intercepted: bool = entry.get("intercepted", false)
			if was_intercepted:
				_spawn_special_effect(tgt_btn, "interceptor_intercept")
				# shield ring overlay on protected target
				var shield := PanelContainer.new()
				shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
				shield.z_index = 210
				shield.custom_minimum_size = Vector2(96,96)
				shield.size = Vector2(96,96)
				var sbs := StyleBoxFlat.new()
				sbs.bg_color = Color(0.35,0.75,1.0,0.0)
				sbs.border_color = Color(0.45,0.85,1.0,0.92)
				sbs.set_border_width_all(3)
				sbs.set_corner_radius_all(18)
				sbs.shadow_color = Color(0.2,0.5,1.0,0.55)
				sbs.shadow_size = 10
				shield.add_theme_stylebox_override("panel", sbs)
				add_child(shield)
				var sr: Rect2 = tgt_btn.get_global_rect()
				if sr.size == Vector2.ZERO:
					sr = Rect2(tgt_btn.get_global_position(), Vector2(80,80))
				var sc: Vector2 = sr.get_center() - get_global_rect().position
				shield.position = sc - shield.size*0.5
				shield.pivot_offset = shield.size*0.5
				shield.scale = Vector2(0.45,0.45)
				var stw := create_tween()
				stw.set_parallel(true)
				stw.tween_property(shield, "scale", Vector2(1.15,1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				stw.tween_property(shield, "modulate", Color(1,1,1,0), 0.22).set_delay(0.08)
				stw.set_parallel(false)
				stw.tween_callback(func(): if is_instance_valid(shield): shield.queue_free())
				_spawn_damage_number(tgt_btn, dmg)
				# also show blocked amount as green +number
				var blocked: int = entry.get("dmg_before_intercept", dmg) - dmg
				if blocked > 0:
					_spawn_heal_number(tgt_btn, blocked)
			else:
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
		# Barracks buff has no special attack animation (removed per request)
		# Projectile: unique per-card 20-frame high-rectangle derived from regular sprite
		_spawn_attack_projectile(attacker_card, atk_btn, tgt_btn if not is_direct else tgt_hp_bar)
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

func _get_projectile_frames(card_name: String) -> SpriteFrames:
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
	# Fallback: try card attack frames if projectile not found (e.g., for buildings)
	if sf.get_frame_count("fly") == 0:
		for i in range(20):
			var f2: String = "res://Assets/Cards/%s/attack/sprite_%d.png" % [card_name, i]
			if ResourceLoader.exists(f2):
				var tex2 := load(f2) as Texture2D
				if tex2 != null:
					sf.add_frame("fly", tex2)
	return sf

func _spawn_attack_projectile(attacker_card: Card, attacker_btn: Button, target_btn: Control):
	if attacker_card == null or attacker_btn == null or target_btn == null or not is_instance_valid(attacker_btn) or not is_instance_valid(target_btn):
		return
	var sf := _get_projectile_frames(attacker_card.card_name)
	if sf.get_frame_count("fly") == 0:
		return
	var start_rect: Rect2 = attacker_btn.get_global_rect()
	var end_rect: Rect2 = target_btn.get_global_rect()
	if start_rect.size == Vector2.ZERO:
		start_rect = Rect2(attacker_btn.get_global_position(), Vector2(78,78))
	if end_rect.size == Vector2.ZERO:
		end_rect = Rect2(target_btn.get_global_position(), Vector2(78,78))
	var start_pos: Vector2 = start_rect.get_center()
	var end_pos: Vector2 = end_rect.get_center()
	# Unique per-card projectile count and trajectory
	var burst: int = 1
	if attacker_card.card_name == "Interceptor":
		burst = 2
	elif attacker_card.card_name == "Howitzer" or attacker_card.card_name == "Anti Aircraft":
		burst = 2
	elif attacker_card.card_name == "Rocket Launcher":
		burst = 3
	# Spawn burst projectiles with slight stagger
	for b in range(burst):
		var proj := Control.new()
		proj.mouse_filter = Control.MOUSE_FILTER_IGNORE
		proj.z_index = 160
		proj.z_as_relative = false
		if proj.has_method("set_as_top_level"):
			proj.top_level = true
		proj.clip_contents = false
		var asp := AnimatedSprite2D.new()
		asp.sprite_frames = sf
		asp.animation = "fly"
		asp.centered = true
		asp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		# Scale projectile to be visible but not too large: 128 base -> 28-36 on board
		var base: float = 128.0
		if sf.get_frame_count("fly") > 0:
			var tex: Texture2D = sf.get_frame_texture("fly", 0)
			if tex != null:
				base = float(tex.get_width())
		var scale_f: float = 38.0 / base
		if attacker_card.card_name == "Tank":
			scale_f = 50.0 / base
		elif attacker_card.card_name == "Interceptor":
			scale_f = 34.0 / base
		elif attacker_card.card_name == "Fighter Jet":
			scale_f = 42.0 / base
		elif attacker_card.card_name == "Infantry":
			scale_f = 36.0 / base
		asp.scale = Vector2(scale_f, scale_f)
		proj.add_child(asp)
		asp.position = Vector2.ZERO
		asp.play("fly")
		# Position projectile at start
		var offset: Vector2 = Vector2.ZERO
		if burst > 1:
			offset = Vector2(0, (b - (burst-1)*0.5)*14)
		proj.position = start_pos + offset
		add_child(proj)
		# Animate to target: linear for bullets, arc for artillery
		var duration: float = 0.35
		if attacker_card.card_name == "Infantry":
			duration = 0.22
		elif attacker_card.card_name == "Tank":
			duration = 0.40
		elif attacker_card.card_name == "Artilery" or attacker_card.card_name == "Howitzer":
			duration = 0.45
		elif attacker_card.card_name == "Rocket Launcher":
			duration = 0.50
		elif attacker_card.card_name == "Interceptor":
			duration = 0.32
		# Stagger burst
		duration += b * 0.06
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE)
		tw.set_ease(Tween.EASE_IN_OUT)
		# For arc projectiles, add height via parallel y offset
		if attacker_card.card_name == "Artilery" or attacker_card.card_name == "Howitzer" or attacker_card.card_name == "Tank":
			var mid: Vector2 = (start_pos + end_pos) * 0.5 + Vector2(0, -60) + offset
			tw.tween_property(proj, "position", mid, duration*0.5)
			tw.tween_property(proj, "position", end_pos + offset, duration*0.5)
		else:
			tw.tween_property(proj, "position", end_pos + offset, duration)
		# Rotate to face target
		var dir: Vector2 = (end_pos - start_pos).normalized()
		asp.rotation = dir.angle()
		# Cleanup after
		var proj_ref: Control = proj
		if get_tree() != null:
			get_tree().create_timer(duration + 0.15).timeout.connect(func():
				if is_instance_valid(proj_ref):
					proj_ref.queue_free()
			)
		# Small delay between burst projectiles
		if burst > 1 and b < burst-1:
			await get_tree().create_timer(0.07).timeout

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
	sb.set_border_width_all(2)
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

func _spawn_heal_number(anchor: Control, amt: int):
	if anchor == null or not is_instance_valid(anchor):
		return
	if amt <= 0:
		return
	var lbl := Label.new()
	lbl.text = "+%d" % amt
	lbl.add_theme_font_size_override("font_size", 46)
	lbl.add_theme_color_override("font_color", Color(0.2, 1, 0.4))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 7)
	lbl.z_index = 301
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate = Color(0.2, 1, 0.4, 1)
	add_child(lbl)
	var anchor_rect: Rect2 = anchor.get_global_rect()
	if anchor_rect.size == Vector2.ZERO:
		anchor_rect = Rect2(anchor.get_global_position(), Vector2(80, 80))
	var center: Vector2 = anchor_rect.get_center()
	var local_center: Vector2 = center - get_global_rect().position
	lbl.position = local_center + Vector2(14, -10)
	lbl.scale = Vector2(0.7, 0.7)
	lbl.pivot_offset = lbl.size * 0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position", local_center + Vector2(14, -36), 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate", Color(0.2, 1, 0.4, 0), 0.48).set_delay(0.22)
	tw.set_parallel(false)
	tw.tween_callback(func(): if is_instance_valid(lbl): lbl.queue_free())

func _spawn_income_effect(anchor: Control, kind: String, amount: int):
	if anchor == null or not is_instance_valid(anchor):
		return
	if amount <= 0:
		return
	# particle effect from Assets/Effects/income_*
	var eff_kind: String = "income_money" if kind == "money" else "income_bio"
	_spawn_special_effect(anchor, eff_kind)
	var col: Color = Color(1, 0.85, 0.15) if kind == "money" else Color(0.3, 1, 0.5)
	var lbl := Label.new()
	lbl.text = "+%d" % amount
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0,0,0,1))
	lbl.add_theme_constant_override("outline_size", 7)
	lbl.z_index = 305
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate = col
	add_child(lbl)
	var anchor_rect: Rect2 = anchor.get_global_rect()
	if anchor_rect.size == Vector2.ZERO:
		anchor_rect = Rect2(anchor.get_global_position(), Vector2(80,80))
	var center: Vector2 = anchor_rect.get_center()
	var local_center: Vector2 = center - get_global_rect().position
	lbl.position = local_center + Vector2(-14, -8)
	lbl.scale = Vector2(0.6,0.6)
	lbl.pivot_offset = lbl.size*0.5
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2(1.08,1.08), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position", local_center + Vector2(-14, -38), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate", Color(col.r, col.g, col.b, 0), 0.55).set_delay(0.2)
	tw.set_parallel(false)
	tw.tween_callback(func(): if is_instance_valid(lbl): lbl.queue_free())
	# anchor bounce
	var atw := create_tween()
	atw.tween_property(anchor, "scale", Vector2(1.08,1.08), 0.08).set_trans(Tween.TRANS_BACK)
	atw.tween_property(anchor, "scale", Vector2(1.0,1.0), 0.14).set_trans(Tween.TRANS_BACK)


func _inspect_ai_full_deck():
	# Show full deck composition, not remaining DrawPile, so hand cannot be guessed
	if ai_player == null:
		return
	var full: Array = ai_player.get_full_deck_for_inspection() if ai_player.has_method("get_full_deck_for_inspection") else ai_player.DrawPile
	# Sort for stable view and to hide hand/draw order
	full.sort_custom(func(a,b): return (a.card_name if a is Card else str(a)) < (b.card_name if b is Card else str(b)))
	_inspect_pile("AI Deck (Full)", full)
func _inspect_pile(title: String, pile: Array):
	# Sort and stack identical cards alphabetically (count badge), keep actual pile order (draw order) untouched
	var view_pile: Array = pile.duplicate()
	view_pile.sort_custom(func(a, b): return (a.card_name if a is Card else str(a)) < (b.card_name if b is Card else str(b)))
	# Group identical for stacking
	var pile_grouped: Array = []
	var _last: String = ""
	var _g: Dictionary = {}
	for c in view_pile:
		var cn: String = c.card_name if c is Card else str(c)
		if _g.is_empty() or cn != _last:
			if not _g.is_empty():
				pile_grouped.append(_g)
			_g = {"card": c, "count": 1, "name": cn}
			_last = cn
		else:
			_g["count"] = (_g["count"] as int) + 1
	if not _g.is_empty():
		pile_grouped.append(_g)
	var pile_sorted: Array = []
	for g in pile_grouped:
		pile_sorted.append(g["card"])
	# Keep counts aligned with pile_sorted via dictionary lookup
	var _pile_counts: Dictionary = {}
	for g in pile_grouped:
		_pile_counts[g["name"]] = g["count"]
	inspect_title.text = "%s (%d)" % [title, pile.size()]
	# Clear previous grid
	for child in inspect_grid.get_children():
		inspect_grid.remove_child(child)
		child.queue_free()
	# configure grid for transposed 4-row layout
	inspect_grid.add_theme_constant_override("h_separation", 10)
	inspect_grid.add_theme_constant_override("v_separation", 6)
	if pile.is_empty():
		inspect_grid.columns = 1
		var empty_lbl := Label.new()
		empty_lbl.text = "(empty)"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		inspect_grid.add_child(empty_lbl)
	else:
		var cols: int = pile_sorted.size()
		# cap visible columns to avoid absurd width; ScrollContainer will scroll (stacked view)
		inspect_grid.columns = cols
		# Row 1: titles
		for card in pile_sorted:
			var cname: String = card.card_name if card is Card else str(card)
			var lbl := Label.new()
			lbl.text = cname
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 18)
			lbl.add_theme_color_override("font_color", Color(1, 1, 1))
			lbl.custom_minimum_size = Vector2(110, 22)
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			inspect_grid.add_child(lbl)
		# Row 2: art (with stack count badge)
		for card in pile_sorted:
			var cname2: String = card.card_name if card is Card else str(card)
			var art_center := CenterContainer.new()
			art_center.custom_minimum_size = Vector2(110, 56)
			art_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			# Wrapper for badge overlay
			var art_wrap := Control.new()
			art_wrap.custom_minimum_size = Vector2(56, 56)
			art_wrap.size = Vector2(56, 56)
			art_wrap.clip_contents = false
			var art := Card.create_sprite_for(cname2, Vector2(56, 56))
			art.clip_contents = true
			art.custom_minimum_size = Vector2(56, 56)
			art.size = Vector2(56, 56)
			art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			art_wrap.add_child(art)
			var _cnt: int = _pile_counts.get(cname2, 1) as int
			if _cnt > 1:
				var _badge := Control.new()
				_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_badge.custom_minimum_size = Vector2(28, 20)
				_badge.size = Vector2(28, 20)
				_badge.position = Vector2(36, 36)
				_badge.z_index = 10
				var _bg := PanelContainer.new()
				_bg.custom_minimum_size = Vector2(28, 20)
				_bg.size = Vector2(28, 20)
				var _sb2 := StyleBoxFlat.new()
				_sb2.bg_color = Color(0.92, 0.22, 0.22, 1)
				_sb2.set_corner_radius_all(10)
				_sb2.border_color = Color(1,1,1,0.9)
				_sb2.set_border_width_all(1)
				_bg.add_theme_stylebox_override("panel", _sb2)
				var _lbl2 := Label.new()
				_lbl2.text = "X%d" % _cnt
				_lbl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_lbl2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				_lbl2.add_theme_font_size_override("font_size", 12)
				_lbl2.add_theme_color_override("font_color", Color(1,1,1))
				_lbl2.add_theme_color_override("font_outline_color", Color(0,0,0,0.9))
				_lbl2.add_theme_constant_override("outline_size", 3)
				_bg.add_child(_lbl2)
				_badge.add_child(_bg)
				art_wrap.add_child(_badge)
			art_center.add_child(art_wrap)
			inspect_grid.add_child(art_center)
		# Row 3: stats
		for card in pile_sorted:
			var c3: Card = card as Card if card is Card else null
			var stats := Label.new()
			if c3 is Unit:
				stats.text = "HP:%d DMG:%d" % [(c3 as Unit).HitPoints, (c3 as Unit).Damage]
			elif c3 is Building:
				stats.text = "HP:%d INC:%d" % [(c3 as Building).HitPoints, (c3 as Building).Income]
			else:
				stats.text = ""
			stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stats.add_theme_font_size_override("font_size", 16)
			stats.add_theme_color_override("font_color", Color(0.9,0.9,1))
			stats.custom_minimum_size = Vector2(110, 18)
			stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			inspect_grid.add_child(stats)
		# Row 4: desc (SpecialEffect)
		for card in pile_sorted:
			var c4: Card = card as Card if card is Card else null
			var desc := RichTextLabel.new()
			desc.bbcode_enabled = true
			desc.fit_content = true
			desc.text = _effect_with_traits(c4 as Card) if c4 != null else ""
			desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.clip_contents = true
			desc.custom_minimum_size = Vector2(110, 32)
			desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			desc.add_theme_font_size_override("normal_font_size", 14)
			desc.add_theme_color_override("default_color", Color(0.8,0.8,1))
			inspect_grid.add_child(desc)
	# enlarge popup to fit grid and enable horizontal scroll - opaque and on top to hide field cards
	inspect_popup.z_index = 110
	inspect_popup.z_as_relative = false
	if inspect_popup.has_method("set_as_top_level"):
		inspect_popup.top_level = true
	# Opaque panel (alpha 1) so field cards don't show through
	var _ip_sb := StyleBoxFlat.new()
	_ip_sb.bg_color = Color(0.10, 0.10, 0.18, 1.0)
	_ip_sb.border_color = Color(0.92, 0.84, 0.38, 1.0)
	_ip_sb.set_border_width_all(2)
	_ip_sb.set_corner_radius_all(10)
	_ip_sb.content_margin_left = 12
	_ip_sb.content_margin_right = 12
	_ip_sb.content_margin_top = 10
	_ip_sb.content_margin_bottom = 10
	_ip_sb.shadow_color = Color(0,0,0,0.5)
	_ip_sb.shadow_size = 8
	inspect_popup.add_theme_stylebox_override("panel", _ip_sb)
	inspect_popup.custom_minimum_size = Vector2(760, 360)
	var vp: Vector2 = get_viewport_rect().size
	inspect_popup.size = Vector2(760, 360)
	inspect_popup.position = (vp - inspect_popup.size) / 2.0
	inspect_popup.visible = true
	inspect_popup.move_to_front()

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
