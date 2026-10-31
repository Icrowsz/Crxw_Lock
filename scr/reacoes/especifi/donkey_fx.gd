class_name DonkeyFX
extends RefCounted
## Efeitos da Reação Química DONKEY (Barou + Isagi), todos desenhados por código (nenhuma imagem):
##  - kick_fx():         o estilo do chute Twisted Path (bola negra com partículas vermelhas, maior que a do Devour);
##  - on_territory():    peças de quebra-cabeça BRILHANTES giram em volta do Isagi enquanto a dupla está pronta;
##  - trail_point():     os dashes do Chop King deixam um RASTRO NEGRO com raios vermelhos longos, que fica até o chute;
##  - chop_done():       o Chop King acabou: sem Nutmeg = o rastro some; com Nutmeg = ele espera o Twisted Path;
##  - twisted_impact():  no chute: raios negros e vermelhos saem da bola e do rastro, e as peças se soltam.
##
## Leve (veja "Desempenho" do prompt):
##  - o rastro é UM nó (duas Line2D com no máximo 60 pontos + até 12 raios redesenhados ~11x por segundo);
##  - as peças usam as malhas em cache do OrbitalFX.draw_piece (nada de triangular polígono por quadro);
##  - todo efeito tem limite de tempo e sai sozinho se a partida acaba, o turno muda ou o Nutmeg deixa de valer.

const RED := Color(0.86, 0.03, 0.05)
const DEEP_RED := Color(0.55, 0.0, 0.03)
const BLACK := Color(0.04, 0.0, 0.02)
const PIECE_BLUE := Color(0.55, 0.82, 1.0)

## Acima de jogadores e bola (que usam z_index = y como profundidade)
const FX_Z: int = 2990
## O rastro fica no CHÃO: acima do campo (-4096) e das peças do Pieces (-4000), mas atrás do Barou e de todo mundo
const TRAIL_Z: int = -3990

const META_TRAIL := &"donkey_trail"
const META_ORBIT := &"donkey_orbit"


# ---------- ESTILO DO CHUTE ----------

static func kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = Color(0.1, 0.0, 0.03)
	fx.trail_width = 34.0
	fx.particle_color = RED
	fx.amount = 64
	fx.lifetime = 0.8
	fx.speed_min = 60.0
	fx.speed_max = 200.0
	fx.gravity = Vector2.ZERO
	fx.spin = 420.0
	fx.scale_min = 0.25
	fx.scale_max = 0.6
	fx.burst_amount = 48
	fx.burst_speed = 460.0
	return fx


static func _ok(from: Node) -> bool:
	return from != null and from.is_inside_tree()


static func _add(from: Node, n: Node) -> void:
	var scene: Node = from.get_tree().current_scene
	(scene if scene != null else from).add_child(n)


## O nó guardado no meta (ou null se não existe / já foi liberado)
static func _meta_node(from: Node, key: StringName) -> Node:
	if not from.has_meta(key):
		return null
	var v: Variant = from.get_meta(key)
	return v as Node if is_instance_valid(v) else null


# ---------- RASTRO DO CHOP KING ----------

## O dash vai usar o rastro negro? (preparação da reação pronta e fora de recarga). Chame UMA vez por dash.
static func wants_trail(barou: Player) -> bool:
	return ReactionDonkey.setup_ready(barou)


## Chame a cada quadro do dash (só se wants_trail()): acrescenta um ponto ao rastro negro
static func trail_point(barou: Player, pos: Vector2) -> void:
	if not _ok(barou):
		return
	var t := _meta_node(barou, META_TRAIL) as Trail
	if t == null or t.is_over():
		t = Trail.new()
		t.barou = barou as Barou
		_add(barou, t)
		barou.set_meta(META_TRAIL, t)
	t.add(pos)


## O Chop King acabou. Com o Nutmeg liberado o rastro espera o Twisted Path; sem ele, some.
static func chop_done(barou: Player, nutmeg_ready: bool) -> void:
	var t := _meta_node(barou, META_TRAIL) as Trail
	if t == null:
		return
	if nutmeg_ready:
		t.arm()
	else:
		t.fade_out()


# ---------- PEÇAS EM VOLTA DO ISAGI ----------

