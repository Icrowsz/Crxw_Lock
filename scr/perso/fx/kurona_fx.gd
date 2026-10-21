class_name KuronaFX
extends RefCounted
## Efeitos visuais do Kurona, no estilo do hiori_fx.gd / aiku_fx.gd: ROSA OPACO (sem brilho) com tubarões e água.
## Tudo por código (nenhuma imagem). Gotas, bolhas e dentes de tubarão como partículas, mais efeitos desenhados:
##  - Fin:    uma nadadeira dorsal rosa que "nada" pelo chão deixando uma esteira de espuma (dashes, passes, carrinho);
##  - Jaws:   uma bocarra de tubarão que abocanha o ponto e fecha com um estalo (Bite, Teeth);
##  - Mark:   A MARCA DO KURONA: uma mordida de tubarão simples (a arcada de dentes, em oval) boiando sobre a cabeça do
##            marcado, com uma gotinha pingando e ondas no chão. Com orbit = true (Satellite), bolhas giram em volta;
##  - Shell:  uma bolha d'água rosa em volta da bola durante o drible do Close Quarter Dribble;
##  - Link:   a fita de água ondulada, com bolhas subindo, que liga o Kurona ao aliado no Underwater;
##  - Ripple: ondas que se abrem no chão.
## Quem chama passa um nó qualquer que já esteja na árvore (ex: o Kurona) em "from".

const PINK := Color(0.90, 0.46, 0.66)         # rosa opaco
const PINK_LIGHT := Color(0.97, 0.76, 0.86)
const PINK_DEEP := Color(0.62, 0.25, 0.44)
const FOAM := Color(1.0, 0.93, 0.96)

const _KEY_DROP := &"kurona_drop_tex"
const _KEY_BUBBLE := &"kurona_bubble_tex"
const _KEY_TOOTH := &"kurona_tooth_tex"
const _KEY_PICK := &"kurona_pick"
const _KEY_FADE := &"kurona_fade"

## Acima de tudo (jogadores e bola usam z_index = y como profundidade)
const FX_Z: int = 3000
## Camada no chão (nadadeira, ondas, fita): translúcida por cima do campo. Se o seu campo usar outra ordem, mude aqui.
const GROUND_Z: int = 2900


# ---------- RECURSOS COMPARTILHADOS ----------

static func _tri_sign(p: Vector2, a: Vector2, b: Vector2) -> float:
	return (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)


static func _in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1: float = _tri_sign(p, a, b)
	var d2: float = _tri_sign(p, b, c)
	var d3: float = _tri_sign(p, c, a)
	var has_neg: bool = d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var has_pos: bool = d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (has_neg and has_pos)


static func _bake(key: StringName, w: int, h: int, inside: Callable) -> ImageTexture:
	if Engine.has_meta(key):
		return Engine.get_meta(key) as ImageTexture
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var hits: int = 0
			for sy in 3:
				for sx in 3:
					if inside.call(Vector2(float(x) + (float(sx) + 0.5) / 3.0, float(y) + (float(sy) + 0.5) / 3.0)):
						hits += 1
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, float(hits) / 9.0))
	var tex := ImageTexture.create_from_image(img)
	Engine.set_meta(key, tex)
	return tex


## Gota d'água (redonda embaixo, com a ponta para cima), 12x18
static func drop_texture() -> ImageTexture:
	return _bake(_KEY_DROP, 12, 18, func(p: Vector2) -> bool:
		return p.distance_to(Vector2(6.0, 12.0)) <= 5.0 or _in_triangle(p, Vector2(6.0, 1.0), Vector2(1.6, 10.0), Vector2(10.4, 10.0)))


## Bolha: só o aro, com um brilhinho no canto, 24x24
static func bubble_texture() -> ImageTexture:
	return _bake(_KEY_BUBBLE, 24, 24, func(p: Vector2) -> bool:
		var d: float = p.distance_to(Vector2(12.0, 12.0))
		return (d <= 10.5 and d >= 8.8) or p.distance_to(Vector2(8.0, 8.0)) <= 1.7)


## Dente de tubarão: triângulo com a ponta para cima, 12x16
static func tooth_texture() -> ImageTexture:
	return _bake(_KEY_TOOTH, 12, 16, func(p: Vector2) -> bool:
		return _in_triangle(p, Vector2(6.0, 0.5), Vector2(0.5, 15.5), Vector2(11.5, 15.5)))


