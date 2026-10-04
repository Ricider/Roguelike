# World Map campaign screen: the map is the battlefield.
# Each nation (you first, then every AI nation in order) collects income and
# draws, places cards from its hand on its own empty hexes, then every one of
# its units fires: units without Range hit the closest enemy card, units with
# Range hit a random card of the closest enemy nation (rules in MapWar).
# Destroyed cards cost HP; a nation at 0 HP cedes border hexes to its top
# damager and rebuilds. Conquer every claimed hex to win.
extends Control

const ICON_HP := "res://Assets/UI/heart.png"
const ICON_BIO := "res://Assets/UI/bio_icon.png"
const ICON_MONEY := "res://Assets/UI/money_icon.png"
const SPEEDS := [1.0, 2.0, 4.0]
const SHOT_GAP := 0.07 # seconds between shots at 1x
const TRAVEL := 0.28 # projectile flight time at 1x
const WALK_STEP := 0.08 # seconds per hex when units march to the front (visual only)
const WALK_MAX := 1.0 # longest march out (or back) at 1x; long routes step faster to fit
const RANGED_GAP := 3 # ranged units march no closer than this many hexes to their target
const START_HEX_PX := 18.0 # open zoomed in on your capital: same hex size on every map
const PAN_STEP := 60.0
const SHOT_SFX := {
	"Infantry": "shot_rifle", "Special Ops": "shot_rifle",
	"Tank": "shot_cannon", "Artilery": "shot_cannon", "Howitzer": "shot_cannon",
	"Rocket Launcher": "shot_rocket", "RocketLauncher": "shot_rocket",
	"Drone": "shot_laser", "Fighter Jet": "missile", "Interceptor": "missile",
	"Anti Aircraft": "shot_flak",
}

var _view: WorldMapView = null
var _minimap: Minimap = null
var _war: MapWar = null
var _banner: Label = null
var _status: Label = null
var _legend: VBoxContainer = null
var _player_flag: TextureRect = null
var _player_name: Label = null
var _gauges: Dictionary = {} # "hp"/"bio"/"money" -> {bar, value, income}
var _inf_label: Label = null
var _inf_box: Control = null
var _shop_btn: Button = null
var _shop_panel: PanelContainer = null
var _briefing: Control = null
signal briefing_closed
var _report_panel: PanelContainer = null
var _report: Dictionary = {}     # the last round's MapWar.round_stats
var _report_turn: int = 0
var _report_all: bool = false    # tab: all nations instead of your own fights
var _report_sort: String = ""     # column the table is sorted by ("" = yours first, by damage)
var _report_sort_desc: bool = true
var _sort_arrows: Array = []      # [up, down] pixel triangle icons for the sorted header
var _stat_tiles: Label = null
var _mods_box: HFlowContainer = null # your modifiers as animated badges (hover for the effect)
var _mods_sig: String = "" # rebuild the badges only when the list changes
var _hover_bar: Label = null
var _hand_box: HBoxContainer = null
var _end_btn: Button = null
var _speed_btn: Button = null
var _follow_cam: bool = true # the camera follows other nations' turns and fights
var _log: RichTextLabel = null
var _selected: Card = null
var _moving: String = "" # key of the unit picked to move ("" = none)
var _group: Array = [] # keys of the units picked for a bulk move (drag a box / Shift+click)
const DEPLOY_ZONE := Color(0.55, 1.0, 0.5) # where a selected unit card can be summoned (green, like the glowing hexes)
const MOVE_STEP := 0.12 # seconds per hex for a move's walk at 1x
var _busy: bool = false
var _speed_idx: int = 1 # 2x: a full round of 8 nations stays snappy
var _log_lines: Array = []
var _hover: CardHover = null # description cards + tooltips (see scripts/card_hover.gd)

func _ready() -> void:
	_sfx_music("map")
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.map_campaign == null or not gs.map_mode or gs.map_campaign.player_nation != gs.selected_player_name:
			gs.start_map_campaign(gs.selected_player_name)
		_war = gs.ensure_map_war()
	_build_ui()
	if _war != null:
		_view.set_war(_war)
		_log_line("[color=#ffd966]Turn %d.[/color] Place cards on your hexes, then End Turn." % _war.turn)
		if WorldMap.STORY_CHAPTER > 0:
			var sch: Dictionary = StoryText.chapter(WorldMap.STORY_CAMPAIGN, WorldMap.STORY_CHAPTER)
			_log_line("[color=#ffd966]Chapter %d: %s.[/color] %s" % [WorldMap.STORY_CHAPTER, sch["title"], sch["objective"]])
		_start_player_turn()
	_refresh()
	# camera needs the laid-out view size before it can centre
	await get_tree().process_frame
	_go_home()
	await _story_start_briefing()
	await _story_forces_briefing()

func _go_home() -> void:
	var c := _campaign()
	if c != null and c.is_alive(c.player_nation):
		_view.center_on(c.capital_site(c.player_nation), _view.zoom_for_hex_size(START_HEX_PX))

# ---------------------------------------------------------------- helpers
func _sfx(sfx_name: String, volume_db: float = 0.0) -> void:
	var sm = get_node_or_null("/root/SoundManager")
	if sm != null:
		sm.play(sfx_name, volume_db)

func _sfx_music(track: String) -> void:
	var sm = get_node_or_null("/root/SoundManager")
	if sm != null:
		sm.play_music(track)

func _campaign() -> MapCampaign:
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return null
	return gs.map_campaign as MapCampaign

func _me() -> String:
	var c := _campaign()
	return c.player_nation if c != null else ""

func _human() -> Player:
	return _war.players.get(_me()) if _war != null else null

func _speed() -> float:
	return SPEEDS[_speed_idx]

func _wait(sec: float) -> void:
	await get_tree().create_timer(sec / _speed()).timeout

func _nation_hex_color(nm: String) -> String:
	return Color.html(str(WorldMap.nation_by_name(nm).get("color", "ffffff"))).lightened(0.25).to_html(false)

func _log_line(bb: String) -> void:
	_log_lines.append(bb)
	while _log_lines.size() > 60:
		_log_lines.pop_front()
	if _log != null:
		_log.text = "\n".join(_log_lines)

func _flag_tex(nation: String) -> Texture2D:
	var path := "res://Assets/Players/%s/flag.png" % nation
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

func _icon(path: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path) as Texture2D
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"TitleLabel"
	l.add_theme_font_size_override("font_size", 16) # Press Start 2P is an 8px font: keep sizes on its grid
	l.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	return l

func _bar(fill_col: Color, w: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(w, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_col
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.04, 0.08)
	back.border_color = Color(0.37, 0.41, 0.5)
	back.set_border_width_all(1)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	return bar

# -------------------------------------------------------------------- UI
func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.name = "BG"
	bg.texture = load("res://Assets/UI/bg_tile.png") as Texture2D
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side_name in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side_name, 10)
	add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)
	# Left: map, hover readout, hand
	var map_col := VBoxContainer.new()
	map_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_col.add_theme_constant_override("separation", 6)
	hbox.add_child(map_col)
	_view = WorldMapView.new()
	_view.name = "MapView"
	_view.custom_minimum_size = Vector2(600, 400)
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.tile_selected.connect(_on_tile_selected)
	_view.tile_hovered.connect(_on_tile_hovered)
	_view.hover_cleared.connect(_clear_map_hover)
	_view.box_selected.connect(_on_box_selected)
	map_col.add_child(_view)
	# minimap in the map's bottom-left corner
	_minimap = Minimap.new()
	_minimap.name = "Minimap"
	_minimap.view = _view
	_minimap.anchor_top = 1.0
	_minimap.anchor_bottom = 1.0
	_view.add_child(_minimap)
	_hover = CardHover.new()
	_hover.name = "CardHover"
	add_child(_hover)
	# zoom controls floating in the map's top-right corner
	var zoom_bar := HBoxContainer.new()
	zoom_bar.name = "ZoomBar"
	zoom_bar.add_theme_constant_override("separation", 4)
	zoom_bar.anchor_left = 1.0
	zoom_bar.anchor_right = 1.0
	zoom_bar.offset_left = -300
	zoom_bar.offset_right = -10
	zoom_bar.offset_top = 10
	zoom_bar.offset_bottom = 54
	zoom_bar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR # the map view is NEAREST; keep button text smooth
	_view.add_child(zoom_bar)
	var follow := Button.new()
	follow.name = "FollowButton"
	follow.text = "Follow"
	follow.toggle_mode = true
	follow.button_pressed = _follow_cam
	follow.custom_minimum_size = Vector2(98, 44)
	follow.add_theme_font_size_override("font_size", 16)
	follow.focus_mode = Control.FOCUS_NONE
	follow.toggled.connect(func(on: bool): _follow_cam = on)
	_tip(follow, func(): return "[Follow]: during other nations' turns the camera flies to each of them and frames every fight, one defender at a time. Off: the camera stays where you leave it.")
	zoom_bar.add_child(follow)
	for spec in [["-", func(): _view.zoom_by(1.0 / 1.3)], ["+", func(): _view.zoom_by(1.3)], ["Home", _go_home]]:
		var zb := Button.new()
		zb.text = spec[0]
		zb.custom_minimum_size = Vector2(44 if spec[0].length() == 1 else 86, 44)
		zb.add_theme_font_size_override("font_size", 20 if spec[0].length() == 1 else 16)
		zb.focus_mode = Control.FOCUS_NONE
		zb.pressed.connect(spec[1])
		zoom_bar.add_child(zb)
	_hover_bar = Label.new()
	_hover_bar.name = "HoverBar"
	_hover_bar.text = "Pick a card below, then click a glowing hex. Click a unit to move it; drag a box (or Shift+click) to pick several. Scroll to zoom, right-drag to pan, H returns home."
	_hover_bar.add_theme_font_size_override("font_size", 16)
	_hover_bar.add_theme_color_override("font_color", Color(0.85, 0.86, 0.92))
	map_col.add_child(_hover_bar)
	var hand_panel := PanelContainer.new()
	hand_panel.custom_minimum_size = Vector2(0, 118)
	map_col.add_child(hand_panel)
	_hand_box = HBoxContainer.new()
	_hand_box.name = "Hand"
	_hand_box.add_theme_constant_override("separation", 6)
	hand_panel.add_child(_hand_box)
	# Right: command panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
	hbox.add_child(panel)
	var side := VBoxContainer.new()
	side.name = "Side"
	side.add_theme_constant_override("separation", 8)
	panel.add_child(side)
	var title := Label.new()
	title.text = ("CHAPTER %d" % WorldMap.STORY_CHAPTER) if WorldMap.STORY_CHAPTER > 0 else ("WORLD WAR" if WorldMap.MAP_ID == "world" else WorldMap.MAP_NAME.to_upper())
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86))
	side.add_child(title)
	# Player card: flag + name, then pixel gauges (HP / Bio / Money) and Influence + Shop
	var card := PanelContainer.new()
	card.theme_type_variation = &"GoldPanel"
	side.add_child(card)
	var card_v := VBoxContainer.new()
	card_v.add_theme_constant_override("separation", 6)
	card.add_child(card_v)
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 10)
	card_v.add_child(card_row)
	_player_flag = TextureRect.new()
	_player_flag.custom_minimum_size = Vector2(52, 52)
	_player_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_player_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_player_flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	card_row.add_child(_player_flag)
	var card_col := VBoxContainer.new()
	card_col.add_theme_constant_override("separation", 0)
	card_row.add_child(card_col)
	_player_name = Label.new()
	_player_name.add_theme_font_size_override("font_size", 22)
	_player_name.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	card_col.add_child(_player_name)
	_stat_tiles = Label.new()
	_stat_tiles.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	_stat_tiles.add_theme_font_size_override("font_size", 14)
	card_col.add_child(_stat_tiles)
	var gauge_row := HBoxContainer.new()
	gauge_row.add_theme_constant_override("separation", 4)
	card_v.add_child(gauge_row)
	gauge_row.add_child(_make_gauge("hp", "res://Assets/UI/hp_bg.png", "res://Assets/UI/hp_fill.png", ICON_HP))
	gauge_row.add_child(_make_gauge("bio", "res://Assets/UI/bio_bg.png", "res://Assets/UI/bio_fill.png", ICON_BIO))
	gauge_row.add_child(_make_gauge("money", "res://Assets/UI/money_bg.png", "res://Assets/UI/money_fill.png", ICON_MONEY))
	# Influence counter + Shop
	var inf_col := VBoxContainer.new()
	inf_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inf_col.alignment = BoxContainer.ALIGNMENT_CENTER
	inf_col.add_theme_constant_override("separation", 4)
	gauge_row.add_child(inf_col)
	var inf_title := Label.new()
	inf_title.text = "INFLUENCE"
	inf_title.add_theme_font_size_override("font_size", 17) # body font: the 8px title font can't fit this column crisply
	inf_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	inf_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inf_col.add_child(inf_title)
	var inf_row := HBoxContainer.new()
	inf_row.alignment = BoxContainer.ALIGNMENT_CENTER
	inf_row.add_theme_constant_override("separation", 4)
	inf_col.add_child(inf_row)
	inf_row.add_child(_icon("res://Assets/UI/influence_icon.png", 30))
	_inf_label = Label.new()
	_inf_label.name = "InfluenceCount"
	_inf_label.add_theme_font_size_override("font_size", 30)
	_inf_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	inf_row.add_child(_inf_label)
	_inf_box = inf_row
	_tip(inf_row, func(): return TIP_INFLUENCE % MapWar.INFLUENCE_PER_HEX)
	var inf_hint := Label.new()
	inf_hint.text = "+%d per hex won" % MapWar.INFLUENCE_PER_HEX
	inf_hint.add_theme_font_size_override("font_size", 13)
	inf_hint.add_theme_color_override("font_color", Color(0.75, 0.76, 0.85))
	inf_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inf_col.add_child(inf_hint)
	_shop_btn = Button.new()
	_shop_btn.name = "ShopButton"
	_shop_btn.text = "Shop"
	_shop_btn.theme_type_variation = &"SelectedButton"
	_shop_btn.custom_minimum_size = Vector2(0, 44)
	_shop_btn.add_theme_font_size_override("font_size", 18)
	_shop_btn.focus_mode = Control.FOCUS_NONE
	_shop_btn.pressed.connect(_open_shop)
	_tip(_shop_btn, func(): return TIP_SHOP)
	# Modifiers you own, like the old battle screen's modifier stack
	var mods_row := HBoxContainer.new()
	mods_row.add_theme_constant_override("separation", 8)
	card_v.add_child(mods_row)
	var mods_lbl := Label.new()
	mods_lbl.text = "Modifiers"
	mods_lbl.add_theme_font_size_override("font_size", 16)
	mods_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	mods_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mods_row.add_child(mods_lbl)
	_mods_box = HFlowContainer.new()
	_mods_box.name = "Modifiers"
	_mods_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mods_box.add_theme_constant_override("h_separation", 4)
	_mods_box.add_theme_constant_override("v_separation", 4)
	mods_row.add_child(_mods_box)
	inf_col.add_child(_shop_btn)
	_status = Label.new()
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 17)
	_status.add_theme_color_override("font_color", Color(1.0, 0.84, 0.2))
	side.add_child(_status)
	var turn_row := HBoxContainer.new()
	turn_row.add_theme_constant_override("separation", 8)
	side.add_child(turn_row)
	_end_btn = Button.new()
	_end_btn.name = "EndTurnButton"
	_end_btn.text = "End Turn"
	_end_btn.theme_type_variation = &"PrimaryButton"
	_end_btn.custom_minimum_size = Vector2(0, 52)
	_end_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_end_btn.add_theme_font_size_override("font_size", 22)
	_end_btn.focus_mode = Control.FOCUS_NONE
	_end_btn.pressed.connect(_on_end_turn)
	turn_row.add_child(_end_btn)
	_speed_btn = Button.new()
	_speed_btn.name = "SpeedButton"
	_speed_btn.text = "Speed 2x"
	_speed_btn.custom_minimum_size = Vector2(104, 52)
	_speed_btn.focus_mode = Control.FOCUS_NONE
	_speed_btn.pressed.connect(func():
		_speed_idx = (_speed_idx + 1) % SPEEDS.size()
		_speed_btn.text = "Speed %dx" % int(_speed()))
	turn_row.add_child(_speed_btn)
	_banner = Label.new()
	_banner.name = "Banner"
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_theme_font_size_override("font_size", 16)
	_banner.visible = false
	side.add_child(_banner)
	side.add_child(_section_label("NATIONS"))
	_legend = VBoxContainer.new()
	_legend.name = "Legend"
	_legend.add_theme_constant_override("separation", 2)
	side.add_child(_legend)
	var log_head := HBoxContainer.new()
	side.add_child(log_head)
	var log_title := _section_label("BATTLE LOG")
	log_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_head.add_child(log_title)
	var rep_btn := Button.new()
	rep_btn.name = "ReportButton"
	rep_btn.text = "Round report"
	rep_btn.custom_minimum_size = Vector2(0, 30)
	rep_btn.add_theme_font_size_override("font_size", 14)
	rep_btn.focus_mode = Control.FOCUS_NONE
	rep_btn.pressed.connect(_open_report)
	log_head.add_child(rep_btn)
	_log = RichTextLabel.new()
	_log.name = "Log"
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(0, 90)
	_log.add_theme_font_size_override("normal_font_size", 15)
	side.add_child(_log)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	side.add_child(row)
	for spec in [["NewCampaignButton", "New", _on_new_campaign_pressed], ["SaveButton", "Save", _on_save_pressed], ["BackButton", "Menu", _on_back_pressed]]:
		var b := Button.new()
		b.name = spec[0]
		b.text = spec[1]
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 16)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[2])
		row.add_child(b)
	var sm = get_node_or_null("/root/SoundManager")
	if sm != null:
		var snd: Button = sm.make_toggle_button()
		snd.custom_minimum_size = Vector2(0, 44)
		snd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		snd.add_theme_font_size_override("font_size", 15)
		row.add_child(snd)

