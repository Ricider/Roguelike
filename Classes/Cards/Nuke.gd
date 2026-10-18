extends Item
class_name Nuke

func _init():
	super._init("Nuke", 120, 240, 20, 4, {"Bomber Jet": 8})
	Falloff = 3 # 20 where it lands, then 17, 14, 11, 8 out to 4 hexes
	SpecialEffect = "One use: dropped by one of your [Bomber Jets] on any hex within 8 hexes. Every enemy card and flag within [4 hexes] of where it lands takes [20 damage] where it lands, [3 less] for every hex further out (8 at the edge), and the 7 hexes at its heart become [nuclear wasteland]: units starting their turn there take 3 damage. An enemy Interceptor within 3 hexes of the target halves it."
