extends GameObject
class_name Card

var MoneyCost: int = 0
var BioCost: int = 0
var card_name: String = "Card"
var SpecialEffect: String = "" # AIInterpretedString per spec

func get_display_name() -> String:
	return card_name