func _refresh() -> void:
	var c := _campaign()
	if c == null:
		return
	_view.set_campaign(c)
	_minimap.refresh()
	_refresh_legend()
	_refresh_player_card()
	_refresh_hand()
	if c.has_won() and WorldMap.STORY_CHAPTER > 0:
		_show_banner("CHAPTER %d WON! The story continues..." % WorldMap.STORY_CHAPTER, Color(1.0, 0.86, 0.35))
	elif c.has_won():
		_show_banner("WORLD CONQUERED! %s rules all %d hexes." % [c.player_nation, c.tile_count(c.player_nation)], Color(1.0, 0.86, 0.35))
	elif c.has_lost() and WorldMap.STORY_CHAPTER > 0:
		_show_banner("THE STATE TROOPS HAVE FALLEN.", Color(1, 0.45, 0.4))
	elif c.has_lost():
		_show_banner("ELIMINATED! %s holds no territory. Start a New campaign." % c.player_nation, Color(1, 0.45, 0.4))

func _show_banner(text: String, col: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", col)
	_banner.visible = true
	_end_btn.disabled = true

# Animated badge per owned modifier; hover shows its name and effect.
func _refresh_modifiers(p: Player) -> void:
	var names: Array = []
	for m in p.Modifiers:
		names.append((m as Modifier).modifier_name if m is Modifier else str(m))
	var sig := ",".join(names)
	if sig == _mods_sig and _mods_box.get_child_count() > 0:
		return
	_mods_sig = sig
	for ch in _mods_box.get_children():
		ch.queue_free()
	if p.Modifiers.is_empty():
		var none := Label.new()
		none.text = "none yet (see Shop)"
		none.add_theme_font_size_override("font_size", 14)
		none.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
		_mods_box.add_child(none)
		return
	for m in p.Modifiers:
		if not (m is Modifier):
			continue
		var mod := m as Modifier
		var badge := Control.new()
		badge.custom_minimum_size = Vector2(40, 40)
		badge.add_child(Modifier.create_sprite_for(mod.modifier_name, Vector2(40, 40)))
		var tip_text := "[%s]: %s" % [mod.modifier_name, mod.Effect]
		_tip(badge, func(): return tip_text)
		_mods_box.add_child(badge)

# "Modifiers: A, B" for a nation's tooltip.
func _modifier_names(p: Player) -> String:
	var names: Array = []
	for m in p.Modifiers:
		names.append((m as Modifier).modifier_name if m is Modifier else str(m))
	return ", ".join(names) if not names.is_empty() else "none"

# Vertical pixel gauge like the battle screen: +income on top, bar, value, icon.
func _make_gauge(key: String, bg_path: String, fill_path: String, icon_path: String) -> Control:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.custom_minimum_size = Vector2(58, 0)
	var income := Label.new()
	income.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	income.add_theme_font_size_override("font_size", 14)
	income.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	col.add_child(income)
	var bar := TextureProgressBar.new()
	bar.name = key.capitalize() + "Gauge"
	bar.texture_under = load(bg_path) as Texture2D
	bar.texture_progress = load(fill_path) as Texture2D
	bar.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	bar.nine_patch_stretch = true
	bar.stretch_margin_left = 6
	bar.stretch_margin_right = 6
	bar.stretch_margin_top = 9
	bar.stretch_margin_bottom = 9
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar.custom_minimum_size = Vector2(30, 96)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE # let the gauge column get the hover
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(bar)
	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 15)
	col.add_child(value)
	var ic := _icon(icon_path, 20)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ic)
	_gauges[key] = {"bar": bar, "value": value, "income": income}
	match key:
		"hp": _tip(col, func(): return TIP_HP)
		"bio": _tip(col, func(): return TIP_BIO + _upkeep_tip("bio"))
		"money": _tip(col, func(): return TIP_MONEY + _upkeep_tip("money"))
	return col

# " Upkeep: -N per turn (5% of your units' total BioCost / MoneyCost)."
func _upkeep_tip(key: String) -> String:
	if _war == null:
		return ""
	var up: Dictionary = _war.upkeep(_me())
	var label := "BioCost" if key == "bio" else "MoneyCost"
	return "\n[Upkeep]: -%d per turn, %d%% of the total %s of your units on the map." % [int(up[key]), roundi(MapWar.UPKEEP_RATE * 100.0), label]

func _set_gauge(key: String, val: int, max_val: int, gain: int) -> void:
	var g: Dictionary = _gauges[key]
	var bar := g["bar"] as TextureProgressBar
	bar.max_value = maxi(max_val, 1)
	var tw := bar.create_tween()
	tw.tween_property(bar, "value", float(val), 0.35).set_trans(Tween.TRANS_SINE)
	(g["value"] as Label).text = "%d/%d" % [val, max_val] if key == "hp" else str(val)
	(g["income"] as Label).text = ("+%d" % gain) if gain > 0 else (str(gain) if gain < 0 else " ")
	(g["income"] as Label).add_theme_color_override("font_color", Color(0.55, 1.0, 0.55) if gain >= 0 else Color(1.0, 0.45, 0.4))
	if key == "hp":
		bar.tint_progress = Color(1, 0.6, 0.6) if val * 4 < max_val else Color.WHITE

# Influence gained: counter pulses and a "+N" floats up from it.
func _bump_influence(amount: int) -> void:
	if amount <= 0 or _inf_box == null:
		return
	_sfx("coin")
	var pop := Label.new()
	pop.text = "+%d" % amount
	pop.add_theme_font_size_override("font_size", 24)
	pop.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	pop.top_level = true
	pop.global_position = _inf_label.global_position + Vector2(_inf_label.size.x + 6, -4)
	add_child(pop)
	var tw := pop.create_tween().set_parallel(true)
	tw.tween_property(pop, "global_position:y", pop.global_position.y - 36, 1.1)
	tw.tween_property(pop, "modulate:a", 0.0, 1.1)
	tw.chain().tween_callback(pop.queue_free)
	_inf_label.pivot_offset = _inf_label.size * 0.5
	var tw2 := _inf_label.create_tween()
	tw2.tween_property(_inf_label, "scale", Vector2(1.35, 1.35), 0.12)
	tw2.tween_property(_inf_label, "scale", Vector2.ONE, 0.25)

func _refresh_player_card() -> void:
	var c := _campaign()
	var p := _human()
	_player_flag.texture = _flag_tex(c.player_nation)
	_player_name.text = c.player_nation
	if p != null:
		_set_gauge("hp", p.HitPoints, p.MaxHitPoints, p.predicted_hp_gain())
		# next turn's income minus the army's upkeep (MapWar.upkeep)
		var up: Dictionary = _war.upkeep(_me()) if _war != null else {"money": 0, "bio": 0}
		_set_gauge("bio", p.BioSupply, 200, p.predicted_bio_gain() - int(up["bio"]))
		_set_gauge("money", p.MoneySupply, 200, p.predicted_money_gain() - int(up["money"]))
		_inf_label.text = str(p.Influence)
	_shop_btn.disabled = _busy or c.has_won() or c.has_lost()
	if p != null:
		_refresh_modifiers(p)
	_stat_tiles.text = "%d hexes · %d cards on the map · turn %d" % [c.tile_count(c.player_nation), _war.cards_of(c.player_nation).size() if _war != null else 0, _war.turn if _war != null else 1]

func _refresh_legend() -> void:
	var c := _campaign()
	for child in _legend.get_children():
		child.queue_free()
	# most hexes first; nations that are out drop to the bottom (ties keep map order)
	var order: Array = WorldMap.nations().duplicate()
	var idx := {}
	for i in range(order.size()):
		idx[str(order[i]["name"])] = i
	var hexes := func(d: Dictionary) -> int:
		var nm := str(d["name"])
		return c.tile_count(nm) if c.is_alive(nm) else -1
	order.sort_custom(func(a, b):
		var ha: int = hexes.call(a)
		var hb: int = hexes.call(b)
		return ha > hb if ha != hb else idx[str(a["name"])] < idx[str(b["name"])])
	for n in order:
		_legend.add_child(_nation_row(c, n as Dictionary))

