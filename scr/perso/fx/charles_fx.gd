class_name CharlesFX
extends RefCounted
## Efeitos visuais do Charles: FOGO TURQUESA em labaredas curvas com detalhes amarelo-laranja, fumaça escura em fios e
## brilhos (chutes e passes), diabinhos de PM, balão de fala dos
## desvios, o CARROSSEL/radar da Metavision e as MINAS TERRESTRES amarelas do Playful Trap.
## Tudo por código (nenhuma imagem): faísca e fumaça de fogo são desenhadas uma única vez em texturas brancas e a
## cor vem da partícula. Os efeitos "vivos" (mina, carrossel, balão, onda) são nós pequenos que se apagam sozinhos.
##
## Leve, como o do Niko e o do Hiori:
##  - texturas (faísca, bolinha, labareda, fio de fumaça), degradê e material aditivo compartilhados (criados uma vez e guardados no Engine);
##  - poucos CPUParticles2D "one_shot" por efeito, com poucas partículas e vida curta;
##  - o carrossel só desenha enquanto a Metavision está ligada.
##
## O que cada coisa é:
##  - kick_fx() / charged_fx(): rastro de fogo turquesa com brilhos amarelos (KickFX dos chutes/passes)
##  - flame() / trail():         labaredas turquesa (+ amarelo-laranja, fumaça e brilhos) numa explosão / seguindo a bola
##  - draw_pm_marks():           os diabinhos 😈 amarelos de PM ao lado do Charles (chamar dentro do _draw)
##  - draw_devil():              desenha UM diabinho amarelo (usado pelas marcas de PM, pela barra de PM e pelo mark())
##  - mark() / unmark():         marca de diabinho flutuando sobre quem foi afetado por uma bomba ou marcado por um passe
##  - speech():                  balão de fala em cima do Charles ("ez", "easy", "too slow", "zzz..")
##  - make_carousel():           o carrossel/radar translúcido da Metavision (filho do Charles)
##  - mine() / boom():           a mina amarela de baixa opacidade e a explosão dela (cada explosão, uma cor)
##  - scare():                   a onda de susto da Mischievous Genius (4 PM)
##
## Quem chama passa um nó qualquer que já esteja na árvore (ex: o Charles) em "from".

const YELLOW := Color(1.0, 0.85, 0.2)          # o amarelo de sempre do Charles
const YELLOW_LIGHT := Color(1.0, 0.95, 0.55)
const BLUE := Color(0.35, 0.65, 1.0)           # faíscas azuis
const BLUE_DEEP := Color(0.15, 0.3, 0.8)
const ORANGE := Color(1.0, 0.55, 0.1)          # detalhe quente das labaredas
const CYAN := Color(0.1, 0.9, 1.0)             # o corpo do fogo (turquesa vivo)
const CYAN_LIGHT := Color(0.65, 1.0, 1.0)      # núcleo claro e brilhos
const SMOKE := Color(0.04, 0.06, 0.1)          # fumaça preta em fios
const RED_LINE := Color(0.85, 0.2, 0.15)       # contorno do diabinho nos inimigos afetados

## Cores das explosões das minas: cada explosão pega a próxima da fila (embaralhada), então não repetem
const BOOM_COLORS: Array[Color] = [
	Color(1.0, 0.35, 0.3), Color(0.3, 0.9, 1.0), Color(0.95, 0.4, 1.0), Color(0.55, 1.0, 0.4),
	Color(1.0, 0.65, 0.15), Color(0.6, 0.5, 1.0), Color(1.0, 0.5, 0.75), Color(1.0, 1.0, 1.0)]

const _KEY_SPARK := &"charles_spark_tex"
const _KEY_PUFF := &"charles_puff_tex"
const _KEY_FADE := &"charles_fade"
const _KEY_FLAME := &"charles_flame_tex"
const _KEY_WISP := &"charles_wisp_tex"
const _KEY_ADD := &"charles_add_mat"

static var _boom_bag: Array[Color] = []
static var _last_boom: Color = Color.BLACK


# ---------- ESTILO DO CHUTE / PASSE (KickFX) ----------

