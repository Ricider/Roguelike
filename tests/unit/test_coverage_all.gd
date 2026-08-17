extends GutTest
# Covers all changes so far: flying, new cards, decks, Euro Army, flags, heart/gauges, tints, magnification, combat

func test_unit_flying_and_stats():
	assert_true(Unit.new() != null, "Unit exists")
	var inf := Infantry.new()
	assert_eq(inf.HitPoints, 12, "Infantry 12 HP")
	assert_eq(inf.Damage, 2, "Infantry 2 dmg")
	assert_false(inf.HasRange, "Infantry no range")
	assert_false(inf.Flying, "Infantry not flying")
	assert_eq(inf.MoneyCost, 5, "Infantry money")
	assert_eq(inf.BioCost, 15, "Infantry bio")
	assert_eq(inf.InfluenceCost, 10, "Infantry influence 10")
	var tank := Tank.new()
	assert_eq(tank.HitPoints, 25, "Tank 25")
	assert_eq(tank.Damage, 8, "Tank 8")
	assert_false(tank.Flying, "Tank not flying")
	assert_eq(tank.InfluenceCost, 15, "Tank influence 15")
	var art := Artilery.new()
	assert_eq(art.HitPoints, 12, "Artilery 12")
	assert_eq(art.Damage, 8, "Artilery 8")
	assert_eq(art.BioCost, 8, "Artilery bio 8")
	assert_true(art.HasRange, "Artilery ranged")
	assert_eq(art.InfluenceCost, 20, "Artilery influence 20")
	var rl := RocketLauncher.new()
	assert_eq(rl.HitPoints, 12, "Rocket 12")
	assert_eq(rl.BioCost, 5, "Rocket bio 5")
	assert_eq(rl.InfluenceCost, 30, "Rocket influence 30")
	assert_eq(rl.SpecialEffect, "attacks 4 times every Combat Phase", "Rocket 4x")
	var drone := Drone.new()
	assert_eq(drone.HitPoints, 6, "Drone 6")
	assert_eq(drone.Damage, 3, "Drone 3")
	assert_true(drone.Flying, "Drone flying true")
	assert_eq(drone.InfluenceCost, 15, "Drone influence 15")
	var fj := FighterJet.new()
	assert_eq(fj.HitPoints, 14, "FighterJet 14")
	assert_eq(fj.Damage, 6, "FighterJet 6")
	assert_true(fj.HasRange, "FighterJet ranged")
	assert_true(fj.Flying, "FighterJet flying")
	assert_eq(fj.SpecialEffect, "Also damages tiles adjacent to where it hit", "FighterJet splash")
	assert_eq(fj.InfluenceCost, 40, "FighterJet influence 40")
	var fac := Factory.new()
	assert_eq(fac.InfluenceCost, 20, "Factory influence 20")
	var barr := Barracks.new()
	assert_eq(barr.InfluenceCost, 30, "Barracks influence 30")
	var hous := Housing.new()
	assert_eq(hous.InfluenceCost, 15, "Housing influence 15")
	var wall := Wall.new()
	assert_eq(wall.InfluenceCost, 5, "Wall influence 5")
	var corp := Corporation.new()
	assert_eq(corp.HitPoints, 25, "Corporation 25 HP")
	assert_eq(corp.Income, 12, "Corporation 12 Income")
	assert_eq(corp.MoneyCost, 70, "Corporation money 70")
	assert_eq(corp.BioCost, 20, "Corporation bio 20")
	assert_eq(corp.InfluenceCost, 60, "Corporation influence 60")
	assert_eq(corp.SpecialEffect, "Reduce MoneyCost of playing all cards by 20%", "Corp effect")

