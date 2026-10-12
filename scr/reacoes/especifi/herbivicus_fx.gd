class_name HerbivicusFX
extends RefCounted
## Efeitos visuais da reação HERBIVICUS (Ness + Kaiser). Tudo é feito por código: não precisa de
## imagem nem de cena, e todos os efeitos se apagam sozinhos.
##
##  - attach_ball_glow(): halo + brilhos que acompanham a bola (Alohomora "carregado" e Emperor Impact);
##  - giant_rose(): a rosa azul translúcida GIGANTE que desabrocha no momento do chute;
##  - flash() / shake(): clarão azul na tela e tremida da câmera;
##  - sparkle_burst(): explosão de brilhos em um ponto.
##
## Quem chama passa um nó qualquer que já esteja na árvore (ex: self) em "from".

enum Style { PASS, SHOT }

const PINK := Color(1.0, 0.55, 0.9)
const BLUE_DEEP := Color(0.05, 0.16, 0.8)
const BLUE := Color(0.2, 0.5, 1.0)
const BLUE_LIGHT := Color(0.65, 0.88, 1.0)
const WHITE_GLOW := Color(0.94, 0.98, 1.0)


# ---------- UTILIDADES ----------

## Bolinha de luz macia (branca no centro, some na borda), para as partículas
static func soft_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 32
	tex.height = 32
	return tex


## Mistura "somar luz": faz tudo brilhar
static func additive_material() -> CanvasItemMaterial:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat


## Degradê da cor até transparente (as partículas somem aos poucos)
static func fade_ramp(color: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(color, 1.0))
	g.set_color(1, Color(color, 0.0))
	return g


static func _world(from: Node) -> Node:
	var scene: Node = from.get_tree().current_scene
	return scene if scene != null else from


# ---------- BRILHOS ----------

## Explosão de brilhos em uma posição global
static func sparkle_burst(from: Node, pos: Vector2, color: Color, amount: int = 24,
		speed: float = 160.0, scale_max: float = 0.35, lifetime: float = 0.8) -> void:
	if not is_instance_valid(from) or not from.is_inside_tree():
		return
	var p := CPUParticles2D.new()
	p.top_level = true
	p.texture = soft_texture()
	p.material = additive_material()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 0.8
	p.gravity = Vector2(0.0, -30.0)
	p.angle_max = 360.0
	p.scale_amount_min = scale_max * 0.4
	p.scale_amount_max = scale_max
	p.color_ramp = fade_ramp(color)
	p.z_index = 3000
	p.z_as_relative = false
	_world(from).add_child(p)
	p.global_position = pos
	p.emitting = true
	from.get_tree().create_timer(lifetime + 0.5).timeout.connect(p.queue_free)


## Halo + brilhos que acompanham a bola. Acaba sozinho (veja BallGlow).
## PASS = Alohomora carregado (rosa/azul, fica enquanto a bola paira);
## SHOT = Emperor Impact (azul forte, dura poucos segundos).
static func attach_ball_glow(ball: Ball, style: Style) -> void:
	if ball == null:
		return
	for child in ball.get_children():
		if child is BallGlow:
			child.queue_free()
	var glow := BallGlow.new()
	glow.ball = ball
	glow.touches = ball.interaction_count
	if style == Style.PASS:
		glow.primary = PINK
		glow.secondary = BLUE_LIGHT
		glow.radius = 34.0
		glow.sparkles = 22
		glow.end_when_released = true
	else:
		glow.primary = BLUE
		glow.secondary = WHITE_GLOW
		glow.radius = 54.0
		glow.sparkles = 46
		glow.max_age = 1.8
	ball.add_child(glow)


# ---------- TELA ----------

## Treme a câmera (Camera2D da cena). Sem câmera, não faz nada.
static func shake(from: Node, strength: float = 12.0, duration: float = 0.5) -> void:
	var cam: Camera2D = from.get_viewport().get_camera_2d()
	if cam == null:
		return
	if not cam.has_meta("herbivicus_base"):
		cam.set_meta("herbivicus_base", cam.offset)
	var base: Vector2 = cam.get_meta("herbivicus_base")
	var tw: Tween = cam.create_tween()
	tw.tween_method(_shake_step.bind(cam, base, strength), 0.0, 1.0, duration)
	tw.tween_callback(_shake_end.bind(cam, base))


static func _shake_step(t: float, cam: Camera2D, base: Vector2, strength: float) -> void:
	if not is_instance_valid(cam):
		return
	var k: float = 1.0 - t   # a tremida vai diminuindo
	cam.offset = base + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * k * k


static func _shake_end(cam: Camera2D, base: Vector2) -> void:
	if not is_instance_valid(cam):
		return
	cam.offset = base
	cam.remove_meta("herbivicus_base")


