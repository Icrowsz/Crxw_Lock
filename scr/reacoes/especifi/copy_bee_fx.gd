class_name CopyBeeFX
extends RefCounted
## Efeitos da Reação Química Copy-Bee (Bachira + Reo), todos desenhados por código:
##  - A VESPA: agressiva. Vista de frente, de cabeça angular com olhos estreitos e brilhantes em "V" de raiva,
##    mandíbulas grandes que estalam, antenas inquietas, asas afiadas batendo muito rápido, patas com ganchos e
##    um ferrão longo pingando veneno. Paira tremendo, inclinada para a frente, e a cada ~2 s dá uma
##    ferroada (um bote para a frente). Amarela e preta no Bachira, roxa no Reo.
##  - AS GARRAS (no lugar da pantera): quando o Reo chuta o Model: Panther, a vespa avança e três garras
##    roxas rasgam a bola num "X" (como as garras do Chigiri); enquanto a bola voa, ela vai sendo arranhada
##    por novas garras ao longo do caminho. Some quando alguém toca na bola ou o tempo acaba.

const YELLOW := Color(1.0, 0.85, 0.2)
const BLACK := Color(0.1, 0.1, 0.1)
const PURPLE := Color(0.65, 0.3, 0.95)
const PURPLE_DARK := Color(0.3, 0.05, 0.5)
const PURPLE_LIGHT := Color(0.86, 0.72, 1.0)

const EYE_RED := Color(1.0, 0.16, 0.08)        # olhos da vespa amarela (Bachira)
const EYE_VIOLET := Color(1.0, 0.25, 0.95)     # olhos da vespa roxa (Reo)
const VENOM := Color(1.0, 0.55, 0.08)          # veneno do ferrão (Bachira)
const VENOM_PURPLE := Color(0.95, 0.3, 1.0)    # veneno do ferrão (Reo)

## Tamanho da vespa em relação ao desenho-base (que tem ~85 px de altura)
const WASP_SCALE: float = 1.0

## Acima de jogadores e bola (que usam z_index = y como profundidade)
const FX_Z: int = 3000


## Cria uma vespa flutuando ao lado do jogador
## purple = a vespa do Reo (roxa); sem isso, a amarela do Bachira
static func attach_wasp(player: Node2D, purple: bool = false) -> Node2D:
	if player == null or not player.is_inside_tree(): return null
	var wasp := Wasp.new()
	wasp.purple = purple
	player.add_child(wasp)
	return wasp


## As garras roxas que rasgam a bola quando o Reo chuta (o Model: Panther).
## start_pos = de onde a vespa sai (ela avança dali até a bola, e as garras abrem no chute)
static func claws(from: Node, ball: Ball, start_pos: Vector2 = Vector2.INF) -> void:
	if from == null or not from.is_inside_tree() or ball == null: return
	var t := ClawTrail.new()
	t.target = ball
	t.start_pos = start_pos
	var scene := from.get_tree().current_scene
	scene.add_child(t)


## Nome antigo (o reo.gd chamava a pantera): agora são as garras
static func panther(from: Node, ball: Ball, start_pos: Vector2 = Vector2.INF) -> void:
	claws(from, ball, start_pos)


# =====================================================================================
# A VESPA
# =====================================================================================