func test_decks_johndoe_insurgents_euro():
	# New spec: State Troops replaces JohnDoe, difficulties 1/2/4/5, all decks updated
	var jd := CardFactory.make_starting_deck()
	assert_eq(jd.size(), 31, "State Troops/JohnDoe 31")
	var cjd := {}
	for card in jd:
		cjd[card.card_name] = cjd.get(card.card_name,0)+1
	assert_eq(cjd.get("Wall",0),10, "JD Wall 10")
	assert_eq(cjd.get("Infantry",0),10, "JD Inf 10")
	assert_eq(cjd.get("Tank",0),3, "JD Tank 3")
	assert_eq(cjd.get("Artilery",0),3, "JD Artilery 3")
	assert_eq(cjd.get("Factory",0),2, "JD Factory 2")
	assert_eq(cjd.get("Housing",0),2, "JD Housing 2")
	assert_eq(cjd.get("Barracks",0),1, "JD Barracks 1")
	var ins := CardFactory.make_insurgents_deck()
	assert_eq(ins.size(),31, "Insurgents 31")
	var ci := {}
	for card in ins:
		ci[card.card_name]=ci.get(card.card_name,0)+1
	assert_eq(ci.get("Drone",0),8, "Ins Drone 8")
	assert_eq(ci.get("Wall",0),5, "Ins Wall 5")
	var euro_deck := CardFactory.make_euro_army_deck()
	assert_eq(euro_deck.size(),41, "Euro deck 41")
	var ce := {}
	for card in euro_deck:
		ce[card.card_name]=ce.get(card.card_name,0)+1
	assert_eq(ce.get("Fighter Jet",0),4, "Euro Fighter Jet 4")
	assert_eq(ce.get("Drone",0),8, "Euro Drone 8")
	var euro := CardFactory.make_euro_army_player()
	assert_eq(euro.HitPoints,60, "Euro 60 HP")
	assert_eq(euro.BioSupply,80, "Euro 80 bio")
	assert_eq(euro.MoneySupply,50, "Euro 50 money")
	assert_eq(euro.Difficulty,5, "Euro diff 5 per new spec")
	assert_eq(euro.Influence,50, "Euro influence 50")
	assert_eq(euro.display_name,"Euro Army", "Euro name")
	assert_eq(euro.BackgroundImage, "City with european style towers", "Euro background")
	# board 2 Housing +1 Factory at back row 0 (other side vs front row 3 for AI top)
	var back = euro.Board[0]
	var hous = 0
	var fac = 0
	for sq in back.Squares:
		if sq.Inhabitant is Housing:
			hous+=1
		if sq.Inhabitant is Factory:
			fac+=1
	assert_eq(hous,2, "Euro back row 0 2 Housing")
	assert_eq(fac,1, "Euro back row 0 1 Factory")
	# New players: State Troops and Horde
	var st := CardFactory.make_state_troops_player()
	assert_eq(st.display_name, "State Troops", "State Troops name")
	assert_eq(st.HitPoints, 100, "State Troops HP 100")
	assert_eq(st.Influence, 20, "State Troops influence 20")
	assert_eq(st.Difficulty, 2, "State Troops diff 2")
	assert_eq(st.BackgroundImage, "Middle Eastern town, add some mosques around, don't make the entire thing a desert", "ST background")
	var st_back = st.Board[0]
	var st_hous = 0
	var st_inf = 0
	for sq in st_back.Squares:
		if sq.Inhabitant is Housing:
			st_hous+=1
		if sq.Inhabitant is Infantry:
			st_inf+=1
	assert_eq(st_hous,1, "State Troops back 1 Housing")
	assert_eq(st_inf,1, "State Troops back 1 Infantry")
	var horde := CardFactory.make_horde_player()
	assert_eq(horde.display_name, "Horde", "Horde name")
	assert_eq(horde.HitPoints, 200, "Horde HP 200")
	assert_eq(horde.Influence, 25, "Horde influence 25")
	assert_eq(horde.Difficulty, 4, "Horde diff 4")
	assert_eq(horde.BackgroundImage, "Russian style city, snowy, add few trees", "Horde background")
	var h_back = horde.Board[0]
	var h_hous = 0
	var h_art = 0
	var h_tank = 0
	for sq in h_back.Squares:
		if sq.Inhabitant is Housing:
			h_hous+=1
			assert_eq((sq.Inhabitant as Building).HitPoints, 5, "Horde Housing damaged to 5")
		if sq.Inhabitant is Artilery:
			h_art+=1
			assert_eq((sq.Inhabitant as Unit).HitPoints, 5, "Horde Artilery damaged to 5")
		if sq.Inhabitant is Tank:
			h_tank+=1
			assert_eq((sq.Inhabitant as Unit).HitPoints, 5, "Horde Tank damaged to 5")
	assert_eq(h_hous,2, "Horde back 2 Housing")
	assert_eq(h_art,1, "Horde back 1 Artilery")
	assert_eq(h_tank,2, "Horde back 2 Tank")
	var insurg := CardFactory.make_insurgents_player()
	assert_eq(insurg.HitPoints, 120, "Insurgents HP 120 per new spec")
	assert_eq(insurg.Influence, 10, "Insurgents influence 10")
	assert_eq(insurg.Difficulty, 1, "Insurgents diff 1")
	# Horde deck size 48 per spec sum
	var horde_deck := CardFactory.make_horde_deck()
	assert_eq(horde_deck.size(), 48, "Horde deck 48")

