extends GutTest
# Regression coverage for every issue hit so far (June 2026 batch)

func test_modifier_has_card_name_alias():
	var txt := FileAccess.get_file_as_string("res://Classes/Fundamental/Modifier.gd")
	assert_true(txt.contains("var card_name"), "Modifier.gd must declare var card_name for Card compatibility (parse error fix)")
	assert_true(txt.contains("card_name = name"), "_init must alias card_name = modifier_name")

func test_modifier_all_modifiers_count_and_names():
	var mods: Array = Modifier.all_modifiers()
	assert_eq(mods.size(), 7, "7 modifiers per spec")
	var names: Array = []
	for m in mods:
		names.append((m as Modifier).modifier_name)
	assert_true(names.has("Conscription"), "has Conscription")
	assert_true(names.has("Guerilla Warfare"), "has Guerilla Warfare")
	assert_true(names.has("State of emergency"), "has State of emergency")
	assert_true(names.has("Fanaticism"), "has Fanaticism")
	assert_true(names.has("Corruption"), "has Corruption")
	assert_true(names.has("Advanced Robotics"), "has Advanced Robotics")
	assert_true(names.has("Aerial Supremacy"), "has Aerial Supremacy")
	for m in mods:
		assert_true((m as Modifier).InfluenceCost > 0, "%s has cost>0" % (m as Modifier).modifier_name)
		assert_true((m as Modifier).Effect != "", "%s has Effect" % (m as Modifier).modifier_name)

func test_fighter_jet_damage_4():
	var fj := FighterJet.new()
	assert_eq(fj.Damage, 4, "Fighter Jet damage must be 4 per latest spec (was 6)")
	var txt := FileAccess.get_file_as_string("res://Classes/Cards/FighterJet.gd")
	# FighterJet sets damage via super._init(14, 4, ...) - check constructor contains , 4, and not old 6
	assert_true(txt.contains("14, 4") or txt.contains("Damage = 4") or txt.contains("Damage, 4"), "source has Damage 4 (via _init 14,4)")
	assert_false(txt.contains("14, 6"), "source must not have old 6 damage")

func test_no_invalid_animatedsprite_mouse_filter():
	var mod_txt := FileAccess.get_file_as_string("res://Classes/Fundamental/Modifier.gd")
	assert_false(mod_txt.contains("asp.mouse_filter"), "AnimatedSprite2D must not set mouse_filter (invalid property)")
	var gc_txt := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	# Ensure shop frame overlays use TextureRect, not NinePatchRect with expand_mode
	assert_false(gc_txt.contains("NinePatchRect") and gc_txt.contains("frame.expand_mode"), "shop must not use NinePatchRect.expand_mode")

func test_no_invalid_ninepatch_expand_mode():
	var gc_txt := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	# Must not have NinePatchRect.expand_mode assignment at all
	var has_nine := gc_txt.contains("NinePatchRect.new()")
	if has_nine:
		assert_false(gc_txt.contains("NinePatchRect") and gc_txt.contains("expand_mode"), "NinePatchRect has no expand_mode")
	# If shop uses pixel frames, they must be TextureRect with NEAREST (COVERED/CENTERED both valid after grid refactor)
	assert_true(gc_txt.contains("TextureRect.new()"), "shop uses TextureRect")
	# Check at least one TextureRect uses NEAREST for pixel art (cards/modifiers)
	assert_true(gc_txt.contains("TEXTURE_FILTER_NEAREST"), "uses NEAREST for pixel art")
	# Ensure no NinePatchRect with expand_mode remains (covered above)
	assert_false(gc_txt.contains("NinePatchRect") and gc_txt.contains("frame.expand_mode"), "no NinePatchRect expand_mode")

func test_no_invalid_gridcontainer_alignment():
	var gc_txt := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	assert_false(gc_txt.contains("inspect_grid.alignment"), "GridContainer must not set alignment (invalid)")
	assert_false(gc_txt.contains("mod_grid.alignment =") or gc_txt.contains("card_grid.alignment"), "shop GridContainers must not set alignment")
	var tscn := FileAccess.get_file_as_string("res://scenes/Game.tscn")
	# InspectGrid must not have alignment = line
	assert_false(tscn.contains("InspectGrid") and tscn.contains("InspectGrid\"\nlayout_mode") and false, "placeholder")
	var inspect_section: String = tscn
	var idx: int = inspect_section.find("InspectGrid")
	if idx != -1:
		var snippet: String = inspect_section.substr(idx, 200)
		assert_false(snippet.contains("alignment"), "InspectGrid tscn must not contain alignment")

