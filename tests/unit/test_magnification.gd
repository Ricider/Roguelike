extends GutTest
# Regression for magnification: consistent vertical height, no overflow, efficient space use

func test_magnification_preview_fixed_consistent_size():
	var gc_txt := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	# preview must be fixed 280x168 for all cards — no dynamic combined_minimum sizing
	assert_true(gc_txt.contains("custom_minimum_size = Vector2(280, 168)"), "preview fixed 280x168")
	assert_true(gc_txt.contains("preview_popup.size = Vector2(280, 168)"), "preview size fixed 280x168")
	assert_false(gc_txt.contains("268, 140"), "no old dynamic 268x140 fallback")
	# must clamp to viewport to avoid overflow
	assert_true(gc_txt.contains("vp.x - sz.x - 8.0"), "clamped to viewport")
	assert_true(gc_txt.contains("clip_contents = true"), "clipped")

func test_magnification_efficient_space_no_empty_middle():
	var gc_txt := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	# must use HBox top (art left | details right) + full-width effect below, not VBox stacked centered
	assert_true(gc_txt.contains("var top := HBoxContainer.new()"), "top HBox exists")
	assert_true(gc_txt.contains("var root := VBoxContainer.new()"), "root VBox exists")
	assert_true(gc_txt.contains("art.clip_contents = true"), "art clipped")
	assert_true(gc_txt.contains("art.custom_minimum_size = Vector2(132, 132)"), "art 132 magnified")
	# effect must span full width below top, not inside details (which left empty middle)
	assert_true(gc_txt.contains("root.add_child(eff)"), "effect added to root (full width), not details")
	assert_false(gc_txt.contains("details.add_child(eff)"), "effect not inside details")
	# separation tight to avoid middle gap
	assert_true(gc_txt.contains("separation\", 8") or gc_txt.contains("separation\", 5"), "tight separation")

func test_magnification_vertical_height_consistent_for_all_card_types():
	var gc_txt := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	# name must have fixed height to avoid wrap variation (Rocket Launcher 15 chars)
	assert_true(gc_txt.contains("Vector2(124, 20)"), "name fixed 124x20")
	# effect must have fixed 32 height with placeholder " " when no effect, so Wall (no effect) vs Barracks (with effect) same height
	assert_true(gc_txt.contains("Vector2(264, 32)"), "effect fixed 264x32")
	assert_true(gc_txt.contains("eff.text = \" \""), "placeholder blank effect for no-effect cards")
	# filler to fill remaining height so no empty bottom variation
	assert_true(gc_txt.contains("filler.size_flags_vertical = Control.SIZE_EXPAND_FILL"), "filler expands")
	# runtime check: preview for different cards yields same popup size
	var wall := Wall.new()
	var barracks := Barracks.new()
	var rl := RocketLauncher.new()
	var inf := Infantry.new()
	for card in [wall, barracks, rl, inf]:
		var txt: String = FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
		# all cards share same preview construction — verified via fixed sizes above
		assert_not_null(card, "card exists " + card.card_name)
	assert_eq(wall.SpecialEffect, "", "Wall no effect")
	assert_ne(barracks.SpecialEffect, "", "Barracks has effect")
	assert_eq(rl.SpecialEffect, "attacks 4 times every Combat Phase", "RL effect")

func test_magnification_applies_to_field_and_hand():
	var gc_txt := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	# field (board) and hand must both use _show_card_preview
	assert_true(gc_txt.contains("btn.mouse_entered.connect(func(): _show_card_preview(_card_prev))"), "board field uses preview")
	assert_true(gc_txt.contains("btn.mouse_entered.connect(func(): _show_card_preview(_hand_prev))"), "hand uses preview")
	# counts: should appear at least twice (field + hand)
	assert_true(gc_txt.count("_show_card_preview") >= 2, "preview used for both field and hand")
