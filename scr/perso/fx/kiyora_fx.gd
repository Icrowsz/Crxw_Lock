class_name KiyoraFX
extends RefCounted
## Efeitos visuais das habilidades do Kiyora: FAÍSCAS e NOTAS MUSICAIS azul-esverdeadas (dança, breakdance e
## ritmo), anéis de batida no chão, imagens residuais dos dashes e o rodopio da bola (Backspin).
## Tudo por código (nenhuma imagem): a faísca e a nota são desenhadas uma única vez numa textura 32x32
## branca e a cor vem da partícula, que sorteia entre dois tons (azul-esverdeado / menta).
##
## Pensado para ser leve, igual ao hiori_fx.gd:
##  - duas texturas e dois degradês compartilhados (criados uma vez e guardados no Engine);
##  - poucos CPUParticles2D "one_shot" por efeito, com poucas partículas e vida curta;
##  - cada efeito se apaga sozinho; o único emissor contínuo é a aura, que fica desligada
##    (emitting = false) quando não está em uso;
##  - sem som, sem luz, sem mistura aditiva; os desenhos animados usam Tween (nada de _process).
##
## Quem chama passa um nó qualquer que já esteja na árvore (ex: o Kiyora) em "from".
##
## Resumo:
##   burst / ring / line / notes / trail -> partículas (faíscas e notas)
##   beat(from, pos)                     -> anéis de batida que se abrem no chão (ritmo / Dance Battle)
##   dash(from, quem, a, b)              -> imagem residual + riscos de velocidade (Six-Step, Twister, Windmill)
##   spin_mark(ball)                     -> arcos girando em volta da bola (freadas e rodopios do Backspin)
##   slip(from, pos)                     -> brilho curto quando a bola ignora um obstáculo
##   attach_wind(quem)                   -> redemoinho de vento girando em volta dele (Dance Battle); devolve o nó
##   make_aura()                         -> faíscas contínuas em volta dele enquanto o Backspin vale

const TEAL := Color(0.05, 0.30, 0.38)          # azul escuro esverdeado
const TEAL_LIGHT := Color(0.28, 0.68, 0.64)    # azul-esverdeado claro
const MINT := Color(0.78, 0.98, 0.92)          # menta (brilho)

const _KEY_SPARK := &"kiyora_spark_tex"
const _KEY_NOTE := &"kiyora_note_tex"
const _KEY_PICK := &"kiyora_pick"
const _KEY_FADE := &"kiyora_fade"


# ---------- RECURSOS COMPARTILHADOS ----------

## Cria as texturas já no começo (o Kiyora chama no _ready) para não travar na primeira habilidade
static func warm_up() -> void:
	spark_texture()
	note_texture()


## Faísca de 4 pontas (estrela fina), branca, 32x32
static func spark_texture() -> ImageTexture:
	if Engine.has_meta(_KEY_SPARK):
		return Engine.get_meta(_KEY_SPARK) as ImageTexture
	var poly := PackedVector2Array([Vector2(16.0, 1.0), Vector2(19.0, 13.0), Vector2(31.0, 16.0), Vector2(19.0, 19.0),
		Vector2(16.0, 31.0), Vector2(13.0, 19.0), Vector2(1.0, 16.0), Vector2(13.0, 13.0)])
	var tex := _rasterize(func(p: Vector2) -> bool: return Geometry2D.is_point_in_polygon(p, poly))
	Engine.set_meta(_KEY_SPARK, tex)
	return tex


## Colcheia (nota musical), branca, 32x32
static func note_texture() -> ImageTexture:
	if Engine.has_meta(_KEY_NOTE):
		return Engine.get_meta(_KEY_NOTE) as ImageTexture
	var flag := PackedVector2Array([Vector2(17.0, 5.0), Vector2(26.0, 11.0), Vector2(26.0, 17.0), Vector2(17.0, 11.0)])
	var tex := _rasterize(func(p: Vector2) -> bool:
		var q: Vector2 = p - Vector2(11.0, 24.0)   # cabeça da nota: elipse
		if (q.x * q.x) / 41.0 + (q.y * q.y) / 22.0 <= 1.0:
			return true
		if p.x >= 15.5 and p.x <= 18.0 and p.y >= 5.0 and p.y <= 24.0:   # haste
			return true
		return Geometry2D.is_point_in_polygon(p, flag))
	Engine.set_meta(_KEY_NOTE, tex)
	return tex


## Desenha uma máscara 32x32 com 2x2 amostras por pixel (borda suave)
static func _rasterize(inside: Callable) -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var hits: int = 0
			for sy in 2:
				for sx in 2:
					if inside.call(Vector2(float(x) + (float(sx) + 0.5) / 2.0, float(y) + (float(sy) + 0.5) / 2.0)):
						hits += 1
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, float(hits) / 4.0))
	return ImageTexture.create_from_image(img)


## Sorteio entre dois tons (degrau no meio do degradê)
static func _pick_ramp() -> Gradient:
	if Engine.has_meta(_KEY_PICK):
		return Engine.get_meta(_KEY_PICK) as Gradient
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.5])
	g.colors = PackedColorArray([TEAL_LIGHT, MINT])
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


