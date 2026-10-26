class_name BarouFX
extends RefCounted
## Efeitos visuais do Barou: RAIOS vermelhos e pretos.
## Tudo por código (nenhuma imagem): o raio é desenhado uma única vez numa textura branca 24x64 e a
## cor vem da partícula (vermelho ou preto). Os efeitos "vivos" (aura, rastro, ligação) são nós
## pequenos que se apagam sozinhos.
##
## Leve, como o do Isagi:
##  - uma textura e dois degradês compartilhados (criados uma vez e guardados no Engine);
##  - um CPUParticles2D "one_shot" por efeito (poucas partículas, vida curta);
##  - a aura do Predator Eye só roda enquanto está ligada.
##
## O que cada coisa é:
##  - kick():        raios em volta da bola quando o Barou chuta (maior com o Predator Eye)
##  - begin_trail(): rastro vermelho com contorno preto dos dashes/avanços (siga o Barou com add())
##  - make_aura():   raios que saem do Barou durante o Predator Eye (ele fica bem em destaque)
##  - zap():         raio ligando dois pontos (agarrar um inimigo, Tyrant)
##  - burst()/line()/shock(): explosão de raios, raios ao longo de uma linha e onda de choque
##
## Quem chama passa um nó qualquer que já esteja na árvore (ex: o Barou) em "from".

const RED := Color(0.86, 0.03, 0.05)
const DEEP_RED := Color(0.55, 0.0, 0.03)
const BLACK := Color(0.04, 0.0, 0.02)

const _KEY_TEX := &"barou_bolt_tex"
const _KEY_PICK := &"barou_bolt_pick"
const _KEY_FADE := &"barou_bolt_fade"


# ---------- ESTILO DO CHUTE (aura + partículas do KickFX) ----------

## Vermelho com pedaços escuros. strong = a versão maior (Devour)
static func kick_fx(strong: bool = false) -> KickFX:
	var fx := KickFX.new()
	fx.color = RED if strong else Color(0.775, 0.038, 0.04, 1.0)
	fx.trail_width = 26.0 if strong else 16.0
	fx.particle_color = Color(0.05, 0.0, 0.0) if strong else Color(0.1, 0.1, 0.1)
	fx.amount = 48 if strong else 26
	fx.lifetime = 0.7 if strong else 0.5
	fx.speed_min = 50.0 if strong else 30.0
	fx.speed_max = 170.0 if strong else 110.0
	fx.gravity = Vector2.ZERO
	fx.spin = 360.0 if strong else 240.0
	fx.scale_min = 0.2 if strong else 0.15
	fx.scale_max = 0.5 if strong else 0.35
	fx.burst_amount = 36 if strong else 18
	fx.burst_speed = 380.0 if strong else 260.0
	return fx


# ---------- RECURSOS COMPARTILHADOS ----------

## O raio (zig-zag que afina na ponta), branco, 24x64, com a ponta para baixo
static func bolt_texture() -> ImageTexture:
	if Engine.has_meta(_KEY_TEX):
		return Engine.get_meta(_KEY_TEX) as ImageTexture
	var pts: Array[Vector2] = [Vector2(13, 2), Vector2(18, 17), Vector2(8, 29), Vector2(17, 43), Vector2(9, 62)]
	var img := Image.create(24, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 24:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var d: float = INF
			for i in pts.size() - 1:
				d = minf(d, _segment_distance(p, pts[i], pts[i + 1]))
			var half: float = lerpf(3.2, 0.9, p.y / 64.0)   # grosso em cima, fino na ponta
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf((half - d) / 1.2 + 0.5, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	Engine.set_meta(_KEY_TEX, tex)
	return tex


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Cada raio nasce vermelho (65%) OU preto (35%)
static func _pick_ramp() -> Gradient:
	if Engine.has_meta(_KEY_PICK):
		return Engine.get_meta(_KEY_PICK) as Gradient
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.65])
	g.colors = PackedColorArray([RED, BLACK])
	Engine.set_meta(_KEY_PICK, g)
	return g


static func _fade_ramp() -> Gradient:
	if Engine.has_meta(_KEY_FADE):
		return Engine.get_meta(_KEY_FADE) as Gradient
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	Engine.set_meta(_KEY_FADE, g)
	return g


