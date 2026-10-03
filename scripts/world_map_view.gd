# Civ-style hex renderer for the WorldMap Earth data, with a zoom/pan camera.
# Pointy-top hexes in "odd-r" offset layout (odd rows shifted half a hex right),
# matching MapCampaign's hex adjacency. The map wraps east-west like a globe:
# panning sideways scrolls forever and any hex can appear more than once when
# zoomed out. Pixel-art terrain (TileArt), shimmering sea, owner tints, nation
# borders along hex edges and flag-on-pole capitals are drawn on the base layer;
# fast-changing bits (units, FX, hover, selection, placement hints) live on a
# child overlay so the base layer only redraws on camera moves and map changes.
# Controls: mouse wheel zooms at the cursor, drag (any button) pans, and
# zoom_by()/pan_by()/center_on() are public for buttons and keys.
extends Control
class_name WorldMapView

signal tile_selected(x: int, y: int)
signal tile_hovered(x: int, y: int)
signal hover_cleared # mouse left the map or moved off the grid

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
const ZOOM_MIN: float = 1.0 # whole world fits the width
const ZOOM_MAX: float = 4.0
const DRAG_THRESHOLD: float = 6.0
const UNIT_FRAMES := [0, 5, 10, 15]
const SHOT_COLORS := {
	"shot_rifle": Color(1.0, 0.9, 0.4), "shot_cannon": Color(1.0, 0.6, 0.2), "shot_rocket": Color(1, 1, 1),
	"shot_laser": Color(0.4, 0.9, 1.0), "missile": Color(0.95, 0.95, 1.0), "shot_flak": Color(1.0, 0.7, 0.3),
}

var selected := Vector2i(-1, -1)
var hovered := Vector2i(-1, -1)
var zoom: float = 1.0
var _pan := Vector2.ZERO # map origin offset in pixels (x wraps, y is clamped)
var _flags: Dictionary = {}
var _owners: Dictionary = {}
var _nation_colors: Dictionary = {}
var _dead: Dictionary = {}
var _player_nation: String = ""
var _campaign: MapCampaign = null
var _edges: Dictionary = {}
var _edge_map: Dictionary = {} # "x,y" -> [[edge index, colour], ...]
var _tiles: Dictionary = {}
# Terrain is one GPU mesh in map units (hex size 1), built once and moved/scaled
# for pan and zoom, so the camera never redraws hex by hex:
#   _sea_meshes[phase] - ocean + deep-sea margin, one per wave phase (map fixed)
#   _land_mesh         - land hexes tinted by owner (rebuilt when borders change)
# Grid lines and borders are precomputed segment lists drawn with draw_multiline.
var _terrain: Control = null # layer behind the view with the tint shader
var _atlas: ImageTexture = null
var _sea_meshes: Array = []
var _sea_map_id: String = ""
var _land_mesh: ArrayMesh = null
var _land_dirty: bool = true
var _land_sel_owner: String = "~"
var _grid_pts := PackedVector2Array()
var _border_segs: Array = [] # [[Color, PackedVector2Array]] in map units
const TERRAIN_SHADER := """
shader_type canvas_item;
// vertex colour = owner tint (alpha = strength), blended over the tile texture
// (fragment COLOR arrives pre-multiplied by the texture, so pass the raw tint)
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(mix(t.rgb, tint.rgb, tint.a), t.a);
}
"""
const HEX_OVERDRAW := 1.015 # a hair over hex size 1 so neighbours never show seams
const DEEP_SEA_TINT := Color(0.05, 0.08, 0.18, 0.5)
const VOID_LAND_TINT := Color(0.16, 0.16, 0.2, 0.74) # story maps: land outside the chapter's war
const VOID_SEA_TINT := Color(0.08, 0.09, 0.13, 0.62)
var _front: Array = [] # enemy hexes touching the player's border (card-battle mode only)
var _sea_phase: int = 0
var _sea_clock: float = 0.0
var _pulse_t: float = 0.0
var _pulse_clock: float = 0.0
var _overlay: Control = null
var _corner_unit: PackedVector2Array = PackedVector2Array()
var _hex_uvs: PackedVector2Array = PackedVector2Array()
# Hex war: cards on the map, legal placement hexes, hover ghost and battle FX
var war: MapWar = null
var placeable: Dictionary = {} # "x,y" -> true while a hand card is selected
var ghost_card: String = "" # card name previewed under the cursor
var effects: Array = [] # transient {kind, from, to, t0, dur, ...}
# While an attack plays out, the war logic has already resolved every shot. These
# keep the screen at the pre-attack state until each shot lands:
var ghosts: Dictionary = {}       # "x,y" -> {name, owner, hp, max}: already destroyed, not yet hit on screen
var hp_shown: Dictionary = {}     # "x,y" -> HP to show instead of the card's real (already lowered) HP
var flag_hp_shown: Dictionary = {} # nation -> HP to show on its flag bar
var flag_site_shown: Dictionary = {} # nation -> hex its flag is shown on (it may already have moved)
var walks: Dictionary = {} # "x,y" -> {"path": [hexes, home first], "t0", "step", "back"}: visual-only march
var aim: Dictionary = {} # hover help: {"from": hex, "to": hex, "ranged": bool} -> targeting arrow
var _text_layer: Control = null # damage numbers: smooth filtering (the overlay is NEAREST for pixel sprites)
const GOLD := Color(1.0, 0.82, 0.3)
const CYAN := Color(0.45, 0.9, 1.0)
var _clock: float = 0.0
var _fx_clock: float = 0.0
var _unit_tex: Dictionary = {} # card name -> Array[Texture2D] (32px idle frames)
# drag-to-pan state
var _press_pos := Vector2.ZERO
var _pressed: bool = false
var _dragging: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tiles = TileArt.make_tile_set()
	_atlas = _build_atlas()
	_terrain = Control.new()
	_terrain.name = "Terrain"
	_terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_terrain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_terrain.show_behind_parent = true # under the grid, borders and flags drawn by the view
	_terrain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = TERRAIN_SHADER
	mat.shader = sh
	_terrain.material = mat
	_terrain.draw.connect(_draw_terrain)
	add_child(_terrain)
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
	_text_layer = Control.new()
	_text_layer.name = "TextFX"
	_text_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_text_layer.draw.connect(_draw_text_fx)
	add_child(_text_layer)
	resized.connect(_redraw_all)
	mouse_exited.connect(func():
		hovered = Vector2i(-1, -1)
		aim = {}
		_overlay.queue_redraw()
		hover_cleared.emit())

func _redraw_all() -> void:
	queue_redraw()
	if _terrain != null:
		_terrain.queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()

func set_campaign(campaign: MapCampaign) -> void:
	_campaign = campaign
	_owners = campaign.owner.duplicate()
	_nation_colors.clear()
	_dead.clear()
	_edges.clear()
	_edge_map.clear()
	_player_nation = campaign.player_nation
	for n in WorldMap.nations():
		var d := n as Dictionary
		var nm := str(d["name"])
		_nation_colors[nm] = Color.html(str(d["color"]))
		if not campaign.is_alive(nm):
			_dead[nm] = true
		else:
			_edges[nm] = campaign.border_edges(nm)
	# per-hex edge list so borders draw with their hex (works with wrap + culling)
	for nm in _edges.keys():
		var bc: Color = Color(1.0, 0.84, 0.2) if nm == _player_nation else _nation_colors[nm]
		for e in (_edges[nm] as Array):
			var entry := e as Array
			var t := entry[0] as Vector2i
			var k := MapCampaign.key_of(t.x, t.y)
			if not _edge_map.has(k):
				_edge_map[k] = []
			(_edge_map[k] as Array).append([int(entry[2]), bc])
	# The pulsing "you can attack here" front line only applies to the old card-battle wars.
	_front = _compute_front(campaign) if war == null else []
	_land_dirty = true
	_build_borders()
	_redraw_all()

func set_war(w: MapWar) -> void:
	war = w
	_front = []
	_overlay.queue_redraw()

