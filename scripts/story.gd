# Story screen for the State Troops campaign. One scene, four moods, picked by
# GameState.story_screen:
#   menu   - the five chapters (locked until the one before is won)
#   intro  - a chapter's illustration, story and objective, then into the war
#   outro  - after a win: what happened next, over the NEXT chapter's
#            illustration (the epilogue's after the last chapter)
#   defeat - the fallen flag, with a retry
# Text types itself out; a click, Space or Enter shows it all at once. The art
# drifts slowly (a pixel-art Ken Burns) and every change fades through black.
extends Control

const TYPE_SPEED := 0.016 # seconds per character
const FADE := 0.45

var _gs = null
var _phase := "menu"
var _chapter := 1
var _bg: TextureRect = null
var _text: RichTextLabel = null
var _typing: Tween = null
var _fader: ColorRect = null
var _buttons: HBoxContainer = null

func _ready() -> void:
	_gs = get_node_or_null("/root/GameState")
	var st: Dictionary = _gs.story_screen if _gs != null else {}
	_phase = str(st.get("phase", "menu"))
	_chapter = clampi(int(st.get("chapter", 1)), 1, StoryText.count())
	var sm = get_node_or_null("/root/SoundManager")
	if sm != null:
		sm.play_music("menu")
	_build()
	_fade_in()

# ----------------------------------------------------------------- layout
func _build() -> void:
	for c in get_children():
		c.queue_free()
	var black := ColorRect.new()
	black.color = Color(0.02, 0.02, 0.04)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	_bg = TextureRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.texture = StoryText.image(_image_name())
	add_child(_bg)
	_drift()
	# darken the lower part so the text reads over any picture
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.02, 0.05, 0.0))
	grad.set_color(1, Color(0.02, 0.02, 0.05, 0.94))
	grad.add_point(0.45, Color(0.02, 0.02, 0.05, 0.25))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	if _phase == "menu":
		_build_menu()
	else:
		_build_story()
	_fader = ColorRect.new()
	_fader.color = Color(0, 0, 0, 1)
	_fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fader)

func _image_name() -> String:
	match _phase:
		"menu":
			return "ch1"
		"defeat":
			return "defeat"
		"epilogue":
			return "epilogue"
		"outro":
			return "epilogue" if _chapter >= StoryText.count() else str(StoryText.chapter(_chapter + 1)["image"])
		_:
			return str(StoryText.chapter(_chapter)["image"])

# Slow drift and zoom over the illustration.
func _drift() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_bg):
		return
	_bg.pivot_offset = _bg.size * 0.5
	_bg.scale = Vector2.ONE
	var tw := _bg.create_tween().set_loops()
	tw.tween_property(_bg, "scale", Vector2(1.07, 1.07), 18.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_bg, "scale", Vector2.ONE, 18.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _build_story() -> void:
	var box := MarginContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		box.add_theme_constant_override("margin_" + side, 180)
	box.add_theme_constant_override("margin_bottom", 56)
	add_child(box)
	# a translucent slab behind the words so they read over any picture
	var slab := PanelContainer.new()
	slab.size_flags_vertical = Control.SIZE_SHRINK_END
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.07, 0.74)
	sb.border_color = Color(1.0, 0.84, 0.35, 0.55)
	sb.border_width_top = 2
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 18
	sb.content_margin_bottom = 20
	slab.add_theme_stylebox_override("panel", sb)
	slab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(slab)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_END
	v.add_theme_constant_override("separation", 12)
	slab.add_child(v)
	var ch: Dictionary = StoryText.chapter(_chapter)
	var kicker := Label.new()
	var title := Label.new()
	var paragraphs: Array = []
	var objective := ""
	match _phase:
		"intro":
			kicker.text = "CHAPTER %d" % _chapter
			title.text = str(ch["title"])
			paragraphs = ch["intro"]
			objective = str(ch["objective"])
		"outro":
			kicker.text = "CHAPTER %d  COMPLETE" % _chapter
			title.text = str(ch["title"])
			paragraphs = ch["outro"]
		"epilogue":
			kicker.text = "EPILOGUE"
			title.text = StoryText.EPILOGUE_TITLE
			paragraphs = StoryText.EPILOGUE
		"defeat":
			kicker.text = "CHAPTER %d  LOST" % _chapter
			title.text = StoryText.DEFEAT_TITLE
			paragraphs = StoryText.DEFEAT
	kicker.add_theme_font_size_override("font_size", 18)
	kicker.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	v.add_child(kicker)
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.93, 0.75))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	v.add_child(title)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.custom_minimum_size = Vector2(0, 40)
	_text.add_theme_font_size_override("normal_font_size", 22)
	_text.add_theme_color_override("default_color", Color(0.92, 0.92, 0.96))
	_text.add_theme_constant_override("line_separation", 6)
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_text.add_theme_constant_override("shadow_offset_x", 2)
	_text.add_theme_constant_override("shadow_offset_y", 2)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body := "\n\n".join(paragraphs)
	if objective != "":
		body += "\n\n[color=#ffd966]OBJECTIVE:[/color] [color=#fff2c0]%s[/color]" % objective
	_text.text = body
	v.add_child(_text)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 14)
	v.add_child(_buttons)
	match _phase:
		"intro":
			_add_button("Begin Chapter %d" % _chapter, _begin_chapter, true)
			_add_button("Chapters", func(): _go("menu", _chapter))
		"outro":
			if _chapter >= StoryText.count():
				_add_button("Continue", func(): _go("epilogue", _chapter), true)
			else:
				_add_button("Continue to Chapter %d" % (_chapter + 1), func(): _go("intro", _chapter + 1), true)
			_add_button("Chapters", func(): _go("menu", _chapter))
		"epilogue":
			_add_button("Chapters", func(): _go("menu", _chapter), true)
			_add_button("Main Menu", _to_main_menu)
		"defeat":
			_add_button("Retry Chapter %d" % _chapter, _begin_chapter, true)
			_add_button("Chapters", func(): _go("menu", _chapter))
	_type_out()

