# Civ-style hex renderer for the WorldMap Earth data, with a zoom/pan camera.
# Pointy-top hexes in "odd-r" offset layout (odd rows shifted half a hex right),
# matching MapCampaign's hex adjacency. The map wraps east-west like a globe:
# panning sideways scrolls forever and any hex can appear more than once when
# zoomed out. Pixel-art terrain (TileArt), shimmering sea, owner tints, nation
# borders along hex edges and flag-on-pole capitals are drawn on the base layer;
# fast-changing bits (units, FX, hover, selection, placement hints) live on a
# child overlay so the base layer only redraws on camera moves and map changes.
# Controls: mouse wheel zooms at the cursor, right (or middle) drag pans, left drag
# draws a selection box (box_selected), a left click selects a hex, and
# zoom_by()/pan_by()/center_on() are public for buttons and keys.
extends Control
class_name WorldMapView

signal tile_selected(x: int, y: int)
signal tile_hovered(x: int, y: int)
signal hover_cleared # mouse left the map or moved off the grid
signal box_selected(rect: Rect2, additive: bool) # left drag: a selection box (local coordinates); Shift held = add to the selection

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
var _overlay: Control = null # marks over the units: hover, selection, auras, effects
var _grid: Control = null # hex grid, borders and flags
var _under: Control = null # marks under the units: zones, rings, glows, boat wakes
var _units: Control = null # the cards themselves (redrawn on change and 4x a second)
var _walkers: Control = null # cards marching right now (redrawn every frame they move)
var _chips: Control = null # HP / attack chips of the cards standing still (redrawn on change)
var _ci: CanvasItem = null # the layer being drawn (the draw helpers paint on it)
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
# Selected units: their attack range as tinted, outlined zones, the enemy targets
# inside them, a ring under each selected unit and, while planning a bulk move, a
# marker on each hex a unit would march to.
var range_zones: Array = [] # [{"hexes": {Vector2i: true}, "ranged": bool or "color": Color}, ...]
var range_targets: Array = [] # enemy card/flag hexes within those zones
var group_marks: Array = [] # hexes of the selected units
var plan_marks: Array = [] # [[from hex, to hex], ...]: where a bulk move would send them
const RANGE_MELEE := Color(1.0, 0.45, 0.35)  # same colours as the targeting arrow
const RANGE_RANGED := Color(0.55, 0.85, 1.0)
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
var _boxing: bool = false # a left drag draws a selection box (right/middle drags pan)
var _box_end := Vector2.ZERO
var click_shift: bool = false # Shift was held on the latest map click (read by tile_selected handlers)

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
	# Grid, borders and flags; marks under the units; the units; marks over them.
	_grid = _add_layer("Grid", _draw_base)
	_under = _add_layer("UnderUnits", _draw_under)
	_units = _add_layer("Units", _draw_unit_layer)
	_walkers = _add_layer("Walkers", _draw_walker_layer)
	_overlay = _add_layer("Overlay", _draw_overlay)
	_chips = _add_layer("StatChips", _draw_chip_layer)
	_chips.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
		_redraw(_overlay)
		hover_cleared.emit())

func _add_layer(layer_name: String, draw_fn: Callable) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.draw.connect(draw_fn)
	add_child(layer)
	return layer

func _redraw_all() -> void:
	if _terrain != null:
		_terrain.queue_redraw()
	for layer in [_grid, _under, _units, _walkers, _overlay, _chips, _text_layer]:
		if layer != null:
			_redraw(layer)

# Everything that shows the war's state: call after changing what the map shows
# (cards, HP, ghosts, zones...). Hover and selection only need the overlay.
func redraw_layers() -> void:
	for layer in [_under, _units, _walkers, _overlay, _chips]:
		_redraw(layer)

# ------------------------------------------------------------ scrolling
# Panning doesn't redraw: each layer is drawn with SCROLL_SLACK pixels of extra
# content round the screen and is slid by the camera's offset since it was drawn
# (a few hundred units cost a few ms to draw; moving a layer costs nothing). A
# layer is redrawn, back in place, when it has slid too far, on a zoom, or when
# its content changes anyway (the animation pulses).
const SCROLL_SLACK := 192.0
var _drawn_cam: Dictionary = {} # layer -> [origin x, origin y, hex size] it was drawn at

func _mark_drawn(layer: Control, m: Array) -> void:
	_drawn_cam[layer] = [float(m[1]), float(m[2]), float(m[0])]

func _redraw(layer: Control) -> void:
	layer.position = Vector2.ZERO
	layer.scale = Vector2.ONE
	layer.queue_redraw()

# Zooming works the same way while the camera moves (a glide, the mouse wheel): a
# layer drawn at hex size s0 is scaled by s/s0 instead of redrawn, as long as what
# it drew still covers the screen. A frame after the camera stops, scaled layers
# are redrawn crisp.
const ZOOM_SLACK := 0.2 # redraw once the scale is more than 20% off
var _cam_settle: int = 0 # frames until the camera counts as resting

func _camera_moved() -> void:
	if _terrain != null:
		_terrain.queue_redraw() # one mesh per wrapped copy: always cheap
	_cam_settle = 2
	var m := metrics()
	for layer in [_grid, _under, _units, _walkers, _overlay, _chips, _text_layer]:
		if layer == null:
			continue
		var d: Array = _drawn_cam.get(layer, [])
		if d.is_empty() or float(d[2]) <= 0.0:
			_redraw(layer)
			continue
		var k: float = float(m[0]) / float(d[2])
		# where the drawn picture's origin must go: o_now = offset + o_drawn * k
		var off := Vector2(float(m[1]) - float(d[0]) * k, float(m[2]) - float(d[1]) * k)
		if WorldMap.WRAPS:
			var period: float = m[4]
			off.x = wrapf(off.x, -period * 0.5, period * 0.5)
		# the screen, in the drawn picture's coordinates, must lie within what it drew
		var lo := -off / k
		var hi := (size - off) / k
		if absf(k - 1.0) > ZOOM_SLACK or lo.x < -SCROLL_SLACK or lo.y < -SCROLL_SLACK \
				or hi.x > size.x + SCROLL_SLACK or hi.y > size.y + SCROLL_SLACK:
			_redraw(layer)
		else:
			layer.position = off
			layer.scale = Vector2(k, k)

func _settle_layers() -> void:
	for layer in [_grid, _under, _units, _walkers, _overlay, _chips, _text_layer]:
		if layer != null and layer.scale != Vector2.ONE:
			_redraw(layer)

func set_campaign(campaign: MapCampaign) -> void:
	# The game calls this after every change that might move a border; when none did,
	# skip re-tracing every border and re-tinting the land (tens of ms on the world map).
	var sig: Array = [campaign.get_instance_id(), WorldMap.MAP_ID, campaign.player_nation, campaign.owner.hash(), campaign.flag_sites.hash()]
	if war != null and sig == _campaign_sig:
		redraw_layers()
		return
	_campaign_sig = sig
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
	_campaign_rev += 1
	_land_dirty = true
	_build_borders()
	_redraw_all()

# Where each nation's flag stands, cached until the borders or flags change (the map
# asks for every flag on every redraw; MapCampaign works it out from the owner map).
var _sites: Dictionary = {}
var _sites_sig: Array = []

func capital_site(nation: String) -> Vector2i:
	var sig: Array = [_campaign_rev, _campaign.flag_sites.hash()]
	if sig != _sites_sig:
		_sites_sig = sig
		_sites.clear()
	if not _sites.has(nation):
		_sites[nation] = _campaign.capital_site(nation)
	return _sites[nation]

func set_war(w: MapWar) -> void:
	war = w
	_ucache_sig = []
	_front = []
	redraw_layers()

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
	if _cam_settle > 0:
		_cam_settle -= 1
		if _cam_settle == 0:
			_settle_layers()
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
		# the animated marks (few) every pulse; the units and their stat chips (many,
		# and costly to draw) only when what they show changes
		_redraw(_under)
		_redraw(_overlay)
		var hp_sig := _hp_sig()
		var usig: Array = [int(_clock * 4.0), hp_sig] # sprite frame, war state
		if usig != _last_units_sig:
			_last_units_sig = usig
			_redraw(_units)
		var csig: Array = hp_sig if metrics()[0] >= STAT_CHIP_MIN_HEX else []
		if csig != _last_chip_sig:
			_last_chip_sig = csig
			_redraw(_chips)
		var ssig := _scars().hash()
		if ssig != _last_scar_sig: # ruins or wasteland appeared
			_last_scar_sig = ssig
			_redraw(_grid)
		if walks.size() != _last_walk_n: # a march began or ended: the walkers layer empties
			_last_walk_n = walks.size()
			_redraw(_walkers)
			_redraw(_text_layer)
	if not effects.is_empty() or not walks.is_empty():
		_fx_clock += delta
		if _fx_clock >= 1.0 / 40.0:
			_fx_clock = 0.0
			_redraw(_under)
			_redraw(_overlay)
			_redraw(_text_layer) # damage numbers, and the marching cards' chips
			if not walks.is_empty():
				_redraw(_walkers) # only they move: the units layer stays as it is
		var keep: Array = []
		for e in effects:
			if _clock < float(e["t0"]) + float(e["dur"]):
				keep.append(e)
		effects = keep
	for wk in walks.keys():
		var w: Dictionary = walks[wk]
		if bool(w["back"]) and _walk_progress(w) <= 0.0:
			walks.erase(wk)
			_walks_changed()

# What the units layer and the stat chips show, apart from the camera: the war
# (cards, owners, buffs...), every card's HP and the attack replay's state.
var _last_chip_sig: Array = []
var _last_units_sig: Array = []
var _last_walk_n: int = 0
var _last_scar_sig: int = 0

func _hp_sig() -> Array:
	if war == null:
		return []
	var hp_sum := 0
	for k in war.units.keys():
		hp_sum = (hp_sum * 31 + war.card_hp(war.units[k]["card"])) & 0x3fffffffffff
	return [_war_sig(), hp_sum, hp_shown.hash(), ghosts.hash(), walks.size()]

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
	margin += SCROLL_SLACK # layers slide by up to this much before they are redrawn
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
	_camera_moved()

func pan_by(delta: Vector2) -> void:
	_edge_free = false
	_pan += delta
	_normalize_pan()
	_camera_moved()

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
	_camera_moved()

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
	_camera_moved()

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
	_camera_moved()

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
				_dragging = mb.button_index != MOUSE_BUTTON_LEFT # right/middle drags pan
				_press_pos = mb.position
				_boxing = mb.button_index == MOUSE_BUTTON_LEFT # left drags box-select
				_box_end = mb.position
			else:
				if _boxing and mb.button_index == MOUSE_BUTTON_LEFT:
					var boxed := _press_pos.distance_to(mb.position) > DRAG_THRESHOLD
					_boxing = false
					_redraw(_overlay)
					if boxed:
						_pressed = false
						box_selected.emit(Rect2(_press_pos, Vector2.ZERO).expand(mb.position), mb.shift_pressed)
						return
					# a left press that never really moved is a click
				var was_click := _pressed and not _dragging and mb.button_index == MOUSE_BUTTON_LEFT
				_pressed = false
				_dragging = false
				if was_click:
					click_shift = mb.shift_pressed
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
		if _pressed and _boxing:
			_box_end = mm.position
			_redraw(_overlay)
			return
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
			_redraw(_overlay)
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

