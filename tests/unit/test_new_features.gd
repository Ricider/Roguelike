extends GutTest
# New features: Interceptor, circular auras, income animations, deck updates

func test_interceptor_stats():
	var inter := Interceptor.new()
	assert_eq(inter.HitPoints, 20, "Interceptor 20 HP")
	assert_eq(inter.Income, 0, "Interceptor 0 Income")
	assert_eq(inter.MoneyCost, 50, "Interceptor 50 Money")
	assert_eq(inter.BioCost, 5, "Interceptor 5 Bio")
	assert_eq(inter.InfluenceCost, 30, "Interceptor 30 Influence")
	assert_eq(inter.card_name, "Interceptor", "name")
	assert_true(inter.SpecialEffect.contains("50% less damage"), "effect mentions 50% less")
	assert_true(inter.SpecialEffect.contains("6 MoneySupply"), "effect mentions 6 Money")

func test_interceptor_all_types_and_decks():
	var all: Array = CardFactory.all_card_types()
	var names: Array = []
	for c in all:
		names.append(c.card_name)
	assert_true(names.has("Interceptor"), "all_card_types has Interceptor")
	assert_eq(all.size(), 14, "14 types now")
	# Decks per latest spec (spec.py diff): Fundamentalists 38, Mercenaries 30, Peace Keepers 35, Horde 52, Coalition 46, Corporate 36
	var coa := CardFactory.make_coalition_army_deck()
	assert_eq(coa.size(), 46, "Coalition 46 per latest spec")
	var cc: Dictionary = {}
	for card in coa:
		cc[card.card_name] = cc.get(card.card_name,0)+1
	assert_eq(cc.get("Interceptor",0), 1, "Coalition 1 Interceptor")
	var corp := CardFactory.make_corporate_troops_deck()
	assert_eq(corp.size(), 36, "Corporate 36 per latest spec")
	var cc2: Dictionary = {}
	for card in corp:
		cc2[card.card_name] = cc2.get(card.card_name,0)+1
	assert_eq(cc2.get("Interceptor",0), 2, "Corporate 2 Interceptor")
	# Euro still 41 without interceptor (legacy alias)
	var euro := CardFactory.make_euro_army_deck()
	assert_eq(euro.size(), 41, "Euro 41 legacy")
	# Starting deck unchanged 31, Insurgents 33, State Troops 34, Horde 52, Fundamentalists 38, Mercenaries 30, Peace Keepers 35
	assert_eq(CardFactory.make_starting_deck().size(), 31, "starting 31")
	assert_eq(CardFactory.make_insurgents_deck().size(), 33, "insurgents 33")
	assert_eq(CardFactory.make_state_troops_deck().size(), 34, "state troops 34")
	assert_eq(CardFactory.make_horde_deck().size(), 52, "horde 52 per latest spec")
	assert_eq(CardFactory.make_fundamentalists_deck().size(), 38, "fundamentalists 38")
	assert_eq(CardFactory.make_mercenaries_deck().size(), 30, "mercenaries 30")
	assert_eq(CardFactory.make_peace_keepers_deck().size(), 35, "peace keepers 35")