## Fogo turquesa grande subindo, com brilhos amarelos espalhados
static func kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = CYAN
	fx.trail_width = 30.0
	fx.particle_color = YELLOW
	fx.amount = 44
	fx.lifetime = 0.8
	fx.speed_min = 25.0
	fx.speed_max = 130.0
	fx.gravity = Vector2(0.0, -120.0)   # as labaredas sobem
	fx.spin = 360.0
	fx.scale_min = 0.28
	fx.scale_max = 0.65
	fx.burst_amount = 34
	fx.burst_speed = 340.0
	return fx


## Ainda maior e mais brilhante (o Rabona "carregado" da reação Cruel)
static func charged_fx() -> KickFX:
	var fx := kick_fx()
	fx.color = CYAN_LIGHT
	fx.trail_width = 48.0
	fx.particle_color = Color(1.0, 0.8, 0.25)
	fx.amount = 80
	fx.lifetime = 1.0
	fx.speed_min = 30.0
	fx.speed_max = 190.0
	fx.spin = 480.0
	fx.scale_min = 0.35
	fx.scale_max = 0.85
	fx.burst_amount = 56
	fx.burst_speed = 460.0
	return fx


# ---------- RECURSOS COMPARTILHADOS ----------

## Faísca de 4 pontas (24x24), branca
static func spark_texture() -> ImageTexture:
	if Engine.has_meta(_KEY_SPARK):
		return Engine.get_meta(_KEY_SPARK) as ImageTexture
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 24:
			var dx: float = absf(float(x) + 0.5 - 12.0) / 12.0
			var dy: float = absf(float(y) + 0.5 - 12.0) / 12.0
			var a: float = clampf(1.0 - (sqrt(dx) + sqrt(dy)), 0.0, 1.0)   # estrela de 4 pontas
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a * 2.2, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	Engine.set_meta(_KEY_SPARK, tex)
	return tex


## Bolinha macia (24x24), branca: a labareda
static func puff_texture() -> ImageTexture:
	if Engine.has_meta(_KEY_PUFF):
		return Engine.get_meta(_KEY_PUFF) as ImageTexture
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 24:
			var d: float = Vector2(float(x) + 0.5 - 12.0, float(y) + 0.5 - 12.0).length() / 12.0
			img.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 1.5)))
	var tex := ImageTexture.create_from_image(img)
	Engine.set_meta(_KEY_PUFF, tex)
	return tex


