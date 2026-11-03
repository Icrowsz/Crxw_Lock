class_name MarionetteFX
extends RefCounted
## Efeitos da Reação Química MARIONETTE (Rin + Aryu), todos desenhados por código (nenhuma imagem):
##  - begin_hand():   a MÃO DE MARIONETISTA do Puppets (mesmo estilo do rin_fx.gd), bem maior e mais detalhada, sobre o Aryu;
##  - arm_hand():     o passe chegou (reação armada): a mão fica sobre o Aryu esperando o cabeceio;
##  - finish():       o movimento do Aryu acabou: a mão some (também some sozinha se a reação perder o sentido);
##  - header_kick():  a bola do Marionette Header é acompanhada das ESTRELINHAS do Aryu misturadas com FIOS do Rin.
##
## Leve (veja "Desempenho" do prompt):
##  - a mão é UM nó, redesenhado 20x por segundo só enquanto ela existe (como a do rin_fx.gd);
##  - o rastro da bola é UM nó com lista pequena e limitada (28 pontos, 16 estrelas) e 3 polilinhas por quadro;
##  - todo efeito tem limite de tempo e sai sozinho se a partida acaba, o turno muda ou alguém toca na bola.

const TEAL := Color(0.176, 0.661, 0.569)          # verde-água do Rin
const TEAL_LIGHT := Color(0.314, 0.909, 0.625)
const TEAL_DEEP := Color(0.08, 0.30, 0.30)         # igual ao rin_fx.gd
const BLACK := Color(0.015, 0.05, 0.05)
const BROWN := Color(0.55, 0.33, 0.15)             # marrom do Aryu

## Acima de jogadores e bola (que usam z_index = y como profundidade)
const FX_Z: int = 2990

const META_HAND := &"marionette_hand"


# ---------- ESTILO DO CHUTE ----------

## Aura do cabeceio: fio verde-água do Rin + partículas brancas do Aryu
static func kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = TEAL
	fx.additive = false
	fx.trail_width = 10.0
	fx.shape = KickFX.Shape.SQUARE
	fx.particle_color = Color(1.0, 1.0, 1.0)
	fx.amount = 24
	fx.lifetime = 0.7
	fx.speed_min = 15.0
	fx.speed_max = 80.0
	fx.gravity = Vector2(0.0, -50.0)
	fx.spin = 240.0
	fx.swirl = 140.0
	fx.scale_min = 0.15
	fx.scale_max = 0.35
	fx.burst_amount = 16
	fx.burst_speed = 240.0
	return fx


static func _add(from: Node, n: Node) -> void:
	var scene: Node = from.get_tree().current_scene
	(scene if scene != null else from).add_child(n)


static func _hand_of(aryu: Node) -> Hand:
	if not aryu.has_meta(META_HAND):
		return null
	var v: Variant = aryu.get_meta(META_HAND)
	return v as Hand if is_instance_valid(v) else null


# ---------- MÃO DE MARIONETISTA ----------

## O Puppets (reação) começou: a mão grande aparece sobre o Aryu (no lugar da mão normal do Rin)
static func begin_hand(aryu: Player, size: float) -> void:
	if aryu == null or not aryu.is_inside_tree():
		return
	end_hand(aryu)
	var h := Hand.new()
	h.target = aryu
	h.size = size
	_add(aryu, h)
	aryu.set_meta(META_HAND, h)


## O passe chegou e a reação ficou armada: a mão agora vale até o fim do movimento do Aryu
static func arm_hand(aryu: Player) -> void:
	var h := _hand_of(aryu)
	if h != null:
		h.arm()


## A mão some (QTE errado, cancelado...)
static func end_hand(aryu: Player) -> void:
	var h := _hand_of(aryu)
	if h != null:
		h.fade()


## O movimento do Aryu acabou (ou a reação foi cancelada): apaga o preparo e a mão
static func finish(aryu: Player) -> void:
	if aryu == null or not is_instance_valid(aryu):
		return
	if aryu.has_meta(ReactionMarionette.META_SETUP):
		aryu.remove_meta(ReactionMarionette.META_SETUP)
	if aryu.has_meta(ReactionMarionette.META_HOLD):
		aryu.remove_meta(ReactionMarionette.META_HOLD)
	end_hand(aryu)