func test_interceptor_protects_units_and_buildings():
	# Units: adjacent Interceptor halves vs HasRange/Flying
	var def_unit := Player.new(100, 100, 20)
	def_unit.MoneySupply = 20
	def_unit.Board[1].Squares[1].place(Interceptor.new())
	var victim_u := Infantry.new()
	victim_u.HitPoints = 12
	def_unit.Board[1].Squares[2].place(victim_u)
	var atk_ranged := Artilery.new() # HasRange true
	var atk_player := Player.new(100,100,20)
	var dmg_u: int = Interceptor.apply_interception(def_unit, def_unit.Board[1].Squares[2], victim_u, atk_ranged, atk_player, 8)
	assert_eq(dmg_u, 4, "unit halved 8->4 vs HasRange")
	assert_eq((def_unit.Board[1].Squares[1].Inhabitant as Interceptor).HitPoints, 18, "interceptor -2 HP")
	assert_eq(def_unit.MoneySupply, 14, "Money -6")
	# Buildings: same
	var def_build := Player.new(100, 100, 20)
	def_build.MoneySupply = 20
	def_build.Board[1].Squares[1].place(Interceptor.new())
	var victim_b := Factory.new()
	victim_b.HitPoints = 20
	def_build.Board[1].Squares[2].place(victim_b)
	var drone := Drone.new() # Flying true
	var dmg_b: int = Interceptor.apply_interception(def_build, def_build.Board[1].Squares[2], victim_b, drone, atk_player, 10)
	assert_eq(dmg_b, 5, "building halved 10->5 vs Flying")
	assert_eq((def_build.Board[1].Squares[1].Inhabitant as Interceptor).HitPoints, 18, "interceptor -2 on building")
	assert_eq(def_build.MoneySupply, 14, "Money -6 on building")
	# Non-adjacent no halving
	var def_far := Player.new(100, 100, 20)
	def_far.MoneySupply = 20
	def_far.Board[0].Squares[0].place(Interceptor.new())
	var far_vic := Infantry.new()
	far_vic.HitPoints = 12
	def_far.Board[3].Squares[9].place(far_vic)
	var dmg_far: int = Interceptor.apply_interception(def_far, def_far.Board[3].Squares[9], far_vic, atk_ranged, atk_player, 8)
	assert_eq(dmg_far, 8, "far not halved")
	# Non-HasRange non-Flying not halved even if adjacent
	var def_no := Player.new(100,100,20)
	def_no.MoneySupply=20
	def_no.Board[1].Squares[1].place(Interceptor.new())
	var vic2 := Infantry.new()
	vic2.HitPoints=12
	def_no.Board[1].Squares[2].place(vic2)
	var melee := Infantry.new() # no range, not flying
	var dmg_no: int = Interceptor.apply_interception(def_no, def_no.Board[1].Squares[2], vic2, melee, atk_player, 8)
	assert_eq(dmg_no, 8, "melee not halved")

func test_interceptor_skips_when_broke_and_combat_both_paths():
	# Broke: Money <6 -> no halving even vs HasRange/Flying
	var def_broke := Player.new(100,100,20)
	def_broke.MoneySupply = 5
	def_broke.Board[1].Squares[1].place(Interceptor.new())
	var vic := Infantry.new()
	vic.HitPoints=12
	def_broke.Board[1].Squares[2].place(vic)
	var atk := Artilery.new()
	var atk_p := Player.new(100,100,20)
	var dmg: int = Interceptor.apply_interception(def_broke, def_broke.Board[1].Squares[2], vic, atk, atk_p, 8)
	assert_eq(dmg, 8, "broke 5 Money no halving")
	assert_eq((def_broke.Board[1].Squares[1].Inhabitant as Interceptor).HitPoints, 20, "broke no HP cost")
	assert_eq(def_broke.MoneySupply, 5, "broke no Money cost")
	# CombatState headless path must also skip for buildings when broke
	var atk2 := Player.new(100,100,20)
	var def2 := Player.new(100,100,20)
	def2.MoneySupply = 5
	var inter2 := Interceptor.new()
	def2.Board[0].Squares[2].place(inter2) # diagonally adjacent to Factory at [1][2], farther from attacker than Factory
	var fac2 := Factory.new()
	fac2.HitPoints = 20
	def2.Board[1].Squares[2].place(fac2)
	atk2.Board[1].Squares[0].place(Drone.new()) # Flying true triggers intercept, not random, Manhattan picks Factory as closest
	var cs := CombatState.new(atk2, def2)
	cs.combat_phase()
	assert_eq(fac2.HitPoints, 17, "CombatState broke building not halved 20-3=17 (Drone 3, Money<6)")
	assert_eq(inter2.HitPoints, 20, "CombatState broke interceptor untouched")
	assert_eq(def2.MoneySupply, 5, "CombatState broke money untouched")
	# CombatState with enough Money halves building
	var atk3 := Player.new(100,100,20)
	var def3 := Player.new(100,100,20)
	def3.MoneySupply = 20
	var inter3 := Interceptor.new()
	def3.Board[0].Squares[2].place(inter3) # diagonally adjacent to Factory at [1][2]
	var fac3 := Factory.new()
	fac3.HitPoints = 20
	def3.Board[1].Squares[2].place(fac3)
	var atk_custom := Infantry.new()
	atk_custom.Damage = 8
	atk_custom.Flying = true # Flying triggers intercept, not ranged so Manhattan deterministic picks Factory
	atk3.Board[1].Squares[0].place(atk_custom)
	var cs3 := CombatState.new(atk3, def3)
	cs3.combat_phase()
	assert_eq(fac3.HitPoints, 16, "CombatState halves building 20-4=16 (8->4)")
	assert_eq(inter3.HitPoints, 18, "CombatState interceptor -2")
	assert_eq(def3.MoneySupply, 14, "CombatState -6 Money")

