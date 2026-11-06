class_name KaiserFX
extends RefCounted
## Efeitos visuais do Kaiser, no estilo do kurona_fx.gd / yukimiya_fx.gd: AZUL com detalhes ROSAS e muitas
## ROSAS GIRANDO (flor com cabo e espinhos). Tudo por código (nenhuma imagem):
##  - Rosas:   a flor inteira (botão em espiral, cabo e espinhos) girando rápido, em 3 tons de azul;
##  - Pétalas: pétalas rosas soltas, girando e caindo devagar;
##  - rose_burst / kick_burst: explosão de rosas e pétalas (em volta de um ponto, ou em cone no chute);
##  - ball_roses: rosas e pétalas que acompanham a bola por alguns segundos (chutes de habilidade);
##  - dash_trail: esteira azul atrás do Kaiser nos dashes, com rosas girando e pétalas soltando;
##  - ring: onda azul no chão com um aro rosa (troca de Vision);
##  - kick_style: o KickFX (rastro + aura) azul que acompanha a bola nos chutes de habilidade.
##  - vision_aura: o visual da Vision em volta do Kaiser. Metavisão = RADAR circular azul (anel fixo + feixe
##    que gira); Olhar do Predador = CORTES DE GARRA dourados em volta. Nó filho do Kaiser, sem redesenho por quadro;
##  - draw_dash_preview: linha tracejada com seta (a prévia dos dashes do Path / Blitzkrieg / Blindheit).
## Quem chama passa um nó qualquer que já esteja na árvore (ex: o Kaiser) em "from".

const BLUE := Color(0.12, 0.28, 0.95)
const BLUE_LIGHT := Color(0.45, 0.68, 1.0)
const BLUE_DEEP := Color(0.07, 0.14, 0.62)
const PINK := Color(1.0, 0.45, 0.72)
const PINK_LIGHT := Color(1.0, 0.75, 0.88)
const PINK_DEEP := Color(0.85, 0.25, 0.55)

const _KEY_ROSE := &"kaiser_rose_tex"
const _KEY_PETAL := &"kaiser_petal_tex"
const _KEY_BLUE_PICK := &"kaiser_blue_pick"
const _KEY_PINK_PICK := &"kaiser_pink_pick"
const _KEY_FADE := &"kaiser_fade"

## Acima de tudo (jogadores e bola usam z_index = y como profundidade)
const FX_Z: int = 3000
## Camada no chão (esteira dos dashes, ondas): por cima do campo. Se o seu campo usar outra ordem, mude aqui.
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


## Rosa inteira com a flor para cima: botão em espiral (anéis vazados), cabo e dois espinhos, 22x34
static func rose_texture() -> ImageTexture:
	return _bake(_KEY_ROSE, 22, 34, func(p: Vector2) -> bool:
		var d: float = p.distance_to(Vector2(11.0, 9.0))
		# Botão: círculo com anéis vazados (dá o aspecto de pétalas enroladas)
		if d <= 8.0 and absf(d - 5.4) > 0.75 and absf(d - 2.4) > 0.6:
			return true
		# Cabo
		if p.x >= 10.2 and p.x <= 11.8 and p.y >= 16.0 and p.y <= 33.0:
			return true
		# Espinhos (um de cada lado)
		return _in_triangle(p, Vector2(11.0, 22.0), Vector2(17.0, 20.0), Vector2(11.0, 25.0)) \
			or _in_triangle(p, Vector2(11.0, 27.0), Vector2(5.0, 25.0), Vector2(11.0, 30.0)))


## Pétala (gota com a ponta para cima), 10x14
static func petal_texture() -> ImageTexture:
	return _bake(_KEY_PETAL, 10, 14, func(p: Vector2) -> bool:
		return p.distance_to(Vector2(5.0, 9.0)) <= 4.2 or _in_triangle(p, Vector2(5.0, 0.5), Vector2(1.0, 8.0), Vector2(9.0, 8.0)))


