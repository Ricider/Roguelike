extends SceneTree
# Dev helper: frame times on a crowded map (vsync off). Fills every nation's land with
# cards from its own deck (every STRESS_STEP-th owned hex: 3 gives ~400 cards on the
# world map, 1 gives ~1100), then measures.
#
#   godot --path . --resolution 1600x900 -s tools/dev/stress_profile.gd
#
# Modes (environment variables):
#   (default)          idle and panning at several zooms, whole map down to close up
#   STRESS_LAYERS=1    ...also the mean cost of each map layer's redraw
#   STRESS_COMBAT=1    a whole AI round from End Turn until it is your turn again (the
#                      frames over 16.7 ms, and what the game was doing in them);
#                      STRESS_FOLLOW=1 with the follow camera on
#   STRESS_AI_TIMES=1  (with STRESS_COMBAT) how long each nation's shop / build / move /
#                      attacks take to think, unsliced
#   STRESS_SHOT=/tmp/x screenshots at three zooms, centred on a Barracks
#   STRESS_STEP=n      density; PROF_MAP=<id> another map (default world)

var _layer_us: Dictionary = {} # layer -> [microseconds drawing, calls]

func _initialize() -> void:
	_run()

func _env(key: String) -> String:
	return OS.get_environment(key)

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await process_frame
	var gs = root.get_node("GameState")
	gs.start_map_campaign("State Troops", _env("PROF_MAP") if _env("PROF_MAP") != "" else "world")
	change_scene_to_file("res://scenes/WorldMap.tscn")
	for i in range(30):
		await process_frame
	var gc = current_scene
	var view = gc._view
	var war: MapWar = gc._war
	var step := int(_env("STRESS_STEP")) if _env("STRESS_STEP") != "" else 3
	for nm in war.players.keys():
		var p: Player = war.players[nm]
		var deck: Array = p.DrawPile + p.DiscardPile + p.Hand
		if deck.is_empty():
			continue
		var tiles: Array = war.campaign.tiles_of(str(nm))
		for i in range(0, tiles.size(), step):
			var t: Vector2i = tiles[i]
			if not war.units.has(MapCampaign.key_of(t.x, t.y)):
				war._put(str(nm), deck[(i / step) % deck.size()].get_script().new(), t)
	print("cards on the map: %d (step %d)" % [war.units.size(), step])
	if _env("STRESS_SHOT") != "":
		await _screenshots(gc)
	elif _env("STRESS_COMBAT") == "1":
		await _combat(gc)
	else:
		if _env("STRESS_LAYERS") == "1":
			_time_layers(view)
		for z in [["whole map", 0.0], ["6px hexes", 6.0], ["12px hexes", 12.0], ["18px hexes", 18.0], ["30px hexes", 30.0]]:
			if float(z[1]) <= 0.0:
				view.zoom_by(0.01)
			else:
				view.center_on(gc._campaign().capital_site(gc._me()), view.zoom_for_hex_size(float(z[1])))
			for i in range(20):
				await process_frame
			await _measure(str(z[0]) + " idle", 240)
			await _measure(str(z[0]) + " pan", 240, func(_i): view.pan_by(Vector2(4, 0)))
	quit()

func _measure(label: String, frames: int, each: Callable = Callable()) -> void:
	for k in _layer_us.keys():
		_layer_us[k] = [0, 0]
	var times: Array = []
	var last := Time.get_ticks_usec()
	for i in range(frames):
		if each.is_valid():
			each.call(i)
		await process_frame
		var now := Time.get_ticks_usec()
		times.append(now - last)
		last = now
	times.sort()
	var total := 0
	for t in times:
		total += t
	var avg: float = float(total) / times.size() / 1000.0
	print("%-18s avg %6.2f ms (%4.0f fps)  p95 %6.2f ms  worst %6.2f ms" % [label, avg, 1000.0 / avg,
		times[int(times.size() * 0.95)] / 1000.0, times[times.size() - 1] / 1000.0])
	if not _layer_us.is_empty():
		var parts: Array = []
		for k in _layer_us.keys():
			parts.append("%s %.2f ms x%d" % [k, _layer_us[k][0] / 1000.0 / maxi(_layer_us[k][1], 1), _layer_us[k][1]])
		print("    redraws: ", ", ".join(parts))

