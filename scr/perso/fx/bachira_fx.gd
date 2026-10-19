class_name BachiraFX
extends RefCounted
## Efeitos visuais do Bachira, no mesmo estilo do isagi_fx.gd. Tudo por código (nenhuma imagem):
##  - LABAREDAS pretas e amarelas: em todas as habilidades (chutes, avanço, aura do Instinct);
##  - ABELHINHAS: no Bee Shot e no Freedom;
##  - SILHUETA (o "monstro" do Bachira): invocada ao lado dele durante o Unleash Instinct.
##    Desenhada por código (corpo escuro, cabelo em chamas, olhos brancos brilhando e um sorriso
##    de dentes), ou use uma imagem sua passando "texture" (PNG com fundo transparente).
##
## Leve: texturas e degradês criados uma vez e guardados no Engine, poucos emissores
## CPUParticles2D "one_shot" de vida curta (apagam sozinhos). O único emissor contínuo é a aura
## (fica desligada quando não usada) e a silhueta só existe durante o Instinct.
## Quem chama passa um nó qualquer que já esteja na árvore (ex: o Bachira) em "from".

const BLACK := Color(0.05, 0.04, 0.03)
const YELLOW := Color(1.0, 0.84, 0.12)

const _KEY_FLAME := &"bachira_flame_tex"
const _KEY_BEE := &"bachira_bee_tex"
const _KEY_PICK := &"bachira_flame_pick"
const _KEY_FADE := &"bachira_fade"
const _KEY_SHRINK := &"bachira_shrink"

## Acima de tudo (jogadores e bola usam z_index = y como profundidade)
const FX_Z: int = 3000


# ---------- RECURSOS COMPARTILHADOS ----------

## Labareda (gota com a ponta curvada), branca, 32x40: a cor vem da partícula
static func flame_texture() -> ImageTexture:
	if Engine.has_meta(_KEY_FLAME):
		return Engine.get_meta(_KEY_FLAME) as ImageTexture
	var img := Image.create(32, 40, false, Image.FORMAT_RGBA8)
	for y in 40:
		for x in 32:
			var hits: int = 0
			for sy in 3:
				for sx in 3:
					if _in_flame(Vector2((float(x) + (float(sx) + 0.5) / 3.0) / 32.0,
							(float(y) + (float(sy) + 0.5) / 3.0) / 40.0)):
						hits += 1
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, float(hits) / 9.0))
	var tex := ImageTexture.create_from_image(img)
	Engine.set_meta(_KEY_FLAME, tex)
	return tex


static func _in_flame(uv: Vector2) -> bool:
	if uv.y < 0.04 or uv.y > 0.98:
		return false
	var t: float = (uv.y - 0.04) / 0.94                        # 0 = ponta, 1 = base
	var center: float = 0.5 + 0.12 * (1.0 - t) * sin(t * 5.0)   # a ponta balança para o lado
	var half: float = 0.44 * pow(maxf(sin(PI * pow(t, 0.8)), 0.0), 0.8)
	return absf(uv.x - center) <= half


## Abelhinha de cabeça para baixo (a cabeça no fundo da textura: com "align_y" ela voa de cabeça
## para a frente): corpo listrado de amarelo e preto, cabeça preta e asas claras. 20x28.
static func bee_texture() -> ImageTexture:
	if Engine.has_meta(_KEY_BEE):
		return Engine.get_meta(_KEY_BEE) as ImageTexture
	var img := Image.create(20, 28, false, Image.FORMAT_RGBA8)
	for y in 28:
		for x in 20:
			var hits: int = 0
			var col := Color(0, 0, 0, 0)
			for sy in 2:
				for sx in 2:
					var c: Color = _bee_pixel(Vector2(float(x) + (float(sx) + 0.5) / 2.0, float(y) + (float(sy) + 0.5) / 2.0))
					if c.a > 0.0:
						hits += 1
						col = c
			if hits > 0:
				img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * float(hits) / 4.0))
	var tex := ImageTexture.create_from_image(img)
	Engine.set_meta(_KEY_BEE, tex)
	return tex


static func _bee_pixel(p: Vector2) -> Color:
	# Cabeça (embaixo)
	if p.distance_to(Vector2(10.0, 24.0)) <= 3.6:
		return Color(0.06, 0.05, 0.04, 1.0)
	# Corpo: elipse com listras amarelas e pretas
	var q: Vector2 = (p - Vector2(10.0, 14.0)) / Vector2(5.6, 9.6)
	if q.length() <= 1.0:
		return YELLOW if int((p.y - 4.0) / 4.0) % 2 == 0 else Color(0.06, 0.05, 0.04, 1.0)
	# Asas (duas elipses claras e translúcidas)
	for wing in [Vector2(4.2, 11.0), Vector2(15.8, 11.0)]:
		var w: Vector2 = (p - wing) / Vector2(3.4, 6.2)
		if w.length() <= 1.0:
			return Color(0.88, 0.95, 1.0, 0.8)
	return Color(0, 0, 0, 0)


