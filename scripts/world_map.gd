# World Map campaign screen: same battles/shop as a sequential run, but wars
# are chosen on the map. Attack neighboring nations only; winner takes
# 1 tile per 10 HP left from the shared border. Conquer the world to win.
extends Control

var _view: WorldMapView = null
var _info: Label = null
var _banner: Label = null
var _attack_btn: Button = null
var _target: String = ""

func _ready() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs != null:
		if gs.map_campaign == null or not gs.map_mode or gs.map_campaign.player_nation != gs.selected_player_name:
			gs.start_map_campaign(gs.selected_player_name)
	_build_ui()
	_refresh()

func _campaign() -> MapCampaign:
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return null
	return gs.map_campaign as MapCampaign

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.name = "BG"
	bg.color = Color(0.05, 0.06, 0.10, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 12)
	add_child(hbox)
	_view = WorldMapView.new()
	_view.name = "MapView"
	_view.custom_minimum_size = Vector2(600, 400)
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.tile_selected.connect(_on_tile_selected)
	hbox.add_child(_view)
	var side := VBoxContainer.new()
	side.name = "Side"
	side.custom_minimum_size = Vector2(360, 0)
	side.add_theme_constant_override("separation", 8)
	hbox.add_child(side)
	var title := Label.new()
	title.text = "WORLD MAP"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.94, 0.92, 0.86))
	side.add_child(title)
	_banner = Label.new()
	_banner.name = "Banner"
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_theme_font_size_override("font_size", 16)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.84, 0.2))
	side.add_child(_banner)
	var legend_title := Label.new()
	legend_title.text = "NATIONS"
	legend_title.add_theme_font_size_override("font_size", 20)
	side.add_child(legend_title)
	var legend := VBoxContainer.new()
	legend.name = "Legend"
	legend.add_theme_constant_override("separation", 6)
	side.add_child(legend)
	_info = Label.new()
	_info.name = "Info"
	_info.text = "Select a tile to inspect it."
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 16)
	_info.custom_minimum_size = Vector2(0, 130)
	side.add_child(_info)
	_attack_btn = Button.new()
	_attack_btn.name = "AttackButton"
	_attack_btn.text = "Attack"
	_attack_btn.disabled = true
	_attack_btn.custom_minimum_size = Vector2(0, 56)
	_attack_btn.add_theme_font_size_override("font_size", 22)
	_attack_btn.pressed.connect(_on_attack_pressed)
	side.add_child(_attack_btn)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	var new_btn := Button.new()
	new_btn.name = "NewCampaignButton"
	new_btn.text = "New Campaign"
	new_btn.custom_minimum_size = Vector2(0, 48)
	new_btn.add_theme_font_size_override("font_size", 18)
	new_btn.pressed.connect(_on_new_campaign_pressed)
	side.add_child(new_btn)
	var save_btn := Button.new()
	save_btn.name = "SaveButton"
	save_btn.text = "Save Campaign"
	save_btn.custom_minimum_size = Vector2(0, 48)
	save_btn.add_theme_font_size_override("font_size", 18)
	save_btn.pressed.connect(_on_save_pressed)
	side.add_child(save_btn)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Menu"
	back.custom_minimum_size = Vector2(0, 48)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(_on_back_pressed)
	side.add_child(back)

func _refresh() -> void:
	var c := _campaign()
	if c == null:
		return
	_view.set_campaign(c)
	_target = ""
	_attack_btn.disabled = true
	_attack_btn.text = "Attack"
	var legend := get_node("HBox/Side/Legend") as VBoxContainer
	for child in legend.get_children():
		child.queue_free()
	for n in WorldMap.nations():
		var d := n as Dictionary
		var nm := str(d["name"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var swatch := ColorRect.new()
		swatch.color = Color.html(str(d["color"]))
		if not c.is_alive(nm):
			swatch.color = Color(0.35, 0.35, 0.38)
		swatch.custom_minimum_size = Vector2(22, 22)
		row.add_child(swatch)
		var lab := Label.new()
		var you := "  <YOU>" if nm == c.player_nation else ""
		if c.is_alive(nm):
			lab.text = "%s%s - %s (%d tiles)" % [nm, you, str(d["capital"]), c.tile_count(nm)]
		else:
			lab.text = "%s%s - eliminated" % [nm, you]
		lab.add_theme_font_size_override("font_size", 15)
		row.add_child(lab)
		legend.add_child(row)
	var gs = get_node_or_null("/root/GameState")
	var hp := 0
	var inf := 0
	if gs != null and gs.run_player != null:
		hp = gs.run_player.HitPoints
		inf = gs.run_player.Influence
	if c.has_won():
		_banner.text = "WORLD CONQUERED! %s rules all %d tiles. Start a New Campaign or return to Menu." % [c.player_nation, c.tile_count(c.player_nation)]
	elif c.has_lost():
		_banner.text = "ELIMINATED! %s holds no territory. Start a New Campaign." % c.player_nation
	else:
		_banner.text = "You: %s - %d tiles | HP %d | Influence %d\nTap a neighboring enemy to declare war (1 tile per 10 HP)." % [c.player_nation, c.tile_count(c.player_nation), hp, inf]

func _on_tile_selected(x: int, y: int) -> void:
	var c := _campaign()
	if c == null:
		return
	_target = ""
	_attack_btn.disabled = true
	_attack_btn.text = "Attack"
	var terrain := WorldMap.terrain_at(x, y)
	var text := "Tile (%d, %d)\nTerrain: %s" % [x, y, terrain.capitalize()]
	var o := c.owner_of(x, y)
	if o == "":
		if WorldMap.is_land(x, y):
			text += "\nWilderness (unclaimed, no wars here)"
		_info.text = text
		return
	text += "\nOwner: %s (%d tiles)" % [o, c.tile_count(o)]
	var holder := c.capital_holder_at(x, y)
	if holder != "":
		var n := WorldMap.nation_by_name(holder)
		text += "\nCapital: %s (%s)" % [str(n.get("capital", holder)), holder]
	if c.has_won() or c.has_lost():
		_info.text = text
		return
	if o == c.player_nation:
		text += "\nYour territory."
	elif not c.is_alive(o):
		text += "\nEliminated."
	elif c.can_attack(o):
		text += "\nNeighbor - you can declare war!"
		_target = o
		_attack_btn.disabled = false
		_attack_btn.text = "Attack %s!" % o
	else:
		text += "\nNo shared border - conquer your way there."
	_info.text = text

func _on_attack_pressed() -> void:
	var c := _campaign()
	var gs = get_node_or_null("/root/GameState")
	if c == null or gs == null or _target == "":
		return
	if not c.can_attack(_target):
		return
	gs.start_map_battle(_target)
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_new_campaign_pressed() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return
	gs.start_map_campaign(gs.selected_player_name)
	_info.text = "Select a tile to inspect it."
	_refresh()

func _on_save_pressed() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs == null or not gs.has_method("save_game"):
		_info.text = "Save not available."
		return
	_info.text = "Campaign saved." if gs.save_game() else "Save failed."

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
