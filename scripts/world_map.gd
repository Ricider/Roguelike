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
const START_ZOOM := 1.9 # open zoomed in on your capital so units read clearly
const PAN_STEP := 60.0
const SHOT_SFX := {
	"Infantry": "shot_rifle", "Special Ops": "shot_rifle",
	"Tank": "shot_cannon", "Artilery": "shot_cannon", "Howitzer": "shot_cannon",
	"Rocket Launcher": "shot_rocket", "RocketLauncher": "shot_rocket",
	"Drone": "shot_laser", "Fighter Jet": "missile", "Interceptor": "missile",
	"Anti Aircraft": "shot_flak",
}

var _view: WorldMapView = null
var _war: MapWar = null
var _banner: Label = null
var _status: Label = null
var _legend: VBoxContainer = null
var _player_flag: TextureRect = null
var _player_name: Label = null
var _stat_hp: Label = null
var _stat_bio: Label = null
var _stat_money: Label = null
var _stat_tiles: Label = null
var _hover_bar: Label = null
var _hand_box: HBoxContainer = null
var _end_btn: Button = null
var _speed_btn: Button = null
var _log: RichTextLabel = null
var _selected: Card = null
var _busy: bool = false
var _speed_idx: int = 1 # 2x: a full round of 8 nations stays snappy
var _log_lines: Array = []

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
		_start_player_turn()
	_refresh()
	# camera needs the laid-out view size before it can centre
	await get_tree().process_frame
	_go_home()

func _go_home() -> void:
	var c := _campaign()
	if c != null and c.is_alive(c.player_nation):
		_view.center_on(c.capital_site(c.player_nation), START_ZOOM)

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
	l.add_theme_font_size_override("font_size", 12)
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
	map_col.add_child(_view)
	# zoom controls floating in the map's top-right corner
	var zoom_bar := HBoxContainer.new()
	zoom_bar.name = "ZoomBar"
	zoom_bar.add_theme_constant_override("separation", 4)
	zoom_bar.anchor_left = 1.0
	zoom_bar.anchor_right = 1.0
	zoom_bar.offset_left = -196
	zoom_bar.offset_right = -10
	zoom_bar.offset_top = 10
	zoom_bar.offset_bottom = 54
	_view.add_child(zoom_bar)
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
	_hover_bar.text = "Pick a card below, then click a glowing hex. Scroll to zoom, drag to pan, arrows/WASD move, H returns home."
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
	title.text = "WORLD WAR"
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86))
	side.add_child(title)
	# Player card: flag, name, HP / Bio / Money / hexes
	var card := PanelContainer.new()
	card.theme_type_variation = &"GoldPanel"
	side.add_child(card)
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 10)
	card.add_child(card_row)
	_player_flag = TextureRect.new()
	_player_flag.custom_minimum_size = Vector2(64, 64)
	_player_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_player_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_player_flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	card_row.add_child(_player_flag)
	var card_col := VBoxContainer.new()
	card_col.add_theme_constant_override("separation", 2)
	card_row.add_child(card_col)
	_player_name = Label.new()
	_player_name.add_theme_font_size_override("font_size", 22)
	_player_name.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	card_col.add_child(_player_name)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 5)
	card_col.add_child(stats)
	stats.add_child(_icon(ICON_HP, 18))
	_stat_hp = Label.new()
	stats.add_child(_stat_hp)
	stats.add_child(_icon(ICON_BIO, 18))
	_stat_bio = Label.new()
	stats.add_child(_stat_bio)
	stats.add_child(_icon(ICON_MONEY, 18))
	_stat_money = Label.new()
	stats.add_child(_stat_money)
	_stat_tiles = Label.new()
	_stat_tiles.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	_stat_tiles.add_theme_font_size_override("font_size", 15)
	card_col.add_child(_stat_tiles)
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
	side.add_child(_section_label("BATTLE LOG"))
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
	_refresh_legend()
	_refresh_player_card()
	_refresh_hand()
	if c.has_won():
		_show_banner("WORLD CONQUERED! %s rules all %d hexes." % [c.player_nation, c.tile_count(c.player_nation)], Color(1.0, 0.86, 0.35))
	elif c.has_lost():
		_show_banner("ELIMINATED! %s holds no territory. Start a New campaign." % c.player_nation, Color(1, 0.45, 0.4))

