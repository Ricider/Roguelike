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
		Modifier.new("Conscription", "Gain 15 additional BioSupply every turn, but earn 50% less MoneySupply", 50),
		Modifier.new("Guerilla Warfare", "Your cards that have a BioCost higher than MoneyCost deal 100% more damage, but the ones that have BioCost lower than MoneyCost have 50% less HP", 70),
		Modifier.new("State of emergency", "You gain 3 HitPoints every turn", 90),
		Modifier.new("Fanaticism", "Your buildings have 50% less HP, but Units have 100% more", 40),
		Modifier.new("Corruption", "Your buildings have 50% less HP, but you gain +10 MoneySupply every turn", 40),
		Modifier.new("Advanced Robotics", "All units have HasRange set to true, but they cost +5 extra MoneySupply", 100),
		Modifier.new("Aerial Supremacy", "If a unit has Flying set to true then they deal +2 damage, but they cost +5 extra MoneySupply", 80),
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
	var container := Control.new()
	container.custom_minimum_size = size
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Panel background like card frame
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = _modifier_base_color()
	sb.border_color = _modifier_border_color()
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	container.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	var icon_lbl := Label.new()
	icon_lbl.text = _modifier_icon()
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", int(size.x * 0.55))
	icon_lbl.add_theme_color_override("font_color", Color(1,1,1))
	icon_lbl.add_theme_color_override("font_outline_color", Color(0,0,0))
	icon_lbl.add_theme_constant_override("outline_size", 8)
	icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_lbl)
	var name_lbl := Label.new()
	name_lbl.text = modifier_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", int(size.x * 0.13))
	name_lbl.add_theme_color_override("font_color", Color(1,1,0.9))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.custom_minimum_size = Vector2(size.x * 0.9, 0)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)
	# AnimatedSprite2D overlay for frame animation (pulsing tint) - same size/detail as Cards
	var asp := AnimatedSprite2D.new()
	asp.sprite_frames = get_sprite_frames()
	asp.animation = "idle"
	asp.autoplay = "idle"
	asp.centered = true
	asp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	asp.position = size * 0.5
	asp.scale = Vector2(size.x / 512.0, size.y / 512.0)
	asp.modulate = Color(1,1,1,0.18) # subtle overlay
	container.add_child(asp)
	asp.play("idle")
	# Subtle scale pulse like cards
	var tw := container.create_tween()
	tw.set_loops()
	tw.tween_property(container, "scale", Vector2(1.04, 1.04), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(container, "scale", Vector2(1.0, 1.0), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return container

static func create_sprite_for(modifier_name: String, size: Vector2) -> Control:
	var tmp := Modifier.new(modifier_name, "", 0)
	return tmp.create_animated_sprite(size)
