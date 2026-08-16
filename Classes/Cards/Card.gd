extends GameObject
class_name Card

# Base card - spec says just pass, but we store costs for logic
var MoneyCost: int = 0
var BioCost: int = 0
var card_name: String = "Card"

func get_display_name() -> String:
	return card_name