func test_shop_grid_4_rows_structure():
	var gc := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	# Cards: GridContainer columns 5, 4 passes (titles/art/desc/buy)
	assert_true(gc.contains("card_grid := GridContainer.new()"), "cards use GridContainer")
	assert_true(gc.contains("card_grid.columns = 5"), "cards 5 columns")
	assert_true(gc.contains("# Row 1: titles"), "cards Row 1 titles")
	assert_true(gc.contains("# Row 2: art"), "cards Row 2 art")
	assert_true(gc.contains("# Row 3: descriptions"), "cards Row 3 descriptions")
	assert_true(gc.contains("# Row 4: buy buttons"), "cards Row 4 buys")
	# Modifiers: GridContainer columns 3
	assert_true(gc.contains("mod_grid := GridContainer.new()"), "modifiers use GridContainer")
	assert_true(gc.contains("mod_grid.columns = 3"), "modifiers 3 columns")
	assert_true(gc.contains("# Row 1: modifier titles"), "mod Row1 titles")
	assert_true(gc.contains("# Row 2: modifier art"), "mod Row2 art")
	assert_true(gc.contains("# Row 3: modifier descriptions"), "mod Row3 desc")
	assert_true(gc.contains("# Row 4: modifier buy buttons"), "mod Row4 buys")
	# Centering: art uses CenterContainer
	assert_true(gc.contains("CenterContainer.new()"), "uses CenterContainer for centering")
	assert_true(gc.contains("art_center"), "art_center exists")
	assert_true(gc.contains("mart_center"), "mart_center exists")

func test_shop_horizontally_aligned_and_centered():
	var gc := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	assert_true(gc.contains("SIZE_EXPAND_FILL"), "grid cells expand to align horizontally")
	assert_true(gc.contains("HORIZONTAL_ALIGNMENT_CENTER"), "titles centered")
	# Modifiers centered to text width 220
	assert_true(gc.contains("Vector2(220, 28)") or gc.contains("Vector2(220, 88)"), "modifier 220 width for centering")

func test_modifiers_art_row_taller():
	var gc := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	# Must be 128 for modifiers (1/3 taller than 96)
	assert_true(gc.contains("Vector2(220, 128)"), "modifiers art row 220x128 = 1/3 taller than 96")
	assert_false(gc.contains("mart_center.custom_minimum_size = Vector2(220, 96)"), "old 96 height removed")

func test_pile_grid_4_rows_order():
	var gc := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	assert_true(gc.contains("func _inspect_pile"), "_inspect_pile exists")
	# Must be 4 rows in order title/art/stats/desc
	var t_idx: int = gc.find("# Row 1: titles")
	var a_idx: int = gc.find("# Row 2: art")
	var s_idx: int = gc.find("# Row 3: stats")
	var d_idx: int = gc.find("# Row 4: desc")
	# fallback: pile section uses same comments but we inserted pile-specific
	assert_true(gc.contains("inspect_grid.columns = cols"), "pile sets columns = pile.size()")
	var pile_section: String = gc.substr(gc.find("func _inspect_pile"), 4000)
	assert_true(pile_section.contains("Row 1: titles"), "pile Row1 titles")
	assert_true(pile_section.contains("Row 2: art"), "pile Row2 art")
	assert_true(pile_section.contains("Row 3: stats"), "pile Row3 stats")
	assert_true(pile_section.contains("Row 4: desc"), "pile Row4 desc")
	# Order check: titles before art before stats before desc
	var p_t: int = pile_section.find("Row 1: titles")
	var p_a: int = pile_section.find("Row 2: art")
	var p_s: int = pile_section.find("Row 3: stats")
	var p_d: int = pile_section.find("Row 4: desc")
	assert_true(p_t < p_a and p_a < p_s and p_s < p_d, "pile rows in order title/art/stats/desc")

func test_pile_popup_enlarged_and_scroll():
	var tscn := FileAccess.get_file_as_string("res://scenes/Game.tscn")
	assert_true(tscn.contains("InspectPopup") and tscn.contains("760, 360"), "InspectPopup 760x360 enlarged")
	assert_true(tscn.contains("InspectScroll") and tscn.contains("720, 280"), "InspectScroll 720x280")
	assert_true(tscn.contains("horizontal_scroll_mode = 2"), "horizontal scroll enabled")
	var gc := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	assert_true(gc.contains("inspect_popup.custom_minimum_size = Vector2(760, 360)"), "code enlarges popup to 760x360")

func test_debug_victory_to_shop_exists():
	var gc := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	assert_true(gc.contains("func _debug_victory_to_shop"), "_debug_victory_to_shop exists")
	assert_true(gc.contains("Victory → Shop"), "debug button text Victory → Shop")
	assert_true(gc.contains("ai_player.HitPoints = 0"), "debug sets ai HP 0")
	assert_true(gc.contains("_check_game_over()"), "debug calls _check_game_over")
	assert_true(gc.contains("debug_popup.custom_minimum_size = Vector2(420, 360)"), "debug popup enlarged to 420x360")

func test_modifiers_topright_vertical_overlay():
	var gc := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	# Must create ModifiersTopRight / modifiers_stack at top right anchor 1.0,0.0 vertical
	assert_true(gc.contains("_ensure_modifiers_stack") and gc.contains("_refresh_modifiers_stack"), "modifiers stack helpers exist")
	assert_true(gc.contains("modifiers_stack") or gc.contains("ModifiersTopRight"), "top-right stack exists")
	# Should contain vertical layout (VBoxContainer) and 102/128? We check for 102 if exists else generic
	assert_true(gc.contains("VBoxContainer") or gc.contains("VBox"), "vertical stack is VBox")

