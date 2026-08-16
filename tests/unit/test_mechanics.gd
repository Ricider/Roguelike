extends GutTest
# GUT suite for core mechanics — now lives in Classes/.
# Run from Editor: GutScene → Run, or headless on Linux CI.
# Covers the same cases as the previous headless SceneTree script.

func test_cardfactory_deck_composition():
	var deck: Array = CardFactory.make_starting_deck()
	assert_eq(deck.size(), 16, "deck size 16 per spec [5I,2T,2A,2F,4H,1B]")
	var c := {}
	for card in deck:
		c[card.card_name] = c.get(card.card_name, 0) + 1
	assert_eq(c.get("Infantry", 0), 5, "Infantry x5")
	assert_eq(c.get("Tank", 0), 2, "Tank x2")
	assert_eq(c.get("Artilery", 0), 2, "Artilery x2")
	assert_eq(c.get("Factory", 0), 2, "Factory x2")
	assert_eq(c.get("Barracks", 0), 1, "Barracks x1")
	assert_eq(c.get("Housing", 0), 4, "Housing x4")

func test_player_economy_basic():
	var p := Player.new(100, 100, 20)
	p.DrawPile = CardFactory.make_starting_deck()
	p.DiscardPile.clear()
	p.Hand.clear()
	p.economy_phase()
	assert_eq(p.BioSupply, 120, "Bio 15%+5 100->120 per updated spec (100*1.15+5)")
	assert_eq(p.MoneySupply, 30, "Money +10 +0 income 20->30 per updated spec")
	assert_eq(p.Hand.size(), 5, "draws 5")

func test_player_economy_with_factory_income():
	var p := Player.new(100, 100, 20)
	p.Board[0].Squares[0].place(Factory.new()) # +5
	p.DrawPile = CardFactory.make_starting_deck()
	p.Hand.clear()
	p.economy_phase()
	assert_eq(p.MoneySupply, 35, "Money +10+5 Factory 20->35 per updated spec")

func test_player_economy_housing_bonus():
	var p1 := Player.new(100, 100, 20)
	p1.Board[0].Squares[0].place(Housing.new())
	p1.DrawPile = CardFactory.make_starting_deck()
	p1.Hand.clear()
	p1.economy_phase()
	assert_eq(p1.BioSupply, 128, "Bio 15%+5+8% with 1 Housing 100->128 per updated spec (100*1.23+5)")

	var p2 := Player.new(100, 100, 20)
	p2.Board[0].Squares[0].place(Housing.new())
	p2.Board[0].Squares[1].place(Housing.new())
	p2.DrawPile = CardFactory.make_starting_deck()
	p2.Hand.clear()
	p2.economy_phase()
	assert_eq(p2.BioSupply, 136, "Bio 15%+5+16% with 2 Housing 100->136 per updated spec (100*1.31+5)")

func test_player_draw_shuffle_and_discard():
	var p := Player.new(100, 100, 20)
	p.DrawPile.clear()
	p.DiscardPile = [Infantry.new(), Tank.new(), Factory.new()]
	p.Hand.clear()
	p.draw_cards()
	assert_eq(p.Hand.size(), 3, "draw shuffles Discard into Draw (3)")
	assert_true(p.DiscardPile.is_empty(), "Discard empty after shuffle")
	p.Hand = [Infantry.new(), Infantry.new()]
	p.DiscardPile.clear()
	p.discard_hand()
	assert_eq(p.Hand.size(), 0, "discard clears Hand")
	assert_eq(p.DiscardPile.size(), 2, "discard moves 2 to Discard")

func test_player_play_card_success_and_failures():
	var p := Player.new(100, 100, 20)
	var inf := Infantry.new()
	p.Hand = [inf]
	assert_true(p.play_card(inf, 0, 0), "play success")
	assert_eq(p.MoneySupply, 15, "deducts 5 Money")
	assert_eq(p.BioSupply, 85, "deducts 15 Bio")
	assert_eq(p.Board[0].Squares[0].Inhabitant, inf, "places card")
	assert_eq(p.Hand.size(), 0, "removes from Hand")

	var p2 := Player.new(100, 2, 2)
	var tank := Tank.new()
	p2.Hand = [tank]
	assert_false(p2.play_card(tank, 0, 1), "fails insufficient Money")
	assert_eq(p2.Hand.size(), 1, "Hand unchanged on fail")

	var p3 := Player.new(100, 100, 20)
	var a := Infantry.new()
	var b := Infantry.new()
	p3.Board[0].Squares[0].place(a)
	p3.Hand = [b]
	assert_false(p3.play_card(b, 0, 0), "fails occupied")
	assert_false(p3.play_card(b, 3, 0), "fails row OOB")
	assert_false(p3.play_card(b, 0, 7), "fails col OOB")

