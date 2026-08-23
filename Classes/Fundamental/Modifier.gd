extends GameObject
class_name Modifier

var modifier_name: String = ""
var Effect: String = ""
var InfluenceCost: int = 0
var card_name: String = "" # alias for shop UI generic handling (Card compatibility)

func _init(name: String = "", effect: String = "", cost: int = 0):
	super._init()
	modifier_name = name
	Effect = effect
	InfluenceCost = cost
	card_name = name

static func all_modifiers() -> Array:
	return [
		Modifier.new("Conscription", "Gain 15 additional BioSupply every turn, but earn 50% less MoneySupply", 35),
		Modifier.new("Guerilla Warfare", "Your cards that have a BioCost higher than MoneyCost deal 40% more damage, but the ones that have BioCost lower than MoneyCost have 50% less HP", 25),
		Modifier.new("State of emergency", "You gain 3 HitPoints every turn", 20),
		Modifier.new("Fanaticism", "Your buildings have 50% less HP, but Units have 40% more", 30),
		Modifier.new("Corruption", "Your buildings have 50% less HP, but you gain +10 MoneySupply every turn", 30),
		Modifier.new("Advanced Robotics", "All units have HasRange set to true, but they cost +5 extra MoneySupply", 60),
		Modifier.new("Aerial Supremacy", "If a unit has Flying set to true then they deal +2 damage, but they cost +5 extra MoneySupply", 50),
		Modifier.new("Defensive Doctrine", "Your cards have +10 hp, but they deal -1 damage", 40),
	]

static func by_name(name: String) -> Modifier:
	for m in all_modifiers():
		if (m as Modifier).modifier_name == name:
			return m as Modifier
	return null

# --- Art helpers (mirrors Card, 512 base, 20 frames, 10fps) ---
static var _frames_cache: Dictionary = {}

func _modifier_base_color() -> Color:
	match modifier_name:
		"Conscription": return Color(0.30, 0.58, 0.22, 1) # vivid green
		"Guerilla Warfare": return Color(0.62, 0.45, 0.18, 1) # warm amber/brown
		"State of emergency": return Color(0.82, 0.12, 0.12, 1) # bright red
		"Fanaticism": return Color(1.0, 0.42, 0.05, 1) # vivid orange
		"Corruption": return Color(0.42, 0.16, 0.64, 1) # rich purple
		"Advanced Robotics": return Color(0.18, 0.45, 0.78, 1) # electric blue
		"Aerial Supremacy": return Color(0.22, 0.72, 0.88, 1) # cyan sky
		"Defensive Doctrine": return Color(0.35, 0.45, 0.65, 1) # steel blue-gray
		_: return Color(0.2, 0.2, 0.25, 1)

func _modifier_border_color() -> Color:
	var c: Color = _modifier_base_color()
	return Color(c.r * 0.6, c.g * 0.6, c.b * 0.6, 1)

func _modifier_icon() -> String:
	match modifier_name:
		"Conscription": return "⚔"
		"Guerilla Warfare": return "🌿"
		"State of emergency": return "✚"
		"Fanaticism": return "🔥"
		"Corruption": return "◆"
		"Advanced Robotics": return "⚙"
		"Aerial Supremacy": return "✈"
		"Defensive Doctrine": return "🛡"
		_: return "◈"

func get_static_sprite() -> Texture2D:
	var path_png: String = "res://Assets/Modifiers/%s/sprite.png" % modifier_name
	if ResourceLoader.exists(path_png):
		return load(path_png) as Texture2D
	var path_svg: String = "res://Assets/Modifiers/%s/sprite.svg" % modifier_name
	if ResourceLoader.exists(path_svg):
		return load(path_svg) as Texture2D
	# fallback: generate single-color texture
	var img := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	img.fill(_modifier_base_color())
	return ImageTexture.create_from_image(img)

func get_sprite_frames() -> SpriteFrames:
	if Modifier._frames_cache.has(modifier_name):
		return Modifier._frames_cache[modifier_name] as SpriteFrames
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 10.0)
	# Try disk frames first (20 pngs like Cards)
	var found: bool = false
	for i in range(20):
		var fpath: String = "res://Assets/Modifiers/%s/sprite_%d.png" % [modifier_name, i]
		if ResourceLoader.exists(fpath):
			var tex := load(fpath) as Texture2D
			if tex != null:
				sf.add_frame("idle", tex)
				found = true
	if found:
		Modifier._frames_cache[modifier_name] = sf
		return sf
	# Fallback: generate 20 tint-pulsing frames procedurally (no disk assets needed)
	var base: Color = _modifier_base_color()
	for i in range(20):
		var img := Image.create(512, 512, false, Image.FORMAT_RGBA8)
		var pulse: float = 0.85 + 0.15 * sin(float(i) / 20.0 * TAU)
		var col: Color = Color(base.r * pulse, base.g * pulse, base.b * pulse, 1)
		img.fill(col)
		var tex2 := ImageTexture.create_from_image(img)
		sf.add_frame("idle", tex2)
	if sf.get_frame_count("idle") == 0:
		var img2 := Image.create(512, 512, false, Image.FORMAT_RGBA8)
		img2.fill(base)
		sf.add_frame("idle", ImageTexture.create_from_image(img2))
	Modifier._frames_cache[modifier_name] = sf
	return sf

func create_animated_sprite(size: Vector2) -> Control:
	# No old logo overlay — pure 20-frame pixel art like Cards (512x512 @10fps)
	var container := Control.new()
	container.custom_minimum_size = size
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.clip_contents = true
	var asp := AnimatedSprite2D.new()
	asp.sprite_frames = get_sprite_frames()
	asp.animation = "idle"
	asp.autoplay = "idle"
	asp.centered = true
	asp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	asp.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	var base: float = 512.0
	var sf := get_sprite_frames()
	if sf.get_frame_count("idle") > 0:
		var tex: Texture2D = sf.get_frame_texture("idle", 0)
		if tex != null:
			base = float(tex.get_width())
			if base < 64:
				base = 512.0
	var scale_f: float = size.x / base
	asp.scale = Vector2(scale_f, scale_f)
	asp.position = size * 0.5
	asp.modulate = Color(1,1,1,1)
	container.add_child(asp)
	asp.play("idle")
	var name_lbl := Label.new()
	name_lbl.text = modifier_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", int(size.x * 0.11))
	name_lbl.add_theme_color_override("font_color", Color(1,1,0.92))
	name_lbl.add_theme_color_override("font_outline_color", Color(0,0,0,0.85))
	name_lbl.add_theme_constant_override("outline_size", 6)
	name_lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0.6))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.custom_minimum_size = Vector2(size.x, size.y * 0.22)
	name_lbl.position = Vector2(0, 6)
	name_lbl.z_index = 10
	container.add_child(name_lbl)
	# Subtle scale pulse like cards - only if inside tree (tests create sprites off-tree)
	var do_pulse := func():
		if not is_instance_valid(container) or not container.is_inside_tree():
			return
		var tree := container.get_tree()
		if tree == null:
			return
		var tw := container.create_tween()
		if tw == null:
			return
		tw.set_loops()
		tw.tween_property(container, "scale", Vector2(1.04, 1.04), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(container, "scale", Vector2(1.0, 1.0), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if container.is_inside_tree():
		do_pulse.call()
	else:
		container.tree_entered.connect(func(): do_pulse.call(), CONNECT_ONE_SHOT)
	return container

static func create_sprite_for(modifier_name: String, size: Vector2) -> Control:
	var tmp := Modifier.new(modifier_name, "", 0)
	return tmp.create_animated_sprite(size)
