# Dev helper: boots a scene, lets it settle, saves a PNG of the viewport, quits.
# godot --path . -s tools/dev/screenshot.gd -- <scene> <out.png> [frames] [setup]
# setup: "battle" starts a run first, "battle_select" also selects the first hand card
# and hovers a square, "battle_endturn" plays one full combat turn,
# "press:<Button>" presses a named button, "map_shop" opens the map shop with 120 Influence, "map" starts a map campaign first, "map_turn" also deploys a card and plays a full round, "map_boat" stages two units sailing out to sea. SNAP_EVERY=N saves a frame every N frames during map_turn rounds (out_NNNN.png).
extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: String = args[0] if args.size() > 0 else "res://scenes/Main.tscn"
	var out: String = args[1] if args.size() > 1 else "user://shot.png"
	var frames: int = int(args[2]) if args.size() > 2 else 90
	var setup: String = args[3] if args.size() > 3 else ""
	_run(scene, out, frames, setup)

func _run(scene: String, out: String, frames: int, setup: String) -> void:
	await process_frame
	var gs = root.get_node_or_null("GameState")
	if gs != null:
		if setup.begins_with("battle"):
			gs.start_run("State Troops")
		elif setup == "tutorial":
			gs.start_tutorial()
		elif setup.begins_with("map"):
			# "map_turn3@europe" plays on a specific map
			gs.start_map_campaign("State Troops", setup.get_slice("@", 1) if setup.contains("@") else "")
			setup = setup.get_slice("@", 0)
		elif setup.begins_with("story:"):
			# story:<phase>:<chapter> opens scenes/Story.tscn on that screen (text shown in full)
			gs.story_screen = {"phase": setup.get_slice(":", 1), "chapter": int(setup.get_slice(":", 2))}
	change_scene_to_file(scene)
	for i in range(frames):
		await process_frame
	var gc = current_scene
	if setup.begins_with("map_fx") and gc != null and gc.has_method("_nation_attacks"):
		# stage: player Barracks + Infantry (buffed) and an enemy Infantry beside an enemy Interceptor
		var w: MapWar = gc._war
		var me: String = gc._me()
		var flag: Vector2i = gc._campaign().capital_site(me)
		var free: Array = []
		for t in gc._campaign().tiles_of(me):
			if not w.units.has(MapCampaign.key_of(t.x, t.y)) and t != flag:
				free.append(t)
		free.sort_custom(func(a, b): return MapCampaign.hex_distance(a, flag) < MapCampaign.hex_distance(b, flag))
		var bar_hex: Vector2i = free[0]
		var inf_hex: Vector2i = Vector2i(-1, -1)
		for t in free:
			if MapCampaign.hex_distance(t, bar_hex) == 1:
				inf_hex = t
				break
		w._put(me, Barracks.new(), bar_hex)
		w._put(me, Drone.new(), inf_hex) # flying + melee: hits the closest target and triggers Interceptors
		# enemy: the nearest foreign hex pair gets an Interceptor + Infantry
		var enemy_hex := Vector2i(-1, -1)
		var best := 1 << 30
		for k in gc._campaign().owner.keys():
			var o := str(gc._campaign().owner[k])
			if o == me:
				continue
			var t2 := MapWar.key_to_hex(k)
			var d := MapCampaign.hex_distance(t2, inf_hex)
			if d < best and not w.units.has(k) and t2 != gc._campaign().capital_site(o):
				best = d
				enemy_hex = t2
		var foe: String = gc._campaign().owner_of(enemy_hex.x, enemy_hex.y)
		for nb in MapCampaign.wrapped_neighbors(enemy_hex):
			if gc._campaign().owner_of(nb.x, nb.y) == foe and not w.units.has(MapCampaign.key_of(nb.x, nb.y)):
				w._put(foe, Interceptor.new(), nb)
				break
		(w.players[foe] as Player).MoneySupply = 100
		var tough := Wall.new()
		tough.HitPoints = 500
		w._put(foe, tough, enemy_hex)
		gc._view.center_on(inf_hex, gc._view.zoom_for_hex_size(26.0))
		for i in range(20):
			await process_frame
		if setup == "map_fx_fire":
			gc._speed_idx = 0
			var entries: Array = w.fire(MapCampaign.key_of(inf_hex.x, inf_hex.y))
			# march the unit to its target (FX_FRAMES decides how far along the frame catches it)
			var walk_path: Array = gc._walk_path(MapCampaign.key_of(inf_hex.x, inf_hex.y), enemy_hex, {})
			gc._view.walk_out(MapCampaign.key_of(inf_hex.x, inf_hex.y), walk_path, 0.08)
			print("walk path ", walk_path)
			for e in entries:
				gc._view.add_shot(e["from"], e["to"], "shot_cannon", 0.28)
				if e.get("buffed", false):
					gc._view.add_buff(e["from"])
				if e.get("intercepted", false):
					gc._view.add_intercept(e["intercept_from"], e["to"], 0.28)
				gc._view.add_number(e["to"], "-%d" % int(e["damage"]), Color(1, 0.45, 0.4), 0.28)
				print("fx shot buffed=", e.get("buffed"), " intercepted=", e.get("intercepted"), " from=", e.get("intercept_from"))
			for i in range(int(OS.get_environment("FX_FRAMES")) if OS.get_environment("FX_FRAMES") != "" else 20):
				await process_frame
	if setup == "map_boat" and gc != null and gc.has_method("_walk_path"):
		# a Tank and an Infantry on the player's coast sail 3 sea hexes out (slow, to catch the boats)
		var w2: MapWar = gc._war
		var me2: String = gc._me()
		var sailed := 0
		for t in gc._campaign().tiles_of(me2):
			if sailed >= 2:
				break
			if w2.units.has(MapCampaign.key_of(t.x, t.y)) or t == gc._campaign().capital_site(me2):
				continue
			var path: Array = [t]
			var cur: Vector2i = t
			for i in range(3):
				var nxt := Vector2i(-1, -1)
				for nb in MapCampaign.wrapped_neighbors(cur):
					if not WorldMap.is_land(nb.x, nb.y) and not path.has(nb):
						nxt = nb
						break
				if nxt.x < 0:
					break
				path.append(nxt)
				cur = nxt
			if path.size() < 4:
				continue
			var unit: Card = Tank.new() if sailed == 0 else Infantry.new()
			w2._put(me2, unit, t)
			gc._view.walk_out(MapCampaign.key_of(t.x, t.y), path, 1.5)
			if sailed == 0:
				gc._view.center_on(path[2], gc._view.zoom_for_hex_size(34.0))
			print("boat path ", path)
			sailed += 1
		for i in range(int(OS.get_environment("FX_FRAMES")) if OS.get_environment("FX_FRAMES") != "" else 150):
			await process_frame
	if setup.begins_with("map_hover") and gc != null and gc.has_method("_show_map_hover"):
		# hover the player's first unit on the map (or a hand card with map_hover_hand)
		if setup == "map_hover_hand":
			var hb = gc._hand_box.get_child(0)
			hb.mouse_entered.emit()
		else:
			for k in gc._war.cards_of(gc._me()):
				if gc._war.units[k]["card"] is Unit:
					var t := MapWar.key_to_hex(k)
					gc._view.center_on(t, gc._view.zoom)
					for i in range(5):
						await process_frame
					# feed mouse motion onto the unit through the normal input path, every frame,
					# so a real cursor resting over the test window can't steal the hover
					var gp: Vector2 = gc._view.hex_global_rect(t).get_center()
					for i in range(20):
						var mm := InputEventMouseMotion.new()
						mm.position = gp + Vector2(i % 2, 0)
						mm.global_position = mm.position
						root.push_input(mm, true) # viewport coordinates (the window is scaled)
						await process_frame
					print("hover unit at ", t)
					break
		for i in range(4):
			await process_frame
		if setup == "map_hover":
			print("after frames aim=", gc._view.aim, " hovered=", gc._view.hovered)
	if setup.begins_with("press:") and gc != null:
		# press a named button (e.g. press:PlayButton) and report where it leads
		var names: PackedStringArray = setup.substr(6).split("/")
		var btn := gc.find_child(names[0], true, false) as Button
		if names.size() > 1 and btn != null:
			btn.pressed.emit()
			for i in range(20):
				await process_frame
			btn = current_scene.find_child(names[1], true, false) as Button
		if btn != null:
			btn.pressed.emit()
			for i in range(60):
				await process_frame
		# press:A/B presses A, then B (e.g. PlayButton/Map_europe)
		var gs3 = root.get_node_or_null("GameState")
		print("pressed=", setup.substr(6), " scene=", current_scene.scene_file_path if current_scene else "none", " map_mode=", gs3.map_mode, " run_started=", gs3.run_started)
	if setup == "map_conquer" and gc != null and gc.has_method("_resolve_collapses"):
		# force a neighbour to collapse with all its damage credited to the player
		var me: String = gc._me()
		var victim := ""
		for n in gc._war.turn_order():
			if n != me and gc._campaign().is_neighbor(me, n):
				victim = n
				break
		var inf0: int = gc._human().Influence
		(gc._war.players[victim] as Player).HitPoints = 0
		gc._war.ledger[victim] = {me: 50}
		gc._resolve_collapses()
		for i in range(40):
			await process_frame
		print("conquer victim=", victim, " influence ", inf0, " -> ", gc._human().Influence, " label=", gc._inf_label.text)
	if setup == "map_shop" and gc != null and gc.has_method("_open_shop"):
		gc._human().Influence = 120
		gc._refresh_player_card()
		gc._open_shop()
		for i in range(10):
			await process_frame
		var before: int = gc._human().Influence
		var offer: Array = gc._war.shop_of(gc._me())["cards"]
		var bought: bool = gc._war.buy_card(gc._me(), offer[0]) if not offer.is_empty() else false
		gc._after_purchase()
		gc._build_shop(false)
		print("shop bought=", bought, " influence ", before, " -> ", gc._human().Influence, " drawpile=", gc._human().DrawPile.size())
		for i in range(20):
			await process_frame
	if setup.begins_with("map_turn") and gc != null and gc.has_method("_on_end_turn"):
		# each round: deploy every affordable card on free own hexes, End Turn, let all AIs play (4x)
		gc._speed_idx = 2
		var rounds: int = int(setup.substr(8)) if setup.length() > 8 else 1
		var waited := 0
		var cam0: Array = gc._view.camera_state() # the follow camera should hand this back each round
		for rnd in range(rounds):
			_dismiss_briefing(gc)
			for card in gc._human().Hand.duplicate():
				if gc._war.shortfall(gc._me(), card) == "" and gc._busy == false:
					gc._select_card([card])
					if gc._view.placeable.is_empty():
						break
					var key: String = gc._view.placeable.keys()[0]
					var t := MapWar.key_to_hex(key)
					gc._on_tile_selected(t.x, t.y)
			gc._clear_selection()
			var t0 := Time.get_ticks_msec()
			gc._on_end_turn()
			var snap_every := int(OS.get_environment("SNAP_EVERY")) # >0: save a frame every N frames mid-round
			while gc._busy and waited < 20000:
				await process_frame
				waited += 1
				_dismiss_briefing(gc)
				if snap_every > 0 and waited % snap_every == 0:
					RenderingServer.force_draw(false)
					root.get_viewport().get_texture().get_image().save_png(out.get_basename() + "_%04d.png" % waited)
					print("SNAP ", waited, " status=", gc._status.text)
			print("round ", rnd + 1, " took ", Time.get_ticks_msec() - t0, "ms")
		for i in range(30):
			await process_frame
		print("camera back home: ", (gc._view.camera_state()[0] as Vector2).distance_to(cam0[0]) < 0.5 and absf(float(gc._view.camera_state()[1]) - float(cam0[1])) < 0.01)
		print("round_frames=", waited, " turn=", gc._war.turn, " units=", gc._war.units.size())
		for line in gc._log_lines:
			print("LOG ", line)
		if OS.get_environment("REPORT_SORT") != "":
			# reopen the round report sorted by a column (REPORT_DESC=0 for ascending, REPORT_ALL=1 for all nations)
			gc._report_all = OS.get_environment("REPORT_ALL") == "1"
			gc._report_sort = OS.get_environment("REPORT_SORT")
			gc._report_sort_desc = OS.get_environment("REPORT_DESC") != "0"
			gc._open_report()
			for i in range(10):
				await process_frame
			for r in gc._report_rows():
				print("ROW ", r[0], " -> ", r[1], " ", gc._report_sort_value(r, gc._report_sort))
			# REPORT_CLICK=Dealt presses that header 3 times through the UI and reports the order each time
			var click := OS.get_environment("REPORT_CLICK")
			for n in range(3 if click != "" else 0):
				var hb: Button = null
				for b in gc._report_panel.find_children("*", "Button", true, false):
					if (b as Button).text == click:
						hb = b
				hb.pressed.emit()
				for i in range(4):
					await process_frame
				var vals := []
				for r in gc._report_rows():
					vals.append(gc._report_sort_value(r, gc._report_sort))
				print("CLICK ", n + 1, " sort=", gc._report_sort, " desc=", gc._report_sort_desc, " values=", vals)
	if setup == "battle_endturn" and gc != null and gc.has_method("_on_end_turn"):
		# place a couple of units, then run a full combat turn (exercises combat sfx/log)
		for slot in range(2):
			gc._select_hand_slot(slot)
			for r in range(4):
				for c in range(10):
					if gc.selected_card != null and gc.human.Board[r].Squares[c].is_empty():
						gc._on_board_click(r, c)
		gc._on_end_turn()
		for i in range(420):
			await process_frame
		var sm = root.get_node_or_null("SoundManager")
		if sm != null:
			print("music=", sm._music_name, " sfx_voices_used=", sm._last_played.keys())
	if setup.begins_with("story:") and gc != null and gc.has_method("_finish_typing"):
		gc._finish_typing()
		for i in range(30):
			await process_frame
	# force a synchronous draw: waiting for frame_post_draw hangs if the OS
	# stops drawing an occluded window, and a stale frame shows old UI
	RenderingServer.force_draw(false)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()

# Story briefings wait for their button; automated rounds press it (KEEP_BRIEFING=1 to leave them up).
func _dismiss_briefing(gc) -> void:
	if OS.get_environment("KEEP_BRIEFING") == "1" or gc == null or gc.get("_briefing") == null:
		return
	if is_instance_valid(gc._briefing):
		var ok = gc._briefing.find_child("BriefingOK", true, false)
		if ok != null:
			ok.pressed.emit()
