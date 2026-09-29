# Minimap: the whole campaign map in a corner of the map view.
#  - every hex as a 2x2 pixel block: nation colour on owned land, terrain
#    colour on wilderness, dark blue sea (baked into a texture on refresh());
#  - live specks for cards on the map and a dot per living nation's flag;
#  - a gold frame showing what the main view is looking at (two pieces when
#    it straddles the seam of the wrapping world map).
# Click or drag on it to move the camera there.
extends Control
class_name Minimap

const MAX_SIZE := Vector2(300, 170)
const PAD := 4.0
const SEA := Color(0.07, 0.13, 0.24)
const GOLD := Color(1.0, 0.84, 0.3)

var view: WorldMapView = null
var _tex: ImageTexture = null
var _map_rect := Rect2() # where the map texture sits inside this control
var _dragging := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	tooltip_text = ""
	_fit()

# Size the box to the map's shape (hexes are wider than their row height).
func _fit() -> void:
	var map_w: float = (WorldMap.GRID_W + (0.0 if WorldMap.WRAPS else 0.5)) * WorldMapView.SQRT3
	var map_h: float = 1.5 * WorldMap.GRID_H + 0.5
	var k: float = minf((MAX_SIZE.x - PAD * 2.0) / map_w, (MAX_SIZE.y - PAD * 2.0) / map_h)
	var inner := Vector2(map_w, map_h) * k
	custom_minimum_size = inner + Vector2(PAD, PAD) * 2.0
	size = custom_minimum_size
	offset_left = 10.0
	offset_right = 10.0 + size.x
	offset_top = -10.0 - size.y
	offset_bottom = -10.0
	_map_rect = Rect2(Vector2(PAD, PAD), inner)

# Re-bake territory colours (call when ownership changes or the map is swapped).
func refresh() -> void:
	_fit()
	var c: MapCampaign = view._campaign if view != null else null
	var W: int = WorldMap.GRID_W
	var H: int = WorldMap.GRID_H
	var img := Image.create(W * 2 + 1, H * 2, false, Image.FORMAT_RGBA8)
	img.fill(SEA)
	var colors := {}
	for n in WorldMap.nations():
		colors[str(n["name"])] = Color.html(str(n["color"]))
	for y in range(H):
		for x in range(W):
			if not WorldMap.is_land(x, y):
				continue
			var terrain: Color = WorldMapView.TERRAIN_COLORS.get(WorldMap.terrain_at(x, y), Color.GRAY)
			var col: Color = terrain.darkened(0.25)
			var o: String = c.owner_of(x, y) if c != null else ""
			if o != "":
				col = (colors.get(o, Color.WHITE) as Color).lerp(terrain, 0.18)
				if c.player_nation == o:
					col = col.lightened(0.18)
			var px: int = x * 2 + (y & 1)
			img.fill_rect(Rect2i(px, y * 2, 2, 2), col)
	if _tex == null or _tex.get_size() != Vector2(img.get_size()):
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)
	queue_redraw()

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw() # the camera frame and unit specks follow the main view

# hex -> point inside this control
func _hex_point(t: Vector2i) -> Vector2:
	var fx: float = (float(t.x) + 0.5 * float(t.y & 1) + 0.5) / (WorldMap.GRID_W + 0.5)
	var fy: float = (float(t.y) + 0.5) / WorldMap.GRID_H
	return _map_rect.position + Vector2(fx, fy) * _map_rect.size

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.09, 0.9), true)
	if _tex != null:
		draw_texture_rect(_tex, _map_rect, false)
	if view == null or view._campaign == null:
		return
	var c: MapCampaign = view._campaign
	# cards on the map: a dark-edged speck in the owner's colour
	if view.war != null:
		for k in view.war.units.keys():
			var info: Dictionary = view.war.units[k]
			var p := _hex_point(MapWar.key_to_hex(str(k)))
			var nc: Color = view._nation_colors.get(str(info["owner"]), Color.WHITE)
			draw_rect(Rect2(p - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.05, 0.04, 0.08), true)
			draw_rect(Rect2(p - Vector2(0.5, 0.5), Vector2(1, 1)), nc.lightened(0.5), true)
	# flags: a white-ringed dot, gold for the player
	for n in WorldMap.nations():
		var nm := str(n["name"])
		if not c.is_alive(nm):
			continue
		var fp := _hex_point(c.capital_site(nm))
		draw_circle(fp, 3.5, Color(0.05, 0.04, 0.08))
		draw_circle(fp, 2.5, GOLD if nm == c.player_nation else Color.WHITE)
		draw_circle(fp, 1.4, view._nation_colors.get(nm, Color.WHITE))
	# the main view's window onto the map
	var vr := _view_rect()
	for off in ([-_map_rect.size.x, 0.0, _map_rect.size.x] if WorldMap.WRAPS else [0.0]):
		var r := Rect2(vr.position + Vector2(off, 0), vr.size).intersection(_map_rect)
		if r.size.x > 0.5 and r.size.y > 0.5:
			draw_rect(r, Color(0, 0, 0, 0.55), false, 3.0)
			draw_rect(r, GOLD, false, 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.84, 0.3, 0.7), false, 1.5)

# The main view's visible area in this control's coordinates.
func _view_rect() -> Rect2:
	var m: Array = view.metrics()
	var s: float = m[0]
	var map_px := Vector2((WorldMap.GRID_W + 0.5) * WorldMapView.SQRT3 * s, (1.5 * WorldMap.GRID_H + 0.5) * s)
	var origin := Vector2(float(m[1]), float(m[2]))
	var a := (Vector2.ZERO - origin) / map_px
	var b := (view.size - origin) / map_px
	if WorldMap.WRAPS:
		var shift: float = floorf(a.x)
		a.x -= shift
		b.x -= shift
	return Rect2(_map_rect.position + a * _map_rect.size, (b - a) * _map_rect.size)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
		if _dragging:
			_jump((event as InputEventMouseButton).position)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_jump((event as InputEventMouseMotion).position)
		accept_event()
	elif event is InputEventMouseButton:
		accept_event() # keep wheel zoom from leaking to the map under the minimap

func _jump(p: Vector2) -> void:
	if view == null:
		return
	var f := (p - _map_rect.position) / _map_rect.size
	view.center_on_fraction(clampf(f.x, 0.0, 1.0), clampf(f.y, 0.0, 1.0))