## Labareda em forma de língua curva (24x44), branca, com a PONTA EMBAIXO (a partícula alinha o Y com a velocidade,
## então a ponta aponta para onde ela vai)
static func flame_texture() -> ImageTexture:
	if Engine.has_meta(_KEY_FLAME):
		return Engine.get_meta(_KEY_FLAME) as ImageTexture
	var w: int = 24
	var h: int = 44
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var s: float = 1.0 - float(y) / float(h - 1)   # 0 = ponta (embaixo), 1 = topo arredondado
		var half: float = 0.46 * pow(s, 0.85) if s <= 0.7 else 0.46 * pow(0.7, 0.85) * sqrt(maxf(0.0, 1.0 - pow((s - 0.7) / 0.3, 2.0)))
		var cx: float = 0.5 + 0.13 * sin(s * PI * 1.5)   # a curva da língua de fogo
		for x in w:
			var d: float = absf(float(x) / float(w - 1) - cx) / maxf(half, 0.001)
			var a: float = clampf((1.0 - d) * 2.0, 0.0, 1.0) if half > 0.001 else 0.0
			img.set_pixel(x, y, Color(1, 1, 1, a * clampf(0.35 + s * 0.9, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	Engine.set_meta(_KEY_FLAME, tex)
	return tex


## Fio de fumaça fininho e ondulado (16x48), branco
static func wisp_texture() -> ImageTexture:
	if Engine.has_meta(_KEY_WISP):
		return Engine.get_meta(_KEY_WISP) as ImageTexture
	var w: int = 16
	var h: int = 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var s: float = float(y) / float(h - 1)
		var cx: float = 0.5 + 0.28 * sin(s * PI * 2.0)
		var half: float = 0.09 * (1.0 - s * 0.5)
		for x in w:
			var d: float = absf(float(x) / float(w - 1) - cx) / half
			img.set_pixel(x, y, Color(1, 1, 1, clampf((1.0 - d) * 2.0, 0.0, 1.0) * (0.35 + 0.65 * (1.0 - s))))
	var tex := ImageTexture.create_from_image(img)
	Engine.set_meta(_KEY_WISP, tex)
	return tex


## Mistura aditiva (as chamas brilham e se somam), compartilhada
static func _additive() -> CanvasItemMaterial:
	if Engine.has_meta(_KEY_ADD):
		return Engine.get_meta(_KEY_ADD) as CanvasItemMaterial
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	Engine.set_meta(_KEY_ADD, mat)
	return mat


static func _fade_ramp() -> Gradient:
	if Engine.has_meta(_KEY_FADE):
		return Engine.get_meta(_KEY_FADE) as Gradient
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
	Engine.set_meta(_KEY_FADE, g)
	return g


static func _make(tex: Texture2D, color: Color, amount: int, lifetime: float, speed: float,
		size_min: float, size_max: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.color = color
	p.color_ramp = _fade_ramp()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.1
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	p.z_index = 3000
	p.z_as_relative = false
	return p


## Camada de labaredas/fumaça: a ponta aponta para onde a partícula vai (align) ou sobe (sem align)
static func _layer(tex: Texture2D, color: Color, amount: int, lifetime: float, speed: float,
		size_min: float, size_max: float, additive: bool, align: bool = true) -> CPUParticles2D:
	var p := _make(tex, color, amount, lifetime, speed, size_min, size_max)
	p.damping_min = speed * 0.4   # as línguas de fogo viajam mais antes de parar
	p.damping_max = speed * 0.7
	if align:
		p.particle_flag_align_y = true
		p.angle_min = 0.0
		p.angle_max = 0.0
	else:
		p.angle_min = 160.0   # a ponta (que fica embaixo na textura) vira para cima
		p.angle_max = 200.0
	if additive:
		p.material = _additive()
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


static func _add_node(from: Node, n: Node) -> void:
	var scene: Node = from.get_tree().current_scene
	(scene if scene != null else from).add_child(n)


## Onde ficam os efeitos de CHÃO: dentro do campo (acima do desenho dele, abaixo de quem usa o y como profundidade)
static func _ground_parent(from: Node) -> Node:
	var field: Node = from.get_tree().get_first_node_in_group("field")
	if field != null:
		return field
	var scene: Node = from.get_tree().current_scene
	return scene if scene != null else from


# ---------- FOGO E FAÍSCAS ----------

## Explosão de fogo turquesa: fumaça escura em fios por trás, labaredas curvas turquesa, núcleo claro, detalhes
## amarelos e laranja nas pontas e brilhos voando (chute, passe, susto, +PM). strong = ainda maior.
static func flame(from: Node, pos: Vector2, amount: int = 14, strong: bool = false) -> void:
	if not _ok(from):
		return
	var k: float = 1.4 if strong else 1.0
	var ring := Shock.new()
	ring.setup(CYAN, 110.0 if strong else 70.0, 0.35)
	ring.flash = true
	_add_node(from, ring)
	ring.global_position = pos
	var smoke := _layer(wisp_texture(), SMOKE, maxi(int(round(float(amount) * 0.45)), 3), 1.0, 110.0 * k, 1.0, 1.9, false)
	smoke.gravity = Vector2(0.0, -50.0)
	_launch(from, smoke, pos)
	var cyan := _layer(flame_texture(), CYAN, maxi(amount, 5), 0.7, 210.0 * k, 1.1, 2.1, true)
	cyan.gravity = Vector2(0.0, -150.0)
	cyan.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	cyan.emission_sphere_radius = 10.0
	_launch(from, cyan, pos)
	var core := _layer(flame_texture(), CYAN_LIGHT, maxi(int(round(float(amount) * 0.5)), 3), 0.5, 140.0 * k, 0.6, 1.1, true)
	core.gravity = Vector2(0.0, -100.0)
	_launch(from, core, pos)
	var warm := _layer(flame_texture(), YELLOW, maxi(int(round(float(amount) * 0.4)), 3), 0.6, 190.0 * k, 0.7, 1.4, true)
	warm.gravity = Vector2(0.0, -130.0)
	_launch(from, warm, pos)
	var ember := _layer(flame_texture(), ORANGE, maxi(int(round(float(amount) * 0.25)), 2), 0.55, 170.0 * k, 0.6, 1.1, true)
	_launch(from, ember, pos)
	var glitter := _make(spark_texture(), CYAN_LIGHT, maxi(int(round(float(amount) * 1.2)), 6), 0.95, 330.0 * k, 0.25, 0.6)
	glitter.gravity = Vector2(0.0, 50.0)
	glitter.material = _additive()
	_launch(from, glitter, pos)


## Fogo turquesa seguindo a bola por "seconds" segundos (línguas subindo, fumaça escura e brilhos)
static func trail(ball: Ball, seconds: float = 0.7) -> void:
	if ball == null or not ball.is_inside_tree():
		return
	var holder: Node = ball.sprite if ball.sprite != null else ball
	var smoke := _layer(wisp_texture(), SMOKE, 6, 0.9, 40.0, 0.8, 1.4, false, false)
	smoke.gravity = Vector2(0.0, -50.0)
	var cyan := _layer(flame_texture(), CYAN, 22, 0.55, 60.0, 0.9, 1.5, true, false)
	cyan.gravity = Vector2(0.0, -110.0)
	var warm := _layer(flame_texture(), YELLOW, 8, 0.5, 60.0, 0.5, 0.9, true, false)
	warm.gravity = Vector2(0.0, -90.0)
	var glitter := _make(spark_texture(), CYAN_LIGHT, 10, 0.7, 100.0, 0.25, 0.5)
	glitter.material = _additive()
	var parts: Array[CPUParticles2D] = [smoke, cyan, warm, glitter]
	for p in parts:
		p.explosiveness = 0.0
		holder.add_child(p)
		p.emitting = true
	var tree: SceneTree = ball.get_tree()
	tree.create_timer(seconds).timeout.connect(func() -> void:
		for p in parts:
			if is_instance_valid(p):
				p.emitting = false)
	tree.create_timer(seconds + 0.9).timeout.connect(func() -> void:
		for p in parts:
			if is_instance_valid(p):
				p.queue_free())


## Onda de susto da Mischievous Genius: anel amarelo e azul que se abre + faíscas
static func scare(from: Node, pos: Vector2, radius: float) -> void:
	if not _ok(from):
		return
	var wave := Shock.new()
	wave.setup(CYAN, radius, 0.7)
	_add_node(from, wave)
	wave.global_position = pos
	var wave2 := Shock.new()
	wave2.setup(YELLOW, radius * 0.7, 0.55)
	_add_node(from, wave2)
	wave2.global_position = pos
	flame(from, pos, 22, true)


# ---------- EXPLOSÃO DA MINA ----------

## Próxima cor de explosão: sempre diferente da anterior
static func next_boom_color() -> Color:
	if _boom_bag.is_empty():
		_boom_bag.assign(BOOM_COLORS)
		_boom_bag.shuffle()
		if _boom_bag[0] == _last_boom and _boom_bag.size() > 1:   # não repete a última da rodada passada
			_boom_bag.reverse()
	_last_boom = _boom_bag.pop_front()
	return _last_boom


## Explosão colorida: clarão, onda de choque e faíscas/fragmentos na cor dada
static func boom(from: Node, pos: Vector2, color: Color) -> void:
	if not _ok(from):
		return
	var wave := Shock.new()
	wave.setup(color, 120.0, 0.45)
	wave.flash = true
	_add_node(from, wave)
	wave.global_position = pos
	var sparks := _make(spark_texture(), color, 14, 0.7, 240.0, 0.5, 1.0)
	sparks.gravity = Vector2(0.0, 60.0)
	_launch(from, sparks, pos)
	var puffs := _make(puff_texture(), color.lightened(0.3), 8, 0.6, 120.0, 0.8, 1.4)
	puffs.gravity = Vector2(0.0, -40.0)
	_launch(from, puffs, pos)


# ---------- MINA DO PLAYFUL TRAP ----------

## Mina terrestre amarela de baixa opacidade, no chão do campo. active = false: mina "apagada" (errou o QTE)
static func mine(from: Node, pos: Vector2, active: bool = true) -> Mine:
	if not _ok(from):
		return null
	var m := Mine.new()
	m.active = active
	_ground_parent(from).add_child(m)
	m.global_position = pos
	return m


# ---------- BALÃO DE FALA ----------

## Balão em cima do personagem ("ez", "easy", "too slow", "zzz.."): aparece, fica um pouquinho e some
static func speech(target: Node2D, text: String) -> void:
	if target == null or not target.is_inside_tree():
		return
	var b := Bubble.new()
	b.text = text
	b.position = Vector2(20.0, -84.0)
	target.add_child(b)


# ---------- CARROSSEL DA METAVISION ----------

static func make_carousel(radius: float = 150.0) -> Carousel:
	var c := Carousel.new()
	c.radius = radius
	c.visible = false
	return c


# ---------- DIABINHOS (PM e marcas) ----------

## Diabinho 😈 amarelo desenhado em `c` (dentro do _draw ou de um sinal draw). center = meio do rosto, s = raio da
## cabeça. filled = aceso (amarelo com contorno `outline`); false = só o contorno apagado (PM que ele não tem).
static func draw_devil(c: CanvasItem, center: Vector2, s: float, filled: bool = true, outline: Color = BLUE_DEEP) -> void:
	var line: Color = outline if filled else Color(0.9, 0.9, 1.0, 0.4)
	var w: float = maxf(s * 0.14, 1.0)
	for side in [-1.0, 1.0]:   # chifres
		var horn := PackedVector2Array([center + Vector2(side * s * 0.9, -s * 0.35),
			center + Vector2(side * s * 1.2, -s * 1.55), center + Vector2(side * s * 0.2, -s * 0.9)])
		if filled:
			c.draw_colored_polygon(horn, ORANGE)
		c.draw_polyline(horn, line, w)
	if filled:
		c.draw_circle(center, s, YELLOW)
	c.draw_arc(center, s, 0.0, TAU, 20, line, w)
	var feature: Color = Color(0.25, 0.15, 0.05) if filled else line
	for side in [-1.0, 1.0]:   # olhos furiosos (inclinados para dentro)
		c.draw_line(center + Vector2(side * s * 0.62, -s * 0.42), center + Vector2(side * s * 0.15, -s * 0.1), feature, maxf(s * 0.26, 1.2))
	c.draw_arc(center + Vector2(0.0, s * 0.05), s * 0.55, deg_to_rad(15.0), deg_to_rad(165.0), 10, feature, maxf(s * 0.18, 1.2))   # sorriso


## Os diabinhos de PM empilhados ao lado do personagem (chamar dentro do _draw de quem desenha). Acesos = pontos que
## ele tem; apagados = só o contorno.
static func draw_pm_marks(c: CanvasItem, origin: Vector2, pm: int, max_pm: int, size: float = 4.5) -> void:
	for i in max_pm:   # o primeiro (de baixo) fica em origin e os outros sobem
		draw_devil(c, origin + Vector2(0.0, -float(i) * size * 2.8), size, i < pm)


## Marca de diabinho flutuando sobre `target` (quem foi afetado por uma bomba ou aliado marcado por um passe).
## outline = cor do contorno (RED_LINE para inimigos, BLUE_DEEP para aliados). Fica até o unmark().
static func mark(target: Node2D, outline: Color = BLUE_DEEP) -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree() or target.has_node("CharlesMark"):
		return
	var d := DevilMark.new()
	d.name = "CharlesMark"
	d.outline = outline
	target.add_child(d)


static func unmark(target: Node2D) -> void:
	if target != null and is_instance_valid(target) and target.has_node("CharlesMark"):
		(target.get_node("CharlesMark") as DevilMark).fade_out()


# ---------- NÓS ----------

## Diabinho amarelo que flutua (balançando) sobre a cabeça do dono
class DevilMark extends Node2D:
	var outline: Color = CharlesFX.BLUE_DEEP
	var _t: float = 0.0
	var _closing: bool = false

	func _ready() -> void:
		z_index = 3100
		z_as_relative = false
		modulate.a = 0.0
		scale = Vector2(0.4, 0.4)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.15)
		tw.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _process(delta: float) -> void:
		_t += delta
		var owner_height: float = (get_parent() as Player).height if get_parent() is Player else 0.0
		position = Vector2(0.0, -owner_height - 86.0 + sin(_t * 3.0) * 3.0)
		queue_redraw()

	func fade_out() -> void:
		if _closing:
			return
		_closing = true
		name = "CharlesMarkOld"   # libera o nome para uma marca nova
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 15.0, Color(CharlesFX.YELLOW, 0.18))   # brilho
		CharlesFX.draw_devil(self, Vector2.ZERO, 10.0, true, outline)


## Onda de choque: anel que se abre e some (e, se flash, um clarão no começo)
class Shock extends Node2D:
	var color: Color = Color.WHITE
	var max_radius: float = 100.0
	var life: float = 0.5
	var flash: bool = false
	var _t: float = 0.0

	func setup(c: Color, radius: float, seconds: float) -> void:
		color = c
		max_radius = radius
		life = seconds
		z_index = 2900
		z_as_relative = false

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var u: float = clampf(_t / life, 0.0, 1.0)
		var r: float = max_radius * (1.0 - pow(1.0 - u, 3.0))
		var fade: float = 1.0 - u
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color, 0.85 * fade), 4.0 * fade + 1.0)
		draw_arc(Vector2.ZERO, r * 0.65, 0.0, TAU, 32, Color(color.lightened(0.4), 0.5 * fade), 2.0)
		if flash:
			draw_circle(Vector2.ZERO, max_radius * 0.35 * (1.0 - u), Color(color.lightened(0.5), 0.7 * fade))