func _nation_row(c: MapCampaign, d: Dictionary) -> Control:
	var nm := str(d["name"])
	var alive := c.is_alive(nm)
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 30)
	btn.set_meta("no_ui_sfx", true)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.add_theme_constant_override("separation", 6)
	btn.add_child(row)
	row.add_child(_icon("res://Assets/Players/%s/flag.png" % nm, 28))
	var name_lbl := Label.new()
	name_lbl.text = nm
	name_lbl.custom_minimum_size = Vector2(118, 0)
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if nm == c.player_nation:
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	row.add_child(name_lbl)
	var p: Player = _war.players.get(nm) if _war != null else null
	var hp_bar := _bar(Color.html(str(d["color"])), 56)
	if p != null:
		hp_bar.max_value = maxi(p.MaxHitPoints, 1)
		hp_bar.value = p.HitPoints if alive else 0
		btn.tooltip_text = "%s · capital %s · HP %d/%d\nModifiers: %s" % [nm, str(d["capital"]), p.HitPoints, p.MaxHitPoints, _modifier_names(p)]
	row.add_child(hp_bar)
	var count := Label.new()
	count.text = ("%d hex" % c.tile_count(nm)) if alive else "out"
	if alive and _war != null and _war.loss_multiplier(nm) > 1:
		# few or no units: this nation loses land 2x / 4x as fast
		var mult := _war.loss_multiplier(nm)
		count.text = "%dx %s" % [mult, count.text]
		count.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if mult >= 4 else Color(1, 0.55, 0.4))
	if _war != null and alive:
		var why := ""
		match _war.loss_multiplier(nm):
			4: why = " (none: loses land 4x as fast)"
			2: why = " (under %d: loses land 2x as fast)" % MapWar.WEAK_UNIT_COUNT
		btn.tooltip_text += " · %d units on the map%s" % [_war.unit_count(nm), why]
	count.custom_minimum_size = Vector2(76, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_theme_font_size_override("font_size", 14)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(count)
	if not alive:
		btn.modulate = Color(1, 1, 1, 0.4)
	else:
		btn.pressed.connect(func(): _view.select_tile(c.capital_site(nm), false))
	return btn

# -------------------------------------------------------------- hover help
const TIP_HP := "[Health]: Your nation's hit points. You lose HP when one of your cards is destroyed (equal to the BioSupply spent on it) and when enemies hit your flag. At 0 HP you cede border hexes to whoever hurt you most, then rebuild."
const TIP_BIO := "[BioSupply]: The people you can call up, spent to deploy cards. Grows 10% + 5 each turn, +8 per Housing on the map. Max 200."
const TIP_MONEY := "[MoneySupply]: Your treasury, spent to deploy cards. +10 each turn plus the Income of your buildings on the map. Max 200."
const TIP_INFLUENCE := "[Influence]: Earned when your nation takes hexes (+%d per hex). Spend it in the [Shop] on cards and modifiers, or to remove a card from your deck."
const TIP_SHOP := "[Shop]: 5 cards drawn with your starting deck's odds plus 3 modifiers, restocked every turn. Bought cards are drawn next."

func _tip(node: Control, text_fn: Callable) -> void:
	# text_fn is called at hover time so numbers are always current
	node.mouse_filter = Control.MOUSE_FILTER_STOP if not (node is BaseButton) else node.mouse_filter
	node.mouse_entered.connect(func(): _hover.show_text(str(text_fn.call()), node.get_global_rect()))
	node.mouse_exited.connect(func(): _hover.hide_all())

# Stats for a card still in a hand or shop: effective values vs the base card.
func _hand_info(card: Card, p: Player, where: String) -> Dictionary:
	var d := {"owner": where, "hp": p.effective_hitpoints_for(card), "hp_base": p.base_hitpoints_for(card),
		"money": p.get_effective_money_cost(card), "money_base": card.MoneyCost, "nation": p.display_name}
	if card is Unit:
		d["dmg"] = p.effective_damage_for(card, null)
		d["dmg_base"] = (card as Unit).Damage
		d["ranged"] = p.has_range_for(card)
	var notes: Array = []
	var short := _war.shortfall(_me(), card) if (_war != null and p == _human()) else ""
	if short != "":
		notes.append("[color=#ff7a70]Need %s to deploy.[/color]" % short)
	d["notes"] = notes
	return d

# Stats for a card standing on the map, plus what it will do next.
func _unit_info(k: String) -> Dictionary:
	var info: Dictionary = _war.units[k]
	var owner := str(info["owner"])
	var card: Card = info["card"]
	var p: Player = _war.players[owner]
	var t := MapWar.key_to_hex(k)
	var hp: int = _war.card_hp(card)
	var d := {"owner": owner + ("  (you)" if owner == _me() else ""),
		"owner_color": Color.html(str(WorldMap.nation_by_name(owner).get("color", "ffffff"))),
		"hp": hp, "hp_max": int(card.get_meta("map_max_hp", hp)), "nation": owner}
	var notes: Array = []
	if card is Unit:
		var u := card as Unit
		d["dmg"] = _war.effective_damage(owner, u, t)
		d["dmg_base"] = u.Damage
		d["ranged"] = p.has_range_for(u)
		if _war._barracks_bonus(owner, t) > 0:
			notes.append("[color=#8fe08f]+2 damage from an adjacent Barracks.[/color]")
		var flank := _war.flank_bonus(k)
		if flank > 0:
			notes.append("[color=#ff8a7a]%s: takes +%d damage from every hit.[/color]" % [_war.flank_name(flank).capitalize(), flank])
		if _war._home_bonus(owner, t) > 0:
			notes.append("[color=#8fe08f]+1 damage: fighting on home ground.[/color]")
		else:
			notes.append("[color=#c8b89a]Away from home: no +1 home-ground damage.[/color]")
		if not u.Flying and WorldMap.terrain_at(t.x, t.y) == WorldMap.MOUNTAIN:
			notes.append("[color=#c8b89a]Mountain cover: takes 1 less damage.[/color]")
		var full_moves := _war.turn_allowance(k)
		if owner == _me():
			notes.append("[color=#9fd3ff]Moves: %d of %d left this turn. Click it to move.[/color]" % [_war.moves_left(k), full_moves])
		else:
			notes.append("[color=#9fd3ff]Moves up to %d hex%s a turn.[/color]" % [full_moves, "" if full_moves == 1 else "es"])
		if not u.Flying:
			if not _war.can_sail(owner, u):
				notes.append("[color=#c8b89a]Too slow to board a boat: it can't cross water.[/color]")
			elif not WorldMap.is_land(t.x, t.y):
				notes.append("[color=#ff8a7a]In a boat: %d hex slower a turn, %d hexes less range, takes +%d damage from every hit.[/color]" % [MapWar.SEA_PENALTY, MapWar.SEA_RANGE_PENALTY, MapWar.SEA_DAMAGE_PENALTY])
			else:
				notes.append("[color=#c8b89a]Boarding a boat costs 1 extra move; at sea it is %d hex slower, has %d hexes less range and takes +%d damage.[/color]" % [MapWar.SEA_PENALTY, MapWar.SEA_RANGE_PENALTY, MapWar.SEA_DAMAGE_PENALTY])
		if WorldMap.terrain_at(t.x, t.y) == WorldMap.JUNGLE:
			notes.append("[color=#8fcf7a]Forest cover: takes 1 less damage from flying attackers.[/color]")
		var aim := _war.predict_target(k)
		var reach := _war.attack_range(owner, u, t)
		if aim.is_empty():
			notes.append("[color=#ff9a7a]No target within its range of %d hexes: move it closer.[/color]" % reach)
		else:
			var col := _nation_hex_color(str(aim["owner"]))
			if bool(aim["ranged"]):
				notes.append("Next shot: a random target of [color=#%s]%s[/color] (closest nation, %d hexes)." % [col, aim["owner"], int(aim["distance"])])
			else:
				var tie := " (or another of %d equally close)" % int(aim["ties"]) if int(aim["ties"]) > 1 else ""
				notes.append("Next shot: [color=#%s]%s[/color]'s %s, %d hexes away%s." % [col, aim["owner"], str(aim["name"]).trim_prefix(str(aim["owner"]) + " "), int(aim["distance"]), tie])
			if card is RocketLauncher or card is Howitzer:
				notes.append("Fires 4 times each turn.")
		notes.append("[color=#9fd3ff]Attack range: %d hexes.[/color]" % reach)
	elif card is Building:
		d["income"] = (card as Building).Income
	d["notes"] = notes
	return d

func _clear_map_hover() -> void:
	_view.aim = {}
	# a bulk-move or move preview falls back to where the units stand now
	if _war != null and not _group.is_empty():
		_view.plan_marks = []
		_show_range(_group)
	elif _war != null and _moving != "" and _war.units.has(_moving):
		_show_range([_moving])
	if _hover != null:
		_hover.hide_all()

# ------------------------------------------------------------------- hand
func _refresh_hand() -> void:
	if _hover != null:
		_hover.hide_all()
	for child in _hand_box.get_children():
		child.queue_free()
	var p := _human()
	if p == null:
		return
	# stack identical cards, units first like the battle screen
	var groups: Dictionary = {}
	var order: Array = []
	for card in p.Hand:
		var cn := (card as Card).card_name
		if not groups.has(cn):
			groups[cn] = []
			order.append(cn)
		(groups[cn] as Array).append(card)
	order.sort_custom(func(a, b):
		var ua: int = 0 if (groups[a][0] is Unit) else 1
		var ub: int = 0 if (groups[b][0] is Unit) else 1
		return ua < ub if ua != ub else a < b)
	for cn in order:
		_hand_box.add_child(_hand_button(groups[cn] as Array))
	if p.Hand.is_empty():
		var l := Label.new()
		l.text = "  Hand empty. End Turn to draw back up to 10."
		_hand_box.add_child(l)

func _hand_button(stack: Array) -> Button:
	var card: Card = stack[0]
	var p := _human()
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 96)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_meta("no_ui_sfx", true)
	if _selected != null and stack.has(_selected):
		btn.theme_type_variation = &"SelectedButton"
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = 6
	row.offset_right = -6
	row.add_theme_constant_override("separation", 4)
	btn.add_child(row)
	var art := Card.create_sprite_for(card.card_name, Vector2(64, 64), _me())
	art.custom_minimum_size = Vector2(64, 64)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(art)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)
	var nm := Label.new()
	nm.text = card.card_name + ("  x%d" % stack.size() if stack.size() > 1 else "")
	nm.add_theme_font_size_override("font_size", 15)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	col.add_child(nm)
	var stat := Label.new()
	if card is Unit:
		stat.text = "HP %d  DMG %d%s" % [(card as Unit).HitPoints, (card as Unit).Damage, "  RNG" if p.has_range_for(card) else ""]
	elif card is Building:
		stat.text = "HP %d  INC %d" % [(card as Building).HitPoints, (card as Building).Income]
	stat.add_theme_font_size_override("font_size", 13)
	stat.add_theme_color_override("font_color", Color(0.82, 0.84, 0.9))
	col.add_child(stat)
	var cost := Label.new()
	cost.text = "$%d  Bio %d" % [p.get_effective_money_cost(card), card.BioCost]
	cost.add_theme_font_size_override("font_size", 13)
	var short := _war.shortfall(_me(), card)
	cost.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if short != "" else Color(1, 0.86, 0.4))
	col.add_child(cost)
	if short != "":
		btn.modulate = Color(1, 1, 1, 0.55)
	btn.pressed.connect(func(): _select_card(stack))
	btn.mouse_entered.connect(func(): _hover.show_card(card, _hand_info(card, p, "In your hand%s" % (" (x%d)" % stack.size() if stack.size() > 1 else "")), btn.get_global_rect()))
	btn.mouse_exited.connect(func(): _hover.hide_all())
	return btn

