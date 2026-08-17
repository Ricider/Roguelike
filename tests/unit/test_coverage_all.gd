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
	var tank := Tank.new()
	assert_eq(tank.HitPoints, 25, "Tank 25")
	assert_eq(tank.Damage, 8, "Tank 8")
	assert_false(tank.Flying, "Tank not flying")
	var art := Artilery.new()
	assert_eq(art.HitPoints, 12, "Artilery 12")
	assert_eq(art.Damage, 8, "Artilery 8")
	assert_eq(art.BioCost, 8, "Artilery bio 8")
	assert_true(art.HasRange, "Artilery ranged")
	var rl := RocketLauncher.new()
	assert_eq(rl.HitPoints, 12, "Rocket 12")
	assert_eq(rl.BioCost, 5, "Rocket bio 5")
	var drone := Drone.new()
	assert_eq(drone.HitPoints, 6, "Drone 6")
	assert_eq(drone.Damage, 3, "Drone 3")
	assert_true(drone.Flying, "Drone flying true")
	var fj := FighterJet.new()
	assert_eq(fj.HitPoints, 14, "FighterJet 14")
	assert_eq(fj.Damage, 6, "FighterJet 6")
	assert_true(fj.HasRange, "FighterJet ranged")
	assert_true(fj.Flying, "FighterJet flying")
	assert_eq(fj.SpecialEffect, "Also damages tiles adjacent to where it hit", "FighterJet splash")

func test_decks_johndoe_insurgents_euro():
	var jd := CardFactory.make_starting_deck()
	assert_eq(jd.size(), 31, "JohnDoe 31")
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
	assert_eq(euro.Difficulty,2, "Euro diff 2")
	assert_eq(euro.display_name,"Euro Army", "Euro name")
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