# Keys of `owner`'s units whose hex centre lies inside `rect` (local coordinates).
func units_in_rect(rect: Rect2, owner: String) -> Array:
	var out: Array = []
	if war == null:
		return out
	var m := metrics()
	for k in war.units.keys():
		if str(war.units[k]["owner"]) != owner or not (war.units[k]["card"] is Unit):
			continue
		for cp in _visible_copies(MapWar.key_to_hex(str(k)), m, 0.0):
			if rect.has_point(cp as Vector2):
				out.append(str(k))
				break
	return out

func clear_range() -> void:
	range_zones = []
	range_targets = []
	group_marks = []
	plan_marks = []
	redraw_layers()

func select_tile(t: Vector2i, emit: bool = true) -> void:
	selected = t
	_redraw_all() # selected nation tint lives on the base layer
	if emit:
		tile_selected.emit(t.x, t.y)
	click_shift = false # only ever describes the click being handled

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

func _draw_base() -> void:
	var m := metrics()
	_mark_drawn(_grid, m)
	var s: float = m[0]
	if s < 2.0:
		return
	var oy: float = m[2]
	var map_h: float = (1.5 * WorldMap.GRID_H + 0.5) * s
	_draw_scars(m)
	# hex grid (1px hairlines) and nation borders, from precomputed map-unit segments
	var bw: float = maxf(2.0, floorf(s * 0.22))
	for ox in _copy_origins(m):
		_grid.draw_set_transform(Vector2(ox, m[2]), 0.0, Vector2(s, s))
		if not _grid_pts.is_empty():
			_grid.draw_multiline(_grid_pts, Color(0, 0, 0, 0.22), -1.0)
		for seg in _border_segs:
			_grid.draw_multiline(seg[1], Color(0.05, 0.04, 0.08, 0.85), (bw + 2.0) / s)
		for seg in _border_segs:
			_grid.draw_multiline(seg[1], seg[0], bw / s)
	_grid.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Pixel bezel: polar edges (the world wraps sideways); all four sides on regional maps
	if WorldMap.WRAPS:
		for edge_y in [oy - FRAME_PX, oy + map_h]:
			if edge_y + FRAME_PX >= 0.0 and edge_y <= size.y:
				_grid.draw_rect(Rect2(0, edge_y, size.x, FRAME_PX), Color8(20, 16, 30), true)
				_grid.draw_rect(Rect2(0, edge_y + 2.0, size.x, 2.0), Color8(94, 104, 128), true)
	else:
		var fr := Rect2(m[1], oy, _map_width(s), map_h).grow(FRAME_PX * 0.5)
		_grid.draw_rect(fr, Color8(20, 16, 30), false, FRAME_PX)
		_grid.draw_rect(fr.grow(-2.0), Color8(94, 104, 128), false, 2.0)
	# Capitals: pixel flag on a pole, planted on the capital hex
	for n in WorldMap.nations():
		var d := n as Dictionary
		var nm := str(d["name"])
		var site := Vector2i(int(d["x"]), int(d["y"]))
		if _campaign != null:
			site = flag_site_shown.get(nm, capital_site(nm))
		var fs: float = maxf(s * 2.6, 16.0)
		for cc in _visible_copies(site, m, fs):
			var base := (cc as Vector2) + Vector2(0, s * 0.55)
			_grid.draw_rect(Rect2(base + Vector2(-fs * 0.2, -2.0), Vector2(fs * 0.4, 3.0)), Color(0, 0, 0, 0.45), true)
			if _dead.has(nm):
				var xc := base - Vector2(0, s * 0.6)
				var r: float = s * 0.45
				_grid.draw_line(xc - Vector2(r, r), xc + Vector2(r, r), Color(0.8, 0.8, 0.85), 2.0)
				_grid.draw_line(xc + Vector2(-r, r), xc + Vector2(r, -r), Color(0.8, 0.8, 0.85), 2.0)
				continue
			if _flags.has(nm):
				# flag art has its pole at ~x=0.12 of the texture; plant that on the hex centre
				_grid.draw_texture_rect(_flags[nm] as Texture2D, Rect2(base - Vector2(fs * 0.12, fs * 0.9), Vector2(fs, fs)), false)
			if nm == _player_nation:
				_draw_star(_grid, base + Vector2(0, -fs * 0.98), maxf(s * 0.5, 4.0), Color(1.0, 0.86, 0.3))

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

# Every unit's idle frames also go into one shared atlas texture, so the whole army
# draws as a single batch (a texture switch per sprite would cost a draw call each).
const ATLAS_CELL := 32
const ATLAS_SIZE := 1024 # 32x32 cells of 32px; full => fall back to the frame textures
var _sprite_img: Image = null
var _sprite_atlas: ImageTexture = null
var _sprite_regions: Dictionary = {} # "card|nation" -> Array[Rect2] in the atlas ([] = not in it)
var _sprite_cells: int = 0

func _atlas_regions(card_name: String, nation: String) -> Array:
	var cache_key := card_name + "|" + nation
	if _sprite_regions.has(cache_key):
		return _sprite_regions[cache_key]
	var frames := unit_frames(card_name, nation)
	var per_row: int = ATLAS_SIZE / ATLAS_CELL
	var out: Array = []
	if _sprite_cells + frames.size() <= per_row * per_row:
		if _sprite_img == null:
			_sprite_img = Image.create(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8)
		for tex in frames:
			var img: Image = (tex as Texture2D).get_image()
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			var at := Vector2i((_sprite_cells % per_row) * ATLAS_CELL, (_sprite_cells / per_row) * ATLAS_CELL)
			_sprite_img.blit_rect(img, Rect2i(0, 0, ATLAS_CELL, ATLAS_CELL), at)
			out.append(Rect2(Vector2(at), Vector2(ATLAS_CELL, ATLAS_CELL)))
			_sprite_cells += 1
		if _sprite_atlas == null:
			_sprite_atlas = ImageTexture.create_from_image(_sprite_img)
		elif not out.is_empty():
			_sprite_atlas.update(_sprite_img)
	_sprite_regions[cache_key] = out
	return out

# Owner base under each unit (a dark-rimmed flat ellipse, white inside so the draw
# call's modulate paints it in the nation's colour): one texture, batched like the sprites.
var _base_tex: ImageTexture = null

func _unit_base_tex() -> ImageTexture:
	if _base_tex != null:
		return _base_tex
	var w := 72
	var h := 33
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rim := Color(0.05, 0.04, 0.08, 0.85)
	var inner: float = 0.6 / 0.72
	for y in range(h):
		for x in range(w):
			# 3x3 supersampling for soft edges
			var cover_out := 0.0
			var cover_in := 0.0
			for sy in range(3):
				for sx in range(3):
					var px: float = ((x + (sx + 0.5) / 3.0) / w) * 2.0 - 1.0
					var py: float = ((y + (sy + 0.5) / 3.0) / h) * 2.0 - 1.0
					var d: float = px * px + py * py
					if d <= 1.0:
						cover_out += 1.0 / 9.0
					if d <= inner * inner:
						cover_in += 1.0 / 9.0
			var col := Color(rim.r, rim.g, rim.b, rim.a * cover_out)
			if cover_in > 0.0:
				col = col.blend(Color(1, 1, 1, cover_in)) # the white fill over the dark rim
			img.set_pixel(x, y, col)
	_base_tex = ImageTexture.create_from_image(img)
	return _base_tex

# What every card on the map looks like apart from the camera and the clock: owner,
# colour, sprite frames, Barracks buff, Interceptor cover, flanking and the damage it
# deals from where it stands. Rebuilt only when the war changes (cards placed, moved
# or removed, a new turn, money crossing the Interceptor's fee, modifiers, borders),
# not on every redraw: on a crowded map those neighbour scans were most of a frame.
var _ucache: Array = [] # entries in drawing order (north to south)
var _ucache_sig: Array = []
var _ucache_barracks: Array = [] # hexes of Barracks (their ripples)
var _ucache_marked: Array = [] # entries with an aura, flank arrows or a boat
var _ucache_by_key: Dictionary = {} # "x,y" -> entry
var _campaign_rev: int = 0 # bumped by set_campaign: ownership feeds the home-ground bonus
var _campaign_sig: Array = [] # what set_campaign last traced the borders for

func _war_sig() -> Array:
	var sig: Array = [war.units.hash(), war.turn, _campaign_rev]
	for nm in war.players.keys():
		var p: Player = war.players[nm]
		sig.append(p.MoneySupply >= 6)
		sig.append(p.Modifiers.size())
	return sig