func _select_card(stack: Array) -> void:
	if _busy:
		return
	var card: Card = stack[0]
	if _selected != null and stack.has(_selected):
		_clear_selection()
		return
	var short := _war.shortfall(_me(), card)
	if short != "":
		_sfx("deny", -4.0)
		_hover_bar.text = "Can't afford %s: need %s" % [card.card_name, short]
		return
	_sfx("card_select", -3.0)
	_selected = card
	_moving = ""
	_group = []
	_view.clear_range()
	var keys: Dictionary = {}
	for t in _war.deploy_hexes(_me(), card):
		keys[MapCampaign.key_of((t as Vector2i).x, (t as Vector2i).y)] = true
	_view.placeable = keys
	_view.ghost_card = card.card_name
	_hover_bar.text = "Deploy %s: click a glowing hex (Esc to cancel)." % card.card_name
	if card is Unit:
		# units are summoned near what raises them: show that area and its sources
		var zone := {}
		var sources: Array = _war.deploy_sources(_me(), card)
		for src in sources:
			for h in _war.hexes_within(src as Vector2i, MapWar.DEPLOY_RADIUS):
				if _campaign().owner_of((h as Vector2i).x, (h as Vector2i).y) == _me():
					zone[h] = true
		_view.range_zones = [{"hexes": zone, "color": DEPLOY_ZONE}]
		_view.group_marks = sources
		_hover_bar.text = "Deploy %s within %d hexes of %s: click a glowing hex (Esc to cancel)." % [card.card_name, MapWar.DEPLOY_RADIUS, MapWar.deploy_anchor_text(card)]
		if keys.is_empty():
			_hover_bar.text = "No free hex within %d hexes of %s for %s." % [MapWar.DEPLOY_RADIUS, MapWar.deploy_anchor_text(card), card.card_name]
	_refresh_hand()

func _clear_selection() -> void:
	_selected = null
	_moving = ""
	_group = []
	_view.clear_range()
	_view.placeable = {}
	_view.ghost_card = ""
	_refresh_hand()

# ---------------------------------------------------------------- moving units
# Click one of your units to see where it can go this turn (glowing hexes), then a
# glowing hex to walk it there. Moves left carry over within the turn.
func _pick_mover(k: String) -> void:
	_selected = null
	_view.ghost_card = ""
	_group = []
	_view.plan_marks = []
	_view.group_marks = [MapWar.key_to_hex(k)]
	_show_range([k]) # where it can shoot from here (hovering a glowing hex previews from there)
	var card: Card = _war.units[k]["card"]
	var left := _war.moves_left(k)
	var full := _war.turn_allowance(k)
	if left <= 0:
		_moving = ""
		_view.placeable = {}
		_sfx("deny", -6.0)
		if _deployed_this_turn(card):
			_hover_bar.text = "%s was deployed this turn: it can move from next turn." % card.card_name
		else:
			_hover_bar.text = "%s has no moves left this turn (%d per turn)." % [card.card_name, full]
		_refresh_hand()
		return
	var reach := _war.reachable(k)
	var keys := {}
	for t in reach.keys():
		keys[MapCampaign.key_of((t as Vector2i).x, (t as Vector2i).y)] = true
	_moving = k
	_view.placeable = keys
	_sfx("card_select", -3.0)
	if keys.is_empty():
		_hover_bar.text = "%s has nowhere to go: every hex within %d is taken or blocked." % [card.card_name, left]
	else:
		_hover_bar.text = "Move %s: click a glowing hex (%d of %d move%s left this turn; Esc to cancel)." % [card.card_name, left, full, "" if full == 1 else "s"]
	_refresh_hand()

func _deployed_this_turn(card: Card) -> bool:
	return card.has_meta("deployed_turn") and int(card.get_meta("deployed_turn")) == _war.turn

func _move_unit_to(t: Vector2i) -> void:
	var k := _moving
	var card: Card = _war.units[k]["card"]
	var path := _war.move(_me(), k, t)
	if path.is_empty():
		_sfx("deny", -4.0)
		return
	_view.animate_move(path, MOVE_STEP)
	_sfx("card_place", -6.0)
	_log_line("You move %s %d hex%s." % [card.card_name, path.size() - 1, "" if path.size() == 2 else "es"])
	var nk := MapCampaign.key_of(t.x, t.y)
	_moving = ""
	_view.placeable = {}
	if _war.moves_left(nk) > 0:
		_pick_mover(nk) # still has moves: keep it picked
	else:
		_view.clear_range()
		_hover_bar.text = "Moved %s. Pick another unit or card, or End Turn." % card.card_name
		_refresh_hand()

# ------------------------------------------------------------ bulk moves
# Drag a box round your units (Shift+drag adds to the pick) or Shift+click them to pick several, then click
# any hex: each marches towards it as far as its moves allow, the nearest taking the
# closest spots (MapWar.move_group). Hovering a hex previews where each would end up
# and the group's attack range from there. Esc drops the selection.
func _toggle_group(k: String) -> void:
	var keys: Array = _group.duplicate()
	if _moving != "" and not keys.has(_moving):
		keys.append(_moving)
	if keys.has(k):
		keys.erase(k)
	else:
		keys.append(k)
	_set_group(keys)

func _on_box_selected(rect: Rect2, additive: bool) -> void:
	if _war == null or _busy:
		return
	var found: Array = _view.units_in_rect(rect, _me())
	if found.is_empty():
		_hover_bar.text = "No units of yours in that box (drag with the right mouse button to move the map)."
		return
	var keys: Array = []
	if additive: # Shift+drag adds to what is picked; a plain drag starts afresh
		keys = _group.duplicate()
		if _moving != "" and not keys.has(_moving):
			keys.append(_moving)
	for k in found:
		if not keys.has(k):
			keys.append(k)
	_set_group(keys)

func _set_group(keys: Array) -> void:
	var mine: Array = keys.filter(func(k): return _war.units.has(k) and str(_war.units[k]["owner"]) == _me() and _war.units[k]["card"] is Unit)
	if mine.is_empty():
		_clear_selection()
		return
	if mine.size() == 1:
		_pick_mover(str(mine[0]))
		return
	_selected = null
	_view.ghost_card = ""
	_moving = ""
	_group = mine
	var keys2 := {}
	var ready := 0
	var marks: Array = []
	for k in _group:
		marks.append(MapWar.key_to_hex(k))
		if _war.moves_left(k) > 0:
			ready += 1
		for t in _war.reachable(k).keys():
			keys2[MapCampaign.key_of((t as Vector2i).x, (t as Vector2i).y)] = true
	_view.placeable = keys2
	_view.group_marks = marks
	_view.plan_marks = []
	_show_range(_group)
	_sfx("card_select", -3.0)
	_hover_bar.text = "%d units picked (%d can still move): click any hex to march them towards it. Shift+click adds or drops one, Shift+drag adds more; Esc cancels." % [_group.size(), ready]
	_refresh_hand()

func _preview_group(goal: Vector2i) -> void:
	var plan: Array = _war.plan_group(_me(), _group, goal)
	var at := {}
	var marks: Array = []
	for mv in plan:
		at[str(mv[0])] = mv[1]
		marks.append([MapWar.key_to_hex(str(mv[0])), mv[1]])
	_view.plan_marks = marks
	_show_range(_group, at)
	_hover_bar.text = "March %d of %d units towards here (Esc cancels)." % [plan.size(), _group.size()] if not plan.is_empty() \
		else "None of the %d units can get any closer to here this turn." % _group.size()

func _move_group_to(goal: Vector2i) -> void:
	var moves: Array = _war.move_group(_me(), _group, goal)
	if moves.is_empty():
		_sfx("deny", -4.0)
		_hover_bar.text = "None of them can get any closer to there this turn."
		return
	var moved := {}
	for mv in moves:
		_view.animate_move(mv[2], MOVE_STEP)
		var to: Vector2i = mv[1]
		moved[str(mv[0])] = MapCampaign.key_of(to.x, to.y)
	_sfx("card_place", -6.0)
	_log_line("You move %d unit%s." % [moves.size(), "" if moves.size() == 1 else "s"])
	var keys: Array = []
	for k in _group:
		keys.append(moved.get(k, k))
	_set_group(keys) # stays picked: march on, or Esc
	_hover_bar.text = "Moved %d of %d units. Click another hex to march on, or Esc." % [moves.size(), keys.size()]

# ------------------------------------------------------------ attack range display
# Show where the units on `keys` can shoot, standing where `at` puts them (key -> hex;
# missing = where they are now): one zone for the melee units (4 hexes) and one for
# the ranged (8), plus a bracket on every enemy card or flag inside.
func _show_range(keys: Array, at: Dictionary = {}) -> void:
	var zones := {false: {}, true: {}}
	var targets := {}
	for k in keys:
		if not _war.units.has(k) or not (_war.units[k]["card"] is Unit):
			continue
		var u := _war.units[k]["card"] as Unit
		var from: Vector2i = at.get(k, MapWar.key_to_hex(k))
		var r := _war.attack_range(_me(), u, from) # shorter from a boat
		var ranged: bool = (_war.players[_me()] as Player).has_range_for(u)
		for h in _war.hexes_within(from, r):
			zones[ranged][h] = true
		for t in _war.targets_in_range(_me(), from, r):
			targets[t] = true
	var out: Array = []
	for ranged in [false, true]:
		if not (zones[ranged] as Dictionary).is_empty():
			out.append({"hexes": zones[ranged], "ranged": ranged})
	_view.range_zones = out
	_view.range_targets = targets.keys()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var kc := (event as InputEventKey).keycode
		if kc == KEY_ESCAPE and _report_panel != null:
			_close_report()
			get_viewport().set_input_as_handled()
		elif kc == KEY_ESCAPE and _shop_panel != null:
			_close_shop()
			get_viewport().set_input_as_handled()
		elif kc == KEY_ESCAPE and (_selected != null or _moving != "" or not _group.is_empty() or not _view.range_zones.is_empty()):
			_clear_selection()
			get_viewport().set_input_as_handled()
		elif (kc == KEY_SPACE or kc == KEY_ENTER) and not _busy and not _end_btn.disabled:
			_on_end_turn()
			get_viewport().set_input_as_handled()
		else:
			var pan := Vector2.ZERO
			match kc:
				KEY_LEFT, KEY_A: pan = Vector2(PAN_STEP, 0)
				KEY_RIGHT, KEY_D: pan = Vector2(-PAN_STEP, 0)
				KEY_UP, KEY_W: pan = Vector2(0, PAN_STEP)
				KEY_DOWN, KEY_S: pan = Vector2(0, -PAN_STEP)
				KEY_EQUAL, KEY_PLUS, KEY_KP_ADD: _view.zoom_by(1.2)
				KEY_MINUS, KEY_KP_SUBTRACT: _view.zoom_by(1.0 / 1.2)
				KEY_H: _go_home()
				_: return
			if pan != Vector2.ZERO:
				_view.pan_by(pan)
			get_viewport().set_input_as_handled()

# -------------------------------------------------------------- map input
func _describe(x: int, y: int) -> String:
	var c := _campaign()
	var o := c.owner_of(x, y)
	var text := "(%d, %d) %s" % [x, y, WorldMap.terrain_at(x, y).capitalize()]
	text += " · " + (o if o != "" else ("out of this war" if WorldMap.is_void(x, y) else ("wilderness" if WorldMap.is_land(x, y) else "open sea")))
	if _war != null:
		var holder := c.capital_holder_at(x, y)
		if holder != "":
			var hp_p: Player = _war.players[holder]
			text += " · %s's flag  HP %d/%d (a target: hits here cost %s HP)" % [holder, hp_p.HitPoints, hp_p.MaxHitPoints, holder]
		var info := _war.unit_at(Vector2i(x, y))
		if not info.is_empty():
			var card: Card = info["card"]
			var owner := str(info["owner"])
			text += " · %s's %s  HP %d" % [owner, card.card_name, _war.card_hp(card)]
			if card is Unit and not (card as Unit).Flying and WorldMap.terrain_at(x, y) == WorldMap.MOUNTAIN:
				text += " · mountain cover: takes 1 less damage"
			if card is Unit and WorldMap.terrain_at(x, y) == WorldMap.JUNGLE:
				text += " · forest cover: takes 1 less damage from flying attackers"
			if card is Unit:
				var u := card as Unit
				var ranged: bool = (_war.players[owner] as Player).has_range_for(u)
				text += "  DMG %d · %s" % [_war.effective_damage(owner, u, Vector2i(x, y)), "ranged: random card of the closest nation" if ranged else "hits the closest enemy"]
	return text

func _on_tile_hovered(x: int, y: int) -> void:
	if _campaign() == null or _war == null:
		return
	_show_map_hover(x, y)
	if not _busy and not _group.is_empty():
		_preview_group(Vector2i(x, y))
		return
	if not _busy and _moving != "" and _war.units.has(_moving):
		# preview its range from the hovered hex if it can go there, else from where it is
		var hk := MapCampaign.key_of(x, y)
		_show_range([_moving], {_moving: Vector2i(x, y)} if _view.placeable.has(hk) else {})
	if _selected != null:
		var why := _war.can_place(_me(), _selected, Vector2i(x, y))
		_hover_bar.text = ("Deploy %s here" % _selected.card_name) if why == "" else why
		if why == "" and _selected is Unit and not (_selected as Unit).Flying and WorldMap.terrain_at(x, y) == WorldMap.MOUNTAIN:
			_hover_bar.text += " (mountain: takes 1 less damage)"
		elif why == "" and _selected is Unit and WorldMap.terrain_at(x, y) == WorldMap.JUNGLE:
			_hover_bar.text += " (forest: takes 1 less damage from flying attackers)"
		return
	_hover_bar.text = _describe(x, y)