func _compute_front(campaign: MapCampaign) -> Array:
	var out: Array = []
	if campaign.has_won() or campaign.has_lost():
		return out
	for key in _owners.keys():
		var o := str(_owners[key])
		if o == _player_nation or not campaign.can_attack(o):
			continue
		var t := MapWar.key_to_hex(str(key))
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
	_clock += delta
	if _sea_clock >= SEA_STEP_SEC:
		_sea_clock = 0.0
		_sea_phase = (_sea_phase + 1) % TileArt.VARIANTS
		if _terrain != null:
			_terrain.queue_redraw() # swapping to the next wave mesh is one draw call
	var busy := not effects.is_empty() or not placeable.is_empty() or not aim.is_empty() or (war != null and not war.units.is_empty())
	if (not _front.is_empty() or busy) and _pulse_clock >= 1.0 / PULSE_FPS:
		_pulse_clock = 0.0
		_overlay.queue_redraw()
	if not effects.is_empty() or not walks.is_empty():
		_fx_clock += delta
		if _fx_clock >= 1.0 / 40.0:
			_fx_clock = 0.0
			_overlay.queue_redraw()
			_text_layer.queue_redraw()
		var keep: Array = []
		for e in effects:
			if _clock < float(e["t0"]) + float(e["dur"]):
				keep.append(e)
		effects = keep
	for wk in walks.keys():
		var w: Dictionary = walks[wk]
		if bool(w["back"]) and _walk_progress(w) <= 0.0:
			walks.erase(wk)

func _variant_for(x: int, y: int) -> int:
	return absi(x * 73856093 ^ y * 19349663) % TileArt.VARIANTS

# ----------------------------------------------------------------- camera
# Hex size at zoom 1: the world fills the width (it wraps); a regional map fits entirely.
func _fit_size() -> float:
	var avail := size - Vector2(FRAME_PX, FRAME_PX) * 2.0
	if WorldMap.WRAPS:
		return maxf(avail.x / (WorldMap.GRID_W * SQRT3), 0.0)
	return maxf(minf(avail.x / ((WorldMap.GRID_W + 0.5) * SQRT3), avail.y / (1.5 * WorldMap.GRID_H + 0.5)), 0.0)

# Zoom level at which hexes are `px` pixels (centre to corner) on screen.
func zoom_for_hex_size(px: float) -> float:
	return clampf(px / maxf(_fit_size(), 0.001), ZOOM_MIN, ZOOM_MAX)

func _map_width(s: float) -> float:
	return (WorldMap.GRID_W + (0.0 if WorldMap.WRAPS else 0.5)) * SQRT3 * s

# [hex size (centre->corner), origin x, origin y, hex width, wrap period]
func metrics() -> Array:
	var s: float = _fit_size() * clampf(zoom, ZOOM_MIN, ZOOM_MAX)
	var w: float = SQRT3 * s
	var period: float = WorldMap.GRID_W * w
	var map_h: float = (1.5 * WorldMap.GRID_H + 0.5) * s
	var map_w: float = _map_width(s)
	var ox: float = floorf((size.x - map_w) * 0.5 + _pan.x)
	if not WorldMap.WRAPS:
		ox = floorf((size.x - map_w) * 0.5 + _pan.x) if _edge_free else (floorf((size.x - map_w) * 0.5) if map_w + FRAME_PX * 2.0 <= size.x
			else floorf(clampf((size.x - map_w) * 0.5 + _pan.x, size.x - map_w - FRAME_PX, FRAME_PX)))
	var oy: float
	if _edge_free:
		oy = floorf((size.y - map_h) * 0.5 + _pan.y) # _normalize_pan keeps it within reach
	elif map_h + FRAME_PX * 2.0 <= size.y:
		oy = floorf((size.y - map_h) * 0.5)
	else:
		oy = floorf(clampf((size.y - map_h) * 0.5 + _pan.y, size.y - map_h - FRAME_PX, FRAME_PX))
	return [s, ox, oy, w, period]

func hex_center(x: int, y: int, m: Array) -> Vector2:
	var s: float = m[0]
	var w: float = m[3]
	return Vector2(m[1] + (x + 0.5 * float(y & 1)) * w + w * 0.5, m[2] + y * 1.5 * s + s)

# Screen position of hex t using the wrapped copy nearest the view centre.
func screen_pos(t: Vector2i, m: Array) -> Vector2:
	var c := hex_center(t.x, t.y, m)
	if not WorldMap.WRAPS:
		return c
	var period: float = m[4]
	var mid: float = size.x * 0.5
	c.x = c.x + roundf((mid - c.x) / period) * period
	return c

# Every wrapped copy of hex t that is on screen (for units and flags).
func _visible_copies(t: Vector2i, m: Array, margin: float) -> Array:
	var out: Array = []
	var period: float = m[4]
	var c := hex_center(t.x, t.y, m)
	if not WorldMap.WRAPS:
		if c.x >= -margin and c.x <= size.x + margin and c.y >= -margin and c.y <= size.y + margin:
			out.append(c)
		return out
	var k0 := int(floor((-margin - c.x) / period))
	var k1 := int(ceil((size.x + margin - c.x) / period))
	for k in range(k0, k1 + 1):
		var p := Vector2(c.x + k * period, c.y)
		if p.x >= -margin and p.x <= size.x + margin and p.y >= -margin and p.y <= size.y + margin:
			out.append(p)
	return out

func zoom_by(factor: float, anchor: Vector2 = Vector2(-1, -1)) -> void:
	_edge_free = false
	if anchor.x < 0:
		anchor = size * 0.5
	var m := metrics()
	var old_s: float = m[0]
	var new_zoom := clampf(zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(new_zoom, zoom):
		return
	var new_s: float = _fit_size() * new_zoom
	# keep the map point under the anchor fixed: origin' = anchor - (anchor - origin) * s'/s
	var ratio: float = new_s / maxf(old_s, 0.001)
	var new_ox: float = anchor.x - (anchor.x - float(m[1])) * ratio
	var new_oy: float = anchor.y - (anchor.y - float(m[2])) * ratio
	zoom = new_zoom
	var new_map_w: float = _map_width(new_s)
	var new_map_h: float = (1.5 * WorldMap.GRID_H + 0.5) * new_s
	_pan.x = new_ox - (size.x - new_map_w) * 0.5
	_pan.y = new_oy - (size.y - new_map_h) * 0.5
	_normalize_pan()
	_redraw_all()

func pan_by(delta: Vector2) -> void:
	_edge_free = false
	_pan += delta
	_normalize_pan()
	_redraw_all()

func _normalize_pan() -> void:
	var s: float = _fit_size() * zoom
	var period: float = WorldMap.GRID_W * SQRT3 * s
	if WorldMap.WRAPS:
		if period > 0.0:
			_pan.x = fposmod(_pan.x + period * 0.5, period) - period * 0.5
	else:
		var slack_x: float = maxf(0.0, (_map_width(s) - size.x) * 0.5 + FRAME_PX)
		if _edge_free:
			slack_x = absf(_map_width(s) - size.x) * 0.5 + size.x * 0.5
		_pan.x = clampf(_pan.x, -slack_x, slack_x)
	var map_h: float = (1.5 * WorldMap.GRID_H + 0.5) * s
	var slack: float = maxf(0.0, (map_h - size.y) * 0.5 + FRAME_PX)
	if _edge_free:
		slack = absf(map_h - size.y) * 0.5 + size.y * 0.5 # far enough to centre any hex
	_pan.y = clampf(_pan.y, -slack, slack)

# Put hex t in the middle of the view (optionally at a new zoom).
func center_on(t: Vector2i, new_zoom: float = -1.0) -> void:
	_edge_free = false
	if new_zoom > 0.0:
		zoom = clampf(new_zoom, ZOOM_MIN, ZOOM_MAX)
	_pan = Vector2.ZERO
	var m := metrics()
	var c := hex_center(t.x, t.y, m)
	_pan = size * 0.5 - c
	_normalize_pan()
	_redraw_all()

# ------------------------------------------------------------ camera moves
# The camera as [centre in map units (hex size 1, see _unit_center), zoom].
func camera_state() -> Array:
	var m := metrics()
	var s: float = m[0]
	return [(size * 0.5 - Vector2(float(m[1]), float(m[2]))) / maxf(s, 0.001), zoom]

# The follow camera may look past the map's edges (into the deep-sea margin) so a
# fight by a pole or a regional map's border still sits in the middle; any camera
# move by the player (pan, zoom, Home, minimap) brings the normal limits back.
var _edge_free: bool = false

func set_camera(center: Vector2, new_zoom: float, free: bool = false) -> void:
	_edge_free = free
	zoom = clampf(new_zoom, ZOOM_MIN, ZOOM_MAX)
	_pan = Vector2.ZERO
	var m := metrics()
	var s: float = m[0]
	_pan = size * 0.5 - (Vector2(float(m[1]), float(m[2])) + center * s)
	_normalize_pan()
	_redraw_all()

# The camera that shows every hex in `hexes` as large as possible, with `pad`
# hexes of margin all round. On the wrapping world map each hex is taken in the
# copy nearest the first one, so a fight across the date line stays together.
# With `focus` (the hexes where the shooting lands), the camera is centred on the
# focus and zoomed out just enough to keep every hex of `hexes` in view around it.
func frame_for(hexes: Array, pad: float = 1.5, focus: Array = []) -> Array:
	if hexes.is_empty() and focus.is_empty():
		return camera_state()
	var period: float = WorldMap.GRID_W * SQRT3
	var first: Vector2i = focus[0] if not focus.is_empty() else hexes[0]
	var ref := _unit_center(first.x, first.y)
	var unwrap := func(h: Vector2i) -> Vector2:
		var c := _unit_center(h.x, h.y)
		if WorldMap.WRAPS:
			c.x += roundf((ref.x - c.x) / period) * period
		return c
	# the centre: middle of the focus (or of everything)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for h in (focus if not focus.is_empty() else hexes):
		var c: Vector2 = unwrap.call(h)
		lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.y))
		hi = Vector2(maxf(hi.x, c.x), maxf(hi.y, c.y))
	var center := (lo + hi) * 0.5
	# half-extents around that centre that cover every hex; a hex reaches sqrt3/2
	# sideways and 1 up/down from its centre, then the margin
	var half := Vector2.ZERO
	for h in hexes + focus:
		var c: Vector2 = unwrap.call(h)
		half = Vector2(maxf(half.x, absf(c.x - center.x)), maxf(half.y, absf(c.y - center.y)))
	half += Vector2(SQRT3 * 0.5 + pad * SQRT3, 1.0 + pad * 1.5)
	var avail := size - Vector2(FRAME_PX, FRAME_PX) * 2.0
	var s_fit: float = minf(avail.x / maxf(half.x * 2.0, 0.001), avail.y / maxf(half.y * 2.0, 0.001))
	if WorldMap.WRAPS:
		center.x = fposmod(center.x, period)
	return [center, s_fit / maxf(_fit_size(), 0.001)]