# ---------- RASTRO DA BOLA ----------

## Chamado logo depois do ball.kick() do cabeceio: estrelinhas do Aryu e fios do Rin acompanham a bola
static func header_kick(aryu: Player, ball: Ball) -> void:
	if aryu == null or not aryu.is_inside_tree() or ball == null or not is_instance_valid(ball):
		return
	var t := BallTrail.new()
	t.setup(ball, Aryu._make_star_texture())   # a mesma estrelinha branca de 5 pontas do Aryu
	_add(aryu, t)


## A mão de marionetista grande, no estilo da do Rin (rin_fx.gd: PuppetHand), só que maior e mais detalhada: manga com
## punho e dobras, palma com marca e linhas, cinco dedos de três juntas segurando a cruzeta, cruzeta com argolas e 7 fios
## verde-água (cabeça, ombros, mãos e pés do Aryu) com brilho e contas de luz correndo. Segue o Aryu (salto, avanço),
## balança e mexe os dedos. Redesenha 20x por segundo (só enquanto existe).
class Hand extends Node2D:
	const MAX_AGE: float = 120.0       # limite de segurança (s)
	const PENDING_MAX: float = 60.0    # sem armar nesse tempo (QTE errado, ação cancelada...): some
	const FADE_TIME: float = 0.35

	var target: Player
	var size: float = 2.0              # tamanho (multiplica o desenho)
	var _armed: bool = false
	var _fading: bool = false
	var _grow: float = 0.0             # 0 -> 1 enquanto a mão cresce
	var _drop: float = 0.0             # altura da cruzeta (origem deste nó) acima do centro do Aryu (px)
	var _radius: float = 18.0
	var _age: float = 0.0
	var _poll: float = 0.0
	var _redraw: float = 0.0
	var _pop: Tween

	func _init() -> void:
		top_level = true
		z_index = MarionetteFX.FX_Z
		z_as_relative = false
		modulate.a = 0.0

	func _ready() -> void:
		_radius = target.placeholder_radius
		_drop = _radius + 52.0 * size
		_follow()
		_pop = create_tween().set_parallel(true)
		_pop.tween_property(self, "modulate:a", 1.0, 0.3)
		_pop.tween_method(_set_grow, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _set_grow(v: float) -> void:
		_grow = v
		queue_redraw()

	func arm() -> void:
		_armed = true

	func fade() -> void:
		if _fading:
			return
		_fading = true
		if _pop != null and _pop.is_valid():
			_pop.kill()
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, FADE_TIME)
		tw.tween_callback(queue_free)

	## Centro do Aryu (com a altura do salto) no mundo
	func _center() -> Vector2:
		return target.global_position + Vector2(0.0, -target.height)

	## A mão paira sobre o Aryu e balança como a do Puppets do Rin
	func _follow() -> void:
		global_position = _center() + Vector2(sin(_age * 1.7) * 6.0, -(_drop + sin(_age * 2.3) * 4.0))

	func _process(delta: float) -> void:
		_age += delta
		if not is_instance_valid(target) or _age >= MAX_AGE:
			queue_free()
			return
		_follow()
		_redraw += delta
		if _redraw >= 0.05:   # 20 quadros por segundo bastam para os dedos e os fios
			_redraw = 0.0
			queue_redraw()
		_poll += delta
		if _poll >= 0.25 and not _fading:   # confere ~4x por segundo (não todo quadro)
			_poll = 0.0
			_check()

	## A mão só vale enquanto a reação vale
	func _check() -> void:
		var m: MatchManager = target._get_manager()
		if m == null or m.match_over:
			fade()
			return
		if not _armed:
			if _age > PENDING_MAX:
				fade()
			return
		var waiting: bool = target.has_meta(ReactionMarionette.META_SETUP)
		if not waiting and not target.has_meta(ReactionMarionette.META_HOLD):
			fade()   # o preparo expirou ou o movimento acabou
			return
		if waiting:   # esperando o cabeceio: se a bola caiu ou alguém tocou nela, a reação acabou
			var ball: Ball = target._get_ball()
			var info: Dictionary = target.get_meta(ReactionMarionette.META_SETUP) as Dictionary
			if ball == null or not ball.hovering or ball.interaction_count != int(info.get("touches", -1)):
				fade()

	## Polígono preto com contorno verde-água (o estilo do rin_fx.gd)
	func _shape(pts: PackedVector2Array, fill: Color = MarionetteFX.BLACK, line: Color = MarionetteFX.TEAL, w: float = 1.5) -> void:
		draw_colored_polygon(pts, fill)
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, line, w)

	func _draw() -> void:
		var s: float = size * lerpf(0.3, 1.0, _grow)
		var teal: Color = MarionetteFX.TEAL
		var light: Color = MarionetteFX.TEAL_LIGHT
		var deep: Color = MarionetteFX.TEAL_DEEP
		var black: Color = MarionetteFX.BLACK
		var lw: float = 1.4 + 0.2 * s   # espessura dos contornos

		# brilho suave em volta da mão
		draw_circle(Vector2(0.0, -16.0 * s), 40.0 * s, Color(teal, 0.07))
		draw_circle(Vector2(0.0, -16.0 * s), 26.0 * s, Color(teal, 0.09))

		# manga (sobe para fora da tela) com dobras e punho
		_shape(PackedVector2Array([Vector2(-9.0, -92.0) * s, Vector2(9.0, -92.0) * s, Vector2(13.0, -32.0) * s, Vector2(-13.0, -32.0) * s]), black, teal, lw)
		draw_line(Vector2(-4.0, -80.0) * s, Vector2(-6.0, -42.0) * s, Color(teal, 0.35), lw * 0.8)
		draw_line(Vector2(4.0, -84.0) * s, Vector2(6.0, -44.0) * s, Color(teal, 0.35), lw * 0.8)
		_shape(PackedVector2Array([Vector2(-14.0, -36.0) * s, Vector2(14.0, -36.0) * s, Vector2(14.5, -28.0) * s, Vector2(-14.5, -28.0) * s]), deep, teal, lw)
		draw_line(Vector2(-14.0, -32.0) * s, Vector2(14.0, -32.0) * s, Color(light, 0.55), lw * 0.7)

		# palma (octógono) com marca no centro e linhas
		_shape(PackedVector2Array([Vector2(-12.0, -28.0) * s, Vector2(12.0, -28.0) * s, Vector2(15.0, -23.0) * s,
			Vector2(14.0, -12.0) * s, Vector2(-14.0, -12.0) * s, Vector2(-15.0, -23.0) * s]), black, teal, lw)
		var gem := Vector2(0.0, -20.0) * s
		draw_colored_polygon(PackedVector2Array([gem + Vector2(0.0, -4.0) * s, gem + Vector2(3.0, 0.0) * s,
			gem + Vector2(0.0, 4.0) * s, gem + Vector2(-3.0, 0.0) * s]), Color(light, 0.85))
		draw_polyline(PackedVector2Array([Vector2(-10.0, -17.0) * s, Vector2(-6.0, -15.5) * s, Vector2(-3.0, -16.5) * s]), Color(teal, 0.5), lw * 0.8)
		draw_polyline(PackedVector2Array([Vector2(10.0, -17.0) * s, Vector2(6.0, -15.5) * s, Vector2(3.0, -16.5) * s]), Color(teal, 0.5), lw * 0.8)

		# cruzeta (com argolas onde os fios prendem)
		var ends: Array[float] = [-24.0, -16.0, -8.0, 0.0, 8.0, 16.0, 24.0]
		draw_rect(Rect2(-28.0 * s, -2.0 * s, 56.0 * s, 6.0 * s), black)
		draw_rect(Rect2(-28.0 * s, -2.0 * s, 56.0 * s, 6.0 * s), teal, false, lw)
		for cap_x in [-28.0, 28.0]:
			draw_circle(Vector2(cap_x * s, 1.0 * s), 4.4 * s, black)
			draw_arc(Vector2(cap_x * s, 1.0 * s), 4.4 * s, 0.0, TAU, 14, teal, lw)
		for ex in ends:
			draw_circle(Vector2(ex * s, 4.0 * s), 1.7 * s, Color(light, 0.95))
			draw_line(Vector2(ex * s, 0.0), Vector2(ex * s, 3.0 * s), Color(teal, 0.6), lw * 0.7)

		# dedos: 3 juntas cada, o polegar mais curto e aberto; mexem de leve (como no Puppets do Rin)
		for i in 5:
			var x: float = -10.4 + float(i) * 5.2
			var wig: float = sin(_age * 7.0 + float(i)) * 1.5
			var p0: Vector2 = Vector2(x, -12.0)
			var p1: Vector2 = Vector2(x * 1.10, -7.0)
			var p2: Vector2 = Vector2(x * 1.06, -2.5)
			var p3: Vector2 = Vector2(x * 1.04 + wig, 1.5)
			var fw: float = 5.4
			if i == 0:   # polegar
				p0 = Vector2(-13.0, -15.0)
				p1 = Vector2(-17.0, -9.5)
				p2 = Vector2(-15.0, -4.0)
				p3 = Vector2(-11.5 + wig, 0.5)
				fw = 5.8
			var seg: Array[Vector2] = [p0 * s, p1 * s, p2 * s, p3 * s]
			for k in 3:   # contorno verde-água grosso, depois o miolo preto (igual ao rin_fx.gd)
				draw_line(seg[k], seg[k + 1], teal, (fw + 2.4) * s * 0.5 + 1.0)
			for k in 3:
				draw_line(seg[k], seg[k + 1], black, fw * s * 0.5)
			for k in 4:   # juntas
				draw_circle(seg[k], fw * s * 0.27, black)
				draw_arc(seg[k], fw * s * 0.27, 0.0, TAU, 8, Color(teal, 0.8), lw * 0.7)
			draw_circle(seg[3] + Vector2(0.0, -0.4 * s), 0.9 * s, Color(light, 0.9))   # brilho na ponta

		# fios: da cruzeta até a cabeça, os ombros, as mãos e os pés do Aryu (as pontas ficam presas no corpo dele)
		var c: Vector2 = _center() - global_position   # centro do Aryu no sistema deste nó
		var r: float = _radius
		var offs: Array[Vector2] = [
			Vector2(-r * 1.1, 0.0), Vector2(-r * 0.65, -r * 0.45), Vector2(-r * 0.5, r * 0.8), Vector2(0.0, -r),
			Vector2(r * 0.5, r * 0.8), Vector2(r * 0.65, -r * 0.45), Vector2(r * 1.1, 0.0)]
		var tw: float = 1.3 + 0.3 * size
		for i in 7:
			var a: Vector2 = Vector2(ends[i] * s, 4.0 * s)
			var wobble: float = sin(_age * 7.0 + float(i) * 1.3) * 2.5   # a mão "puxa" os fios
			var b: Vector2 = c + offs[i] + Vector2(wobble, 0.0)
			var ctrl: Vector2 = (a + b) * 0.5 + Vector2(sin(_age * 3.0 + float(i)) * 4.0, 0.0)
			var pts := PackedVector2Array()
			for k in 9:
				var t: float = float(k) / 8.0
				pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
			draw_polyline(pts, Color(teal, 0.18), tw * 3.0)   # brilho
			draw_polyline(pts, Color(teal, 0.9), tw)
			draw_circle(b, 2.6, Color(teal, 0.35))   # a ponta presa no Aryu, com halo
			draw_circle(b, 1.7, Color(light, 0.95))
			var bt: float = fposmod(_age * 0.9 + float(i) * 0.37, 1.0)   # conta de luz correndo pelo fio
			var bead: Vector2 = a.lerp(ctrl, bt).lerp(ctrl.lerp(b, bt), bt)
			draw_circle(bead, 1.9, Color(light, 0.9))