func _add_button(text: String, cb: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 54)
	b.add_theme_font_size_override("font_size", 20)
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.theme_type_variation = &"PrimaryButton"
	b.pressed.connect(cb)
	_buttons.add_child(b)
	return b

func _type_out() -> void:
	_text.visible_ratio = 0.0
	_buttons.modulate = Color(1, 1, 1, 0)
	var chars: int = _text.get_parsed_text().length()
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, maxf(0.3, chars * TYPE_SPEED))
	_typing.tween_property(_buttons, "modulate", Color.WHITE, 0.35)

func _finish_typing() -> void:
	if _typing != null and _typing.is_valid() and _typing.is_running():
		_typing.kill()
		_text.visible_ratio = 1.0
		_buttons.modulate = Color.WHITE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_finish_typing()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var kc := (event as InputEventKey).keycode
		if kc in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_finish_typing()
		elif kc == KEY_ESCAPE:
			if _phase == "menu":
				_to_main_menu()
			else:
				_go("menu", _chapter)

# ----------------------------------------------------------------- chapter menu
func _build_menu() -> void:
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 18)
	add_child(center)
	var title := Label.new()
	title.text = StoryText.SAGA_TITLE
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)
	var sub := Label.new()
	sub.text = StoryText.SAGA_SUBTITLE
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.92, 0.9, 0.95))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	center.add_child(row)
	var prog: Dictionary = _gs.story_progress() if _gs != null else {"unlocked": 1, "completed": []}
	for n in range(1, StoryText.count() + 1):
		row.add_child(_chapter_card(n, n <= int(prog["unlocked"]), (prog["completed"] as Array).has(n) or (prog["completed"] as Array).has(float(n))))
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(foot)
	_buttons = foot
	_add_button("Main Menu", _to_main_menu)

func _chapter_card(n: int, unlocked: bool, done: bool) -> Button:
	var ch: Dictionary = StoryText.chapter(n)
	var b := Button.new()
	b.name = "Chapter%d" % n
	b.custom_minimum_size = Vector2(250, 268)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not unlocked
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 10
	v.offset_bottom = -10
	v.add_theme_constant_override("separation", 6)
	b.add_child(v)
	var art := TextureRect.new()
	art.texture = StoryText.image(str(ch["image"]))
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.custom_minimum_size = Vector2(0, 128)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.clip_contents = true
	if not unlocked:
		art.modulate = Color(0.25, 0.25, 0.3)
	v.add_child(art)
	var k := Label.new()
	k.text = "CHAPTER %d" % n
	k.add_theme_font_size_override("font_size", 15)
	k.add_theme_color_override("font_color", Color(1.0, 0.84, 0.35))
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(k)
	var t := Label.new()
	t.text = str(ch["title"]) if unlocked else "???"
	t.add_theme_font_size_override("font_size", 19)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := Label.new()
	s.text = "Won" if done else ("Ready" if unlocked else "Locked")
	s.add_theme_font_size_override("font_size", 14)
	s.add_theme_color_override("font_color", Color(0.55, 0.95, 0.5) if done else (Color(0.9, 0.9, 1.0) if unlocked else Color(0.6, 0.6, 0.7)))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	b.pressed.connect(func(): _go("intro", n))
	return b

# ----------------------------------------------------------------- flow
func _fade_in() -> void:
	var tw := create_tween()
	tw.tween_property(_fader, "color:a", 0.0, FADE)

func _fade_out() -> void:
	_fader.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fader, "color:a", 1.0, FADE)
	await tw.finished

func _go(phase: String, chapter: int) -> void:
	await _fade_out()
	_phase = phase
	_chapter = clampi(chapter, 1, StoryText.count())
	if _gs != null:
		_gs.story_screen = {"phase": _phase, "chapter": _chapter}
	_build()
	_fade_in()

func _begin_chapter() -> void:
	await _fade_out()
	if _gs != null:
		_gs.start_story_chapter(_chapter)
	get_tree().change_scene_to_file("res://scenes/WorldMap.tscn")

func _to_main_menu() -> void:
	await _fade_out()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
