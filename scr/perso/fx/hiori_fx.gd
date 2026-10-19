class_name HioriFX
extends RefCounted
## Efeitos visuais das habilidades do Hiori: FLOCOS DE NEVE e CACOS DE VIDRO pequenos, mais o gelo
## (camada fina no chão, bloco de gelo e a área do Frost Guard).
## Tudo por código (nenhuma imagem): o floco e o caco são desenhados uma única vez numa textura 32x32
## branca e a cor vem da partícula, que sorteia entre dois tons (branco/azul-gelo).
##
## Pensado para ser leve, igual ao isagi_fx.gd:
##  - duas texturas e quatro degradês compartilhados (criados uma vez e guardados no Engine);
##  - poucos CPUParticles2D "one_shot" por efeito, com poucas partículas e vida curta;
##  - cada efeito se apaga sozinho; o único emissor contínuo é a aura, que fica desligada
##    (emitting = false) quando não está em uso;
##  - sem som, sem luz, sem mistura aditiva.
##
## Quem chama passa um nó qualquer que já esteja na árvore (ex: o Hiori) em "from".
##
## Resumo:
##   burst / ring / line / area / trail / shatter -> partículas (neve + vidro)
##   ice_layer(from, a, b)   -> camada fina de gelo no chão entre dois pontos, que some aos poucos (Glacial Cut)
##   ice_block(from, alvo)   -> bloco de gelo em volta de um jogador; quebra em cacos no fim (congelamento do Let It Go)
##   draw_frost_area(...)    -> círculo com um floco grande marcando um alcance (Frost Guard); chamar dentro do _draw()

const SNOW_WHITE := Color(0.95, 0.98, 1.0)     # branco gelado
const SNOW_BLUE := Color(0.62, 0.88, 1.0)      # azul-gelo claro
const GLASS_PALE := Color(0.80, 0.96, 1.0)     # vidro claro
const GLASS_BLUE := Color(0.42, 0.74, 0.95)    # vidro azulado
const ICE := Color(0.55, 0.85, 1.0)            # cor base do gelo

const _KEY_SNOW := &"hiori_snow_tex"
const _KEY_SHARD := &"hiori_shard_tex"
const _KEY_SNOW_PICK := &"hiori_snow_pick"
const _KEY_GLASS_PICK := &"hiori_glass_pick"
const _KEY_FADE := &"hiori_fade"


# ---------- RECURSOS COMPARTILHADOS ----------

## Cria as texturas já no começo (o Hiori chama no _ready) para não travar na primeira habilidade
static func warm_up() -> void:
	snow_texture()
	shard_texture()


## Floco de neve de 6 pontas com ramificações, branco, 32x32
static func snow_texture() -> ImageTexture:
	if Engine.has_meta(_KEY_SNOW):
		return Engine.get_meta(_KEY_SNOW) as ImageTexture
	var segs: Array[Vector2] = _flake_segments()
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var hits: int = 0
			for sy in 2:   # 2x2 amostras por pixel: borda suave
				for sx in 2:
					if _in_flake(Vector2(float(x) + (float(sx) + 0.5) / 2.0, float(y) + (float(sy) + 0.5) / 2.0), segs):
						hits += 1
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, float(hits) / 4.0))
	var tex := ImageTexture.create_from_image(img)
	Engine.set_meta(_KEY_SNOW, tex)
	return tex


## Pares de pontos (início, fim) dos traços do floco: 6 braços, cada um com 2 pares de ramos
static func _flake_segments() -> Array[Vector2]:
	var c := Vector2(16.0, 16.0)
	var out: Array[Vector2] = []
	for k in 6:
		var d: Vector2 = Vector2.from_angle(float(k) * TAU / 6.0 - PI * 0.5)
		out.append(c)
		out.append(c + d * 13.5)
		for step in 2:
			var frac: float = 0.5 if step == 0 else 0.78
			var branch: float = 5.5 if step == 0 else 3.8
			var p: Vector2 = c + d * 13.5 * frac
			for side in [-1.0, 1.0]:
				out.append(p)
				out.append(p + d.rotated(float(side) * PI / 3.0) * branch)
	return out


static func _in_flake(p: Vector2, segs: Array[Vector2]) -> bool:
	for i in range(0, segs.size(), 2):
		if Geometry2D.get_closest_point_to_segment(p, segs[i], segs[i + 1]).distance_to(p) <= 1.1:
			return true
	return false