## O Isagi acabou de usar o Territory: cria (se ainda não existe) as peças que giram nele. Elas só APARECEM
## enquanto a dupla estiver pronta (Predator Eye do Barou ativo + reação fora de recarga) e somem sozinhas
## quando o Territory acaba.
static func on_territory(isagi: Player) -> void:
	if not _ok(isagi) or _meta_node(isagi, META_ORBIT) != null:
		return
	var o := Orbit.new()
	o.isagi = isagi as Isagi
	isagi.add_child(o)
	isagi.set_meta(META_ORBIT, o)


# ---------- IMPACTO DO TWISTED PATH ----------

## Chamado pelo kick_ball() logo depois que a bola sai: o rastro se solta em raios, as peças do Isagi se
## espalham e raios negros e vermelhos saem do ponto do chute.
static func twisted_impact(barou: Player, partner: Player, ball: Ball, dir: Vector2) -> void:
	if not _ok(barou) or ball == null or not is_instance_valid(ball):
		return
	var pos: Vector2 = ball.sprite.global_position if ball.sprite != null else ball.global_position
	var t := _meta_node(barou, META_TRAIL) as Trail
	if t != null:
		t.release()
	if partner != null and is_instance_valid(partner):
		var o := _meta_node(partner, META_ORBIT) as Orbit
		if o != null:
			o.release()
	var imp := Impact.new()
	imp.dir = dir
	_add(barou, imp)
	imp.global_position = pos
	BarouFX.burst(barou, pos, 26, true)          # partículas de raio (vermelhas e pretas)
	BarouFX.shock(barou, pos, 150.0, 0.45)       # ondas de choque maiores que as do chute normal
	BarouFX.shock(barou, pos, 95.0, 0.3)


# ---------- NÓS DOS EFEITOS ----------

## Raios em zig-zag: pontos RELATIVOS ao início, indo na direção "dir" por "length" px
static func _make_bolt(origin: Vector2, dir: Vector2, length: float, steps: int = 6, wobble: float = 0.7) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cur: Vector2 = origin
	pts.append(cur)
	for _s in steps:
		cur += dir.rotated(randf_range(-wobble, wobble)) * (length / float(steps))
		pts.append(cur)
	return pts


