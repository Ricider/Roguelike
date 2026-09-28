# Civ-style hex renderer for the WorldMap Earth data.
# Pointy-top hexes in "odd-r" offset layout (odd rows shifted half a hex right),
# matching MapCampaign's hex adjacency. Pixel-art terrain (TileArt) mapped onto
# each hex, a shimmering sea, owner tints, crisp nation borders along hex edges
# and flag-on-pole capitals. Fast-changing bits (front-line pulse, hover,
# selection) live on a child overlay so the 1800-hex base layer redraws rarely.
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
const PULSE_FPS: float = 20.0
const SQRT3: float = 1.7320508

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
var _front: Array = [] # enemy hexes touching the player's border (attackable nations only)
var _sea_phase: int = 0
var _sea_clock: float = 0.0
var _pulse_t: float = 0.0
var _pulse_clock: float = 0.0
var _overlay: Control = null
var _corner_unit: PackedVector2Array = PackedVector2Array()
var _hex_uvs: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tiles = TileArt.make_tile_set()
	# Unit pointy-top hex (size 1): corner k at angle 60k-30 deg, edge k runs corner k -> k+1
	for k in range(6):
		var a: float = deg_to_rad(60.0 * k - 30.0)
		_corner_unit.append(Vector2(cos(a), sin(a)))
		# UV: hex bounding box (sqrt3 x 2) mapped onto the square tile texture
		_hex_uvs.append(Vector2(cos(a) / SQRT3 + 0.5, sin(a) * 0.5 + 0.5))
	for n in WorldMap.nations():
		var d := n as Dictionary
		var path := "res://Assets/Players/%s/flag.png" % str(d["name"])
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				_flags[str(d["name"])] = tex
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	resized.connect(queue_redraw)
	mouse_exited.connect(func():
		hovered = Vector2i(-1, -1)
		_overlay.queue_redraw())

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
	if _overlay != null:
		_overlay.queue_redraw()

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
	_pulse_clock += delta
	if _sea_clock >= SEA_STEP_SEC:
		_sea_clock = 0.0
		_sea_phase = (_sea_phase + 1) % TileArt.VARIANTS
		queue_redraw()
	if not _front.is_empty() and _pulse_clock >= 1.0 / PULSE_FPS:
		_pulse_clock = 0.0
		_overlay.queue_redraw()

func _variant_for(x: int, y: int) -> int:
	return absi(x * 73856093 ^ y * 19349663) % TileArt.VARIANTS

# [hex size (centre->corner), origin x, origin y, hex width]
func metrics() -> Array:
	var avail := size - Vector2(FRAME_PX, FRAME_PX) * 2.0
	var s: float = minf(avail.x / ((WorldMap.GRID_W + 0.5) * SQRT3), avail.y / (1.5 * WorldMap.GRID_H + 0.5))
	s = maxf(s, 0.0)
	var w: float = SQRT3 * s
	var map_w: float = (WorldMap.GRID_W + 0.5) * w
	var map_h: float = (1.5 * WorldMap.GRID_H + 0.5) * s
	var ox: float = floorf((size.x - map_w) * 0.5)
	var oy: float = floorf((size.y - map_h) * 0.5)
	return [s, ox, oy, w]

func hex_center(x: int, y: int, m: Array) -> Vector2:
	var s: float = m[0]
	var w: float = m[3]
	return Vector2(m[1] + (x + 0.5 * float(y & 1)) * w + w * 0.5, m[2] + y * 1.5 * s + s)