func _show_banner(text: String, col: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", col)
	_banner.visible = true
	_end_btn.disabled = true

func _refresh_player_card() -> void:
	var c := _campaign()
	var p := _human()
	_player_flag.texture = _flag_tex(c.player_nation)
	_player_name.text = c.player_nation
	if p != null:
		_stat_hp.text = "%d/%d" % [p.HitPoints, p.MaxHitPoints]
		_stat_bio.text = str(p.BioSupply)
		_stat_money.text = str(p.MoneySupply)
	_stat_tiles.text = "%d hexes · %d cards on the map · turn %d" % [c.tile_count(c.player_nation), _war.cards_of(c.player_nation).size() if _war != null else 0, _war.turn if _war != null else 1]

func _refresh_legend() -> void:
	var c := _campaign()
	for child in _legend.get_children():
		child.queue_free()
	for n in WorldMap.nations():
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
	name_lbl.custom_minimum_size = Vector2(128, 0)
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
		btn.tooltip_text = "%s · capital %s · HP %d/%d" % [nm, str(d["capital"]), p.HitPoints, p.MaxHitPoints]
	row.add_child(hp_bar)
	var count := Label.new()
	count.text = ("%d hex" % c.tile_count(nm)) if alive else "out"
	count.custom_minimum_size = Vector2(54, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_theme_font_size_override("font_size", 14)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(count)
	if not alive:
		btn.modulate = Color(1, 1, 1, 0.4)
	else:
		btn.pressed.connect(func(): _view.select_tile(c.capital_site(nm), false))
	return btn

# ------------------------------------------------------------------- hand
func _refresh_hand() -> void:
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
	var art := Card.create_sprite_for(card.card_name, Vector2(64, 64))
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
	var keys: Dictionary = {}
	for t in _campaign().tiles_of(_me()):
		var tv := t as Vector2i
		if not _war.units.has(MapCampaign.key_of(tv.x, tv.y)):
			keys[MapCampaign.key_of(tv.x, tv.y)] = true
	_view.placeable = keys
	_view.ghost_card = card.card_name
	_hover_bar.text = "Deploy %s: click a glowing hex (Esc to cancel)." % card.card_name
	_refresh_hand()

func _clear_selection() -> void:
	_selected = null
	_view.placeable = {}
	_view.ghost_card = ""
	_refresh_hand()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var kc := (event as InputEventKey).keycode
		if kc == KEY_ESCAPE and _selected != null:
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
	text += " · " + (o if o != "" else ("wilderness" if WorldMap.is_land(x, y) else "open sea"))
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
			if card is Unit:
				var u := card as Unit
				var ranged: bool = (_war.players[owner] as Player).has_range_for(u)
				text += "  DMG %d · %s" % [_war.effective_damage(owner, u, Vector2i(x, y)), "ranged: random card of the closest nation" if ranged else "hits the closest enemy"]
	return text

func _on_tile_hovered(x: int, y: int) -> void:
	if _campaign() == null or _war == null:
		return
	if _selected != null:
		var why := _war.can_place(_me(), _selected, Vector2i(x, y))
		_hover_bar.text = ("Deploy %s here" % _selected.card_name) if why == "" else why
		return
	_hover_bar.text = _describe(x, y)

func _on_tile_selected(x: int, y: int) -> void:
	if _war == null or _busy:
		return
	if _selected == null:
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
func _start_player_turn() -> void:
	_war.begin_turn(_me())
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
	_clear_selection()
	_sfx("end_turn", -2.0)
	_status.text = "Your units open fire..."
	await _nation_attacks(_me())
	_war.end_turn(_me())
	if _check_end():
		return
	for n in _war.turn_order():
		if n == _me() or not _war.alive(n):
			continue
		_status.text = "%s is moving..." % n
		_war.begin_turn(n)
		var placed: Array = _war.ai_build(n)
		for pl in placed:
			_view.add_place(pl[1] as Vector2i)
		if not placed.is_empty():
			_sfx("card_place", -6.0)
			_log_line("[color=#%s]%s[/color] deploys %d card%s." % [_nation_hex_color(n), n, placed.size(), "" if placed.size() == 1 else "s"])
			await _wait(0.35)
		await _nation_attacks(n)
		_war.end_turn(n)
		if _check_end():
			return
	_war.turn += 1
	_log_line("[color=#ffd966]Turn %d.[/color]" % _war.turn)
	_start_player_turn()
	_refresh()

func _nation_attacks(n: String) -> void:
	var shots := 0
	for k in _war.attackers_of(n):
		var entries: Array = _war.fire(k)
		for e in entries:
			shots += 1
			var kind: String = SHOT_SFX.get(str(e["card"]), "shot_rifle")
			var travel: float = TRAVEL / _speed()
			var destroyed: Array = e["destroyed"]
			_view.add_shot(e["from"], e["to"], kind, travel)
			_sfx(kind, -6.0)
			for dinfo in destroyed:
				_view.add_wreck(dinfo["hex"], str(dinfo["name"]), str(dinfo["owner"]), travel)
				_view.add_boom(dinfo["hex"], true, travel)
			for sp in e["splash"]:
				_view.add_boom(sp as Vector2i, false, travel)
			_view.add_boom(e["to"], false, travel)
			_view.add_number(e["to"], "-%d" % int(e["damage"]), Color(1, 0.8, 0.3) if e["direct"] else Color(1, 0.45, 0.4), travel)
			var impact: String = "hq_hit" if e["direct"] else ("explosion" if not destroyed.is_empty() else ("intercept" if e["intercepted"] else "hit"))
			get_tree().create_timer(travel).timeout.connect(func(): _sfx(impact, -5.0))
			if e["direct"]:
				_log_line("[color=#%s]%s[/color] %s hits [color=#%s]%s[/color]'s flag for %d" % [_nation_hex_color(n), n, e["card"], _nation_hex_color(str(e["victim"])), e["victim"], int(e["damage"])])
			elif not destroyed.is_empty():
				_log_line("[color=#%s]%s[/color] %s destroys [color=#%s]%s[/color]'s %s" % [_nation_hex_color(n), n, e["card"], _nation_hex_color(str(e["victim"])), e["victim"], e["target_name"]])
			await _wait(SHOT_GAP)
		_refresh_player_card()
	if shots > 0:
		await _wait(TRAVEL + 0.15)
	_refresh_legend()
	_refresh_player_card()
	_resolve_collapses()

func _resolve_collapses() -> void:
	var events: Array = _war.resolve_collapses()
	if events.is_empty():
		return
	for ev in events:
		var loser := str(ev["loser"])
		var winner := str(ev["winner"])
		if winner != "":
			_sfx("war")
			var tail := ("[b]%s is eliminated.[/b]" % loser) if bool(ev["eliminated"]) else ("%s rebuilds." % loser)
			_log_line("[color=#ff7a70]%s collapses![/color] %s takes %d hex%s. %s" % [loser, winner, int(ev["tiles"]), "" if int(ev["tiles"]) == 1 else "es", tail])
		else:
			_log_line("%s is exhausted but nobody can reach its land. It rebuilds." % loser)
	_refresh()

func _check_end() -> bool:
	var c := _campaign()
	if c.has_won():
		_sfx("victory")
		_refresh()
		return true
	if c.has_lost():
		_sfx("defeat")
		_refresh()
		return true
	return false

# ----------------------------------------------------------------- buttons
func _on_new_campaign_pressed() -> void:
	if _busy:
		return
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return
	gs.start_map_campaign(gs.selected_player_name)
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
