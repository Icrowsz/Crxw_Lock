class_name ChigiriFX
extends RefCounted
## Efeitos visuais do Chigiri, no estilo do hiori_fx.gd / kurona_fx.gd. Tudo por código (nenhuma imagem).
## VERMELHO/ROSA com detalhes de VELOCIDADE (riscos, imagens residuais, ondas de choque), principalmente nos chutes:
##  - Panther:  a pantera vermelha translúcida que SEGUE o Chigiri (corre atrás quando ele anda, senta e balança a cauda
##              quando ele para) e DÁ O BOTE na bola nos chutes, arranhando-a com garras;
##  - Dash:     a faixa de velocidade que o avanço deixa (rastro afunilado, linhas paralelas e imagens residuais);
##  - Claws:    três arranhões diagonais (a garra da pantera) na hora do chute;
##  - Shock:    onda de choque achatada no chão;
##  - Zone:     a GOLDEN ZONE: o ÚNICO lugar com dourado. Brilho (bloom) bem marcante: camadas de luz aditiva, raios
##              girando, anéis, brilhos viajando e faíscas douradas subindo.
##
## BLOOM DE VERDADE: as cores HDR (acima de 1.0) da zona só "estouram" com o glow ligado no Environment (e o HDR 2D
## do viewport). enable_bloom() liga isso sozinho se a cena não tiver um WorldEnvironment; se tiver, ligue o glow nele
## (Glow > Enabled, HDR Threshold 1.0, Background = Canvas). Sem isso o brilho continua aparecendo: as camadas aditivas
## de luz são o bloom "falso" e funcionam em qualquer configuração.

const RED := Color(0.95, 0.16, 0.22)
const RED_DEEP := Color(0.62, 0.06, 0.12)
const PINK := Color(1.0, 0.45, 0.62)
const PINK_HOT := Color(1.0, 0.78, 0.84)

# O dourado só existe na Golden Zone
const GOLD := Color(1.0, 0.78, 0.2, 0.745)
const GOLD_LIGHT := Color(1.0, 0.929, 0.6, 0.745)
const GOLD_HOT := Color(2.4, 1.752, 0.502, 0.745)      # HDR: estoura no bloom

const _KEY_STREAK := &"chigiri_streak_tex"
const _KEY_SPARK := &"chigiri_spark_tex"
const _KEY_SOFT := &"chigiri_soft_tex"
const _KEY_PICK := &"chigiri_pick"
const _KEY_FADE := &"chigiri_fade"
const _KEY_ADD := &"chigiri_additive"

## Acima de tudo (jogadores e bola usam z_index = y como profundidade)
const FX_Z: int = 3000
## Camada no chão (rastro de velocidade e a Golden Zone): translúcida por cima do campo
const GROUND_Z: int = 2900


# ---------- RECURSOS COMPARTILHADOS ----------

static func _bake(key: StringName, w: int, h: int, alpha_at: Callable) -> ImageTexture:
	if Engine.has_meta(key):
		return Engine.get_meta(key) as ImageTexture
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(alpha_at.call(float(x) + 0.5, float(y) + 0.5), 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	Engine.set_meta(key, tex)
	return tex


## Risco de velocidade: fino, comprido (vertical, 6x40), afunila nas duas pontas
static func streak_texture() -> ImageTexture:
	return _bake(_KEY_STREAK, 6, 40, func(x: float, y: float) -> float:
		var half: float = 2.7 * sin(PI * y / 40.0)
		return 1.0 - absf(x - 3.0) / maxf(half, 0.05))


## Faísca de quatro pontas, 16x16
static func spark_texture() -> ImageTexture:
	return _bake(_KEY_SPARK, 16, 16, func(x: float, y: float) -> float:
		var v: float = sqrt(absf(x - 8.0)) + sqrt(absf(y - 8.0))
		return (sqrt(7.5) - v) * 1.6)


## Luz suave redonda (centro forte, borda transparente): a base do bloom falso
static func soft_texture() -> Texture2D:
	if Engine.has_meta(_KEY_SOFT):
		return Engine.get_meta(_KEY_SOFT) as Texture2D
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	Engine.set_meta(_KEY_SOFT, t)
	return t


static func _additive() -> CanvasItemMaterial:
	if Engine.has_meta(_KEY_ADD):
		return Engine.get_meta(_KEY_ADD) as CanvasItemMaterial
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	Engine.set_meta(_KEY_ADD, m)
	return m


## Cada partícula nasce vermelha, rosa ou rosa-quente
static func _pick() -> Gradient:
	if Engine.has_meta(_KEY_PICK):
		return Engine.get_meta(_KEY_PICK) as Gradient
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.4, 0.75])
	g.colors = PackedColorArray([RED, PINK, PINK_HOT])
	Engine.set_meta(_KEY_PICK, g)
	return g


