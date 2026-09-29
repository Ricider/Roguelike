# CardHover: hover help for the world map screen, in the pixel UI style.
#  - show_card(): the description card from the old battle screen (art, name,
#    HP / damage or income, Money / Bio / Influence costs, special effect) plus
#    the two trait boxes ([Flying]/[Grounded], [HasRange]/[Melee]) beside it.
#  - show_text(): a small tooltip box ([Brackets] are highlighted orange).
# Everything is click-through, drawn on top and kept inside the window.
extends Control
class_name CardHover

const ORANGE := "#FF9500"
const CARD_W := 340.0
const TRAIT_W := 176.0
const GAP := 8.0

var _card_panel: PanelContainer = null
var _traits: VBoxContainer = null
var _text_panel: PanelContainer = null
var _text_label: RichTextLabel = null
var _gen: int = 0 # bumps on every show/hide so stale deferred layouts are dropped

func _ready() -> void:
	top_level = true
	z_index = 900
	z_as_relative = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_panel = PanelContainer.new()
	_card_panel.visible = false
	add_child(_card_panel)
	_traits = VBoxContainer.new()
	_traits.visible = false
	_traits.add_theme_constant_override("separation", 6)
	add_child(_traits)
	_text_panel = PanelContainer.new()
	_text_panel.visible = false
	add_child(_text_panel)
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(280, 0)
	_text_label.add_theme_font_size_override("normal_font_size", 15)
	_text_panel.add_child(_text_label)
	_click_through(self)

func _click_through(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_click_through(c)

func hide_all() -> void:
	_gen += 1
	if _card_panel != null:
		_card_panel.visible = false
		_traits.visible = false
		_text_panel.visible = false

# [Word] -> orange, like the old battle-screen tooltips.
static func highlight(text: String) -> String:
	var out := ""
	var i := 0
	while i < text.length():
		var ch := text[i]
		if ch == "[" and not text.substr(i).begins_with("[color") and not text.substr(i).begins_with("[/") and not text.substr(i).begins_with("[b]") and not text.substr(i).begins_with("[i]"):
			var close := text.find("]", i)
			if close > i:
				out += "[color=%s]%s[/color]" % [ORANGE, text.substr(i, close - i + 1).replace("[", "[lb]")]
				i = close + 1
				continue
		out += ch
		i += 1
	return out

# ------------------------------------------------------------------- text tip
func show_text(bb: String, near: Rect2) -> void:
	hide_all()
	_text_label.text = highlight(bb)
	_text_panel.visible = true
	_place_later(_text_panel, near, _gen, false, false)

# ---------------------------------------------------------------- card preview
# info keys (all optional): owner, owner_color (Color), hp, hp_max, hp_base, dmg, dmg_base,
# income, money, money_base, bio, influence (shop price), ranged, flying, notes (Array of bbcode lines)
# below=true opens the card under the anchor (e.g. to keep a targeting arrow above it visible).
func show_card(card: Card, info: Dictionary, anchor: Rect2, below: bool = false) -> void:
	hide_all()
	for c in _card_panel.get_children():
		_card_panel.remove_child(c)
		c.queue_free()
	for c in _traits.get_children():
		_traits.remove_child(c)
		c.queue_free()
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.custom_minimum_size = Vector2(CARD_W - 28, 0)
	_card_panel.add_child(root)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	var art := Card.create_sprite_for(card.card_name, Vector2(112, 112))
	art.custom_minimum_size = Vector2(112, 112)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.clip_contents = true
	top.add_child(art)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	top.add_child(col)
	var name_lbl := Label.new()
	name_lbl.text = card.card_name
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	col.add_child(name_lbl)
	if info.has("owner"):
		var own := Label.new()
		own.text = str(info["owner"])
		own.add_theme_font_size_override("font_size", 15)
		own.add_theme_color_override("font_color", (info.get("owner_color", Color.WHITE) as Color).lightened(0.3))
		col.add_child(own)
	# HP | DMG or INC
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 4)
	col.add_child(stats)
	# on the map: current/max HP; in hand or shop: effective HP coloured against the base card
	var hp: int = int(info.get("hp", _base_hp(card)))
	var hp_max: int = int(info.get("hp_max", hp))
	var hp_col: Color = _cmp_color(hp, hp_max, true) if info.has("hp_max") else _cmp_color(hp, int(info.get("hp_base", hp)), true)
	_stat(stats, "res://Assets/UI/heart.png", ("%d/%d" % [hp, hp_max]) if hp_max != hp else str(hp), hp_col, 22)
	if card is Unit:
		var dmg: int = int(info.get("dmg", (card as Unit).Damage))
		var dmg_base: int = int(info.get("dmg_base", (card as Unit).Damage))
		_stat(stats, "res://Assets/UI/sword.png", str(dmg), _cmp_color(dmg, dmg_base, true), 22)
	elif card is Building:
		_stat(stats, "res://Assets/UI/income_icon.png", str(int(info.get("income", (card as Building).Income))), Color.WHITE, 22)
	# Money | Bio | Influence
	var costs := HBoxContainer.new()
	costs.add_theme_constant_override("separation", 4)
	col.add_child(costs)
	var money: int = int(info.get("money", card.MoneyCost))
	_stat(costs, "res://Assets/UI/money_icon.png", str(money), _cmp_color(money, int(info.get("money_base", card.MoneyCost)), false), 18)
	_stat(costs, "res://Assets/UI/bio_icon.png", str(int(info.get("bio", card.BioCost))), Color.WHITE, 18)
	if info.has("influence"):
		_stat(costs, "res://Assets/UI/influence_icon.png", str(int(info["influence"])), Color(1.0, 0.86, 0.35), 18)
	# Effect text: traits prefix + special effect + extra notes
	var eff := RichTextLabel.new()
	eff.bbcode_enabled = true
	eff.fit_content = true
	eff.scroll_active = false
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eff.custom_minimum_size = Vector2(CARD_W - 28, 0)
	eff.add_theme_font_size_override("normal_font_size", 16)
	var lines: Array = []
	var ranged: bool = bool(info.get("ranged", card is Unit and (card as Unit).HasRange))
	var flying: bool = card is Unit and (card as Unit).Flying
	if card is Unit:
		lines.append("[color=%s][lb]%s[rb] [lb]%s[rb][/color]" % [ORANGE, "HasRange" if ranged else "Melee", "Flying" if flying else "Grounded"])
	if card.SpecialEffect != "":
		lines.append(card.SpecialEffect)
	for n in info.get("notes", []):
		lines.append(str(n))
	eff.text = "\n".join(lines) if not lines.is_empty() else " "
	root.add_child(eff)
	_card_panel.visible = true
	if card is Unit:
		_trait_box("[Flying]" if flying else "[Grounded]",
			"Takes half damage from attackers without Range. Gets no mountain cover. In a forest it takes 1 less damage from flying attackers." if flying
			else "On a mountain hex it takes 1 less damage from every hit. In a forest it takes 1 less damage from flying attackers.")
		_trait_box("[HasRange]" if ranged else "[Melee]",
			"Fires at a random target (any card or the flag) of the closest enemy nation." if ranged
			else "Fires at the closest enemy target (card or flag) anywhere on the map. Deals half damage to Flying units.")
		_traits.visible = true
	elif card is Building:
		_trait_box("[Building]", "Can't be placed on mountain hexes.")
		_traits.visible = true
	_click_through(_card_panel)
	_click_through(_traits)
	_place_later(_card_panel, anchor, _gen, true, below)