## Caquinho de vidro (cristal pontudo e torto), branco, 32x32
static func shard_texture() -> ImageTexture:
	if Engine.has_meta(_KEY_SHARD):
		return Engine.get_meta(_KEY_SHARD) as ImageTexture
	var poly := PackedVector2Array([Vector2(16.0, 2.0), Vector2(23.0, 13.0), Vector2(19.0, 30.0),
		Vector2(10.0, 25.0), Vector2(8.0, 11.0)])
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var hits: int = 0
			for sy in 2:
				for sx in 2:
					if Geometry2D.is_point_in_polygon(Vector2(float(x) + (float(sx) + 0.5) / 2.0, float(y) + (float(sy) + 0.5) / 2.0), poly):
						hits += 1
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, float(hits) / 4.0))
	var tex := ImageTexture.create_from_image(img)
	Engine.set_meta(_KEY_SHARD, tex)
	return tex


## Sorteio entre dois tons (degrau no meio do degradê)
static func _pick_ramp(key: StringName, a: Color, b: Color) -> Gradient:
	if Engine.has_meta(key):
		return Engine.get_meta(key) as Gradient
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.5])
	g.colors = PackedColorArray([a, b])
	Engine.set_meta(key, g)
	return g


static func _snow_ramp() -> Gradient:
	return _pick_ramp(_KEY_SNOW_PICK, SNOW_WHITE, SNOW_BLUE)


static func _glass_ramp() -> Gradient:
	return _pick_ramp(_KEY_GLASS_PICK, GLASS_PALE, GLASS_BLUE)


## Fica inteira e some no final da vida
static func _fade_ramp() -> Gradient:
	if Engine.has_meta(_KEY_FADE):
		return Engine.get_meta(_KEY_FADE) as Gradient
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	Engine.set_meta(_KEY_FADE, g)
	return g


