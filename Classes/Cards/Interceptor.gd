extends Building
class_name Interceptor

func _init():
	super._init(20, 0, 50, 5, "Interceptor", 30)
	SpecialEffect = "Friendly units in adjacent squares take 50% less damage from enemies that have HasRange or Flying set to True, every time this damage reduction effect kicks in the interceptor loses 2 HP and its owner loses 6 MoneySupply"

# Find all interceptor squares adjacent (8-dir) to target_sq on defender's board
static func find_adjacent_interceptors(defender: Player, target_sq: Square) -> Array:
	var out: Array = []
	var pos = null
	for r in range(defender.Board.size()):
		for c in range(defender.Board[r].Squares.size()):
			if defender.Board[r].Squares[c] == target_sq:
				pos = {"r": r, "c": c}
				break
		if pos != null:
			break
	if pos == null:
		return out
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0:
				continue
			var nr: int = pos["r"] + dr
			var nc: int = pos["c"] + dc
			if nr < 0 or nr >= defender.Board.size():
				continue
			if nc < 0 or nc >= 10:
				continue
			var sq: Square = (defender.Board[nr] as Row).Squares[nc]
			if sq.Inhabitant != null and sq.Inhabitant is Interceptor:
				var hp: int = (sq.Inhabitant as Building).HitPoints
				if hp > 0:
					out.append(sq)
	return out

# Try to apply interceptor reduction. Returns reduced damage if applied, else original.
# Also applies side-effects: interceptor -2 HP, defender -6 MoneySupply per trigger (first interceptor only per hit)
# Skips entirely if owner has <6 MoneySupply (requested)
static func apply_interception(defender: Player, target_sq: Square, target_card: Card, attacker: Unit, attacker_player: Player, damage: int) -> int:
	# Protects both Units and Buildings (requested: buildings as well as units)
	if not (target_card is Unit or target_card is Building):
		return damage
	if defender.MoneySupply < 6:
		return damage
	var has_range: bool = attacker.HasRange
	if attacker_player != null and attacker_player.has_method("has_range_for"):
		has_range = attacker_player.has_range_for(attacker)
	var is_flying: bool = attacker.Flying
	# Only vs HasRange or Flying attackers
	if not (has_range or is_flying):
		return damage
	var interceptors: Array = find_adjacent_interceptors(defender, target_sq)
	if interceptors.is_empty():
		return damage
	# Halve damage (50% less) at least 1
	var reduced: int = int(damage / 2)
	if reduced < 1:
		reduced = 1
	# Pay cost on first interceptor
	var chosen_sq: Square = interceptors[0] as Square
	var interceptor: Interceptor = chosen_sq.Inhabitant as Interceptor
	interceptor.HitPoints -= 2
	defender.MoneySupply -= 6
	if defender.MoneySupply < 0:
		defender.MoneySupply = 0
	return reduced