func _base_hp(card: Card) -> int:
	if card is Unit:
		return (card as Unit).HitPoints
	if card is Building:
		return (card as Building).HitPoints
	return 0

# green when better than base, red when worse (higher_is_better picks the direction)
func _cmp_color(val: int, base: int, higher_is_better: bool) -> Color:
	if val == base:
		return Color.WHITE
	var better := (val > base) == higher_is_better
	return Color(0.45, 0.95, 0.45) if better else Color(1, 0.45, 0.4)

func _stat(row: HBoxContainer, icon_path: String, text: String, col: Color, size_px: int) -> void:
	var ic := TextureRect.new()
	ic.texture = load(icon_path) as Texture2D
	ic.custom_minimum_size = Vector2(size_px, size_px)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	row.add_child(l)

func _trait_box(title: String, body: String) -> void:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(TRAIT_W, 0)
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.scroll_active = false
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(TRAIT_W - 28, 0)
	t.add_theme_font_size_override("normal_font_size", 13)
	t.text = highlight(title) + ": " + body
	box.add_child(t)
	_traits.add_child(box)

# ---------------------------------------------------------------- placement
# Wrapped text measures tall before it has a width, so sizes settle a frame
# later; place now (best guess) and again once layout is done.
func _place_later(panel: Control, anchor: Rect2, gen: int, with_traits: bool, below: bool) -> void:
	_place(panel, anchor, with_traits, below)
	await get_tree().process_frame
	if gen != _gen or not is_instance_valid(panel) or not panel.visible:
		return
	_place(panel, anchor, with_traits, below)

func _place(panel: Control, anchor: Rect2, with_traits: bool, below: bool) -> void:
	panel.reset_size()
	var vp := get_viewport_rect().size
	var sz := panel.size
	# above the anchor (or below when asked), flipping if it would leave the screen
	var above_y := anchor.position.y - sz.y - GAP
	var below_y := anchor.end.y + GAP
	var pos := Vector2(anchor.get_center().x - sz.x * 0.5, below_y if below else above_y)
	if below and pos.y + sz.y > vp.y - GAP:
		pos.y = above_y
	elif not below and pos.y < GAP:
		pos.y = below_y
	pos.x = clampf(pos.x, GAP, maxf(GAP, vp.x - sz.x - GAP))
	pos.y = clampf(pos.y, GAP, maxf(GAP, vp.y - sz.y - GAP))
	panel.global_position = pos.floor()
	if with_traits and _traits.visible:
		_traits.reset_size()
		var tsz := _traits.size
		var tx := pos.x - tsz.x - GAP
		if tx < GAP:
			tx = pos.x + sz.x + GAP # no room on the left: put them on the right
		var ty := clampf(pos.y + (sz.y - tsz.y) * 0.5, GAP, maxf(GAP, vp.y - tsz.y - GAP))
		_traits.global_position = Vector2(tx, ty).floor()
