# Civ-style square-grid renderer for the WorldMap Earth data.
# Draws terrain tiles, nation capitals (flag or color marker), selection.
extends Control
class_name WorldMapView

signal tile_selected(x: int, y: int)

const TERRAIN_COLORS = {
	"ocean": Color(0.10, 0.22, 0.38),
	"grassland": Color(0.29, 0.55, 0.28),
	"desert": Color(0.82, 0.70, 0.42),
	"mountain": Color(0.45, 0.40, 0.38),
	"snow": Color(0.88, 0.91, 0.94),
	"jungle": Color(0.13, 0.42, 0.22),
}

var selected := Vector2i(-1, -1)
var _flags: Dictionary = {}
var _owners: Dictionary = {}
var _nation_colors: Dictionary = {}
var _dead: Dictionary = {}
var _player_nation: String = ""
var _campaign: MapCampaign = null
var _edges: Dictionary = {}
var _tiles: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_tiles = TileArt.make_tile_set()
	for n in WorldMap.nations():
		var d := n as Dictionary
		var path := "res://Assets/Players/%s/flag.png" % str(d["name"])
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				_flags[str(d["name"])] = tex
	resized.connect(queue_redraw)

func set_campaign(campaign: MapCampaign) -> void:
	_campaign = campaign
	_owners = campaign.owner.duplicate()
	_nation_colors.clear()
	_dead.clear()
	_edges.clear()
	_player_nation = campaign.player_nation
	for n in WorldMap.nations():
		var d := n as Dictionary
		var nm := str(d["name"])
		_nation_colors[nm] = Color.html(str(d["color"]))
		if not campaign.is_alive(nm):
			_dead[nm] = true
		else:
			_edges[nm] = campaign.border_edges(nm)
	queue_redraw()

func _variant_for(x: int, y: int) -> int:
	return absi(x * 73856093 ^ y * 19349663) % TileArt.VARIANTS

func metrics() -> Array:
	var tile: float = minf(size.x / WorldMap.GRID_W, size.y / WorldMap.GRID_H)
	var ox: float = (size.x - tile * WorldMap.GRID_W) * 0.5
	var oy: float = (size.y - tile * WorldMap.GRID_H) * 0.5
	return [tile, ox, oy]

func tile_at_point(p: Vector2) -> Vector2i:
	var m := metrics()
	var tile: float = m[0]
	var tx := int(floor((p.x - m[1]) / tile))
	var ty := int(floor((p.y - m[2]) / tile))
	if not WorldMap.in_bounds(tx, ty):
		return Vector2i(-1, -1)
	return Vector2i(tx, ty)

func _gui_input(event: InputEvent) -> void:
	var clicked := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		clicked = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		clicked = (event as InputEventScreenTouch).pressed
	if clicked:
		var t := Vector2i(-1, -1)
		if event is InputEventMouseButton:
			t = tile_at_point((event as InputEventMouseButton).position)
		else:
			t = tile_at_point((event as InputEventScreenTouch).position)
		if t.x >= 0:
			selected = t
			queue_redraw()
			tile_selected.emit(t.x, t.y)

func _draw() -> void:
	var m := metrics()
	var tile: float = m[0]
	var ox: float = m[1]
	var oy: float = m[2]
	if tile < 2.0:
		return
	# Tiles: art texture + translucent owner tint (wilderness keeps pure art)
	for y in range(WorldMap.GRID_H):
		for x in range(WorldMap.GRID_W):
			var rect := Rect2(ox + x * tile, oy + y * tile, tile + 0.5, tile + 0.5)
			var variants: Array = _tiles.get(WorldMap.terrain_at(x, y), [])
			if variants.is_empty():
				draw_rect(rect, TERRAIN_COLORS.get(WorldMap.terrain_at(x, y), Color.BLACK), true)
			else:
				draw_texture_rect(variants[_variant_for(x, y)] as Texture2D, rect, false)
			var o: String = str(_owners.get(MapCampaign.key_of(x, y), ""))
			if o != "" and _nation_colors.has(o):
				var nc := _nation_colors[o] as Color
				draw_rect(rect, Color(nc.r, nc.g, nc.b, 0.32), true)
	# Grid lines
	var grid_col := Color(0, 0, 0, 0.25)
	for x in range(WorldMap.GRID_W + 1):
		var lx := ox + x * tile
		draw_line(Vector2(lx, oy), Vector2(lx, oy + WorldMap.GRID_H * tile), grid_col, 1.0)
	for y in range(WorldMap.GRID_H + 1):
		var ly := oy + y * tile
		draw_line(Vector2(ox, ly), Vector2(ox + WorldMap.GRID_W * tile, ly), grid_col, 1.0)
	# Nation borders in each nation's own color
	var bw: float = maxf(2.0, tile * 0.14)
	for nm in _edges.keys():
		var bc := _nation_colors[nm] as Color
		for e in (_edges[nm] as Array):
			var entry := e as Array
			_draw_border_edge(entry[0] as Vector2i, entry[1] as Vector2i, tile, ox, oy, bw, bc)
	# Capitals (flags follow the nation if its home tile falls)
	var font := ThemeDB.fallback_font
	for n in WorldMap.nations():
		var d := n as Dictionary
		var nm := str(d["name"])
		var site := Vector2i(int(d["x"]), int(d["y"]))
		if _campaign != null:
			site = _campaign.capital_site(nm)
		var cx := ox + (site.x + 0.5) * tile
		var cy := oy + (site.y + 0.5) * tile
		var center := Vector2(cx, cy)
		var radius: float = tile * 0.62
		var ncol := Color.html(str(d["color"]))
		if _dead.has(nm):
			ncol = Color(0.35, 0.35, 0.38)
		# White ring + nation color disc so capitals read on any terrain
		if nm == _player_nation:
			draw_circle(center, radius + 3.5, Color(1.0, 0.84, 0.2))
		draw_circle(center, radius + 1.5, Color.WHITE)
		draw_circle(center, radius, ncol)
		if _flags.has(nm) and not _dead.has(nm):
			var tex: Texture2D = _flags[nm]
			var side: float = tile * 0.9
			draw_texture_rect(tex, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false)
		else:
			var letter := nm.left(1)
			var fs := int(clampf(tile * 0.7, 8.0, 22.0))
			var tw := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var th := font.get_height(fs)
			draw_string(font, center + Vector2(-tw * 0.5, th * 0.35), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# Selection highlight
	if selected.x >= 0:
		var sel := Rect2(ox + selected.x * tile, oy + selected.y * tile, tile, tile)
		draw_rect(sel, Color(1, 1, 1, 0.9), false, 2.0)

func _draw_border_edge(t: Vector2i, d: Vector2i, tile: float, ox: float, oy: float, w: float, col: Color) -> void:
	var rx: float = ox + t.x * tile
	var ry: float = oy + t.y * tile
	var inset: float = w * 0.5
	var ext: float = w * 0.5
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	if d == Vector2i(1, 0):
		a = Vector2(rx + tile - inset, ry - ext)
		b = Vector2(rx + tile - inset, ry + tile + ext)
	elif d == Vector2i(-1, 0):
		a = Vector2(rx + inset, ry - ext)
		b = Vector2(rx + inset, ry + tile + ext)
	elif d == Vector2i(0, 1):
		a = Vector2(rx - ext, ry + tile - inset)
		b = Vector2(rx + tile + ext, ry + tile - inset)
	else:
		a = Vector2(rx - ext, ry + inset)
		b = Vector2(rx + tile + ext, ry + inset)
	draw_line(a, b, col, w, true)
