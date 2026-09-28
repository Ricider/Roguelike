# Civ-style square-grid renderer for the WorldMap Earth data.
# Pixel-art terrain tiles (TileArt) with a shimmering sea, owner tints, crisp
# nation borders, a pulsing front line on nations you can attack, hover and
# selection outlines, and flag-on-pole capitals.
extends Control
class_name WorldMapView

signal tile_selected(x: int, y: int)
signal tile_hovered(x: int, y: int)

const TERRAIN_COLORS = {
	"ocean": Color(0.10, 0.22, 0.38),
	"grassland": Color(0.29, 0.55, 0.28),
	"desert": Color(0.82, 0.70, 0.42),
	"mountain": Color(0.45, 0.40, 0.38),
	"snow": Color(0.88, 0.91, 0.94),
	"jungle": Color(0.13, 0.42, 0.22),
}
const FRAME_PX: float = 6.0
const SEA_STEP_SEC: float = 0.7

var selected := Vector2i(-1, -1)
var hovered := Vector2i(-1, -1)
var _flags: Dictionary = {}
var _owners: Dictionary = {}
var _nation_colors: Dictionary = {}
var _dead: Dictionary = {}
var _player_nation: String = ""
var _campaign: MapCampaign = null
var _edges: Dictionary = {}
var _tiles: Dictionary = {}
var _front: Array = [] # enemy tiles touching the player's border (attackable nations only)
var _sea_phase: int = 0
var _sea_clock: float = 0.0
var _pulse_t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tiles = TileArt.make_tile_set()
	for n in WorldMap.nations():
		var d := n as Dictionary
		var path := "res://Assets/Players/%s/flag.png" % str(d["name"])
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				_flags[str(d["name"])] = tex
	resized.connect(queue_redraw)
	mouse_exited.connect(func():
		hovered = Vector2i(-1, -1)
		queue_redraw())

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
	_front = _compute_front(campaign)
	queue_redraw()

func _compute_front(campaign: MapCampaign) -> Array:
	var out: Array = []
	if campaign.has_won() or campaign.has_lost():
		return out
	for key in _owners.keys():
		var o := str(_owners[key])
		if o == _player_nation or not campaign.can_attack(o):
			continue
		var parts := str(key).split(",")
		var t := Vector2i(int(parts[0]), int(parts[1]))
		for nb in MapCampaign.wrapped_neighbors(t):
			var nv := nb as Vector2i
			if str(_owners.get(MapCampaign.key_of(nv.x, nv.y), "")) == _player_nation:
				out.append(t)
				break
	return out

func _process(delta: float) -> void:
	_sea_clock += delta
	_pulse_t += delta
	var dirty := not _front.is_empty()
	if _sea_clock >= SEA_STEP_SEC:
		_sea_clock = 0.0
		_sea_phase = (_sea_phase + 1) % TileArt.VARIANTS
		dirty = true
	if dirty:
		queue_redraw()

func _variant_for(x: int, y: int) -> int:
	return absi(x * 73856093 ^ y * 19349663) % TileArt.VARIANTS

func metrics() -> Array:
	var avail := size - Vector2(FRAME_PX, FRAME_PX) * 2.0
	var tile: float = floorf(minf(avail.x / WorldMap.GRID_W, avail.y / WorldMap.GRID_H))
	var ox: float = floorf((size.x - tile * WorldMap.GRID_W) * 0.5)
	var oy: float = floorf((size.y - tile * WorldMap.GRID_H) * 0.5)
	return [tile, ox, oy]

func tile_at_point(p: Vector2) -> Vector2i:
	var m := metrics()
	var tile: float = m[0]
	if tile <= 0.0:
		return Vector2i(-1, -1)
	var tx := int(floor((p.x - m[1]) / tile))
	var ty := int(floor((p.y - m[2]) / tile))
	if not WorldMap.in_bounds(tx, ty):
		return Vector2i(-1, -1)
	return Vector2i(tx, ty)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := tile_at_point((event as InputEventMouseMotion).position)
		if h != hovered:
			hovered = h
			queue_redraw()
			if h.x >= 0:
				tile_hovered.emit(h.x, h.y)
		return
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
			select_tile(t)

