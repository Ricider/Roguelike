extends RefCounted
class_name PileArt

# Mirrors Modifier/Card art helpers: 512x512 20 frames @10fps, square, rounded 44, no pulse, twice-detailed
static var _frames_cache: Dictionary = {}

static func _pile_base_color(pile: String) -> Color:
	match pile:
		"Draw": return Color(0.34, 0.36, 0.24, 1)
		"Discard": return Color(0.20, 0.38, 0.43, 1)
		"Graveyard": return Color(0.19, 0.19, 0.21, 1)
		_: return Color(0.2,0.2,0.22,1)

static func get_sprite_frames(pile: String) -> SpriteFrames:
	if PileArt._frames_cache.has(pile):
		return PileArt._frames_cache[pile] as SpriteFrames
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 10.0)
	var found: bool = false
	for i in range(20):
		var fpath: String = "res://Assets/Piles/%s/sprite_%d.png" % [pile, i]
		if ResourceLoader.exists(fpath):
			var tex := load(fpath) as Texture2D
			if tex != null:
				sf.add_frame("idle", tex)
				found = true
	if found:
		PileArt._frames_cache[pile] = sf
		return sf
	# fallback single-color
	var col := _pile_base_color(pile)
	var img := Image.create(512,512,false,Image.FORMAT_RGBA8)
	img.fill(col)
	sf.add_frame("idle", ImageTexture.create_from_image(img))
	PileArt._frames_cache[pile]=sf
	return sf

static func create_animated_sprite(pile: String, size: Vector2) -> Control:
	var container := Control.new()
	container.custom_minimum_size = size
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.clip_contents = true
	var asp := AnimatedSprite2D.new()
	asp.sprite_frames = get_sprite_frames(pile)
	asp.animation = "idle"
	asp.autoplay = "idle"
	asp.centered = true
	asp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	asp.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	var base: float = 512.0
	var sf := get_sprite_frames(pile)
	if sf.get_frame_count("idle")>0:
		var tex: Texture2D = sf.get_frame_texture("idle",0)
		if tex != null:
			base = float(tex.get_width())
			if base < 64: base = 512.0
	var scale_f: float = size.x / base
	asp.scale = Vector2(scale_f, scale_f)
	asp.position = size * 0.5
	asp.modulate = Color(1,1,1,1)
	container.add_child(asp)
	asp.play("idle")
	# No extra pulse - matches modifier spec no pulse
	var name_lbl := Label.new()
	name_lbl.text = pile
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", int(size.x * 0.13))
	name_lbl.add_theme_color_override("font_color", Color(1,1,0.92))
	name_lbl.add_theme_color_override("font_outline_color", Color(0,0,0,0.85))
	name_lbl.add_theme_constant_override("outline_size", 6)
	name_lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0.6))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_lbl.custom_minimum_size = Vector2(size.x, size.y * 0.20)
	name_lbl.position = Vector2(0, 5)
	name_lbl.z_index = 10
	container.add_child(name_lbl)
	return container

static func create_sprite_for(pile: String, size: Vector2) -> Control:
	return create_animated_sprite(pile, size)