var _cam_tween: Tween = null
var _cam_goal: Array = []

# Where the camera is heading: the end of a glide still in progress, else where it is.
func camera_goal() -> Array:
	if _cam_tween != null and _cam_tween.is_valid() and _cam_tween.is_running() and not _cam_goal.is_empty():
		return _cam_goal
	return camera_state()

# Glide (pan + zoom together) to a camera from frame_for/camera_state. Returns the
# tween's finished signal so callers can await it (null tween => already there).
func glide_to(cam: Array, duration: float) -> Signal:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_goal = cam
	var from: Array = camera_state()
	var c0: Vector2 = from[0]
	var c1: Vector2 = cam[0]
	if WorldMap.WRAPS:  # take the short way round the globe
		var period: float = WorldMap.GRID_W * SQRT3
		c1.x += roundf((c0.x - c1.x) / period) * period
	var z0: float = clampf(float(from[1]), ZOOM_MIN, ZOOM_MAX)
	var z1: float = clampf(float(cam[1]), ZOOM_MIN, ZOOM_MAX)
	_cam_tween = create_tween()
	_cam_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_method(func(t: float):
		set_camera(c0.lerp(c1, t), z0 * pow(z1 / z0, t), true), 0.0, 1.0, maxf(duration, 0.01))
	return _cam_tween.finished

# Put a point of the map in the middle of the view: fx, fy are 0..1 across the
# whole map (the minimap hands these over). Keeps the zoom.
func center_on_fraction(fx: float, fy: float) -> void:
	_edge_free = false
	_pan = Vector2.ZERO
	var m := metrics()
	var s: float = m[0]
	var map_px := Vector2((WorldMap.GRID_W + 0.5) * SQRT3 * s, (1.5 * WorldMap.GRID_H + 0.5) * s)
	var c := Vector2(float(m[1]), float(m[2])) + Vector2(fx, fy) * map_px
	_pan = size * 0.5 - c
	_normalize_pan()
	_redraw_all()

# ------------------------------------------------------------- picking
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
	if WorldMap.WRAPS:
		col = posmod(col, WorldMap.GRID_W) # east-west wrap
	if not WorldMap.in_bounds(col, row):
		return Vector2i(-1, -1)
	return Vector2i(col, row)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1.15, mb.position)
			accept_event()
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.0 / 1.15, mb.position)
			accept_event()
			return
		if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				_pressed = true
				_dragging = mb.button_index != MOUSE_BUTTON_LEFT # right/middle always pan
				_press_pos = mb.position
			else:
				var was_click := _pressed and not _dragging and mb.button_index == MOUSE_BUTTON_LEFT
				_pressed = false
				_dragging = false
				if was_click:
					var t := tile_at_point(mb.position)
					if t.x >= 0:
						select_tile(t)
			return
	if event is InputEventMagnifyGesture:
		zoom_by((event as InputEventMagnifyGesture).factor, (event as InputEventMagnifyGesture).position)
		return
	if event is InputEventPanGesture:
		pan_by(-(event as InputEventPanGesture).delta * 12.0)
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _pressed:
			if not _dragging and mm.position.distance_to(_press_pos) > DRAG_THRESHOLD:
				_dragging = true
			if _dragging:
				pan_by(mm.relative)
				hover_cleared.emit()
				return
		var h := tile_at_point(mm.position)
		if h != hovered:
			hovered = h
			_overlay.queue_redraw()
			if h.x >= 0:
				tile_hovered.emit(h.x, h.y)
			else:
				hover_cleared.emit()
		return
	if event is InputEventScreenDrag:
		pan_by((event as InputEventScreenDrag).relative)
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		var t2 := tile_at_point((event as InputEventScreenTouch).position)
		if t2.x >= 0:
			select_tile(t2)

func select_tile(t: Vector2i, emit: bool = true) -> void:
	selected = t
	_redraw_all() # selected nation tint lives on the base layer
	if emit:
		tile_selected.emit(t.x, t.y)

# ---------------------------------------------------------------- base layer
func _draw_hex_tex(ci: CanvasItem, c: Vector2, s: float, tex: Texture2D, tint: Color = Color.WHITE) -> void:
	ci.draw_polygon(_hex_points(c, s), PackedColorArray([tint]), _hex_uvs, tex)

func _visible_range(m: Array) -> Array:
	var s: float = m[0]
	var w: float = m[3]
	var ox: float = m[1]
	var oy: float = m[2]
	var x0 := int(floor((-ox) / w)) - 2
	var x1 := int(ceil((size.x - ox) / w)) + 1
	var y0 := int(floor((-oy - s) / (1.5 * s))) - 1
	var y1 := int(ceil((size.y - oy) / (1.5 * s))) + 1
	return [x0, x1, y0, y1]