func select_tile(t: Vector2i) -> void:
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
	var map_rect := Rect2(ox, oy, tile * WorldMap.GRID_W, tile * WorldMap.GRID_H)
	# Deep sea fills the letterbox so the map never floats in a void
	var ocean_tiles: Array = _tiles.get("ocean", [])
	if not ocean_tiles.is_empty():
		var cols := int(ceil(size.x / tile)) + 1
		var rows := int(ceil(size.y / tile)) + 1
		var sx := fposmod(ox, tile) - tile
		var sy := fposmod(oy, tile) - tile
		for j in range(rows + 1):
			for i in range(cols + 1):
				var r := Rect2(sx + i * tile, sy + j * tile, tile, tile)
				if map_rect.encloses(r):
					continue
				draw_texture_rect(ocean_tiles[(i + j + _sea_phase) % ocean_tiles.size()] as Texture2D, r, false, Color(0.45, 0.5, 0.65))
	# Pixel bezel around the playable map
	var fr := map_rect.grow(FRAME_PX)
	draw_rect(fr, Color8(20, 16, 30), true)
	draw_rect(fr.grow(-2.0), Color8(94, 104, 128), true)
	draw_rect(Rect2(fr.position + Vector2(2, 2), Vector2(fr.size.x - 4, 2)), Color8(190, 200, 216), true)
	draw_rect(map_rect.grow(1.0), Color8(20, 16, 30), true)
	# Tiles: art texture + translucent owner tint (wilderness keeps pure art)
	var sel_owner: String = ""
	if selected.x >= 0:
		sel_owner = str(_owners.get(MapCampaign.key_of(selected.x, selected.y), ""))
	for y in range(WorldMap.GRID_H):
		for x in range(WorldMap.GRID_W):
			var rect := Rect2(ox + x * tile, oy + y * tile, tile, tile)
			var terrain := WorldMap.terrain_at(x, y)
			var variants: Array = _tiles.get(terrain, [])
			if variants.is_empty():
				draw_rect(rect, TERRAIN_COLORS.get(terrain, Color.BLACK), true)
			else:
				var v := _variant_for(x, y)
				if terrain == "ocean":
					v = (v + _sea_phase) % variants.size()
				draw_texture_rect(variants[v] as Texture2D, rect, false)
			var o: String = str(_owners.get(MapCampaign.key_of(x, y), ""))
			if o != "" and _nation_colors.has(o):
				var nc := _nation_colors[o] as Color
				var a: float = 0.30
				if o == sel_owner:
					a = 0.46
				draw_rect(rect, Color(nc.r, nc.g, nc.b, a), true)
	# Faint grid
	var grid_col := Color(0, 0, 0, 0.18)
	for x in range(WorldMap.GRID_W + 1):
		var lx := ox + x * tile
		draw_line(Vector2(lx, oy), Vector2(lx, oy + WorldMap.GRID_H * tile), grid_col, 1.0)
	for y in range(WorldMap.GRID_H + 1):
		var ly := oy + y * tile
		draw_line(Vector2(ox, ly), Vector2(ox + WorldMap.GRID_W * tile, ly), grid_col, 1.0)
	# Front line: enemy tiles you could win next pulse red
	if not _front.is_empty():
		var pulse: float = 0.30 + 0.25 * (0.5 + 0.5 * sin(_pulse_t * 4.0))
		for t in _front:
			var tv := t as Vector2i
			var fr_rect := Rect2(ox + tv.x * tile, oy + tv.y * tile, tile, tile)
			draw_rect(fr_rect, Color(1.0, 0.18, 0.12, pulse), true)
			# crossed-swords style hatch + red frame reads even on red-tinted nations
			draw_line(fr_rect.position + Vector2(2, tile - 2), fr_rect.position + Vector2(tile - 2, 2), Color(1, 0.9, 0.8, pulse + 0.2), 2.0)
			draw_rect(fr_rect.grow(-1.0), Color(1, 0.3, 0.25, pulse + 0.25), false, 2.0)
	# Nation borders in each nation's own color, with a dark under-stroke
	var bw: float = maxf(2.0, floorf(tile * 0.14))
	for nm in _edges.keys():
		var bc := _nation_colors[nm] as Color
		if nm == _player_nation:
			bc = Color(1.0, 0.84, 0.2)
		for e in (_edges[nm] as Array):
			var entry := e as Array
			_draw_border_edge(entry[0] as Vector2i, entry[1] as Vector2i, tile, ox, oy, bw + 2.0, Color(0.05, 0.04, 0.08, 0.8))
			_draw_border_edge(entry[0] as Vector2i, entry[1] as Vector2i, tile, ox, oy, bw, bc)
	# Hover + selection outlines (square pixel frames)
	if hovered.x >= 0 and hovered != selected:
		_draw_tile_frame(hovered, tile, ox, oy, Color(1, 1, 1, 0.55), 2.0)
	if selected.x >= 0:
		_draw_tile_frame(selected, tile, ox, oy, Color8(20, 16, 30), 4.0)
		_draw_tile_frame(selected, tile, ox, oy, Color(1.0, 0.86, 0.3), 2.0)
	# Capitals: pixel flag on a pole, planted on the capital tile
	for n in WorldMap.nations():
		var d := n as Dictionary
		var nm := str(d["name"])
		var site := Vector2i(int(d["x"]), int(d["y"]))
		if _campaign != null:
			site = _campaign.capital_site(nm)
		var base := Vector2(ox + (site.x + 0.5) * tile, oy + (site.y + 1.0) * tile)
		var fs: float = maxf(tile * 1.7, 16.0)
		# ground marker under the pole
		draw_rect(Rect2(base + Vector2(-fs * 0.28, -2.0), Vector2(fs * 0.5, 3.0)), Color(0, 0, 0, 0.45), true)
		if _dead.has(nm):
			var c := base - Vector2(0, tile * 0.5)
			var s: float = tile * 0.3
			draw_line(c - Vector2(s, s), c + Vector2(s, s), Color(0.8, 0.8, 0.85), 2.0)
			draw_line(c + Vector2(-s, s), c + Vector2(s, -s), Color(0.8, 0.8, 0.85), 2.0)
			continue
		if _flags.has(nm):
			# flag art has its pole at ~x=0.12 of the texture; plant that on the tile centre
			var pos := base - Vector2(fs * 0.12, fs * 0.9)
			draw_texture_rect(_flags[nm] as Texture2D, Rect2(pos, Vector2(fs, fs)), false)
		if nm == _player_nation:
			_draw_star(base + Vector2(0, -fs * 0.98), maxf(tile * 0.32, 4.0), Color(1.0, 0.86, 0.3))

func _draw_tile_frame(t: Vector2i, tile: float, ox: float, oy: float, col: Color, w: float) -> void:
	var r := Rect2(ox + t.x * tile, oy + t.y * tile, tile, tile)
	draw_rect(r.grow(w * 0.5), col, false, w)

func _draw_star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var ang: float = -PI / 2.0 + i * PI / 5.0
		var rad: float = r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	draw_colored_polygon(pts, col)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color8(20, 16, 30), 1.0)

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
	draw_line(a, b, col, w, false)