## Cada rosa nasce de um dos 3 tons de azul
static func _blue_pick() -> Gradient:
	if Engine.has_meta(_KEY_BLUE_PICK):
		return Engine.get_meta(_KEY_BLUE_PICK) as Gradient
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.4, 0.75])
	g.colors = PackedColorArray([BLUE, BLUE_LIGHT, BLUE_DEEP])
	Engine.set_meta(_KEY_BLUE_PICK, g)
	return g


## Cada pétala nasce de um dos 3 tons de rosa
static func _pink_pick() -> Gradient:
	if Engine.has_meta(_KEY_PINK_PICK):
		return Engine.get_meta(_KEY_PINK_PICK) as Gradient
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.4, 0.75])
	g.colors = PackedColorArray([PINK, PINK_LIGHT, PINK_DEEP])
	Engine.set_meta(_KEY_PINK_PICK, g)
	return g


static func _fade() -> Gradient:
	if Engine.has_meta(_KEY_FADE):
		return Engine.get_meta(_KEY_FADE) as Gradient
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	Engine.set_meta(_KEY_FADE, g)
	return g


static func _emitter(tex: Texture2D, pick: Gradient, amount: int, life: float, speed: float,
		smin: float, smax: float, spin: float, gravity: Vector2) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.color_initial_ramp = pick
	p.color_ramp = _fade()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector2.UP
	p.spread = 180.0
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


## Rosas azuis girando MUITO (spin alto)
static func _roses(amount: int, life: float, speed: float, smin: float, smax: float, spin: float = 900.0) -> CPUParticles2D:
	return _emitter(rose_texture(), _blue_pick(), amount, life, speed, smin, smax, spin, Vector2(0.0, 60.0))


## Pétalas rosas, mais leves: giram e caem devagar
static func _petals(amount: int, life: float, speed: float, smin: float, smax: float) -> CPUParticles2D:
	return _emitter(petal_texture(), _pink_pick(), amount, life, speed, smin, smax, 420.0, Vector2(0.0, 90.0))


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


static func _sphere(p: CPUParticles2D, radius: float) -> void:
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius


# ---------- EFEITOS ----------

## O visual da bola nos chutes de habilidade (rastro azul + partículas rosas). Passe no play_fx do kick_ball.
static func kick_style(strong: bool = false) -> KickFX:
	var fx := KickFX.new()
	fx.color = BLUE
	fx.trail_width = 20.0 if strong else 14.0
	fx.particle_color = PINK_LIGHT
	fx.amount = 30 if strong else 22
	fx.lifetime = 0.55
	fx.speed_min = 15.0
	fx.speed_max = 80.0 if strong else 70.0
	fx.gravity = Vector2(0.0, -40.0)
	fx.spin = 300.0
	fx.scale_min = 0.15
	fx.scale_max = 0.4 if strong else 0.35
	fx.burst_amount = 20 if strong else 14
	fx.burst_speed = 240.0
	return fx


## Explosão de rosas girando e pétalas rosas em volta de um ponto
static func rose_burst(from: Node, pos: Vector2, amount: int = 8, strong: bool = false) -> void:
	if not _ok(from):
		return
	var r: CPUParticles2D = _roses(amount, 0.8 if strong else 0.65, 300.0 if strong else 220.0, 0.7, 1.2 if strong else 1.0)
	_sphere(r, 8.0)
	_launch(from, r, pos)
	var p: CPUParticles2D = _petals(amount * 2, 0.9, 240.0 if strong else 170.0, 0.8, 1.3)
	_sphere(p, 10.0)
	_launch(from, p, pos)


## Só pétalas rosas
static func petals(from: Node, pos: Vector2, amount: int = 10) -> void:
	if not _ok(from):
		return
	var p: CPUParticles2D = _petals(amount, 0.9, 170.0, 0.8, 1.3)
	_sphere(p, 8.0)
	_launch(from, p, pos)


