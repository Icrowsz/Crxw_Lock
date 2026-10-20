class_name AikuFX
extends RefCounted
## Efeitos visuais do Aiku: uma COBRA VERDE que se enrola em volta dele e da bola e dá o bote. Tudo por código.
##
## A cobra se move como uma cobra de verdade: só a CABEÇA segue um caminho (bote em S, ondulação, espiral de enrolar)
## e o corpo vai atrás, passando exatamente por onde a cabeça passou (rastro). Por isso ela serpenteia, se enrola e
## dá o bote sem animação pronta. Línguinha, olhos de fenda e escamas no corpo.
##
##  - strike(): a cobra recua em S e dá o bote de um ponto a outro (Snake Lunge, Burglar Radar...)
##  - slither(): a cobra serpenteia por um caminho (Serpent Slip, Venom Deflect, passes...)
##  - wrap(): a cobra se enrola em volta de alguém/da bola e desenrola (preparação, deflect, cabeceio)
##  - bind(): a cobra ENROLADA no inimigo enquanto o bloqueio dura (Snake Lunge, Ultimate Defense); release() solta
##  - mark(): cobrinha armada no ombro do inimigo marcado (Blooming Halt); pop() faz ela estourar
##  - radar(): a área do Burglar Radar: um RADAR (varredura, anéis, pings) com uma cobra translúcida devorando o próprio corpo, girando
##  - burst(): escamas verdes explodindo num ponto
##
## Quem chama passa um nó que já esteja na árvore em "from" (ex: o próprio Aiku).

const GREEN := Color(0.30, 0.74, 0.24)
const GREEN_LIGHT := Color(0.68, 0.95, 0.38)
const GREEN_DEEP := Color(0.07, 0.28, 0.11)
const EYE := Color(1.0, 0.88, 0.2)
const TONGUE := Color(0.9, 0.15, 0.25)

const _KEY_TEX := &"aiku_scale_tex"
const _KEY_PICK := &"aiku_scale_pick"
const _KEY_FADE := &"aiku_scale_fade"


# ---------- RECURSOS COMPARTILHADOS (escamas das partículas) ----------

## Uma escama (losango), branca, 32x32
static func scale_texture() -> ImageTexture:
	if Engine.has_meta(_KEY_TEX):
		return Engine.get_meta(_KEY_TEX) as ImageTexture
	var poly := PackedVector2Array([Vector2(16.0, 2.0), Vector2(28.0, 16.0), Vector2(16.0, 30.0), Vector2(4.0, 16.0)])
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var hits: int = 0
			for sy in 3:   # 3x3 amostras por pixel: borda suave
				for sx in 3:
					if Geometry2D.is_point_in_polygon(Vector2(float(x) + (float(sx) + 0.5) / 3.0, float(y) + (float(sy) + 0.5) / 3.0), poly):
						hits += 1
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, float(hits) / 9.0))
	var tex := ImageTexture.create_from_image(img)
	Engine.set_meta(_KEY_TEX, tex)
	return tex


## Cada escama nasce verde escura OU verde clara (sorteio: degrau no meio do degradê)
static func _pick_ramp() -> Gradient:
	if Engine.has_meta(_KEY_PICK):
		return Engine.get_meta(_KEY_PICK) as Gradient
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.5])
	g.colors = PackedColorArray([GREEN_DEEP, GREEN_LIGHT])
	Engine.set_meta(_KEY_PICK, g)
	return g


static func _fade_ramp() -> Gradient:
	if Engine.has_meta(_KEY_FADE):
		return Engine.get_meta(_KEY_FADE) as Gradient
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	Engine.set_meta(_KEY_FADE, g)
	return g


static func _ok(from: Node) -> bool:
	return from != null and from.is_inside_tree()


## Explosão de escamas em volta de um ponto do campo. strong = mais escamas, maiores e mais longe.
static func burst(from: Node, pos: Vector2, amount: int = 12, strong: bool = false) -> void:
	if not _ok(from):
		return
	var speed: float = 170.0 if strong else 120.0
	var p := CPUParticles2D.new()
	p.texture = scale_texture()
	p.color_initial_ramp = _pick_ramp()
	p.color_ramp = _fade_ramp()
	p.amount = amount
	p.lifetime = 0.7 if strong else 0.55
	p.local_coords = false
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.0
	p.damping_max = speed * 1.4
	p.gravity = Vector2(0.0, 30.0)
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -220.0
	p.angular_velocity_max = 220.0
	p.scale_amount_min = 0.4 if strong else 0.3
	p.scale_amount_max = 0.8 if strong else 0.6
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0 if strong else 8.0
	p.z_index = 3000   # acima de tudo (jogadores e bola usam z_index = y como profundidade)
	p.z_as_relative = false
	var tree: SceneTree = from.get_tree()
	var scene: Node = tree.current_scene
	(scene if scene != null else from).add_child(p)
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = true
	tree.create_timer(p.lifetime + 0.4).timeout.connect(p.queue_free)