func unit_cache() -> Array:
	if war == null:
		return []
	var sig := _war_sig()
	if sig == _ucache_sig:
		return _ucache
	# Only cards moved, arrived or fell (same turn, money, modifiers, borders): redo
	# just them and their neighbours, which is all a buff, cover or flank can reach.
	var patched := not _ucache_sig.is_empty() and sig.slice(1) == _ucache_sig.slice(1) and _patch_cache()
	_ucache_sig = sig
	if patched:
		return _ucache
	_ucache.clear()
	_ucache_by_key.clear()
	# Plain arrays and integer cell keys: a full rebuild avoids the string keys and
	# helper calls of MapWar's own checks (a crowded map has a thousand cards).
	var keys: Array = war.units.keys()
	var n := keys.size()
	var gw: int = WorldMap.GRID_W
	var gh: int = WorldMap.GRID_H
	var wraps: bool = WorldMap.WRAPS
	var hexes: Array = []
	var cards: Array = []
	var owner_of: PackedStringArray = PackedStringArray()
	var owner_ix: PackedInt32Array = PackedInt32Array()
	var alive: PackedByteArray = PackedByteArray()
	var nation_ix: Dictionary = {}
	var occ: Dictionary = {} # y * gw + x -> index
	for idx in range(n):
		var info: Dictionary = war.units[keys[idx]]
		var h := MapWar.key_to_hex(str(keys[idx]))
		var o := str(info["owner"])
		if not nation_ix.has(o):
			nation_ix[o] = nation_ix.size()
		hexes.append(h)
		cards.append(info["card"])
		owner_of.append(o)
		owner_ix.append(int(nation_ix[o]))
		alive.append(1 if war.card_hp(info["card"]) > 0 else 0)
		occ[h.y * gw + h.x] = idx
	var nb_cells := func(t: Vector2i) -> PackedInt32Array: # the 6 neighbours' cells (-1 = off the map)
		var out := PackedInt32Array()
		var dirs: Array = MapCampaign.HEX_DIRS_ODD if (t.y & 1) == 1 else MapCampaign.HEX_DIRS_EVEN
		for d in dirs:
			var ny: int = t.y + d.y
			var nx: int = t.x + d.x
			if wraps:
				nx = posmod(nx, gw)
			out.append(ny * gw + nx if (ny >= 0 and ny < gh and nx >= 0 and nx < gw) else -1)
		return out
	# A living Barracks buffs its owner's units next to it (MapWar.is_buffed); a living
	# Interceptor covers its owner's other cards within INTERCEPTOR_RANGE while they
	# can pay 6 Money (MapWar.is_shielded). Mark the hexes they reach: there are few.
	var buff_at: Dictionary = {} # cell * 64 + nation index -> true
	var cover_at: Dictionary = {}
	for idx in range(n):
		var c: Card = cards[idx]
		if alive[idx] == 0:
			continue
		if c is Barracks:
			for cell in nb_cells.call(hexes[idx]):
				if cell >= 0:
					buff_at[cell * 64 + owner_ix[idx]] = true
		elif c is Interceptor:
			for h in war.hexes_within(hexes[idx], MapWar.INTERCEPTOR_RANGE):
				cover_at[((h as Vector2i).y * gw + (h as Vector2i).x) * 64 + owner_ix[idx]] = true
	var can_pay: Dictionary = {}
	for nm in war.players.keys():
		can_pay[str(nm)] = (war.players[nm] as Player).MoneySupply >= 6
	var base_dmg: Dictionary = {} # [owner, card stats] -> Player.effective_damage_for (the same for every copy)
	var barracks_bonus: Dictionary = {} # owner -> MapWar._barracks_bonus next to one of its Barracks
	var land_owner: Dictionary = war.campaign.owner if war.campaign != null else {}
	for idx in range(n):
		var k: String = str(keys[idx])
		var t: Vector2i = hexes[idx]
		var owner: String = owner_of[idx]
		var card: Card = cards[idx]
		var is_unit := card is Unit
		var cell: int = t.y * gw + t.x
		var buffed: bool = is_unit and buff_at.has(cell * 64 + owner_ix[idx])
		var shielded: bool = not (card is Interceptor) and bool(can_pay.get(owner, false)) and cover_at.has(cell * 64 + owner_ix[idx])
		var flank := 0 # MapWar.flank_at: living enemy units on the 6 sides
		if is_unit:
			var enemy: Array = [false, false, false, false, false, false]
			var n_enemy := 0
			var cells: PackedInt32Array = nb_cells.call(t)
			for i in range(6):
				var j: int = occ.get(cells[i], -1) if cells[i] >= 0 else -1
				if j >= 0 and alive[j] == 1 and owner_ix[j] != owner_ix[idx] and cards[j] is Unit:
					enemy[i] = true
					n_enemy += 1
			if n_enemy >= 6:
				flank = MapWar.FLANK_ENCIRCLED
			elif n_enemy >= 4:
				flank = MapWar.FLANK_SURROUNDED
			elif (enemy[0] and enemy[3]) or (enemy[1] and enemy[4]) or (enemy[2] and enemy[5]):
				flank = MapWar.FLANK_FLANKED
		var atk := "" # MapWar.effective_damage, from the parts worked out above
		if is_unit and war.players.has(owner):
			var u := card as Unit
			var bk: Array = [owner, u.card_name, u.Damage, u.BioCost, u.MoneyCost, u.Flying]
			if not base_dmg.has(bk):
				base_dmg[bk] = (war.players[owner] as Player).effective_damage_for(u, null)
			if buffed and not barracks_bonus.has(owner): # the same next to any of its Barracks
				barracks_bonus[owner] = war._barracks_bonus(owner, t)
			var dmg: int = int(base_dmg[bk]) + (int(barracks_bonus[owner]) if buffed else 0) \
				+ (MapWar.HOME_BONUS if str(land_owner.get(k, "")) == owner else 0)
			atk = str(dmg) + ("x4" if (card is RocketLauncher or card is Howitzer) else "")
		_ucache_by_key[k] = _cache_entry(k, t, owner, card, buffed, shielded, flank, atk)
	_order_cache()
	return _ucache

func _cache_entry(k: String, t: Vector2i, owner: String, card: Card, buffed: bool, shielded: bool, flank: int, atk: String) -> Dictionary:
	var is_unit := card is Unit
	return {
		"k": k, "t": t, "owner": owner, "card": card, "is_unit": is_unit,
		"nc": _nation_colors.get(owner, Color.WHITE), "buffed": buffed, "shielded": shielded,
		"flank": flank, "atk": atk, "seed": t.x * 13 + t.y * 7, "frame_off": t.x + t.y,
		"regions": _atlas_regions(card.card_name, owner),
		"frames": unit_frames(card.card_name, owner),
		"sea": not (is_unit and (card as Unit).Flying) and not WorldMap.is_land(t.x, t.y),
	}

# _ucache (and the Barracks and marked lists) from _ucache_by_key, north to south so
# a sprite never stands behind the one on the row above it. (A native sort of
# row-major keys: a GDScript comparator was most of a rebuild.)
func _order_cache() -> void:
	var entries: Array = _ucache_by_key.values()
	var order := PackedInt64Array()
	for i in range(entries.size()):
		var t: Vector2i = entries[i]["t"]
		order.append((int(t.y) * 65536 + int(t.x)) * 65536 + i)
	order.sort()
	_ucache = []
	_ucache_barracks.clear()
	_ucache_marked.clear()
	for o in order:
		var e: Dictionary = entries[o & 0xffff]
		_ucache.append(e)
		if e["card"] is Barracks:
			_ucache_barracks.append(e["t"])
		if e["buffed"] or e["shielded"] or int(e["flank"]) > 0 or e["sea"]:
			_ucache_marked.append(e)

# Bring the cache up to date after a few cards changed hex, arrived or were removed,
# asking MapWar itself about each card they could affect. False (nothing done) when
# too much changed for that to be cheaper than a full rebuild.
const PATCH_MAX := 24

func _patch_cache() -> bool:
	var changed: Array = []
	for k in war.units.keys():
		var e: Dictionary = _ucache_by_key.get(k, {})
		if e.is_empty() or e["card"] != war.units[k]["card"] or e["owner"] != str(war.units[k]["owner"]):
			if war.units[k]["card"] is Interceptor or (not e.is_empty() and e["card"] is Interceptor):
				return false # its cover reaches further than the neighbours redone below
			changed.append(k)
			if changed.size() > PATCH_MAX:
				return false
	if _ucache_by_key.size() != war.units.size() - _count_new(changed):
		for k in _ucache_by_key.keys():
			if not war.units.has(k):
				if _ucache_by_key[k]["card"] is Interceptor:
					return false
				changed.append(k)
				if changed.size() > PATCH_MAX:
					return false
	var redo: Dictionary = {} # the changed hexes and their neighbours
	for k in changed:
		redo[k] = true
		for nb in MapCampaign.wrapped_neighbors(MapWar.key_to_hex(str(k))):
			redo[MapCampaign.key_of((nb as Vector2i).x, (nb as Vector2i).y)] = true
	for k in redo.keys():
		_ucache_by_key.erase(k)
		if not war.units.has(k):
			continue
		var info: Dictionary = war.units[k]
		var owner := str(info["owner"])
		var card: Card = info["card"]
		var t := MapWar.key_to_hex(str(k))
		var atk := ""
		if card is Unit and war.players.has(owner):
			atk = str(war.effective_damage(owner, card as Unit, t)) + ("x4" if (card is RocketLauncher or card is Howitzer) else "")
		_ucache_by_key[k] = _cache_entry(str(k), t, owner, card, war.is_buffed(str(k)),
			war.is_shielded(str(k)) and not (card is Interceptor), war.flank_bonus(str(k)), atk)
	_order_cache()
	return true

# How many of `keys` are new to the cache (so its size can be checked for removals).
func _count_new(keys: Array) -> int:
	var n := 0
	for k in keys:
		if not _ucache_by_key.has(k):
			n += 1
	return n

func _draw_card(card_name: String, c: Vector2, s: float, tint: Color = Color.WHITE, frame_offset: int = 0, nation: String = "") -> void:
	var frames := unit_frames(card_name, nation)
	if frames.is_empty():
		return
	var tex: Texture2D = frames[(int(_clock * 4.0) + frame_offset) % frames.size()]
	var side: float = s * 2.1
	_ci.draw_texture_rect(tex, Rect2(c - Vector2(side * 0.5, side * 0.62), Vector2(side, side)), false, tint)

func add_shot(from: Vector2i, to: Vector2i, sfx_kind: String, travel: float) -> void:
	effects.append({"kind": "shot", "from": from, "to": to, "t0": _clock, "dur": travel, "color": SHOT_COLORS.get(sfx_kind, Color.WHITE)})

func add_boom(at: Vector2i, big: bool, delay: float) -> void:
	effects.append({"kind": "boom", "to": at, "t0": _clock + delay, "dur": 0.55 if big else 0.3, "big": big})

func add_number(at: Vector2i, text: String, col: Color, delay: float) -> void:
	effects.append({"kind": "num", "to": at, "t0": _clock + delay, "dur": 0.9, "text": text, "color": col})

# A Missile or Nuke flying from its launch site `from` to `to` (an arc, `travel` s).
func add_item_flight(from: Vector2i, to: Vector2i, nuke: bool, travel: float) -> void:
	effects.append({"kind": "item", "from": from, "to": to, "t0": _clock, "dur": travel, "nuke": nuke})

# Its explosion at `to`, reaching `radius` hexes, after `delay` s.
func add_blast(to: Vector2i, radius: int, nuke: bool, delay: float) -> void:
	effects.append({"kind": "blast", "to": to, "t0": _clock + delay, "dur": 2.6 if nuke else 1.0, "radius": radius, "nuke": nuke})

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
	_walks_changed()

# A real move (MapWar.move): the card already stands on the path's last hex; show it
# walking there from the first one, `step` seconds per hex.
func animate_move(path: Array, step: float) -> void:
	if path.size() < 2:
		return
	var dest: Vector2i = path[path.size() - 1]
	var rev: Array = path.duplicate()
	rev.reverse()
	walks[MapCampaign.key_of(dest.x, dest.y)] = {"path": rev, "t0": _clock, "step": maxf(step, 0.001), "back": true}
	_walks_changed()
	redraw_layers()

func walk_back(k: String) -> void:
	if walks.has(k):
		walks[k]["back"] = true
		walks[k]["t0"] = _clock

func clear_walks() -> void:
	walks.clear()
	_walks_changed()

# A card started or stopped marching: it moves between the units and walkers layers.
func _walks_changed() -> void:
	_last_walk_n = walks.size()
	for layer in [_units, _walkers, _chips, _text_layer]:
		if layer != null:
			_redraw(layer)

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

# True while a ground card is on a sea hex, marching or parked there (it rides a boat).
func at_sea(k: String) -> bool:
	if war == null or not war.units.has(k):
		return false
	var card: Card = war.units[k]["card"]
	if card is Unit and (card as Unit).Flying:
		return false
	var w: Dictionary = walks.get(k, {})
	if w.is_empty():
		var here := MapWar.key_to_hex(k)
		return not WorldMap.is_land(here.x, here.y)
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