func _hex_points(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(6)
	for k in range(6):
		pts[k] = c + _corner_unit[k] * s
	return pts

func tile_at_point(p: Vector2) -> Vector2i:
	var m := metrics()
	var s: float = m[0]
	if s <= 0.0:
		return Vector2i(-1, -1)
	# pixel -> axial (relative to hex (0,0) centre) -> cube round -> odd-r offset
	var o := hex_center(0, 0, m)
	var px: float = p.x - o.x
	var py: float = p.y - o.y
	var q: float = (SQRT3 / 3.0 * px - py / 3.0) / s
	var r: float = (2.0 / 3.0 * py) / s
	var cx: float = q
	var cz: float = r
	var cy: float = -cx - cz
	var rx: float = roundf(cx)
	var ry: float = roundf(cy)
	var rz: float = roundf(cz)
	var dx: float = absf(rx - cx)
	var dy: float = absf(ry - cy)
	var dz: float = absf(rz - cz)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	var row := int(rz)
	var col := int(rx) + (row - (row & 1)) / 2
	if not WorldMap.in_bounds(col, row):
		return Vector2i(-1, -1)
	return Vector2i(col, row)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := tile_at_point((event as InputEventMouseMotion).position)
		if h != hovered:
			hovered = h
			_overlay.queue_redraw()
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
	queue_redraw() # selected nation tint lives on the base layer
	_overlay.queue_redraw()
	tile_selected.emit(t.x, t.y)

func _draw_hex_tex(c: Vector2, s: float, tex: Texture2D, tint: Color = Color.WHITE) -> void:
	draw_polygon(_hex_points(c, s), PackedColorArray([tint]), _hex_uvs, tex)

func _draw() -> void:
	var m := metrics()
	var s: float = m[0]
	var w: float = m[3]
	if s < 2.0:
		return
	var ox: float = m[1]
	var oy: float = m[2]
	var map_rect := Rect2(ox, oy, (WorldMap.GRID_W + 0.5) * w, (1.5 * WorldMap.GRID_H + 0.5) * s)
	# Deep sea hexes fill the letterbox so the map never floats in a void
	var ocean_tiles: Array = _tiles.get("ocean", [])
	if not ocean_tiles.is_empty():
		var pad_x := int(ceil(ox / w)) + 2
		var pad_y := int(ceil(oy / (1.5 * s))) + 2
		for y in range(-pad_y, WorldMap.GRID_H + pad_y):
			for x in range(-pad_x, WorldMap.GRID_W + pad_x):
				if WorldMap.in_bounds(x, y):
					continue
				var c := hex_center(x, y, m)
				if c.x < -w or c.x > size.x + w or c.y < -s * 2.0 or c.y > size.y + s * 2.0:
					continue
				_draw_hex_tex(c, s + 0.5, ocean_tiles[absi(x + y + _sea_phase) % ocean_tiles.size()] as Texture2D, Color(0.42, 0.47, 0.62))
	# Pixel bezel around the playable map
	var fr := map_rect.grow(FRAME_PX)
	draw_rect(fr, Color8(20, 16, 30), false, 4.0)
	draw_rect(fr.grow(-3.0), Color8(94, 104, 128), false, 2.0)
	draw_rect(Rect2(fr.position + Vector2(3, 3), Vector2(fr.size.x - 6, 1)), Color8(190, 200, 216), true)
	# Hexes: terrain art + translucent owner tint (wilderness keeps pure art)
	var sel_owner: String = ""
	if selected.x >= 0:
		sel_owner = str(_owners.get(MapCampaign.key_of(selected.x, selected.y), ""))
	var grid_col := Color(0, 0, 0, 0.22)
	for y in range(WorldMap.GRID_H):
		for x in range(WorldMap.GRID_W):
			var c := hex_center(x, y, m)
			var terrain := WorldMap.terrain_at(x, y)
			var variants: Array = _tiles.get(terrain, [])
			# +0.5px overdraw hides hairline seams between neighbouring hexes
			if variants.is_empty():
				draw_colored_polygon(_hex_points(c, s + 0.5), TERRAIN_COLORS.get(terrain, Color.BLACK))
			else:
				var v := _variant_for(x, y)
				if terrain == "ocean":
					v = (v + _sea_phase) % variants.size()
				_draw_hex_tex(c, s + 0.5, variants[v] as Texture2D)
			var o: String = str(_owners.get(MapCampaign.key_of(x, y), ""))
			if o != "" and _nation_colors.has(o):
				var nc := _nation_colors[o] as Color
				draw_colored_polygon(_hex_points(c, s + 0.5), Color(nc.r, nc.g, nc.b, 0.46 if o == sel_owner else 0.30))
	# Faint hex grid
	for y in range(WorldMap.GRID_H):
		for x in range(WorldMap.GRID_W):
			var pts := _hex_points(hex_center(x, y, m), s)
			pts.append(pts[0])
			draw_polyline(pts, grid_col, 1.0)
	# Nation borders along hex edges, each with a dark under-stroke
	var bw: float = maxf(2.0, floorf(s * 0.22))
	for nm in _edges.keys():
		var bc := _nation_colors[nm] as Color
		if nm == _player_nation:
			bc = Color(1.0, 0.84, 0.2)
		for e in (_edges[nm] as Array):
			var entry := e as Array
			var t := entry[0] as Vector2i
			var k: int = int(entry[2])
			var c := hex_center(t.x, t.y, m)
			# pull the edge slightly inward so neighbouring nations' borders sit side by side
			var inset := s - bw * 0.5
			var a := c + _corner_unit[k] * inset
			var b := c + _corner_unit[(k + 1) % 6] * inset
			draw_line(a, b, Color(0.05, 0.04, 0.08, 0.85), bw + 2.0)
			draw_line(a, b, bc, bw)
	# Capitals: pixel flag on a pole, planted on the capital hex
	for n in WorldMap.nations():
		var d := n as Dictionary
		var nm := str(d["name"])
		var site := Vector2i(int(d["x"]), int(d["y"]))
		if _campaign != null:
			site = _campaign.capital_site(nm)
		var base := hex_center(site.x, site.y, m) + Vector2(0, s * 0.55)
		var fs: float = maxf(s * 2.6, 16.0)
		draw_rect(Rect2(base + Vector2(-fs * 0.2, -2.0), Vector2(fs * 0.4, 3.0)), Color(0, 0, 0, 0.45), true)
		if _dead.has(nm):
			var cc := base - Vector2(0, s * 0.6)
			var r: float = s * 0.45
			draw_line(cc - Vector2(r, r), cc + Vector2(r, r), Color(0.8, 0.8, 0.85), 2.0)
			draw_line(cc + Vector2(-r, r), cc + Vector2(r, -r), Color(0.8, 0.8, 0.85), 2.0)
			continue
		if _flags.has(nm):
			# flag art has its pole at ~x=0.12 of the texture; plant that on the hex centre
			draw_texture_rect(_flags[nm] as Texture2D, Rect2(base - Vector2(fs * 0.12, fs * 0.9), Vector2(fs, fs)), false)
		if nm == _player_nation:
			_draw_star(self, base + Vector2(0, -fs * 0.98), maxf(s * 0.5, 4.0), Color(1.0, 0.86, 0.3))

func _draw_overlay() -> void:
	var m := metrics()
	var s: float = m[0]
	if s < 2.0:
		return
	# Front line: enemy hexes you could win next pulse red with a hatch
	if not _front.is_empty():
		var pulse: float = 0.30 + 0.25 * (0.5 + 0.5 * sin(_pulse_t * 4.0))
		for t in _front:
			var tv := t as Vector2i
			var c := hex_center(tv.x, tv.y, m)
			_overlay.draw_colored_polygon(_hex_points(c, s), Color(1.0, 0.18, 0.12, pulse))
			_overlay.draw_line(c + Vector2(-s * 0.5, s * 0.5), c + Vector2(s * 0.5, -s * 0.5), Color(1, 0.9, 0.8, pulse + 0.2), 2.0)
			var ring := _hex_points(c, s - 1.5)
			ring.append(ring[0])
			_overlay.draw_polyline(ring, Color(1, 0.3, 0.25, pulse + 0.25), 2.0)
	if hovered.x >= 0 and hovered != selected:
		_hex_outline(hovered, m, Color(1, 1, 1, 0.6), 2.0)
	if selected.x >= 0:
		_hex_outline(selected, m, Color8(20, 16, 30), 5.0)
		_hex_outline(selected, m, Color(1.0, 0.86, 0.3), 2.5)

func _hex_outline(t: Vector2i, m: Array, col: Color, width: float) -> void:
	var pts := _hex_points(hex_center(t.x, t.y, m), m[0])
	pts.append(pts[0])
	_overlay.draw_polyline(pts, col, width)

func _draw_star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var ang: float = -PI / 2.0 + i * PI / 5.0
		var rad: float = r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	ci.draw_colored_polygon(pts, col)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, Color8(20, 16, 30), 1.0)
