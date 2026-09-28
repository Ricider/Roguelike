# World Map campaign screen: same battles/shop as a sequential run, but wars
# are chosen on the map. Attack neighboring nations only; winner takes
# 1 tile per 10 HP left from the shared border. Conquer the world to win.
extends Control

const ICON_HP := "res://Assets/UI/heart.png"
const ICON_INF := "res://Assets/UI/influence_icon.png"

var _view: WorldMapView = null
var _info: RichTextLabel = null
var _info_tile: TextureRect = null
var _banner: Label = null
var _attack_btn: Button = null
var _legend: VBoxContainer = null
var _player_flag: TextureRect = null
var _player_name: Label = null
var _stat_tiles: Label = null
var _stat_hp: Label = null
var _stat_inf: Label = null
var _hover_bar: Label = null
var _target: String = ""
var _land_total: int = 0

func _ready() -> void:
	_sfx_music("map")
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.map_campaign == null or not gs.map_mode or gs.map_campaign.player_nation != gs.selected_player_name:
			gs.start_map_campaign(gs.selected_player_name)
	for y in range(WorldMap.GRID_H):
		for x in range(WorldMap.GRID_W):
			if WorldMap.is_land(x, y):
				_land_total += 1
	_build_ui()
	_refresh()

func _sfx(sfx_name: String) -> void:
	var sm = get_node_or_null("/root/SoundManager")
	if sm != null:
		sm.play(sfx_name)

func _sfx_music(track: String) -> void:
	var sm = get_node_or_null("/root/SoundManager")
	if sm != null:
		sm.play_music(track)

func _campaign() -> MapCampaign:
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return null
	return gs.map_campaign as MapCampaign

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
	return t

func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"TitleLabel"
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	return l

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
		margin.add_theme_constant_override(side_name, 12)
	add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)
	# Left: map with a hover readout underneath
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
	_hover_bar = Label.new()
	_hover_bar.name = "HoverBar"
	_hover_bar.text = "Hover a tile for details  ·  red pulsing tiles = nations you can attack"
	_hover_bar.add_theme_font_size_override("font_size", 16)
	_hover_bar.add_theme_color_override("font_color", Color(0.85, 0.86, 0.92))
	map_col.add_child(_hover_bar)
	# Right: command panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	hbox.add_child(panel)
	var side := VBoxContainer.new()
	side.name = "Side"
	side.add_theme_constant_override("separation", 10)
	panel.add_child(side)
	var title := Label.new()
	title.text = "WORLD MAP"
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86))
	side.add_child(title)
	# Player card: flag, name, tiles / HP / influence
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
	stats.add_theme_constant_override("separation", 6)
	card_col.add_child(stats)
	_stat_tiles = Label.new()
	stats.add_child(_stat_tiles)
	stats.add_child(_icon(ICON_HP, 18))
	_stat_hp = Label.new()
	stats.add_child(_stat_hp)
	stats.add_child(_icon(ICON_INF, 18))
	_stat_inf = Label.new()
	stats.add_child(_stat_inf)
	_banner = Label.new()
	_banner.name = "Banner"
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_theme_font_size_override("font_size", 16)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.84, 0.2))
	side.add_child(_banner)
	side.add_child(_section_label("NATIONS"))
	_legend = VBoxContainer.new()
	_legend.name = "Legend"
	_legend.add_theme_constant_override("separation", 3)
	side.add_child(_legend)
	side.add_child(_section_label("INTEL"))
	var info_box := PanelContainer.new()
	info_box.custom_minimum_size = Vector2(0, 120)
	side.add_child(info_box)
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 10)
	info_box.add_child(info_row)
	_info_tile = TextureRect.new()
	_info_tile.custom_minimum_size = Vector2(48, 48)
	_info_tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_info_tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	info_row.add_child(_info_tile)
	_info = RichTextLabel.new()
	_info.name = "Info"
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.scroll_active = false
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_font_size_override("normal_font_size", 16)
	_info.text = "Select a tile to inspect it."
	info_row.add_child(_info)
	_attack_btn = Button.new()
	_attack_btn.name = "AttackButton"
	_attack_btn.text = "Attack"
	_attack_btn.disabled = true
	_attack_btn.theme_type_variation = &"PrimaryButton"
	_attack_btn.custom_minimum_size = Vector2(0, 56)
	_attack_btn.add_theme_font_size_override("font_size", 22)
	_attack_btn.pressed.connect(_on_attack_pressed)
	side.add_child(_attack_btn)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	side.add_child(row)
	for spec in [["NewCampaignButton", "New Campaign", _on_new_campaign_pressed], ["SaveButton", "Save", _on_save_pressed], ["BackButton", "Menu", _on_back_pressed]]:
		var b := Button.new()
		b.name = spec[0]
		b.text = spec[1]
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 17)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[2])
		row.add_child(b)
	var sm = get_node_or_null("/root/SoundManager")
	if sm != null:
		var snd: Button = sm.make_toggle_button()
		snd.custom_minimum_size = Vector2(0, 40)
		snd.add_theme_font_size_override("font_size", 15)
		side.add_child(snd)

