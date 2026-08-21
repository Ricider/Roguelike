extends GutTest
# Tests for Manhattan targeting (4x detail upgrade) and hover arrow logic

func _make_player(name: String) -> Player:
	var p := Player.new(100, 200, 200, 0, name, "", 100)
	for row in p.Board:
		for sq in row.Squares:
			sq.clear()
	return p

func _place(p: Player, r: int, c: int, card: Card):
	p.Board[r].Squares[c].place(card)

func test_manhattan_distance_basic():
	var human := _make_player("Human")
	var ai := _make_player("AI")
	var cs := CombatState.new(human, ai)
	# Human attacker at front (0,0), AI defender at front (3,0) => row_dist 1, col 0 => 1
	var a_sq: Square = human.Board[0].Squares[0]
	var d_sq: Square = ai.Board[3].Squares[0]
	_place(human, 0, 0, Infantry.new())
	_place(ai, 3, 0, Infantry.new())
	var d: int = cs._manhattan_distance(human, a_sq, ai, d_sq)
	assert_eq(d, 1, "front-to-front Manhattan 1")
	# Same attacker to far col 9 front => col 9 => 10
	var d_sq2: Square = ai.Board[3].Squares[9]
	_place(ai, 3, 9, Infantry.new())
	var d2: int = cs._manhattan_distance(human, a_sq, ai, d_sq2)
	assert_eq(d2, 10, "front-to-front far col 9 => 10")
	# Back row (3) human attacker to front AI => row_dist 4, col 0 => 4
	var a_back: Square = human.Board[3].Squares[0]
	_place(human, 3, 0, Tank.new())
	var d3: int = cs._manhattan_distance(human, a_back, ai, d_sq)
	assert_eq(d3, 4, "back-to-front row_dist 4")

func test_pick_target_manhattan_closest_not_row():
	# Attacker human at col 0 front, defender AI has front far col vs back close col
	# Manhattan should pick back close (distance 4) over front far (10), row-only would pick front far
	var human := _make_player("Human")
	var ai := _make_player("AI")
	var cs := CombatState.new(human, ai)
	var atk := Infantry.new() # HasRange false
	_place(human, 0, 0, atk)
	var front_far := Wall.new()
	var back_close := Wall.new()
	_place(ai, 3, 9, front_far)
	_place(ai, 0, 0, back_close) # AI back row 0 is farthest, but col 0 => distance = 1+3+1+0? Wait AI back row 0 distance: attacker front 0 + defender back (3-0=3) +1 =4, plus col0 =>4
	# front_far distance = 1 + 0 +1? Actually attacker 0, defender front 3 => 0+0+1=1 +9=10
	# back_close distance = 0+3+1=4 +0=4 => closer
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	var picked = cs._pick_target_manhattan(ai, human, human.Board[0].Squares[0], false, rng)
	assert_not_null(picked, "picked something")
	# Should be back_close (Manhattan 4) not front_far (10)
	assert_eq(picked["card"], back_close, "Manhattan picks back same-col over front far-col")

func test_pick_target_manhattan_tie_deterministic():
	var human := _make_player("Human")
	var ai := _make_player("AI")
	var cs := CombatState.new(human, ai)
	_place(human, 0, 5, Infantry.new())
	# Two defender targets symmetric distance tie Manhattan 3 => deterministic first to match arrow single
	_place(ai, 3, 3, Wall.new())
	_place(ai, 3, 7, Wall.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var p1 = cs._pick_target_manhattan(ai, human, human.Board[0].Squares[5], false, rng)
	var p2 = cs._pick_target_manhattan(ai, human, human.Board[0].Squares[5], false, rng)
	assert_eq(p1["square"], ai.Board[3].Squares[3], "deterministic picks first minimal")
	assert_eq(p2["square"], ai.Board[3].Squares[3], "deterministic consistent")

func test_predict_target_matches_manhattan():
	var human := _make_player("Human")
	var ai := _make_player("AI")
	var cs := CombatState.new(human, ai)
	_place(human, 1, 2, Infantry.new())
	_place(ai, 2, 2, Wall.new())
	_place(ai, 3, 9, Wall.new())
	var pred: Dictionary = cs.predict_target(human, human.Board[1].Squares[2], ai)
	assert_not_null(pred["square"], "predict returns square")
	# Attacker (1,2) human: dist to front row 3 col9 => attacker dist 1, defender dist 0, row1 + col7=8
	# to (2,2) AI: attacker 1 + defender 1 (3-2=1) +1=3 + col0=3 => 3, so (2,2) closer
	assert_eq(pred["square"], ai.Board[2].Squares[2], "predict picks Manhattan closest")

func test_ranged_still_random_any():
	var human := _make_player("Human")
	var ai := _make_player("AI")
	var cs := CombatState.new(human, ai)
	_place(human, 0, 0, Artilery.new()) # HasRange true
	_place(ai, 0, 0, Wall.new())
	_place(ai, 3, 9, Wall.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var seen = {}
	for i in range(20):
		var t = cs._pick_target_manhattan(ai, human, human.Board[0].Squares[0], true, rng)
		seen[t["square"]] = true
	assert_true(seen.size() > 1, "ranged picks random among all, not just Manhattan closest")

func test_legacy_pick_target_still_row_based():
	# Old 3-arg calls must remain row-based for existing tests
	var human := _make_player("Human")
	var ai := _make_player("AI")
	var cs := CombatState.new(human, ai)
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	_place(ai, 0, 0, Infantry.new())
	_place(ai, 3, 0, Infantry.new())
	for i in range(5):
		var t = cs._pick_target(ai, false, rng)
		assert_eq(t["square"], ai.Board[3].Squares[0], "legacy non-ranged picks front row 3")

func test_hp_tooltip_wording():
	var tscn := FileAccess.get_file_as_string("res://GodotHelpers/GameController.gd")
	assert_true(tscn.contains("when a card dies its owner loses HP equal to its BioSupply cost"), "HP tooltip reworded")

func test_combat_manhattan_e2e():
	# Full combat: attacker at front col 0 should damage Manhattan-closest, not row-closest far col
	var human := _make_player("Human")
	var ai := _make_player("AI")
	var atk := Infantry.new()
	atk.Damage = 5
	_place(human, 0, 0, atk)
	var front_far := Wall.new()
	front_far.HitPoints = 20
	var back_close := Wall.new()
	back_close.HitPoints = 20
	_place(ai, 3, 9, front_far)
	_place(ai, 0, 0, back_close)
	var cs := CombatState.new(human, ai)
	var log: Array = cs.combat_phase()
	# Should have hit back_close (Manhattan 4) not front_far (10)
	assert_true(back_close.HitPoints < 20, "Manhattan closest back_close was hit")
	assert_eq(front_far.HitPoints, 20, "front far not hit when Manhattan closer exists")