static func _fade() -> Gradient:
	if Engine.has_meta(_KEY_FADE):
		return Engine.get_meta(_KEY_FADE) as Gradient
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	Engine.set_meta(_KEY_FADE, g)
	return g


static func _particles(tex: Texture2D, amount: int, life: float, speed: float, smin: float, smax: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.color_initial_ramp = _pick()
	p.color_ramp = _fade()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.5
	p.damping_max = speed * 0.9
	p.gravity = Vector2.ZERO
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
	p.explosiveness = 0.95
	p.emitting = true
	tree.create_timer(p.lifetime + 0.4).timeout.connect(p.queue_free)


static func _ok(from: Node) -> bool:
	return from != null and from.is_inside_tree()


static func _add(from: Node, node: Node) -> void:
	var scene: Node = from.get_tree().current_scene
	(scene if scene != null else from).add_child(node)


# ---------- EFEITOS ----------

## Riscos de velocidade saindo de "pos" na direção "dir" (alinhados com o movimento)
static func streaks(from: Node, pos: Vector2, dir: Vector2, amount: int = 12, strong: bool = false) -> void:
	if not _ok(from):
		return
	var p: CPUParticles2D = _particles(streak_texture(), amount, 0.32 if strong else 0.25,
		1000.0 if strong else 700.0, 0.7 if strong else 0.5, 1.3 if strong else 0.9)
	p.particle_flag_align_y = true
	p.direction = dir.normalized()
	p.spread = 9.0
	p.damping_min = 600.0
	p.damping_max = 1100.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	_launch(from, p, pos)


## Faíscas em estrela se abrindo
static func sparks(from: Node, pos: Vector2, amount: int = 10) -> void:
	if not _ok(from):
		return
	var p: CPUParticles2D = _particles(spark_texture(), amount, 0.45, 280.0, 0.6, 1.1)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 8.0
	_launch(from, p, pos)


## O estouro de um chute: riscos para frente, faíscas, ondas de choque e as garras da pantera
static func kick_burst(from: Node, pos: Vector2, dir: Vector2) -> void:
	if not _ok(from):
		return
	streaks(from, pos, dir, 16, true)
	streaks(from, pos, -dir, 8, false)
	sparks(from, pos, 12)
	shock(from, pos, 70.0)
	claws(from, pos, dir)


## Faíscas que acompanham a bola por "seconds" segundos (filhas do sprite dela: seguem a altura)
static func ball_trail(ball: Ball, seconds: float = 0.8) -> void:
	if ball == null or not ball.is_inside_tree():
		return
	var p: CPUParticles2D = _particles(spark_texture(), 12, 0.4, 40.0, 0.4, 0.8)
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


## Onda de choque achatada no chão
static func shock(from: Node, pos: Vector2, radius: float = 70.0) -> void:
	if not _ok(from):
		return
	var s := Shock.new(radius)
	_add(from, s)
	s.global_position = pos


## Três arranhões diagonais (a garra da pantera) cruzando "pos" na direção "dir"
static func claws(from: Node, pos: Vector2, dir: Vector2) -> void:
	if not _ok(from):
		return
	var c := Claws.new(dir)
	_add(from, c)
	c.global_position = pos


## Faixa de velocidade de um avanço. Alimente com add_point() a cada quadro e chame finish() no fim.
static func dash(from: Node, radius: float = 16.0) -> Dash:
	if not _ok(from):
		return null
	var d := Dash.new(radius)
	_add(from, d)
	return d


## A pantera que segue o "owner_player"
static func panther(owner_player: Player) -> Panther:
	if not _ok(owner_player):
		return null
	var p := Panther.new(owner_player)
	_add(owner_player, p)
	return p


## A Golden Zone (o único dourado do Chigiri)
static func zone(from: Node, center: Vector2, radius: float) -> Zone:
	if not _ok(from):
		return null
	var hdr: bool = false
	var vp: Viewport = from.get_viewport()
	if vp != null and "use_hdr_2d" in vp:
		hdr = bool(vp.get("use_hdr_2d"))
	var z := Zone.new(center, radius, hdr)
	_add(from, z)
	return z


## Liga o glow (bloom) do jogo para o dourado HDR da Golden Zone estourar. Se a cena já tem um WorldEnvironment, não
## mexe nele (ligue o glow lá, veja o topo do arquivo). Devolve true se há glow ativo.
static func enable_bloom(from: Node) -> bool:
	if not _ok(from):
		return false
	var vp: Viewport = from.get_viewport()
	if vp != null and "use_hdr_2d" in vp:
		vp.set("use_hdr_2d", true)
	var scene: Node = from.get_tree().current_scene
	if scene == null:
		return false
	var found: Array[Node] = scene.find_children("*", "WorldEnvironment", true, false)
	if not found.is_empty():
		var existing: Environment = (found[0] as WorldEnvironment).environment
		return existing != null and existing.glow_enabled
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = false
	env.glow_hdr_threshold = 0.1     # só o que passa de 1.0 (o dourado) brilha; o resto do jogo não muda
	env.glow_intensity = 0.1
	env.glow_strength = 0.1
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)
	return true