## Fios do Rin (verde-água) enrolados em volta da trajetória da bola + estrelinhas brancas do Aryu
class BallTrail extends Node2D:
	const MAX_POINTS: int = 28
	const MIN_STEP: float = 7.0
	const MAX_STARS: int = 16
	const MAX_AGE: float = 3.0         # limite de segurança (s)
	const FADE_TIME: float = 0.35

	var ball: Ball
	var _tex: Texture2D
	var _touches: int = 0
	var _pts := PackedVector2Array()
	var _stars: Array[Dictionary] = []   # {pos, vel, age, life, rot, size}
	var _age: float = 0.0
	var _emit: float = 0.0
	var _fade: float = 1.0
	var _ending: bool = false

	func _init() -> void:
		top_level = true
		z_index = MarionetteFX.FX_Z - 1
		z_as_relative = false

	func setup(b: Ball, tex: Texture2D) -> void:
		ball = b
		_tex = tex
		_touches = b.interaction_count   # o toque do próprio chute já conta; outro toque encerra o rastro

	func _process(delta: float) -> void:
		_age += delta
		if not is_instance_valid(ball) or _age >= MAX_AGE:
			queue_free()
			return
		# alguém tocou na bola ou ela parou no chão: o rastro começa a sumir
		if not _ending and (ball.interaction_count != _touches \
				or (_age > 0.4 and ball.is_on_ground() and ball.velocity.length() < 30.0)):
			_ending = true
		if _ending:
			_fade -= delta / FADE_TIME
		else:
			var head: Vector2 = ball.sprite.global_position if ball.sprite != null else ball.global_position
			if _pts.is_empty() or _pts[_pts.size() - 1].distance_to(head) >= MIN_STEP:
				_pts.append(head)
				if _pts.size() > MAX_POINTS:
					_pts.remove_at(0)
			_emit += delta
			if _emit >= 0.04 and _stars.size() < MAX_STARS:   # uma estrelinha nova a cada 0,04 s
				_emit = 0.0
				_stars.append({"pos": head + Vector2(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0)),
					"vel": Vector2(randf_range(-30.0, 30.0), randf_range(-60.0, -10.0)), "age": 0.0,
					"life": randf_range(0.5, 0.9), "rot": randf() * TAU, "size": randf_range(0.5, 0.9)})
		for i in range(_stars.size() - 1, -1, -1):   # envelhece as estrelas (de trás para a frente: dá para remover)
			var st: Dictionary = _stars[i]
			st["age"] = float(st["age"]) + delta
			st["pos"] = (st["pos"] as Vector2) + (st["vel"] as Vector2) * delta
			if float(st["age"]) >= float(st["life"]):
				_stars.remove_at(i)
		if _ending and _fade <= 0.0 and _stars.is_empty():
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var n: int = _pts.size()
		var fade: float = maxf(_fade, 0.0)
		if n >= 2:
			for k in 3:   # 3 fios que se enrolam ao longo da trajetória (a ponta, perto da bola, é a mais forte)
				var line := PackedVector2Array()
				var cols := PackedColorArray()
				for i in n:
					var u: float = float(i) / float(n - 1)   # 0 = cauda, 1 = bola
					var side: Vector2 = (_pts[mini(i + 1, n - 1)] - _pts[maxi(i - 1, 0)]).normalized().orthogonal()
					var off: float = sin(float(i) * 0.7 + float(Time.get_ticks_msec()) * 0.012 + float(k) * 2.1) * (8.0 * (1.0 - u) + 1.5)
					line.append(_pts[i] + side * off)
					cols.append(Color(MarionetteFX.TEAL_LIGHT, 0.9 * u * fade))
				draw_polyline_colors(line, cols, 1.8)
		for st: Dictionary in _stars:
			var k: float = 1.0 - float(st["age"]) / float(st["life"])
			draw_set_transform(st["pos"] as Vector2, float(st["rot"]) + float(st["age"]) * 3.0, Vector2.ONE * float(st["size"]) * k)
			draw_texture(_tex, -_tex.get_size() * 0.5, Color(1.0, 1.0, 1.0, k * fade))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
