extends GameObject
class_name Card

var MoneyCost: int = 0
var BioCost: int = 0
var card_name: String = "Card"
var SpecialEffect: String = "" # AIInterpretedString per spec

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

func get_sprite_frames() -> SpriteFrames:
	if Card._frames_cache.has(card_name):
		return Card._frames_cache[card_name] as SpriteFrames
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 10.0)
	for i in range(20):
		var fpath: String = "res://Assets/Cards/%s/sprite_%d.png" % [card_name, i]
		if ResourceLoader.exists(fpath):
			var tex := load(fpath) as Texture2D
			if tex != null:
				sf.add_frame("idle", tex)
	Card._frames_cache[card_name] = sf
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
	asp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var scale_f: float = size.x / 128.0
	asp.scale = Vector2(scale_f, scale_f)
	asp.position = size * 0.5
	container.add_child(asp)
	asp.play("idle")
	return container

static func get_frames_for(card_name: String) -> SpriteFrames:
	var tmp := Card.new()
	tmp.card_name = card_name
	return tmp.get_sprite_frames()

static func create_sprite_for(card_name: String, size: Vector2) -> Control:
	var tmp := Card.new()
	tmp.card_name = card_name
	return tmp.create_animated_sprite(size)