# ---------- ONDA DE CHOQUE ----------

class Shock extends Node2D:
	var radius: float = 70.0
	var _t: float = 0.0

	func _init(r: float) -> void:
		radius = r
		z_as_relative = false
		z_index = ChigiriFX.GROUND_Z

	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.4:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var u: float = _t / 0.4
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, radius * (0.2 + 0.8 * u), 0.0, TAU, 40, Color(ChigiriFX.PINK, 0.8 * (1.0 - u)), 4.0 * (1.0 - u) + 1.0, true)
		draw_arc(Vector2.ZERO, radius * (0.1 + 0.6 * u), 0.0, TAU, 32, Color(ChigiriFX.RED, 0.6 * (1.0 - u)), 2.0, true)
		for i in 8:   # marquinhas de velocidade saindo em raios
			var d: Vector2 = Vector2.from_angle(TAU * float(i) / 8.0)
			draw_line(d * radius * (0.35 + 0.65 * u), d * radius * (0.5 + 0.8 * u), Color(ChigiriFX.PINK_HOT, 0.7 * (1.0 - u)), 2.0)


# ---------- ARRANHÕES ----------

class Claws extends Node2D:
	var dir: Vector2 = Vector2.RIGHT
	var _t: float = 0.0

	func _init(d: Vector2) -> void:
		dir = d.normalized() if d.length() > 0.01 else Vector2.RIGHT
		z_as_relative = false
		z_index = ChigiriFX.FX_Z

	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.4:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var u: float = _t / 0.4
		var grow: float = clampf(u / 0.35, 0.0, 1.0)
		var fade: float = 1.0 - clampf((u - 0.4) / 0.6, 0.0, 1.0)
		var along: Vector2 = dir.rotated(-0.9)
		var across: Vector2 = along.orthogonal()
		for i in 3:
			var off: Vector2 = across * (float(i) - 1.0) * 15.0
			var a: Vector2 = off - along * 30.0
			var b: Vector2 = off + along * (30.0 * grow * 2.0 - 30.0)
			var width: float = 7.0 * (1.0 - float(absi(i - 1)) * 0.25)
			draw_polygon(PackedVector2Array([a, a.lerp(b, 0.5) + across * width * 0.5, b, a.lerp(b, 0.5) - across * width * 0.5]),
				PackedColorArray([Color(ChigiriFX.RED, 0.9 * fade), Color(ChigiriFX.PINK, 0.95 * fade),
					Color(ChigiriFX.PINK_HOT, 0.9 * fade), Color(ChigiriFX.PINK, 0.95 * fade)]))