## Cada partícula nasce rosa, rosa-claro ou espuma
static func _pick() -> Gradient:
	if Engine.has_meta(_KEY_PICK):
		return Engine.get_meta(_KEY_PICK) as Gradient
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.4, 0.75])
	g.colors = PackedColorArray([PINK, PINK_LIGHT, FOAM])
	Engine.set_meta(_KEY_PICK, g)
	return g


static func _fade() -> Gradient:
	if Engine.has_meta(_KEY_FADE):
		return Engine.get_meta(_KEY_FADE) as Gradient
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	Engine.set_meta(_KEY_FADE, g)
	return g


static func _particles(tex: Texture2D, amount: int, life: float, speed: float, gravity: Vector2,
		smin: float, smax: float, spin: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.color_initial_ramp = _pick()
	p.color_ramp = _fade()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector2.UP
	p.spread = 170.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.3
	p.damping_max = speed * 0.5
	p.gravity = gravity
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -spin
	p.angular_velocity_max = spin
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	p.z_index = FX_Z
	p.z_as_relative = false
	return p


static func _launch(from: Node, p: CPUParticles2D, pos: Vector2) -> void:
	var tree: SceneTree = from.get_tree()
	var scene: Node = tree.current_scene
	(scene if scene != null else from).add_child(p)
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = true
	tree.create_timer(p.lifetime + 0.4).timeout.connect(p.queue_free)


static func _ok(from: Node) -> bool:
	return from != null and from.is_inside_tree()


static func _add(from: Node, node: Node) -> void:
	var scene: Node = from.get_tree().current_scene
	(scene if scene != null else from).add_child(node)


# ---------- EFEITOS ----------

## Respingo: gotas caindo e algumas bolhas subindo
static func splash(from: Node, pos: Vector2, amount: int = 12, strong: bool = false) -> void:
	if not _ok(from):
		return
	var drops: CPUParticles2D = _particles(drop_texture(), amount, 0.7 if strong else 0.55, 230.0 if strong else 160.0,
		Vector2(0.0, 520.0), 0.5 if strong else 0.4, 0.9 if strong else 0.7, 120.0)
	drops.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	drops.emission_sphere_radius = 10.0
	_launch(from, drops, pos)
	bubbles(from, pos, maxi(amount / 3, 3))


## Bolhas subindo devagar
static func bubbles(from: Node, pos: Vector2, amount: int = 8) -> void:
	if not _ok(from):
		return
	var p: CPUParticles2D = _particles(bubble_texture(), amount, 0.9, 60.0, Vector2(0.0, -70.0), 0.35, 0.7, 40.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	_launch(from, p, pos)


## Estouro de uma mordida: dentes voando, gotas e bolhas
static func chomp_burst(from: Node, pos: Vector2) -> void:
	if not _ok(from):
		return
	var teeth: CPUParticles2D = _particles(tooth_texture(), 12, 0.7, 240.0, Vector2(0.0, 420.0), 0.5, 0.9, 520.0)
	teeth.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	teeth.emission_sphere_radius = 12.0
	_launch(from, teeth, pos)
	splash(from, pos, 10, true)


## Bolhas que acompanham a bola por "seconds" segundos (filhas do sprite dela: seguem a altura)
static func ball_trail(ball: Ball, seconds: float = 0.8) -> void:
	if ball == null or not ball.is_inside_tree():
		return
	var p: CPUParticles2D = _particles(bubble_texture(), 10, 0.6, 30.0, Vector2(0.0, -40.0), 0.3, 0.55, 30.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 6.0
	p.explosiveness = 0.0
	var holder: Node = ball.sprite if ball.sprite != null else ball
	holder.add_child(p)
	p.emitting = true
	var tree: SceneTree = ball.get_tree()
	tree.create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false)
	tree.create_timer(seconds + p.lifetime + 0.3).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free())


## Ondas se abrindo no chão
static func ripple(from: Node, pos: Vector2, radius: float = 60.0) -> void:
	if not _ok(from):
		return
	var r := Ripple.new(radius)
	_add(from, r)
	r.global_position = pos


## Nadadeira dorsal que nada de "a" até "b" em "life" segundos, deixando a esteira
static func fin(from: Node, a: Vector2, b: Vector2, life: float = 0.5) -> Fin:
	if not _ok(from):
		return null
	var f := Fin.new(a, b, life)
	_add(from, f)
	return f


## Bocarra de tubarão abocanhando "pos" (fecha com um estalo e some)
static func jaws(from: Node, pos: Vector2, size: float = 46.0) -> void:
	if not _ok(from):
		return
	var j := Jaws.new(size)
	_add(from, j)
	j.global_position = pos


## A marca do Kurona sobre a cabeça de "target". orbit = true: bolhas giram em volta (Satellite).
static func mark(target: Player, orbit: bool = false) -> Mark:
	if not _ok(target):
		return null
	var m := Mark.new(target, orbit)
	_add(target, m)
	return m


## Bolha d'água em volta da bola (drible). Chame release() para estourar.
static func shell(ball: Ball) -> Shell:
	if not _ok(ball):
		return null
	var s := Shell.new(ball)
	_add(ball, s)
	return s


## Fita de água ligando dois jogadores (Underwater). Chame release() quando a conexão acabar.
static func link(a: Player, b: Player, max_length: float) -> Link:
	if not _ok(a) or b == null:
		return null
	var l := Link.new(a, b, max_length)
	_add(a, l)
	return l


# ---------- ONDAS NO CHÃO ----------

class Ripple extends Node2D:
	var radius: float = 60.0
	var _t: float = 0.0

	func _init(r: float) -> void:
		radius = r
		z_as_relative = false
		z_index = KuronaFX.GROUND_Z

	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.8:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))   # achatado: vemos o chão de cima, em perspectiva
		for i in 3:
			var u: float = clampf(_t / 0.8 - float(i) * 0.18, 0.0, 1.0)
			if u <= 0.0:
				continue
			draw_arc(Vector2.ZERO, radius * (0.25 + 0.75 * u), 0.0, TAU, 40,
				Color(KuronaFX.PINK_LIGHT, 0.7 * (1.0 - u)), 3.0 * (1.0 - u) + 1.0, true)