func _draw() -> void:
	var m := metrics()
	var s: float = m[0]
	if s < 2.0:
		return
	var oy: float = m[2]
	var map_h: float = (1.5 * WorldMap.GRID_H + 0.5) * s
	# hex grid (1px hairlines) and nation borders, from precomputed map-unit segments
	var bw: float = maxf(2.0, floorf(s * 0.22))
	for ox in _copy_origins(m):
		draw_set_transform(Vector2(ox, m[2]), 0.0, Vector2(s, s))
		if not _grid_pts.is_empty():
			draw_multiline(_grid_pts, Color(0, 0, 0, 0.22), -1.0)
		for seg in _border_segs:
			draw_multiline(seg[1], Color(0.05, 0.04, 0.08, 0.85), (bw + 2.0) / s)
		for seg in _border_segs:
			draw_multiline(seg[1], seg[0], bw / s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Pixel bezel: polar edges (the world wraps sideways); all four sides on regional maps
	if WorldMap.WRAPS:
		for edge_y in [oy - FRAME_PX, oy + map_h]:
			if edge_y + FRAME_PX >= 0.0 and edge_y <= size.y:
				draw_rect(Rect2(0, edge_y, size.x, FRAME_PX), Color8(20, 16, 30), true)
				draw_rect(Rect2(0, edge_y + 2.0, size.x, 2.0), Color8(94, 104, 128), true)
	else:
		var fr := Rect2(m[1], oy, _map_width(s), map_h).grow(FRAME_PX * 0.5)
		draw_rect(fr, Color8(20, 16, 30), false, FRAME_PX)
		draw_rect(fr.grow(-2.0), Color8(94, 104, 128), false, 2.0)
	# Capitals: pixel flag on a pole, planted on the capital hex
	for n in WorldMap.nations():
		var d := n as Dictionary
		var nm := str(d["name"])
		var site := Vector2i(int(d["x"]), int(d["y"]))
		if _campaign != null:
			site = flag_site_shown.get(nm, _campaign.capital_site(nm))
		var fs: float = maxf(s * 2.6, 16.0)
		for cc in _visible_copies(site, m, fs):
			var base := (cc as Vector2) + Vector2(0, s * 0.55)
			draw_rect(Rect2(base + Vector2(-fs * 0.2, -2.0), Vector2(fs * 0.4, 3.0)), Color(0, 0, 0, 0.45), true)
			if _dead.has(nm):
				var xc := base - Vector2(0, s * 0.6)
				var r: float = s * 0.45
				draw_line(xc - Vector2(r, r), xc + Vector2(r, r), Color(0.8, 0.8, 0.85), 2.0)
				draw_line(xc + Vector2(-r, r), xc + Vector2(r, -r), Color(0.8, 0.8, 0.85), 2.0)
				continue
			if _flags.has(nm):
				# flag art has its pole at ~x=0.12 of the texture; plant that on the hex centre
				draw_texture_rect(_flags[nm] as Texture2D, Rect2(base - Vector2(fs * 0.12, fs * 0.9), Vector2(fs, fs)), false)
			if nm == _player_nation:
				_draw_star(self, base + Vector2(0, -fs * 0.98), maxf(s * 0.5, 4.0), Color(1.0, 0.86, 0.3))

# Map-unit centre of hex (x, y) (hex size 1, origin at the map's top-left).
static func _unit_center(x: int, y: int) -> Vector2:
	return Vector2((float(x) + 0.5 * float(y & 1)) * SQRT3 + SQRT3 * 0.5, float(y) * 1.5 + 1.0)

# Screen x of every wrapped copy of the map that touches the view.
func _copy_origins(m: Array) -> Array:
	var ox: float = m[1]
	if not WorldMap.WRAPS:
		return [ox]
	var period: float = m[4]
	var out: Array = []
	var k0 := int(floor(-(ox + period) / period))
	var k1 := int(ceil((size.x - ox) / period))
	for k in range(k0, k1 + 1):
		var x0: float = ox + k * period
		if x0 < size.x and x0 + period > 0.0:
			out.append(x0)
	return out

func _draw_terrain() -> void:
	var m := metrics()
	var s: float = m[0]
	if s < 2.0 or _atlas == null:
		return
	if _sea_map_id != WorldMap.MAP_ID or _sea_meshes.is_empty():
		_build_sea()
	var sel_owner: String = ""
	if selected.x >= 0:
		sel_owner = str(_owners.get(MapCampaign.key_of(selected.x, selected.y), ""))
	if _land_dirty or _land_mesh == null or sel_owner != _land_sel_owner:
		_build_land(sel_owner)
	for ox in _copy_origins(m):
		_terrain.draw_set_transform(Vector2(ox, m[2]), 0.0, Vector2(s, s))
		_terrain.draw_mesh(_sea_meshes[_sea_phase % _sea_meshes.size()], _atlas)
		_terrain.draw_mesh(_land_mesh, _atlas)
	_terrain.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# All terrain tiles in one texture: a row per terrain, a column per variant.
func _build_atlas() -> ImageTexture:
	var cell: int = TileArt.SIZE
	var img := Image.create(cell * TileArt.VARIANTS, cell * TileArt.TERRAINS.size(), false, Image.FORMAT_RGBA8)
	for ti in range(TileArt.TERRAINS.size()):
		var variants: Array = _tiles.get(TileArt.TERRAINS[ti], [])
		for v in range(variants.size()):
			var src: Image = (variants[v] as Texture2D).get_image()
			if src.is_compressed():
				src.decompress()
			src.convert(Image.FORMAT_RGBA8)
			img.blit_rect(src, Rect2i(0, 0, cell, cell), Vector2i(v * cell, ti * cell))
	return ImageTexture.create_from_image(img)

# Append one textured hex (7 vertices, 6 triangles) to the mesh arrays.
func _add_hex(arr: Array, c: Vector2, terrain_idx: int, variant: int, tint: Color) -> void:
	var verts: PackedVector2Array = arr[0]
	var uvs: PackedVector2Array = arr[1]
	var cols: PackedColorArray = arr[2]
	var idx: PackedInt32Array = arr[3]
	var cell: float = float(TileArt.SIZE)
	var aw: float = cell * TileArt.VARIANTS
	var ah: float = cell * TileArt.TERRAINS.size()
	var base := Vector2(variant * cell, terrain_idx * cell)
	var first := verts.size()
	verts.append(c)
	uvs.append((base + Vector2(cell, cell) * 0.5) / Vector2(aw, ah))
	cols.append(tint)
	for k in range(6):
		verts.append(c + _corner_unit[k] * HEX_OVERDRAW)
		# half-texel inset keeps NEAREST sampling inside this tile's cell
		uvs.append((base + Vector2(0.5, 0.5) + _hex_uvs[k] * (cell - 1.0)) / Vector2(aw, ah))
		cols.append(tint)
	for k in range(6):
		idx.append(first)
		idx.append(first + 1 + k)
		idx.append(first + 1 + (k + 1) % 6)

func _mesh_from(arr: Array) -> ArrayMesh:
	var data := []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = arr[0]
	data[Mesh.ARRAY_TEX_UV] = arr[1]
	data[Mesh.ARRAY_COLOR] = arr[2]
	data[Mesh.ARRAY_INDEX] = arr[3]
	var mesh := ArrayMesh.new()
	if (arr[0] as PackedVector2Array).size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return mesh

func _new_arrays() -> Array:
	return [PackedVector2Array(), PackedVector2Array(), PackedColorArray(), PackedInt32Array()]

# Ocean hexes plus a deep-sea margin around the map, once per wave phase; also the
# hex grid lines (the map's shape never changes during a campaign).
func _build_sea() -> void:
	_sea_map_id = WorldMap.MAP_ID
	_sea_meshes.clear()
	var ocean_i: int = TileArt.TERRAINS.find("ocean")
	var W: int = WorldMap.GRID_W
	var H: int = WorldMap.GRID_H
	var pad_x: int = 0 if WorldMap.WRAPS else 20
	var pad_y: int = 14 if WorldMap.WRAPS else 20
	var clear := Color(0, 0, 0, 0)
	for phase in range(TileArt.VARIANTS):
		var arr := _new_arrays()
		for y in range(-pad_y, H + pad_y):
			for x in range(-pad_x, W + pad_x):
				var inside: bool = y >= 0 and y < H and x >= 0 and x < W
				if inside and WorldMap.terrain_at(x, y) != "ocean":
					continue
				if inside:
					_add_hex(arr, _unit_center(x, y), ocean_i, (_variant_for(x, y) + phase) % TileArt.VARIANTS,
						VOID_SEA_TINT if WorldMap.is_void(x, y) else clear)
				else:
					_add_hex(arr, _unit_center(x, y), ocean_i, posmod(x + y + phase, TileArt.VARIANTS), DEEP_SEA_TINT)
		_sea_meshes.append(_mesh_from(arr))
	# grid: each hex contributes its three upper edges once; the bottom row closes the rest
	_grid_pts = PackedVector2Array()
	for y in range(H):
		for x in range(W):
			var c := _unit_center(x, y)
			var ks: Array = [3, 4, 5] if y < H - 1 else [0, 1, 2, 3, 4, 5]
			if x == W - 1 and not WorldMap.WRAPS:
				ks.append(0)
			for k in ks:
				_grid_pts.append(c + _corner_unit[k])
				_grid_pts.append(c + _corner_unit[(k + 1) % 6])

# Land hexes, tinted by owner (stronger for the selected nation).
func _build_land(sel_owner: String) -> void:
	_land_dirty = false
	_land_sel_owner = sel_owner
	var arr := _new_arrays()
	for y in range(WorldMap.GRID_H):
		for x in range(WorldMap.GRID_W):
			var terrain := WorldMap.terrain_at(x, y)
			if terrain == "ocean":
				continue
			var ti: int = TileArt.TERRAINS.find(terrain)
			var tint := Color(0, 0, 0, 0)
			var o: String = str(_owners.get(MapCampaign.key_of(x, y), ""))
			if WorldMap.is_void(x, y):
				tint = VOID_LAND_TINT
			elif o != "" and _nation_colors.has(o):
				var nc := _nation_colors[o] as Color
				tint = Color(nc.r, nc.g, nc.b, 0.46 if o == sel_owner else 0.30)
			_add_hex(arr, _unit_center(x, y), maxi(ti, 0), _variant_for(x, y), tint)
	_land_mesh = _mesh_from(arr)

# Border segments per nation colour, inset so both sides of a shared edge show.
func _build_borders() -> void:
	var groups: Dictionary = {}
	for key in _edge_map.keys():
		var t := MapWar.key_to_hex(str(key))
		var c := _unit_center(t.x, t.y)
		for ed in (_edge_map[key] as Array):
			var k: int = int(ed[0])
			var col: Color = ed[1]
			if not groups.has(col):
				groups[col] = PackedVector2Array()
			var pts: PackedVector2Array = groups[col]
			pts.append(c + _corner_unit[k] * 0.89)
			pts.append(c + _corner_unit[(k + 1) % 6] * 0.89)
			groups[col] = pts
	_border_segs.clear()
	for col in groups.keys():
		_border_segs.append([col, groups[col]])

# ------------------------------------------------------------ units + FX
# 32px pixel-exact idle frames made once per card (512px art / 16).
func unit_frames(card_name: String, nation: String = "") -> Array:
	var cache_key := card_name + "|" + nation
	if _unit_tex.has(cache_key):
		return _unit_tex[cache_key]
	var out: Array = []
	for i in UNIT_FRAMES:
		var path := Card.idle_frame_path(card_name, i, nation) # each nation's own art
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var img := tex.get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		img.resize(32, 32, Image.INTERPOLATE_NEAREST)
		out.append(ImageTexture.create_from_image(img))
	_unit_tex[cache_key] = out
	return out

func _draw_card(card_name: String, c: Vector2, s: float, tint: Color = Color.WHITE, frame_offset: int = 0, nation: String = "") -> void:
	var frames := unit_frames(card_name, nation)
	if frames.is_empty():
		return
	var tex: Texture2D = frames[(int(_clock * 4.0) + frame_offset) % frames.size()]
	var side: float = s * 2.1
	_overlay.draw_texture_rect(tex, Rect2(c - Vector2(side * 0.5, side * 0.62), Vector2(side, side)), false, tint)

func add_shot(from: Vector2i, to: Vector2i, sfx_kind: String, travel: float) -> void:
	effects.append({"kind": "shot", "from": from, "to": to, "t0": _clock, "dur": travel, "color": SHOT_COLORS.get(sfx_kind, Color.WHITE)})

func add_boom(at: Vector2i, big: bool, delay: float) -> void:
	effects.append({"kind": "boom", "to": at, "t0": _clock + delay, "dur": 0.55 if big else 0.3, "big": big})

func add_number(at: Vector2i, text: String, col: Color, delay: float) -> void:
	effects.append({"kind": "num", "to": at, "t0": _clock + delay, "dur": 0.9, "text": text, "color": col})

func add_wreck(at: Vector2i, card_name: String, owner: String, until_delay: float) -> void:
	effects.append({"kind": "wreck", "to": at, "t0": _clock, "dur": until_delay, "name": card_name, "owner": owner})

# Barracks buff firing: golden burst + rising chevrons at the attacker.
func add_buff(at: Vector2i) -> void:
	effects.append({"kind": "buff", "to": at, "t0": _clock, "dur": 0.6})

# Interception: a counter-missile from the Interceptor meets the shot, then a
# hexagonal shield flashes over the protected card.
func add_intercept(interceptor: Vector2i, target: Vector2i, impact_delay: float) -> void:
	if interceptor.x >= 0:
		effects.append({"kind": "counter", "from": interceptor, "to": target, "t0": _clock + impact_delay * 0.3, "dur": impact_delay * 0.7})
	effects.append({"kind": "shield", "to": target, "t0": _clock + impact_delay, "dur": 0.7})

# Visual only: the card at key `k` marches hex by hex along `path` (home first),
# `step` seconds per hex, and waits at the end until walk_back(). It never moves on the board.
func walk_out(k: String, path: Array, step: float) -> void:
	walks[k] = {"path": path, "t0": _clock, "step": maxf(step, 0.001), "back": false}

# A real move (MapWar.move): the card already stands on the path's last hex; show it
# walking there from the first one, `step` seconds per hex.
func animate_move(path: Array, step: float) -> void:
	if path.size() < 2:
		return
	var dest: Vector2i = path[path.size() - 1]
	var rev: Array = path.duplicate()
	rev.reverse()
	walks[MapCampaign.key_of(dest.x, dest.y)] = {"path": rev, "t0": _clock, "step": maxf(step, 0.001), "back": true}
	_overlay.queue_redraw()

func walk_back(k: String) -> void:
	if walks.has(k):
		walks[k]["back"] = true
		walks[k]["t0"] = _clock

func clear_walks() -> void:
	walks.clear()

# How many path steps the walker has covered right now (0 = at home).
func _walk_progress(w: Dictionary) -> float:
	var n: float = float((w["path"] as Array).size() - 1)
	var steps: float = (_clock - float(w["t0"])) / float(w["step"])
	return clampf(n - steps, 0.0, n) if bool(w["back"]) else clampf(steps, 0.0, n)

# Current pixel offset of a marching card from its home hex (zero at rest).
func unit_offset(k: String, m: Array) -> Vector2:
	var w: Dictionary = walks.get(k, {})
	if w.is_empty():
		return Vector2.ZERO
	var path: Array = w["path"]
	var pos: float = _walk_progress(w)
	var i: int = mini(int(pos), path.size() - 2)
	var f: float = pos - float(i)
	# screen points along the path, unwrapped across the east-west seam
	var home := screen_pos(path[0] as Vector2i, m)
	var prev := home
	var a := home
	var b := home
	for j in range(1, i + 2):
		var nxt := _wrap_target(prev, screen_pos(path[j] as Vector2i, m), m)
		if j == i:
			a = nxt
		if j == i + 1:
			b = nxt
		prev = nxt
	if i == 0:
		a = home
	var s: float = m[0]
	var hop: float
	if at_sea(k):
		hop = sin(_clock * 9.0) * s * 0.05 # a boat bobs instead of hopping
	else:
		hop = absf(sin(f * PI)) * s * 0.18 if pos > 0.0 and pos < float(path.size() - 1) else 0.0
	return a.lerp(b, f) - home - Vector2(0, hop)

# True while a marching ground card is on a sea hex (it rides a boat there).
func at_sea(k: String) -> bool:
	var w: Dictionary = walks.get(k, {})
	if w.is_empty() or war == null or not war.units.has(k):
		return false
	var card: Card = war.units[k]["card"]
	if card is Unit and (card as Unit).Flying:
		return false
	var path: Array = w["path"]
	var t: Vector2i = path[clampi(roundi(_walk_progress(w)), 0, path.size() - 1)]
	return not WorldMap.is_land(t.x, t.y)

# +1 when the marching card heads east on screen, -1 west.
func _walk_facing(k: String, m: Array) -> float:
	var w: Dictionary = walks.get(k, {})
	if w.is_empty():
		return 1.0
	var path: Array = w["path"]
	var a := screen_pos(path[0] as Vector2i, m)
	var b := _wrap_target(a, screen_pos(path[path.size() - 1] as Vector2i, m), m)
	var dx: float = (b.x - a.x) * (-1.0 if bool(w["back"]) else 1.0)
	return -1.0 if dx < 0.0 else 1.0

# Pixel boat under a card crossing the sea: wake behind, then the hull drawn over
# the sprite's feet so the unit stands inside it. Bow points along `facing`.
func _draw_boat_wake(c: Vector2, s: float, facing: float) -> void:
	var foam := Color(0.85, 0.95, 1.0, 0.75)
	for i in range(3):
		var wx: float = -facing * s * (1.15 + i * 0.32)
		var ph: float = fmod(_clock * 3.0 + i * 0.33, 1.0)
		_overlay.draw_line(c + Vector2(wx, s * (0.6 - 0.12 * i)), c + Vector2(wx - facing * s * 0.25, s * (0.66 - 0.08 * i)), Color(foam.r, foam.g, foam.b, foam.a * (1.0 - ph * 0.6)), maxf(1.5, s * 0.08))
	_overlay.draw_line(c + Vector2(-s * 1.0, s * 0.7), c + Vector2(s * 1.0, s * 0.7), Color(foam.r, foam.g, foam.b, 0.35), maxf(1.5, s * 0.09))

func _draw_boat_hull(c: Vector2, s: float, nc: Color, facing: float) -> void:
	var pts := PackedVector2Array()
	for p in [Vector2(-0.98, 0.24), Vector2(1.35, 0.0), Vector2(0.66, 0.68), Vector2(-0.88, 0.68)]:
		pts.append(c + Vector2(p.x * facing, p.y) * s)
	var outline := pts.duplicate()
	outline.append(pts[0])
	_overlay.draw_colored_polygon(pts, Color(0.46, 0.28, 0.15))
	# nation-coloured stripe under the gunwale, then plank lines
	var stripe := PackedVector2Array([pts[0], pts[1], pts[1].lerp(pts[2], 0.32), pts[0].lerp(pts[3], 0.32)])
	_overlay.draw_colored_polygon(stripe, nc)
	_overlay.draw_line(pts[0].lerp(pts[3], 0.66), pts[1].lerp(pts[2], 0.66), Color(0.3, 0.17, 0.09), maxf(1.0, s * 0.06))
	_overlay.draw_polyline(outline, Color(0.08, 0.05, 0.1), maxf(1.5, s * 0.09))
	_overlay.draw_line(pts[0], pts[1], Color(0.8, 0.6, 0.38), maxf(1.0, s * 0.06))

func add_place(at: Vector2i) -> void:
	effects.append({"kind": "place", "to": at, "t0": _clock, "dur": 0.45})

func _wrap_target(a: Vector2, b: Vector2, m: Array) -> Vector2:
	# shoot across the east-west seam the short way
	if not WorldMap.WRAPS:
		return b
	var period: float = m[4]
	b.x = b.x + roundf((a.x - b.x) / period) * period
	return b

func _hex_poly(c: Vector2, r: float) -> PackedVector2Array:
	var pts := _hex_points(c, r)
	pts.append(pts[0])
	return pts

# Glowing line helper: wide faint stroke under a thin bright one.
func _glow_polyline(pts: PackedVector2Array, col: Color, width: float) -> void:
	_overlay.draw_polyline(pts, Color(col.r, col.g, col.b, col.a * 0.25), width * 3.0)
	_overlay.draw_polyline(pts, col, width)

# Barracks: golden hex ripples washing over the ring of hexes it buffs.
func _draw_barracks_ripples(m: Array) -> void:
	var s: float = m[0]
	for k in war.units.keys():
		if not (war.units[k]["card"] is Barracks):
			continue
		var t := MapWar.key_to_hex(str(k))
		for cp in _visible_copies(t, m, s * 3.0):
			for wave_i in range(2):
				var ph: float = fposmod(_clock * 0.45 + wave_i * 0.5 + float(t.x * 7 + t.y) * 0.013, 1.0)
				var a: float = (1.0 - ph) * 0.6 * minf(ph * 6.0, 1.0)
				_glow_polyline(_hex_poly(cp as Vector2, s * (0.9 + ph * 1.35)), Color(GOLD.r, GOLD.g, GOLD.b, a), 2.0)

# Buffed unit: warm glow + rotating dashed gold ring at its feet, bobbing double chevron.
func _draw_buff_aura(c: Vector2, s: float, seed_i: int) -> void:
	var base := c + Vector2(0, s * 0.45)
	var pulse: float = 0.5 + 0.5 * sin(_clock * 3.0 + seed_i)
	_overlay.draw_set_transform(base, 0.0, Vector2(1.0, 0.45))
	_overlay.draw_circle(Vector2.ZERO, s * 1.05, Color(GOLD.r, GOLD.g, GOLD.b, 0.12 + 0.1 * pulse))
	var rot: float = _clock * 1.6 + seed_i
	for i in range(6):
		var a0: float = rot + i * TAU / 6.0
		_overlay.draw_arc(Vector2.ZERO, s * 0.92, a0, a0 + TAU / 11.0, 8, Color(GOLD.r, GOLD.g, GOLD.b, 0.35), maxf(6.0, s * 0.3))
		_overlay.draw_arc(Vector2.ZERO, s * 0.92, a0, a0 + TAU / 11.0, 8, Color(1, 0.93, 0.6), maxf(2.5, s * 0.12))
	_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var bob: float = sin(_clock * 3.0 + seed_i) * s * 0.08
	var p := c + Vector2(s * 0.8, -s * 0.85 + bob)
	var w: float = s * 0.3
	for j in range(2):
		var y: float = p.y + j * s * 0.26
		var chev := PackedVector2Array([Vector2(p.x - w, y + w * 0.75), Vector2(p.x, y), Vector2(p.x + w, y + w * 0.75)])
		_overlay.draw_polyline(chev, Color8(20, 16, 30), maxf(5.0, s * 0.24))
		_overlay.draw_polyline(chev, Color(1, 0.93, 0.55).lerp(GOLD, 0.5 * j), maxf(2.5, s * 0.12))

# Shielded unit: faint cyan hex bubble with a bright glint running round its edge.
func _draw_shield_aura(c: Vector2, s: float, seed_i: int) -> void:
	var r: float = s * 0.95
	var pts := _hex_points(c, r)
	_overlay.draw_colored_polygon(pts, Color(CYAN.r, CYAN.g, CYAN.b, 0.07))
	var shimmer: float = 0.35 + 0.15 * sin(_clock * 2.5 + seed_i)
	_glow_polyline(_hex_poly(c, r), Color(CYAN.r, CYAN.g, CYAN.b, shimmer), 1.5)
	var u: float = fposmod(_clock * 0.55 + seed_i * 0.17, 1.0) * 6.0
	var e := int(u)
	var f: float = u - e
	var a := pts[e]
	var b := pts[(e + 1) % 6]
	var head := a.lerp(b, f)
	var tail := a.lerp(b, maxf(0.0, f - 0.45))
	_overlay.draw_line(tail, head, Color(1, 1, 1, 0.9), 2.5)
	_overlay.draw_circle(head, maxf(1.5, s * 0.07), Color(0.85, 1, 1, 0.95))

func _draw_units(m: Array) -> void:
	var s: float = m[0]
	var margin: float = s * 2.0
	_draw_barracks_ripples(m)
	for k in war.units.keys():
		var info: Dictionary = war.units[k]
		var t := MapWar.key_to_hex(str(k))
		var owner := str(info["owner"])
		var nc: Color = _nation_colors.get(owner, Color.WHITE)
		var card: Card = info["card"]
		var hp: int = int(hp_shown.get(k, war.card_hp(card)))
		var mx: int = int(card.get_meta("map_max_hp", maxi(hp, 1)))
		var frac: float = clampf(float(hp) / float(maxi(mx, 1)), 0.0, 1.0)
		var buffed: bool = war.is_buffed(str(k))
		var shielded: bool = war.is_shielded(str(k)) and not (card is Interceptor)
		var seed_i: int = t.x * 13 + t.y * 7
		var shift := unit_offset(str(k), m)
		var sea := at_sea(str(k))
		var facing := _walk_facing(str(k), m) if sea else 1.0
		for cp in _visible_copies(t, m, margin):
			var c := (cp as Vector2) + shift
			if sea:
				_draw_boat_wake(c, s, facing)
			else:
				# owner base: flat ellipse in nation colour under the sprite
				_overlay.draw_set_transform(c + Vector2(0, s * 0.45), 0.0, Vector2(1.0, 0.45))
				_overlay.draw_circle(Vector2.ZERO, s * 0.72, Color(0.05, 0.04, 0.08, 0.85))
				_overlay.draw_circle(Vector2.ZERO, s * 0.6, nc)
				_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if buffed:
				_draw_buff_aura(c, s, seed_i)
			_draw_card(card.card_name, c, s, Color.WHITE, t.x + t.y, owner)
			if sea:
				_draw_boat_hull(c, s, nc, facing)
			if shielded:
				_draw_shield_aura(c, s, seed_i)
			# HP bar under the unit
			var bwid: float = s * 1.3
			var r := Rect2(c + Vector2(-bwid * 0.5, s * 0.72), Vector2(bwid, maxf(2.0, s * 0.16)))
			_overlay.draw_rect(r.grow(1.0), Color(0.05, 0.04, 0.08, 0.9), true)
			_overlay.draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), Color(1.0 - frac, 0.35 + 0.6 * frac, 0.25), true)
	# cards the logic already destroyed, standing until the shot that kills them
	for gk in ghosts.keys():
		var gd: Dictionary = ghosts[gk]
		var gt := MapWar.key_to_hex(str(gk))
		var gnc: Color = _nation_colors.get(str(gd["owner"]), Color.WHITE)
		var gfrac: float = clampf(float(gd["hp"]) / float(maxi(int(gd["max"]), 1)), 0.0, 1.0)
		for cp in _visible_copies(gt, m, margin):
			var gc := cp as Vector2
			_overlay.draw_set_transform(gc + Vector2(0, s * 0.45), 0.0, Vector2(1.0, 0.45))
			_overlay.draw_circle(Vector2.ZERO, s * 0.72, Color(0.05, 0.04, 0.08, 0.85))
			_overlay.draw_circle(Vector2.ZERO, s * 0.6, gnc)
			_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_draw_card(str(gd["name"]), gc, s, Color.WHITE, gt.x + gt.y, str(gd["owner"]))
			var gw: float = s * 1.3
			var gr := Rect2(gc + Vector2(-gw * 0.5, s * 0.72), Vector2(gw, maxf(2.0, s * 0.16)))
			_overlay.draw_rect(gr.grow(1.0), Color(0.05, 0.04, 0.08, 0.9), true)
			_overlay.draw_rect(Rect2(gr.position, Vector2(gr.size.x * gfrac, gr.size.y)), Color(1.0 - gfrac, 0.35 + 0.6 * gfrac, 0.25), true)