func _show_map_hover(x: int, y: int) -> void:
	_view.aim = {}
	var k := MapCampaign.key_of(x, y)
	var t := Vector2i(x, y)
	if _war.units.has(k):
		var card: Card = _war.units[k]["card"]
		var aim := _war.predict_target(k)
		var below := false
		if not aim.is_empty():
			_view.aim = {"from": t, "to": aim["hex"], "ranged": aim["ranged"]}
			# open the card on the side away from the target so the arrow stays visible
			below = _view.hex_global_rect(aim["hex"]).get_center().y < _view.hex_global_rect(t).get_center().y
		_hover.show_card(card, _unit_info(k), _view.hex_global_rect(t), below)
		return
	var holder := _campaign().capital_holder_at(x, y)
	if holder != "":
		var hp_p: Player = _war.players[holder]
		var mods: Array = []
		for m in hp_p.Modifiers:
			var mod_name: String = (m as Modifier).modifier_name if m is Modifier else str(m)
			var eff: String = (m as Modifier).Effect if m is Modifier else ""
			mods.append("[%s]%s" % [mod_name, (": " + eff) if eff != "" else ""])
		var mods_text := "\nModifiers: none" if mods.is_empty() else "\nModifiers:\n" + "\n".join(mods)
		_hover.show_text("[%s flag]: %s. HP %d/%d. Any hit on this flag comes straight off %s's HP. When the hex falls, the flag moves to the heart of its remaining land.%s" % [holder, str(WorldMap.nation_by_name(holder).get("capital", "")), hp_p.HitPoints, hp_p.MaxHitPoints, holder, mods_text], _view.hex_global_rect(t))
		return
	_hover.hide_all()

func _on_tile_selected(x: int, y: int) -> void:
	if _war == null or _busy:
		return
	if _selected == null:
		var t0 := Vector2i(x, y)
		var k0 := MapCampaign.key_of(x, y)
		var info0 := _war.unit_at(t0)
		var mine: bool = not info0.is_empty() and str(info0["owner"]) == _me() and info0["card"] is Unit
		if mine and (_view.click_shift or Input.is_key_pressed(KEY_SHIFT)):
			_toggle_group(k0)
			return
		if not _group.is_empty():
			if mine and not _group.has(k0):
				_pick_mover(k0) # a plain click on another unit picks just that one
			else:
				_move_group_to(t0)
			return
		if _moving != "" and _view.placeable.has(k0):
			_move_unit_to(t0)
			return
		var info := _war.unit_at(t0)
		if not info.is_empty() and str(info["owner"]) == _me() and info["card"] is Unit and k0 != _moving:
			_pick_mover(k0)
			return
		_clear_selection()
		_sfx("map_select")
		_hover_bar.text = _describe(x, y)
		return
	var t := Vector2i(x, y)
	var why := _war.can_place(_me(), _selected, t)
	if why != "":
		_sfx("deny", -4.0)
		_hover_bar.text = why
		return
	var placed := _selected
	_war.place(_me(), placed, t)
	_sfx("card_place")
	_view.add_place(t)
	_log_line("You deploy %s." % placed.card_name)
	_selected = null
	_view.placeable = {}
	_view.ghost_card = ""
	_view.clear_range()
	# keep deploying the same card type while copies remain and are affordable
	var next: Card = null
	for c in _human().Hand:
		if (c as Card).card_name == placed.card_name:
			next = c
			break
	if next != null and _war.shortfall(_me(), next) == "":
		_select_card([next])
	else:
		_hover_bar.text = "Deployed %s. Pick another card or End Turn." % placed.card_name
		_refresh_hand()
	_refresh_player_card()

# ------------------------------------------------------------------- turns
func _start_player_turn(round_over: bool = false) -> void:
	if round_over:
		# the round that just ended (your attack + every AI turn): keep it for the report
		_report = _war.round_stats.duplicate(true)
		_report_turn = _war.turn - 1
	_war.reset_round_stats()
	_war.begin_turn(_me())
	var up: Dictionary = _war.last_upkeep
	if int(up.get("money", 0)) > 0 or int(up.get("bio", 0)) > 0:
		_log_line("[color=#ff9a7a]Upkeep:[/color] your army costs %d Money and %d Bio this turn." % [int(up["money"]), int(up["bio"])])
	_announce_arrivals(_me())
	_busy = false
	_end_btn.disabled = _campaign().has_won() or _campaign().has_lost()
	_status.text = "Your turn. Deploy cards, then End Turn (Space)."
	_refresh_player_card()
	_refresh_hand()

func _on_end_turn() -> void:
	if _busy or _war == null:
		return
	_busy = true
	_end_btn.disabled = true
	_shop_btn.disabled = true
	_close_shop()
	_close_report()
	_clear_selection()
	await _story_combat_briefing()
	_sfx("end_turn", -2.0)
	_status.text = "Your units open fire..."
	var my_cam: Array = _view.camera_goal() # handed back when your turn comes round
	await _nation_attacks(_me())
	_war.end_turn(_me())
	if _check_end():
		return
	for n in _war.turn_order():
		if n == _me() or not _war.alive(n):
			continue
		_status.text = "%s is moving..." % n
		if _follow_cam:
			# fly over the nation whose turn it is, framing its whole territory
			await _view.glide_to(_view.frame_for(_campaign().tiles_of(n), 0.5), CAM_GLIDE / _speed())
		_war.begin_turn(n)
		if _announce_arrivals(n):
			await _wait(0.35)
		var bought: Array = _war.ai_shop(n)
		if not bought.is_empty():
			_log_line("[color=#%s]%s[/color] shops: %s." % [_nation_hex_color(n), n, ", ".join(bought)])
			_show_modifier_changes(_war.last_modifier_changes if _war.last_modifier_changes_nation == n else [])
		var placed: Array = _war.ai_build(n)
		for pl in placed:
			_view.add_place(pl[1] as Vector2i)
		if not placed.is_empty():
			_sfx("card_place", -6.0)
			_log_line("[color=#%s]%s[/color] deploys %d card%s." % [_nation_hex_color(n), n, placed.size(), "" if placed.size() == 1 else "s"])
			await _wait(0.35)
		# then repositions: behind walls, beside Barracks/Interceptors, onto weakened enemies
		var moved: Array = _war.ai_move(n)
		if not moved.is_empty():
			var longest := 0
			for mv in moved:
				_view.animate_move(mv[2], MOVE_STEP / _speed())
				longest = maxi(longest, (mv[2] as Array).size() - 1)
			_log_line("[color=#%s]%s[/color] moves %d unit%s." % [_nation_hex_color(n), n, moved.size(), "" if moved.size() == 1 else "s"])
			await _wait(MOVE_STEP * longest + 0.1)
		await _nation_attacks(n)
		_war.end_turn(n)
		if _check_end():
			return
	_war.turn += 1
	_log_line("[color=#ffd966]Turn %d.[/color]" % _war.turn)
	if _follow_cam:
		_view.glide_to(my_cam, CAM_GLIDE / _speed())
	_start_player_turn(true)
	_refresh()
	if not _report.is_empty() and not _campaign().has_won() and not _campaign().has_lost():
		_open_report()

func _nation_attacks(n: String) -> void:
	# 1. Resolve the whole attack in the war logic first, so every unit's real
	#    targets are known, random picks and retargets after earlier kills included.
	#    The view then replays it from the pre-attack state (begin_replay).
	var snapshot := {}
	for k in _war.units.keys():
		var card: Card = _war.units[k]["card"]
		var hp: int = _war.card_hp(card)
		snapshot[k] = {"name": card.card_name, "owner": str(_war.units[k]["owner"]), "hp": hp,
			"max": int(card.get_meta("map_max_hp", maxi(hp, 1))), "bio": card.BioCost}
	var flag_hp := {}
	var flag_sites := {}
	for nm in _war.players.keys():
		flag_hp[nm] = (_war.players[nm] as Player).HitPoints
		if _campaign().is_alive(str(nm)):
			flag_sites[nm] = _campaign().capital_site(str(nm))
	var plan: Array = [] # [[attacker key, entries], ...] in firing order
	var dead: Array = []
	for k in _war.attackers_of(n):
		var entries: Array = _war.fire(k)
		plan.append([k, entries])
		for e in entries:
			for d in e["destroyed"]:
				dead.append(str(d["key"]))
			for ev in e.get("collapses", []):
				for lk in ev.get("lost", []):
					dead.append(str(lk)) # stands until the collapse plays out on screen
	_view.begin_replay(snapshot, dead, flag_hp, flag_sites)
	# 2. Play it back one defender at a time, with the camera centred on each fight
	#    (yours included; with Follow off the camera stays put).
	var groups: Array = _split_by_victim(plan)
	var follow := _follow_cam
	for group in groups:
		if follow:
			await _frame_fight(group, flag_sites)
		await _replay_group(n, group, snapshot, dead, flag_sites)
	_view.end_replay() # back to the real state (splash and interceptor wear included)
	_refresh_legend()
	_refresh_player_card()
	_resolve_collapses()

# Where a unit marches for its shots: its target, or for a multi-shot unit (Rocket
# Launcher, Howitzer) the target hex closest in total to all the others it hits.
func _march_goal(entries: Array) -> Vector2i:
	var best: Vector2i = entries[0]["to"]
	var best_sum := 1 << 30
	for a in entries:
		var sum := 0
		for b in entries:
			sum += MapCampaign.hex_distance(a["to"], b["to"])
		if sum < best_sum:
			best_sum = sum
			best = a["to"]
	return best

# A replayed shot reaches its target: lower the shown HP (a flag hit, or a card;
# a destroyed card also costs its owner its BioCost on the flag bar).
func _land_hit(e: Dictionary, snapshot: Dictionary, impact: String) -> void:
	_sfx(impact, -5.0)
	if not is_instance_valid(_view):
		return
	var to: Vector2i = e["to"]
	if bool(e["direct"]):
		_view.replay_hit(to, int(e["damage"]), str(e["victim"]))
	else:
		_view.replay_hit(to, int(e["damage"]))
	for d in e["destroyed"]:
		var dk := str(d["key"])
		if snapshot.has(dk):
			_view.replay_hit(to, int(snapshot[dk]["bio"]), str(d["owner"]))
	# a nation fell on this shot: its flag re-forms elsewhere at full HP and its
	# border moves now (the log lines and Influence follow after the attack)
	var collapses: Array = e.get("collapses", [])
	if not collapses.is_empty():
		for ev in collapses:
			_view.replay_collapse(ev)
		_view.set_campaign(_campaign())
		_minimap.refresh()
		_refresh_legend()