# ---------- NADADEIRA ----------

class Fin extends Node2D:
	var a: Vector2
	var b: Vector2
	var life: float = 0.5
	var _t: float = 0.0
	var _wake: PackedVector2Array = PackedVector2Array()
	var _face: float = 1.0

	func _init(from_p: Vector2, to_p: Vector2, l: float) -> void:
		a = from_p
		b = to_p
		life = maxf(l, 0.1)
		top_level = true
		z_as_relative = false
		z_index = KuronaFX.GROUND_Z + 20
		_face = 1.0 if to_p.x >= from_p.x else -1.0

	func _spot(u: float) -> Vector2:
		var base: Vector2 = a.lerp(b, 1.0 - pow(1.0 - u, 2.0))
		var side: Vector2 = (b - a).normalized().orthogonal()
		return base + side * sin(u * TAU * 1.5) * 12.0 * (1.0 - 0.4 * u)

	func _process(delta: float) -> void:
		_t += delta
		var u: float = clampf(_t / life, 0.0, 1.0)
		global_position = _spot(u)
		if u < 1.0:
			_wake.append(global_position)
			if _wake.size() > 36:
				_wake.remove_at(0)
		if _t > life + 0.45:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var out: float = clampf((_t - life) / 0.45, 0.0, 1.0)   # depois que chega, afunda e some
		var vis: float = 1.0 - out
		# Esteira de espuma: duas linhas que se abrem em V e vão sumindo
		var n: int = _wake.size()
		for i in range(1, n):
			var k: float = float(i) / float(maxi(n, 1))
			var p0: Vector2 = _wake[i - 1] - global_position
			var p1: Vector2 = _wake[i] - global_position
			var spread: Vector2 = (p1 - p0).normalized().orthogonal() * (1.0 - k) * 9.0
			var c := Color(KuronaFX.FOAM, 0.55 * k * vis)
			draw_line(p0 + spread, p1 + spread, c, 2.0)
			draw_line(p0 - spread, p1 - spread, c, 2.0)
		draw_set_transform(Vector2(0.0, out * 14.0), 0.0, Vector2(_face, 1.0))
		# Marolinha em volta da base
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 20, Color(KuronaFX.FOAM, 0.6 * vis), 2.0)
		# Nadadeira dorsal (borda de trás côncava, ponta para a frente) e a cauda logo atrás
		var dorsal := PackedVector2Array([Vector2(-16.0, 0.0), Vector2(-9.0, -14.0), Vector2(5.0, -30.0),
			Vector2(9.0, -12.0), Vector2(15.0, 0.0)])
		draw_colored_polygon(dorsal, Color(KuronaFX.PINK, 0.92 * vis))
		draw_polyline(PackedVector2Array([dorsal[0], dorsal[1], dorsal[2], dorsal[3], dorsal[4]]),
			Color(KuronaFX.PINK_DEEP, 0.9 * vis), 2.0, true)
		draw_line(Vector2(-3.0, -6.0), Vector2(3.0, -22.0), Color(KuronaFX.PINK_LIGHT, 0.7 * vis), 2.0)
		var tail := PackedVector2Array([Vector2(-44.0, 0.0), Vector2(-38.0, -12.0), Vector2(-33.0, -4.0),
			Vector2(-28.0, -13.0), Vector2(-24.0, 0.0)])
		draw_colored_polygon(tail, Color(KuronaFX.PINK, 0.8 * vis))