# Show the board as it was before an attack that the logic has already resolved.
func begin_replay(snapshot: Dictionary, dead_keys: Array, flag_hp: Dictionary, flag_sites: Dictionary = {}) -> void:
	flag_site_shown = flag_sites.duplicate()
	hp_shown.clear()
	ghosts.clear()
	for k in snapshot.keys():
		hp_shown[k] = int(snapshot[k]["hp"])
	for k in dead_keys:
		if snapshot.has(k):
			ghosts[k] = (snapshot[k] as Dictionary).duplicate()
	flag_hp_shown = flag_hp.duplicate()
	_overlay.queue_redraw()

# A replayed shot landed on hex `to` (a card or a flag) for `dmg`.
func replay_hit(to: Vector2i, dmg: int, flag_owner: String = "") -> void:
	var k := MapCampaign.key_of(to.x, to.y)
	if flag_owner != "":
		if flag_hp_shown.has(flag_owner):
			flag_hp_shown[flag_owner] = maxi(0, int(flag_hp_shown[flag_owner]) - dmg)
	elif hp_shown.has(k):
		hp_shown[k] = maxi(0, int(hp_shown[k]) - dmg)
		if ghosts.has(k):
			ghosts[k]["hp"] = hp_shown[k]
	_overlay.queue_redraw()