## Rastro negro dos dashes. Fica no campo (top_level) até o Twisted Path acontecer.
class Trail extends Node2D:
	const MAX_POINTS: int = 60
	const MIN_STEP: float = 8.0       # só ganha ponto novo depois de andar isto (poucos pontos)
	const MAX_BOLTS: int = 24
	const MAX_BOLT_ALPHA: float = 0.7   # opacidade dos raios junto ao Barou (a cauda é mais transparente)
	const MAX_AGE: float = 60.0       # limite de segurança (s)
	const RELEASE_TIME: float = 0.55

	var barou: Barou
	var _state: int = 0               # 0 = dashes em andamento, 1 = esperando o Twisted Path, 2 = se desfazendo
	var _disperse: bool = false       # true = os raios voam para fora (chute); false = só some
	var _age: float = 0.0
	var _regen_acc: float = 0.0
	var _poll_acc: float = 0.0
	var _rel_t: float = 0.0
	var _glow: Line2D
	var _core: Line2D
	var _bolts: Array[PackedVector2Array] = []
	var _bolt_alpha: Array[float] = []   # opacidade de cada raio (maior perto do Barou)

	func _init() -> void:
		top_level = true   # os pontos são posições do campo
		z_index = DonkeyFX.TRAIL_Z   # na camada de baixo, atrás do Barou
		z_as_relative = false
		var taper := Curve.new()   # a cauda é fina e a ponta (onde o Barou está) é grossa
		taper.add_point(Vector2(0.0, 0.1))
		taper.add_point(Vector2(1.0, 1.0))
		_glow = _make_line(30.0, Color(DonkeyFX.DEEP_RED, 0.55), taper)
		_core = _make_line(17.0, DonkeyFX.BLACK, taper)
		add_child(_glow)
		add_child(_core)

	func _make_line(w: float, c: Color, taper: Curve) -> Line2D:
		var l := Line2D.new()
		l.width = w
		l.default_color = c
		l.width_curve = taper
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		l.begin_cap_mode = Line2D.LINE_CAP_ROUND
		l.end_cap_mode = Line2D.LINE_CAP_ROUND
		return l

	func is_over() -> bool:
		return _state == 2

	func add(pos: Vector2) -> void:
		if _state != 0:
			return
		var n: int = _core.get_point_count()
		if n > 0 and _core.get_point_position(n - 1).distance_to(pos) < MIN_STEP:
			return
		_glow.add_point(pos)
		_core.add_point(pos)
		if _core.get_point_count() > MAX_POINTS:
			_glow.remove_point(0)
			_core.remove_point(0)

	## Terminou o Chop King com o Nutmeg liberado: o rastro espera o chute da reação
	func arm() -> void:
		if _state == 0:
			_state = 1

	## O chute aconteceu: os raios se soltam do rastro e voam para fora
	func release() -> void:
		if _state == 2:
			return
		_state = 2
		_disperse = true
		_rel_t = 0.0
		var pts: PackedVector2Array = _core.points
		if pts.size() > 0:   # 3 estouros de raios ao longo do rastro (início, meio e fim)
			for i in 3:
				BarouFX.burst(self, pts[int(float(i) * float(pts.size() - 1) / 2.0)], 8, true)
		queue_redraw()

	## O rastro some (sem Nutmeg, turno acabou, partida reiniciou...)
	func fade_out() -> void:
		if _state == 2:
			return
		_state = 2
		_disperse = false
		_rel_t = 0.0

	## Raios longos saindo para os lados de alguns pontos do rastro (refeitos ~11x por segundo: piscam)
	func _regen() -> void:
		_bolts.clear()
		_bolt_alpha.clear()
		var pts: PackedVector2Array = _core.points
		var n: int = pts.size()
		if n < 2:
			return
		for _i in mini(MAX_BOLTS, n):
			var idx: int = randi() % n
			var tangent: Vector2 = (pts[mini(idx + 1, n - 1)] - pts[maxi(idx - 1, 0)]).normalized()
			var side: Vector2 = tangent.orthogonal() * (1.0 if randf() < 0.5 else -1.0)
			var dir: Vector2 = (side + tangent * randf_range(-0.6, 0.6)).normalized()
			_bolts.append(DonkeyFX._make_bolt(pts[idx], dir, randf_range(70.0, 160.0)))
			# o fim da lista é onde o Barou está: perto dele o raio é mais opaco, na cauda quase some
			_bolt_alpha.append(MAX_BOLT_ALPHA * lerpf(0.2, 1.0, float(idx) / float(n - 1)))
		queue_redraw()

	func _process(delta: float) -> void:
		_age += delta
		if _age >= MAX_AGE or not is_instance_valid(barou):
			queue_free()
			return
		if _state == 2:
			_rel_t += delta
			if _rel_t >= RELEASE_TIME:
				queue_free()
				return
			modulate.a = 1.0 - _rel_t / RELEASE_TIME
			queue_redraw()
			return
		# Partida acabou ou virou o turno: o rastro não vale mais
		var m: MatchManager = barou._get_manager()
		if m == null or m.match_over or m.current_team != barou.team:
			fade_out()
			return
		_regen_acc += delta
		if _regen_acc >= 0.09:
			_regen_acc = 0.0
			_regen()
		if _state == 1:   # esperando o chute: se o Nutmeg deixou de valer (bola saiu do alcance, turno...), some
			_poll_acc += delta
			if _poll_acc >= 0.2:
				_poll_acc = 0.0
				if not barou.has_free_followup():
					fade_out()

	func _draw() -> void:
		var k: float = clampf(_rel_t / RELEASE_TIME, 0.0, 1.0) if _state == 2 and _disperse else 0.0
		for i in _bolts.size():
			var pts: PackedVector2Array = _bolts[i]
			var a: float = _bolt_alpha[i]
			var line: PackedVector2Array = pts
			if k > 0.0:   # chute: o raio estica para fora (copia só durante o fim do efeito)
				line = PackedVector2Array()
				var o: Vector2 = pts[0]
				for p: Vector2 in pts:
					line.append(o + (p - o) * (1.0 + k * 1.8))
			draw_polyline(line, Color(DonkeyFX.BLACK, a), 5.0)
			draw_polyline(line, Color(DonkeyFX.RED, a), 2.4)


