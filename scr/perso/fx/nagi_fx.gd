class_name NagiFX
extends RefCounted
## Efeitos visuais do Nagi: CAVEIRAS simples, brancas, com variações de azul e roxo bem claros.
## Tudo por código (nenhuma imagem): a caveira é desenhada uma única vez numa textura 48x48 branca,
## e a cor vem da partícula, que sorteia entre branco, azul-gelo e lilás.
##
## Leve, no mesmo estilo do IsagiFX:
##  - uma textura e dois degradês compartilhados (criados uma vez e guardados no Engine);
##  - um CPUParticles2D "one_shot" por efeito, poucas partículas e vida curta, que se apaga sozinho;
##  - o único emissor contínuo é a aura, que fica desligada (emitting = false) quando não está em uso.
##
## A CAVEIRA GRANDE (skull) é um sprite que sai de cima do Nagi e SOBE de tamanho e de opacidade
## a cada desvio do Zero Reset Turn: use stage_size() / stage_alpha() com o número do desvio.
##
## Quem chama passa um nó qualquer que já esteja na árvore (ex: o Nagi) em "from".

const WHITE := Color(1.0, 1.0, 1.0)
const ICE := Color(0.78, 0.90, 1.0)      # azul bem claro
const LILAC := Color(0.84, 0.78, 1.0)    # roxo bem claro

const _KEY_TEX := &"nagi_skull_tex"
const _KEY_PICK := &"nagi_skull_pick"
const _KEY_FADE := &"nagi_skull_fade"


# ---------- RECURSOS COMPARTILHADOS ----------

## A caveira (crânio redondo, olhos, nariz e dentes vazados), branca, 48x48
static func skull_texture() -> ImageTexture:
	if Engine.has_meta(_KEY_TEX):
		return Engine.get_meta(_KEY_TEX) as ImageTexture
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	for y in 48:
		for x in 48:
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
	var cranium: bool = p.distance_to(Vector2(24.0, 20.0)) <= 15.5
	var cheeks: bool = p.x >= 15.0 and p.x <= 33.0 and p.y >= 24.0 and p.y <= 34.0
	var jaw: bool = p.x >= 17.0 and p.x <= 31.0 and p.y >= 33.0 and p.y <= 42.0
	var eye_l: bool = p.distance_to(Vector2(18.5, 21.0)) <= 4.4
	var eye_r: bool = p.distance_to(Vector2(29.5, 21.0)) <= 4.4
	var nose: bool = p.y >= 27.0 and p.y <= 31.5 and absf(p.x - 24.0) <= (p.y - 26.5) * 0.55
	var teeth: bool = p.y >= 36.5 and p.y <= 42.0 \
		and (absf(p.x - 21.0) < 0.55 or absf(p.x - 24.0) < 0.55 or absf(p.x - 27.0) < 0.55)
	return (cranium or cheeks or jaw) and not (eye_l or eye_r or nose or teeth)


## Cada caveira nasce branca, azul-gelo OU lilás (sorteio: degraus no degradê)
static func _pick_ramp() -> Gradient:
	if Engine.has_meta(_KEY_PICK):
		return Engine.get_meta(_KEY_PICK) as Gradient
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.45, 0.75])
	g.colors = PackedColorArray([WHITE, ICE, LILAC])
	Engine.set_meta(_KEY_PICK, g)
	return g


## Fica inteira e some no final da vida
static func _fade_ramp() -> Gradient:
	if Engine.has_meta(_KEY_FADE):
		return Engine.get_meta(_KEY_FADE) as Gradient
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)])
	Engine.set_meta(_KEY_FADE, g)
	return g