# The replay's killing shot launched: from here the wreck effect shows the card.
func replay_remove(k: String) -> void:
	ghosts.erase(k)

# A nation collapsed on this replayed shot: its flag re-forms at full HP on its new
# hex and the cards it lost with its land go.
func replay_collapse(ev: Dictionary) -> void:
	var loser := str(ev["loser"])
	if bool(ev.get("eliminated", false)):
		flag_site_shown.erase(loser)
	elif (ev["flag"] as Vector2i).x >= 0:
		flag_site_shown[loser] = ev["flag"]
		add_place(ev["flag"])
	flag_hp_shown[loser] = int(ev.get("max_hp", flag_hp_shown.get(loser, 0)))
	for k in ev.get("lost", []):
		if ghosts.has(k):
			add_boom(MapWar.key_to_hex(str(k)), false, 0.0)
			ghosts.erase(k)
	_redraw_all()

func end_replay() -> void:
	ghosts.clear()
	hp_shown.clear()
	flag_hp_shown.clear()
	flag_site_shown.clear()
	_redraw_all()

# Capital flags are targets: show each living nation's HP under its flag.
func _draw_flag_hp(m: Array) -> void:
	var s: float = m[0]
	for nm in war.players.keys():
		if _dead.has(nm) or _campaign == null or not _campaign.is_alive(str(nm)):
			continue
		var p: Player = war.players[nm]
		var fhp: int = int(flag_hp_shown.get(nm, p.HitPoints))
		var frac: float = clampf(float(fhp) / float(maxi(p.MaxHitPoints, 1)), 0.0, 1.0)
		var nc: Color = _nation_colors.get(nm, Color.WHITE)
		for cp in _visible_copies(flag_site_shown.get(nm, _campaign.capital_site(str(nm))), m, s * 3.0):
			var bw: float = s * 2.0
			var r := Rect2((cp as Vector2) + Vector2(-bw * 0.5, s * 1.0), Vector2(bw, maxf(3.0, s * 0.2)))
			_overlay.draw_rect(r.grow(1.5), Color8(20, 16, 30), true)
			_overlay.draw_rect(r.grow(0.5), Color(1.0, 0.86, 0.35), false, 1.0)
			_overlay.draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), nc.lightened(0.15), true)