# ---------- FAIXA DE VELOCIDADE DO AVANÇO ----------

class Dash extends Node2D:
	var radius: float = 16.0
	var points: PackedVector2Array = PackedVector2Array()   # posições globais
	var _life: float = 1.0
	var _finishing: bool = false

	func _init(r: float) -> void:
		radius = r
		top_level = true
		z_as_relative = false
		z_index = ChigiriFX.GROUND_Z

	func add_point(gp: Vector2) -> void:
		if points.is_empty() or points[points.size() - 1].distance_to(gp) >= 4.0:
			points.append(gp)

	func finish() -> void:
		_finishing = true

	func _process(delta: float) -> void:
		global_position = Vector2.ZERO   # os pontos já são globais
		if _finishing:
			_life -= delta / 0.45
			if _life <= 0.0:
				queue_free()
				return
		queue_redraw()

	func _draw() -> void:
		var n: int = points.size()
		if n < 2:
			return
		var l: float = clampf(_life, 0.0, 1.0)
		# Rastro afunilado: fino na origem, grosso perto de quem corre
		for i in range(1, n):
			var t: float = float(i) / float(n)
			var w: float = lerpf(2.0, radius, t)
			draw_line(points[i - 1], points[i], Color(ChigiriFX.RED.lerp(ChigiriFX.PINK, t), 0.55 * t * l), w)
		# Linhas de velocidade paralelas, mais curtas
		var dir: Vector2 = (points[n - 1] - points[maxi(n - 4, 0)]).normalized()
		var side: Vector2 = dir.orthogonal()
		for k in 2:
			var off: Vector2 = side * (radius * 0.9) * (1.0 if k == 0 else -1.0)
			var from_i: int = int(float(n) * 0.35)
			draw_line(points[from_i] + off, points[n - 1] + off * 0.7, Color(ChigiriFX.PINK_HOT, 0.45 * l), 1.5)
		# Imagens residuais (vultos que ficam para trás)
		for i in range(0, n, 7):
			var t2: float = float(i) / float(n)
			draw_circle(points[i], radius * (0.7 + 0.3 * t2), Color(ChigiriFX.RED, 0.16 * t2 * l))


# ---------- A PANTERA ----------