# A unit hemmed in by enemies: red arrows pointing in at it, two when flanked (+1),
# four when surrounded (+2), all six when encircled (+4).
func _draw_flank_marks(c: Vector2, s: float, bonus: int) -> void:
	var n := 2 if bonus <= MapWar.FLANK_FLANKED else (4 if bonus <= MapWar.FLANK_SURROUNDED else 6)
	var dirs: Array = {2: [0, 3], 4: [0, 1, 3, 4], 6: [0, 1, 2, 3, 4, 5]}[n]
	var pulse: float = 0.8 + 0.2 * sin(_clock * 7.0)
	var push: float = s * 0.06 * sin(_clock * 7.0) # the arrows jab inwards
	for i in dirs:
		var ang: float = float(i) * TAU / 6.0
		var d := Vector2(cos(ang), sin(ang))
		var tip: Vector2 = c + d * (s * 0.62 - push)
		var base: Vector2 = c + d * (s * 1.12 - push)
		var side := Vector2(-d.y, d.x) * s * 0.3
		var tri := PackedVector2Array([tip, base + side, base - side])
		var outline := tri.duplicate()
		outline.append(tri[0])
		_ci.draw_colored_polygon(tri, Color(1.0, 0.25, 0.18, pulse))
		_ci.draw_polyline(outline, Color(0.05, 0.04, 0.08, 0.95), maxf(2.0, s * 0.07))
		_ci.draw_line(tip.lerp(base, 0.25), tip.lerp(base, 0.8), Color(1.0, 0.85, 0.7, 0.8 * pulse), maxf(1.0, s * 0.04))

# Pixel boat under a card crossing the sea: wake behind, then the hull drawn over
# the sprite's feet so the unit stands inside it. Bow points along `facing`.
func _draw_boat_wake(c: Vector2, s: float, facing: float) -> void:
	var foam := Color(0.85, 0.95, 1.0, 0.75)
	for i in range(3):
		var wx: float = -facing * s * (1.15 + i * 0.32)
		var ph: float = fmod(_clock * 3.0 + i * 0.33, 1.0)
		_ci.draw_line(c + Vector2(wx, s * (0.6 - 0.12 * i)), c + Vector2(wx - facing * s * 0.25, s * (0.66 - 0.08 * i)), Color(foam.r, foam.g, foam.b, foam.a * (1.0 - ph * 0.6)), maxf(1.5, s * 0.08))
	_ci.draw_line(c + Vector2(-s * 1.0, s * 0.7), c + Vector2(s * 1.0, s * 0.7), Color(foam.r, foam.g, foam.b, 0.35), maxf(1.5, s * 0.09))

func _draw_boat_hull(c: Vector2, s: float, nc: Color, facing: float) -> void:
	var pts := PackedVector2Array()
	for p in [Vector2(-0.98, 0.24), Vector2(1.35, 0.0), Vector2(0.66, 0.68), Vector2(-0.88, 0.68)]:
		pts.append(c + Vector2(p.x * facing, p.y) * s)
	var outline := pts.duplicate()
	outline.append(pts[0])
	_ci.draw_colored_polygon(pts, Color(0.46, 0.28, 0.15))
	# nation-coloured stripe under the gunwale, then plank lines
	var stripe := PackedVector2Array([pts[0], pts[1], pts[1].lerp(pts[2], 0.32), pts[0].lerp(pts[3], 0.32)])
	_ci.draw_colored_polygon(stripe, nc)
	_ci.draw_line(pts[0].lerp(pts[3], 0.66), pts[1].lerp(pts[2], 0.66), Color(0.3, 0.17, 0.09), maxf(1.0, s * 0.06))
	_ci.draw_polyline(outline, Color(0.08, 0.05, 0.1), maxf(1.5, s * 0.09))
	_ci.draw_line(pts[0], pts[1], Color(0.8, 0.6, 0.38), maxf(1.0, s * 0.06))

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
	_ci.draw_polyline(pts, Color(col.r, col.g, col.b, col.a * 0.25), width * 3.0)
	_ci.draw_polyline(pts, col, width)

# Barracks: golden hex ripples washing over the ring of hexes it buffs.
func _draw_barracks_ripples(m: Array) -> void:
	var s: float = m[0]
	for t in _ucache_barracks:
		for cp in _visible_copies(t, m, s * 3.0):
			for wave_i in range(2):
				var ph: float = fposmod(_clock * 0.45 + wave_i * 0.5 + float(t.x * 7 + t.y) * 0.013, 1.0)
				var a: float = (1.0 - ph) * 0.6 * minf(ph * 6.0, 1.0)
				var rad: float = s * (0.9 + ph * 1.35)
				var e: float = rad * FX_HEX_SPAN
				_ci.draw_texture_rect_region(_fx_texture(), Rect2((cp as Vector2) - Vector2(e, e), Vector2(e, e) * 2.0), _fx(FX_HEX, rad), Color(GOLD.r, GOLD.g, GOLD.b, a))

# The per-unit animations (buff rings, chevrons, shield bubbles, glints, Barracks
# ripples) are sprites cut from one small texture baked at start-up, moved, turned
# and tinted per frame: hundreds of them still batch into a few draw calls, where
# drawing each from arcs and polylines cost a draw call per stroke.
# Each comes in two stroke weights: the old strokes had a minimum width in pixels,
# so on small hexes (the whole world fits on screen) they are relatively bolder.
const FX_BUFF := Rect2(0, 0, 96, 96)       # glow disc + 6 dashes on a ring (radius 0.92 of 1.25)
const FX_HEX := Rect2(96, 0, 96, 96)       # glowing hex outline (radius 1 of 1.2)
const FX_SHIELD := Rect2(192, 0, 96, 96)   # hex bubble: faint fill + glowing rim (radius 1 of 1.2)
const FX_CHEVRON := Rect2(288, 0, 48, 48)  # double chevron (x -0.5..0.5, y -0.3..0.7 of the hex size)
const FX_DOT := Rect2(336, 0, 16, 16)      # soft white dot
const FX_BOLD := Vector2(0, 96)            # offset of the bold copy of each (not the dot)
const FX_BOLD_BELOW := 20.0                # px: hexes / rings smaller than this use the bold copy
const FX_RING_SPAN := 1.25 # FX_BUFF covers -1.25..1.25 of the hex size
const FX_HEX_SPAN := 1.2   # FX_HEX / FX_SHIELD cover -1.2..1.2 of the hex radius
var _fx_tex: ImageTexture = null

# `cell` in the stroke weight for something `px` pixels across (hex size or radius).
static func _fx(cell: Rect2, px: float) -> Rect2:
	return Rect2(cell.position + FX_BOLD, cell.size) if px < FX_BOLD_BELOW else cell

func _fx_texture() -> ImageTexture:
	if _fx_tex != null:
		return _fx_tex
	var img := Image.create(352, 192, false, Image.FORMAT_RGBA8)
	var light := Color(1, 0.93, 0.6)
	var dark := Color(0.08, 0.06, 0.12)
	for bold in [false, true]:
		# half stroke widths (hex-size units): [glow/outline, bright line]
		var ring_w: Array = [0.25, 0.105] if bold else [0.15, 0.06]
		var hex_w: Array = [0.25, 0.08] if bold else [0.12, 0.04]
		var chev_w: Array = [0.21, 0.105] if bold else [0.12, 0.06]
		for cell in [FX_BUFF, FX_HEX, FX_SHIELD, FX_CHEVRON, FX_DOT]:
			var r: Rect2 = cell
			if bold and r == FX_DOT:
				continue
			var at := r.position + (FX_BOLD if bold else Vector2.ZERO)
			var n: int = int(r.size.x)
			for py in range(n):
				for px in range(n):
					var u := Vector2((px + 0.5) / n, (py + 0.5) / n) # 0..1 across the cell
					var col := Color(0, 0, 0, 0)
					if r == FX_BUFF:
						var q := (u * 2.0 - Vector2.ONE) * FX_RING_SPAN
						var aa: float = 2.0 * FX_RING_SPAN / n
						col = _over(col, Color(GOLD.r, GOLD.g, GOLD.b, 0.17 * _cover(q.length() - 1.05, aa)))
						var d := _dist_to_dashes(q, 0.92)
						col = _over(col, Color(GOLD.r, GOLD.g, GOLD.b, 0.35 * _cover(d - float(ring_w[0]), aa)))
						col = _over(col, Color(light.r, light.g, light.b, _cover(d - float(ring_w[1]), aa)))
					elif r == FX_HEX or r == FX_SHIELD:
						var q := (u * 2.0 - Vector2.ONE) * FX_HEX_SPAN
						var aa: float = 2.0 * FX_HEX_SPAN / n
						var sd := _hex_sd(q)
						if r == FX_SHIELD:
							col = _over(col, Color(1, 1, 1, 0.083 * _cover(sd, aa)))
						var glow := 0.125 if r == FX_SHIELD else 0.25
						var line := 0.5 if r == FX_SHIELD else 1.0
						col = _over(col, Color(1, 1, 1, glow * _cover(absf(sd) - float(hex_w[0]), aa)))
						col = _over(col, Color(1, 1, 1, line * _cover(absf(sd) - float(hex_w[1]), aa)))
					elif r == FX_CHEVRON:
						var q := Vector2(u.x - 0.5, u.y - 0.3) # hex-size units
						var aa: float = 1.0 / n
						for j in range(2):
							var y: float = j * 0.26
							var d: float = minf(_seg_dist(q, Vector2(-0.3, y + 0.225), Vector2(0, y)), _seg_dist(q, Vector2(0, y), Vector2(0.3, y + 0.225)))
							var c2: Color = Color(1, 0.93, 0.55).lerp(GOLD, 0.5 * j)
							col = _over(col, Color(dark.r, dark.g, dark.b, _cover(d - float(chev_w[0]), aa)))
							col = _over(col, Color(c2.r, c2.g, c2.b, _cover(d - float(chev_w[1]), aa)))
					else: # FX_DOT
						var q := u * 2.0 - Vector2.ONE
						col = Color(1, 1, 1, _cover(q.length() - 0.8, 2.0 / n))
					img.set_pixel(int(at.x) + px, int(at.y) + py, col)
	_fx_tex = ImageTexture.create_from_image(img)
	return _fx_tex

# Anti-aliased coverage of a shape at signed distance `sd` (pixel size `aa`).
static func _cover(sd: float, aa: float) -> float:
	return clampf(0.5 - sd / aa, 0.0, 1.0)

static func _over(under: Color, top: Color) -> Color:
	return under.blend(top) if top.a > 0.0 else under

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))

# Signed distance to a pointy-top hex of circumradius 1 (negative inside).
static func _hex_sd(p: Vector2) -> float:
	var d := -INF
	for k in range(6):
		var ang: float = deg_to_rad(60.0 * k)
		d = maxf(d, p.dot(Vector2(cos(ang), sin(ang))))
	return d - 0.8660254

# Distance to the buff ring's 6 dashes (radius `rad`, each TAU/11 long, one every TAU/6).
static func _dist_to_dashes(p: Vector2, rad: float) -> float:
	var ang: float = fposmod(p.angle(), TAU)
	var best := INF
	for i in range(6):
		var a0: float = i * TAU / 6.0
		var a1: float = a0 + TAU / 11.0
		if ang >= a0 and ang <= a1:
			best = minf(best, absf(p.length() - rad))
		else:
			best = minf(best, minf(p.distance_to(Vector2(cos(a0), sin(a0)) * rad), p.distance_to(Vector2(cos(a1), sin(a1)) * rad)))
	return best

