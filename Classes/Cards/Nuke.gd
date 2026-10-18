extends Item
class_name Nuke

func _init():
	super._init("Nuke", 120, 240, 20, 4, {"Bomber Jet": 8})
	SpecialEffect = "One use: dropped by one of your [Bomber Jets] on any hex within 8 hexes. Every enemy card and flag within [4 hexes] of where it lands takes [20 damage], and the 7 hexes at its heart become [nuclear wasteland]: units starting their turn there take 3 damage. An enemy Interceptor within 3 hexes of the target halves it."