# One fight of an attack (all of it, or one defender's share): split into waves at
# collapses, march, fire, wait for the shots, then walk everyone home.
func _replay_group(n: String, plan: Array, snapshot: Dictionary, dead: Array, flag_sites: Dictionary) -> void:
	# 2. Split the attack into waves at every collapse: when a shot brings a nation
	#    down, its flag re-forms elsewhere, so the units firing after that must only
	#    set off once the flag has visibly moved. Each wave's units march together,
	#    hex by hex, towards their real target (the most central one when they fire
	#    at several; visual only: the cards stay on their hexes), fire, and wait for
	#    their last shot to land before the next wave picks its spots. Ground units
	#    cross sea in boats; ranged units keep RANGED_GAP hexes from the target.
	var waves: Array = [[]]
	for item in plan:
		(waves[waves.size() - 1] as Array).append(item)
		for e in (item[1] as Array):
			if not (e.get("collapses", []) as Array).is_empty():
				waves.append([])
				break
	var shots := 0
	var walkers: Array = []
	var taken := {}
	for dk in dead:
		taken[MapWar.key_to_hex(dk)] = true # a doomed card still stands there on screen
	for nm in flag_sites.keys():
		taken[flag_sites[nm]] = true # a flag as shown now (it may move later this attack)
	var march := 0.0 # seconds at 1x for the slowest march (for the walk home)
	var shooter: Player = _war.players[n]
	for wave in waves:
		if (wave as Array).is_empty():
			continue
		var wave_march := 0.0
		for item in wave:
			var k: String = item[0]
			var entries: Array = item[1]
			if entries.is_empty() or not _war.units.has(k):
				continue
			var ranged: bool = shooter.has_range_for(_war.units[k]["card"])
			var goal := _march_goal(entries)
			var path := _walk_path(k, goal, taken, RANGED_GAP if ranged else 1)
			if path.size() < 2:
				continue
			taken[path[path.size() - 1]] = true
			var step: float = minf(WALK_STEP, WALK_MAX / float(path.size() - 1))
			_view.walk_out(k, path, step / _speed())
			walkers.append(k)
			wave_march = maxf(wave_march, step * float(path.size() - 1))
		march = maxf(march, wave_march)
		if wave_march > 0.0:
			await _wait(wave_march + 0.05)
		# 3. Replay this wave's shots in firing order; HP bars, wrecks and fallen
		#    flags update as each one lands.
		var wave_shots := 0
		for item in wave:
			for e in (item[1] as Array):
				shots += 1
				wave_shots += 1
				var kind: String = SHOT_SFX.get(str(e["card"]), "shot_rifle")
				var travel: float = TRAVEL / _speed()
				var destroyed: Array = e["destroyed"]
				_view.add_shot(e["from"], e["to"], kind, travel)
				_sfx(kind, -6.0)
				if bool(e.get("buffed", false)):
					_view.add_buff(e["from"]) # Barracks +2: golden burst at the shooter
				if bool(e.get("intercepted", false)):
					_view.add_intercept(e.get("intercept_from", Vector2i(-1, -1)), e["to"], travel)
					_log_line("[color=#7fd8ff]%s's Interceptor halves a hit on its %s.[/color]" % [e["victim"], e["target_name"]])
				for dinfo in destroyed:
					_view.replay_remove(str(dinfo["key"])) # the wreck effect takes over until impact
					_view.add_wreck(dinfo["hex"], str(dinfo["name"]), str(dinfo["owner"]), travel)
					_view.add_boom(dinfo["hex"], true, travel)
				for sp in e["splash"]:
					_view.add_boom(sp as Vector2i, false, travel)
				_view.add_boom(e["to"], false, travel)
				_view.add_number(e["to"], "-%d" % int(e["damage"]), Color(1, 0.8, 0.3) if e["direct"] else Color(1, 0.45, 0.4), travel)
				var impact: String = "hq_hit" if e["direct"] else ("explosion" if not destroyed.is_empty() else ("intercept" if e["intercepted"] else "hit"))
				get_tree().create_timer(travel).timeout.connect(_land_hit.bind(e, snapshot, impact))
				if e["direct"]:
					_log_line("[color=#%s]%s[/color] %s hits [color=#%s]%s[/color]'s flag for %d" % [_nation_hex_color(n), n, e["card"], _nation_hex_color(str(e["victim"])), e["victim"], int(e["damage"])])
				elif not destroyed.is_empty():
					_log_line("[color=#%s]%s[/color] %s destroys [color=#%s]%s[/color]'s %s" % [_nation_hex_color(n), n, e["card"], _nation_hex_color(str(e["victim"])), e["victim"], e["target_name"]])
				await _wait(SHOT_GAP)
		if wave_shots > 0:
			await _wait(TRAVEL + 0.15) # the last shot lands (and any collapse plays out)
		for nm in flag_sites.keys():
			if _view.flag_site_shown.get(nm, flag_sites[nm]) != flag_sites[nm]:
				taken.erase(flag_sites[nm])          # a flag that moved frees its old hex...
				flag_sites[nm] = _view.flag_site_shown[nm]
				taken[flag_sites[nm]] = true          # ...and holds its new one
	if march > 0.0:
		for k in walkers:
			_view.walk_back(k)
		await _wait(march + 0.05)
		_view.clear_walks()

# [[k, entries], ...] split into one plan per defender, in the order they are first
# hit; a unit firing at two nations appears in both with its shots for each.
func _split_by_victim(plan: Array) -> Array:
	var order: Array = []
	var by_victim := {}
	for item in plan:
		var per := {}
		for e in (item[1] as Array):
			var v := str(e["victim"])
			if not per.has(v):
				per[v] = []
			(per[v] as Array).append(e)
		for v in per.keys():
			if not by_victim.has(v):
				by_victim[v] = []
				order.append(v)
			(by_victim[v] as Array).append([item[0], per[v]])
	var out: Array = []
	for v in order:
		out.append(by_victim[v])
	return out

# Glide the camera to frame one fight: the attackers, everything they hit and the
# defender's flag, as close as fits with a little margin.
const CAM_GLIDE := 0.6 # seconds at 1x
func _frame_fight(group: Array, flag_sites: Dictionary) -> void:
	var attackers: Array = []
	var action: Array = [] # where the shots land: the camera centres on these
	for item in group:
		attackers.append(MapWar.key_to_hex(str(item[0])))
		for e in (item[1] as Array):
			action.append(e["to"])
			for sp in e["splash"]:
				action.append(sp)
	if action.is_empty():
		return
	await _view.glide_to(_view.frame_for(attackers, 1.5, action), CAM_GLIDE / _speed())

# Visual march route for the card at `k` towards `target` (home first). Ground units walk
# over their own land, sail over open sea (the view draws a boat) and cross the border
# into the land of the nation they attack, never through a third nation's land;
# flying ones go straight over anything. It never ends nearer than `min_gap` hexes
# to the target (ranged units keep their distance). It ends on the free hex
# closest to the target (the border, or right beside it). Free means no card stands there
# and no other walker has claimed it (`taken`), so marching units never overlap.
# A single-hex path means stay put.
func _walk_path(k: String, target: Vector2i, taken: Dictionary, min_gap: int = 1) -> Array:
	var home := MapWar.key_to_hex(k)
	var info: Dictionary = _war.units[k]
	var nation := str(info["owner"])
	var flying: bool = info["card"] is Unit and (info["card"] as Unit).Flying
	var flags := {} # flag hexes are never a place to stand
	for nm in _war.players.keys():
		if _campaign().is_alive(str(nm)):
			flags[_campaign().capital_site(str(nm))] = true
	var free := func(t: Vector2i) -> bool:
		return t == home or (not taken.has(t) and not flags.has(t) and not _war.units.has(MapCampaign.key_of(t.x, t.y)))
	var home_d := MapCampaign.hex_distance(home, target)
	if flying:
		# rings around the target, nearest first: the free hex closest to home wins
		var goal := home
		var seen := {target: true}
		var ring: Array = [target]
		# (the rings before min_gap are only stepped through, never landed on)
		for radius in range(1, home_d):
			var next: Array = []
			for t in ring:
				for nb in MapCampaign.wrapped_neighbors(t):
					if not seen.has(nb):
						seen[nb] = true
						next.append(nb)
			ring = next
			if radius < min_gap:
				continue
			var best_h := 1 << 30
			for t in ring:
				var h := MapCampaign.hex_distance(home, t)
				if free.call(t) and h < best_h:
					best_h = h
					goal = t
			if goal != home:
				break
		# fly there in a straight hex line
		var path: Array = [home]
		var cur := home
		while cur != goal:
			var step := cur
			var step_d := MapCampaign.hex_distance(cur, goal)
			for nb in MapCampaign.wrapped_neighbors(cur):
				var d := MapCampaign.hex_distance(nb, goal)
				if d < step_d:
					step_d = d
					step = nb
			if step == cur:
				break
			cur = step
			path.append(cur)
		return path if cur == goal else [home]
	# ground: breadth-first over the nation's own land and the open sea; hexes much
	# farther from the target than home are never worth the detour
	var c := _campaign()
	var enemy := c.owner_of(target.x, target.y)
	var sails: bool = _war.can_sail(nation, info["card"]) # 1-move units never take a boat
	var reach: int = home_d + 8
	var parent := {home: home}
	var depth_of := {home: 0}
	var queue: Array = [home]
	var best := home
	var best_score := Vector3i(home_d, 0, 0)
	var head := 0
	while head < queue.size():
		var t: Vector2i = queue[head]
		head += 1
		# closest to the target first, then land over a boat, then the shorter trip
		var score := Vector3i(MapCampaign.hex_distance(t, target), 0 if WorldMap.is_land(t.x, t.y) else 1, int(depth_of[t]))
		if free.call(t) and score.x >= min_gap and score < best_score:
			best_score = score
			best = t
		for nb in MapCampaign.wrapped_neighbors(t):
			if parent.has(nb) or MapCampaign.hex_distance(nb, target) > reach or WorldMap.is_void(nb.x, nb.y):
				continue
			if not sails and not WorldMap.is_land(nb.x, nb.y):
				continue
			if WorldMap.is_land(nb.x, nb.y) and c.owner_of(nb.x, nb.y) != nation and (enemy == "" or c.owner_of(nb.x, nb.y) != enemy):
				continue
			parent[nb] = t
			depth_of[nb] = int(depth_of[t]) + 1
			queue.append(nb)
	var out: Array = [best]
	while out[0] != home:
		out.push_front(parent[out[0]])
	return out

func _resolve_collapses() -> void:
	var events: Array = _war.resolve_collapses()
	if events.is_empty():
		return
	for ev in events:
		var loser := str(ev["loser"])
		var winner := str(ev["winner"])
		if winner == _me():
			_bump_influence(int(ev.get("influence", 0)))
			_log_line("[color=#ffd966]+%d Influence[/color] for %d hex%s." % [int(ev.get("influence", 0)), int(ev["tiles"]), "" if int(ev["tiles"]) == 1 else "es"])
		if winner != "":
			_sfx("war")
			var tail := ("[b]%s is eliminated.[/b]" % loser) if bool(ev["eliminated"]) else ("%s rebuilds." % loser)
			var weak_note := ""
			match int(ev.get("multiplier", 1)):
				4: weak_note = " [color=#ff7060](no units on the map: 4x losses)[/color]"
				2: weak_note = " [color=#ffb070](under %d units: 2x losses)[/color]" % MapWar.WEAK_UNIT_COUNT
			_log_line("[color=#ff7a70]%s collapses![/color] %s takes %d hex%s%s. %s" % [loser, winner, int(ev["tiles"]), "" if int(ev["tiles"]) == 1 else "es", weak_note, tail])
			if bool(ev.get("flag_moved", false)) and not bool(ev["eliminated"]):
				var fs: Vector2i = ev["flag"]
				_log_line("%s's flag falls back to the heart of its land %s." % [loser, str(fs)])
				_view.add_place(fs)
		else:
			_log_line("%s is exhausted but nobody can reach its land. It rebuilds." % loser)
	_refresh()

func _check_end() -> bool:
	var c := _campaign()
	if c.has_won():
		_sfx("victory")
		_refresh()
		if WorldMap.STORY_CHAPTER > 0:
			_story_end(true)
		return true
	if c.has_lost():
		_sfx("defeat")
		_refresh()
		if WorldMap.STORY_CHAPTER > 0:
			_story_end(false)
		return true
	return false

# A story chapter is decided: record it and hand over to the story screen
# (the outro and the next chapter, or the defeat screen with a retry).
func _story_end(won: bool) -> void:
	var ch := WorldMap.STORY_CHAPTER
	var cid := WorldMap.STORY_CAMPAIGN
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if won:
			gs.story_complete(cid, ch)
		gs.delete_save() # nothing left to resume in a finished chapter
		gs.story_screen = {"phase": "outro" if won else "defeat", "campaign": cid, "chapter": ch}
	_status.text = "Chapter %d won!" % ch if won else "Chapter %d lost..." % ch
	await get_tree().create_timer(1.6).timeout
	get_tree().change_scene_to_file("res://scenes/Story.tscn")

# -------------------------------------------------------------------- shop
# Same shop as between card battles (GameState.buy_card / buy_modifier /
# remove_card_from_deck), paid with Influence earned by taking hexes. Stock
# refreshes at the start of each of your turns; bought cards join your draw pile.
const REMOVE_COST := MapWar.REMOVE_COST

# ------------------------------------------------------------ story briefings
# A chapter can brief the player on the map (StoryText "briefing" at the start,
# "combat_briefing" after the first End Turn). Shown once per war, on turn 1.
func _story_start_briefing() -> void:
	if WorldMap.STORY_CHAPTER <= 0 or _war == null or _war.turn != 1 or _war.has_meta("briefed_start"):
		return
	var b: Dictionary = StoryText.chapter(WorldMap.STORY_CAMPAIGN, WorldMap.STORY_CHAPTER).get("briefing", {})
	if b.is_empty():
		return
	_war.set_meta("briefed_start", true)
	# show the dug-in enemy Infantry while the briefing is up
	var enemy_inf: Array = []
	for k in _war.units.keys():
		if str(_war.units[k]["owner"]) != _me() and _war.units[k]["card"] is Infantry:
			enemy_inf.append(MapWar.key_to_hex(k))
	if not enemy_inf.is_empty():
		await _view.glide_to(_view.frame_for(enemy_inf, 1.0), 0.8)
	var has_wall := false
	for c in _human().Hand:
		if c is Wall:
			has_wall = true
	var hint := "You have a [Wall] in your hand: pick it below and place it on one of your hexes between the two armies." if has_wall \
		else "No [Wall] in your hand yet? Keep the trick in mind: one will turn up from your deck, or buy one in the [Shop] once you have Influence."
	var lines: Array = []
	for l in b["lines"]:
		lines.append(str(l).replace("{wall_hint}", hint))
	var foe := ""
	for n in WorldMap.nations():
		if str(n["name"]) != _me():
			foe = str(n["name"])
			break
	await _show_briefing(str(b["title"]), lines, str(b.get("button", "OK")),
		[["Infantry", foe, "mountain", "Dug in: 1 less damage per hit"], ["Wall", _me(), "grassland", "Your shield: soaks up their fire"]])
	var home := _campaign().capital_site(_me())
	await _view.glide_to(_view.frame_for([home] + enemy_inf, 1.0), 0.8)