# ---------- BOCARRA ----------

class Jaws extends Node2D:
	var size: float = 46.0
	var _t: float = 0.0
	const LIFE: float = 0.7
	const TEETH: int = 7

	func _init(s: float) -> void:
		size = s
		z_as_relative = false
		z_index = KuronaFX.FX_Z

	func _ready() -> void:
		get_tree().create_timer(0.28).timeout.connect(func() -> void:
			if is_inside_tree():
				KuronaFX.chomp_burst(self, global_position))

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var u: float = _t / LIFE
		var open: float = 1.0
		if u < 0.4:
			open = 1.0 - pow(u / 0.4, 3.0)        # fecha acelerando (o bote)
		else:
			open = 0.0
		var alpha: float = 1.0 if u < 0.7 else 1.0 - (u - 0.7) / 0.3
		var gap: float = size * 0.75 * open
		_draw_jaw(-1.0, gap, alpha)
		_draw_jaw(1.0, gap, alpha)

	## sign -1 = mandíbula de cima (dentes para baixo); 1 = de baixo (dentes para cima)
	func _draw_jaw(sign_y: float, gap: float, alpha: float) -> void:
		var body := PackedVector2Array()
		for i in 17:
			var t: float = PI * float(i) / 16.0
			body.append(Vector2(cos(t) * size, sign_y * (gap + sin(t) * size * 0.75)))
		draw_colored_polygon(body, Color(KuronaFX.PINK, 0.9 * alpha))
		draw_polyline(body, Color(KuronaFX.PINK_DEEP, 0.9 * alpha), 2.0, true)
		# Dentes ao longo da borda de dentro
		var step: float = size * 2.0 / float(TEETH)
		for i in TEETH:
			var x0: float = -size + step * float(i)
			var tip := Vector2(x0 + step * 0.5, sign_y * (gap - size * 0.26))
			var tri := PackedVector2Array([Vector2(x0 + 2.0, sign_y * gap), tip, Vector2(x0 + step - 2.0, sign_y * gap)])
			draw_colored_polygon(tri, Color(KuronaFX.FOAM, alpha))


# ---------- A MARCA: UMA MORDIDA DE TUBARÃO ----------