static func _make(tex: Texture2D, pick: Gradient, amount: int, lifetime: float, speed: float,
		size_min: float, size_max: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.color_initial_ramp = pick
	p.color_ramp = _fade_ramp()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false          # ficam no campo e não acompanham quem as soltou
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.9     # desaceleram e flutuam
	p.damping_max = speed * 1.2
	p.gravity = Vector2(0.0, -22.0)   # a neve sobe devagar, como as partículas dos chutes
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -200.0
	p.angular_velocity_max = 200.0
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	p.z_index = 3000   # acima de tudo (jogadores e bola usam z_index = y como profundidade)
	p.z_as_relative = false
	return p


static func _snow(amount: int, lifetime: float, speed: float, size_min: float = 0.35, size_max: float = 0.65) -> CPUParticles2D:
	return _make(snow_texture(), _snow_ramp(), amount, lifetime, speed, size_min, size_max)


## Cacos: menores, mais rápidos no começo e CAEM (gravidade para baixo)
static func _glass(amount: int, lifetime: float, speed: float) -> CPUParticles2D:
	var p := _make(shard_texture(), _glass_ramp(), amount, lifetime, speed, 0.28, 0.5)
	p.gravity = Vector2(0.0, 110.0)
	p.damping_min = speed * 0.5
	p.damping_max = speed * 0.8
	p.angular_velocity_min = -420.0
	p.angular_velocity_max = 420.0
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


static func _share(amount: int, fraction: float) -> int:
	return maxi(int(round(float(amount) * fraction)), 3)


## Onde ficam os efeitos de CHÃO: dentro do campo, acima do desenho dele e abaixo de quem usa o y como profundidade
static func _ground_parent(from: Node) -> Node:
	var field: Node = from.get_tree().get_first_node_in_group("field")
	if field != null:
		return field
	var scene: Node = from.get_tree().current_scene
	return scene if scene != null else from


# ---------- EFEITOS DE PARTÍCULAS ----------

## Explosão de flocos e cacos em volta de um ponto. strong = mais, maiores e mais longe.
static func burst(from: Node, pos: Vector2, amount: int = 10, strong: bool = false) -> void:
	if not _ok(from):
		return
	var snow := _snow(_share(amount, 0.6), 0.9 if strong else 0.75, 130.0 if strong else 95.0,
		0.4, 0.8 if strong else 0.6)
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	snow.emission_sphere_radius = 16.0 if strong else 10.0
	_launch(from, snow, pos)
	var glass := _glass(_share(amount, 0.4), 0.7, 190.0 if strong else 140.0)
	glass.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	glass.emission_sphere_radius = 8.0
	_launch(from, glass, pos)


## Quebra: bem mais cacos de vidro do que neve (o bloco de gelo se desfazendo)
static func shatter(from: Node, pos: Vector2, amount: int = 22) -> void:
	if not _ok(from):
		return
	var glass := _glass(amount, 0.85, 220.0)
	glass.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	glass.emission_sphere_radius = 14.0
	_launch(from, glass, pos)
	var snow := _snow(_share(amount, 0.35), 0.8, 110.0)
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	snow.emission_sphere_radius = 14.0
	_launch(from, snow, pos)


## Anel de flocos que se abre em volta de um ponto (ativações)
static func ring(from: Node, pos: Vector2, radius: float, amount: int = 14) -> void:
	if not _ok(from):
		return
	var p := _snow(amount, 0.9, 60.0, 0.4, 0.7)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = radius
	p.radial_accel_min = 20.0
	p.radial_accel_max = 60.0
	_launch(from, p, pos)


## Flocos que nascem ao longo de uma linha (passe, avanço, bola sendo puxada)
static func line(from: Node, a: Vector2, b: Vector2, amount: int = 12) -> void:
	if not _ok(from):
		return
	var p := _snow(amount, 0.75, 50.0, 0.35, 0.6)
	var pts := PackedVector2Array()
	var samples: int = maxi(amount * 2, 4)
	for i in samples:
		pts.append((b - a) * (float(i) / float(samples - 1)))
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = pts
	_launch(from, p, a)


## Neve espalhada por uma área circular
static func area(from: Node, center: Vector2, radius: float, amount: int = 16) -> void:
	if not _ok(from):
		return
	var p := _snow(amount, 1.1, 30.0, 0.4, 0.7)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	_launch(from, p, center)


## Neve que acompanha a bola por "seconds" segundos (filho do sprite dela: segue a altura)
static func trail(ball: Ball, seconds: float = 0.5) -> void:
	if ball == null or not ball.is_inside_tree():
		return
	var p := _snow(14, 0.55, 40.0, 0.3, 0.5)
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


## Neve contínua em volta do personagem (Metavision). Vira filho do Hiori e começa DESLIGADA;
## quem a criou liga e desliga com "emitting".
static func make_aura(radius: float = 30.0) -> CPUParticles2D:
	var p := _snow(8, 1.4, 22.0, 0.3, 0.5)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.gravity = Vector2(0.0, 14.0)   # a neve da aura cai devagar
	p.emitting = false
	return p


# ---------- GELO ----------

## Camada FINA de gelo no chão entre dois pontos (global). Fica translúcida e some aos poucos.
## Chame a cada pedaço do caminho (ex: de 14 em 14 px) para fazer o rastro do avanço.
static func ice_layer(from: Node, a: Vector2, b: Vector2, width: float = 34.0, seconds: float = 1.6) -> void:
	if not _ok(from) or a.distance_to(b) < 0.5:
		return
	var holder := Node2D.new()   # um nó por pedaço: as duas linhas somem juntas
	holder.z_index = -4000       # acima do campo (-4096), abaixo de tudo que usa a profundidade pelo y
	holder.z_as_relative = false
	_ground_parent(from).add_child(holder)
	var pa: Vector2 = holder.to_local(a)
	var pb: Vector2 = holder.to_local(b)
	holder.add_child(_ice_line(pa, pb, width, Color(ICE, 0.34)))                         # a camada
	holder.add_child(_ice_line(pa, pb, width * 0.4, Color(0.93, 0.99, 1.0, 0.5)))        # o brilho do meio
	var tw: Tween = holder.create_tween()
	tw.tween_property(holder, "modulate:a", 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(holder.queue_free)


static func _ice_line(a: Vector2, b: Vector2, width: float, color: Color) -> Line2D:
	var l := Line2D.new()
	l.points = PackedVector2Array([a, b])
	l.width = width
	l.default_color = color
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	return l


## Bloco de gelo em volta de um jogador (filho dele: acompanha). Cresce rápido e se desfaz em cacos:
## depois de "seconds" segundos OU, com follow_lock = true, assim que o jogador deixa de estar travado
## (atordoado). Devolve o bloco: chame break_now() nele para quebrar antes do tempo.
static func ice_block(from: Node, target: Node2D, seconds: float = 1.2, follow_lock: bool = false) -> Node2D:
	if not _ok(from) or target == null or not is_instance_valid(target):
		return null
	var block := IceBlock.new()
	var body: float = float(target.get("body_radius")) if target.get("body_radius") != null else 18.0
	var lift: float = float(target.get("height")) if target.get("height") != null else 0.0
	block.setup(body)
	block.position = Vector2(0.0, -lift)
	target.add_child(block)
	block.hold(seconds, target if follow_lock else null)
	burst(from, target.global_position + Vector2(0.0, -lift - body), 8)   # neve na hora em que congela
	return block


## Círculo com um floco grande dentro, marcando um alcance. Chamar DENTRO do _draw() de quem desenha.
## strength 0..1: sobe o brilho (ex: 1 quando dá para usar a habilidade). spin = giro do floco (radianos).
static func draw_frost_area(c: CanvasItem, center: Vector2, radius: float, strength: float = 0.5, spin: float = 0.0) -> void:
	var edge := Color(0.72, 0.94, 1.0)
	c.draw_circle(center, radius, Color(edge, 0.08 + 0.10 * strength))
	c.draw_arc(center, radius, 0.0, TAU, 56, Color(edge, 0.5 + 0.45 * strength), 2.5)
	# anel interno de pontinhos de gelo
	var dots: int = 20
	for i in dots:
		var a: float = float(i) * TAU / float(dots) - spin * 0.5
		c.draw_circle(center + Vector2.from_angle(a) * radius * 0.9, 1.7, Color(1.0, 1.0, 1.0, 0.35 + 0.4 * strength))
	_draw_flake(c, center, radius * 0.78, spin, Color(0.86, 0.97, 1.0, 0.4 + 0.45 * strength))


## Floco de 6 pontas com ramos (o mesmo desenho da textura, só que em linhas e em tamanho grande)
static func _draw_flake(c: CanvasItem, center: Vector2, r: float, spin: float, col: Color) -> void:
	for k in 6:
		var d: Vector2 = Vector2.from_angle(float(k) * TAU / 6.0 + spin)
		c.draw_line(center, center + d * r, col, 2.6)
		for step in 2:
			var frac: float = 0.5 if step == 0 else 0.78
			var branch: float = r * (0.4 if step == 0 else 0.28)
			var p: Vector2 = center + d * r * frac
			for side in [-1.0, 1.0]:
				c.draw_line(p, p + d.rotated(float(side) * PI / 3.0) * branch, col, 2.0)
	c.draw_circle(center, maxf(r * 0.1, 3.0), col)


# ---------- BLOCO DE GELO ----------

class IceBlock extends Node2D:
	var _w: float = 44.0
	var _h: float = 54.0
	var _broken: bool = false
	var _watch: Node2D = null   # se houver: o bloco dura enquanto este jogador estiver travado

	func setup(body_radius: float) -> void:
		_w = body_radius * 2.5
		_h = body_radius * 3.0
		z_index = 1   # acima do desenho do jogador (z relativo a ele)
		modulate.a = 0.0
		scale = Vector2(0.4, 0.4)

	## Cresce e quebra: depois de "seconds" segundos ou, com "watch", quando ele deixa de estar travado
	func hold(seconds: float, watch: Node2D = null) -> void:
		var grow := create_tween().set_parallel(true)
		grow.tween_property(self, "modulate:a", 1.0, 0.2)
		grow.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_watch = watch
		set_process(_watch != null)
		if _watch == null:
			get_tree().create_timer(seconds).timeout.connect(break_now)

	func _process(_delta: float) -> void:
		if _watch == null or not is_instance_valid(_watch) or not _watch.has_method("is_locked") \
				or not _watch.call("is_locked"):
			break_now()

	func break_now() -> void:
		if _broken or not is_inside_tree():
			return
		_broken = true
		HioriFX.shatter(self, global_position + Vector2(0.0, -_h * 0.5), 24)
		queue_free()

	func _draw() -> void:
		var d: float = 9.0   # profundidade do bloco (faces de cima e do lado)
		var x0: float = -_w * 0.5
		var x1: float = _w * 0.5
		var y0: float = -_h
		var y1: float = 4.0
		var edge := Color(0.85, 0.97, 1.0, 0.95)
		# face da frente
		draw_colored_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
			Color(HioriFX.ICE, 0.42))
		# face de cima (mais clara) e face da direita (mais escura)
		draw_colored_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + d, y0 - d), Vector2(x1 + d, y0 - d), Vector2(x1, y0)]),
			Color(0.9, 0.99, 1.0, 0.55))
		draw_colored_polygon(PackedVector2Array([Vector2(x1, y0), Vector2(x1 + d, y0 - d), Vector2(x1 + d, y1 - d), Vector2(x1, y1)]),
			Color(0.35, 0.65, 0.9, 0.5))
		# contorno e brilhos
		draw_polyline(PackedVector2Array([Vector2(x0, y1), Vector2(x0, y0), Vector2(x0 + d, y0 - d), Vector2(x1 + d, y0 - d),
			Vector2(x1 + d, y1 - d), Vector2(x1, y1), Vector2(x0, y1)]), edge, 2.0)
		draw_polyline(PackedVector2Array([Vector2(x1, y1), Vector2(x1, y0), Vector2(x0, y0)]), edge, 2.0)
		draw_line(Vector2(x0 + 8.0, y0 + 12.0), Vector2(x0 + 20.0, y0 + 4.0), Color(1, 1, 1, 0.85), 2.5)
		draw_line(Vector2(x0 + 8.0, y0 + 24.0), Vector2(x0 + 14.0, y0 + 19.0), Color(1, 1, 1, 0.6), 2.0)
		draw_line(Vector2(x1 - 10.0, y1 - 8.0), Vector2(x1 - 20.0, y1 - 18.0), Color(1, 1, 1, 0.45), 2.0)