class Wasp extends Node2D:
	var purple: bool = false
	var _time: float = randf() * 10.0

	func _ready() -> void:
		z_index = 5   # relativo ao jogador: fica por cima dele

	## 0..1: a "ferroada", um bote rápido para fora a cada ~2.2 s
	func _lunge() -> float:
		var ph: float = fposmod(_time, 2.2)
		return sin(ph / 0.26 * PI) if ph < 0.26 else 0.0

	func _process(delta: float) -> void:
		_time += delta
		# Paira ao lado do jogador (o do Reo na esquerda e o do Bachira na direita), inquieta, e dá botes
		var side: float = -1.0 if purple else 1.0
		var lunge: float = _lunge()
		var jitter := Vector2(sin(_time * 37.0), cos(_time * 43.0)) * 1.1
		position = Vector2(side * (52.0 + lunge * 14.0) + cos(_time * 1.8) * 6.0,
			-44.0 + sin(_time * 2.9) * 7.0 - lunge * 4.0) + jitter
		rotation = side * (0.14 + lunge * 0.32) + sin(_time * 3.1) * 0.05   # inclinada, pronta para atacar
		queue_redraw()

	func _draw() -> void:
		var s: float = CopyBeeFX.WASP_SCALE
		var lunge: float = _lunge()
		var pulse: float = 0.5 + 0.5 * sin(_time * 9.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))

		var body: Color = CopyBeeFX.PURPLE if purple else CopyBeeFX.YELLOW
		var stripe: Color = CopyBeeFX.PURPLE_DARK if purple else Color(0.07, 0.06, 0.05)
		var thorax: Color = Color(0.2, 0.06, 0.34) if purple else Color(0.24, 0.15, 0.05)
		var head_col: Color = Color(0.1, 0.03, 0.18) if purple else Color(0.08, 0.07, 0.07)
		var glow: Color = CopyBeeFX.EYE_VIOLET if purple else CopyBeeFX.EYE_RED
		var venom: Color = CopyBeeFX.VENOM_PURPLE if purple else CopyBeeFX.VENOM
		var ink := Color(0.04, 0.03, 0.05, 0.95)

		# Brilho ameaçador atrás dela (mais forte na ferroada)
		draw_circle(Vector2(0.0, 6.0), 48.0, Color(glow, 0.05 + 0.04 * pulse + 0.1 * lunge))

		# Asas afiadas, batendo muito rápido; as de baixo menores, em contrafase
		var flap: float = sin(_time * 52.0) * 0.26
		_wing(54.0, 14.0, -0.95 + flap, false)
		_wing(54.0, 14.0, -0.95 + flap, true)
		_wing(34.0, 9.0, -0.1 - flap, false)
		_wing(34.0, 9.0, -0.1 - flap, true)

		# Seis patas com ganchos, esticadas para agarrar (mais ainda na ferroada)
		for side in [1.0, -1.0]:
			for i in 3:
				var sway: float = sin(_time * 4.4 + float(i) * 1.3) * 2.0
				var hip := Vector2(side * 8.0, 3.0 + float(i) * 4.5)
				var knee := Vector2(side * (23.0 + float(i) * 2.0), 8.0 + float(i) * 5.0 - lunge * 6.0)
				var foot := Vector2(side * (21.0 - float(i) * 4.0) + sway, 28.0 + float(i) * 4.0 - lunge * 10.0)
				draw_polyline(PackedVector2Array([hip, knee, foot]), ink, 2.4, true)
				draw_line(foot, foot + Vector2(side * 3.5, 5.0), ink, 2.2)   # o gancho
				draw_line(foot, foot + Vector2(-side * 1.5, 5.5), ink, 1.4)

		# Abdômen: gota comprida e listrada que balança, terminando em ponta e no ferrão
		var swing: float = sin(_time * 3.6) * 0.09 - lunge * 0.3 * (-1.0 if purple else 1.0)
		draw_set_transform(Vector2(0.0, 8.0), swing, Vector2(s, s))
		var c := Vector2(0.0, 25.0)
		var cuts: Array[float] = [-1.0, -0.55, -0.1, 0.35, 0.7, 1.0]
		for i in cuts.size() - 1:
			_band(c, 13.0, 27.0, cuts[i] * 27.0, cuts[i + 1] * 27.0, body if i % 2 == 0 else stripe)
		draw_polyline(_closed(_ellipse(c, 13.0, 27.0)), ink, 1.6, true)
		draw_colored_polygon(PackedVector2Array([Vector2(-7, 49), Vector2(7, 49), Vector2(0, 66)]), stripe)   # ponta
		draw_polyline(PackedVector2Array([Vector2(-7, 49), Vector2(0, 66), Vector2(7, 49)]), ink, 1.4, true)
		draw_colored_polygon(PackedVector2Array([Vector2(-2.4, 64), Vector2(2.4, 64), Vector2(3.6, 76), Vector2(0.8, 86)]), ink)   # ferrão
		draw_circle(Vector2(0.8, 88.0 + pulse * 2.0), 2.0 + pulse * 1.3, Color(venom, 0.95))   # gota de veneno
		draw_circle(Vector2(0.8, 88.0 + pulse * 2.0), 5.0 + pulse * 2.0, Color(venom, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))

		# Tórax peludo, com pelos eriçados como espinhos
		draw_colored_polygon(_ellipse(Vector2(0, 2), 14.0, 13.0), thorax)
		draw_polyline(_closed(_ellipse(Vector2(0, 2), 14.0, 13.0)), ink, 1.6, true)
		for k in 14:
			var a: float = TAU * float(k) / 14.0 + 0.2
			var p0 := Vector2(0, 2) + Vector2(cos(a) * 13.0, sin(a) * 12.0)
			draw_line(p0, p0 + Vector2(cos(a), sin(a)) * (6.0 if k % 2 == 0 else 4.0), Color(ink, 0.9), 1.5)

		# Cabeça angular (bochechas largas e queixo pontudo)
		var head := PackedVector2Array([Vector2(-15, -22), Vector2(-9, -31), Vector2(9, -31), Vector2(15, -22),
			Vector2(12, -12), Vector2(5, -6), Vector2(-5, -6), Vector2(-12, -12)])
		draw_colored_polygon(head, head_col)
		draw_polyline(_closed(head), ink, 1.7, true)
		draw_colored_polygon(PackedVector2Array([Vector2(-5, -14), Vector2(5, -14), Vector2(3, -8), Vector2(-3, -8)]), body)   # placa do rosto

		var open: float = 0.35 * (0.5 + 0.5 * sin(_time * 7.0)) + lunge * 0.6   # as mandíbulas estalam; abrem na ferroada
		for sgn in [1.0, -1.0]:
			# Olho estreito e inclinado (cantos de dentro mais baixos: cara de brava), brilhando
			var eye := PackedVector2Array([Vector2(sgn * 3.5, -17), Vector2(sgn * 6.0, -24), Vector2(sgn * 14.0, -28),
				Vector2(sgn * 15.5, -21), Vector2(sgn * 9.0, -14.5)])
			draw_colored_polygon(eye, Color(glow, 0.95))
			draw_colored_polygon(PackedVector2Array([Vector2(sgn * 5.5, -18), Vector2(sgn * 8.0, -23), Vector2(sgn * 13.0, -25.5),
				Vector2(sgn * 13.0, -22), Vector2(sgn * 9.0, -17.5)]), Color(1.0, 0.95, 0.85, 0.85))   # miolo quente
			draw_line(Vector2(sgn * 9.5, -27.5), Vector2(sgn * 9.5, -16.0), Color(0.02, 0.0, 0.03), 1.8)   # pupila em fenda
			draw_polyline(_closed(eye), ink, 1.6, true)
			# sobrancelha pesada e baixa
			draw_line(Vector2(sgn * 1.0, -20.0), Vector2(sgn * 17.0, -31.5), ink, 3.4)
			# mandíbula grande e afiada, com dente na ponta
			var spread: float = 1.0 + open
			var mand := PackedVector2Array([Vector2(sgn * 3.0, -9.0), Vector2(sgn * 7.0 * spread, -2.0),
				Vector2(sgn * 10.5 * spread, 5.0), Vector2(sgn * 8.0, 11.0)])
			draw_polyline(mand, ink, 5.2, true)
			draw_polyline(mand, body.darkened(0.15), 2.6, true)
			draw_colored_polygon(PackedVector2Array([mand[2], mand[3], mand[3] + Vector2(sgn * -2.0, 4.0)]), ink)   # a ponta
			# antena inquieta, dobrada para a frente
			var tw: float = sin(_time * 12.0 + sgn) * 2.0
			var ant := PackedVector2Array([Vector2(sgn * 4.0, -30.0), Vector2(sgn * 11.0, -41.0 + tw), Vector2(sgn * 21.0, -46.0), Vector2(sgn * 25.0, -39.0 - tw)])
			draw_polyline(ant, ink, 1.9, true)

		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## Uma asa em forma de folha, com nervuras; "base" é o ângulo (para a direita); mirror = a asa esquerda
	func _wing(length: float, width: float, base: float, mirror: bool) -> void:
		var pts := PackedVector2Array()
		var n: int = 10
		for i in range(n + 1):
			var t: float = float(i) / float(n)
			pts.append(Vector2(length * t, -width * pow(maxf(sin(PI * pow(t, 0.7)), 0.0), 0.9)))   # mais pontuda na ponta
		for i in range(n - 1, 0, -1):
			var t: float = float(i) / float(n)
			pts.append(Vector2(length * t, width * 0.4 * sin(PI * t)))
		var origin := Vector2(5.0, -4.0)
		var poly := PackedVector2Array()
		for p in pts:
			var q: Vector2 = p.rotated(base)
			if mirror:
				q.x = -q.x
			poly.append(Vector2(origin.x * (-1.0 if mirror else 1.0), origin.y) + q)
		draw_colored_polygon(poly, Color(0.85, 0.9, 1.0, 0.26))
		draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0.04, 0.04, 0.07, 0.95), 1.6, true)
		# nervuras
		for v in [Vector2(0.95, -0.1), Vector2(0.78, -0.55), Vector2(0.55, 0.15)]:
			var tip := Vector2(length * v.x, width * v.y).rotated(base)
			if mirror:
				tip.x = -tip.x
			var o := Vector2(origin.x * (-1.0 if mirror else 1.0), origin.y)
			draw_line(o, o + tip, Color(0.04, 0.04, 0.07, 0.7), 1.1)

	## Uma faixa horizontal da elipse (y0..y1, em relação ao centro): as listras do abdômen
	func _band(c: Vector2, rx: float, ry: float, y0: float, y1: float, color: Color) -> void:
		var pts := PackedVector2Array()
		var steps: int = 6
		for i in range(steps + 1):
			var y: float = lerpf(y0, y1, float(i) / float(steps))
			pts.append(c + Vector2(rx * sqrt(maxf(1.0 - pow(y / ry, 2.0), 0.0)), y))
		for i in range(steps, -1, -1):
			var y: float = lerpf(y0, y1, float(i) / float(steps))
			pts.append(c + Vector2(-rx * sqrt(maxf(1.0 - pow(y / ry, 2.0), 0.0)), y))
		draw_colored_polygon(pts, color)

	func _closed(pts: PackedVector2Array) -> PackedVector2Array:
		return pts + PackedVector2Array([pts[0]])

	func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 24:
			var a: float = TAU * float(i) / 24.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		return pts


