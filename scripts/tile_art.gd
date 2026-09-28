# TileArt: procedural per-terrain tile textures for the world map.
# No external assets: each 48x48 tile is generated once at runtime with a
# deterministic seed, 4 variants per terrain so the map doesn't look stamped.
extends RefCounted
class_name TileArt

const SIZE: int = 48
const VARIANTS: int = 4
const TERRAINS: Array = ["ocean", "grassland", "desert", "mountain", "snow", "jungle"]

const BASES = {
	"ocean": Color(0.10, 0.22, 0.38),
	"grassland": Color(0.29, 0.55, 0.28),
	"desert": Color(0.82, 0.70, 0.42),
	"mountain": Color(0.45, 0.40, 0.38),
	"snow": Color(0.88, 0.91, 0.94),
	"jungle": Color(0.13, 0.42, 0.22),
}

static func make_tile_set() -> Dictionary:
	var out: Dictionary = {}
	for terrain in TERRAINS:
		var arr: Array = []
		for v in range(VARIANTS):
			var rng := RandomNumberGenerator.new()
			rng.seed = absi(hash("%s:%d" % [terrain, v]))
			arr.append(_make_tile(str(terrain), rng))
		out[terrain] = arr
	return out

static func _make_tile(terrain: String, rng: RandomNumberGenerator) -> ImageTexture:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(BASES.get(terrain, Color.BLACK))
	_grain(img, rng, 0.05)
	match terrain:
		"ocean":
			_waves(img, rng, Color(0.25, 0.45, 0.62))
		"grassland":
			_tufts(img, rng, Color(0.16, 0.38, 0.16), Color(0.55, 0.75, 0.35), 14)
		"desert":
			_speckles(img, rng, Color(0.68, 0.55, 0.30), 30)
			_speckles(img, rng, Color(0.95, 0.85, 0.60), 24)
			_dunes(img, rng)
		"mountain":
			_peak(img, rng, Color(0.60, 0.57, 0.55), Color(0.30, 0.26, 0.25), Color(0.92, 0.93, 0.95))
		"snow":
			for i in range(3):
				_blob(img, rng.randf_range(6.0, SIZE - 6.0), rng.randf_range(6.0, SIZE - 6.0), rng.randf_range(3.0, 6.0), Color(0.78, 0.84, 0.92))
			_speckles(img, rng, Color(1, 1, 1), 26)
		"jungle":
			for i in range(5):
				_blob(img, rng.randf_range(6.0, SIZE - 6.0), rng.randf_range(6.0, SIZE - 6.0), rng.randf_range(4.0, 8.0), Color(0.07, 0.28, 0.13))
			_speckles(img, rng, Color(0.35, 0.68, 0.30), 22)
	return ImageTexture.create_from_image(img)

static func _grain(img: Image, rng: RandomNumberGenerator, amt: float) -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			var p := img.get_pixel(x, y)
			var d: float = (rng.randf() - 0.5) * 2.0 * amt
			img.set_pixel(x, y, Color(clampf(p.r + d, 0.0, 1.0), clampf(p.g + d, 0.0, 1.0), clampf(p.b + d, 0.0, 1.0), 1.0))

static func _blob(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	for y in range(maxi(0, int(cy - r)), mini(SIZE, int(cy + r) + 1)):
		for x in range(maxi(0, int(cx - r)), mini(SIZE, int(cx + r) + 1)):
			var dx: float = x + 0.5 - cx
			var dy: float = y + 0.5 - cy
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(x, y, col)

static func _speckles(img: Image, rng: RandomNumberGenerator, col: Color, count: int) -> void:
	for i in range(count):
		img.set_pixel(rng.randi_range(0, SIZE - 1), rng.randi_range(0, SIZE - 1), col)

static func _waves(img: Image, rng: RandomNumberGenerator, col: Color) -> void:
	for i in range(3):
		var wy: float = rng.randf_range(6.0, SIZE - 6.0)
		var amp := rng.randf_range(1.5, 3.0)
		var per := rng.randf_range(10.0, 18.0)
		var ph := rng.randf_range(0.0, TAU)
		for x in range(SIZE):
			var y := int(wy + sin(x / per * TAU + ph) * amp)
			if y >= 0 and y < SIZE:
				img.set_pixel(x, y, col)

static func _tufts(img: Image, rng: RandomNumberGenerator, dark: Color, light: Color, count: int) -> void:
	for i in range(count):
		var x := rng.randi_range(1, SIZE - 2)
		var y := rng.randi_range(2, SIZE - 2)
		img.set_pixel(x, y, dark)
		img.set_pixel(x, y - 1, dark)
		img.set_pixel(x, y - 2, light)

static func _dunes(img: Image, rng: RandomNumberGenerator) -> void:
	for i in range(3):
		var y := rng.randi_range(6, SIZE - 8)
		var x0 := rng.randi_range(2, SIZE - 18)
		var run := rng.randi_range(10, 16)
		for x in range(x0, mini(SIZE, x0 + run)):
			img.set_pixel(x, y, Color(0.92, 0.82, 0.58))
			img.set_pixel(x, y + 1, Color(0.70, 0.58, 0.34))

static func _peak(img: Image, rng: RandomNumberGenerator, light: Color, dark: Color, cap: Color) -> void:
	var cx: float = SIZE * 0.5 + rng.randf_range(-6.0, 6.0)
	var top: float = rng.randf_range(6.0, 12.0)
	var bottom: float = SIZE - rng.randf_range(4.0, 8.0)
	for y in range(int(top), int(bottom)):
		var t: float = (y - top) / (bottom - top)
		var hw: float = t * SIZE * 0.45
		for x in range(int(cx - hw), int(cx + hw) + 1):
			if x < 0 or x >= SIZE:
				continue
			var col: Color = light if x < cx else dark
			if t < 0.35 and rng.randf() < 0.9 - t:
				col = cap
			img.set_pixel(x, y, col)