# Buffed unit: warm glow + rotating dashed gold ring at its feet...
func _draw_buff_aura(c: Vector2, s: float, seed_i: int) -> void:
	var fx := _fx_texture()
	var base := c + Vector2(0, s * 0.45)
	var pulse: float = 0.5 + 0.5 * sin(_clock * 3.0 + seed_i)
	var rot: float = _clock * 1.6 + seed_i
	# turn the ring, then squash it flat onto the ground
	_ci.draw_set_transform_matrix(Transform2D(Vector2(cos(rot), 0.45 * sin(rot)), Vector2(-sin(rot), 0.45 * cos(rot)), base))
	var e: float = s * FX_RING_SPAN
	_ci.draw_texture_rect_region(fx, Rect2(-e, -e, e * 2.0, e * 2.0), _fx(FX_BUFF, s), Color(1, 1, 1, 0.8 + 0.2 * pulse))
	_ci.draw_set_transform_matrix(Transform2D.IDENTITY)

# ...and its bobbing double chevron, drawn over the units so neighbours can't hide it.
func _draw_buff_chevron(c: Vector2, s: float, seed_i: int) -> void:
	var bob: float = sin(_clock * 3.0 + seed_i) * s * 0.08
	var p := c + Vector2(s * 0.8, -s * 0.85 + bob)
	_ci.draw_texture_rect_region(_fx_texture(), Rect2(p + Vector2(-0.5, -0.3) * s, Vector2(s, s)), _fx(FX_CHEVRON, s))

# Shielded unit: faint cyan hex bubble with a bright glint running round its edge.
func _draw_shield_aura(c: Vector2, s: float, seed_i: int) -> void:
	var fx := _fx_texture()
	var r: float = s * 0.95
	var shimmer: float = 0.35 + 0.15 * sin(_clock * 2.5 + seed_i)
	var e: float = r * FX_HEX_SPAN
	_ci.draw_texture_rect_region(fx, Rect2(c - Vector2(e, e), Vector2(e, e) * 2.0), _fx(FX_SHIELD, r), Color(CYAN.r, CYAN.g, CYAN.b, shimmer / 0.42 * 0.84))
	var u: float = fposmod(_clock * 0.55 + seed_i * 0.17, 1.0) * 6.0
	var k := int(u)
	var f: float = u - k
	var a: Vector2 = c + _corner_unit[k] * r
	var b: Vector2 = c + _corner_unit[(k + 1) % 6] * r
	var dot: float = maxf(1.5, s * 0.07)
	for i in range(3): # the glint and its fading tail
		var t: float = f - i * 0.15
		if t < 0.0:
			break
		var rr: float = dot * (1.3 - i * 0.3)
		_ci.draw_texture_rect_region(fx, Rect2(a.lerp(b, t) - Vector2(rr, rr), Vector2(rr, rr) * 2.0), FX_DOT, Color(0.85, 1, 1, 0.95 - i * 0.3))

# [entry, screen centre, at sea, boat facing] for every on-screen copy of `ents`.
func _visible_units(m: Array, ents: Array) -> Array:
	var margin: float = float(m[0]) * 2.0
	var vis: Array = []
	for e in ents:
		var k: String = e["k"]
		var walking := walks.has(k)
		var shift := unit_offset(k, m) if walking else Vector2.ZERO
		var cps := _visible_copies(e["t"], m, margin + shift.length())
		if cps.is_empty():
			continue
		var sea: bool = at_sea(k) if walking else bool(e["sea"])
		var facing := _walk_facing(k, m) if (sea and walking) else 1.0
		for cp in cps:
			vis.append([e, (cp as Vector2) + shift, sea, facing])
	return vis

# The few units with animated marks (auras, flank arrows, boats) and any marching ones.
func _marked_units(m: Array) -> Array:
	unit_cache()
	var ents: Array = _ucache_marked.duplicate()
	for k in walks.keys():
		if _ucache_by_key.has(k) and not ents.has(_ucache_by_key[k]):
			ents.append(_ucache_by_key[k])
	return _visible_units(m, ents)

# Units layer: bases, sprites, boats and HP bars of every card on screen. Each kind
# of mark goes in its own pass: the bases, the sprites and the bars each share one
# texture, so the renderer batches the whole army's into a few draw calls instead of
# switching state for every unit.
func _draw_units(m: Array, ents: Array, with_ghosts: bool) -> void:
	var s: float = m[0]
	var vis := _visible_units(m, ents)
	var base_tex := _unit_base_tex()
	var base_size := Vector2(s * 1.44, s * 0.648)
	for v in vis:
		if not v[2]:
			_ci.draw_texture_rect(base_tex, Rect2((v[1] as Vector2) + Vector2(0, s * 0.45) - base_size * 0.5, base_size), false, v[0]["nc"])
	var side: float = s * 2.1
	var tick: int = int(_clock * 4.0)
	for v in vis:
		var e: Dictionary = v[0]
		var c: Vector2 = v[1]
		var dst := Rect2(c - Vector2(side * 0.5, side * 0.62), Vector2(side, side))
		var regions: Array = e["regions"]
		if not regions.is_empty():
			_ci.draw_texture_rect_region(_sprite_atlas, dst, regions[(tick + int(e["frame_off"])) % regions.size()])
		else:
			var frames: Array = e["frames"]
			if not frames.is_empty():
				_ci.draw_texture_rect(frames[(tick + int(e["frame_off"])) % frames.size()], dst, false)
		if v[2]:
			_draw_boat_hull(c, s, e["nc"], v[3]) # the hull goes over the sprite's feet
	# HP bar under each unit
	var bwid: float = s * 1.3
	var bh: float = maxf(2.0, s * 0.16)
	for v in vis:
		var e: Dictionary = v[0]
		var card: Card = e["card"]
		var hp: int = int(hp_shown.get(e["k"], war.card_hp(card)))
		var mx: int = int(card.get_meta("map_max_hp", maxi(hp, 1)))
		var frac: float = clampf(float(hp) / float(maxi(mx, 1)), 0.0, 1.0)
		var r := Rect2((v[1] as Vector2) + Vector2(-bwid * 0.5, s * 0.72), Vector2(bwid, bh))
		_ci.draw_rect(r.grow(1.0), Color(0.05, 0.04, 0.08, 0.9), true)
		_ci.draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), Color(1.0 - frac, 0.35 + 0.6 * frac, 0.25), true)
	if not with_ghosts:
		return
	var margin: float = s * 2.0
	# cards the logic already destroyed, standing until the shot that kills them
	for gk in ghosts.keys():
		var gd: Dictionary = ghosts[gk]
		var gt := MapWar.key_to_hex(str(gk))
		var gnc: Color = _nation_colors.get(str(gd["owner"]), Color.WHITE)
		var gfrac: float = clampf(float(gd["hp"]) / float(maxi(int(gd["max"]), 1)), 0.0, 1.0)
		for cp in _visible_copies(gt, m, margin):
			var gc := cp as Vector2
			_ci.draw_texture_rect(base_tex, Rect2(gc + Vector2(0, s * 0.45) - base_size * 0.5, base_size), false, gnc)
			_draw_card(str(gd["name"]), gc, s, Color.WHITE, gt.x + gt.y, str(gd["owner"]))
			var gw: float = s * 1.3
			var gr := Rect2(gc + Vector2(-gw * 0.5, s * 0.72), Vector2(gw, maxf(2.0, s * 0.16)))
			_ci.draw_rect(gr.grow(1.0), Color(0.05, 0.04, 0.08, 0.9), true)
			_ci.draw_rect(Rect2(gr.position, Vector2(gr.size.x * gfrac, gr.size.y)), Color(1.0 - gfrac, 0.35 + 0.6 * gfrac, 0.25), true)

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
	redraw_layers()

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
	redraw_layers()

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
	release_scars()
	ghosts.clear()
	hp_shown.clear()
	flag_hp_shown.clear()
	flag_site_shown.clear()
	_redraw_all()