func _draw_effects(m: Array) -> void:
	var s: float = m[0]
	for e in effects:
		var age: float = _clock - float(e["t0"])
		if age < 0.0:
			continue
		var k: float = clampf(age / float(e["dur"]), 0.0, 1.0)
		var to_c := screen_pos(e["to"] as Vector2i, m)
		match str(e["kind"]):
			"shot":
				var fh := e["from"] as Vector2i
				var a := screen_pos(fh, m) + unit_offset(MapCampaign.key_of(fh.x, fh.y), m) - Vector2(0, s * 0.3)
				var b := _wrap_target(a, to_c, m)
				var col: Color = e["color"]
				var head := a.lerp(b, k)
				var tail := a.lerp(b, maxf(0.0, k - 0.25))
				_overlay.draw_line(tail, head, Color(col.r, col.g, col.b, 0.55), maxf(1.5, s * 0.12))
				_overlay.draw_circle(head, maxf(1.5, s * 0.16), col)
			"boom":
				var big: bool = e["big"]
				var rad: float = s * (0.4 + k * (1.6 if big else 0.9))
				var alpha: float = 1.0 - k
				_overlay.draw_circle(to_c, rad, Color(1.0, 0.55, 0.15, 0.55 * alpha))
				_overlay.draw_circle(to_c, rad * 0.6, Color(1.0, 0.92, 0.5, 0.8 * alpha))
				_overlay.draw_arc(to_c, rad * 1.1, 0.0, TAU, 18, Color(1, 1, 1, 0.6 * alpha), 1.5)
			"buff":
				var ease_k: float = 1.0 - pow(1.0 - k, 3.0)
				var fade: float = 1.0 - k
				_overlay.draw_circle(to_c, s * (0.5 + ease_k * 0.9), Color(GOLD.r, GOLD.g, GOLD.b, 0.18 * fade))
				_overlay.draw_arc(to_c, s * (0.45 + ease_k * 1.25), 0.0, TAU, 28, Color(GOLD.r, GOLD.g, GOLD.b, 0.35 * fade), 6.0)
				_overlay.draw_arc(to_c, s * (0.45 + ease_k * 1.25), 0.0, TAU, 28, Color(1, 0.95, 0.7, fade), 2.0)
				for ray in range(8):
					var ang: float = ray * TAU / 8.0 + k * 1.2
					var d0: float = s * (0.35 + ease_k * 0.9)
					var d1: float = d0 + s * 0.45 * fade
					_overlay.draw_line(to_c + Vector2(cos(ang), sin(ang)) * d0, to_c + Vector2(cos(ang), sin(ang)) * d1, Color(GOLD.r, GOLD.g, GOLD.b, fade), 2.0)
				var cy: float = to_c.y - s * (0.7 + ease_k * 1.3)
				var w: float = s * 0.3
				for j in range(2):
					var yy: float = cy + j * s * 0.26
					var chev := PackedVector2Array([Vector2(to_c.x - w, yy + w * 0.7), Vector2(to_c.x, yy), Vector2(to_c.x + w, yy + w * 0.7)])
					_overlay.draw_polyline(chev, Color(0.08, 0.06, 0.12, fade), maxf(4.0, s * 0.2))
					_overlay.draw_polyline(chev, Color(GOLD.r, GOLD.g, GOLD.b, fade), maxf(2.0, s * 0.1))
			"counter":
				var fa := screen_pos(e["from"] as Vector2i, m) - Vector2(0, s * 0.6)
				var fb := _wrap_target(fa, to_c, m)
				var hk: float = k * k # accelerates towards the hit
				var head2 := fa.lerp(fb, hk)
				var tail2 := fa.lerp(fb, maxf(0.0, hk - 0.3))
				_overlay.draw_line(tail2, head2, Color(CYAN.r, CYAN.g, CYAN.b, 0.35), maxf(4.0, s * 0.25))
				_overlay.draw_line(tail2, head2, Color(0.9, 1, 1, 0.95), maxf(1.5, s * 0.09))
				_overlay.draw_circle(head2, maxf(2.0, s * 0.13), Color(1, 1, 1))
			"shield":
				var ek: float = 1.0 - pow(1.0 - k, 2.0)
				var fade2: float = 1.0 - k
				var r: float = s * (0.95 + ek * 0.35)
				var hex := _hex_points(to_c, r)
				_overlay.draw_colored_polygon(hex, Color(CYAN.r, CYAN.g, CYAN.b, 0.32 * fade2))
				for cc in range(3):
					_overlay.draw_line(hex[cc], hex[cc + 3], Color(0.85, 1, 1, 0.45 * fade2), 1.5)
				var inner := _hex_poly(to_c, r * 0.55)
				_overlay.draw_polyline(inner, Color(0.85, 1, 1, 0.5 * fade2), 1.5)
				_glow_polyline(_hex_poly(to_c, r), Color(0.8, 1, 1, fade2), 2.5)
				for sp in range(10):
					var sa: float = sp * TAU / 10.0 + 0.3
					var sd: float = s * (1.0 + ek * 1.0)
					_overlay.draw_circle(to_c + Vector2(cos(sa), sin(sa)) * sd, maxf(1.0, s * 0.06 * fade2), Color(0.85, 1, 1, fade2))
			"wreck":
				_draw_card(str(e["name"]), to_c, s, Color(1, 0.5, 0.45, 0.9 - 0.4 * k), 0, str(e.get("owner", "")))
			"place":
				_overlay.draw_arc(to_c, s * (0.6 + k * 0.8), 0.0, TAU, 20, Color(0.6, 1.0, 0.45, 1.0 - k), 2.0)