class Mark extends Node2D:
	var target: Player
	var orbit: bool = false
	var _t: float = 0.0
	var _dying: bool = false
	var _fade: float = 1.0
	var _lift: float = 74.0

	func _init(t: Player, with_orbit: bool) -> void:
		target = t
		orbit = with_orbit
		z_as_relative = false
		z_index = KuronaFX.FX_Z

	func _ready() -> void:
		_follow()
		KuronaFX.splash(self, global_position, 8, false)
		KuronaFX.ripple(self, target.global_position, 55.0)

	## A marca estoura (usada) em dentes e gotas
	func pop() -> void:
		if _dying:
			return
		_dying = true
		KuronaFX.chomp_burst(self, global_position)

	func _follow() -> void:
		global_position = target.global_position + Vector2(0.0, -target.height - _lift + sin(_t * 2.4) * 3.0)

	func _process(delta: float) -> void:
		if not is_instance_valid(target):
			queue_free()
			return
		_t += delta
		if _dying:
			_fade -= delta * 6.0
			if _fade <= 0.0:
				queue_free()
				return
		_follow()
		if int(_t * 1.2) != int((_t - delta) * 1.2):   # de tempos em tempos, uma onda no chão do marcado
			KuronaFX.ripple(self, target.global_position, 50.0)
		queue_redraw()

	func _draw() -> void:
		var grow: float = clampf(_t / 0.25, 0.0, 1.0)
		var s: float = (1.0 + sin(grow * PI) * 0.2) * grow * (1.0 + (1.0 - _fade) * 0.4)
		var a: float = _fade
		s = maxf(s, 0.01)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		# Mordida simples: uma oval de dentes. Os de cima apontam para baixo, os de baixo para cima,
		# intercalados; a oval fica aberta dos lados (é a arcada, não uma coroa)
		var rx: float = 22.0
		var ry: float = 15.0
		var snap: float = (sin(_t * 3.0) * 0.5 + 0.5) * 2.0   # a mordida "respira"
		var teeth: int = 6
		for row in 2:
			var up: bool = row == 0
			var dir_y: float = 1.0 if up else -1.0
			for i in teeth:
				var f0: float = float(i) / float(teeth)
				var f1: float = float(i + 1) / float(teeth)
				var a0: float = lerpf(0.12, 0.88, f0) * PI
				var a1: float = lerpf(0.12, 0.88, f1) * PI
				var am: float = (a0 + a1) * 0.5
				var sy: float = -1.0 if up else 1.0
				var base0 := Vector2(cos(a0 + PI) * rx * -1.0, sy * sin(a0) * ry)
				var base1 := Vector2(cos(a1 + PI) * rx * -1.0, sy * sin(a1) * ry)
				var tip := Vector2(cos(am + PI) * rx * -1.0 * 0.86, sy * sin(am) * ry * 0.86 + dir_y * (7.0 - snap * (1.0 if up else -1.0) * 0.5))
				# a fileira de baixo fica meio dente deslocada
				if not up:
					base0.x += rx * 0.1
					base1.x += rx * 0.1
					tip.x += rx * 0.1
				draw_colored_polygon(PackedVector2Array([base0, tip, base1]), Color(KuronaFX.PINK, 0.95 * a))
				draw_polyline(PackedVector2Array([base0, tip, base1]), Color(KuronaFX.PINK_DEEP, 0.9 * a), 1.5, true)
		# Gotinha pingando da mordida
		var drip: float = fposmod(_t * 0.9, 1.0)
		draw_circle(Vector2(0.0, ry + 4.0 + drip * 18.0), 2.6 * (1.0 - drip * 0.5), Color(KuronaFX.PINK_LIGHT, 0.9 * a * (1.0 - drip)))
		# Satellite: bolhas orbitando a mordida
		if orbit:
			for k in 3:
				var ang: float = _t * 2.2 + TAU * float(k) / 3.0
				var p := Vector2(cos(ang) * 34.0, sin(ang) * 16.0)
				draw_arc(p, 4.5, 0.0, TAU, 12, Color(KuronaFX.PINK_LIGHT, 0.9 * a), 2.0)
				draw_circle(p + Vector2(-1.4, -1.4), 1.0, Color(KuronaFX.FOAM, 0.9 * a))
		# Ondas no chão, em volta de onde o marcado está
		draw_set_transform(Vector2(0.0, _lift + target.height), 0.0, Vector2(s, s * 0.45))
		for i in 2:
			var u: float = fposmod(_t * 0.6 + float(i) * 0.5, 1.0)
			draw_arc(Vector2.ZERO, 22.0 + 20.0 * u, 0.0, TAU, 32, Color(KuronaFX.PINK, 0.55 * a * (1.0 - u)), 2.5)


# ---------- BOLHA D'ÁGUA NA BOLA ----------

class Shell extends Node2D:
	var ball: Ball
	var _t: float = 0.0
	var _dying: bool = false
	var _fade: float = 1.0

	func _init(b: Ball) -> void:
		ball = b
		z_as_relative = false
		z_index = KuronaFX.FX_Z

	func release() -> void:
		if _dying:
			return
		_dying = true
		KuronaFX.splash(self, global_position, 8, false)

	func _process(delta: float) -> void:
		if not is_instance_valid(ball):
			queue_free()
			return
		_t += delta
		if _dying:
			_fade -= delta * 8.0
			if _fade <= 0.0:
				queue_free()
				return
		global_position = ball.global_position + Vector2(0.0, -ball.height)
		queue_redraw()

	func _draw() -> void:
		var a: float = _fade * clampf(_t / 0.15, 0.0, 1.0)
		var pts := PackedVector2Array()
		for i in 24:
			var ang: float = TAU * float(i) / 24.0
			var wob: float = 1.0 + sin(ang * 3.0 + _t * 9.0) * 0.07 + sin(ang * 5.0 - _t * 6.0) * 0.04
			pts.append(Vector2.from_angle(ang) * 23.0 * wob)
		draw_colored_polygon(pts, Color(KuronaFX.PINK, 0.16 * a))
		var closed: PackedVector2Array = pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(KuronaFX.PINK_LIGHT, 0.65 * a), 2.0, true)
		draw_arc(Vector2.ZERO, 16.0, PI * 1.1, PI * 1.55, 8, Color(KuronaFX.FOAM, 0.8 * a), 2.0)