# Capital flags are targets: show each living nation's HP under its flag.
func _draw_flag_hp(m: Array) -> void:
	var s: float = m[0]
	for nm in war.players.keys():
		if _dead.has(nm) or _campaign == null:
			continue
		var p: Player = war.players[nm]
		var fhp: int = int(flag_hp_shown.get(nm, p.HitPoints))
		var frac: float = clampf(float(fhp) / float(maxi(p.MaxHitPoints, 1)), 0.0, 1.0)
		var nc: Color = _nation_colors.get(nm, Color.WHITE)
		for cp in _visible_copies(flag_site_shown.get(nm, capital_site(str(nm))), m, s * 3.0):
			var bw: float = s * 2.0
			var r := Rect2((cp as Vector2) + Vector2(-bw * 0.5, s * 1.0), Vector2(bw, maxf(3.0, s * 0.2)))
			_ci.draw_rect(r.grow(1.5), Color8(20, 16, 30), true)
			_ci.draw_rect(r.grow(0.5), Color(1.0, 0.86, 0.35), false, 1.0)
			_ci.draw_rect(Rect2(r.position, Vector2(r.size.x * frac, r.size.y)), nc.lightened(0.15), true)

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
				_ci.draw_line(tail, head, Color(col.r, col.g, col.b, 0.55), maxf(1.5, s * 0.12))
				_ci.draw_circle(head, maxf(1.5, s * 0.16), col)
			"boom":
				var big: bool = e["big"]
				var rad: float = s * (0.4 + k * (1.6 if big else 0.9))
				var alpha: float = 1.0 - k
				_ci.draw_circle(to_c, rad, Color(1.0, 0.55, 0.15, 0.55 * alpha))
				_ci.draw_circle(to_c, rad * 0.6, Color(1.0, 0.92, 0.5, 0.8 * alpha))
				_ci.draw_arc(to_c, rad * 1.1, 0.0, TAU, 18, Color(1, 1, 1, 0.6 * alpha), 1.5)
			"buff":
				var ease_k: float = 1.0 - pow(1.0 - k, 3.0)
				var fade: float = 1.0 - k
				_ci.draw_circle(to_c, s * (0.5 + ease_k * 0.9), Color(GOLD.r, GOLD.g, GOLD.b, 0.18 * fade))
				_ci.draw_arc(to_c, s * (0.45 + ease_k * 1.25), 0.0, TAU, 28, Color(GOLD.r, GOLD.g, GOLD.b, 0.35 * fade), 6.0)
				_ci.draw_arc(to_c, s * (0.45 + ease_k * 1.25), 0.0, TAU, 28, Color(1, 0.95, 0.7, fade), 2.0)
				for ray in range(8):
					var ang: float = ray * TAU / 8.0 + k * 1.2
					var d0: float = s * (0.35 + ease_k * 0.9)
					var d1: float = d0 + s * 0.45 * fade
					_ci.draw_line(to_c + Vector2(cos(ang), sin(ang)) * d0, to_c + Vector2(cos(ang), sin(ang)) * d1, Color(GOLD.r, GOLD.g, GOLD.b, fade), 2.0)
				var cy: float = to_c.y - s * (0.7 + ease_k * 1.3)
				var w: float = s * 0.3
				for j in range(2):
					var yy: float = cy + j * s * 0.26
					var chev := PackedVector2Array([Vector2(to_c.x - w, yy + w * 0.7), Vector2(to_c.x, yy), Vector2(to_c.x + w, yy + w * 0.7)])
					_ci.draw_polyline(chev, Color(0.08, 0.06, 0.12, fade), maxf(4.0, s * 0.2))
					_ci.draw_polyline(chev, Color(GOLD.r, GOLD.g, GOLD.b, fade), maxf(2.0, s * 0.1))
			"counter":
				var fa := screen_pos(e["from"] as Vector2i, m) - Vector2(0, s * 0.6)
				var fb := _wrap_target(fa, to_c, m)
				# an interceptor missile: climbs off its launcher, then streaks at the hit
				var path := func(u: float) -> Vector2:
					var uk: float = u * u # accelerates towards the hit
					return fa.lerp(fb, uk) - Vector2(0, sin(u * PI) * minf(fa.distance_to(fb) * 0.35, s * 3.0))
				_draw_smoke_trail(path, k, s, 7, Color(0.85, 0.95, 1.0))
				var head2: Vector2 = path.call(k)
				_draw_missile(head2, head2 - path.call(maxf(0.0, k - 0.02)), maxf(7.0, s * 0.7), CYAN, false)
			"shield":
				var ek: float = 1.0 - pow(1.0 - k, 2.0)
				var fade2: float = 1.0 - k
				var r: float = s * (0.95 + ek * 0.35)
				var hex := _hex_points(to_c, r)
				_ci.draw_colored_polygon(hex, Color(CYAN.r, CYAN.g, CYAN.b, 0.32 * fade2))
				for cc in range(3):
					_ci.draw_line(hex[cc], hex[cc + 3], Color(0.85, 1, 1, 0.45 * fade2), 1.5)
				var inner := _hex_poly(to_c, r * 0.55)
				_ci.draw_polyline(inner, Color(0.85, 1, 1, 0.5 * fade2), 1.5)
				_glow_polyline(_hex_poly(to_c, r), Color(0.8, 1, 1, fade2), 2.5)
				for sp in range(10):
					var sa: float = sp * TAU / 10.0 + 0.3
					var sd: float = s * (1.0 + ek * 1.0)
					_ci.draw_circle(to_c + Vector2(cos(sa), sin(sa)) * sd, maxf(1.0, s * 0.06 * fade2), Color(0.85, 1, 1, fade2))
			"item":
				var ia := screen_pos(e["from"] as Vector2i, m) - Vector2(0, s * 0.5)
				var ib := _wrap_target(ia, to_c, m)
				var nuke: bool = e["nuke"]
				var height: float = clampf(ia.distance_to(ib) * 0.45, s * 2.0, s * 9.0)
				var ipath := func(u: float) -> Vector2:
					return ia.lerp(ib, u) - Vector2(0, sin(u * PI) * height) # a ballistic arc
				_draw_smoke_trail(ipath, k, s, 12 if nuke else 9, Color(0.8, 0.8, 0.82))
				var ih: Vector2 = ipath.call(k)
				_draw_missile(ih, ih - ipath.call(maxf(0.0, k - 0.02)), maxf(10.0, s * (1.3 if nuke else 0.95)), Color(0.95, 0.8, 0.2) if nuke else Color(1, 0.3, 0.25), nuke)
			"blast":
				_draw_blast(to_c, s, k, int(e["radius"]), bool(e["nuke"]))
			"wreck":
				_draw_card(str(e["name"]), to_c, s, Color(1, 0.5, 0.45, 0.9 - 0.4 * k), 0, str(e.get("owner", "")))
			"place":
				_ci.draw_arc(to_c, s * (0.6 + k * 0.8), 0.0, TAU, 20, Color(0.6, 1.0, 0.45, 1.0 - k), 2.0)

# A missile at `p` heading along `dir`, `l` pixels long: flickering exhaust, fins,
# body, warhead (nuke: fat, olive with a yellow band and nose).
func _draw_missile(p: Vector2, dir: Vector2, l: float, tip: Color, nuke: bool) -> void:
	var d := dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	var nv := Vector2(-d.y, d.x)
	var w: float = l * (0.3 if nuke else 0.2)
	var tail := p - d * l * 0.5
	var fl: float = l * (0.45 + 0.18 * sin(_clock * 47.0))
	_ci.draw_colored_polygon(PackedVector2Array([tail + nv * w * 0.55, tail - nv * w * 0.55, tail - d * fl]), Color(1.0, 0.55, 0.12, 0.9))
	_ci.draw_colored_polygon(PackedVector2Array([tail + nv * w * 0.3, tail - nv * w * 0.3, tail - d * fl * 0.6]), Color(1.0, 0.95, 0.6))
	var fin := Color(0.25, 0.27, 0.32)
	for side in [1.0, -1.0]:
		_ci.draw_colored_polygon(PackedVector2Array([tail + nv * w * 0.5 * side, tail + nv * w * 1.15 * side - d * l * 0.06, tail + d * l * 0.22 + nv * w * 0.5 * side]), fin)
	var body := Color(0.45, 0.5, 0.32) if nuke else Color(0.88, 0.9, 0.94)
	var front := p + d * l * 0.22
	var hull := PackedVector2Array([tail + nv * w * 0.5, front + nv * w * 0.5, front - nv * w * 0.5, tail - nv * w * 0.5])
	_ci.draw_colored_polygon(hull, body)
	if nuke:
		var band := tail + d * l * 0.35
		_ci.draw_colored_polygon(PackedVector2Array([band + nv * w * 0.5, band + d * l * 0.1 + nv * w * 0.5, band + d * l * 0.1 - nv * w * 0.5, band - nv * w * 0.5]), Color(0.95, 0.8, 0.2))
	var nose := PackedVector2Array([front + nv * w * 0.5, p + d * l * 0.5, front - nv * w * 0.5])
	_ci.draw_colored_polygon(nose, tip)
	var outline := PackedVector2Array([tail + nv * w * 0.5, front + nv * w * 0.5, p + d * l * 0.5, front - nv * w * 0.5, tail - nv * w * 0.5, tail + nv * w * 0.5])
	_ci.draw_polyline(outline, Color(0.06, 0.05, 0.1, 0.9), maxf(1.0, l * 0.05))

# Puffs left behind along `path` (a Callable u -> screen point, u in 0..1) up to `k`.
func _draw_smoke_trail(path: Callable, k: float, s: float, puffs: int, col: Color) -> void:
	for i in range(puffs, 0, -1):
		var u: float = k - i * 0.035
		if u <= 0.0:
			continue
		var f: float = float(i) / float(puffs + 1)
		_ci.draw_circle(path.call(u), maxf(1.5, s * (0.1 + 0.32 * f)), Color(col.r, col.g, col.b, 0.55 * (1.0 - f)))

# A Missile's or Nuke's explosion at `c`, `k` 0..1 through it, covering `radius` hexes.
func _draw_blast(c: Vector2, s: float, k: float, radius: int, nuke: bool) -> void:
	var reach: float = (float(radius) + 0.5) * s * SQRT3 # to the outer hexes' far edge
	var ease_k: float = 1.0 - pow(1.0 - k, 3.0)
	var fade: float = 1.0 - k
	if nuke:
		if k < 0.25: # the flash
			_ci.draw_circle(c, reach * (0.6 + k * 2.0), Color(1, 1, 0.92, 0.85 * (1.0 - k / 0.25)))
		# shockwave racing out over the whole blast
		var wave_k := clampf(k / 0.55, 0.0, 1.0)
		if wave_k < 1.0:
			_ci.draw_arc(c, reach * wave_k, 0.0, TAU, 64, Color(1, 0.95, 0.8, 0.8 * (1.0 - wave_k)), maxf(3.0, s * 0.35))
			_ci.draw_arc(c, reach * wave_k * 0.93, 0.0, TAU, 64, Color(1, 0.6, 0.2, 0.4 * (1.0 - wave_k)), maxf(6.0, s * 0.7))
		# scorched ground and the fireball under the cloud
		_ci.draw_circle(c, reach * 0.55 * ease_k, Color(0.25, 0.12, 0.05, 0.35 * fade))
		_ci.draw_circle(c, s * (0.8 + 1.6 * ease_k), Color(1.0, 0.45 + 0.3 * fade, 0.1, 0.85 * fade))
		# mushroom cloud: a stem rising into a rolling cap
		var rise: float = s * 6.5 * ease_k
		var top := c - Vector2(0, rise)
		var stem_w: float = s * (0.5 + 0.4 * ease_k)
		var smoke := Color(0.55, 0.45, 0.4).lerp(Color(1.0, 0.55, 0.2), clampf(1.0 - k * 1.6, 0.0, 1.0))
		_ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-stem_w, 0), top + Vector2(-stem_w * 0.6, 0), top + Vector2(stem_w * 0.6, 0), c + Vector2(stem_w, 0)]), Color(smoke.r, smoke.g, smoke.b, 0.85 * fade))
		var cap_r: float = s * (1.2 + 2.4 * ease_k)
		_ci.draw_set_transform(top, 0.0, Vector2(1.0, 0.6))
		_ci.draw_circle(Vector2.ZERO, cap_r, Color(smoke.r, smoke.g, smoke.b, 0.9 * fade))
		_ci.draw_circle(Vector2(0, -cap_r * 0.25), cap_r * 0.7, Color(smoke.r + 0.15, smoke.g + 0.1, smoke.b + 0.05, 0.8 * fade))
		_ci.draw_circle(Vector2(0, cap_r * 0.3), cap_r * 0.45, Color(1.0, 0.7, 0.3, 0.6 * fade * clampf(1.5 - k * 2.0, 0.0, 1.0)))
		_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if k < 0.2:
		_ci.draw_circle(c, reach * 0.5, Color(1, 1, 0.9, 0.8 * (1.0 - k / 0.2)))
	_ci.draw_circle(c, reach * (0.3 + 0.6 * ease_k), Color(1.0, 0.5, 0.15, 0.55 * fade))
	_ci.draw_circle(c, reach * (0.15 + 0.35 * ease_k), Color(1.0, 0.9, 0.45, 0.8 * fade))
	_ci.draw_arc(c, reach * (0.2 + 0.9 * ease_k), 0.0, TAU, 40, Color(1, 1, 1, 0.7 * fade), maxf(2.0, s * 0.15))
	for ray in range(10):
		var ang: float = ray * TAU / 10.0 + 0.4
		var d0: float = reach * (0.25 + 0.8 * ease_k)
		_ci.draw_line(c + Vector2(cos(ang), sin(ang)) * d0, c + Vector2(cos(ang), sin(ang)) * (d0 + s * 0.4 * fade), Color(1, 0.8, 0.3, fade), 2.0)

# ------------------------------------------------------------ scars
# Ruins and nuclear wasteland (MapWar.scars) are drawn on the grid layer. While an
# attack plays out the screen keeps showing the scars from before it (hold_scars),
# revealing each new one as its shot lands (reveal_scars) or when the replay ends.
var _scars_held: Variant = null # Dictionary while held, else null (show war.scars)

func _scars() -> Dictionary:
	if _scars_held != null:
		return _scars_held
	return war.scars if war != null else {}

