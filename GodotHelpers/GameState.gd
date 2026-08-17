extends Node

# Debug enemy selection persisted across scene reloads
var selected_enemy: String = "Euro Army" # "Euro Army" | "Insurgents"

func set_enemy(name: String):
	if name in ["Euro Army", "Insurgents"]:
		selected_enemy = name

func make_selected_enemy() -> AIPlayer:
	if selected_enemy == "Insurgents":
		return CardFactory.make_insurgents_player()
	return CardFactory.make_euro_army_player()

func background_path_for(player_name: String) -> String:
	if player_name == "Insurgents":
		return "res://Assets/Players/Insurgents/background.png"
	if player_name == "Euro Army":
		return "res://Assets/Players/Euro Army/background.png"
	return ""