## Cada labareda nasce preta OU amarela (sorteio: degrau no meio do degradê)
static func _pick_ramp() -> Gradient:
	if Engine.has_meta(_KEY_PICK):
		return Engine.get_meta(_KEY_PICK) as Gradient
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.5])
	g.colors = PackedColorArray([BLACK, YELLOW])
	Engine.set_meta(_KEY_PICK, g)
	return g


static func _fade_ramp() -> Gradient:
	if Engine.has_meta(_KEY_FADE):
		return Engine.get_meta(_KEY_FADE) as Gradient
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	Engine.set_meta(_KEY_FADE, g)
	return g


## A labareda encolhe até quase nada no fim da vida
static func _shrink_curve() -> Curve:
	if Engine.has_meta(_KEY_SHRINK):
		return Engine.get_meta(_KEY_SHRINK) as Curve
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(1.0, 0.15))
	Engine.set_meta(_KEY_SHRINK, c)
	return c


static func _flame_particles(amount: int, lifetime: float, speed: float, size_min: float, size_max: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = flame_texture()
	p.color_initial_ramp = _pick_ramp()
	p.color_ramp = _fade_ramp()
	p.scale_amount_curve = _shrink_curve()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = Vector2.UP
	p.spread = 55.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.5
	p.damping_max = speed * 0.8
	p.gravity = Vector2(0.0, -110.0)    # as chamas sobem
	p.angle_min = -18.0
	p.angle_max = 18.0
	p.angular_velocity_min = -60.0
	p.angular_velocity_max = 60.0
	p.scale_amount_min = size_min
	p.scale_amount_max = size_max
	p.z_index = FX_Z
	p.z_as_relative = false
	return p


static func _launch(from: Node, p: CPUParticles2D, pos: Vector2) -> void:
	var tree: SceneTree = from.get_tree()
	var scene: Node = tree.current_scene
	(scene if scene != null else from).add_child(p)
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 0.85
	p.emitting = true
	tree.create_timer(p.lifetime + 0.4).timeout.connect(p.queue_free)


static func _ok(from: Node) -> bool:
	return from != null and from.is_inside_tree()


# ---------- EFEITOS ----------

## Labaredas pretas e amarelas subindo em volta de um ponto. strong = mais, maiores e mais altas.
static func flames(from: Node, pos: Vector2, amount: int = 12, strong: bool = false) -> void:
	if not _ok(from):
		return
	var p := _flame_particles(amount, 0.8 if strong else 0.6, 150.0 if strong else 110.0,
		1.1 if strong else 0.8, 1.7 if strong else 1.2)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 20.0 if strong else 13.0
	_launch(from, p, pos)


## Labaredas que nascem ao longo de uma linha (o avanço do Step Overs)
static func flame_line(from: Node, a: Vector2, b: Vector2, amount: int = 14) -> void:
	if not _ok(from):
		return
	var p := _flame_particles(amount, 0.65, 70.0, 0.8, 1.3)
	var pts := PackedVector2Array()
	var samples: int = maxi(amount * 2, 4)
	for i in samples:
		pts.append((b - a) * (float(i) / float(samples - 1)))
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = pts
	_launch(from, p, a)


## Abelhinhas que voam em espiral para fora de um ponto (Bee Shot e Freedom)
static func bees(from: Node, pos: Vector2, amount: int = 7) -> void:
	if not _ok(from):
		return
	var p := CPUParticles2D.new()
	p.texture = bee_texture()
	p.color_ramp = _fade_ramp()
	p.amount = amount
	p.lifetime = 1.2
	p.local_coords = false
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 130.0
	p.damping_min = 40.0
	p.damping_max = 70.0
	p.tangential_accel_min = -140.0     # fazem curva em volta do ponto, como um enxame
	p.tangential_accel_max = 140.0
	p.gravity = Vector2(0.0, -20.0)
	p.particle_flag_align_y = true      # voam de cabeça para a frente
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.05
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 10.0
	p.z_index = FX_Z
	p.z_as_relative = false
	_launch(from, p, pos)


## Aura contínua de labaredas (Unleash Instinct). Vira filha de quem a criou e começa DESLIGADA.
static func make_aura(radius: float = 24.0) -> CPUParticles2D:
	var p := _flame_particles(10, 0.7, 55.0, 0.7, 1.1)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.spread = 25.0
	p.gravity = Vector2(0.0, -75.0)
	p.emitting = false
	return p


## Invoca a silhueta saindo das costas do jogador; chame dismiss() nela para sumir. texture = imagem
## opcional (PNG com fundo transparente); vazia = desenhada por código.
static func summon_monster(owner_player: Player, texture: Texture2D = null) -> Monster:
	if not _ok(owner_player):
		return null
	var m := Monster.new(owner_player, texture)
	owner_player.get_tree().current_scene.add_child(m)
	return m


# ---------- A SILHUETA ----------

class Monster extends Node2D:
	var owner_player: Player
	var texture: Texture2D
	var height_px: float = 150.0   # unidade de desenho (a cabeça com o cabelo é o que mais pesa)
	var _age: float = 0.0
	var _alpha: float = 0.0
	var _dismissing: bool = false
	var _flames: CPUParticles2D

	func _init(p: Player, tex: Texture2D) -> void:
		owner_player = p
		texture = tex
		z_as_relative = false

	func _ready() -> void:
		_flames = BachiraFX.make_aura(22.0)
		_flames.amount = 12
		_flames.position = Vector2(0.0, -0.30 * height_px)   # nasce do corpo fino, perto das costas
		add_child(_flames)
		_flames.emitting = true
		_follow()

	func dismiss() -> void:
		_dismissing = true
		if _flames:
			_flames.emitting = false

	## Sai das COSTAS do dono: a base do corpo fica colada nas costas dele (mesma profundidade, 1
	## abaixo, então o Bachira fica na frente) e olha para o mesmo lado. Acompanha os saltos dele.
	func _follow() -> void:
		var f: float = owner_player.facing
		global_position = owner_player.global_position + Vector2(-f * 9.0, -owner_player.height)
		z_index = int(owner_player.global_position.y) - 1
		scale = Vector2(f, 1.0)
		# a mesma profundidade da chama: o emissor é filho e usa o z dele (acima de tudo)

	func _process(delta: float) -> void:
		_age += delta
		if not is_instance_valid(owner_player):
			queue_free()
			return
		_alpha = move_toward(_alpha, 0.0 if _dismissing else 1.0, delta * (3.0 if _dismissing else 2.2))
		if _dismissing and _alpha <= 0.01:
			queue_free()
			return
		_follow()
		queue_redraw()

	func _draw() -> void:
		var a: float = _alpha
		if a <= 0.01:
			return
		var t: float = _age
		var s: float = height_px
		var bob: float = sin(t * 2.2) * 2.0    # oscila de leve
		draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)

		if texture != null:   # imagem própria: só aparece com a névoa e o brilho
			var w: float = s * (texture.get_width() / maxf(texture.get_height(), 1.0))
			draw_texture_rect(texture, Rect2(Vector2(-w * 0.5, -s), Vector2(w, s)), false, Color(1, 1, 1, a * 0.95))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return

		var body: Color = Color(0.05, 0.03, 0.03, a * 0.93)
		var rim: Color = Color(0.45, 0.24, 0.12, a * 0.55)   # luz marrom nas bordas, como na imagem

		# Névoa escura na base (onde o corpo "nasce" das costas do Bachira)
		for i in 5:
			var ph: float = t * 0.7 + float(i) * 1.7
			var rise: float = fmod(ph, 3.0) / 3.0
			draw_circle(Vector2(-0.03 * s + sin(ph * 1.3 + float(i)) * 0.09 * s, (-0.10 - rise * 0.22) * s),
				(0.06 + 0.05 * rise) * s, Color(0.07, 0.05, 0.04, a * 0.30 * (1.0 - rise)))

		# Corpo ESGUIO que sai das costas: base larga e esfumaçada, cintura fina, ombros estreitos e
		# pescoço longo, inclinado para trás (e balançando de leve)
		var base := Vector2(-0.02, -0.10)
		var neck := Vector2(-0.10, -0.47)
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		var steps: int = 9
		for k in steps + 1:
			var u: float = float(k) / float(steps)
			var c: Vector2 = base.lerp(neck, u) + Vector2(-0.025 * sin(u * PI) + sin(t * 1.6 + u * 3.0) * 0.012 * u, 0.0)
			var w: float = lerpf(0.085, 0.032, smoothstep(0.0, 0.45, u))           # base -> cintura
			w = lerpf(w, 0.058, smoothstep(0.45, 0.85, u))                          # cintura -> ombros
			w = lerpf(w, 0.030, smoothstep(0.85, 1.0, u))                           # ombros -> pescoço
			left.append(c + Vector2(-w, 0.0))
			right.append(c + Vector2(w, 0.0))
		right.reverse()
		var torso := PackedVector2Array()
		torso.append_array(left)
		torso.append_array(right)
		_poly(torso, s, body, rim)

		# Braço comprido e fino, esticado por cima do ombro dele para a frente, com garras
		var shoulder := Vector2(-0.08, -0.43)
		var elbow := Vector2(0.10, -0.55 + sin(t * 1.4) * 0.01)
		var hand := Vector2(0.33, -0.47 + sin(t * 1.4 + 0.8) * 0.012)
		var arm_pts := PackedVector2Array([shoulder * s, elbow * s, hand * s])
		draw_polyline(arm_pts, rim, 0.052 * s, true)
		draw_polyline(arm_pts, body, 0.038 * s, true)
		for claw in [Vector2(0.43, -0.53), Vector2(0.45, -0.46), Vector2(0.41, -0.40)]:
			draw_line(hand * s, claw * s, body, 0.018 * s, true)

		# Cabelo em chamas (espetos que tremem)
		var head_c := Vector2(-0.07, -0.64)   # a cabeça é a mesma de antes, só desceu junto com o corpo mais curto
		var head_off: Vector2 = head_c - Vector2(0.04, -0.84)
		for i in 9:
			var ang: float = deg_to_rad(190.0 + float(i) * 20.0)
			var spike: float = 0.24 + 0.07 * sin(t * 6.0 + float(i) * 1.9) + (0.05 if i % 2 == 0 else 0.0)
			var base_a: Vector2 = head_c + Vector2.from_angle(ang - 0.17) * 0.14
			var base_b: Vector2 = head_c + Vector2.from_angle(ang + 0.17) * 0.14
			var tip: Vector2 = head_c + Vector2.from_angle(ang + 0.05 * sin(t * 4.0 + float(i))) * (0.14 + spike)
			_poly(PackedVector2Array([base_a, tip, base_b]), s, body, Color(0, 0, 0, 0))

		# Cabeça
		var head := PackedVector2Array()
		for i in 22:
			head.append(head_c + Vector2.from_angle(TAU * float(i) / 22.0) * Vector2(0.16, 0.145))
		_poly(head, s, body, rim)

		# Olhos brancos brilhando (inclinados) com halo
		var glow: float = 0.75 + 0.25 * sin(t * 3.0)
		for eye0 in [Vector2(-0.025, -0.865), Vector2(0.115, -0.855)]:
			var eye: Vector2 = eye0 + head_off
			var sign_x: float = -1.0 if eye0.x < 0.05 else 1.0
			draw_circle(eye * s, 0.085 * s, Color(1, 1, 1, a * 0.16 * glow))
			var pts := PackedVector2Array()
			for i in 12:
				var e: Vector2 = Vector2(cos(TAU * float(i) / 12.0) * 0.05, sin(TAU * float(i) / 12.0) * 0.024)
				pts.append((eye + e.rotated(0.45 * sign_x)) * s)
			draw_colored_polygon(pts, Color(1, 1, 1, a * glow))

		# Sorriso largo de dentes
		var smile := PackedVector2Array()
		for i in 11:
			var u: float = float(i) / 10.0
			smile.append((Vector2(lerpf(-0.07, 0.17, u), -0.775 + sin(u * PI) * 0.055) + head_off) * s)
		for i in range(10, -1, -1):
			var u: float = float(i) / 10.0
			smile.append((Vector2(lerpf(-0.07, 0.17, u), -0.775 + sin(u * PI) * 0.012) + head_off) * s)
		draw_colored_polygon(smile, Color(1, 1, 1, a * 0.95))
		for k in 7:   # dentes: riscos escuros finos
			var u2: float = (float(k) + 0.5) / 7.0
			var x: float = lerpf(-0.07, 0.17, u2)
			draw_line((Vector2(x, -0.775 + sin(u2 * PI) * 0.055) + head_off) * s,
				(Vector2(x, -0.775 + sin(u2 * PI) * 0.012) + head_off) * s, Color(0.06, 0.04, 0.04, a * 0.8), 1.5)

		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## Polígono em unidades da altura (s) com contorno opcional
	func _poly(pts: PackedVector2Array, s: float, fill: Color, edge: Color) -> void:
		var scaled := PackedVector2Array()
		for p in pts:
			scaled.append(p * s)
		draw_colored_polygon(scaled, fill)
		if edge.a > 0.01:
			var closed: PackedVector2Array = scaled.duplicate()
			closed.append(scaled[0])
			draw_polyline(closed, edge, 2.0, true)