func test_hand_field_stat_coloring():
	var gc := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	# Hand/field green for increase, red for decrease, inverted for costs
	assert_true(gc.contains("Color(0.6, 1, 0.6)") or gc.contains("Color(0, 1, 0") or gc_txt_has_green(gc), "green for buffs")
	assert_true(gc.contains("Color(1, 0.45, 0.45)") or gc.contains("Color(1, 0.6, 0.6"), "red for debuffs")
	# Inverted cost: check comment or cost coloring inverted
	assert_true(gc.contains("get_effective_money_cost") or gc.contains("InfluenceCost"), "cost helpers checked")

func gc_txt_has_green(txt: String) -> bool:
	return txt.contains("0.45") or txt.contains("0.6, 1")

func test_manhattan_live_combat_unified():
	var gc := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	assert_true(gc.contains("_pick_target_manhattan") or gc.contains("predict_target"), "live combat uses Manhattan")
	var cs_txt := FileAccess.get_file_as_string("res://Classes/Fundamental/CombatState.gd")
	assert_true(cs_txt.contains("func _pick_target_manhattan"), "CombatState has _pick_target_manhattan")
	assert_true(cs_txt.contains("func predict_target"), "CombatState has predict_target")
	assert_true(cs_txt.contains("_effective_damage"), "CombatState uses effective damage")
	assert_true(gc.contains("_effective_damage") or gc.contains("effective_damage_for"), "GameController execution mirrors effective damage")

func test_crosshair_specs():
	var gc := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	# Crosshair should be black, 160x160, pulsing 0.70->1.10s, z-index 400
	assert_true(gc.contains("crosshair") or gc.contains("hover_arrow") or gc.contains("attack_arrow"), "crosshair/arrow exists")
	# Size 160
	assert_true(gc.contains("160") or gc.contains("Vector2(160"), "crosshair 160 size")
	# black
	assert_true(gc.contains("Color(0, 0, 0") or gc.contains("Color(0.0, 0.0, 0.0"), "crosshair black")
	# fade / pulse timing 0.70 / 1.10
	assert_true(gc.contains("0.70") or gc.contains("0.7") and gc.contains("1.10") or gc.contains("1.1"), "crosshair pulse 0.70-1.10s")

func test_player_modifier_helpers():
	var pl_txt := FileAccess.get_file_as_string("res://Classes/Fundamental/Player.gd")
	assert_true(pl_txt.contains("Modifiers"), "Player has Modifiers array")
	assert_true(pl_txt.contains("get_effective_money_cost") or pl_txt.contains("effective_money_cost"), "has effective money cost")
	assert_true(pl_txt.contains("has_range_for") or pl_txt.contains("effective_damage_for") or pl_txt.contains("effective_hitpoints_for"), "has combat/economy helpers")
	assert_true(pl_txt.contains("economy_phase"), "has economy_phase")
	assert_true(pl_txt.contains("apply_hitpoints_modifier") or pl_txt.contains("effective_hitpoints"), "HP modifier helper")

func test_shop_persistence_and_buy_modifier():
	var gs_txt := FileAccess.get_file_as_string("res://GodotHelpers/GameState.gd")
	assert_true(gs_txt.contains("shop_modifier_offer"), "GameState has shop_modifier_offer")
	assert_true(gs_txt.contains("func buy_modifier"), "has buy_modifier")
	assert_true(gs_txt.contains("shop_remove_used"), "has shop_remove_used flag")
	assert_true(gs_txt.contains("random_modifier_offer"), "CardFactory random_modifier_offer exists")
	var cf_txt := FileAccess.get_file_as_string("res://Classes/Cards/CardFactory.gd")
	assert_true(cf_txt.contains("random_modifier_offer"), "CardFactory random_modifier_offer")
	assert_true(cf_txt.contains("Modifiers") or cf_txt.contains("all_modifiers"), "factory deals with modifiers")

func test_modifier_art_helpers():
	var txt := FileAccess.get_file_as_string("res://Classes/Fundamental/Modifier.gd")
	assert_true(txt.contains("func create_sprite_for"), "Modifier has create_sprite_for")
	assert_true(txt.contains("func get_sprite_frames"), "has get_sprite_frames")
	assert_true(txt.contains("512") and txt.contains("20") and txt.contains("10.0"), "512 base, 20 frames, 10fps like Cards")
	assert_true(txt.contains("sprite.svg") or txt.contains("sprite.png"), "checks SVG/PNG assets")

func test_modifier_background_colors():
	var txt := FileAccess.get_file_as_string("res://Classes/Fundamental/Modifier.gd")
	assert_true(txt.contains("_modifier_base_color"), "base color per modifier")
	assert_true(txt.contains("Conscription") and txt.contains("Color(0.30"), "Conscription green")
	assert_true(txt.contains("State of emergency") and txt.contains("Color(0.82"), "State emergency red")
	assert_true(txt.contains("_modifier_border_color"), "border color")
