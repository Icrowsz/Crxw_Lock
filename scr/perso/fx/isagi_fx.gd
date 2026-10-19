class_name IsagiFX
extends RefCounted
## Efeitos visuais das habilidades do Isagi: PEÇAS DE QUEBRA-CABEÇA azul-escuras e azul-claras.
## Tudo por código (nenhuma imagem): a peça é desenhada uma única vez numa textura 32x32 branca e
## o azul vem da cor da partícula, que sorteia entre o escuro e o claro.
##
## Pensado para ser leve:
##  - uma textura e dois degradês compartilhados (criados uma vez e guardados no Engine);
##  - um CPUParticles2D por efeito, "one_shot", com poucas partículas (8 a 22) e vida curta;
##  - cada efeito se apaga sozinho; o único emissor contínuo é a aura, que fica desligada
##    (emitting = false) quando não está em uso;
##  - sem som, sem luz, sem mistura aditiva e sem código rodando por quadro.
##
## Quem chama passa um nó qualquer que já esteja na árvore (ex: o Isagi) em "from".

const DARK := Color(0.07, 0.20, 0.66)    # azul escuro
const LIGHT := Color(0.55, 0.86, 1.0)    # azul claro

const _KEY_TEX := &"isagi_puzzle_tex"
const _KEY_PICK := &"isagi_puzzle_pick"
const _KEY_FADE := &"isagi_puzzle_fade"


# ---------- RECURSOS COMPARTILHADOS ----------

## A peça de quebra-cabeça (corpo quadrado, 2 encaixes para fora e 2 buracos), branca, 32x32
static func puzzle_texture() -> ImageTexture:
	if Engine.has_meta(_KEY_TEX):
		return Engine.get_meta(_KEY_TEX) as ImageTexture
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var hits: int = 0
			for sy in 3:   # 3x3 amostras por pixel: borda suave
				for sx in 3:
					if _inside(Vector2(float(x) + (float(sx) + 0.5) / 3.0, float(y) + (float(sy) + 0.5) / 3.0)):
						hits += 1
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, float(hits) / 9.0))
	var tex := ImageTexture.create_from_image(img)
	Engine.set_meta(_KEY_TEX, tex)
	return tex


static func _inside(p: Vector2) -> bool:
	var body: bool = p.x >= 8.0 and p.x < 24.0 and p.y >= 8.0 and p.y < 24.0
	var knob_top: bool = p.distance_to(Vector2(16.0, 6.5)) <= 4.2
	var knob_right: bool = p.distance_to(Vector2(25.5, 16.0)) <= 4.2
	var hole_left: bool = p.distance_to(Vector2(8.0, 16.0)) <= 3.8
	var hole_bottom: bool = p.distance_to(Vector2(16.0, 24.0)) <= 3.8
	return (body or knob_top or knob_right) and not (hole_left or hole_bottom)


## Cada peça nasce azul escura OU azul clara (sorteio: degrau no meio do degradê)
static func _pick_ramp() -> Gradient:
	if Engine.has_meta(_KEY_PICK):
		return Engine.get_meta(_KEY_PICK) as Gradient
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.5])
	g.colors = PackedColorArray([DARK, LIGHT])
	Engine.set_meta(_KEY_PICK, g)
	return g


## Fica inteira e some no final da vida
static func _fade_ramp() -> Gradient:
	if Engine.has_meta(_KEY_FADE):
		return Engine.get_meta(_KEY_FADE) as Gradient
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	Engine.set_meta(_KEY_FADE, g)
	return g


static func _make(amount: int, lifetime: float, speed: float, size_min: float, size_max: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = puzzle_texture()
	p.color_initial_ramp = _pick_ramp()
	p.color_ramp = _fade_ramp()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false          # as peças ficam no campo e não acompanham quem as soltou
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.9     # desaceleram e flutuam
	p.damping_max = speed * 1.2
	p.gravity = Vector2(0.0, -28.0)   # sobem devagar, como as partículas do chute
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -240.0
	p.angular_velocity_max = 240.0
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	p.z_index = 3000   # acima de tudo (jogadores e bola usam z_index = y como profundidade)
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


# ---------- EFEITOS ----------

## Explosão de peças em volta de um ponto do campo. strong = mais peças, maiores e mais longe.
static func burst(from: Node, pos: Vector2, amount: int = 10, strong: bool = false) -> void:
	if not _ok(from):
		return
	var p := _make(amount, 0.8 if strong else 0.65, 170.0 if strong else 120.0,
		0.45 if strong else 0.35, 0.8 if strong else 0.6)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 18.0 if strong else 12.0
	_launch(from, p, pos)


## Anel de peças que se abre em volta de um ponto (ativações)
static func ring(from: Node, pos: Vector2, radius: float, amount: int = 14) -> void:
	if not _ok(from):
		return
	var p := _make(amount, 0.9, 60.0, 0.4, 0.7)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = radius
	p.radial_accel_min = 20.0
	p.radial_accel_max = 60.0
	_launch(from, p, pos)


## Peças que nascem ao longo de uma linha (passe forçado, avanço, bola sendo puxada)
static func line(from: Node, a: Vector2, b: Vector2, amount: int = 12) -> void:
	if not _ok(from):
		return
	var p := _make(amount, 0.75, 50.0, 0.35, 0.6)
	var pts := PackedVector2Array()
	var samples: int = maxi(amount * 2, 4)
	for i in samples:
		pts.append((b - a) * (float(i) / float(samples - 1)))
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = pts
	_launch(from, p, a)


## Peças espalhadas por uma área retangular (as peças do campo do Pieces)
static func area(from: Node, center: Vector2, size: Vector2, amount: int = 16) -> void:
	if not _ok(from):
		return
	var p := _make(amount, 1.1, 40.0, 0.5, 0.85)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = size * 0.5
	_launch(from, p, center)


## Peças que acompanham a bola por "seconds" segundos (filho do sprite dela: segue a altura)
static func trail(ball: Ball, seconds: float = 0.5) -> void:
	if ball == null or not ball.is_inside_tree():
		return
	var p := _make(14, 0.55, 40.0, 0.3, 0.5)
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


## Aura contínua em volta do personagem (Metavision / See It). Vira filho do Isagi e começa
## DESLIGADA; quem a criou liga e desliga com "emitting".
static func make_aura(radius: float = 30.0) -> CPUParticles2D:
	var p := _make(8, 1.4, 22.0, 0.3, 0.5)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.gravity = Vector2(0.0, -18.0)
	p.emitting = false
	return p