# The chapter's forces (make_story.py "forces"): what makes each side different,
# plus every reinforcement on its way, so nothing that lands later is a surprise.
func _story_forces_briefing() -> void:
	if WorldMap.STORY_CHAPTER <= 0 or _war == null or _war.turn != 1 or _war.has_meta("briefed_forces"):
		return
	if WorldMap.FORCES.is_empty():
		return
	_war.set_meta("briefed_forces", true)
	var lines: Array = (WorldMap.FORCES.get("lines", []) as Array).duplicate()
	var due := _reinforcement_summary()
	if due != "":
		lines.append("Reinforcements on the way: " + due + ".")
	await _show_briefing(str(WorldMap.FORCES.get("title", "Order of Battle")), lines, str(WorldMap.FORCES.get("button", "To work")))

# "[Turn 3] Horde: 2 Tank; [Turn 4] you: 2 Howitzer" (you = the player's nation).
func _reinforcement_summary() -> String:
	var groups: Dictionary = {} # "turn|nation" -> [parts]
	var order: Array = []
	for r in _war.upcoming_reinforcements():
		var key := "%d|%s" % [int(r["turn"]), str(r["nation"])]
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		groups[key].append("%d %s" % [int(r["count"]), str(r["card"])])
	var out: Array = []
	for key in order:
		var bits: PackedStringArray = str(key).split("|")
		var who := "you" if bits[1] == _me() else bits[1]
		out.append("[Turn %s] %s: %s" % [bits[0], who, ", ".join(groups[key])])
	return "; ".join(out)

# Log and flash the reinforcements that just landed for nation `n` (MapWar.last_arrivals).
func _announce_arrivals(n: String) -> bool:
	var arr: Array = _war.last_arrivals
	_war.last_arrivals = []
	if arr.is_empty():
		return false
	var counts: Dictionary = {}
	for a in arr:
		counts[str(a[1])] = int(counts.get(str(a[1]), 0)) + 1
		_view.add_place(a[2] as Vector2i)
	var parts: Array = []
	for nm in counts.keys():
		parts.append("%d %s" % [counts[nm], nm])
	var who := "Your" if n == _me() else "[color=#%s]%s[/color]" % [_nation_hex_color(n), n]
	_log_line("%s reinforcements arrive: %s." % [who, ", ".join(parts)])
	_sfx("card_place", -4.0)
	_refresh()
	return true

func _story_combat_briefing() -> void:
	if WorldMap.STORY_CHAPTER <= 0 or _war == null or _war.turn != 1 or _war.has_meta("briefed_combat"):
		return
	var b: Dictionary = StoryText.chapter(WorldMap.STORY_CAMPAIGN, WorldMap.STORY_CHAPTER).get("combat_briefing", {})
	if b.is_empty():
		return
	_war.set_meta("briefed_combat", true)
	await _show_briefing(str(b["title"]), b["lines"], str(b.get("button", "OK")))

# A modal briefing card over the map: title, highlighted text, optional pictures
# ([card, nation, terrain, caption]), one button. Await it; it returns when closed.
func _show_briefing(title: String, lines: Array, button: String, pictures: Array = []) -> void:
	if _briefing != null and is_instance_valid(_briefing):
		_briefing.queue_free()
	var layer := Control.new()
	layer.name = "Briefing"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.z_index = 70
	add_child(layer)
	_briefing = layer
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP # the map waits until the briefing is read
	layer.add_child(dim)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"GoldPanel"
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(760, 0)
	panel.add_child(v)
	var t := Label.new()
	t.text = title.to_upper()
	t.theme_type_variation = &"TitleLabel"
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	v.add_child(t)
	if not pictures.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 28)
		v.add_child(row)
		for pic in pictures:
			row.add_child(_briefing_picture(str(pic[0]), str(pic[1]), str(pic[2]), str(pic[3])))
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(760, 0)
	body.add_theme_font_size_override("normal_font_size", 18)
	body.add_theme_constant_override("line_separation", 4)
	body.text = CardHover.highlight("\n\n".join(lines))
	v.add_child(body)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(foot)
	var ok := Button.new()
	ok.name = "BriefingOK"
	ok.text = button
	ok.theme_type_variation = &"PrimaryButton"
	ok.custom_minimum_size = Vector2(220, 46)
	ok.add_theme_font_size_override("font_size", 18)
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(func():
		layer.queue_free()
		_briefing = null
		briefing_closed.emit())
	foot.add_child(ok)
	_sfx("map_select")
	await get_tree().process_frame
	if is_instance_valid(panel):
		panel.reset_size()
		panel.position = ((size - panel.size) * 0.5).floor()
	await briefing_closed

# A card standing on a terrain tile, with a caption: the briefing's little pictures.
func _briefing_picture(card_name: String, nation: String, terrain: String, caption: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var tile := Control.new()
	tile.custom_minimum_size = Vector2(110, 96)
	col.add_child(tile)
	var tiles: Array = _view._tiles.get(terrain, [])
	if not tiles.is_empty():
		var ground := TextureRect.new()
		ground.texture = tiles[0]
		ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ground.stretch_mode = TextureRect.STRETCH_SCALE
		ground.position = Vector2(7, 0)
		ground.size = Vector2(96, 96)
		tile.add_child(ground)
	var art := Card.create_sprite_for(card_name, Vector2(80, 80), nation)
	art.position = Vector2(15, 4)
	art.size = Vector2(80, 80)
	tile.add_child(art)
	var cap := Label.new()
	cap.text = caption
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 14)
	cap.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	col.add_child(cap)
	return col

# ------------------------------------------------------------ round report
# Who did what to whom last round: damage dealt and where it came from (Barracks,
# modifiers, unit bonuses, splash), and damage stopped (Interceptors, mountains,
# forests, flying units dodging melee). Opens at the start of each of your turns
# after the first; the Report button reopens it.
const REPORT_COLS := [
	["dealt", "Dealt", "All damage that landed, flags included.", "val"],
	["flag", "Flag", "Of that, damage straight to the nation's flag (its HP).", "val"],
	["kills", "Kills", "Cards destroyed, and the HP their owner lost for them (their BioCost).", "val"],
	["barracks", "+Barracks", "Added by adjacent Barracks (+2 per shot).", "add"],
	["home", "+Home", "Added by firing from the attacker's own land (+1 per shot).", "add"],
	["modifiers", "+Modifiers", "Added (or taken away) by the attacker's modifiers: Guerilla Warfare, Aerial Supremacy, Defensive Doctrine.", "add"],
	["unit_bonus", "+Unit bonus", "Special Ops x2 against ground units, Anti Aircraft x3 against flying ones.", "add"],
	["boat", "+In boat", "Extra damage on ground units caught at sea in a boat (+1 per hit).", "add"],
	["flank", "+Flanked", "Extra damage on units hemmed in by enemy units: +1 flanked (enemies on opposite sides), +2 surrounded (4+), +4 encircled (all 6).", "add"],
	["splash", "+Splash", "Fighter Jet splash on the target's neighbours.", "add"],
	["blocked_interceptor", "-Interceptors", "Stopped by the defender's Interceptors (they halve ranged and flying hits).", "block"],
	["blocked_mountain", "-Mountains", "Stopped by mountain cover (1 per hit on ground units).", "block"],
	["blocked_forest", "-Forests", "Stopped by forest cover (1 per hit from flying attackers).", "block"],
	["blocked_flying", "-Flying", "Flying units take half damage from attackers without Range.", "block"],
]

func _open_report() -> void:
	_close_report()
	if _war == null:
		return
	_report_panel = PanelContainer.new()
	_report_panel.name = "ReportPanel"
	_report_panel.theme_type_variation = &"GoldPanel"
	_report_panel.z_index = 60
	add_child(_report_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_report_panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var title := Label.new()
	title.text = "ROUND REPORT"
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	head.add_child(title)
	var sub := Label.new()
	sub.text = ("Turn %d" % _report_turn) if _report_turn > 0 else ""
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	head.add_child(sub)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	for tab in [[false, "Your fights"], [true, "All nations"]]:
		var tb := Button.new()
		tb.text = tab[1]
		tb.focus_mode = Control.FOCUS_NONE
		tb.theme_type_variation = &"SelectedButton" if _report_all == tab[0] else &""
		var all_tab: bool = tab[0]
		tb.pressed.connect(func():
			_report_all = all_tab
			_open_report())
		head.add_child(tb)
	var rows := _report_rows()
	if rows.is_empty():
		var none := Label.new()
		none.text = "No fighting recorded yet. The report fills in over a round: your attack and every other nation's turn." if _report.is_empty() else "You neither dealt nor took damage last round. Try the All nations tab."
		none.add_theme_font_size_override("font_size", 16)
		v.add_child(none)
	else:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(1180, mini(460, 40 + rows.size() * 30))
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		v.add_child(scroll)
		var grid := GridContainer.new()
		grid.columns = 2 + REPORT_COLS.size()
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 6)
		scroll.add_child(grid)
		# headers: click to sort by that column, click again to flip the order
		for hspec in [["from", "From"], ["to", "To"]]:
			grid.add_child(_report_header(hspec[0], hspec[1], Color(1.0, 0.86, 0.35), "[%s]: click to sort by nation name, click again to reverse." % hspec[1]))
		for col in REPORT_COLS:
			var tip: String = "[%s]: %s Click to sort, click again to reverse." % [str(col[1]).trim_prefix("+").trim_prefix("-"), str(col[2])]
			grid.add_child(_report_header(str(col[0]), str(col[1]), _report_kind_color(str(col[3])), tip))
		for r in rows:
			var att := str(r[0])
			var vic := str(r[1])
			var st: Dictionary = r[2]
			grid.add_child(_report_nation(att))
			grid.add_child(_report_nation(vic))
			for col in REPORT_COLS:
				var cat := str(col[0])
				var n: int = int(st.get(cat, 0))
				var txt := "·"
				if cat == "kills":
					txt = ("%d (-%d HP)" % [n, int(st.get("kill_hp", 0))]) if n > 0 else "·"
				elif n != 0:
					match str(col[3]):
						"add": txt = ("+%d" % n) if n > 0 else str(n)
						"block": txt = "-%d" % n
						_: txt = str(n)
				grid.add_child(_report_cell(txt, _report_kind_color(str(col[3])) if n != 0 else Color(0.45, 0.46, 0.55)))
		v.add_child(_report_summary())
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(foot)
	var close := Button.new()
	close.text = "Close"
	close.theme_type_variation = &"PrimaryButton"
	close.custom_minimum_size = Vector2(120, 40)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_close_report)
	foot.add_child(close)
	# centre once the table has a size
	await get_tree().process_frame
	if _report_panel != null and is_instance_valid(_report_panel):
		_report_panel.reset_size()
		_report_panel.position = ((size - _report_panel.size) * 0.5).floor()

func _close_report() -> void:
	if _hover != null:
		_hover.hide_all()
	if _report_panel != null and is_instance_valid(_report_panel):
		_report_panel.queue_free()
	_report_panel = null

# [[attacker, victim, stats], ...]: yours first (your attacks, then attacks on you),
# each group by damage dealt.
func _report_rows() -> Array:
	var me := _me()
	var mine: Array = []
	var on_me: Array = []
	var others: Array = []
	for k in _report.keys():
		var parts := str(k).split("|")
		var row: Array = [parts[0], parts[1], _report[k]]
		if parts[0] == me:
			mine.append(row)
		elif parts[1] == me:
			on_me.append(row)
		elif _report_all:
			others.append(row)
	var by_dealt := func(a, b): return int(a[2].get("dealt", 0)) > int(b[2].get("dealt", 0))
	mine.sort_custom(by_dealt)
	on_me.sort_custom(by_dealt)
	others.sort_custom(by_dealt)
	var rows: Array = mine + on_me + others
	if _report_sort == "":
		return rows
	# a chosen column sorts the whole table; ties keep the default order above
	var order := {}
	for i in range(rows.size()):
		order[rows[i]] = i
	var col := _report_sort
	var desc := _report_sort_desc
	rows.sort_custom(func(a, b):
		var va = _report_sort_value(a, col)
		var vb = _report_sort_value(b, col)
		if va != vb:
			return (va > vb) if desc else (va < vb)
		return int(order[a]) < int(order[b]))
	return rows

func _report_sort_value(row: Array, col: String) -> Variant:
	match col:
		"from":
			return ("You" if str(row[0]) == _me() else str(row[0])).to_lower()
		"to":
			return ("You" if str(row[1]) == _me() else str(row[1])).to_lower()
		_:
			return int((row[2] as Dictionary).get(col, 0))