# ---------- CAMINHOS DA CABEÇA ----------
## Cada um devolve a posição GLOBAL da cabeça no instante t. Vector2.INF = o nó seguido sumiu (a cobra se desfaz).

static func _smooth(k: float) -> float:
	var c: float = clampf(k, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


static func _center(node: Node2D) -> Vector2:
	var h = node.get("height")
	return node.global_position + Vector2(0.0, -(float(h) if h != null else 0.0))


static func _radius_of(node: Node2D) -> float:
	var r = node.get("placeholder_radius")
	return float(r) if r != null else 18.0


## Bote: recua em S (a cobra "arma"), dispara até b e fica balançando perto dele
static func _p_strike(t: float, a: Vector2, b: Vector2, life: float) -> Vector2:
	var u: float = clampf(t / life, 0.0, 1.0)
	var d: Vector2 = b - a
	var length: float = maxf(d.length(), 1.0)
	var dir: Vector2 = d / length
	var nrm: Vector2 = dir.orthogonal()
	var wind: Vector2 = a - dir * minf(length * 0.25, 40.0)
	if u < 0.4:
		var k: float = u / 0.4
		return a.lerp(wind, _smooth(k)) + nrm * sin(k * TAU * 1.5) * minf(length * 0.12, 16.0) * (1.0 - k * 0.5)
	if u < 0.58:
		var k2: float = (u - 0.4) / 0.18
		return wind.lerp(b, 1.0 - pow(1.0 - k2, 3.0)) + nrm * sin(k2 * PI) * minf(length * 0.05, 8.0)
	var k3: float = (u - 0.58) / 0.42
	return b + nrm * sin(k3 * TAU * 2.0) * minf(length * 0.05, 8.0) * (1.0 - k3) - dir * 8.0 * k3


## Ondulação de a até b: anda em linha reta com a cabeça "remando" de um lado para o outro
static func _p_slither(t: float, a: Vector2, b: Vector2, life: float, amp: float, waves: float) -> Vector2:
	var u: float = clampf(t / life, 0.0, 1.0)
	var nrm: Vector2 = (b - a).orthogonal().normalized()
	return a.lerp(b, _smooth(u)) + nrm * amp * sin(u * waves * TAU) * sin(PI * u)


## Enrola em espiral em volta do nó (r0 -> r1) com algumas voltas e levanta a cabeça no fim
static func _p_coil(t: float, node: Node2D, r0: float, r1: float, turns: float, life: float, lift: float) -> Vector2:
	if not is_instance_valid(node):
		return Vector2.INF
	var u: float = clampf(t / life, 0.0, 1.0)
	var ang: float = TAU * turns * _smooth(u * 1.1) - 1.2
	var r: float = lerpf(r0, r1, _smooth(u * 1.3))
	return _center(node) + Vector2(cos(ang) * r, sin(ang) * r * 0.55 - lift * _smooth((u - 0.6) / 0.4))


## Fica dando voltas em volta do nó, apertando e afrouxando (cobra enrolada na vítima)
static func _p_orbit(t: float, node: Node2D, radius: float, speed: float, lift: float) -> Vector2:
	if not is_instance_valid(node):
		return Vector2.INF
	var ang: float = t * speed * 2.0
	var r: float = radius * (1.0 + 0.08 * sin(t * 3.0))
	return _center(node) + Vector2(cos(ang) * r, sin(ang) * r * 0.55 - lift * (0.5 + 0.5 * sin(t * 0.9)))


# ---------- EFEITOS ----------

static func _spawn(from: Node, path: Callable, life: float, segments: int, spacing: float, head_w: float) -> Snake:
	if not _ok(from):
		return null
	var s := Snake.new()
	s.path = path
	s.life = life
	s.segments = segments
	s.spacing = spacing
	s.head_w = head_w
	s.tail_w = maxf(1.5, head_w * 0.25)
	var scene: Node = from.get_tree().current_scene
	(scene if scene != null else from).add_child(s)
	return s


## A cobra recua em S e dá o bote de "a" até "b"
static func strike(from: Node, a: Vector2, b: Vector2, life: float = 0.65) -> Snake:
	return _spawn(from, _p_strike.bind(a, b, life), life, 22, 5.5, 8.0)


## A cobra serpenteia de "a" até "b"
static func slither(from: Node, a: Vector2, b: Vector2, life: float = 0.7) -> Snake:
	var amp: float = clampf(a.distance_to(b) * 0.12, 8.0, 26.0)
	return _spawn(from, _p_slither.bind(a, b, life, amp, 2.5), life, 24, 5.5, 8.0)


## A cobra se enrola em volta de "around" (o Aiku, um inimigo ou a bola) e se desfaz em "life" segundos
static func wrap(around: Node2D, life: float = 0.9, radius: float = 26.0) -> Snake:
	return _spawn(around, _p_coil.bind(around, radius * 1.7, radius, 2.2, life, radius * 0.6), life, 26, 5.0, 7.0)


## Cobra enrolada no inimigo por tempo indeterminado: solte com release()
static func bind(target: Node2D) -> Snake:
	var r: float = _radius_of(target)
	return _spawn(target, _p_orbit.bind(target, r * 1.15, 1.2, r * 0.6), 0.0, 34, 5.0, 7.0)


## Cobrinha armada no ombro do inimigo marcado (Blooming Halt): solte com pop() ou release()
static func mark(target: Node2D) -> Snake:
	var r: float = _radius_of(target)
	return _spawn(target, _p_orbit.bind(target, r * 0.55, 2.2, r * 1.1), 0.0, 14, 3.6, 5.0)


## A marca estoura: escamas e a cobrinha se desfaz
static func pop(snake: Snake, from: Node, pos: Vector2) -> void:
	burst(from, pos, 16, true)
	release(snake)


static func release(snake: Snake) -> void:
	if snake != null and is_instance_valid(snake):
		snake.release()


## A área do Burglar Radar: uma cobra devorando o próprio corpo, girando em volta de "center"
static func radar(from: Node, center: Vector2, radius: float) -> Radar:
	if not _ok(from):
		return null
	var r := Radar.new()
	r.center = center
	r.radius = radius
	var scene: Node = from.get_tree().current_scene
	(scene if scene != null else from).add_child(r)
	return r


# ---------- NÓS ----------

## A cobra: só a cabeça segue "path"; o corpo passa por onde a cabeça passou. life <= 0 = fica até release().
class Snake extends Node2D:
	var path: Callable
	var life: float = 1.0
	var segments: int = 22
	var spacing: float = 5.5
	var head_w: float = 8.0
	var tail_w: float = 2.0
	var _t: float = 0.0
	var _alpha: float = 0.0
	var _closing: bool = false
	var _close_t: float = 0.0
	var _head: Vector2 = Vector2.ZERO
	var _trail: PackedVector2Array = PackedVector2Array()

	func _ready() -> void:
		top_level = true            # desenha em coordenadas globais
		global_position = Vector2.ZERO
		z_index = 3000
		z_as_relative = false
		var start: Vector2 = path.call(0.0)
		_head = start if start != Vector2.INF else Vector2.ZERO
		_trail.append(_head)

	func release() -> void:
		_closing = true

	func _process(delta: float) -> void:
		_t += delta
		if life > 0.0 and _t >= life:
			_closing = true
		if _closing:
			_close_t += delta
			_alpha = maxf(0.0, 1.0 - _close_t / 0.3)
			if _alpha <= 0.0:
				queue_free()
				return
		else:
			_alpha = minf(_alpha + delta / 0.12, 1.0)
		var p: Vector2 = path.call(_t)
		if p == Vector2.INF:   # o nó que ela seguia sumiu
			_closing = true
		else:
			_head = p
			if _head.distance_to(_trail[_trail.size() - 1]) > 1.2:
				_trail.append(_head)
				if _trail.size() > 160:
					_trail = _trail.slice(_trail.size() - 160)
		queue_redraw()

	## Posições dos anéis do corpo: andam para trás ao longo do rastro, a cada "spacing" px
	func _body_points() -> PackedVector2Array:
		var pts := PackedVector2Array()
		pts.append(_head)
		var prev: Vector2 = _head
		var acc: float = 0.0
		var i: int = _trail.size() - 1
		while pts.size() <= segments and i >= 0:
			var q: Vector2 = _trail[i]
			var d: float = prev.distance_to(q)
			if d < 0.0001:
				i -= 1
				continue
			if acc + d >= spacing:
				var cut: Vector2 = prev.lerp(q, (spacing - acc) / d)
				pts.append(cut)
				prev = cut
				acc = 0.0
				continue
			acc += d
			prev = q
			i -= 1
		while pts.size() <= segments:   # rastro ainda curto: o resto fica enrolado na ponta do rabo
			pts.append(pts[pts.size() - 1])
		return pts

	func _draw() -> void:
		if _alpha <= 0.01:
			return
		var pts: PackedVector2Array = _body_points()
		var n: int = pts.size()
		# contorno escuro
		for i in range(n - 1, 0, -1):
			var w: float = lerpf(head_w, tail_w, float(i) / float(n - 1)) + 2.4
			draw_line(pts[i], pts[i - 1], Color(AikuFX.GREEN_DEEP, _alpha), w)
			draw_circle(pts[i], w * 0.5, Color(AikuFX.GREEN_DEEP, _alpha))
		# corpo com faixas de escamas
		for i in range(n - 1, 0, -1):
			var w2: float = lerpf(head_w, tail_w, float(i) / float(n - 1))
			var col: Color = AikuFX.GREEN.lerp(AikuFX.GREEN_DEEP, 0.3 + 0.3 * sin(float(i) * 0.9))
			col.a = _alpha
			draw_line(pts[i], pts[i - 1], col, w2)
			draw_circle(pts[i], w2 * 0.5, col)
			if i % 3 == 0:
				draw_circle(pts[i], w2 * 0.22, Color(AikuFX.GREEN_LIGHT, _alpha * 0.8))
		_draw_head(pts)

	func _draw_head(pts: PackedVector2Array) -> void:
		var dir: Vector2 = pts[0] - pts[mini(2, pts.size() - 1)]
		dir = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
		var side: Vector2 = dir.orthogonal()
		var hl: float = head_w * 1.25
		var hw: float = head_w * 0.85
		var poly := PackedVector2Array()
		for k in 12:
			var ang: float = TAU * float(k) / 12.0
			var along: float = cos(ang) * hl * (1.0 if cos(ang) > 0.0 else 0.8)
			poly.append(pts[0] + dir * along + side * sin(ang) * hw)
		draw_colored_polygon(poly, Color(AikuFX.GREEN, _alpha))
		var outline := poly.duplicate()
		outline.append(poly[0])
		draw_polyline(outline, Color(AikuFX.GREEN_DEEP, _alpha), 1.6)
		for s in [-1.0, 1.0]:   # olhos de fenda
			var e: Vector2 = pts[0] + dir * hl * 0.25 + side * float(s) * hw * 0.55
			draw_circle(e, head_w * 0.26, Color(AikuFX.EYE, _alpha))
			draw_line(e - dir * head_w * 0.2, e + dir * head_w * 0.2, Color(AikuFX.GREEN_DEEP, _alpha), 1.3)
		if fposmod(_t, 0.8) < 0.25:   # língua bifurcada
			var tip: Vector2 = pts[0] + dir * hl
			var tongue_end: Vector2 = tip + dir * head_w * 1.1
			draw_line(tip, tongue_end, Color(AikuFX.TONGUE, _alpha), 1.4)
			draw_line(tongue_end, tongue_end + (dir + side * 0.6).normalized() * head_w * 0.5, Color(AikuFX.TONGUE, _alpha), 1.3)
			draw_line(tongue_end, tongue_end + (dir - side * 0.6).normalized() * head_w * 0.5, Color(AikuFX.TONGUE, _alpha), 1.3)


## A área do Burglar Radar: um RADAR de verdade (varredura girando com rastro, anéis, mira em cruz, marcas na borda
## e pings que se expandem) com uma serpente TRANSLÚCIDA e simples devorando o próprio rabo, girando em volta.
## Redesenha 30x por segundo.
class Radar extends Node2D:
	const SEGMENTS: int = 48
	const SLICES: int = 26
	var center: Vector2 = Vector2.ZERO
	var radius: float = 350.0
	var _t: float = 0.0
	var _acc: float = 0.0
	var _alpha: float = 0.0
	var _closing: bool = false

	func _ready() -> void:
		top_level = true
		global_position = center
		z_index = 0              # no chão: os jogadores (z_index = y) ficam por cima dela
		z_as_relative = false

	func release() -> void:
		_closing = true

	func _process(delta: float) -> void:
		_t += delta
		_acc += delta
		if _closing:
			_alpha -= delta / 0.4
			if _alpha <= 0.0:
				queue_free()
				return
		else:
			_alpha = minf(_alpha + delta / 0.5, 1.0)
		if _acc >= 0.033:
			_acc = 0.0
			queue_redraw()

	func _draw() -> void:
		var a: float = clampf(_alpha, 0.0, 1.0)
		var g: Color = AikuFX.GREEN
		var l: Color = AikuFX.GREEN_LIGHT

		# Tela do radar: miolo, anéis, mira em cruz e marcas na borda
		draw_circle(Vector2.ZERO, radius, Color(g, 0.05 * a))
		for f in [0.33, 0.66]:
			draw_arc(Vector2.ZERO, radius * float(f), 0.0, TAU, 64, Color(l, 0.13 * a), 1.0)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(g, 0.32 * a), 1.5)   # limite exato do alcance
		for i in 4:
			var d: Vector2 = Vector2.from_angle(PI * 0.5 * float(i))
			draw_line(d * radius * 0.06, d * radius, Color(l, 0.10 * a), 1.0)
		for i in 36:
			var d2: Vector2 = Vector2.from_angle(TAU * float(i) / 36.0)
			var tick: float = 10.0 if i % 3 == 0 else 5.0
			draw_line(d2 * (radius - tick), d2 * radius, Color(l, 0.25 * a), 1.0)

		# Pings: ondas que saem do centro e somem ao chegar na borda
		for k in 2:
			var u: float = fposmod(_t * 0.5 + float(k) * 0.5, 1.0)
			draw_arc(Vector2.ZERO, radius * u, 0.0, TAU, 64, Color(l, 0.28 * a * (1.0 - u)), 2.0)

		# Varredura: o feixe gira e deixa um rastro que vai apagando atrás dele
		var sweep: float = _t * 1.5
		var span: float = 1.1
		for s in SLICES:
			var a1: float = sweep - span * float(s) / float(SLICES)
			var a2: float = sweep - span * float(s + 1) / float(SLICES)
			var fade: float = 1.0 - float(s) / float(SLICES)
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a1) * radius,
				Vector2.from_angle(a2) * radius]), Color(l, 0.20 * a * fade * fade))
		draw_line(Vector2.ZERO, Vector2.from_angle(sweep) * radius, Color(l, 0.7 * a), 2.0)
		draw_circle(Vector2.ZERO, 3.5, Color(l, 0.8 * a))

		_draw_snake(a)

	## A serpente: simples e translúcida (só o corpo em quatro faixas que afinam no rabo e uma cabeça lisa)
	func _draw_snake(a: float) -> void:
		var ring_r: float = radius - 16.0
		var head_ang: float = _t * 0.5                    # a cabeça gira; o corpo vem atrás
		var body_span: float = TAU - 0.55                 # sobra um vão entre a boca e a ponta do rabo
		var pts := PackedVector2Array()
		for k in SEGMENTS + 1:
			pts.append(Vector2.from_angle(head_ang - body_span * float(k) / float(SEGMENTS)) * ring_r)
		var body := Color(AikuFX.GREEN, 0.30 * a)
		var bands: int = 4
		var widths: Array[float] = [16.0, 15.0, 11.0, 5.0]
		for b in bands:
			var from_i: int = b * SEGMENTS / bands
			var to_i: int = (b + 1) * SEGMENTS / bands
			draw_polyline(pts.slice(from_i, to_i + 1), body, widths[b], true)
		# Cabeça lisa, com a boca aberta para o rabo
		var dir: Vector2 = Vector2(-sin(head_ang), cos(head_ang))
		var side: Vector2 = dir.orthogonal()
		var head := PackedVector2Array()
		for k in 12:
			var t: float = TAU * float(k) / 12.0
			head.append(pts[0] + dir * cos(t) * 18.0 + side * sin(t) * 13.0)
		draw_colored_polygon(head, Color(AikuFX.GREEN, 0.36 * a))
		var jaw: Vector2 = pts[0] + dir * 18.0
		var jaw_col := Color(AikuFX.GREEN, 0.34 * a)
		draw_line(jaw, jaw + (dir + side * 0.55).normalized() * 15.0, jaw_col, 3.0)
		draw_line(jaw, jaw + (dir - side * 0.55).normalized() * 15.0, jaw_col, 3.0)
