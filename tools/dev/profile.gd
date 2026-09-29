extends SceneTree
# Dev helper: frame times on the world map with vsync off (idle, panning, zoom, an AI combat turn).
# godot --path . --resolution 1600x900 -s tools/dev/profile.gd      (PROF_MAP=europe for another map)
func _initialize() -> void:
	_run()

func _measure(label: String, frames: int, each: Callable = Callable()) -> void:
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
	print("%-18s avg %.2f ms (%.0f fps)  p95 %.2f ms  proc %.2f ms  draw calls %d" % [label, avg, 1000.0 / avg, times[int(times.size() * 0.95)] / 1000.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await process_frame
	var gs = root.get_node("GameState")
	gs.start_map_campaign("State Troops", OS.get_environment("PROF_MAP"))
	change_scene_to_file("res://scenes/WorldMap.tscn")
	for i in range(30):
		await process_frame
	var gc = current_scene
	await _measure("idle", 240)
	await _measure("panning", 240, func(i): gc._view.pan_by(Vector2(6, 0)))
	gc._view.zoom_by(0.01)
	await _measure("zoomed out", 240)
	gc._view.center_on(gc._campaign().capital_site(gc._me()), 3.5)
	await _measure("zoomed in", 240)
	gc._view.center_on(gc._campaign().capital_site(gc._me()), 1.6)
	gc._speed_idx = 0
	gc._on_end_turn()
	await _measure("combat", 400)
	quit()
