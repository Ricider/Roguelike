extends GameObject
class_name Row

var Squares: Array = [] # Square[7]

func _init():
	super._init()
	Squares = []
	for i in range(7):
		Squares.append(Square.new())

func get_empty_squares() -> Array:
	var out: Array = []
	for s in Squares:
		if s.is_empty():
			out.append(s)
	return out

func get_occupied_squares() -> Array:
	var out: Array = []
	for s in Squares:
		if not s.is_empty():
			out.append(s)
	return out