## Explosão em cone na direção do chute (a hora em que o pé acerta a bola)
static func kick_burst(from: Node, pos: Vector2, dir: Vector2, strong: bool = false) -> void:
	if not _ok(from):
		return
	var d: Vector2 = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	var r: CPUParticles2D = _roses(10 if strong else 7, 0.75, 360.0 if strong else 280.0, 0.7, 1.2)
	r.direction = d
	r.spread = 40.0
	_sphere(r, 8.0)
	_launch(from, r, pos)
	var p: CPUParticles2D = _petals(16 if strong else 10, 0.8, 300.0, 0.8, 1.3)
	p.direction = d
	p.spread = 60.0
	_sphere(p, 8.0)
	_launch(from, p, pos)


## Rosas girando e pétalas que acompanham a bola por "seconds" segundos (filhas do sprite dela: seguem a altura)
static func ball_roses(ball: Ball, seconds: float = 1.0, intense: bool = false) -> void:
	if ball == null or not ball.is_inside_tree():
		return
	var holder: Node = ball.sprite if ball.sprite != null else ball
	var list: Array[CPUParticles2D] = []
	var r: CPUParticles2D = _roses(8 if intense else 5, 0.7, 60.0, 0.45, 0.8, 1000.0)
	var p: CPUParticles2D = _petals(14 if intense else 9, 0.8, 50.0, 0.5, 0.9)
	for e: CPUParticles2D in [r, p]:
		e.explosiveness = 0.0
		_sphere(e, 6.0)
		list.append(e)
	for e: CPUParticles2D in list:
		holder.add_child(e)
		e.emitting = true
	var tree: SceneTree = ball.get_tree()
	tree.create_timer(seconds).timeout.connect(func() -> void:
		for e: CPUParticles2D in list:
			if is_instance_valid(e):
				e.emitting = false)
	tree.create_timer(seconds + 1.2).timeout.connect(func() -> void:
		for e: CPUParticles2D in list:
			if is_instance_valid(e):
				e.queue_free())


## Onda no chão: azul com um aro rosa
static func ring(from: Node, pos: Vector2, radius: float = 60.0) -> void:
	if not _ok(from):
		return
	var r := Ring.new(radius)
	_add(from, r)
	r.global_position = pos


## Esteira azul atrás do Kaiser durante os dashes, com rosas girando. Chame stop() quando o dash acabar.
static func dash_trail(who: Player, strong: bool = false) -> DashTrail:
	if not _ok(who):
		return null
	var t := DashTrail.new(who, strong)
	_add(who, t)
	return t


## Visual da Vision em volta do Kaiser (radar ou garras). Fica como filho dele: acompanha a altura e some junto.
## Troque com show_meta() / show_predator() / hide_all().
static func vision_aura(who: Player, radius: float = 44.0) -> VisionAura:
	if not _ok(who):
		return null
	var a := VisionAura.new(who, radius)
	who.add_child(a)
	return a


## Prévia tracejada de um caminho: "pts" são pontos LOCAIS do nó "canvas" (chame de dentro do _draw dele).
## Os tracinhos andam para a frente, e a ponta tem uma seta. Pede redesenho por quadro enquanto a mira estiver aberta.
static func draw_dash_preview(canvas: CanvasItem, pts: Array[Vector2], color: Color = BLUE_LIGHT) -> void:
	if canvas == null or pts.size() < 2:
		return
	var dash: float = 12.0
	var period: float = dash + 9.0
	var travelled: float = -fmod(float(Time.get_ticks_msec()) * 0.06, period)   # tracinhos "marchando"
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var seg_len: float = a.distance_to(b)
		if seg_len < 0.5:
			continue
		var dir: Vector2 = (b - a) / seg_len
		var d: float = 0.0
		while d < seg_len:
			var phase: float = fposmod(travelled + d, period)
			if phase < dash:
				var d_end: float = minf(d + (dash - phase), seg_len)
				canvas.draw_line(a + dir * d, a + dir * d_end, Color(color, 0.9), 3.0, true)
				d = d_end + 0.01
			else:
				d += period - phase
		travelled += seg_len
		if i < pts.size() - 1:
			canvas.draw_circle(b, 4.0, Color(color, 0.8))   # curva / vértice do caminho
	# Seta na ponta
	var last: Vector2 = pts[pts.size() - 1]
	var back: Vector2 = pts[pts.size() - 2]
	var tip_dir: Vector2 = (last - back).normalized() if last.distance_to(back) > 0.5 else Vector2.RIGHT
	var side: Vector2 = tip_dir.orthogonal() * 9.0
	canvas.draw_colored_polygon(PackedVector2Array([last + tip_dir * 12.0, last + side - tip_dir * 4.0,
		last - side - tip_dir * 4.0]), Color(color, 0.95))