class Panther extends Node2D:
	var owner_player: Player
	var unit: float = 20.0           # tamanho (1 unidade do desenho)
	var _t: float = 0.0
	var _phase: float = 0.0
	var _alpha: float = 0.0
	var _speed: float = 0.0
	var _face: float = 1.0
	var _prev: Vector2 = Vector2.ZERO
	var _pounce_t: float = 1.0       # >= 1 = sem bote
	var _pounce_from: Vector2 = Vector2.ZERO
	var _pounce_to: Vector2 = Vector2.ZERO

	func _init(p: Player) -> void:
		owner_player = p
		top_level = true
		z_as_relative = false

	func _ready() -> void:
		global_position = _home()
		_prev = global_position

	## Onde ela fica quando não está fazendo nada: atrás do Chigiri
	func _home() -> Vector2:
		return owner_player.global_position + Vector2(-owner_player.facing * (owner_player.placeholder_radius + 38.0), 8.0)

	## Salta até "to" (a bola), arranha e volta para o Chigiri
	func pounce(to: Vector2) -> void:
		_pounce_t = 0.0
		_pounce_from = global_position
		_pounce_to = to

	func _process(delta: float) -> void:
		if not is_instance_valid(owner_player):
			queue_free()
			return
		_t += delta
		var target: Vector2 = _home()
		var pos: Vector2 = global_position
		if _pounce_t < 1.0:
			_pounce_t += delta / 0.5
			var u: float = clampf(_pounce_t, 0.0, 1.0)
			if u < 0.5:
				pos = _pounce_from.lerp(_pounce_to, 1.0 - pow(1.0 - u * 2.0, 3.0))
			else:
				pos = _pounce_to.lerp(target, 1.0 - pow(1.0 - (u - 0.5) * 2.0, 2.0))
		else:
			pos += (target - pos) * (1.0 - exp(-7.0 * delta))
		global_position = pos
		_speed = lerpf(_speed, pos.distance_to(_prev) / maxf(delta, 0.001), 1.0 - exp(-10.0 * delta))
		if _speed > 40.0 and absf(pos.x - _prev.x) > 0.2:
			_face = signf(pos.x - _prev.x)
		else:
			_face = owner_player.facing
		_prev = pos
		z_index = int(owner_player.global_position.y) - 1
		_phase += delta * (4.0 + _speed * 0.03)
		_alpha = move_toward(_alpha, 1.0, delta * 2.0)
		queue_redraw()

	func _draw() -> void:
		var s: float = unit
		var f: float = _face
		var run: float = clampf(_speed / 260.0, 0.0, 1.0)            # 0 parada, 1 disparada
		var air: float = sin(clampf(_pounce_t, 0.0, 1.0) * PI) if _pounce_t < 1.0 else 0.0
		var a: float = _alpha
		var fill := Color(ChigiriFX.RED, 0.30 * a)
		var line := Color(ChigiriFX.PINK, 0.62 * a)
		# Parada: agachada e respirando; correndo: corpo alto e arqueando a cada passada
		var sy: float = -0.72 + (1.0 - run) * 0.14 - air * 0.6 + sin(_t * 2.2) * 0.03 * (1.0 - run) + sin(_phase * 2.0) * 0.05 * run
		var arch: float = sin(_phase * 2.0) * 0.1 * run - air * 0.1

		# Linhas de velocidade atrás dela
		if run > 0.25:
			for i in 3:
				var yy: float = sy - 0.15 + float(i) * 0.22
				draw_line(Vector2(-1.6 * f, yy) * s, Vector2((-1.6 - 1.2 * run - float(i) * 0.3) * f, yy) * s, Color(ChigiriFX.PINK_HOT, 0.4 * a), 1.5)

		# Rabo comprido, balançando (mais solto quando parada)
		var tail := PackedVector2Array()
		for i in 9:
			var u: float = float(i) / 8.0
			tail.append(Vector2((-1.2 - u * 1.3) * f, sy - u * 0.35 + sin(_t * (3.0 + 4.0 * run) + u * 3.5) * (0.16 + 0.1 * (1.0 - run)) * u) * s)
		draw_polyline(tail, Color(ChigiriFX.RED, 0.45 * a), 0.2 * s, true)
		draw_polyline(tail, line, 1.5, true)

		# Pernas: duas de cada lado em oposição; saltando, esticam para frente e para trás
		var legs: Array = [[0.72, 0.0], [0.45, PI], [-0.62, PI * 0.5], [-0.9, PI * 1.5]]
		for leg: Array in legs:
			var hip := Vector2(float(leg[0]), sy + 0.3)
			var swing: float = sin(_phase + float(leg[1])) * 0.85 * run
			if air > 0.0:
				swing = lerpf(swing, 1.15 if float(leg[0]) > 0.0 else -1.15, air)
			var lift: float = maxf(0.0, cos(_phase + float(leg[1]))) * 0.16 * run
			var paw: Vector2 = hip + Vector2(sin(swing), cos(swing)) * (0.78 - lift)
			var knee: Vector2 = (hip + paw) * 0.5 + Vector2(-0.14 * signf(float(leg[0]) + 0.1), 0.0)
			var pts := PackedVector2Array([Vector2(hip.x * f, hip.y) * s, Vector2(knee.x * f, knee.y) * s, Vector2(paw.x * f, paw.y) * s])
			draw_polyline(pts, Color(ChigiriFX.RED, 0.4 * a), 0.2 * s, true)
			draw_polyline(pts, line, 1.5, true)

		# Corpo e pescoço
		var body_pts: Array[Vector2] = [Vector2(-1.25, sy + 0.05), Vector2(-0.9, sy - 0.3 + arch), Vector2(-0.1, sy - 0.34 - arch),
			Vector2(0.8, sy - 0.3 + arch), Vector2(1.15, sy - 0.12), Vector2(1.1, sy + 0.22), Vector2(0.5, sy + 0.32),
			Vector2(-0.3, sy + 0.28), Vector2(-1.0, sy + 0.3)]
		var body := PackedVector2Array()
		for bp: Vector2 in body_pts:
			body.append(Vector2(bp.x * f, bp.y) * s)
		draw_colored_polygon(body, fill)
		draw_polyline(body + PackedVector2Array([body[0]]), line, 1.5, true)

		# Cabeça: redonda, focinho curto e orelhas pontudas
		var head: Vector2 = Vector2(1.55, sy - 0.3 + (air * -0.1))
		draw_circle(Vector2(head.x * f, head.y) * s, 0.3 * s, fill)
		draw_arc(Vector2(head.x * f, head.y) * s, 0.3 * s, 0.0, TAU, 16, line, 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2((head.x + 0.18) * f, head.y + 0.02) * s, Vector2((head.x + 0.5) * f, head.y + 0.1) * s,
			Vector2((head.x + 0.2) * f, head.y + 0.22) * s]), fill)
		for ear in [-0.12, 0.14]:
			draw_colored_polygon(PackedVector2Array([Vector2((head.x + float(ear) - 0.1) * f, head.y - 0.22) * s,
				Vector2((head.x + float(ear)) * f, head.y - 0.5) * s, Vector2((head.x + float(ear) + 0.1) * f, head.y - 0.24) * s]), fill)
		# Olho: uma fenda rosa-quente
		draw_line(Vector2((head.x + 0.12) * f, head.y - 0.06) * s, Vector2((head.x + 0.28) * f, head.y - 0.1) * s, Color(ChigiriFX.PINK_HOT, 0.95 * a), 2.0)