static func _make(tex: Texture2D, amount: int, lifetime: float, speed: float,
		size_min: float, size_max: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.color_initial_ramp = _pick_ramp()
	p.color_ramp = _fade_ramp()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false          # ficam no campo e não acompanham quem as soltou
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.9
	p.damping_max = speed * 1.2
	p.gravity = Vector2(0.0, -30.0)   # sobem devagar, como as partículas dos chutes
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -240.0
	p.angular_velocity_max = 240.0
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	p.z_index = 3000   # acima de tudo (jogadores e bola usam z_index = y como profundidade)
	p.z_as_relative = false
	return p


static func _spark(amount: int, lifetime: float, speed: float, size_min: float = 0.3, size_max: float = 0.6) -> CPUParticles2D:
	return _make(spark_texture(), amount, lifetime, speed, size_min, size_max)


## Notas: sobem balançando devagar, sem girar muito
static func _note(amount: int, lifetime: float) -> CPUParticles2D:
	var p := _make(note_texture(), amount, lifetime, 40.0, 0.4, 0.7)
	p.gravity = Vector2(0.0, -55.0)
	p.angle_min = -20.0
	p.angle_max = 20.0
	p.angular_velocity_min = -40.0
	p.angular_velocity_max = 40.0
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


## Onde ficam os efeitos de CHÃO: dentro do campo, acima do desenho dele e abaixo de quem usa o y como profundidade
static func _ground_parent(from: Node) -> Node:
	var field: Node = from.get_tree().get_first_node_in_group("field")
	if field != null:
		return field
	var scene: Node = from.get_tree().current_scene
	return scene if scene != null else from


# ---------- EFEITOS DE PARTÍCULAS ----------

## Explosão de faíscas em volta de um ponto. strong = mais, maiores e mais longe.
static func burst(from: Node, pos: Vector2, amount: int = 10, strong: bool = false) -> void:
	if not _ok(from):
		return
	var p := _spark(amount, 0.7 if strong else 0.55, 200.0 if strong else 140.0, 0.35, 0.7 if strong else 0.55)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 12.0 if strong else 7.0
	_launch(from, p, pos)


## Anel de faíscas que se abre em volta de um ponto (ativações)
static func ring(from: Node, pos: Vector2, radius: float, amount: int = 14) -> void:
	if not _ok(from):
		return
	var p := _spark(amount, 0.8, 60.0, 0.3, 0.55)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = radius
	p.radial_accel_min = 20.0
	p.radial_accel_max = 60.0
	_launch(from, p, pos)


## Faíscas que nascem ao longo de uma linha (passe, dash, bola sendo puxada)
static func line(from: Node, a: Vector2, b: Vector2, amount: int = 12) -> void:
	if not _ok(from):
		return
	var p := _spark(amount, 0.6, 40.0, 0.25, 0.5)
	var pts := PackedVector2Array()
	var samples: int = maxi(amount * 2, 4)
	for i in samples:
		pts.append((b - a) * (float(i) / float(samples - 1)))
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = pts
	_launch(from, p, a)


## Notas musicais que sobem em volta de um ponto (Breakdance, jogo de ritmo)
static func notes(from: Node, pos: Vector2, amount: int = 6) -> void:
	if not _ok(from):
		return
	var p := _note(amount, 1.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 22.0
	_launch(from, p, pos)


## Faíscas que acompanham a bola por "seconds" segundos (filho do sprite dela: segue a altura)
static func trail(ball: Ball, seconds: float = 0.5) -> void:
	if ball == null or not ball.is_inside_tree():
		return
	var p := _spark(12, 0.5, 35.0, 0.25, 0.45)
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


## Faíscas contínuas em volta do personagem (Backspin ativo). Vira filho do Kiyora e começa DESLIGADA;
## quem a criou liga e desliga com "emitting".
static func make_aura(radius: float = 26.0) -> CPUParticles2D:
	var p := _spark(8, 1.2, 20.0, 0.25, 0.45)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.gravity = Vector2(0.0, -18.0)
	p.emitting = false
	return p


# ---------- RITMO E MOVIMENTO ----------

## Anéis de batida que se abrem no chão (um atrás do outro). strong = maiores.
static func beat(from: Node, pos: Vector2, rings: int = 2, strong: bool = false) -> void:
	if not _ok(from):
		return
	var parent: Node = _ground_parent(from)
	for i in rings:
		var holder := BeatRing.new()
		holder.z_index = -4000   # acima do campo (-4096), abaixo de tudo que usa a profundidade pelo y
		holder.z_as_relative = false
		parent.add_child(holder)
		holder.global_position = pos
		holder.scale = Vector2(0.15, 0.09)
		holder.modulate.a = 0.0
		var big: float = 1.9 if strong else 1.3
		var tw: Tween = holder.create_tween()
		if i > 0:
			tw.tween_interval(0.12 * float(i))
		tw.tween_property(holder, "modulate:a", 0.9, 0.05)
		tw.tween_property(holder, "scale", Vector2(big, big * 0.6), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(holder, "modulate:a", 0.0, 0.45).set_delay(0.05)
		tw.tween_callback(holder.queue_free)


## Dash curto: imagem residual onde ele estava + riscos de velocidade + faíscas no caminho
static func dash(from: Node, who: Node2D, a: Vector2, b: Vector2) -> void:
	if not _ok(from) or a.distance_to(b) < 1.0:
		return
	line(from, a, b, 8)
	var scene: Node = from.get_tree().current_scene
	var parent: Node = scene if scene != null else from
	# imagem residual (silhueta que some)
	var radius: float = 18.0
	if who != null and is_instance_valid(who) and who.get("placeholder_radius") != null:
		radius = float(who.get("placeholder_radius"))
	var ghost := Afterimage.new()
	ghost.radius = radius
	ghost.z_index = int(a.y) - 1
	ghost.z_as_relative = false
	parent.add_child(ghost)
	ghost.global_position = a
	ghost.modulate.a = 0.55
	var tw: Tween = ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tw.tween_callback(ghost.queue_free)
	# dois riscos finos paralelos ao caminho
	var holder := Node2D.new()
	holder.z_index = 3000
	holder.z_as_relative = false
	parent.add_child(holder)
	var side: Vector2 = (b - a).normalized().orthogonal() * (radius * 0.5)
	for k in [-1.0, 1.0]:
		var l := Line2D.new()
		l.points = PackedVector2Array([a + side * float(k), b + side * float(k) * 0.4])
		l.width = 3.0
		l.default_color = Color(MINT, 0.75)
		l.begin_cap_mode = Line2D.LINE_CAP_ROUND
		l.end_cap_mode = Line2D.LINE_CAP_ROUND
		holder.add_child(l)
	var tw2: Tween = holder.create_tween()
	tw2.tween_property(holder, "modulate:a", 0.0, 0.25)
	tw2.tween_callback(holder.queue_free)


## Arcos girando em volta da bola (freada / rodopio do Backspin). Filho do sprite: segue a altura.
static func spin_mark(ball: Ball, seconds: float = 0.4) -> void:
	if ball == null or not ball.is_inside_tree():
		return
	var mark := SpinMark.new()
	mark.z_index = 5
	var holder: Node = ball.sprite if ball.sprite != null else ball
	holder.add_child(mark)
	var tw: Tween = mark.create_tween().set_parallel(true)
	tw.tween_property(mark, "rotation", TAU * 1.5, seconds)
	tw.tween_property(mark, "modulate:a", 0.0, seconds).set_delay(seconds * 0.4)
	tw.chain().tween_callback(mark.queue_free)


## Brilho curto onde a bola passou direto por um obstáculo
static func slip(from: Node, pos: Vector2) -> void:
	if not _ok(from):
		return
	ring(from, pos, 14.0, 8)
	burst(from, pos, 6)


## Redemoinho de vento em volta de um nó (filho dele: acompanha). Gira sozinho até quem o criou apagar.
static func attach_wind(who: Node2D) -> Node2D:
	if not _ok(who):
		return null
	var wind := WindSwirl.new()
	wind.position = Vector2(0.0, -20.0)
	wind.z_index = 2
	who.add_child(wind)
	return wind


# ---------- CLASSES DE DESENHO ----------

## Quatro arcos curvos em 3 anéis (elípticos) que giram: o vento da dança. Um único nó, redesenhado por quadro.
class WindSwirl extends Node2D:
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))   # elipse: visão 2.5D
		for ring in 3:
			var r: float = 30.0 + float(ring) * 9.0
			var dir: float = 1.0 if ring % 2 == 0 else -1.0
			var base: float = _t * 6.0 * dir + float(ring) * 1.3
			for k in 2:
				var a0: float = base + PI * float(k)
				draw_arc(Vector2.ZERO, r, a0, a0 + 1.6, 14, Color(KiyoraFX.MINT, 0.7 - 0.15 * float(ring)), 2.5 - 0.5 * float(ring) * 0.5)


## Anel do chão (desenhado uma vez; o tamanho e o sumiço são animados por Tween)
class BeatRing extends Node2D:
	func _draw() -> void:
		draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 40, Color(KiyoraFX.TEAL_LIGHT, 0.9), 3.0)
		draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 40, Color(KiyoraFX.MINT, 0.6), 1.5)


## Silhueta simples (corpo + cabeça) deixada para trás num dash
class Afterimage extends Node2D:
	var radius: float = 18.0

	func _draw() -> void:
		var col := Color(KiyoraFX.TEAL_LIGHT, 0.85)
		draw_circle(Vector2(0.0, -radius), radius * 0.95, col)
		draw_circle(Vector2(0.0, -radius * 2.3), radius * 0.55, col)


## Três arcos que giram em volta da bola
class SpinMark extends Node2D:
	func _draw() -> void:
		for i in 3:
			var a0: float = TAU * float(i) / 3.0
			draw_arc(Vector2.ZERO, 20.0, a0, a0 + 1.5, 10, Color(KiyoraFX.MINT, 0.9), 2.5)