func test_barracks_housing_helpers():
	var p := Player.new(100, 100, 20)
	p.Board[1].Squares[1].place(Barracks.new())
	var sq: Square = p.Board[1].Squares[2]
	sq.place(Infantry.new())
	assert_eq(Barracks.bonus_if_adjacent(p, sq), 2, "+2 orthogonal")

	var p2 := Player.new(100, 100, 20)
	p2.Board[0].Squares[0].place(Barracks.new())
	var diag: Square = p2.Board[1].Squares[1]
	diag.place(Infantry.new())
	assert_eq(Barracks.bonus_if_adjacent(p2, diag), 2, "+2 diagonal")

	var p3 := Player.new(100, 100, 20)
	var iso: Square = p3.Board[0].Squares[0]
	iso.place(Infantry.new())
	assert_eq(Barracks.bonus_if_adjacent(p3, iso), 0, "0 isolated")

	var p4 := Player.new(100, 100, 20)
	assert_almost_eq(Housing.extra_bio_rate(p4), 0.0, 0.0001, "0% none")
	p4.Board[0].Squares[0].place(Housing.new())
	assert_almost_eq(Housing.extra_bio_rate(p4), 0.08, 0.0001, "+8% with 1 per updated spec")
	assert_almost_eq(Housing.bio_rate(p4), 1.23, 0.0001, "1.23 (1.15+0.08) with 1")

func test_combat_damage_and_barracks_bonus():
	var atk := Player.new(100, 100, 20)
	var def := Player.new(100, 100, 20)
	var a := Infantry.new(); a.HitPoints = 10
	atk.Board[2].Squares[0].place(a)
	var d := Infantry.new(); d.HitPoints = 10
	def.Board[2].Squares[0].place(d)
	CombatState.new(atk, def).combat_phase()
	assert_eq(d.HitPoints, 8, "2 dmg 10->8")

	var atk2 := Player.new(100, 100, 20)
	var def2 := Player.new(100, 100, 20)
	atk2.Board[1].Squares[1].place(Barracks.new())
	var a2 := Infantry.new(); a2.HitPoints = 10
	atk2.Board[1].Squares[2].place(a2)
	var d2 := Infantry.new(); d2.HitPoints = 10
	def2.Board[2].Squares[0].place(d2)
	CombatState.new(atk2, def2).combat_phase()
	assert_eq(d2.HitPoints, 6, "Barracks +2 => 4 dmg 10->6")

func test_combat_pick_target():
	var def := Player.new(100, 100, 20)
	def.Board[0].Squares[0].place(Infantry.new())
	def.Board[2].Squares[0].place(Infantry.new())
	var cs := CombatState.new(Player.new(), def)
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	for i in range(5):
		var t = cs._pick_target(def, false, rng)
		assert_eq(t["square"], def.Board[2].Squares[0], "non-ranged picks front row (AI defender)")
	assert_not_null(cs._pick_target(def, true, rng), "ranged picks any")

func test_combat_pick_target_human_vs_ai_front():
	# Human defender front is row 0, AI defender front is row 2 — verifies the vertical direction fix
	var human := Player.new(100, 100, 20) # Players[0] = human (bottom)
	var ai := Player.new(100, 100, 20)    # Players[1] = AI (top)
	var cs := CombatState.new(human, ai)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Human defender: units on back (2) and front (0) — should pick front 0
	human.Board[0].Squares[3].place(Infantry.new())
	human.Board[2].Squares[3].place(Tank.new())
	for i in range(5):
		var t = cs._pick_target(human, false, rng)
		assert_eq(t["square"], human.Board[0].Squares[3], "human defender non-ranged picks row 0 front")
	# AI defender: units on back (0) and front (2) — should pick front 2
	ai.Board[0].Squares[3].place(Tank.new())
	ai.Board[2].Squares[3].place(Infantry.new())
	for i in range(5):
		var t = cs._pick_target(ai, false, rng)
		assert_eq(t["square"], ai.Board[2].Squares[3], "AI defender non-ranged picks row 2 front")

func test_combat_pick_target_middle_row_fallback():
	var human := Player.new(100, 100, 20)
	var ai := Player.new(100, 100, 20)
	var cs := CombatState.new(human, ai)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Only middle row occupied — both defenders should pick row 1
	human.Board[1].Squares[1].place(Infantry.new())
	ai.Board[1].Squares[1].place(Infantry.new())
	assert_eq(cs._pick_target(human, false, rng)["square"], human.Board[1].Squares[1], "human picks middle when front empty")
	assert_eq(cs._pick_target(ai, false, rng)["square"], ai.Board[1].Squares[1], "AI picks middle when front empty")

