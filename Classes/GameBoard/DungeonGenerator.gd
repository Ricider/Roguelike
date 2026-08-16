extends RefCounted
class_name DungeonGenerator

# Generates a grid-based dungeon using random rooms + corridors
# 0 = wall, 1 = floor

var width: int
var height: int
var grid: Array = []

var rng := RandomNumberGenerator.new()

func _init(w: int, h: int, seed_val: int = 0):
	width = w
	height = h
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()

func generate(num_rooms: int = 8, min_size: int = 4, max_size: int = 8) -> Array:
	# fill with walls
	grid = []
	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(0)
		grid.append(row)

	var rooms: Array = []

	for i in range(num_rooms):
		var rw = rng.randi_range(min_size, max_size)
		var rh = rng.randi_range(min_size, max_size)
		var rx = rng.randi_range(1, width - rw - 1)
		var ry = rng.randi_range(1, height - rh - 1)
		var new_room := Rect2i(rx, ry, rw, rh)

		var overlaps := false
		for other in rooms:
			if new_room.intersects(other):
				overlaps = true
				break
		if overlaps:
			continue

		# carve room
		for y in range(ry, ry + rh):
			for x in range(rx, rx + rw):
				grid[y][x] = 1

		if rooms.size() > 0:
			var prev: Rect2i = rooms[-1]
			var prev_center := Vector2i(prev.position.x + prev.size.x / 2, prev.position.y + prev.size.y / 2)
			var new_center := Vector2i(rx + rw / 2, ry + rh / 2)
			# L-shaped corridor
			if rng.randf() < 0.5:
				_carve_h_corridor(prev_center.x, new_center.x, prev_center.y)
				_carve_v_corridor(prev_center.y, new_center.y, new_center.x)
			else:
				_carve_v_corridor(prev_center.y, new_center.y, prev_center.x)
				_carve_h_corridor(prev_center.x, new_center.x, new_center.y)

		rooms.append(new_room)

	# if we failed to place enough rooms, ensure at least 2
	if rooms.size() < 2:
		return generate(num_rooms, min_size, max_size)

	return grid

func _carve_h_corridor(x1: int, x2: int, y: int):
	for x in range(min(x1, x2), max(x1, x2) + 1):
		if y >= 0 and y < height and x >= 0 and x < width:
			grid[y][x] = 1

func _carve_v_corridor(y1: int, y2: int, x: int):
	for y in range(min(y1, y2), max(y1, y2) + 1):
		if y >= 0 and y < height and x >= 0 and x < width:
			grid[y][x] = 1

func get_random_floor_pos() -> Vector2i:
	var attempts := 200
	while attempts > 0:
		var x = rng.randi_range(0, width - 1)
		var y = rng.randi_range(0, height - 1)
		if grid[y][x] == 1:
			return Vector2i(x, y)
		attempts -= 1
	# fallback - scan
	for y in range(height):
		for x in range(width):
			if grid[y][x] == 1:
				return Vector2i(x, y)
	return Vector2i(1, 1)