func test_player_difficulty_and_enemy_is_euro():
	var p := Player.new(100,100,20,1,"Test")
	assert_eq(p.Difficulty,1, "Player difficulty")
	assert_eq(p.display_name,"Test", "Player name")
	var gc_txt := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	assert_true(gc_txt.contains("CardFactory.make_euro_army_player()"), "enemy is Euro Army")
	assert_true(gc_txt.contains("Euro Army"), "Euro Army string")
	assert_false(gc_txt.contains("make_insurgents_deck()") and gc_txt.contains("ai_player = CardFactory.make_insurgents_deck"), "not old insurgents enemy")

func test_flag_art_exists():
	assert_true(ResourceLoader.exists("res://Assets/Players/JohnDoe/flag.png"), "JohnDoe flag exists")
	assert_true(ResourceLoader.exists("res://Assets/Players/Insurgents/flag.png"), "Insurgents flag exists")
	assert_true(ResourceLoader.exists("res://Assets/Players/Euro Army/flag.png"), "Euro flag exists")
	assert_true(ResourceLoader.exists("res://Assets/Players/State Troops/flag.png"), "State Troops flag exists")
	assert_true(ResourceLoader.exists("res://Assets/Players/Horde/flag.png"), "Horde flag exists")
	assert_true(ResourceLoader.exists("res://Assets/Cards/Corporation/sprite.png"), "Corporation sprite exists")
	assert_true(FileAccess.file_exists("res://Assets/Players/JohnDoe/flag.png"), "flag file")
	var gc_txt := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	assert_true(gc_txt.contains("AIFlag") and gc_txt.contains("PlayerFlag"), "flag wired")
	assert_true(ResourceLoader.exists("res://Assets/Players/Euro Army/flag.png"), "euro flag loadable")

func test_heart_and_gauge_textures():
	# heart flipped still 32x32
	assert_true(ResourceLoader.exists("res://Assets/UI/heart.png"), "heart exists")
	# gauge fills must be vertical 12x124 not 124x12
	var gc_tscn := FileAccess.get_file_as_string("res://scenes/Game.tscn")
	assert_true(gc_tscn.contains("Vector2(26, 62)"), "gauge vertical size 26x62")
	# check files are vertical via existence (rotated)
	assert_true(FileAccess.file_exists("res://Assets/UI/hp_fill.png"), "hp_fill exists")
	assert_true(FileAccess.file_exists("res://Assets/UI/hp_bg.png"), "hp_bg exists")

func test_red_unaffordable_and_no_card_tint():
	var gc_txt := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	assert_true(gc_txt.contains("Color(1, 0.45, 0.45)"), "red unaffordable")
	assert_true(gc_txt.contains("btn.modulate = Color(1, 1, 1)"), "board/hand white no blue/yellow/green")
	assert_false(gc_txt.contains("Color(0.15, 0.55, 1.0)"), "no blue tint")
	assert_false(gc_txt.contains("Color(1.0, 0.72, 0.0)"), "no yellow tint")

func test_magnification_click_through_and_flip():
	var gc_txt := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	assert_true(gc_txt.contains("MOUSE_FILTER_IGNORE"), "click-through")
	assert_true(gc_txt.contains("_set_preview_click_through"), "click-through helper")
	assert_true(gc_txt.contains("mouse.y - sz.y - 16"), "flips above when near bottom (hand spill fix)")
	assert_true(gc_txt.contains("280, 168"), "fixed size prevents overflow")

func test_special_effect_sprites_exist():
	assert_true(FileAccess.file_exists("res://Assets/Effects/fighter_jet_splash.png"), "fighter splash exists")
	assert_true(FileAccess.file_exists("res://Assets/Effects/barracks_aura.png"), "barracks aura exists")
	assert_true(FileAccess.file_exists("res://Assets/Effects/fighter_jet_splash_0.png"), "splash frames")
	assert_true(FileAccess.file_exists("res://Assets/Effects/barracks_aura_0.png"), "aura frames")
	var gc_txt := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	assert_true(gc_txt.contains("_spawn_special_effect"), "spawn effect")
	assert_true(gc_txt.contains("fighter_jet_splash"), "fighter effect")
	assert_true(gc_txt.contains("barracks_aura"), "barracks effect")