# =====================================================================================
# AS GARRAS
# =====================================================================================

## Três arranhões diagonais roxos (como as garras do Chigiri): a "fenda" escura, o corte roxo e um brilho claro.
## Abre rápido, fica um instante e some. "size" aumenta tudo (1 = normal).
class ClawSlash extends Node2D:
	var dir: Vector2 = Vector2.RIGHT
	var size: float = 1.0
	var life: float = 0.5
	var _t: float = 0.0

	func _init(d: Vector2, s: float = 1.0, seconds: float = 0.5) -> void:
		dir = d.normalized() if d.length() > 0.01 else Vector2.RIGHT
		size = s
		life = seconds
		top_level = true   # a posição é a do campo (definida antes de entrar na cena)
		z_as_relative = false
		z_index = CopyBeeFX.FX_Z

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var u: float = _t / life
		var grow: float = 1.0 - pow(1.0 - clampf(u / 0.3, 0.0, 1.0), 3.0)   # o corte abre rápido e desacelera
		var fade: float = 1.0 - clampf((u - 0.45) / 0.55, 0.0, 1.0)
		if grow < 0.06:
			return
		var along: Vector2 = dir.rotated(-0.8)   # arranhões na diagonal
		var across: Vector2 = along.orthogonal()
		for i in 3:
			var c: float = float(i) - 1.0
			var length: float = (74.0 - absf(c) * 14.0) * size   # o do meio é o mais comprido
			var off: Vector2 = across * c * 17.0 * size
			var a: Vector2 = off - along * length * 0.5
			var b: Vector2 = a + along * length * grow
			var bend: Vector2 = across * c * 5.0 * size          # leve curva, como unha arrastando
			var mid: Vector2 = a.lerp(b, 0.5) + bend
			var w: float = 7.5 * size * (1.0 - absf(c) * 0.2)
			var rift := PackedVector2Array([a + across * w * 0.7, mid + across * w, b, mid - across * w, a - across * w * 0.7])
			draw_colored_polygon(rift, Color(CopyBeeFX.PURPLE_DARK, 0.92 * fade))
			var cut := PackedVector2Array([a + across * w * 0.35, mid + across * w * 0.55, b, mid - across * w * 0.55, a - across * w * 0.35])
			draw_colored_polygon(cut, Color(CopyBeeFX.PURPLE, 0.95 * fade))
			draw_line(a.lerp(b, 0.12), a.lerp(b, 0.85) + bend * 0.4, Color(CopyBeeFX.PURPLE_LIGHT, 0.9 * fade), 1.6 * size, true)   # brilho do corte
		# Lascas roxas voando em volta
		for dot in [Vector2(-34.0, 20.0), Vector2(30.0, -24.0), Vector2(-24.0, -30.0), Vector2(38.0, 16.0)]:
			draw_circle(dot.rotated(dir.angle()) * size * (0.6 + grow * 0.6), 2.6 * size, Color(CopyBeeFX.PURPLE_LIGHT, 0.7 * fade))