static func _make(amount: int, lifetime: float, speed: float, size_min: float, size_max: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = skull_texture()
	p.color_initial_ramp = _pick_ramp()
	p.color_ramp = _fade_ramp()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false          # as caveiras ficam no campo e não acompanham quem as soltou
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.9
	p.damping_max = speed * 1.2
	p.gravity = Vector2(0.0, -34.0)   # sobem devagar, como fumaça
	p.angle_min = -25.0
	p.angle_max = 25.0
	p.angular_velocity_min = -60.0
	p.angular_velocity_max = 60.0
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


# ---------- ESCALA DA CAVEIRA GRANDE ----------

## Tamanho da caveira no desvio número "stage" (0 = primeiro): cresce a cada desvio
static func stage_size(stage: int, start: float = 1.0, step: float = 0.6) -> float:
	return start + step * float(maxi(stage, 0))


## Opacidade da caveira no desvio número "stage": fica mais forte a cada desvio
static func stage_alpha(stage: int, start: float = 0.3, step: float = 0.18) -> float:
	return clampf(start + step * float(maxi(stage, 0)), 0.0, 1.0)


# ---------- EFEITOS ----------

## UMA caveira que sai de cima de "from" (um Node2D com "height", ex: o Nagi), sobe e some.
## size_mult = tamanho (1.0 = ~44 px), alpha = opacidade máxima. Quanto maior, mais para o lilás.
static func skull(from: Node2D, size_mult: float = 1.0, alpha: float = 0.6, seconds: float = 1.1) -> Sprite2D:
	if not _ok(from):
		return null
	var s := Sprite2D.new()
	s.texture = skull_texture()
	s.z_index = 3000
	s.z_as_relative = false
	var tint: Color = WHITE.lerp(ICE, clampf(size_mult - 1.0, 0.0, 1.0)).lerp(LILAC, clampf((size_mult - 2.0) * 0.5, 0.0, 1.0))
	var h: float = float(from.get("height")) if "height" in from else 0.0
	var base_y: float = -h - 52.0 - 20.0 * size_mult
	s.position = Vector2(0.0, base_y)
	s.scale = Vector2.ONE * 0.45 * size_mult
	s.modulate = Color(tint, 0.0)
	from.add_child(s)
	var tw: Tween = s.create_tween().set_parallel(true)
	tw.tween_property(s, "modulate:a", alpha, seconds * 0.2)
	tw.tween_property(s, "scale", Vector2.ONE * 0.9 * size_mult, seconds * 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position:y", base_y - 26.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(s, "modulate:a", 0.0, seconds * 0.45).set_delay(0.0)
	tw.chain().tween_callback(s.queue_free)
	# alguns "fiapos" de caveirinha junto da grande
	burst(from, from.global_position + Vector2(0.0, base_y), 4 + int(size_mult * 2.0), size_mult > 2.0)
	return s


## Explosão de caveirinhas em volta de um ponto do campo. strong = mais caveiras, maiores e mais longe.
static func burst(from: Node, pos: Vector2, amount: int = 8, strong: bool = false) -> void:
	if not _ok(from):
		return
	var p := _make(amount, 0.8 if strong else 0.65, 150.0 if strong else 100.0,
		0.2 if strong else 0.14, 0.4 if strong else 0.28)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 16.0 if strong else 10.0
	_launch(from, p, pos)


## Poucas caveirinhas saindo de um personagem (uso comum nas habilidades)
static func puff(from: Node2D, amount: int = 6) -> void:
	if not _ok(from):
		return
	var h: float = float(from.get("height")) if "height" in from else 0.0
	burst(from, from.global_position + Vector2(0.0, -h - 26.0), amount, false)


## Anel de caveirinhas que se abre em volta de um ponto (ativações)
static func ring(from: Node, pos: Vector2, radius: float, amount: int = 12) -> void:
	if not _ok(from):
		return
	var p := _make(amount, 0.9, 50.0, 0.16, 0.3)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = radius
	p.radial_accel_min = 20.0
	p.radial_accel_max = 60.0
	_launch(from, p, pos)


## Caveirinhas que nascem ao longo de uma linha (avanços, bola sendo puxada)
static func line(from: Node, a: Vector2, b: Vector2, amount: int = 10) -> void:
	if not _ok(from):
		return
	var p := _make(amount, 0.7, 40.0, 0.14, 0.26)
	var pts := PackedVector2Array()
	var samples: int = maxi(amount * 2, 4)
	for i in samples:
		pts.append((b - a) * (float(i) / float(samples - 1)))
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = pts
	_launch(from, p, a)


## Atordoado: uma caveira pequena em cima do alvo e caveirinhas em volta
static func stun(target: Node2D) -> void:
	if not _ok(target):
		return
	skull(target, 0.7, 0.8, 0.9)


## Caveirinhas que acompanham a bola por "seconds" segundos (filho do sprite dela: segue a altura)
static func trail(ball: Ball, seconds: float = 0.5) -> void:
	if ball == null or not ball.is_inside_tree():
		return
	var p := _make(10, 0.55, 36.0, 0.12, 0.24)
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


## Aura contínua em volta do personagem (domínio da bola / Five Stage Volley). Vira filho do Nagi e
## começa DESLIGADA; quem a criou liga e desliga com "emitting".
static func make_aura(radius: float = 30.0) -> CPUParticles2D:
	var p := _make(8, 1.3, 22.0, 0.14, 0.28)
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.gravity = Vector2(0.0, -22.0)
	p.emitting = false
	return p
