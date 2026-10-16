class_name Formations
extends RefCounted

const PRESETS := {
	3: ["2-1", "1-2", "1-1-1"],
	4: ["2-2", "1-2-1", "2-1-1", "1-1-2"],
	5: ["2-1-2", "2-2-1", "1-2-2", "3-1-1", "1-3-1"],
	6: ["3-2-1", "2-3-1", "1-3-2", "3-1-2", "2-1-2-1", "4-1-1"],
	7: ["3-3-1", "2-3-2", "4-2-1", "3-2-2", "2-4-1", "2-2-3",
		"3-1-2-1", "4-1-2", "2-1-3-1"],
}

const NICKNAMES := {
	"2-1": "Duas defesas, um ataque",
	"1-2": "Um defensor, dois atacantes",
	"1-1-1": "Linha espalhada",
	"2-2": "Equilibrada",
	"1-2-1": "Diamante",
	"2-1-1": "Retranca",
	"1-1-2": "Ofensiva direta",
	"2-1-2": "Meio-campo aberto",
	"2-2-1": "Defensiva equilibrada",
	"1-2-2": "Meio forte, dois atacantes",
	"3-1-1": "Defesa reforçada",
	"1-3-1": "Meio-campo povoado",
	"3-2-1": "Defesa sólida, um atacante",
	"2-3-1": "Meio-campo dominado",
	"1-3-2": "Ofensiva com meio forte",
	"3-1-2": "Contra-ataque",
	"2-1-2-1": "Losango clássico",
	"4-1-1": "Retranca absoluta",
	"3-3-1": "Equilibrada",
	"2-3-2": "Ofensiva equilibrada",
	"3-2-2": "Defesa sólida, dois atacantes",
	"2-4-1": "Meio-campo forte",
	"4-2-1": "Retranca com saída",
	"2-2-3": "Ataque total",
	"3-1-2-1": "Losango com três na defesa",
	"4-1-2": "Defesa sólida com dois atacantes",
	"2-1-3-1": "Losango ofensivo",
}

const DEPTH_FIRST := 0.30
const DEPTH_LAST := 0.80
const EDGE_MARGIN := 40.0


static func presets_for(player_count: int) -> Array[String]:
	var result: Array[String] = []
	if PRESETS.has(player_count):
		for f in PRESETS[player_count]:
			result.append(f)
	else:
		result.append(_auto_formation(player_count))
	return result


static func nickname(formation: String) -> String:
	return NICKNAMES.get(formation, "")


static func _auto_formation(count: int) -> String:
	var parts: PackedStringArray = []
	var left: int = count
	while left > 0:
		var n: int = mini(2, left)
		parts.append(str(n))
		left -= n
	return "-".join(parts)


static func parse(formation: String) -> Array[int]:
	var lines: Array[int] = []
	for s in formation.split("-"):
		if s.is_valid_int() and int(s) > 0:
			lines.append(int(s))
	return lines


static func slots(formation: String, team: int, field: Field) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var lines: Array[int] = parse(formation)
	if lines.is_empty():
		return result
	var half: Vector2 = field.pitch_size * 0.5
	var dir: float = float(field.defend_dir(team))
	for i in lines.size():
		var t: float = 0.5 if lines.size() == 1 else float(i) / float(lines.size() - 1)
		var depth: float = lerpf(DEPTH_FIRST, DEPTH_LAST, t)
		var x: float = dir * half.x * (1.0 - depth)
		var n: int = lines[i]
		var half_span: float = minf(half.y * (0.30 + 0.20 * float(n - 1)), half.y * 0.8)
		for k in n:
			var y: float = 0.0 if n == 1 else lerpf(-half_span, half_span, float(k) / float(n - 1))
			result.append(field.to_global(Vector2(x, y)))
	return result


static func team_area(team: int, field: Field) -> Rect2:
	var half: Vector2 = field.pitch_size * 0.5
	var left: bool = field.defend_dir(team) < 0
	var x0: float = -half.x + EDGE_MARGIN if left else EDGE_MARGIN
	var x1: float = -EDGE_MARGIN if left else half.x - EDGE_MARGIN
	return Rect2(x0, -half.y + EDGE_MARGIN, x1 - x0, (half.y - EDGE_MARGIN) * 2.0)


static func flip_position(global_pos: Vector2, field: Field) -> Vector2:
	var l: Vector2 = field.to_local(global_pos)
	return field.to_global(-l)


static func assign(players: Array[Player], slot_positions: Array[Vector2]) -> Dictionary:
	var free: Array[Player] = players.duplicate()
	var result := {}
	for s in slot_positions:
		if free.is_empty():
			break
		var best: Player = free[0]
		for p in free:
			if p.global_position.distance_to(s) < best.global_position.distance_to(s):
				best = p
		result[best] = s
		free.erase(best)
	return result