# Floating damage numbers, drawn with the UI font on a smoothly filtered layer.
func _draw_text_fx() -> void:
	var m := metrics()
	var s: float = m[0]
	if s < 2.0:
		return
	var font := get_theme_default_font()
	for e in effects:
		if str(e["kind"]) != "num":
			continue
		var age: float = _clock - float(e["t0"])
		if age < 0.0:
			continue
		var k: float = clampf(age / float(e["dur"]), 0.0, 1.0)
		var to_c := screen_pos(e["to"] as Vector2i, m)
		var fs := int(clampf(s * 1.1, 16.0, 40.0))
		var txt := str(e["text"])
		var tw: float = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		# pop in, then float up and fade
		var pop: float = 1.0 + 0.35 * maxf(0.0, 1.0 - k * 6.0)
		var p := to_c + Vector2(-tw * 0.5, -s * 0.8 - k * s * 1.5)
		var col2: Color = e["color"]
		var a: float = 1.0 - maxf(0.0, (k - 0.55) / 0.45)
		_text_layer.draw_set_transform(p + Vector2(tw * 0.5, 0), 0.0, Vector2(pop, pop))
		_text_layer.draw_string_outline(font, Vector2(-tw * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.05, 0.04, 0.08, a))
		_text_layer.draw_string(font, Vector2(-tw * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col2.r, col2.g, col2.b, a))
		_text_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_overlay() -> void:
	var m := metrics()
	var s: float = m[0]
	if s < 2.0:
		return
	var margin: float = s * 2.0
	# Legal placement hexes for the selected card
	if not placeable.is_empty():
		var a: float = 0.45 + 0.35 * (0.5 + 0.5 * sin(_clock * 5.0))
		for key in placeable.keys():
			for cp in _visible_copies(MapWar.key_to_hex(str(key)), m, margin):
				var ring := _hex_points(cp as Vector2, s - 1.5)
				ring.append(ring[0])
				_overlay.draw_polyline(ring, Color(0.6, 1.0, 0.45, a), 2.0)
	# Front line (card-battle mode): enemy hexes you could win next pulse red
	if not _front.is_empty():
		var pulse: float = 0.30 + 0.25 * (0.5 + 0.5 * sin(_pulse_t * 4.0))
		for t in _front:
			for cp in _visible_copies(t as Vector2i, m, margin):
				var c := cp as Vector2
				_overlay.draw_colored_polygon(_hex_points(c, s), Color(1.0, 0.18, 0.12, pulse))
				var ring2 := _hex_points(c, s - 1.5)
				ring2.append(ring2[0])
				_overlay.draw_polyline(ring2, Color(1, 0.3, 0.25, pulse + 0.25), 2.0)
	if war != null:
		_draw_units(m)
		_draw_flag_hp(m)
		_draw_effects(m)
		if ghost_card != "" and hovered.x >= 0 and placeable.has(MapCampaign.key_of(hovered.x, hovered.y)):
			var gp := get_local_mouse_position()
			for cp in _visible_copies(hovered, m, margin):
				if (cp as Vector2).distance_to(gp) < s * 2.0:
					_draw_card(ghost_card, cp as Vector2, s, Color(1, 1, 1, 0.55), 0, _player_nation)
	if not aim.is_empty():
		_draw_aim(m)
	if hovered.x >= 0 and hovered != selected:
		_hex_outline(hovered, m, Color(1, 1, 1, 0.6), 2.0)
	if selected.x >= 0:
		_hex_outline(selected, m, Color8(20, 16, 30), 5.0)
		_hex_outline(selected, m, Color(1.0, 0.86, 0.3), 2.5)

# Hover help (like the old battle screen's attack arrow): dashed line from the
# hovered unit to the target it would hit next, with a pulsing crosshair.
func _draw_aim(m: Array) -> void:
	var s: float = m[0]
	var a := screen_pos(aim["from"] as Vector2i, m)
	var b := _wrap_target(a, screen_pos(aim["to"] as Vector2i, m), m)
	var col := Color(0.55, 0.85, 1.0, 0.95) if bool(aim.get("ranged", false)) else Color(1.0, 0.45, 0.35, 0.95)
	var dist := a.distance_to(b)
	var dash: float = maxf(6.0, s * 0.45)
	var n := int(dist / (dash * 2.0)) + 1
	var off := fposmod(_clock * 30.0, dash * 2.0)
	for i in range(n + 1):
		var t0 := clampf((i * dash * 2.0 + off - dash) / maxf(dist, 1.0), 0.0, 1.0)
		var t1 := clampf((i * dash * 2.0 + off) / maxf(dist, 1.0), 0.0, 1.0)
		if t1 > t0:
			_overlay.draw_line(a.lerp(b, t0), a.lerp(b, t1), Color(0.05, 0.04, 0.08, 0.8), 5.0)
			_overlay.draw_line(a.lerp(b, t0), a.lerp(b, t1), col, 2.5)
	var r: float = s * (0.75 + 0.12 * sin(_clock * 6.0))
	_overlay.draw_arc(b, r, 0.0, TAU, 20, col, 2.5)
	_overlay.draw_line(b - Vector2(r * 1.4, 0), b - Vector2(r * 0.5, 0), col, 2.0)
	_overlay.draw_line(b + Vector2(r * 0.5, 0), b + Vector2(r * 1.4, 0), col, 2.0)
	_overlay.draw_line(b - Vector2(0, r * 1.4), b - Vector2(0, r * 0.5), col, 2.0)
	_overlay.draw_line(b + Vector2(0, r * 0.5), b + Vector2(0, r * 1.4), col, 2.0)

# Global-space rectangle around hex t (for anchoring hover cards).
func hex_global_rect(t: Vector2i) -> Rect2:
	var m := metrics()
	var s: float = m[0]
	var c := screen_pos(t, m)
	return Rect2(get_global_transform() * (c - Vector2(s, s)), Vector2(s, s) * 2.0)

func _hex_outline(t: Vector2i, m: Array, col: Color, width: float) -> void:
	for cp in _visible_copies(t, m, m[0] * 2.0):
		var pts := _hex_points(cp as Vector2, m[0])
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
