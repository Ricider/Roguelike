# TileArt: procedural 8-bit pixel-art terrain tiles for the world map.
# No external assets: each tile is drawn on a 16x16 grid with a small fixed
# palette per terrain, then upscaled NEAREST x3 to 48x48 so the pixels stay
# crisp. Deterministic seed per variant; 4 variants per terrain so the map
# doesn't look stamped.
extends RefCounted
class_name TileArt

const PX: int = 16
const SCALE: int = 3
const SIZE: int = PX * SCALE
const VARIANTS: int = 4
const TERRAINS: Array = ["ocean", "grassland", "desert", "mountain", "snow", "jungle"]

# Per-terrain ramp: base, dark, light, accent
const PALETTES = {
	"ocean": [Color8(36, 82, 150), Color8(26, 58, 118), Color8(92, 160, 220), Color8(200, 236, 252)],
	"grassland": [Color8(84, 150, 62), Color8(58, 112, 46), Color8(132, 194, 86), Color8(250, 226, 90)],
	"desert": [Color8(222, 186, 116), Color8(186, 142, 80), Color8(246, 220, 160), Color8(150, 106, 62)],
	"mountain": [Color8(120, 104, 92), Color8(76, 64, 60), Color8(168, 154, 140), Color8(240, 244, 250)],
	"snow": [Color8(224, 234, 246), Color8(170, 190, 220), Color8(252, 254, 255), Color8(140, 160, 196)],
	"jungle": [Color8(34, 96, 52), Color8(20, 62, 36), Color8(70, 150, 70), Color8(120, 196, 90)],
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
	var img := Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	var pal: Array = PALETTES.get(terrain, PALETTES["grassland"])
	img.fill(pal[0])
	match terrain:
		"ocean":
			_dither(img, rng, pal[1], 18)
			# One soft crest per tile (foam only sometimes) keeps big oceans calm
			var foam: Color = pal[3] if rng.randf() < 0.35 else pal[2]
			_wave_crest(img, rng.randi_range(1, PX - 5), rng.randi_range(3, PX - 3), pal[2].darkened(0.1), foam)
		"grassland":
			_dither(img, rng, pal[1], 14)
			for i in range(5):
				_tuft(img, rng.randi_range(1, PX - 2), rng.randi_range(2, PX - 1), pal[1], pal[2])
			if rng.randf() < 0.6:
				_px(img, rng.randi_range(2, PX - 3), rng.randi_range(2, PX - 3), pal[3])
		"desert":
			_dither(img, rng, pal[2], 12)
			for i in range(2):
				_dune(img, rng.randi_range(0, PX - 9), rng.randi_range(3, PX - 3), rng.randi_range(6, 10), pal[2], pal[1])
			_px(img, rng.randi_range(1, PX - 2), rng.randi_range(1, PX - 2), pal[3])
		"mountain":
			_dither(img, rng, pal[1], 10)
			_peak(img, rng.randi_range(6, 9), rng.randi_range(2, 4), pal)
		"snow":
			_dither(img, rng, pal[1], 10)
			for i in range(2):
				_dune(img, rng.randi_range(0, PX - 8), rng.randi_range(4, PX - 2), rng.randi_range(5, 8), pal[2], pal[1])
			_px(img, rng.randi_range(1, PX - 2), rng.randi_range(1, PX - 2), pal[3])
		"jungle":
			_dither(img, rng, pal[1], 16)
			for i in range(4):
				_canopy(img, rng.randi_range(2, PX - 3), rng.randi_range(2, PX - 3), pal)
	img.resize(SIZE, SIZE, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

static func _px(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and x < PX and y >= 0 and y < PX:
		img.set_pixel(x, y, col)

static func _dither(img: Image, rng: RandomNumberGenerator, col: Color, count: int) -> void:
	# Sparse checkerboard grit: only on even-parity cells so it reads as dithering.
	for i in range(count):
		var x := rng.randi_range(0, PX - 1)
		var y := rng.randi_range(0, PX - 1)
		if (x + y) % 2 == 0:
			_px(img, x, y, col)

static func _wave_crest(img: Image, x: int, y: int, light: Color, foam: Color) -> void:
	_px(img, x, y, light)
	_px(img, x + 1, y - 1, foam)
	_px(img, x + 2, y - 1, foam)
	_px(img, x + 3, y, light)

static func _tuft(img: Image, x: int, y: int, dark: Color, light: Color) -> void:
	_px(img, x, y, dark)
	_px(img, x - 1, y - 1, light)
	_px(img, x + 1, y - 1, light)

static func _dune(img: Image, x0: int, y: int, run: int, light: Color, dark: Color) -> void:
	for x in range(x0, x0 + run):
		var lift: int = 1 if x > x0 + 1 and x < x0 + run - 2 else 0
		_px(img, x, y - lift, light)
		_px(img, x, y + 1 - lift, dark)

static func _peak(img: Image, cx: int, top: int, pal: Array) -> void:
	var bottom: int = PX - 2
	for y in range(top, bottom + 1):
		var hw: int = (y - top) * 7 / maxi(bottom - top, 1) + 1
		for x in range(cx - hw, cx + hw + 1):
			var col: Color = pal[2] if x < cx else pal[1]
			if y - top < 3:
				col = pal[3] if x <= cx else pal[3].darkened(0.15)
			_px(img, x, y, col)
		_px(img, cx - hw - 1, y, Color8(40, 32, 40))
		_px(img, cx + hw + 1, y, Color8(40, 32, 40))
	_px(img, cx, top - 1, Color8(40, 32, 40))

static func _canopy(img: Image, cx: int, cy: int, pal: Array) -> void:
	for y in range(cy - 2, cy + 3):
		for x in range(cx - 2, cx + 3):
			if absi(x - cx) + absi(y - cy) <= 3:
				_px(img, x, y, pal[2])
	_px(img, cx + 2, cy + 1, pal[1])
	_px(img, cx + 1, cy + 2, pal[1])
	_px(img, cx - 1, cy - 1, pal[3])
	_px(img, cx, cy - 2, pal[3])