func hold_scars() -> void:
	if war != null and _scars_held == null:
		_scars_held = war.scars.duplicate()

func reveal_scars(hexes: Array) -> void:
	if _scars_held == null or war == null:
		return
	for h in hexes:
		var k := MapCampaign.key_of((h as Vector2i).x, (h as Vector2i).y)
		if war.scars.has(k):
			_scars_held[k] = war.scars[k]
	_redraw(_grid)

func release_scars() -> void:
	_scars_held = null
	_redraw(_grid)

func _draw_scars(m: Array) -> void:
	var sc := _scars()
	if sc.is_empty():
		return
	var s: float = m[0]
	for k in sc.keys():
		var t := MapWar.key_to_hex(str(k))
		for cp in _visible_copies(t, m, s * 2.0):
			if str(sc[k]) == "wasteland":
				_draw_wasteland(cp as Vector2, s)
			else:
				_draw_ruins(cp as Vector2, s, t)

# Rubble: a dusty tint, a few toppled blocks and a broken wall stub.
func _draw_ruins(c: Vector2, s: float, t: Vector2i) -> void:
	_grid.draw_colored_polygon(_hex_points(c, s * 0.97), Color(0.3, 0.25, 0.2, 0.55))
	if s < 5.0:
		return
	var seed_i: int = t.x * 31 + t.y * 17
	for b in range(5):
		var a: float = float((seed_i * (b + 3)) % 360) * PI / 180.0
		var r: float = s * (0.15 + 0.12 * float((seed_i + b * 7) % 5))
		var sz: float = s * (0.16 + 0.05 * float((seed_i + b) % 3))
		var p := c + Vector2(cos(a), sin(a) * 0.7) * r
		_grid.draw_rect(Rect2(p - Vector2(sz, sz * 0.7) * 0.5, Vector2(sz, sz * 0.7)), Color(0.08, 0.06, 0.06, 0.9), true)
		_grid.draw_rect(Rect2(p - Vector2(sz, sz * 0.7) * 0.5 + Vector2(1, 1), Vector2(sz - 2.0, sz * 0.7 - 2.0)), Color(0.62, 0.55, 0.47) if b % 2 == 0 else Color(0.55, 0.36, 0.26), true)
	# a broken wall stub
	var w0 := c + Vector2(-s * 0.45, s * 0.1)
	_grid.draw_line(w0, w0 + Vector2(0, -s * 0.45), Color(0.08, 0.06, 0.06), maxf(3.0, s * 0.2))
	_grid.draw_line(w0, w0 + Vector2(0, -s * 0.4), Color(0.6, 0.52, 0.45), maxf(1.5, s * 0.12))

# Nuclear wasteland: a sickly glow with a radiation sign.
func _draw_wasteland(c: Vector2, s: float) -> void:
	_grid.draw_colored_polygon(_hex_points(c, s * 0.97), Color(0.45, 0.62, 0.1, 0.5))
	_grid.draw_colored_polygon(_hex_points(c, s * 0.6), Color(0.65, 0.85, 0.2, 0.25))
	if s < 6.0:
		return
	var r: float = s * 0.42
	_grid.draw_circle(c, r + 1.5, Color(0.08, 0.06, 0.06, 0.9))
	_grid.draw_circle(c, r, Color(1.0, 0.85, 0.15))
	for i in range(3): # the trefoil's three blades
		var a0: float = -PI / 2.0 + i * TAU / 3.0 - PI / 6.0
		var pts := PackedVector2Array([c])
		for j in range(7):
			var a: float = a0 + (PI / 3.0) * j / 6.0
			pts.append(c + Vector2(cos(a), sin(a)) * r * 0.85)
		_grid.draw_colored_polygon(pts, Color(0.08, 0.06, 0.06))
	_grid.draw_circle(c, r * 0.24, Color(1.0, 0.85, 0.15))
	_grid.draw_circle(c, r * 0.14, Color(0.08, 0.06, 0.06))

# Floating damage numbers, drawn with the UI font on a smoothly filtered layer.
func _draw_text_fx() -> void:
	var m := metrics()
	_mark_drawn(_text_layer, m)
	var s: float = m[0]
	if s < 2.0:
		return
	var font := get_theme_default_font()
	if war != null and s >= STAT_CHIP_MIN_HEX and not walks.is_empty():
		_draw_stat_chips(_text_layer, m, font, _walking_units())
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

func _draw_chip_layer() -> void:
	var m := metrics()
	_mark_drawn(_chips, m)
	if war == null or float(m[0]) < STAT_CHIP_MIN_HEX:
		return
	_draw_stat_chips(_chips, m, get_theme_default_font(), _standing_units())

# Stat chips under every card on the map: a heart and its HP (as shown, so they tick
# down with each hit during an attack replay) and, for units, a sword and the damage
# each shot deals from where it stands (Barracks, home ground and modifiers included;
# "2x4" for guns that fire 4 times). Hidden when zoomed far out.
const STAT_CHIP_MIN_HEX := 15.0 # hex radius in pixels below which the chips are hidden
# The chip art (a rounded see-through pill, drawn in three slices so it stretches
# to any width, plus the heart and sword) lives in one small texture, so every
# chip on the map draws in one batch, then all the text outlines, then the text.
const CHIP_PILL := Rect2(0, 0, 64, 32)
const CHIP_HEART := Rect2(72, 0, 32, 32)
const CHIP_SWORD := Rect2(112, 0, 32, 32)
const CHIP_ICON_SPAN := 1.1 # icon art covers -1.1r..1.1r of the icon radius r
var _chip_tex: ImageTexture = null
var _chip_text_w: Dictionary = {} # chip text -> width at _chip_fs
var _chip_fs: int = -1

func _chip_texture() -> ImageTexture:
	if _chip_tex != null:
		return _chip_tex
	var img := Image.create(152, 32, false, Image.FORMAT_RGBA8)
	var bg := Color(0.06, 0.05, 0.1, 0.45)
	var border := Color(1, 1, 1, 0.12)
	const SS := 4 # supersampling per axis
	for y in range(32):
		for x in range(152):
			var col := Color(0, 0, 0, 0)
			for sy in range(SS):
				for sx in range(SS):
					var px: float = x + (sx + 0.5) / SS
					var py: float = y + (sy + 0.5) / SS
					col += _chip_sample(px, py, bg, border) / float(SS * SS)
			img.set_pixel(x, y, col)
	_chip_tex = ImageTexture.create_from_image(img)
	return _chip_tex

# Colour of the chip art at texel (px, py), premultiplied-free (averaged by the caller).
func _chip_sample(px: float, py: float, bg: Color, border: Color) -> Color:
	if px < CHIP_PILL.end.x:
		# stadium: within 16px of the segment (16,16)-(48,16)
		var d: float = Vector2(clampf(px, 16.0, 48.0), 16.0).distance_to(Vector2(px, py))
		if d > 16.0:
			return Color(0, 0, 0, 0)
		return bg.blend(border) if d > 14.5 else bg
	if px >= CHIP_HEART.position.x and px < CHIP_HEART.end.x:
		var q := (Vector2(px, py) - CHIP_HEART.get_center()) / (16.0 / CHIP_ICON_SPAN)
		var inside: bool = q.distance_to(Vector2(-0.45, -0.25)) <= 0.52 or q.distance_to(Vector2(0.45, -0.25)) <= 0.52 \
			or Geometry2D.point_is_inside_triangle(q, Vector2(-0.95, -0.05), Vector2(0.95, -0.05), Vector2(0, 0.95))
		return Color.WHITE if inside else Color(0, 0, 0, 0)
	if px >= CHIP_SWORD.position.x and px < CHIP_SWORD.end.x:
		var q := (Vector2(px, py) - CHIP_SWORD.get_center()) / (16.0 / CHIP_ICON_SPAN)
		var g := Vector2(-0.35, 0.35) # crossguard over the blade
		if q.distance_to(Geometry2D.get_closest_point_to_segment(q, g + Vector2(-0.45, -0.45), g + Vector2(0.45, 0.45))) <= 0.15:
			return Color(1.0, 0.8, 0.35)
		if q.distance_to(Geometry2D.get_closest_point_to_segment(q, Vector2(-0.8, 0.8), Vector2(0.85, -0.85))) <= 0.16:
			return Color(0.92, 0.92, 1.0)
	return Color(0, 0, 0, 0)

func _draw_stat_chips(ci: CanvasItem, m: Array, font: Font, ents: Array) -> void:
	var s: float = m[0]
	var margin: float = s * 2.0
	var fs := int(clampf(s * 0.4, 10.0, 16.0))
	var pad: float = maxf(2.0, s * 0.06)
	var icon: float = fs * 0.62
	var h: float = fs + pad * 1.2
	if fs != _chip_fs:
		_chip_fs = fs
		_chip_text_w.clear()
	var tex := _chip_texture()
	var texts: Array = [] # [position, text, colour], drawn after every chip's art
	for e in ents:
		var k: String = e["k"]
		var walking := walks.has(k)
		var shift := unit_offset(k, m) if walking else Vector2.ZERO
		var cps := _visible_copies(e["t"], m, margin + shift.length())
		if cps.is_empty():
			continue
		var card: Card = e["card"]
		var hp: int = int(hp_shown.get(k, war.card_hp(card)))
		var mx: int = int(card.get_meta("map_max_hp", maxi(hp, 1)))
		var frac: float = clampf(float(hp) / float(maxi(mx, 1)), 0.0, 1.0)
		var chips: Array = [[CHIP_HEART, str(hp), Color(1.0 - 0.6 * frac, 0.55 + 0.4 * frac, 0.45), Color(1.0, 0.32, 0.36)]]
		if e["is_unit"]:
			chips.append([CHIP_SWORD, e["atk"], Color(1.0, 0.72, 0.35), Color.WHITE])
		# lay the chips out side by side, centred under the HP bar
		var widths: Array = []
		var total: float = pad * 2.0 * (chips.size() - 1)
		for ch in chips:
			var txt: String = ch[1]
			if not _chip_text_w.has(txt):
				_chip_text_w[txt] = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var w: float = icon + pad * 4.5 + float(_chip_text_w[txt])
			widths.append(w)
			total += w
		for cp in cps:
			var c := (cp as Vector2) + shift
			var x: float = c.x - total * 0.5
			var y: float = c.y + s * 0.92
			for i in range(chips.size()):
				var ch: Array = chips[i]
				var w2: float = widths[i]
				var cap: float = h * 0.5
				ci.draw_texture_rect_region(tex, Rect2(x, y, cap, h), Rect2(0, 0, 16, 32))
				ci.draw_texture_rect_region(tex, Rect2(x + cap, y, w2 - cap * 2.0, h), Rect2(31, 0, 2, 32))
				ci.draw_texture_rect_region(tex, Rect2(x + w2 - cap, y, cap, h), Rect2(48, 0, 16, 32))
				var ic := Vector2(x + pad * 1.8 + icon * 0.5, y + h * 0.5)
				var span: float = icon * 0.5 * CHIP_ICON_SPAN
				ci.draw_texture_rect_region(tex, Rect2(ic - Vector2(span, span), Vector2(span, span) * 2.0), ch[0], ch[3])
				texts.append([Vector2(x + pad * 2.8 + icon, y + h * 0.5 + fs * 0.36), ch[1], ch[2]])
				x += w2 + pad * 2.0
	for t in texts:
		ci.draw_string_outline(font, t[0], t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0.04, 0.03, 0.07, 0.75))
	for t in texts:
		ci.draw_string(font, t[0], t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, t[2])