func test_combat_pick_target_empty_and_ranged_any():
	var human := Player.new(100, 100, 20)
	var ai := Player.new(100, 100, 20)
	var cs := CombatState.new(human, ai)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	assert_null(cs._pick_target(human, false, rng), "empty board returns null (non-ranged)")
	assert_null(cs._pick_target(human, true, rng), "empty board returns null (ranged)")
	# Ranged picks any row — verify it can pick back row even when front occupied
	human.Board[0].Squares[0].place(Infantry.new())
	human.Board[2].Squares[6].place(Tank.new())
	var seen_back := false
	var seen_front := false
	for i in range(20):
		var t = cs._pick_target(human, true, rng)
		if t["square"] == human.Board[0].Squares[0]:
			seen_front = true
		if t["square"] == human.Board[2].Squares[6]:
			seen_back = true
	assert_true(seen_front and seen_back, "ranged can hit any row including back")

func test_combat_pick_target_fallback_not_in_players():
	var outsider := Player.new(100, 100, 20)
	outsider.Board[0].Squares[0].place(Tank.new())
	outsider.Board[2].Squares[0].place(Infantry.new())
	var cs := CombatState.new(Player.new(), Player.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	# outsider not in Players — fallback order [2,1,0] picks front 2
	assert_eq(cs._pick_target(outsider, false, rng)["square"], outsider.Board[2].Squares[0], "fallback picks row 2")

func test_combat_pick_target_multiple_candidates_same_row():
	var human := Player.new(100, 100, 20)
	var ai := Player.new(100, 100, 20)
	var cs := CombatState.new(human, ai)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	human.Board[0].Squares[0].place(Infantry.new())
	human.Board[0].Squares[6].place(Tank.new())
	var seen_left := false
	var seen_right := false
	for i in range(30):
		var t = cs._pick_target(human, false, rng)
		assert_true(t["square"] == human.Board[0].Squares[0] or t["square"] == human.Board[0].Squares[6], "still front row")
		if t["square"] == human.Board[0].Squares[0]:
			seen_left = true
		if t["square"] == human.Board[0].Squares[6]:
			seen_right = true
	assert_true(seen_left and seen_right, "random among same front row candidates")

func test_combat_death_and_direct_hit():
	var atk := Player.new(100, 100, 20)
	var def := Player.new(50, 100, 20)
	var killer := Tank.new(); killer.HitPoints = 20
	atk.Board[2].Squares[0].place(killer)
	var victim := Factory.new(); victim.HitPoints = 1
	def.Board[2].Squares[0].place(victim)
	CombatState.new(atk, def).combat_phase()
	assert_true(def.Board[2].Squares[0].is_empty(), "death clears square")
	assert_eq(def.Graveyard.size(), 1, "death to Graveyard")
	assert_eq(def.HitPoints, 30, "death deducts BioCost 20 50->30")

	var atk2 := Player.new(100, 100, 20)
	var def2 := Player.new(100, 100, 20)
	atk2.Board[2].Squares[0].place(Infantry.new())
	CombatState.new(atk2, def2).combat_phase()
	assert_eq(def2.HitPoints, 98, "no defender => direct 2 dmg 100->98")

func test_ai_take_build_turn():
	var ai := AIPlayer.new(100, 100, 20)
	ai.Hand = [Infantry.new(), Factory.new()]
	ai.MoneySupply = 100; ai.BioSupply = 100
	var before_hand: int = ai.Hand.size()
	var before_empty: int = ai.get_empty_squares().size()
	ai.take_build_turn()
	assert_lt(ai.Hand.size(), before_hand, "AI plays at least one")
	assert_lt(ai.get_empty_squares().size(), before_empty, "AI occupies square")

	var full := AIPlayer.new(100, 100, 20)
	for r in range(3):
		for c in range(7):
			full.Board[r].Squares[c].place(Infantry.new())
	full.Hand = [Infantry.new()]
	full.MoneySupply = 100; full.BioSupply = 100
	full.take_build_turn()
	assert_eq(full.Hand.size(), 1, "AI does not play when full")

func test_card_view_helpers():
	var card := Infantry.new()
	var sf := card.get_sprite_frames()
	# 20 frames if assets present, else fallback at least 1 — both valid after migration
	assert_true(sf.get_frame_count("idle") >= 1, "sprite frames >=1")
	var ctl := Card.create_sprite_for("Infantry", Vector2(48, 48))
	assert_not_null(ctl, "create_sprite_for returns Control")
	assert_true(ctl is Control, "sprite wrapper is Control")
	autofree(ctl)