## Mina terrestre: disco amarelo translúcido com pinos, anel e uma luzinha azul que pisca
class Mine extends Node2D:
	var active: bool = true
	var dormant: bool = false   # Charles longe demais: a mina fica "dormindo" (mais apagada)
	var _t: float = 0.0
	var _gone: bool = false

	func _init() -> void:
		z_index = -3990   # no chão: acima do campo, abaixo de quem usa o y como profundidade
		z_as_relative = false

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	## Some sem explodir (a mais antiga quebra quando passa de 6)
	func pop() -> void:
		if _gone:
			return
		_gone = true
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		var base: float = 1.0 if active else 0.45
		if dormant:
			base *= 0.6
		var y := CharlesFX.YELLOW
		# Sombra e disco (baixa opacidade: ela é "oculta")
		draw_colored_polygon(_ellipse(Vector2(0.0, 2.0), 17.0, 7.0), Color(0, 0, 0, 0.12 * base))
		var col: Color = y if active else Color(0.75, 0.72, 0.55)
		draw_colored_polygon(_ellipse(Vector2.ZERO, 15.0, 9.0), Color(col, 0.22 * base))
		draw_polyline(_ellipse(Vector2.ZERO, 15.0, 9.0) + PackedVector2Array([Vector2(15.0, 0.0)]), Color(col, 0.5 * base), 2.0)
		draw_polyline(_ellipse(Vector2.ZERO, 9.0, 5.5) + PackedVector2Array([Vector2(9.0, 0.0)]), Color(col, 0.35 * base), 1.5)
		# Pinos em volta
		for i in 6:
			var a: float = float(i) * TAU / 6.0
			var dir := Vector2(cos(a), sin(a) * 0.6)
			draw_line(dir * 15.0, dir * 20.0, Color(col, 0.45 * base), 2.0)
		# Luzinha no meio: pisca azul quando ativa
		var blink: float = 0.5 + 0.5 * sin(_t * 5.0) if active else 0.0
		draw_circle(Vector2(0.0, -1.0), 3.0, Color(CharlesFX.BLUE, (0.25 + 0.4 * blink) * base))
		if not active:
			draw_line(Vector2(-5.0, -3.0), Vector2(5.0, 3.0), Color(0.6, 0.6, 0.6, 0.4), 1.5)
			draw_line(Vector2(-5.0, 3.0), Vector2(5.0, -3.0), Color(0.6, 0.6, 0.6, 0.4), 1.5)

	func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 20:
			var a: float = float(i) * TAU / 20.0
			pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
		return pts