static func _make(amount: int, lifetime: float, speed: float, size_min: float, size_max: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = bolt_texture()
	p.color_initial_ramp = _pick_ramp()
	p.color_ramp = _fade_ramp()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.3      # o raio dispara e desacelera
	p.damping_max = speed * 1.8
	p.gravity = Vector2.ZERO
	p.particle_flag_align_y = true   # a ponta do raio acompanha o sentido em que ele vai
	p.angle_min = 0.0
	p.angle_max = 0.0
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	p.z_index = 3000
	p.z_as_relative = false
	return p


static func _launch(from: Node, p: CPUParticles2D, pos: Vector2) -> void:
	var tree: SceneTree = from.get_tree()
	var scene: Node = tree.current_scene
	(scene if scene != null else from).add_child(p)
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = true
	tree.create_timer(p.lifetime + 0.4).timeout.connect(p.queue_free)


static func _ok(from: Node) -> bool:
	return from != null and from.is_inside_tree()


static func _add_node(from: Node, n: Node) -> void:
	var scene: Node = from.get_tree().current_scene
	(scene if scene != null else from).add_child(n)


# ---------- EFEITOS ----------

## Raios saindo para todos os lados de um ponto
static func burst(from: Node, pos: Vector2, amount: int = 10, strong: bool = false) -> void:
	if not _ok(from):
		return
	var p := _make(amount, 0.55 if strong else 0.45, 360.0 if strong else 260.0,
		0.6 if strong else 0.45, 1.1 if strong else 0.8)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 8.0
	_launch(from, p, pos)


## Chute: raios em volta da bola, mais alguns que seguem a direção do chute e uma onda de choque.
## strong = Predator Eye ativo (mais raios, maiores)
static func kick(from: Node, pos: Vector2, dir: Vector2, strong: bool = false) -> void:
	if not _ok(from):
		return
	burst(from, pos, 16 if strong else 10, strong)
	var f := _make(8 if strong else 5, 0.4, 520.0 if strong else 420.0, 0.7, 1.2)
	f.direction = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	f.spread = 28.0
	_launch(from, f, pos)
	shock(from, pos, 70.0 if strong else 48.0)


## Raios espalhados ao longo de uma linha (puxar a bola, avanço)
static func line(from: Node, a: Vector2, b: Vector2, amount: int = 10) -> void:
	if not _ok(from):
		return
	var p := _make(amount, 0.5, 120.0, 0.4, 0.7)
	var pts := PackedVector2Array()
	var samples: int = maxi(amount * 2, 4)
	for i in samples:
		pts.append((b - a) * (float(i) / float(samples - 1)))
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = pts
	_launch(from, p, a)


## Onda de choque: um anel preto com miolo vermelho que se abre e some
static func shock(from: Node, pos: Vector2, radius: float = 60.0, seconds: float = 0.3) -> void:
	if not _ok(from):
		return
	var s := Shock.new()
	s.radius = radius
	s.life = seconds
	_add_node(from, s)
	s.global_position = pos


## Raio ligando dois pontos do campo (agarrar um inimigo, Tyrant). Treme e some sozinho.
static func zap(from: Node, a: Vector2, b: Vector2, seconds: float = 0.35) -> void:
	if not _ok(from):
		return
	var z := Zap.new()
	z.a = a
	z.b = b
	z.life = seconds
	_add_node(from, z)


## Rastro do dash: vermelho com contorno preto. Chame add(posição) a cada quadro e finish() no fim.
static func begin_trail(from: Node) -> Trail:
	var t := Trail.new()
	if _ok(from):
		_add_node(from, t)
	return t


## Raios que saem do Barou durante o Predator Eye. Vira filho dele e começa DESLIGADA.
static func make_aura(radius: float = 17.0) -> Aura:
	var a := Aura.new()
	a.radius = radius
	a.active = false
	return a


# ---------- NÓS DOS EFEITOS ----------

class Trail extends Node2D:
	var _outline: Line2D
	var _core: Line2D
	var max_points: int = 36

	func _init() -> void:
		top_level = true   # os pontos são posições do campo
		z_index = 2990
		z_as_relative = false
		var taper := Curve.new()   # a cauda é fina e a ponta (onde o Barou está) é grossa
		taper.add_point(Vector2(0.0, 0.08))
		taper.add_point(Vector2(1.0, 1.0))
		_outline = _make_line(18.0, BLACK, taper)
		_core = _make_line(9.0, RED, taper)
		add_child(_outline)
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

	func add(pos: Vector2) -> void:
		var n: int = _core.get_point_count()
		if n > 0 and _core.get_point_position(n - 1).distance_to(pos) < 2.0:
			return
		_outline.add_point(pos)
		_core.add_point(pos)
		if _core.get_point_count() > max_points:
			_outline.remove_point(0)
			_core.remove_point(0)

	## O rastro some devagar
	func finish(seconds: float = 0.5) -> void:
		if not is_inside_tree():
			queue_free()
			return
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, seconds)
		tw.tween_callback(queue_free)