func _refresh() -> void:
	var c := _campaign()
	if c == null:
		return
	_view.set_campaign(c)
	_target = ""
	_attack_btn.disabled = true
	_attack_btn.text = "Attack"
	for child in _legend.get_children():
		child.queue_free()
	for n in WorldMap.nations():
		_legend.add_child(_nation_row(c, n as Dictionary))
	var gs = get_node_or_null("/root/GameState")
	var hp := 0
	var inf := 0
	if gs != null and gs.run_player != null:
		hp = gs.run_player.HitPoints
		inf = gs.run_player.Influence
	_player_flag.texture = _flag_tex(c.player_nation)
	_player_name.text = c.player_nation
	_stat_tiles.text = "%d tiles" % c.tile_count(c.player_nation)
	_stat_hp.text = str(hp)
	_stat_inf.text = str(inf)
	if c.has_won():
		_banner.text = "WORLD CONQUERED! %s rules all %d tiles." % [c.player_nation, c.tile_count(c.player_nation)]
	elif c.has_lost():
		_banner.text = "ELIMINATED! %s holds no territory. Start a New Campaign." % c.player_nation
	else:
		var targets: Array = []
		for n in c.alive_nations():
			if n != c.player_nation and c.can_attack(str(n)):
				targets.append(n)
		_banner.text = "Pick a pulsing red tile to declare war. %d neighbor%s in reach." % [targets.size(), "" if targets.size() == 1 else "s"]

func _nation_row(c: MapCampaign, d: Dictionary) -> Control:
	var nm := str(d["name"])
	var alive := c.is_alive(nm)
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(0, 34)
	btn.tooltip_text = "%s - capital %s" % [nm, str(d["capital"])]
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.add_theme_constant_override("separation", 8)
	btn.add_child(row)
	var flag := TextureRect.new()
	flag.texture = _flag_tex(nm)
	flag.custom_minimum_size = Vector2(32, 32)
	flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(flag)
	var name_lbl := Label.new()
	name_lbl.text = nm
	name_lbl.custom_minimum_size = Vector2(150, 0)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if nm == c.player_nation:
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	row.add_child(name_lbl)
	# territory share bar in the nation's colour
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = maxi(_land_total, 1)
	bar.value = c.tile_count(nm)
	bar.custom_minimum_size = Vector2(70, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.html(str(d["color"]))
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.04, 0.08)
	back.border_color = Color(0.37, 0.41, 0.5)
	back.set_border_width_all(1)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	row.add_child(bar)
	var count := Label.new()
	count.text = str(c.tile_count(nm)) if alive else "—"
	count.custom_minimum_size = Vector2(34, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_theme_font_size_override("font_size", 15)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(count)
	if alive and nm != c.player_nation and c.can_attack(nm) and not c.has_won():
		var war := Label.new()
		war.text = "WAR"
		war.add_theme_font_size_override("font_size", 13)
		war.add_theme_color_override("font_color", Color(1, 0.4, 0.35))
		war.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(war)
	if not alive:
		btn.modulate = Color(1, 1, 1, 0.4)
	else:
		btn.pressed.connect(func(): _view.select_tile(c.capital_site(nm)))
	return btn

func _tile_summary(c: MapCampaign, x: int, y: int) -> String:
	var terrain := WorldMap.terrain_at(x, y).capitalize()
	var o := c.owner_of(x, y)
	if o == "":
		return "%s · %s" % [terrain, "wilderness" if WorldMap.is_land(x, y) else "open sea"]
	var tag := ""
	if o == c.player_nation:
		tag = " (you)"
	elif c.can_attack(o):
		tag = " · can attack"
	return "%s · %s%s" % [terrain, o, tag]

func _on_tile_hovered(x: int, y: int) -> void:
	var c := _campaign()
	if c == null:
		return
	_hover_bar.text = "(%d, %d)  %s" % [x, y, _tile_summary(c, x, y)]

func _on_tile_selected(x: int, y: int) -> void:
	var c := _campaign()
	if c == null:
		return
	_sfx("map_select")
	_target = ""
	_attack_btn.disabled = true
	_attack_btn.text = "Attack"
	var terrain := WorldMap.terrain_at(x, y)
	var tiles: Array = _view._tiles.get(terrain, [])
	_info_tile.texture = (tiles[_view._variant_for(x, y)] as Texture2D) if not tiles.is_empty() else null
	var text := "[b]%s[/b]  [color=#9a9ab0](%d, %d)[/color]" % [terrain.capitalize(), x, y]
	var o := c.owner_of(x, y)
	if o == "":
		if WorldMap.is_land(x, y):
			text += "\nWilderness. Unclaimed, no wars here."
		else:
			text += "\nOpen sea."
		_info.text = text
		return
	text += "\nOwner: [color=#%s]%s[/color] (%d tiles)" % [Color.html(str(WorldMap.nation_by_name(o).get("color", "ffffff"))).to_html(false), o, c.tile_count(o)]
	var holder := c.capital_holder_at(x, y)
	if holder != "":
		var n := WorldMap.nation_by_name(holder)
		text += "\nCapital: %s (%s)" % [str(n.get("capital", holder)), holder]
	if c.has_won() or c.has_lost():
		_info.text = text
		return
	if o == c.player_nation:
		text += "\n[color=#ffd966]Your territory.[/color]"
	elif not c.is_alive(o):
		text += "\nEliminated."
	elif c.can_attack(o):
		text += "\n[color=#ff7a70]Neighbor. You can declare war![/color]"
		_target = o
		_attack_btn.disabled = false
		_attack_btn.text = "Attack %s!" % o
	else:
		text += "\nNo shared border. Conquer your way there."
	_info.text = text

func _on_attack_pressed() -> void:
	var c := _campaign()
	var gs = get_node_or_null("/root/GameState")
	if c == null or gs == null or _target == "":
		return
	if not c.can_attack(_target):
		return
	_sfx("war")
	gs.start_map_battle(_target)
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_new_campaign_pressed() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return
	gs.start_map_campaign(gs.selected_player_name)
	_info.text = "Select a tile to inspect it."
	_info_tile.texture = null
	_refresh()

func _on_save_pressed() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("save_game"):
		_info.text = "Save not available."
		return
	_info.text = "Campaign saved." if gs.save_game() else "Save failed."

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