# ---------- VISION EM VOLTA DO KAISER ----------

## Desenhos estáticos da Vision (feitos UMA vez; o movimento vem de rotation / modulate / scale, sem redesenhar)
class AuraShape extends Node2D:
	enum Kind { RADAR_FACE, RADAR_SWEEP, CLAWS }
	const GOLD := Color(0.816, 0.655, 0.0)
	const SWEEP_ANGLE: float = 1.2   # largura (rad) do rastro do feixe do radar
	var kind: Kind = Kind.RADAR_FACE
	var radius: float = 44.0

	func _init(k: Kind = Kind.RADAR_FACE, r: float = 44.0) -> void:
		kind = k
		radius = r

	func _draw() -> void:
		match kind:
			Kind.RADAR_FACE:
				_draw_radar_face()
			Kind.RADAR_SWEEP:
				_draw_radar_sweep()
			Kind.CLAWS:
				_draw_claws()

	## Radar: círculo, anel interno, mira em cruz e quatro marcas na borda
	func _draw_radar_face() -> void:
		var c: Color = KaiserFX.BLUE_LIGHT
		draw_circle(Vector2.ZERO, radius, Color(KaiserFX.BLUE, 0.08))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(c, 0.9), 2.5, true)
		draw_arc(Vector2.ZERO, radius * 0.6, 0.0, TAU, 36, Color(c, 0.3), 1.5, true)
		draw_line(Vector2(-radius, 0.0), Vector2(radius, 0.0), Color(c, 0.18), 1.0)
		draw_line(Vector2(0.0, -radius), Vector2(0.0, radius), Color(c, 0.18), 1.0)
		for i in 4:
			var d: Vector2 = Vector2.from_angle(TAU * float(i) / 4.0 + PI * 0.25)
			draw_line(d * (radius - 7.0), d * radius, Color(c, 0.9), 2.5)
		draw_circle(Vector2.ZERO, 2.5, Color(c, 0.8))

	## Feixe do radar apontando para +x (o nó gira): leque que vai sumindo atrás da linha da frente
	func _draw_radar_sweep() -> void:
		var slices: int = 8
		for i in slices:
			var a0: float = -SWEEP_ANGLE + SWEEP_ANGLE * float(i) / float(slices)
			var a1: float = -SWEEP_ANGLE + SWEEP_ANGLE * float(i + 1) / float(slices)
			var k: float = float(i + 1) / float(slices)
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a0) * radius,
				Vector2.from_angle(a1) * radius]), Color(KaiserFX.BLUE_LIGHT, 0.04 + 0.3 * k))
		draw_line(Vector2.ZERO, Vector2(radius, 0.0), Color(KaiserFX.BLUE_LIGHT, 0.95), 2.0, true)
		draw_circle(Vector2(radius * 0.78, 0.0), 3.0, Color(KaiserFX.PINK_LIGHT, 0.95))   # ponto brilhante no feixe

	## Garras: 4 marcas de 3 cortes em volta (nas diagonais), cada corte afilado nas pontas
	func _draw_claws() -> void:
		var cut_len: float = 30.0
		var cut_w: float = 3.4
		for g in 4:
			var ang: float = TAU * (float(g) + 0.5) / 4.0
			var center: Vector2 = Vector2.from_angle(ang) * (radius + 2.0)
			var u: Vector2 = Vector2.from_angle(ang + PI * 0.5 + 0.55)   # direção dos cortes (diagonal)
			var n: Vector2 = u.orthogonal()
			for k in 3:
				var off: Vector2 = n * (float(k) - 1.0) * 8.0
				var len_k: float = cut_len * (1.0 if k == 1 else 0.82)
				var left: PackedVector2Array = PackedVector2Array()
				var right: PackedVector2Array = PackedVector2Array()
				for s in 5:
					var t: float = float(s) / 4.0
					var w: float = cut_w * sin(PI * t)
					var pt: Vector2 = center + off + u * (t - 0.5) * len_k
					left.append(pt + n * w * 0.5)
					right.append(pt - n * w * 0.5)
				right.reverse()
				left.append_array(right)
				draw_colored_polygon(left, GOLD)


