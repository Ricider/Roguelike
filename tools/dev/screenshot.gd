# Dev helper: boots a scene, lets it settle, saves a PNG of the viewport, quits.
# godot --path . -s tools/dev/screenshot.gd -- <scene> <out.png> [frames] [setup]
# setup: "battle" starts a run first, "battle_select" also selects the first hand card
# and hovers a square, "battle_endturn" plays one full combat turn,
# "press:<Button>" presses a named button, "map_shop" opens the map shop with 120 Influence, "map" starts a map campaign first, "map_turn" also deploys a card and plays a full round.
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
	change_scene_to_file(scene)
	for i in range(frames):
		await process_frame
	var gc = current_scene
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
		for rnd in range(rounds):
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
			while gc._busy and waited < 20000:
				await process_frame
				waited += 1
			print("round ", rnd + 1, " took ", Time.get_ticks_msec() - t0, "ms")
		for i in range(30):
			await process_frame
		print("round_frames=", waited, " turn=", gc._war.turn, " units=", gc._war.units.size())
		for line in gc._log_lines:
			print("LOG ", line)
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
	# force a synchronous draw: waiting for frame_post_draw hangs if the OS
	# stops drawing an occluded window, and a stale frame shows old UI
	RenderingServer.force_draw(false)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