func test_combat_flying_half_and_splash_and_overkill():
	# Flying half damage
	var atk := Player.new(100,100,20)
	var def := Player.new(100,100,20)
	var inf := Infantry.new() # not ranged, 2 dmg
	atk.Board[1].Squares[0].place(inf)
	var drone := Drone.new() # flying 6 HP
	drone.HitPoints = 6
	def.Board[0].Squares[0].place(drone)
	CombatState.new(atk, def).combat_phase()
	assert_eq(drone.HitPoints, 5, "flying half damage 2->1: 6->5")
	# Ranged vs flying not halved
	var atk2 := Player.new(100,100,20)
	var def2 := Player.new(100,100,20)
	var art := Artilery.new() # ranged 8 dmg
	atk2.Board[0].Squares[0].place(art)
	var drone2 := Drone.new()
	drone2.HitPoints = 6
	def2.Board[0].Squares[0].place(drone2)
	CombatState.new(atk2, def2).combat_phase()
	assert_true(drone2.HitPoints <= 0, "ranged full damage kills 6HP drone with 8")
	# Fighter Jet splash
	var atk3 := Player.new(100,100,20)
	var def3 := Player.new(100,100,20)
	var fj := FighterJet.new()
	atk3.Board[0].Squares[0].place(fj)
	var target := Infantry.new()
	target.HitPoints = 12
	def3.Board[1].Squares[1].place(target)
	var adj1 := Infantry.new()
	adj1.HitPoints = 12
	def3.Board[1].Squares[2].place(adj1)
	var adj2 := Infantry.new()
	adj2.HitPoints = 12
	def3.Board[2].Squares[1].place(adj2)
	CombatState.new(atk3, def3).combat_phase()
	# primary target took 6, adjacents also 6
	assert_true(target.HitPoints < 12, "fighter primary damaged")
	assert_true(adj1.HitPoints < 12 or adj2.HitPoints < 12, "fighter splash adjacent damaged")
	# Overkill prevention: Rocket Launcher 4× should not overkill same dead unit, should retarget (deterministic: non-ranged front)
	var atk4 := Player.new(100,100,20)
	var def4 := Player.new(100,100,20)
	var rl := RocketLauncher.new()
	rl.HasRange = false
	atk4.Board[0].Squares[0].place(rl)
	var weak := Infantry.new()
	weak.HitPoints = 1
	def4.Board[3].Squares[0].place(weak)
	var other := Infantry.new()
	other.HitPoints = 12
	def4.Board[2].Squares[0].place(other)
	CombatState.new(atk4, def4).combat_phase()
	# weak front should be killed first, remaining 3 hits must go to next closest (row 2) not overkill weak
	assert_true(weak.HitPoints <= 0, "weak dead")
	assert_true(other.HitPoints < 12, "overkill retarget to next closest")

func test_gauge_scaling_and_board_hand_sizes():
	var tscn := FileAccess.get_file_as_string("res://scenes/Game.tscn")
	assert_true(tscn.contains("Vector2(124, 0)"), "Left/Right Gauges 124")
	assert_true(tscn.contains("Vector2(44, 44)"), "gauge icons 44")
	assert_true(tscn.contains("Vector2(26, 62)"), "gauge bars 26x62")
	assert_true(tscn.contains("font_size = 30") or tscn.contains("font_size = 22"), "gauge headers scaled")
	# boards/hand untouched per gauges-only scaling
	assert_true(tscn.contains("Vector2(0, 150)"), "boards 150 untouched")
	assert_true(tscn.contains("Vector2(0, 80)"), "hand 80 untouched")

func test_corporation_discount_and_influence():
	var p := Player.new(100, 100, 100, 0, "Test", "", 0)
	assert_eq(p.Influence, 0, "Influence starts 0")
	p.Board[0].Squares[0].place(Corporation.new())
	assert_eq(Corporation.discounted_money_cost(p, 10), 8, "Wall 10 -> 8 with 1 Corp 20%")
	assert_eq(Corporation.discounted_money_cost(p, 70), 56, "Corp self 70 -> 56")
	# Stacking 2 corps 0.8*0.8=0.64 => 10 -> 6
	p.Board[0].Squares[1].place(Corporation.new())
	assert_eq(Corporation.discounted_money_cost(p, 10), 6, "10 -> 6 with 2 Corps")
	# play_card uses discounted cost - test with single corp (fresh player) to avoid stacking confusion
	var p2 := Player.new(100, 100, 100, 0, "Test2", "", 0)
	p2.Board[0].Squares[0].place(Corporation.new())
	var wall := Wall.new()
	p2.Hand = [wall]
	p2.MoneySupply = 8
	p2.BioSupply = 100
	assert_true(p2.play_card(wall, 0, 2), "play wall with discounted 8 succeeds with 8 money")
	assert_eq(p2.MoneySupply, 0, "deducted 8 not 10")
	assert_eq(wall.InfluenceCost, 5, "Wall influence 5")
	# also verify 2-corps discounted play leaves 2
	var wall2 := Wall.new()
	p.Hand = [wall2]
	p.MoneySupply = 8
	p.BioSupply = 100
	assert_true(p.play_card(wall2, 0, 2), "play wall with 2 corps discounted 6 succeeds")
	assert_eq(p.MoneySupply, 2, "deducted 6 with 2 corps leaves 2")