## Peças de quebra-cabeça brilhantes girando em volta do Isagi. Filho dele: acompanha o salto.
class Orbit extends Node2D:
	const COUNT: int = 7
	const MAX_AGE: float = 90.0
	const RELEASE_TIME: float = 0.5

	var isagi: Isagi
	var _on: bool = false
	var _alpha: float = 0.0
	var _last_alpha: float = 0.0
	var _t: float = 0.0
	var _age: float = 0.0
	var _poll: float = 0.0
	var _released: bool = false
	var _rel_t: float = 0.0
	var _shapes: Array[int] = []
	var _phase: Array[float] = []

	func _init() -> void:
		z_index = DonkeyFX.FX_Z
		z_as_relative = false
		for i in COUNT:
			_shapes.append(randi() % 5)
			_phase.append(randf() * TAU)

	func release() -> void:
		_released = true
		_rel_t = 0.0

	func _process(delta: float) -> void:
		_age += delta
		_t += delta
		if _age >= MAX_AGE or not is_instance_valid(isagi):
			queue_free()
			return
		if _released:
			_rel_t += delta
			if _rel_t >= RELEASE_TIME:
				queue_free()
				return
		else:
			_poll += delta
			if _poll >= 0.2:   # confere ~5x por segundo (não todo quadro)
				_poll = 0.0
				if not ReactionDonkey.territory_alive(isagi):   # o Territory acabou (ou partida nova): as peças saem
					queue_free()
					return
				_on = ReactionDonkey.find_eye_barou(isagi) != null and ReactionDonkey.ready_for_team(isagi, isagi.team)
		_alpha = move_toward(_alpha, 1.0 if _on and not _released else 0.0, delta * 3.0)
		position = Vector2(0.0, -isagi.height)
		if _alpha > 0.0 or _last_alpha > 0.0:   # redesenha até sumir de vez (e só então para)
			queue_redraw()
		_last_alpha = _alpha

	func _draw() -> void:
		if _alpha <= 0.01:
			return
		var k: float = clampf(_rel_t / RELEASE_TIME, 0.0, 1.0) if _released else 0.0
		var a: float = _alpha * (1.0 - k)
		for i in COUNT:
			var ang: float = _t * 2.6 + TAU * float(i) / float(COUNT) + _phase[i] * 0.2
			var r: float = (46.0 + 9.0 * sin(_t * 3.0 + _phase[i])) * (0.5 + 0.5 * _alpha) * (1.0 + k * 1.6)
			var pos := Vector2(cos(ang) * r, sin(ang) * r * 0.5 - 6.0)   # órbita achatada (2.5D)
			var size: float = 15.0 + 4.0 * sin(_t * 4.0 + float(i))
			var rot: float = _t * 3.0 + _phase[i]
			# brilho: a mesma peça maior e translúcida por baixo, depois a peça clara
			OrbitalFX.draw_piece(self, _shapes[i], pos, rot, size * 1.7, Color(DonkeyFX.PIECE_BLUE, 0.22 * a), Color(DonkeyFX.PIECE_BLUE, 0.0))
			OrbitalFX.draw_piece(self, _shapes[i], pos, rot, size, Color(DonkeyFX.PIECE_BLUE, 0.95 * a), Color(1.0, 1.0, 1.0, a))


## O estouro do chute: raios negros e vermelhos saindo do ponto da bola (alguns na direção do chute)
class Impact extends Node2D:
	const LIFE: float = 0.6

	var dir: Vector2 = Vector2.RIGHT
	var _t: float = 0.0
	var _bolts: Array[PackedVector2Array] = []   # relativos ao centro, feitos uma vez

	func _ready() -> void:
		z_index = DonkeyFX.FX_Z + 1
		z_as_relative = false
		var base: float = dir.angle() if dir.length() > 0.01 else 0.0
		for i in 16:
			if i < 6:   # na direção do chute: mais longos
				_bolts.append(DonkeyFX._make_bolt(Vector2.ZERO, Vector2.from_angle(base + randf_range(-0.9, 0.9)), randf_range(160.0, 260.0), 7))
			else:
				_bolts.append(DonkeyFX._make_bolt(Vector2.ZERO, Vector2.from_angle(randf() * TAU), randf_range(80.0, 170.0)))

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k: float = clampf(_t / LIFE, 0.0, 1.0)
		var grow: float = 1.0 - pow(1.0 - k, 3.0)   # abre rápido e desacelera
		var a: float = 1.0 - k
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(grow, grow))
		for pts: PackedVector2Array in _bolts:
			draw_polyline(pts, Color(DonkeyFX.BLACK, 0.95 * a), 7.0)
			draw_polyline(pts, Color(DonkeyFX.RED, a), 3.0)