## Clarão colorido que cobre a tela e some
static func flash(from: Node, color: Color, peak_alpha: float = 0.7, duration: float = 0.5) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(color, peak_alpha)
	layer.add_child(rect)
	_world(from).add_child(layer)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tw: Tween = rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(layer.queue_free)


# ---------- ROSA GIGANTE ----------

## A rosa azul translúcida gigante: desabrocha (de dentro para fora), gira devagar, solta uma
## onda de choque e depois se desfaz em brilhos. "center" é uma posição global.
static func giant_rose(from: Node, center: Vector2, radius: float = 260.0) -> void:
	if not is_instance_valid(from) or not from.is_inside_tree():
		return
	var rose := GiantRose.new()
	rose.radius = radius
	_world(from).add_child(rose)
	rose.global_position = center
	sparkle_burst(from, center, BLUE_LIGHT, 44, 300.0, 0.8, 1.0)
	sparkle_burst(from, center, WHITE_GLOW, 26, 160.0, 0.5, 0.9)
	# No fim, as pétalas se desfazem em uma chuva de brilhos azuis
	from.get_tree().create_timer(1.3).timeout.connect(
		sparkle_burst.bind(from, center, BLUE, 60, 220.0, 0.7, 1.2))


## Tudo junto, no instante do chute do Emperor Impact
static func emperor_burst(from: Node, center: Vector2, ball: Ball, radius: float = 260.0) -> void:
	giant_rose(from, center, radius)
	flash(from, Color(0.55, 0.78, 1.0), 0.6, 0.55)
	shake(from, 16.0, 0.6)
	attach_ball_glow(ball, Style.SHOT)


# ---------- CLASSES INTERNAS ----------

## Halo que acompanha a bola (filho dela). Acaba quando alguém toca na bola, ela é segurada,
## passa do tempo máximo ou (end_when_released) ela deixa de pairar.
class BallGlow extends Node2D:
	var ball: Ball
	var touches: int = 0
	var primary: Color = Color.WHITE
	var secondary: Color = Color.WHITE
	var radius: float = 40.0
	var sparkles: int = 24
	var max_age: float = INF
	var end_when_released: bool = false

	var _age: float = 0.0
	var _fade: float = 1.0
	var _ending: bool = false
	var _stream: CPUParticles2D

	func _ready() -> void:
		top_level = true   # segue a bola por código (a altura do sprite não é a do nó da bola)
		z_index = 2
		material = HerbivicusFX.additive_material()
		_stream = CPUParticles2D.new()
		_stream.use_parent_material = true
		_stream.texture = HerbivicusFX.soft_texture()
		_stream.amount = sparkles
		_stream.lifetime = 0.8
		_stream.local_coords = false
		_stream.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		_stream.emission_sphere_radius = radius * 0.5
		_stream.direction = Vector2.UP
		_stream.spread = 180.0
		_stream.initial_velocity_min = 10.0
		_stream.initial_velocity_max = 60.0
		_stream.gravity = Vector2(0.0, -45.0)
		_stream.angle_max = 360.0
		_stream.scale_amount_min = 0.15
		_stream.scale_amount_max = 0.4
		_stream.color_ramp = HerbivicusFX.fade_ramp(secondary)
		add_child(_stream)
		_follow()

	func _follow() -> void:
		global_position = ball.sprite.global_position

	func _process(delta: float) -> void:
		_age += delta
		if not is_instance_valid(ball):
			queue_free()
			return
		_follow()
		if not _ending:
			if ball.interaction_count != touches or ball.is_held() or _age > max_age \
					or (end_when_released and not ball.hovering):
				_ending = true
				_stream.emitting = false
		if _ending:
			_fade -= delta / 0.35
			if _fade <= 0.0:
				queue_free()
				return
		queue_redraw()

	func _draw() -> void:
		var pulse: float = 0.5 + 0.5 * sin(_age * 9.0)
		# Halo em camadas (as de dentro são mais fortes)
		for i in 4:
			var f: float = float(4 - i) / 4.0   # 1.0 -> 0.25
			var r: float = radius * f * (0.9 + 0.2 * pulse)
			var c: Color = primary.lerp(secondary, 1.0 - f)
			c.a = 0.10 * (1.0 + (1.0 - f) * 2.0) * _fade
			draw_circle(Vector2.ZERO, r, c)
		# Raios de brilho girando (estrela de 4 pontas)
		var rays: float = radius * 1.1 * (0.8 + 0.4 * pulse)
		for i in 4:
			var a: float = _age * 2.0 + float(i) * PI * 0.5
			draw_line(Vector2.from_angle(a) * 4.0, Vector2.from_angle(a) * rays,
				Color(secondary, 0.8 * _fade), 2.0)