# ---------- A FITA DE ÁGUA (UNDERWATER) ----------

class Link extends Node2D:
	var a: Player
	var b: Player
	var max_length: float = 350.0
	var _t: float = 0.0
	var _dying: bool = false
	var _fade: float = 0.0

	func _init(p1: Player, p2: Player, max_len: float) -> void:
		a = p1
		b = p2
		max_length = max_len
		top_level = true
		z_as_relative = false
		z_index = KuronaFX.GROUND_Z + 40

	func release() -> void:
		if _dying:
			return
		_dying = true
		if is_instance_valid(a) and is_instance_valid(b):
			KuronaFX.splash(self, (a.global_position + b.global_position) * 0.5, 10, true)

	func _process(delta: float) -> void:
		if not is_instance_valid(a) or not is_instance_valid(b):
			queue_free()
			return
		_t += delta
		_fade = move_toward(_fade, 0.0 if _dying else 1.0, delta * (4.0 if _dying else 3.0))
		if _dying and _fade <= 0.01:
			queue_free()
			return
		queue_redraw()

	func _point(p: Player) -> Vector2:
		return p.global_position + Vector2(0.0, -p.height - 16.0)

	func _draw() -> void:
		var p0: Vector2 = _point(a)
		var p1: Vector2 = _point(b)
		var dist: float = p0.distance_to(p1)
		if dist < 2.0:
			return
		var dir: Vector2 = (p1 - p0) / dist
		var side: Vector2 = dir.orthogonal()
		var strain: float = clampf(dist / max_length, 0.0, 1.2)
		var danger: float = clampf((strain - 0.8) / 0.2, 0.0, 1.0)   # perto do limite: escurece e treme
		var col: Color = KuronaFX.PINK.lerp(KuronaFX.PINK_DEEP, danger)
		var amp: float = lerpf(11.0, 3.0, strain * 0.8) + sin(_t * 40.0) * 2.0 * danger
		var steps: int = 26
		for ribbon in 2:
			var phase: float = PI * float(ribbon)
			var pts := PackedVector2Array()
			for i in steps + 1:
				var s: float = float(i) / float(steps)
				var env: float = sin(s * PI)                          # as pontas ficam coladas nos jogadores
				var wave: float = sin(s * TAU * 2.0 - _t * 3.2 + phase) * amp * env
				pts.append(p0.lerp(p1, s) + side * wave - global_position)
			draw_polyline(pts, Color(col, (0.8 if ribbon == 0 else 0.55) * _fade), 3.5 if ribbon == 0 else 2.5, true)
		# Bolhas deslizando pela fita
		for k in 6:
			var s2: float = fposmod(_t * 0.28 + float(k) / 6.0, 1.0)
			var wob: float = sin(s2 * TAU * 2.0 - _t * 3.2) * amp * sin(s2 * PI) * 0.6
			var bp: Vector2 = p0.lerp(p1, s2) + side * wob - global_position
			draw_arc(bp + Vector2(0.0, -sin(_t * 2.0 + float(k)) * 4.0), 3.5 + float(k % 3), 0.0, TAU, 10,
				Color(KuronaFX.PINK_LIGHT, 0.85 * _fade), 1.5)
		# Ondinhas no chão de cada um
		for pl: Player in [a, b]:
			draw_set_transform(pl.global_position - global_position, 0.0, Vector2(1.0, 0.45))
			var u: float = fposmod(_t * 0.7, 1.0)
			draw_arc(Vector2.ZERO, 18.0 + 16.0 * u, 0.0, TAU, 28, Color(col, 0.6 * _fade * (1.0 - u)), 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