## Visual da Vision: nó filho do Kaiser que fica ATRÁS dele (como o anel antigo).
## Metavisão = radar circular com um feixe girando; Olhar do Predador = cortes de garra dourados em volta.
class VisionAura extends Node2D:
	enum Mode { NONE, META, PREDATOR }
	var who: Player = null
	var radius: float = 44.0
	var _mode: Mode = Mode.NONE
	var _face: AuraShape = null
	var _sweep: AuraShape = null
	var _claws: AuraShape = null
	var _t: float = 0.0
	var _pop: float = 1.0   # animação de entrada (0 -> 1)

	# Valores padrão: se o Kaiser for duplicado, o Godot pode recriar este nó sem argumentos
	func _init(p: Player = null, r: float = 44.0) -> void:
		who = p
		radius = r
		show_behind_parent = true
		visible = false

	func _ready() -> void:
		if who == null:
			who = get_parent() as Player
		_face = AuraShape.new(AuraShape.Kind.RADAR_FACE, radius)
		_sweep = AuraShape.new(AuraShape.Kind.RADAR_SWEEP, radius)
		_claws = AuraShape.new(AuraShape.Kind.CLAWS, radius)
		for s: AuraShape in [_face, _sweep, _claws]:
			s.visible = false
			add_child(s)
		set_process(false)
		_apply_mode()

	func show_meta() -> void:
		_set_mode(Mode.META)

	func show_predator() -> void:
		_set_mode(Mode.PREDATOR)

	func hide_all() -> void:
		_set_mode(Mode.NONE)

	func _set_mode(m: Mode) -> void:
		if m == _mode:
			return
		_mode = m
		_pop = 0.0
		_apply_mode()

	func _apply_mode() -> void:
		visible = _mode != Mode.NONE
		set_process(_mode != Mode.NONE)
		if _face == null:
			return   # ainda antes do _ready: ele chama _apply_mode de novo
		_face.visible = _mode == Mode.META
		_sweep.visible = _mode == Mode.META
		_claws.visible = _mode == Mode.PREDATOR

	func _process(delta: float) -> void:
		if not is_instance_valid(who):
			return
		position = Vector2(0.0, -who.height)   # acompanha o corpo quando ele pula
		_t += delta
		_pop = move_toward(_pop, 1.0, delta * 4.0)
		var grow: float = lerpf(1.35, 1.0, ease(_pop, 0.4))
		if _mode == Mode.META:
			_sweep.rotation += TAU * delta / 2.5   # uma volta a cada 2,5 s
			_face.scale = Vector2(grow, grow)
			_sweep.scale = Vector2(grow, grow)
			_face.modulate.a = _pop
			_sweep.modulate.a = _pop
		elif _mode == Mode.PREDATOR:
			_claws.scale = Vector2(grow, grow)
			_claws.modulate.a = _pop * (0.82 + 0.18 * sin(_t * 5.0))   # pulsa de leve


# ---------- ONDA NO CHÃO ----------

