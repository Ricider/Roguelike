extends SceneTree
# AI tournaments: two AI strategies (MapWar.ai_policy overrides) play each other in
# headless games, to find out which tactics win. Each "pair" is two games on the
# same map and seed: a random half of the nations plays strategy A and the rest B,
# then the sides swap. Each nation's share of the land under A minus its share under
# B cancels out how strong the factions themselves are.
#
#   T_A='{"walls":"never"}' T_B='{}' T_PAIRS=6 godot --headless --path . -s tools/dev/ai_tournament.gd
#   T_MAP=world T_ROUNDS=30 T_SEED=100 ...
#
# Prints one "DELTA <nation> <A share - B share>" line per nation per pair, then a
# summary: mean land-share gain for A (in points of the map), its standard error,
# and how often A did better.

func _init() -> void:
	var map_id := OS.get_environment("T_MAP") if OS.get_environment("T_MAP") != "" else "europe"
	var rounds := int(OS.get_environment("T_ROUNDS")) if OS.get_environment("T_ROUNDS") != "" else 25
	var pairs := int(OS.get_environment("T_PAIRS")) if OS.get_environment("T_PAIRS") != "" else 4
	var seed0 := int(OS.get_environment("T_SEED"))
	var pol_a: Dictionary = _json("T_A")
	var pol_b: Dictionary = _json("T_B")
	var gs = load("res://GodotHelpers/GameState.gd").new()
	var deltas: Array = []
	for i in range(pairs):
		var s := seed0 + i
		WorldMap.use_map(map_id)
		var names: Array = []
		for n in WorldMap.nations():
			names.append(str(n["name"]))
		var r := RandomNumberGenerator.new()
		r.seed = s * 7919 + 13
		for j in range(names.size() - 1, 0, -1): # seeded shuffle
			var x := r.randi_range(0, j)
			var tmp = names[j]
			names[j] = names[x]
			names[x] = tmp
		var half := names.slice(0, names.size() / 2)
		var g1 := _play(gs, map_id, rounds, s, half, pol_a, pol_b)
		var g2 := _play(gs, map_id, rounds, s, half, pol_b, pol_a)
		for nm in names:
			# nm played A in g1 if it is in `half`, else in g2
			var a_share: float = g1[nm] if half.has(nm) else g2[nm]
			var b_share: float = g2[nm] if half.has(nm) else g1[nm]
			var d := a_share - b_share
			deltas.append(d)
			print("DELTA %s %.4f" % [nm.replace(" ", "_"), d])
	var mean := 0.0
	for d in deltas:
		mean += d
	mean /= maxf(deltas.size(), 1)
	var var_sum := 0.0
	var better := 0
	for d in deltas:
		var_sum += (d - mean) * (d - mean)
		if d > 0.0:
			better += 1
	var se := sqrt(var_sum / maxf(deltas.size() - 1, 1)) / sqrt(maxf(deltas.size(), 1))
	print("SUMMARY map=%s rounds=%d samples=%d mean_gain=%.2f%% se=%.2f%% A_better=%d/%d" % [map_id, rounds, deltas.size(), mean * 100.0, se * 100.0, better, deltas.size()])
	gs.free()
	quit()

func _json(key: String) -> Dictionary:
	var txt := OS.get_environment(key)
	if txt == "":
		return {}
	var v = JSON.parse_string(txt)
	return v if v is Dictionary else {}

# One all-AI game: nations in `group` play pol_in, the rest pol_out. Returns nation -> share of land.
func _play(gs, map_id: String, rounds: int, s: int, group: Array, pol_in: Dictionary, pol_out: Dictionary) -> Dictionary:
	WorldMap.use_map(map_id)
	var names: Array = []
	for n in WorldMap.nations():
		names.append(str(n["name"]))
	var c := MapCampaign.new(names[0])
	c.player_nation = "" # nobody is human: no one "wins" early
	seed(s)
	var w := MapWar.new()
	w.setup(c, func(nm): return gs.make_player_by_name(nm), null)
	w.rng.seed = s
	for nm in names:
		w.ai_policy[nm] = pol_in if group.has(nm) else pol_out
	for t in range(rounds):
		for n in w.turn_order():
			if not w.alive(n):
				continue
			w.begin_turn(n)
			w.ai_shop(n)
			w.ai_use_items(n)
			w.ai_build(n)
			w.ai_move(n)
			for k in w.attackers_of(n):
				if w.units.has(k):
					w.fire(k)
			w.resolve_collapses()
			w.end_turn(n)
		w.turn += 1
		if c.alive_nations().size() <= 1:
			break
	var total := 0.0
	for nm in names:
		total += c.tiles_of(nm).size()
	var out := {}
	for nm in names:
		out[nm] = c.tiles_of(nm).size() / maxf(total, 1.0)
	return out