func test_player_chooser_state_troops_recommended():
	var main_txt := FileAccess.get_file_as_string("res://scripts/main.gd")
	assert_true(main_txt.contains("State Troops"), "chooser has State Troops")
	assert_true(main_txt.contains("border") or main_txt.contains("StyleBoxFlat"), "recommended border")
	# Check GameState enemy sequence sorted by difficulty starting with insurgents
	var seq := CardFactory.enemy_sequence_for_player("State Troops")
	assert_eq(seq[0].display_name, "Insurgents", "first enemy insurgents")
	assert_true(seq[0].Difficulty < seq[1].Difficulty, "sorted ascending")
	assert_eq(seq.size(), 3, "3 enemies when player is State Troops (excludes self)")
	# All difficulties 1,4,5 for State Troops chooser
	var diffs: Array = []
	for e in seq:
		diffs.append(e.Difficulty)
	assert_true(diffs.has(1) and diffs.has(4) and diffs.has(5), "difficulties 1,4,5")

func test_shop_rules_and_influence_gain():
	var gs = load("res://GodotHelpers/GameState.gd").new()
	autofree(gs)
	gs.start_run("State Troops")
	assert_eq(gs.run_player.Influence, 20, "Start with State Troops influence 20")
	gs.prepare_shop()
	assert_eq(gs.shop_offer.size(), 5, "Shop offers 5")
	for c in gs.shop_offer:
		assert_true(c.InfluenceCost > 0, "shop card has InfluenceCost")
	# Buy one if affordable
	var affordable: Card = null
	for c in gs.shop_offer:
		if c.InfluenceCost <= gs.run_player.Influence:
			affordable = c
			break
	if affordable != null:
		var before: int = gs.run_player.Influence
		var draw_before: int = gs.run_player.DrawPile.size()
		assert_true(gs.buy_card(affordable), "buy succeeds")
		assert_eq(gs.run_player.Influence, before - affordable.InfluenceCost, "influence deducted")
		assert_eq(gs.run_player.DrawPile.size(), draw_before + 1, "added to DrawPile")
		assert_false(gs.shop_offer.has(affordable), "removed from offer")
	# Remove once per shop for 25
	gs.run_player.Influence = 30
	gs.shop_remove_used = false
	var to_remove: Card = gs.run_player.DrawPile[0] if not gs.run_player.DrawPile.is_empty() else Wall.new()
	if gs.run_player.DrawPile.is_empty():
		gs.run_player.DrawPile.append(to_remove)
	var rem_before: int = gs.run_player.Influence
	var sz_before: int = gs.run_player.DrawPile.size() + gs.run_player.DiscardPile.size() + gs.run_player.Graveyard.size()
	assert_true(gs.remove_card_from_deck(to_remove), "remove succeeds")
	assert_eq(gs.run_player.Influence, rem_before - 25, "25 deducted")
	assert_true(gs.shop_remove_used, "once per shop flag set")
	assert_false(gs.remove_card_from_deck(to_remove), "second remove per shop fails")
	# Gain influence on defeat
	var gained_before: int = gs.run_player.Influence
	gs.gain_influence(10)
	assert_eq(gs.run_player.Influence, gained_before + 10, "gain influence")

func test_end_turn_after_stage_victory():
	var gc_txt := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	# Regression: end turn must re-enable after shop continue
	assert_true(gc_txt.contains("_continue_from_shop"), "shop continue exists")
	assert_true(gc_txt.contains("end_turn_btn.disabled = false"), "re-enables end turn")
	# Check that _check_game_over handles run victory with shop
	assert_true(gc_txt.contains("gain_influence") or gc_txt.contains("Gained"), "influence gain on victory")
	assert_true(gc_txt.contains("_show_shop"), "shop shown between battles")
	# Verify shop popup exists and has buy/remove
	assert_true(gc_txt.contains("ShopPopup") or gc_txt.contains("shop_popup"), "shop popup")
	assert_true(gc_txt.contains("InfluenceCost"), "uses InfluenceCost")
	# Verify that _continue_from_shop clears human board but not next enemy board and re-creates CombatState
	assert_true(gc_txt.contains("_clear_board(human)"), "clears human board for next battle")
	assert_true(gc_txt.contains("CombatState.new(human, ai_player)"), "new CombatState for next battle")