# Wrap each map layer's draw callback with a timer.
func _time_layers(view) -> void:
	for pair in [["grid", view._grid, view._draw_base], ["under", view._under, view._draw_under],
			["units", view._units, view._draw_unit_layer], ["walkers", view._walkers, view._draw_walker_layer],
			["overlay", view._overlay, view._draw_overlay], ["chips", view._chips, view._draw_chip_layer],
			["text", view._text_layer, view._draw_text_fx], ["terrain", view._terrain, view._draw_terrain]]:
		var node: CanvasItem = pair[1]
		var fn: Callable = pair[2]
		var label: String = pair[0]
		node.draw.disconnect(fn)
		_layer_us[label] = [0, 0]
		node.draw.connect(func():
			var t0 := Time.get_ticks_usec()
			fn.call()
			_layer_us[label][0] += Time.get_ticks_usec() - t0
			_layer_us[label][1] += 1)

func _combat(gc) -> void:
	gc._view.zoom_by(0.01)
	gc._follow_cam = _env("STRESS_FOLLOW") == "1"
	gc._speed_idx = 0
	for i in range(20):
		await process_frame
	if _env("STRESS_AI_TIMES") == "1":
		var w: MapWar = gc._war
		for nm in w.turn_order():
			if nm == gc._me() or not w.alive(nm):
				continue
			w.begin_turn(nm)
			var a := Time.get_ticks_usec()
			w.ai_shop(nm)
			var b := Time.get_ticks_usec()
			w.ai_build(nm)
			var c := Time.get_ticks_usec()
			w.ai_move(nm)
			var d := Time.get_ticks_usec()
			var attackers := w.attackers_of(nm)
			for k in attackers:
				if w.units.has(k):
					w.fire(k)
			w.resolve_collapses()
			var e := Time.get_ticks_usec()
			print("%-18s shop %5.1f  build %5.1f  move %6.1f  attacks %5.1f ms (%d attackers)" % [nm, (b - a) / 1000.0,
				(c - b) / 1000.0, (d - c) / 1000.0, (e - d) / 1000.0, attackers.size()])
		return
	gc._on_end_turn()
	var t_round := Time.get_ticks_msec()
	var times: Array = []
	var slow: Dictionary = {} # what the game was doing -> frames over 16.7 ms
	var last := Time.get_ticks_usec()
	while gc._busy and times.size() < 20000:
		var doing: String = gc._status.text + (" (shots)" if not gc._view.effects.is_empty() else "") + (" (marching)" if not gc._view.walks.is_empty() else "")
		await process_frame
		var now := Time.get_ticks_usec()
		if now - last > 16700:
			var key := doing + (" [over 40 ms]" if now - last > 40000 else "")
			slow[key] = int(slow.get(key, 0)) + 1
		times.append(now - last)
		last = now
	for key in slow.keys():
		print("  slow frames: %3d  %s" % [slow[key], key])
	times.sort()
	var total := 0
	var n_slow := 0
	for t in times:
		total += t
		if t > 16700:
			n_slow += 1
	var avg := float(total) / maxf(times.size(), 1) / 1000.0
	print("whole AI round: %.1f s, %d frames, avg %.2f ms (%.0f fps), p95 %.2f ms, p99 %.2f ms, worst %.2f ms, over 16.7 ms: %d (%.1f%%)" % [
		(Time.get_ticks_msec() - t_round) / 1000.0, times.size(), avg, 1000.0 / avg, times[int(times.size() * 0.95)] / 1000.0,
		times[int(times.size() * 0.99)] / 1000.0, times[times.size() - 1] / 1000.0, n_slow, 100.0 * n_slow / maxf(times.size(), 1)])

func _screenshots(gc) -> void:
	var view = gc._view
	var focus: Vector2i = gc._campaign().capital_site(gc._me())
	view.unit_cache()
	if not view._ucache_barracks.is_empty():
		focus = view._ucache_barracks[0]
	for z in [4.0, 12.0, 26.0]:
		if z <= 4.0:
			view.zoom_by(0.01)
		else:
			view.center_on(focus, view.zoom_for_hex_size(z))
		for i in range(10):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s_%d.png" % [_env("STRESS_SHOT"), int(z)])
