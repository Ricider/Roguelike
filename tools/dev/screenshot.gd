# Dev helper: boots a scene, lets it settle, saves a PNG of the viewport, quits.
# godot --path . -s tools/dev/screenshot.gd -- <scene> <out.png> [frames] [setup]
# setup: "battle" starts a run first, "battle_select" also selects the first hand card
# and hovers a square, "battle_endturn" plays one full combat turn,
# "map" starts a map campaign first, "map_turn" also deploys a card and plays a full round.
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
			gs.start_map_campaign("State Troops")
	change_scene_to_file(scene)
	for i in range(frames):
		await process_frame
	var gc = current_scene
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
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
