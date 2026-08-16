extends Building
class_name Barracks

func _init():
	super._init(70, 2, 20, 25, "Barracks")
	SpecialEffect = "Friendly units in adjacent squares have +2 damage"

static func bonus_if_adjacent(player: Player, square: Square) -> int:
	# Spec: Friendly units in adjacent squares (orthogonal+diagonal) have +2 damage
	for r_idx in range(player.Board.size()):
		var row: Row = player.Board[r_idx]
		for c_idx in range(row.Squares.size()):
			if row.Squares[c_idx] == square:
				for dr in [-1, 0, 1]:
					for dc in [-1, 0, 1]:
						if dr == 0 and dc == 0:
							continue
						var nr: int = r_idx + dr
						var nc: int = c_idx + dc
						if nr < 0 or nr >= player.Board.size():
							continue
						if nc < 0 or nc >= 10:
							continue
						var n_sq: Square = (player.Board[nr] as Row).Squares[nc]
						if n_sq.Inhabitant != null and n_sq.Inhabitant is Barracks:
							return 2
				return 0
	return 0
