extends GameObject
class_name Card

var MoneyCost: int = 0
var BioCost: int = 0
var InfluenceCost: int = 0
var card_name: String = "Card"
var SpecialEffect: String = "" # AIInterpretedString per spec

# Nation whose art to show ("" = the shared art). Each map nation has its own
# idle frames in Assets/Cards/<card>/nations/<nation>/ (tools/retro_overhaul.py nations).
var art_nation: String = ""

func get_display_name() -> String:
	return card_name

# --- View helpers (moved from GameController, now owned by Card) ---
static var _frames_cache: Dictionary = {}

func get_static_sprite() -> Texture2D:
	var path_png: String = "res://Assets/Cards/%s/sprite.png" % card_name
	if ResourceLoader.exists(path_png):
		return load(path_png) as Texture2D
	var path_svg: String = "res://Assets/Cards/%s/sprite.svg" % card_name
	if ResourceLoader.exists(path_svg):
		return load(path_svg) as Texture2D
	return null

# Path of idle frame i for `nation` (its own art when it exists, else the shared art).
static func idle_frame_path(card: String, i: int, nation: String = "") -> String:
	if nation != "":
		var np := "res://Assets/Cards/%s/nations/%s/sprite_%d.png" % [card, nation, i]
		if ResourceLoader.exists(np):
			return np
	return "res://Assets/Cards/%s/sprite_%d.png" % [card, i]

func get_sprite_frames() -> SpriteFrames:
	var cache_key := card_name + "|" + art_nation
	if Card._frames_cache.has(cache_key):
		return Card._frames_cache[cache_key] as SpriteFrames
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 10.0)
	for i in range(20):
		var fpath: String = Card.idle_frame_path(card_name, i, art_nation)
		if ResourceLoader.exists(fpath):
			var tex := load(fpath) as Texture2D
			if tex != null:
				sf.add_frame("idle", tex)
	# One-shot attack animation (muzzle flash / recoil); played by GameController on each hit
	sf.add_animation("attack")
	sf.set_animation_loop("attack", false)
	sf.set_animation_speed("attack", 24.0)
	for i in range(20):
		var apath: String = "res://Assets/Cards/%s/attack_sprite_%d.png" % [card_name, i]
		if ResourceLoader.exists(apath):
			var atex := load(apath) as Texture2D
			if atex != null:
				sf.add_frame("attack", atex)
	Card._frames_cache[cache_key] = sf
	return sf

func create_animated_sprite(size: Vector2) -> Control:
	var container := Control.new()
	container.custom_minimum_size = size
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var asp := AnimatedSprite2D.new()
	asp.sprite_frames = get_sprite_frames()
	asp.animation = "idle"
	asp.autoplay = "idle"
	asp.centered = true
	# High-res: linear with mipmaps for crisp downscale from 512 source
	asp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	asp.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	var base: float = 512.0
	# Adapt if source is still 128 (fallback) — detect via first frame size
	var sf := get_sprite_frames()
	if sf.get_frame_count("idle") > 0:
		var tex: Texture2D = sf.get_frame_texture("idle", 0)
		if tex != null:
			base = float(tex.get_width())
			if base < 64:
				base = 512.0
	var scale_f: float = size.x / base
	# Infantry and Drone slightly smaller for visual balance
	if card_name == "Infantry" or card_name == "Drone":
		scale_f *= 0.85
	asp.scale = Vector2(scale_f, scale_f)
	asp.position = size * 0.5
	container.add_child(asp)
	asp.play("idle")
	return container

static func get_frames_for(card_name: String) -> SpriteFrames:
	var tmp := Card.new()
	tmp.card_name = card_name
	return tmp.get_sprite_frames()

static func create_sprite_for(card_name: String, size: Vector2, nation: String = "") -> Control:
	var tmp := Card.new()
	tmp.card_name = card_name
	tmp.art_nation = nation
	return tmp.create_animated_sprite(size)