class Shock extends Node2D:
	var radius: float = 60.0
	var life: float = 0.3
	var _t: float = 0.0

	func _init() -> void:
		z_index = 2995
		z_as_relative = false

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k: float = clampf(_t / life, 0.0, 1.0)
		var r: float = radius * (1.0 - pow(1.0 - k, 3.0))   # abre rápido e desacelera
		var a: float = 1.0 - k
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(BLACK, a), 9.0 * (1.0 - k) + 2.0)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(RED, a), 4.5 * (1.0 - k) + 1.0)


class Zap extends Node2D:
	var a: Vector2 = Vector2.ZERO
	var b: Vector2 = Vector2.ZERO
	var life: float = 0.35
	var _t: float = 0.0
	var _acc: float = 0.0
	var _pts: PackedVector2Array = PackedVector2Array()

	func _init() -> void:
		top_level = true
		z_index = 2995
		z_as_relative = false

	func _ready() -> void:
		_regen()

	## Um raio novo (zig-zag diferente) umas 20 vezes por segundo: parece que pisca
	func _regen() -> void:
		_pts.clear()
		var d: Vector2 = b - a
		var perp: Vector2 = d.orthogonal().normalized()
		var n: int = 7
		for i in n + 1:
			var off: float = 0.0 if i == 0 or i == n else randf_range(-1.0, 1.0) * 16.0
			_pts.append(a + d * (float(i) / float(n)) + perp * off)
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		_acc += delta
		if _t >= life:
			queue_free()
			return
		if _acc >= 0.05:
			_acc = 0.0
			_regen()

	func _draw() -> void:
		var alpha: float = 1.0 - clampf(_t / life, 0.0, 1.0) * 0.8
		draw_polyline(_pts, Color(BLACK, alpha), 8.0, true)
		draw_polyline(_pts, Color(RED, alpha), 3.5, true)


## Aura do Predator Eye: halo vermelho pulsando + raios que piscam saindo do corpo
class Aura extends Node2D:
	var radius: float = 17.0   # raio-base: o halo e os raios ficam colados no corpo do Barou
	var bolt_count: int = 9
	var active: bool = false:
		set(value):
			active = value
			visible = value
			set_process(value)
			if value:
				_regen()
	var _bolts: Array[PackedVector2Array] = []
	var _acc: float = 0.0
	var _time: float = 0.0

	func _init() -> void:
		show_behind_parent = true   # atrás do Barou: ele fica em destaque no meio dos raios
		visible = false
		set_process(false)

	func _regen() -> void:
		_bolts.clear()
		var offset: float = randf() * TAU
		for i in bolt_count:
			var ang: float = offset + TAU * float(i) / float(bolt_count) + randf_range(-0.2, 0.2)
			var r0: float = radius * 0.8
			var r1: float = radius * randf_range(1.5, 2.1)   # a ponta do raio passa pouco da borda do corpo
			var pts := PackedVector2Array()
			var steps: int = 5
			for s in steps + 1:
				var r: float = lerpf(r0, r1, float(s) / float(steps))
				var wob: float = 0.0 if s == 0 else randf_range(-0.28, 0.28)   # zig-zag
				pts.append(Vector2(cos(ang + wob), sin(ang + wob)) * r)
			_bolts.append(pts)
		queue_redraw()

	func _process(delta: float) -> void:
		_time += delta
		_acc += delta
		if _acc >= 0.07:   # os raios piscam ~14x por segundo (não todo quadro)
			_acc = 0.0
			_regen()
		else:
			queue_redraw()   # o halo pulsa suave

	func _draw() -> void:
		var pulse: float = 0.5 + 0.5 * sin(_time * 9.0)
		draw_circle(Vector2.ZERO, radius * 1.9, Color(DEEP_RED, 0.16 + 0.08 * pulse))
		draw_circle(Vector2.ZERO, radius * 1.4, Color(RED, 0.18 + 0.1 * pulse))
		draw_arc(Vector2.ZERO, radius * (1.1 + 0.1 * pulse), 0.0, TAU, 32, Color(BLACK, 0.85), 4.0)
		draw_arc(Vector2.ZERO, radius * (1.1 + 0.1 * pulse), 0.0, TAU, 32, Color(RED, 0.95), 1.8)
		for pts in _bolts:
			draw_polyline(pts, Color(BLACK, 0.95), 5.0, true)   # contorno preto
			draw_polyline(pts, Color(RED, 1.0), 2.4, true)      # miolo vermelho