## Acompanha a bola do chute: a vespa avança até ela (um risco roxo), as garras abrem em "X" no chute e,
## enquanto a bola voa, novas garras vão arranhando o caminho. Termina quando alguém toca na bola ou o tempo acaba.
class ClawTrail extends Node2D:
	var target: Ball
	var start_pos: Vector2 = Vector2.INF
	var life: float = 1.4
	var interval: float = 0.14
	var _t: float = 0.0
	var _acc: float = 0.0
	var _touches: int = 0

	func _ready() -> void:
		top_level = true   # o risco da vespa é desenhado em posições do campo
		z_as_relative = false
		z_index = CopyBeeFX.FX_Z
		if not is_instance_valid(target):
			queue_free()
			return
		_touches = target.interaction_count   # o chute do Panther já foi contado
		var v: Vector2 = target.velocity
		var d: Vector2 = v.normalized() if v.length() > 10.0 else Vector2.RIGHT
		# O "X": duas garras cruzadas bem na bola
		for rot in [0.0, 1.6]:
			_spawn(d.rotated(rot), 1.5, 0.55, target.global_position)

	func _process(delta: float) -> void:
		if not is_instance_valid(target) or _t >= life or target.interaction_count != _touches:
			queue_free()   # os arranhões que já foram soltos terminam sozinhos
			return
		_t += delta
		_acc += delta
		var v: Vector2 = target.velocity
		if _acc >= interval and v.length() > 40.0:
			_acc = 0.0
			var d: Vector2 = v.normalized()
			_spawn(d.rotated(randf_range(-0.4, 0.4)), 0.7, 0.4, target.global_position + d.orthogonal() * randf_range(-16.0, 16.0))
		if _t < 0.22:
			queue_redraw()

	## Solta um arranhão no campo (adiciona no próximo quadro: o pai ainda pode estar ocupado montando filhos)
	func _spawn(d: Vector2, size: float, seconds: float, pos: Vector2) -> void:
		var slash := ClawSlash.new(d, size, seconds)
		slash.position = pos
		get_parent().add_child.call_deferred(slash)

	## O risco da vespa indo até a bola (afina e some)
	func _draw() -> void:
		if start_pos == Vector2.INF or not is_instance_valid(target) or _t >= 0.22:
			return
		var k: float = _t / 0.22
		var head: Vector2 = start_pos.lerp(target.global_position, minf(k * 1.6, 1.0))
		var tail: Vector2 = start_pos.lerp(head, k)
		var a: float = 1.0 - k
		draw_line(tail, head, Color(CopyBeeFX.PURPLE_DARK, 0.9 * a), 11.0, true)
		draw_line(tail, head, Color(CopyBeeFX.PURPLE_LIGHT, 0.9 * a), 4.0, true)