class Ring extends Node2D:
	var radius: float = 60.0
	var _t: float = 0.0

	func _init(r: float) -> void:
		radius = r
		z_as_relative = false
		z_index = KaiserFX.GROUND_Z

	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.7:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))   # achatado: vemos o chão de cima, em perspectiva
		for i in 2:
			var u: float = clampf(_t / 0.7 - float(i) * 0.2, 0.0, 1.0)
			if u <= 0.0:
				continue
			var col: Color = KaiserFX.BLUE if i == 0 else KaiserFX.PINK
			draw_arc(Vector2.ZERO, radius * (0.2 + 0.8 * u), 0.0, TAU, 40,
				Color(col, 0.85 * (1.0 - u)), 4.0 * (1.0 - u) + 1.5, true)


# ---------- ESTEIRA DOS DASHES ----------

class DashTrail extends Node2D:
	var who: Player
	var strong: bool = false
	var _pts: Array[Vector2] = []
	var _ages: Array[float] = []
	var _emitters: Array[CPUParticles2D] = []
	var _stopping: bool = false
	var _gone_t: float = 0.0
	var _last_feet: Vector2 = Vector2.ZERO
	const LIFE: float = 0.4

	func _init(p: Player, is_strong: bool) -> void:
		who = p
		strong = is_strong
		_last_feet = p.global_position
		top_level = true
		z_as_relative = false
		z_index = KaiserFX.GROUND_Z + 10

	func _ready() -> void:
		global_position = who.global_position
		var r: CPUParticles2D = KaiserFX._roses(6 if strong else 4, 0.7, 110.0, 0.5, 0.9, 1000.0)
		var p: CPUParticles2D = KaiserFX._petals(14 if strong else 9, 0.8, 90.0, 0.6, 1.0)
		for e: CPUParticles2D in [r, p]:
			e.position = Vector2(0.0, -8.0)
			e.explosiveness = 0.0
			KaiserFX._sphere(e, 10.0)
			e.emitting = false
			add_child(e)
			_emitters.append(e)

	## O dash acabou: para de soltar; o que já saiu vai sumindo sozinho
	func stop() -> void:
		_stopping = true
		for e: CPUParticles2D in _emitters:
			e.emitting = false

	func _process(delta: float) -> void:
		if not is_instance_valid(who):
			queue_free()
			return
		var feet: Vector2 = who.global_position
		var moved: bool = feet.distance_to(_last_feet) > 1.0   # só solta enquanto ele anda
		_last_feet = feet
		global_position = feet
		if not _stopping:
			if moved:
				_pts.append(feet)
				_ages.append(0.0)
			for e: CPUParticles2D in _emitters:
				e.emitting = moved
		for i in range(_ages.size() - 1, -1, -1):
			_ages[i] += delta
			if _ages[i] > LIFE:
				_pts.remove_at(i)
				_ages.remove_at(i)
		if _stopping:
			_gone_t += delta
			if _gone_t > LIFE + 0.8:
				queue_free()
				return
		queue_redraw()

	func _draw() -> void:
		var n: int = _pts.size()
		for i in range(1, n):
			var k: float = 1.0 - ((_ages[i - 1] + _ages[i]) * 0.5) / LIFE
			if k <= 0.0:
				continue
			var a: Vector2 = to_local(_pts[i - 1])
			var b: Vector2 = to_local(_pts[i])
			var w: float = (24.0 if strong else 18.0) * k
			draw_line(a, b, Color(KaiserFX.BLUE_DEEP, 0.6 * k), w, true)
			draw_line(a, b, Color(KaiserFX.BLUE, 0.85 * k), w * 0.6, true)
			draw_line(a, b, Color(KaiserFX.BLUE_LIGHT, 0.9 * k), w * 0.25, true)
			draw_line(a + Vector2(0.0, -w * 0.5), b + Vector2(0.0, -w * 0.5), Color(KaiserFX.PINK, 0.7 * k), 2.0, true)
