extends GameObject
class_name Square

var Inhabitant: Card = null

func is_empty() -> bool:
	return Inhabitant == null

func place(card: Card) -> bool:
	if not is_empty():
		return false
	Inhabitant = card
	return true

func clear():
	Inhabitant = null
