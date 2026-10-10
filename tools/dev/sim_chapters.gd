extends SceneTree
# Plays story chapters headlessly with the AI on the player's side too (the same
# shop / deploy / move / fire logic the AI nations use), several times each, and
# reports how they end: a check that every chapter can be won.
#
#   godot --headless --path . -s tools/dev/sim_chapters.gd                 # every chapter
#   SIM_MAPS=story_2,story_horde_1 SIM_RUNS=5 SIM_TURNS=80 godot --headless --path . -s tools/dev/sim_chapters.gd
#   SIM_TRACE=1 also prints each round of the first run (land, HP, units, Money, Bio, damage).
#   SIM_SEED=n shifts the random seeds, for a different set of games.
#
# Per run: WIN (turn), LOSS (turn), or STALL (turn limit) with each nation's share of
# the land; "quiet" counts the rounds in which nobody damaged anybody (a stalemate sign).

const DEFAULT_RUNS := 3
const DEFAULT_TURNS := 60

func _init() -> void:
	var runs := int(OS.get_environment("SIM_RUNS")) if OS.get_environment("SIM_RUNS") != "" else DEFAULT_RUNS
	var turns := int(OS.get_environment("SIM_TURNS")) if OS.get_environment("SIM_TURNS") != "" else DEFAULT_TURNS
	var seed_base := int(OS.get_environment("SIM_SEED")) # shift the seeds to get different games
	var ids: Array = []
	if OS.get_environment("SIM_MAPS") != "":
		ids = Array(OS.get_environment("SIM_MAPS").split(","))
	else:
		for cid in StoryText.ORDER:
			for n in range(1, StoryText.count(cid) + 1):
				ids.append(StoryText.map_id(cid, n))
	var gs = load("res://GodotHelpers/GameState.gd").new()
	var bad: Array = []
	for mid in ids:
		var line: Array = []
		var wins := 0
		for r in range(runs):
			var res := _play(gs, str(mid), turns, 1000 + seed_base + r)
			line.append(res["text"])
			if res["won"]:
				wins += 1
		print("%-26s %d/%d won | %s" % [mid, wins, runs, " | ".join(line)])
		if wins == 0:
			bad.append(mid)
	print("NOT WON IN ANY RUN: ", bad if not bad.is_empty() else "none")
	gs.free()
	quit()

func _play(gs, mid: String, max_turns: int, seed: int) -> Dictionary:
	WorldMap.use_map(mid)
	var faction := str(StoryText.campaign(WorldMap.STORY_CAMPAIGN).get("faction", "State Troops"))
	var c := MapCampaign.new(faction)
	var w := MapWar.new()
	seed(seed)
	w.setup(c, func(nm): return gs.make_player_by_name(nm), gs.make_player_by_name(faction, true))
	w.rng.seed = seed
	var quiet := 0
	while w.turn <= max_turns:
		var dealt := 0
		w.reset_round_stats()
		for n in w.turn_order():
			if not w.alive(n):
				continue
			w.begin_turn(n)
			w.ai_shop(n)
			w.ai_build(n)
			w.ai_move(n)
			for k in w.attackers_of(n):
				if w.units.has(k):
					for e in w.fire(k):
						dealt += int(e.get("damage", 0))
			w.resolve_collapses()
			w.end_turn(n)
			if c.has_won():
				return {"won": true, "text": "WIN t%d" % w.turn}
			if c.has_lost():
				return {"won": false, "text": "LOSS t%d" % w.turn}
		if dealt == 0:
			quiet += 1
		if OS.get_environment("SIM_TRACE") == "1" and seed == 1000 + int(OS.get_environment("SIM_SEED")):
			var row: Array = []
			for nm in w.players.keys():
				if w.alive(nm):
					var p: Player = w.players[nm]
					var live_units := 0
					for cc in p.DrawPile + p.DiscardPile + p.Hand:
						if cc is Unit:
							live_units += 1
					var out_dmg := 0
					var kills := 0
					for key in w.round_stats.keys():
						if str(key).begins_with(str(nm) + "|"):
							out_dmg += int(w.round_stats[key].get("dealt", 0))
							kills += int(w.round_stats[key].get("kills", 0))
					row.append("%s %dhex hp%d/%d u%d $%d bio%d dealt%d kills%d" % [str(nm).substr(0, 4), c.tiles_of(nm).size(), p.HitPoints, p.MaxHitPoints, w.unit_count(nm), p.MoneySupply, p.BioSupply, out_dmg, kills])
			print("  t%d dealt %d | %s" % [w.turn, dealt, " | ".join(row)])
		w.turn += 1
	var total := 0
	var shares: Array = []
	for nm in c.alive_nations():
		total += c.tiles_of(str(nm)).size()
	for nm in c.alive_nations():
		shares.append("%s %d%%" % [str(nm).substr(0, 4), roundi(100.0 * c.tiles_of(str(nm)).size() / maxf(total, 1))])
	return {"won": false, "text": "STALL [%s] quiet %d" % [", ".join(shares), quiet]}