# A clickable column header; the sorted one shows a pixel arrow for its direction.
func _report_header(col: String, text: String, colour: Color, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_theme_font_size_override("font_size", 15)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new()) # sits like a label; only the colour reacts
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, colour.lightened(0.35) if state.begins_with("font_hover") else colour)
	if col == _report_sort:
		b.icon = _sort_arrow(not _report_sort_desc)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_theme_constant_override("h_separation", 4)
	b.pressed.connect(func():
		if _report_sort == col:
			_report_sort_desc = not _report_sort_desc
		else:
			_report_sort = col
			_report_sort_desc = col != "from" and col != "to" # numbers: biggest first; names: A-Z
		_open_report())
	_tip(b, func(): return tip)
	return b

# Gold pixel triangle, pointing up (ascending) or down (descending).
func _sort_arrow(up: bool) -> Texture2D:
	if _sort_arrows.is_empty():
		for dir_up in [true, false]:
			var img := Image.create(9, 6, false, Image.FORMAT_RGBA8)
			img.fill(Color(0, 0, 0, 0))
			for row in range(5):
				var half: int = row if dir_up else 4 - row
				for x in range(4 - half, 5 + half):
					img.set_pixel(x, row + 1 if dir_up else row, Color(1.0, 0.86, 0.35))
			_sort_arrows.append(ImageTexture.create_from_image(img))
	return _sort_arrows[0 if up else 1]

func _report_summary() -> Label:
	var me := _me()
	var dealt := 0
	var taken := 0
	var saved := 0
	var boosted := 0
	for k in _report.keys():
		var parts := str(k).split("|")
		var st: Dictionary = _report[k]
		if parts[0] == me:
			dealt += int(st.get("dealt", 0))
			boosted += int(st.get("barracks", 0)) + int(st.get("home", 0)) + int(st.get("flank", 0)) + int(st.get("boat", 0)) + int(st.get("modifiers", 0)) + int(st.get("unit_bonus", 0)) + int(st.get("splash", 0))
		elif parts[1] == me:
			taken += int(st.get("dealt", 0))
			for cat in ["blocked_interceptor", "blocked_mountain", "blocked_forest", "blocked_flying"]:
				saved += int(st.get(cat, 0))
	var l := Label.new()
	l.text = "You dealt %d damage (%s%d from bonuses) and took %d; your defences stopped %d." % [dealt, "+" if boosted >= 0 else "", boosted, taken, saved]
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	return l

func _report_cell(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", col)
	return l

func _report_nation(nm: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.add_child(_icon("res://Assets/Players/%s/flag.png" % nm, 20))
	var l := Label.new()
	l.text = "You" if nm == _me() else nm
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35) if nm == _me() else Color.html("#" + _nation_hex_color(nm)))
	h.add_child(l)
	return h

func _report_kind_color(kind: String) -> Color:
	match kind:
		"add": return Color(0.55, 0.95, 0.5)
		"block": return Color(0.5, 0.85, 1.0)
		_: return Color(0.95, 0.95, 1.0)

func _open_shop() -> void:
	if _busy or _war == null:
		return
	_clear_selection()
	_build_shop(false)

func _close_shop() -> void:
	if _hover != null:
		_hover.hide_all()
	if _shop_panel != null and is_instance_valid(_shop_panel):
		_shop_panel.queue_free()
	_shop_panel = null

func _shop_item(title: String, art: Control, lines: Array, cost: int, can_buy: bool, owned: bool, on_buy: Callable, hover_card: Card = null) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(170, 196)
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_meta("no_ui_sfx", true)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.anchor_right = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 8
	v.offset_bottom = -10
	v.add_theme_constant_override("separation", 2)
	btn.add_child(v)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 16)
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	v.add_child(t)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(art)
	for ln in lines:
		var l := Label.new()
		l.text = str(ln)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color(0.82, 0.84, 0.9))
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(l)
	var price := HBoxContainer.new()
	price.alignment = BoxContainer.ALIGNMENT_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.add_child(_icon("res://Assets/UI/influence_icon.png", 18))
	var pl := Label.new()
	pl.text = "Owned" if owned else str(cost)
	pl.add_theme_font_size_override("font_size", 17)
	pl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35) if can_buy else Color(1, 0.45, 0.4))
	price.add_child(pl)
	v.add_child(price)
	if not can_buy:
		btn.modulate = Color(1, 1, 1, 0.55)
	btn.pressed.connect(func():
		if can_buy:
			on_buy.call()
		else:
			_sfx("deny", -4.0))
	if hover_card != null:
		var p := _human()
		btn.mouse_entered.connect(func():
			var info := _hand_info(hover_card, p, "Shop offer")
			info["influence"] = cost
			info["notes"] = []
			_hover.show_card(hover_card, info, btn.get_global_rect()))
		btn.mouse_exited.connect(func(): _hover.hide_all())
	return btn

func _build_shop(remove_mode: bool) -> void:
	_close_shop()
	var p := _human()
	if _war == null or p == null:
		return
	var shop: Dictionary = _war.shop_of(_me())
	_shop_panel = PanelContainer.new()
	_shop_panel.name = "ShopPanel"
	_shop_panel.theme_type_variation = &"GoldPanel"
	_shop_panel.z_index = 60
	_shop_panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_shop_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_shop_panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var title := Label.new()
	title.text = "REMOVE A CARD" if remove_mode else "SHOP"
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	head.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(_icon("res://Assets/UI/influence_icon.png", 26))
	var inf := Label.new()
	inf.text = "%d Influence" % p.Influence
	inf.add_theme_font_size_override("font_size", 22)
	inf.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	head.add_child(inf)
	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.78, 0.8, 0.88))
	v.add_child(sub)
	if remove_mode:
		sub.text = "Pick a card to remove from your deck for %d Influence (once per turn). Cards already on the map stay." % REMOVE_COST
		var groups: Dictionary = {}
		for pile in [p.DrawPile, p.DiscardPile, p.Hand]:
			for c in pile:
				var cn := (c as Card).card_name
				if not groups.has(cn):
					groups[cn] = []
				(groups[cn] as Array).append(c)
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		v.add_child(grid)
		var names: Array = groups.keys()
		names.sort()
		for cn in names:
			var stack: Array = groups[cn]
			var card: Card = stack[0]
			var can: bool = p.Influence >= REMOVE_COST and not bool(shop["remove_used"])
			var item := _shop_item("%s  x%d" % [cn, stack.size()], Card.create_sprite_for(cn, Vector2(64, 64), _me()), [], REMOVE_COST, can, false, func():
				if _war.remove_card(_me(), card):
					_sfx("shop_buy")
					_log_line("You remove a %s from your deck." % cn)
					_after_purchase()
					_build_shop(false))
			item.custom_minimum_size = Vector2(150, 150)
			grid.add_child(item)
	else:
		sub.text = "Spend Influence (earned by taking hexes). Stock refreshes every turn; bought cards are drawn next.\nCard odds follow your starting deck: " + _odds_text(_me())
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(880, 0)
		v.add_child(_section_label("CARDS"))
		var cards_row := HBoxContainer.new()
		cards_row.add_theme_constant_override("separation", 8)
		v.add_child(cards_row)
		for c in shop["cards"]:
			var card := c as Card
			var lines: Array = []
			if card is Unit:
				var u := card as Unit
				lines.append("HP %d  DMG %d%s%s" % [u.HitPoints, u.Damage, "  RNG" if u.HasRange else "", "  FLY" if u.Flying else ""])
			elif card is Building:
				lines.append("HP %d  INC %d" % [(card as Building).HitPoints, (card as Building).Income])
			lines.append("$%d  Bio %d" % [card.MoneyCost, card.BioCost])
			var can_c: bool = p.Influence >= card.InfluenceCost
			cards_row.add_child(_shop_item(card.card_name, Card.create_sprite_for(card.card_name, Vector2(84, 84), _me()), lines, card.InfluenceCost, can_c, false, func():
				if _war.buy_card(_me(), card):
					_sfx("shop_buy")
					_log_line("You buy a %s (joins your draw pile)." % card.card_name)
					_after_purchase()
					_build_shop(false), card))
		if (shop["cards"] as Array).is_empty():
			var none := Label.new()
			none.text = "Sold out until next turn."
			cards_row.add_child(none)
		v.add_child(_section_label("MODIFIERS"))
		var mods_row := HBoxContainer.new()
		mods_row.add_theme_constant_override("separation", 8)
		v.add_child(mods_row)
		for m in shop["mods"]:
			var mod := m as Modifier
			var owned: bool = p.has_modifier(mod.modifier_name)
			var can_m: bool = not owned and p.Influence >= mod.InfluenceCost
			var item_m := _shop_item(mod.modifier_name, Modifier.create_sprite_for(mod.modifier_name, Vector2(64, 64)), [mod.Effect], mod.InfluenceCost, can_m, owned, func():
				if _war.buy_modifier(_me(), mod):
					_sfx("shop_buy")
					_log_line("You adopt %s.%s" % [mod.modifier_name, _modifier_effect_note(_war.last_modifier_changes)])
					_show_modifier_changes(_war.last_modifier_changes)
					_after_purchase()
					_build_shop(false))
			item_m.custom_minimum_size = Vector2(290, 222)
			mods_row.add_child(item_m)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 8)
	v.add_child(foot)
	if not remove_mode:
		var rm := Button.new()
		rm.text = "Remove a card (%d)" % REMOVE_COST if not bool(shop["remove_used"]) else "Removal used this turn"
		rm.disabled = bool(shop["remove_used"]) or p.Influence < REMOVE_COST
		rm.custom_minimum_size = Vector2(0, 44)
		rm.focus_mode = Control.FOCUS_NONE
		rm.pressed.connect(func(): _build_shop(true))
		foot.add_child(rm)
	else:
		var back := Button.new()
		back.text = "Back"
		back.custom_minimum_size = Vector2(110, 44)
		back.focus_mode = Control.FOCUS_NONE
		back.pressed.connect(func(): _build_shop(false))
		foot.add_child(back)
	var close := Button.new()
	close.text = "Close"
	close.theme_type_variation = &"PrimaryButton"
	close.custom_minimum_size = Vector2(120, 44)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_close_shop)
	foot.add_child(close)
	# centre on screen once its size is known
	_shop_panel.reset_size()
	await get_tree().process_frame
	if _shop_panel != null and is_instance_valid(_shop_panel):
		# the wrapped odds line measures tall before it has a width; shrink back to fit
		_shop_panel.reset_size()
		_shop_panel.position = ((size - _shop_panel.size) * 0.5).floor()

# "Infantry 29% · Wall 29% · Tank 9% ..." from the nation's starting deck.
func _odds_text(nation: String) -> String:
	var w: Dictionary = _war.deck_weights.get(nation, {})
	var total := 0
	for cn in w.keys():
		total += int(w[cn])
	var names: Array = w.keys()
	names.sort_custom(func(a, b): return int(w[a]) > int(w[b]) if int(w[a]) != int(w[b]) else str(a) < str(b))
	var parts: Array = []
	for cn in names:
		parts.append("%s %d%%" % [cn, roundi(100.0 * int(w[cn]) / maxi(total, 1))])
	return " · ".join(parts)

# " Applied now: 6 cards +10 HP, 2 buildings -25 HP." for the log
func _modifier_effect_note(changes: Array) -> String:
	if changes.is_empty():
		return ""
	var up := 0
	var down := 0
	for c in changes:
		if int(c["delta"]) > 0:
			up += 1
		else:
			down += 1
	var parts: Array = []
	if up > 0:
		parts.append("%d card%s gain HP" % [up, "" if up == 1 else "s"])
	if down > 0:
		parts.append("%d lose HP" % down)
	return " Applied to the map now: %s." % ", ".join(parts)

# Float the HP change over every affected card on the map.
func _show_modifier_changes(changes: Array) -> void:
	for c in changes:
		var d := int(c["delta"])
		_view.add_number(MapWar.key_to_hex(str(c["key"])), ("+%d" % d) if d > 0 else str(d), Color(0.5, 1, 0.5) if d > 0 else Color(1, 0.55, 0.3), 0.0)

func _after_purchase() -> void:
	_refresh_player_card()
	_refresh_hand()

# ----------------------------------------------------------------- buttons
func _on_new_campaign_pressed() -> void:
	if _busy:
		return
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return
	gs.start_map_campaign(gs.selected_player_name, WorldMap.MAP_ID)
	_war = gs.ensure_map_war()
	_view.set_war(_war)
	_banner.visible = false
	_log_lines.clear()
	_log_line("[color=#ffd966]New campaign.[/color] Turn 1.")
	_start_player_turn()
	_refresh()
	_go_home()

func _on_save_pressed() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("save_game"):
		_log_line("Save not available.")
		return
	_log_line("Campaign saved." if gs.save_game() else "Save failed.")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