## A rosa gigante (desenhada por código). Fica em cima de tudo (menos do HUD).
class GiantRose extends Node2D:
	const PETALS := [9, 8, 7, 6, 5]   # pétalas de cada camada, da de fora para a de dentro

	var radius: float = 260.0
	var bloom_time: float = 0.75   # desabrochando
	var hold_time: float = 0.55    # parada, brilhando
	var fade_time: float = 0.7     # sumindo

	var _t: float = 0.0

	func _ready() -> void:
		z_index = 3000
		z_as_relative = false
		scale = Vector2(1.0, 0.85)   # um pouco achatada: combina com a visão 2.5D

	func _process(delta: float) -> void:
		_t += delta
		if _t >= bloom_time + hold_time + fade_time:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var bloom: float = clampf(_t / bloom_time, 0.0, 1.0)
		var fade: float = 1.0 - clampf((_t - bloom_time - hold_time) / fade_time, 0.0, 1.0)
		var ease_out: float = 1.0 - pow(1.0 - bloom, 3.0)

		# Disco de luz suave atrás da flor
		draw_circle(Vector2.ZERO, radius * 1.05 * ease_out, Color(HerbivicusFX.BLUE, 0.10 * fade))

		# Pétalas: camada 0 = de fora (maior), última = de dentro. As de dentro abrem primeiro.
		var layers: int = PETALS.size()
		for layer in layers:
			var k: float = float(layer) / float(layers - 1)   # 0 = fora, 1 = dentro
			var delay: float = (1.0 - k) * 0.5
			var p: float = clampf((bloom - delay) / 0.5, 0.0, 1.0)
			var open: float = 1.0 - pow(1.0 - p, 3.0)           # abre rápido e desacelera
			if open <= 0.0:
				continue
			var length: float = radius * lerpf(1.0, 0.25, k) * open
			var width: float = length * 0.5
			var count: int = PETALS[layer]
			var direction: float = 1.0 if layer % 2 == 0 else -1.0   # camadas giram em sentidos opostos
			var spin: float = _t * 0.35 * (1.0 + k) * direction + float(layer) * 0.4
			var base_col: Color = HerbivicusFX.BLUE_DEEP.lerp(HerbivicusFX.BLUE_LIGHT, k)
			var visible_amount: float = fade * minf(open * 1.5, 1.0)
			var fill := Color(base_col, lerpf(0.28, 0.5, k) * visible_amount)
			var edge := Color(HerbivicusFX.BLUE_LIGHT, 0.85 * visible_amount)
			for i in count:
				_draw_petal(spin + TAU * float(i) / float(count), length, width, fill, edge)

		# Coração da rosa: espiral clara
		var heart: float = radius * 0.22 * (1.0 - pow(1.0 - clampf(bloom * 1.4, 0.0, 1.0), 3.0))
		var pts := PackedVector2Array()
		for s in 60:
			var u: float = float(s) / 59.0
			pts.append(Vector2.from_angle(u * TAU * 2.5 + _t * 0.6) * heart * u)
		draw_polyline(pts, Color(HerbivicusFX.WHITE_GLOW, 0.8 * fade), 2.5, true)
		draw_circle(Vector2.ZERO, heart * 0.18, Color(HerbivicusFX.WHITE_GLOW, 0.6 * fade))

		# Onda de choque que sai da flor quando ela desabrocha
		if bloom < 1.0:
			draw_arc(Vector2.ZERO, radius * (0.4 + 1.1 * ease_out), 0.0, TAU, 72,
				Color(HerbivicusFX.BLUE_LIGHT, 0.8 * (1.0 - bloom)), 2.0 + 8.0 * (1.0 - bloom), true)

	## Uma pétala (formato de gota arredondada) saindo do centro, virada para "angle"
	func _draw_petal(angle: float, length: float, width: float, fill: Color, edge: Color) -> void:
		var steps: int = 10
		var pts := PackedVector2Array()
		for s in range(steps + 1):   # lado de cima, do centro até a ponta
			var t: float = float(s) / float(steps)
			var w: float = width * pow(maxf(sin(PI * pow(t, 0.8)), 0.0), 0.6)
			pts.append(Vector2(length * t, -w).rotated(angle))
		for s in range(steps - 1, 0, -1):   # lado de baixo, voltando (sem repetir ponta e centro)
			var t: float = float(s) / float(steps)
			var w: float = width * pow(maxf(sin(PI * pow(t, 0.8)), 0.0), 0.6)
			pts.append(Vector2(length * t, w).rotated(angle))
		draw_colored_polygon(pts, fill)
		var outline: PackedVector2Array = pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, edge, 2.0, true)