## Balão de fala branco com a ponta para baixo
class Bubble extends Node2D:
	var text: String = ""
	var _size: Vector2 = Vector2.ZERO
	var _font: Font
	const FONT_SIZE: int = 15

	func _ready() -> void:
		z_index = 3100
		z_as_relative = false
		_font = ThemeDB.fallback_font
		var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE).x
		_size = Vector2(w + 18.0, 26.0)
		modulate.a = 0.0
		scale = Vector2(0.5, 0.5)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.12)
		tw.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var out := create_tween()
		out.tween_interval(1.1)
		out.tween_property(self, "modulate:a", 0.0, 0.3)
		out.tween_callback(queue_free)
		queue_redraw()

	func _draw() -> void:
		if _font == null:
			return
		var rect := Rect2(Vector2(-_size.x * 0.5, -_size.y), _size)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.96)
		sb.border_color = Color(0.12, 0.12, 0.2)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(9)
		draw_style_box(sb, rect)
		# ponta do balão
		draw_colored_polygon(PackedVector2Array([Vector2(-5.0, 0.0), Vector2(5.0, 0.0), Vector2(-7.0, 9.0)]), Color(1, 1, 1, 0.96))
		draw_line(Vector2(-5.0, 0.0), Vector2(-7.0, 9.0), Color(0.12, 0.12, 0.2), 2.0)
		draw_line(Vector2(5.0, 0.0), Vector2(-7.0, 9.0), Color(0.12, 0.12, 0.2), 2.0)
		draw_string(_font, Vector2(rect.position.x + 9.0, rect.position.y + 18.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, Color(0.1, 0.1, 0.18))


## Carrossel translúcido (com varredura de radar): anéis, hastes girando, "cavalinhos" que sobem e descem e o toldo
class Carousel extends Node2D:
	var radius: float = 150.0
	var _t: float = 0.0

	func _process(delta: float) -> void:
		if not visible:
			return
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var y := CharlesFX.YELLOW
		var b := CharlesFX.BLUE
		# Chão do carrossel e os dois anéis
		draw_circle(Vector2.ZERO, radius, Color(y, 0.06))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(y, 0.5), 2.0)
		draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 48, Color(b, 0.35), 1.6)
		# Toldo: festões em volta da borda
		var scallops: int = 18
		for i in scallops:
			var a0: float = float(i) * TAU / float(scallops) + _t * 0.15
			draw_arc(Vector2.ZERO, radius + 5.0, a0, a0 + TAU / float(scallops) * 0.8, 6, Color(y, 0.4), 2.5)
		# Hastes girando
		for i in 6:
			var a: float = _t * 0.6 + float(i) * TAU / 6.0
			var dir := Vector2(cos(a), sin(a))
			draw_line(dir * radius * 0.55, dir * radius, Color(y, 0.22), 1.5)
		# Varredura de radar
		var sweep: float = _t * 1.6
		var fan := PackedVector2Array([Vector2.ZERO])
		for k in 9:
			var a2: float = sweep - float(k) * 0.05
			fan.append(Vector2(cos(a2), sin(a2)) * radius)
		draw_colored_polygon(fan, Color(b, 0.10))
		draw_line(Vector2.ZERO, Vector2(cos(sweep), sin(sweep)) * radius, Color(CharlesFX.YELLOW_LIGHT, 0.55), 2.0)
		# Cavalinhos: bolinhas presas em hastes, subindo e descendo
		var horses: int = 6
		for i in horses:
			var a3: float = -_t * 0.9 + float(i) * TAU / float(horses)
			var foot := Vector2(cos(a3), sin(a3)) * radius * 0.78
			var bob: float = sin(_t * 3.0 + float(i) * 1.7) * 5.0
			var head: Vector2 = foot + Vector2(0.0, -20.0 + bob)
			draw_line(foot, head, Color(y, 0.3), 1.5)
			draw_circle(head, 4.0, Color(y if i % 2 == 0 else b, 0.55))
			draw_circle(head + Vector2(0.0, -1.0), 1.6, Color(1, 1, 1, 0.5))
