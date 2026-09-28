# Dev helper: boots a scene, lets it settle, saves a PNG of the viewport, quits.
# godot --path . -s tools/dev/screenshot.gd -- <scene> <out.png> [frames] [setup]
# setup: "battle" starts a run first, "battle_select" also selects the first hand card
# and hovers a square, "map" starts a map campaign first.
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
		elif setup == "map":
			gs.start_map_campaign("State Troops")
	change_scene_to_file(scene)
	for i in range(frames):
		await process_frame
	var gc = current_scene
	if setup == "battle_select" and gc != null and gc.has_method("_select_hand_slot"):
		gc._select_hand_slot(0)
		for i in range(10):
			await process_frame
		var grid = gc.player_board_container
		if grid != null and grid.get_child_count() > 13:
			gc._on_empty_tile_hover(grid.get_child(13), 1, 3)
		for i in range(20):
			await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	quit()