# Under the units: placement rings, the front, range zones, selection rings, Barracks
# ripples, buff glows and boat wakes (all animated, redrawn every pulse).
func _draw_under() -> void:
	_ci = _under
	var m := metrics()
	_mark_drawn(_under, m)
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
				_ci.draw_polyline(ring, Color(0.6, 1.0, 0.45, a), 2.0)
	# Front line (card-battle mode): enemy hexes you could win next pulse red
	if not _front.is_empty():
		var pulse: float = 0.30 + 0.25 * (0.5 + 0.5 * sin(_pulse_t * 4.0))
		for t in _front:
			for cp in _visible_copies(t as Vector2i, m, margin):
				var c := cp as Vector2
				_ci.draw_colored_polygon(_hex_points(c, s), Color(1.0, 0.18, 0.12, pulse))
				var ring2 := _hex_points(c, s - 1.5)
				ring2.append(ring2[0])
				_ci.draw_polyline(ring2, Color(1, 0.3, 0.25, pulse + 0.25), 2.0)
	if not range_zones.is_empty():
		_draw_range_zones(m)
	if not group_marks.is_empty() or not plan_marks.is_empty():
		_draw_group_marks(m)
	if war != null:
		unit_cache()
		_draw_barracks_ripples(m)
		for v in _marked_units(m):
			if v[0]["buffed"]:
				_draw_buff_aura(v[1], s, int(v[0]["seed"]))
			if v[2]:
				_draw_boat_wake(v[1], s, v[3])

func _draw_unit_layer() -> void:
	_ci = _units
	var m := metrics()
	_mark_drawn(_units, m)
	if float(m[0]) < 2.0 or war == null:
		return
	_draw_units(m, _standing_units(), true)

func _draw_walker_layer() -> void:
	_ci = _walkers
	var m := metrics()
	_mark_drawn(_walkers, m)
	if float(m[0]) < 2.0 or war == null or walks.is_empty():
		return
	_draw_units(m, _walking_units(), false)

# The cache entries standing still / marching (walks), each in drawing order.
func _standing_units() -> Array:
	var ents := unit_cache()
	if walks.is_empty():
		return ents
	var out: Array = []
	for e in ents:
		if not walks.has(e["k"]):
			out.append(e)
	return out

func _walking_units() -> Array:
	var out: Array = []
	for e in unit_cache():
		if walks.has(e["k"]):
			out.append(e)
	return out

# Over the units: shields, flank arrows, flag HP, shots and blasts, the placement
# ghost, targets, the aim arrow, the selection box and the hover/selected outlines.
func _draw_overlay() -> void:
	_ci = _overlay
	var m := metrics()
	_mark_drawn(_overlay, m)
	var s: float = m[0]
	if s < 2.0:
		return
	var margin: float = s * 2.0
	if war != null:
		var marked := _marked_units(m)
		for v in marked:
			if v[0]["shielded"]:
				_draw_shield_aura(v[1], s, int(v[0]["seed"]))
		for v in marked:
			if v[0]["buffed"]:
				_draw_buff_chevron(v[1], s, int(v[0]["seed"]))
		for v in marked: # after every shield, so nothing hides them
			if int(v[0]["flank"]) > 0:
				_draw_flank_marks(v[1], s, int(v[0]["flank"]))
		_draw_flag_hp(m)
		_draw_effects(m)
		if ghost_card != "" and hovered.x >= 0 and placeable.has(MapCampaign.key_of(hovered.x, hovered.y)):
			var gp := get_local_mouse_position()
			for cp in _visible_copies(hovered, m, margin):
				if (cp as Vector2).distance_to(gp) < s * 2.0:
					_draw_card(ghost_card, cp as Vector2, s, Color(1, 1, 1, 0.55), 0, _player_nation)
	if not range_targets.is_empty():
		_draw_range_targets(m)
	if not aim.is_empty():
		_draw_aim(m)
	if _boxing and _pressed and _press_pos.distance_to(_box_end) > DRAG_THRESHOLD:
		var box := Rect2(_press_pos, Vector2.ZERO).expand(_box_end)
		_ci.draw_rect(box, Color(1.0, 0.86, 0.3, 0.12), true)
		_ci.draw_rect(box, Color(1.0, 0.86, 0.3, 0.9), false, 2.0)
	if hovered.x >= 0 and hovered != selected:
		_hex_outline(hovered, m, Color(1, 1, 1, 0.6), 2.0)
	if selected.x >= 0:
		_hex_outline(selected, m, Color8(20, 16, 30), 5.0)
		_hex_outline(selected, m, Color(1.0, 0.86, 0.3), 2.5)

# Attack range of the selected unit(s): a tint over every hex in reach and a thick
# rim (with a white dashed stripe) round the zone's edge, on every hex side whose
# neighbour is outside. Red for melee, blue for ranged, like the targeting arrow.
func _draw_range_zones(m: Array) -> void:
	var s: float = m[0]
	var margin: float = s * 2.0
	var a: float = 0.85 + 0.15 * sin(_clock * 3.0)
	for z in range_zones:
		var hexes: Dictionary = z["hexes"]
		var col: Color = z["color"] if z.has("color") else (RANGE_RANGED if bool(z["ranged"]) else RANGE_MELEE)
		var edges: Array = [] # [p0, p1] on the zone's rim, drawn after every fill
		for h in hexes.keys():
			var t := h as Vector2i
			# directions (in hex units) to the neighbours outside the zone
			var out_dirs: Array = []
			for i in range(6):
				var nb := MapCampaign.hex_neighbor(t, i)
				if not WorldMap.in_bounds(nb.x, nb.y) or not hexes.has(nb):
					out_dirs.append(_neighbor_dir(t, i))
			for cp in _visible_copies(t, m, margin):
				var c := cp as Vector2
				var pts := _hex_points(c, s)
				_ci.draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.22))
				for d in out_dirs:
					# the hex edge facing that neighbour: its midpoint points the same way
					var best := 0
					var best_dot := -INF
					for i in range(6):
						var mid: Vector2 = (pts[i] + pts[(i + 1) % 6]) * 0.5 - c
						var dot := mid.normalized().dot(d as Vector2)
						if dot > best_dot:
							best_dot = dot
							best = i
					edges.append([pts[best], pts[(best + 1) % 6]])
		var w: float = clampf(s * 0.14, 3.0, 6.0)
		for e in edges:
			_ci.draw_line(e[0], e[1], Color(0.05, 0.04, 0.08, 0.9), w + 3.0)
		for e in edges:
			_ci.draw_line(e[0], e[1], Color(col.r, col.g, col.b, a), w)
		# a white dashed stripe down the middle, so the rim never reads as a border
		for e in edges:
			_ci.draw_dashed_line(e[0], e[1], Color(1, 1, 1, 0.9 * a), maxf(1.5, w * 0.4), maxf(3.0, s * 0.18))

# Screen direction from hex `t` to its neighbour `i` (unit length; odd-r rows are
# shifted half a hex, so it is the same whatever the row).
func _neighbor_dir(t: Vector2i, i: int) -> Vector2:
	var nb := MapCampaign.hex_neighbor(t, i)
	var dx: float = float(nb.x - t.x) + 0.5 * float(nb.y & 1) - 0.5 * float(t.y & 1)
	if WorldMap.WRAPS and absf(dx) > WorldMap.GRID_W * 0.5:
		dx -= signf(dx) * WorldMap.GRID_W
	return Vector2(dx, float(nb.y - t.y) * 0.8660254).normalized()

# Pulsing corner brackets on every enemy card or flag the selection could hit.
func _draw_range_targets(m: Array) -> void:
	var s: float = m[0]
	var k: float = 0.62 + 0.08 * sin(_clock * 6.0)
	for t in range_targets:
		for cp in _visible_copies(t as Vector2i, m, s * 2.0):
			var c := cp as Vector2
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var corner := c + Vector2(sx, sy) * s * k
					_ci.draw_line(corner, corner - Vector2(sx * s * 0.28, 0), Color(1.0, 0.3, 0.25, 0.95), 2.5)
					_ci.draw_line(corner, corner - Vector2(0, sy * s * 0.28), Color(1.0, 0.3, 0.25, 0.95), 2.5)

# A gold ring under each selected unit; for a planned bulk move, a dotted line to
# the hex each one would reach and a hollow marker there.
func _draw_group_marks(m: Array) -> void:
	var s: float = m[0]
	var margin: float = s * 2.0
	for t in group_marks:
		for cp in _visible_copies(t as Vector2i, m, margin):
			_ci.draw_set_transform((cp as Vector2) + Vector2(0, s * 0.45), 0.0, Vector2(1.0, 0.45))
			_ci.draw_arc(Vector2.ZERO, s * 0.86, 0.0, TAU, 28, Color(0.05, 0.04, 0.08, 0.85), 5.0)
			_ci.draw_arc(Vector2.ZERO, s * 0.86, 0.0, TAU, 28, Color(1.0, 0.86, 0.3, 0.95), 2.5)
			_ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for pm in plan_marks:
		var from: Vector2i = pm[0]
		var to: Vector2i = pm[1]
		for cp in _visible_copies(to, m, margin):
			var b := cp as Vector2
			var a := _wrap_target(b, screen_pos(from, m), m)
			var n := maxi(2, int(a.distance_to(b) / maxf(6.0, s * 0.35)))
			for i in range(1, n):
				_ci.draw_circle(a.lerp(b, float(i) / n), maxf(1.5, s * 0.06), Color(1.0, 0.86, 0.3, 0.8))
			_ci.draw_arc(b, s * 0.42, 0.0, TAU, 20, Color(0.05, 0.04, 0.08, 0.85), 4.0)
			_ci.draw_arc(b, s * 0.42, 0.0, TAU, 20, Color(1.0, 0.86, 0.3, 0.95), 2.0)

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
			_ci.draw_line(a.lerp(b, t0), a.lerp(b, t1), Color(0.05, 0.04, 0.08, 0.8), 5.0)
			_ci.draw_line(a.lerp(b, t0), a.lerp(b, t1), col, 2.5)
	var r: float = s * (0.75 + 0.12 * sin(_clock * 6.0))
	_ci.draw_arc(b, r, 0.0, TAU, 20, col, 2.5)
	_ci.draw_line(b - Vector2(r * 1.4, 0), b - Vector2(r * 0.5, 0), col, 2.0)
	_ci.draw_line(b + Vector2(r * 0.5, 0), b + Vector2(r * 1.4, 0), col, 2.0)
	_ci.draw_line(b - Vector2(0, r * 1.4), b - Vector2(0, r * 0.5), col, 2.0)
	_ci.draw_line(b + Vector2(0, r * 0.5), b + Vector2(0, r * 1.4), col, 2.0)

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
		_ci.draw_polyline(pts, col, width)

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
