extends GameObject
class_name CombatState

var Players: Array = [] # Player[2]

func _init(p1: Player = null, p2: Player = null):
	super._init()
	Players = []
	if p1 != null:
		Players.append(p1)
	if p2 != null:
		Players.append(p2)