# ---------- A GOLDEN ZONE ----------

class Zone extends Node2D:
	var center: Vector2
	var radius: float = 90.0
	var hdr: bool = false
	var inside: bool = false         # o Chigiri está dentro: a zona brilha mais
	var _t: float = 0.0
	var _alpha: float = 0.0
	var _glow: float = 0.0
	var _pulse: float = 0.0
	var _dismissing: bool = false
	var _sparkles: CPUParticles2D

	func _init(c: Vector2, r: float, use_hdr: bool) -> void:
		center = c
		radius = r
		hdr = use_hdr
		top_level = true
		z_as_relative = false
		z_index = ChigiriFX.GROUND_Z
		material = ChigiriFX._additive()    # tudo aditivo: a luz soma e "brilha" sobre o campo

	func _ready() -> void:
		global_position = center
		_sparkles = ChigiriFX._particles(ChigiriFX.spark_texture(), 26, 1.5, 30.0, 0.5, 1.0)
		_sparkles.local_coords = true
		_sparkles.position = Vector2.ZERO
		_sparkles.top_level = false
		_sparkles.z_as_relative = true
		_sparkles.z_index = 1
		_sparkles.color_initial_ramp = null
		_sparkles.color = ChigiriFX.GOLD_HOT if hdr else ChigiriFX.GOLD_LIGHT
		_sparkles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		_sparkles.emission_sphere_radius = radius * 0.9
		_sparkles.direction = Vector2.UP
		_sparkles.spread = 25.0
		_sparkles.initial_velocity_min = 14.0
		_sparkles.initial_velocity_max = 40.0
		_sparkles.damping_min = 0.0
		_sparkles.damping_max = 0.0
		_sparkles.material = ChigiriFX._additive()
		add_child(_sparkles)
		_sparkles.emitting = true

	func recenter(c: Vector2) -> void:
		center = c
		global_position = c

	## Brilha forte por um instante (44 Pant, entrada)
	func pulse() -> void:
		_pulse = 1.0

	func dismiss() -> void:
		_dismissing = true
		if _sparkles != null:
			_sparkles.emitting = false

	func _process(delta: float) -> void:
		_t += delta
		_alpha = move_toward(_alpha, 0.0 if _dismissing else 1.0, delta * (2.5 if _dismissing else 1.5))
		_glow = move_toward(_glow, 1.0 if inside else 0.0, delta * 3.0)
		_pulse = maxf(_pulse - delta * 1.6, 0.0)
		if _dismissing and _alpha <= 0.01:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var a: float = _alpha
		if a <= 0.01:
			return
		var boost: float = 1.0 + 0.45 * _glow + 0.9 * _pulse
		var breathe: float = 0.88 + 0.12 * sin(_t * 2.1)
		var core: Color = ChigiriFX.GOLD_HOT if hdr else ChigiriFX.GOLD
		var R: float = radius

		# Bloom: camadas de luz suave bem maiores que a zona, somando por cima do campo
		var soft: Texture2D = ChigiriFX.soft_texture()
		for layer: Array in [[3.0, 0.10], [2.2, 0.17], [1.5, 0.28]]:
			var k: float = float(layer[0])
			draw_texture_rect(soft, Rect2(-R * k, -R * k, R * k * 2.0, R * k * 2.0), false,
				Color(core, float(layer[1]) * a * boost * breathe))

		# Disco dourado, mais vivo no miolo
		draw_circle(Vector2.ZERO, R, Color(core, 0.14 * a * boost))
		draw_texture_rect(soft, Rect2(-R, -R, R * 2.0, R * 2.0), false, Color(core, 0.35 * a * boost))

		# Raios de luz girando devagar
		for i in 8:
			var ang: float = _t * 0.35 + TAU * float(i) / 8.0
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(ang - 0.07) * R * 0.97,
				Vector2.from_angle(ang + 0.07) * R * 0.97]), Color(ChigiriFX.GOLD_LIGHT, 0.12 * a * boost))

		# Ondas dourados saindo do centro
		for k in 2:
			var u: float = fposmod(_t * 0.45 + float(k) * 0.5, 1.0)
			draw_arc(Vector2.ZERO, R * u, 0.0, TAU, 64, Color(core, 0.5 * a * (1.0 - u) * boost), 2.5)

		# Anéis: borda grossa e brilhante, outro fino por dentro e um tracejado girando
		draw_arc(Vector2.ZERO, R, 0.0, TAU, 96, Color(core, 0.95 * a * boost), 5.0, true)
		draw_arc(Vector2.ZERO, R, 0.0, TAU, 96, Color(ChigiriFX.GOLD_LIGHT, 0.9 * a), 1.8, true)
		draw_arc(Vector2.ZERO, R * 0.9, 0.0, TAU, 96, Color(core, 0.4 * a), 1.5, true)
		for i in 24:
			var st: float = -_t * 0.6 + TAU * float(i) / 24.0
			draw_arc(Vector2.ZERO, R * 0.78, st, st + TAU / 56.0, 3, Color(core, 0.7 * a * boost), 2.5)

		# Brilhos viajando pela borda (cada um com sua luz e uma cruz de reflexo)
		for i in 3:
			var ang2: float = _t * 1.3 + TAU * float(i) / 3.0
			var p: Vector2 = Vector2.from_angle(ang2) * R
			var gs: float = R * 0.36
			draw_texture_rect(soft, Rect2(p.x - gs, p.y - gs, gs * 2.0, gs * 2.0), false, Color(core, 0.8 * a * boost))
			var arm: float = 14.0 + 6.0 * sin(_t * 5.0 + float(i))
			draw_line(p - Vector2(arm, 0.0), p + Vector2(arm, 0.0), Color(ChigiriFX.GOLD_LIGHT, 0.95 * a), 2.0)
			draw_line(p - Vector2(0.0, arm), p + Vector2(0.0, arm), Color(ChigiriFX.GOLD_LIGHT, 0.95 * a), 2.0)