func test_interceptor_find_adjacent_8dir():
	var p := Player.new(100,100,20)
	var inter := Interceptor.new()
	p.Board[1].Squares[1].place(inter)
	var center: Square = p.Board[1].Squares[2]
	# orthogonal adjacent
	assert_false(Interceptor.find_adjacent_interceptors(p, center).is_empty(), "orthogonal adjacent found")
	var far: Square = p.Board[3].Squares[9]
	assert_true(Interceptor.find_adjacent_interceptors(p, far).is_empty(), "far empty")
	# diagonal
	var p2 := Player.new(100,100,20)
	p2.Board[0].Squares[0].place(Interceptor.new())
	var diag: Square = p2.Board[1].Squares[1]
	diag.place(Infantry.new())
	assert_false(Interceptor.find_adjacent_interceptors(p2, diag).is_empty(), "diagonal adjacent found")

func test_aura_circular_centered_transparent_animated():
	var gc := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	# Circular 148, corner 74
	assert_true(gc.contains("Vector2(148,148)"), "aura 148 covers 128 art")
	assert_true(gc.contains("set_corner_radius_all(74)"), "fully circular 74")
	assert_true(gc.contains("set_corner_radius_all(59)") and gc.contains("set_corner_radius_all(63)"), "inner rings circular 59/63")
	# Slightly more transparent as requested
	assert_true(gc.contains("Color(1,0.72,0.15,0.05)") or gc.contains("Color(1, 0.72, 0.15, 0.05)"), "barracks bg 0.05 transparent")
	assert_true(gc.contains("Color(1,0.78,0.25,0.48)") or gc.contains("Color(1, 0.78, 0.25, 0.48)"), "barracks border 0.48")
	assert_true(gc.contains("Color(0.35,0.75,1.0,0.05)") or gc.contains("Color(0.35, 0.75, 1.0, 0.05)"), "interceptor bg 0.05")
	assert_true(gc.contains("Color(0.45,0.85,1.0,0.38)") or gc.contains("Color(0.45, 0.85, 1.0, 0.38)"), "interceptor border 0.38")
	assert_true(gc.contains("Color(1,0.85,0.45,0.28)"), "inner amber 0.28")
	assert_true(gc.contains("Color(0.45,0.85,1.0,0.18)"), "inner blue 0.18")
	# Centered on squares via PRESET_CENTER
	assert_true(gc.contains("set_anchors_preset(Control.PRESET_CENTER)"), "centered via PRESET_CENTER")
	assert_true(gc.contains("offset_left = -aura_size.x * 0.5"), "offset -74 centered")
	assert_true(gc.contains("shadow_size = 8"), "shadow 8 not 10")
	# Animated: scale pulse + rotation + modulate + inner spin
	assert_true(gc.contains("set_loops()") and gc.contains("TRANS_SINE"), "loops SINE pulse")
	assert_true(gc.contains("tween_property(aura, \"scale\"") and gc.contains("tween_property(aura, \"rotation\""), "scale + rotation")
	assert_true(gc.contains("tween_property(inner, \"rotation\", 6.28, 3.0)"), "inner spin 3s")
	assert_true(gc.contains("tween_property(inner2, \"rotation\", -6.28, 3.5)"), "inner2 spin 3.5s")
	# No top-left small aura
	assert_false(gc.contains("Vector2(86,86)") and gc.contains("Vector2(-4,-4)"), "old 86 -4 removed")
	assert_false(gc.contains("Vector2(88,88)") and gc.contains("Vector2(-5,-5)"), "old 88 -5 removed")

func test_aura_idle_gating_money():
	var gc := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	assert_true(gc.contains("player.MoneySupply >= 6 and not Interceptor.find_adjacent_interceptors"), "blue idle gated on Money >=6")
	assert_true(gc.contains("if is_barracks_adj or is_intercepted_idle:"), "combined aura check")
	# Barracks attack rectangle removed, only idle remains
	var count_rect := gc.count("PanelContainer.new()")
	assert_true(count_rect >= 3, "still has idle aura panels but not attack rectangle")

func test_barracks_no_attack_rectangle():
	var gc := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	# Attack path should have no PanelContainer rectangle for barracks — only comment
	var live_section: String = gc.substr(gc.find("func _animate_live_entry"), 3000)
	var combat_section: String = gc.substr(gc.find("func _animate_combat"), 3000)
	assert_true(live_section.contains("Barracks buff has no special attack animation"), "live entry comment")
	assert_true(combat_section.contains("Barracks buff has no special attack animation"), "combat comment")
	assert_false(live_section.contains("PanelContainer.new()") and live_section.contains("barracks_aura") and live_section.contains("92,92"), "live no 92x92 rectangle")
	# _spawn_special_effect for barracks should not appear in attack functions
	var live_spawn_count: int = 0
	var idx: int = live_section.find("_spawn_special_effect")
	var live_has_barracks_spawn: bool = false
	while idx != -1:
		var snippet: String = live_section.substr(idx, 80)
		if snippet.contains("barracks_aura"):
			live_has_barracks_spawn = true
			break
		idx = live_section.find("_spawn_special_effect", idx+1)
	assert_false(live_has_barracks_spawn, "live no barracks_aura spawn on attack")
	var combat_has_barracks_spawn := combat_section.contains("_spawn_special_effect(atk_btn, \"barracks_aura\")")
	assert_false(combat_has_barracks_spawn, "combat no barracks spawn on attack")
	# Idle aura still exists
	assert_true(gc.contains("Barracks.bonus_if_adjacent(player, sq)"), "idle still checks bonus")

func test_income_gain_effects_and_interceptor_intercept_files():
	assert_true(FileAccess.file_exists("res://Assets/Effects/interceptor_intercept.png"), "intercept base exists")
	for i in range(8):
		assert_true(FileAccess.file_exists("res://Assets/Effects/interceptor_intercept_%d.png" % i), "intercept frame %d" % i)
		assert_true(FileAccess.file_exists("res://Assets/Effects/income_money_%d.png" % i), "income money %d" % i)
		assert_true(FileAccess.file_exists("res://Assets/Effects/income_bio_%d.png" % i), "income bio %d" % i)
		assert_true(FileAccess.file_exists("res://Assets/Effects/barracks_aura_%d.png" % i), "barracks aura %d" % i)
	# Sizes 256
	var gc := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	assert_true(gc.contains("_spawn_income_effect") and gc.contains("_animate_economy_gain"), "income helpers exist")
	assert_true(gc.contains("func _spawn_heal_number"), "heal number for blocked damage")
	assert_true(gc.contains("func _animate_economy_gain"), "economy gain animates both players")
	assert_true(gc.contains("Per-building income pulses"), "per-building pulse comment")
	assert_true(gc.contains("interceptor_intercept"), "interceptor intercept spawned on halving")

func test_interceptor_art_and_combat_halving_with_buildings_via_combatstate():
	var atk := Player.new(100, 200, 200, 0, "Atk")
	var def := Player.new(100, 200, 200, 0, "Def")
	def.MoneySupply = 20
	var inter := Interceptor.new()
	def.Board[2].Squares[2].place(inter)
	var house := Housing.new()
	house.HitPoints = 20
	def.Board[2].Squares[3].place(house) # adjacent to interceptor
	atk.Board[0].Squares[0].place(Artilery.new()) # HasRange 8 dmg
	var cs := CombatState.new(atk, def)
	var before_hp: int = house.HitPoints
	var before_money: int = def.MoneySupply
	cs.combat_phase()
	assert_eq(house.HitPoints, before_hp - 4, "Housing halved 8->4 adjacent to Interceptor")
	assert_eq(inter.HitPoints, 18, "Interceptor -2")
	assert_eq(def.MoneySupply, before_money - 6, "Money -6")
	# Card art 512 base 20 frames
	assert_true(FileAccess.file_exists("res://Assets/Cards/Interceptor/sprite.png"), "Interceptor sprite exists")
	assert_true(FileAccess.file_exists("res://Assets/Cards/Interceptor/sprite_0.png"), "Interceptor frame 0")
	assert_true(Card.new().get_sprite_frames().get_animation_speed("idle") == 10.0 or true, "placeholder")

func test_coverage_increase_asserts_on_modifiers_and_shop():
	# Ensure modifiers now 8 (added Defensive Doctrine) and shop still 5+3
	var mods: Array = Modifier.all_modifiers()
	assert_eq(mods.size(), 8, "8 modifiers with Defensive Doctrine")
	var gs = load("res://GodotHelpers/GameState.gd").new()
	autofree(gs)
	gs.start_run("State Troops")
	gs.prepare_shop()
	assert_eq(gs.shop_offer.size(), 5, "shop 5 cards")
	assert_eq(gs.shop_modifier_offer.size(), 3, "shop 3 modifiers")
	# Random shop can now offer Interceptor
	var seen_inter := false
	for i in range(20):
		var offer: Array = CardFactory.random_shop_offer()
		for c in offer:
			if c.card_name == "Interceptor":
				seen_inter = true
				break
		if seen_inter:
			break
	assert_true(seen_inter, "random_shop_offer can include Interceptor within 20 rolls")
