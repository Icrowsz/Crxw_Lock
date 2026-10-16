class_name CruelFX
extends RefCounted
## Efeitos visuais da reação CRUEL (Charles + Rin). Tudo é feito por código: não precisa de imagem
## nem de cena, e todos os efeitos se apagam sozinhos. Este arquivo NÃO depende dos outros arquivos
## de efeitos (herbivicus_fx.gd, one_more_time_fx.gd).
##
##  CHARLES (Rabona Cross carregado) - amarelo e azul:
##   - summon_charles_demon(): um demônio gigante de caveira com chifres, cabelo desgrenhado, um
##     braço enorme segurando um bastão e uma mão de garras com uma lâmina surge por trás do Charles,
##     com um círculo mágico (estrela + olho) brilhando atrás dele;
##   - attach_ball_aura(ball, Style.RABONA): halo amarelo/azul e brilhos que seguem a bola.
##  RIN (Self Destruction) - preto com contorno azul-esverdeado:
##   - self_destruction_aura(): uma sombra gigante coberta de OLHOS, com uma mão (também com olhos)
##     sobre o Rin, um círculo mágico e uma roda de espinhos que nascem do chão em volta dele;
##   - self_destruction_launch(): no chute, clarão, tremida forte e espinhos nascendo ao longo da
##     trajetória da bola (attach_ball_aura(ball, Style.SELF_DESTRUCTION)).
##
## OTIMIZAÇÃO (para não travar no chute): os desenhos grandes são feitos UMA vez e só se movem /
## somem pelo nó (posição, escala, transparência), sem redesenhar a cada quadro; o demônio só
## redesenha ~10 vezes por segundo (para os cabelos balançarem e os olhos piscarem); texturas,
## materiais e degradês são reaproveitados; os espinhos são criados aos poucos (não todos no mesmo
## quadro) e há um limite de espinhos na tela (MAX_SPIKES).
##
## Quem chama passa um nó qualquer que já esteja na árvore (ex: self) em "from".

enum Style { RABONA, SELF_DESTRUCTION }

const GOLD := Color(1.0, 0.85, 0.2)
const GOLD_LIGHT := Color(1.0, 0.96, 0.6)
const ROYAL := Color(0.2, 0.5, 1.0)
const NAVY := Color(0.03, 0.05, 0.2)
const TEAL := Color(0.15, 0.95, 0.8)
const TEAL_LIGHT := Color(0.75, 1.0, 0.95)
const TEAL_DEEP := Color(0.05, 0.55, 0.5)
const BLACK := Color(0.015, 0.02, 0.03)

## Máximo de tufos de espinhos vivos ao mesmo tempo (acima disso, os novos são ignorados)
const MAX_SPIKES: int = 70

# Recursos reaproveitados (criar textura/material a cada brilho é caro)
static var _soft_tex: GradientTexture2D = null
static var _add_mat: CanvasItemMaterial = null
static var _ramps: Dictionary = {}
## Quantos tufos de espinhos existem agora (controlado pelos próprios tufos)
static var active_spikes: int = 0


# ---------- UTILIDADES ----------

## Bolinha de luz macia (branca no centro, some na borda). Criada uma vez só.
static func soft_texture() -> GradientTexture2D:
	if _soft_tex == null:
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
		_soft_tex = tex
	return _soft_tex


## Mistura "somar luz": faz tudo brilhar. Criada uma vez só.
static func additive_material() -> CanvasItemMaterial:
	if _add_mat == null:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_add_mat = mat
	return _add_mat


## Degradê da cor até transparente (as partículas somem aos poucos). Um por cor, reaproveitado.
static func fade_ramp(color: Color) -> Gradient:
	if _ramps.has(color):
		return _ramps[color] as Gradient
	var g := Gradient.new()
	g.set_color(0, Color(color, 1.0))
	g.set_color(1, Color(color, 0.0))
	_ramps[color] = g
	return g


static func _world(from: Node) -> Node:
	var scene: Node = from.get_tree().current_scene
	return scene if scene != null else from


## Onde colocar os efeitos do chão: junto com os jogadores (o z_index deles é a posição y)
static func _ground_parent(from: Node) -> Node:
	var p: Node = from.get_parent()
	return p if p != null else _world(from)


## Contorno de um olho em forma de amêndoa (lente), inclinado por "tilt" (radianos)
static func lens_points(center: Vector2, half_w: float, half_h: float, tilt: float,
		steps: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var t: float = -1.0 + 2.0 * float(i) / float(steps)
		pts.append(center + Vector2(t * half_w, -(1.0 - t * t) * half_h).rotated(tilt))
	for i in range(steps - 1, 0, -1):
		var t: float = -1.0 + 2.0 * float(i) / float(steps)
		pts.append(center + Vector2(t * half_w, (1.0 - t * t) * half_h).rotated(tilt))
	return pts


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


# ---------- TELA ----------

## Treme a câmera (Camera2D da cena). Sem câmera, não faz nada.
static func shake(from: Node, strength: float = 12.0, duration: float = 0.5) -> void:
	var cam: Camera2D = from.get_viewport().get_camera_2d()
	if cam == null:
		return
	if not cam.has_meta("cruel_base"):
		cam.set_meta("cruel_base", cam.offset)
	var base: Vector2 = cam.get_meta("cruel_base")
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
	cam.remove_meta("cruel_base")


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


# ---------- ESPINHOS ----------

## Um tufo de espinhos nascendo do chão em "pos" (global). "delay" = espera antes de nascer.
static func spike_burst(from: Node, pos: Vector2, scale_mult: float = 1.0, delay: float = 0.0,
		body: Color = BLACK, edge: Color = TEAL) -> void:
	if not is_instance_valid(from) or not from.is_inside_tree():
		return
	if active_spikes >= MAX_SPIKES:
		return   # já tem espinhos demais na tela: ignora (evita travar)
	var cluster := SpikeCluster.new()
	cluster.scale_mult = scale_mult
	cluster.delay = delay
	cluster.body = body
	cluster.edge = edge
	_ground_parent(from).add_child(cluster)
	cluster.global_position = pos
	cluster.z_index = int(pos.y)   # na frente de quem está atrás, atrás de quem está na frente


## Roda de espinhos em volta de um ponto do chão. Eles NÃO são criados todos de uma vez: um
## "criador" cria uns poucos por quadro, em sequência (isso evita a travada no instante do chute).
static func spike_ring(from: Node, ground: Vector2, radius: float, count: int,
		scale_mult: float = 1.0) -> void:
	if not is_instance_valid(from) or not from.is_inside_tree():
		return
	var spawner := SpikeSpawner.new()
	for i in count:
		var ang: float = TAU * float(i) / float(count) + randf_range(-0.12, 0.12)
		var r: float = radius * randf_range(0.85, 1.1)
		spawner.items.append({
			"pos": ground + Vector2(cos(ang) * r, sin(ang) * r * 0.6),   # achatada: visão 2.5D
			"scale": scale_mult * randf_range(0.85, 1.25),
			"delay": 0.035 * float(i),
		})
	_ground_parent(from).add_child(spawner)


# ---------- CHARLES: RABONA CROSS CARREGADO ----------

## O demônio gigante amarelo/azul cobre o Charles, com o círculo mágico (estrela + olho) atrás dele.
## "ground" = onde o Charles pisa (global); "body_height" = a altura dele (px).
static func summon_charles_demon(from: Node, ground: Vector2, body_height: float) -> void:
	if not is_instance_valid(from) or not from.is_inside_tree():
		return
	var center: Vector2 = ground + Vector2(0.0, -body_height)

	var demon := GiantDemon.new()
	demon.size = 430.0
	demon.horned = true
	demon.body_col = NAVY
	demon.edge_col = GOLD
	demon.eye_col = GOLD_LIGHT
	demon.glow_col = ROYAL
	demon.horn_col = Color(0.9, 0.75, 0.25)
	_ground_parent(from).add_child(demon)
	demon.global_position = center
	demon.z_index = int(ground.y) - 3   # bem atrás do Charles: ele aparece na frente, coberto pela sombra

	# Círculo mágico em pé, atrás do Charles (como na imagem de referência)
	var circle := MagicCircle.new()
	circle.vertical = true
	circle.radius = 140.0
	circle.main = GOLD
	circle.alt = ROYAL
	circle.life = 2.4
	_ground_parent(from).add_child(circle)
	circle.global_position = center + Vector2(0.0, -20.0)
	circle.z_index = int(ground.y) - 2

	sparkle_burst(from, center, GOLD, 24, 260.0, 0.7, 1.0)
	sparkle_burst(from, center, ROYAL, 16, 200.0, 0.6, 1.0)
	flash(from, GOLD, 0.25, 0.5)
	shake(from, 7.0, 0.6)


## No instante em que a bola sai no Rabona Cross carregado
static func rabona_burst(from: Node, pos: Vector2) -> void:
	sparkle_burst(from, pos, GOLD, 20, 280.0, 0.6, 0.9)
	sparkle_burst(from, pos, ROYAL, 14, 220.0, 0.5, 0.9)
	shake(from, 5.0, 0.35)


# ---------- RIN: SELF DESTRUCTION ----------

## A sombra gigante coberta de olhos sobe sobre o Rin, com uma mão enorme, o círculo mágico e uma
## roda de espinhos nascendo do chão em volta dele (durante a preparação do chute).
static func self_destruction_aura(from: Node, ground: Vector2, body_height: float) -> void:
	if not is_instance_valid(from) or not from.is_inside_tree():
		return
	var center: Vector2 = ground + Vector2(0.0, -body_height)

	var demon := GiantDemon.new()
	demon.size = 470.0
	demon.horned = false   # vários olhos e uma orbe, em vez de cabeça
	demon.body_col = BLACK
	demon.edge_col = TEAL
	demon.eye_col = TEAL_LIGHT
	demon.glow_col = TEAL_DEEP
	demon.rise_time = 0.45
	demon.hold_time = 1.4
	demon.fade_time = 0.8
	_ground_parent(from).add_child(demon)
	demon.global_position = center
	demon.z_index = int(ground.y) - 1

	var circle := MagicCircle.new()
	circle.radius = 190.0
	circle.main = TEAL
	circle.alt = TEAL_DEEP
	circle.life = 2.7
	_ground_parent(from).add_child(circle)
	circle.global_position = ground
	circle.z_index = int(ground.y) - 2

	spike_ring(from, ground, 130.0, 12, 1.0)
	sparkle_burst(from, center, TEAL, 24, 240.0, 0.7, 1.0)
	flash(from, TEAL, 0.35, 0.6)
	shake(from, 9.0, 0.7)


## No instante do chute: clarão, tremida forte, mais espinhos e a trilha de espinhos na bola
static func self_destruction_launch(from: Node, ground: Vector2, body_height: float, ball: Ball) -> void:
	if not is_instance_valid(from) or not from.is_inside_tree():
		return
	var center: Vector2 = ground + Vector2(0.0, -body_height)
	attach_ball_aura(ball, Style.SELF_DESTRUCTION)
	spike_ring(from, ground, 210.0, 18, 1.25)
	sparkle_burst(from, center, TEAL, 32, 320.0, 0.8, 1.0)
	sparkle_burst(from, center, TEAL_LIGHT, 16, 180.0, 0.5, 0.9)
	flash(from, TEAL_LIGHT, 0.65, 0.5)
	shake(from, 26.0, 0.85)


# ---------- AURA DA BOLA ----------

## Aura que acompanha a bola. RABONA: halo amarelo/azul e brilhos (fica enquanto a bola paira).
## SELF_DESTRUCTION: bola escura de contorno azul-esverdeado, com olhos, que deixa ESPINHOS
## nascendo por onde passa (dura poucos segundos). Acaba sozinha.
static func attach_ball_aura(ball: Ball, style: Style) -> void:
	if ball == null:
		return
	for child in ball.get_children():
		if child is BallAura:
			child.queue_free()
	var aura := BallAura.new()
	aura.ball = ball
	aura.touches = ball.interaction_count
	aura.style = style
	if style == Style.RABONA:
		aura.radius = 36.0
		aura.end_when_released = true
	else:
		aura.radius = 30.0
		aura.max_age = 2.4
	ball.add_child(aura)


# ---------- CLASSES INTERNAS ----------

## Cria os tufos de espinhos aos poucos (no máximo 2 por quadro), na ordem do atraso de cada um
class SpikeSpawner extends Node:
	var items: Array = []
	var _elapsed: float = 0.0

	func _process(delta: float) -> void:
		_elapsed += delta
		var spawned: int = 0
		while not items.is_empty() and float(items[0]["delay"]) <= _elapsed and spawned < 2:
			var item: Dictionary = items.pop_front()
			CruelFX.spike_burst(self, item["pos"], float(item["scale"]), 0.0)
			spawned += 1
		if items.is_empty():
			queue_free()


## Tufo de espinhos pretos de contorno brilhante que nasce do chão, fica um tempo e some.
## Desenhado UMA vez só: o "nascer" é a escala do nó e o "sumir" é a transparência.
class SpikeCluster extends Node2D:
	var scale_mult: float = 1.0
	var delay: float = 0.0
	var life: float = 2.4
	var body: Color = Color(0.015, 0.02, 0.03)   # preto (quem cria pode trocar)
	var edge: Color = Color(0.15, 0.95, 0.8)     # azul-esverdeado

	var _t: float = 0.0
	var _spikes: Array = []
	var _cracks: Array = []

	func _ready() -> void:
		CruelFX.active_spikes += 1
		_t = -delay
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var count: int = rng.randi_range(3, 5)
		for i in count:
			_spikes.append({
				"x": rng.randf_range(-18.0, 18.0) * scale_mult,
				"ang": rng.randf_range(-0.5, 0.5),
				"h": rng.randf_range(55.0, 125.0) * scale_mult,
				"w": rng.randf_range(9.0, 16.0) * scale_mult,
			})
		for i in 4:
			_cracks.append({"ang": rng.randf_range(0.0, TAU), "len": rng.randf_range(18.0, 46.0) * scale_mult})
		scale = Vector2(0.01, 0.01)
		visible = delay <= 0.0

	func _exit_tree() -> void:
		CruelFX.active_spikes = maxi(0, CruelFX.active_spikes - 1)

	func _process(delta: float) -> void:
		_t += delta
		if _t < 0.0:
			return
		if not visible:
			visible = true
		if _t >= life:
			queue_free()
			return
		var grow: float = clampf(_t / 0.16, 0.0, 1.0)
		var g: float = grow * (1.0 + 0.2 * sin(grow * PI))   # nasce com um "soquinho" a mais
		scale = Vector2(0.6 + 0.4 * g, g)
		modulate.a = 1.0 - clampf((_t - life * 0.6) / (life * 0.4), 0.0, 1.0)

	func _draw() -> void:
		# Rachaduras escuras no chão em volta
		for ck in _cracks:
			var d := Vector2(cos(float(ck["ang"])), sin(float(ck["ang"])) * 0.5)
			draw_line(d * 6.0, d * float(ck["len"]), Color(body, 0.8), 3.0)

		for sp in _spikes:
			var base := Vector2(float(sp["x"]), 0.0)
			var dir := Vector2(sin(float(sp["ang"])), -cos(float(sp["ang"])))   # para cima, um pouco torto
			var perp := Vector2(-dir.y, dir.x)
			var h: float = float(sp["h"])
			var w: float = float(sp["w"])
			var pts := PackedVector2Array([
				base - perp * w,
				base + dir * h * 0.30 - perp * w * 0.95,
				base + dir * h * 0.55 - perp * w * 0.40,
				base + dir * h * 0.62 - perp * w * 0.65,
				base + dir * h,
				base + dir * h * 0.58 + perp * w * 0.55,
				base + dir * h * 0.40 + perp * w * 0.35,
				base + dir * h * 0.22 + perp * w * 0.90,
				base + perp * w,
			])
			var closed: PackedVector2Array = pts.duplicate()
			closed.append(pts[0])
			draw_polyline(closed, Color(edge, 0.22), 8.0)   # brilho por trás
			draw_colored_polygon(pts, Color(body, 0.95))
			draw_polyline(closed, Color(edge, 0.95), 2.5)
			draw_line(base, base + dir * h * 0.85, Color(edge, 0.5), 1.2)   # reflexo no meio


## Círculo mágico: anéis, runas girando, estrela de 5 pontas e um olho no centro. No chão (achatado)
## ou "em pé" (vertical = true, de frente para a câmera, com raios de luz em volta). As partes fixas
## são desenhadas uma vez; só as runas e a estrela giram (girando o nó, sem redesenhar).
class MagicCircle extends Node2D:
	var radius: float = 160.0
	var main: Color = Color(1.0, 0.85, 0.2)   # quem cria troca
	var alt: Color = Color(0.2, 0.5, 1.0)
	var life: float = 2.4
	var vertical: bool = false

	var _t: float = 0.0
	var _squash: float = 0.55
	var _runes: CircleSpin
	var _star: CircleSpin

	func _ready() -> void:
		material = CruelFX.additive_material()
		_squash = 1.0 if vertical else 0.55   # no chão: visão de cima em 2.5D
		scale = Vector2(0.01, 0.01 * _squash)
		modulate.a = 0.0
		_runes = CircleSpin.new()
		_runes.mode = 0
		_runes.radius = radius
		_runes.color = main
		_runes.use_parent_material = true
		add_child(_runes)
		_star = CircleSpin.new()
		_star.mode = 1
		_star.radius = radius
		_star.color = main
		_star.use_parent_material = true
		add_child(_star)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		var grow: float = 1.0 - pow(1.0 - clampf(_t / 0.3, 0.0, 1.0), 3.0)
		scale = Vector2(grow, grow * _squash)
		modulate.a = 1.0 - clampf((_t - (life - 0.5)) / 0.5, 0.0, 1.0)
		_runes.rotation = _t * 0.6
		_star.rotation = -_t * 0.4

	func _draw() -> void:
		var r: float = radius
		draw_circle(Vector2.ZERO, r, Color(alt, 0.10))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(main, 0.9), 3.0)
		draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 48, Color(alt, 0.85), 2.0)
		draw_arc(Vector2.ZERO, r * 0.45, 0.0, TAU, 32, Color(main, 0.8), 2.0)
		if vertical:
			# Raios de luz saindo do círculo (como na imagem de referência)
			for i in 18:
				var ang: float = TAU * float(i) / 18.0
				var len_out: float = r * (1.35 if i % 2 == 0 else 1.7)
				draw_line(Vector2.from_angle(ang) * r * 1.05, Vector2.from_angle(ang) * len_out,
					Color(main, 0.35), 2.0)
		# Olho no centro
		var lens: PackedVector2Array = CruelFX.lens_points(Vector2.ZERO, r * 0.36, r * 0.16, 0.0)
		draw_colored_polygon(lens, Color(alt, 0.35))
		var closed: PackedVector2Array = lens.duplicate()
		closed.append(lens[0])
		draw_polyline(closed, Color(main, 0.95), 2.5)
		draw_circle(Vector2.ZERO, r * 0.11, Color(main, 0.9))
		draw_line(Vector2(0.0, -r * 0.1), Vector2(0.0, r * 0.1), Color(0.0, 0.0, 0.0, 0.9), 3.0)


## Parte que gira do círculo mágico. mode 0 = runas (risquinhos entre os anéis de fora);
## mode 1 = estrela de 5 pontas.
class CircleSpin extends Node2D:
	var mode: int = 0
	var radius: float = 160.0
	var color: Color = Color(1.0, 0.85, 0.2)

	func _draw() -> void:
		var r: float = radius
		if mode == 0:
			for i in 28:
				var ang: float = TAU * float(i) / 28.0
				var inner: float = r * (0.84 if i % 2 == 0 else 0.88)
				draw_line(Vector2.from_angle(ang) * inner, Vector2.from_angle(ang) * r * 0.98,
					Color(color, 0.8), 2.0)
		else:
			var star := PackedVector2Array()
			for i in 5:
				var ang: float = TAU * float((i * 2) % 5) / 5.0 - PI * 0.5
				star.append(Vector2.from_angle(ang) * r * 0.8)
			star.append(star[0])
			draw_polyline(star, Color(color, 0.85), 2.0)


## O demônio gigante.
##  horned = true (Charles): caveira de chifres e dentes, cabelo desgrenhado, um braço enorme
##    segurando um bastão com cristais e uma mão de garras com uma lâmina brilhando.
##  horned = false (Rin): massa de sombra coberta de olhos que piscam, uma orbe grande no meio e uma
##    mão enorme (com olhos na palma) descendo sobre o personagem.
## O (0,0) do nó é o centro do personagem; o demônio se ergue por trás e acima dele. O desenho é
## refeito só ~10 vezes por segundo (cabelos balançando, olhos piscando); subir e sumir é feito pela
## posição, escala e transparência do nó.
class GiantDemon extends Node2D:
	const BLOB_N: int = 32
	const REDRAW_EVERY: float = 0.1

	var size: float = 420.0
	# Cores padrão (quem cria troca): azul-marinho com contorno amarelo
	var body_col: Color = Color(0.03, 0.05, 0.2)
	var edge_col: Color = Color(1.0, 0.85, 0.2)
	var eye_col: Color = Color(1.0, 0.96, 0.6)
	var glow_col: Color = Color(0.2, 0.5, 1.0)
	var horn_col: Color = Color(0.85, 0.7, 0.25)
	var horned: bool = true
	var rise_time: float = 0.5
	var hold_time: float = 1.2
	var fade_time: float = 0.7

	var _t: float = 0.0
	var _redraw_acc: float = 0.0
	var _base_pos: Vector2 = Vector2.ZERO
	var _have_base: bool = false
	var _blob: Array = []
	var _strands: Array = []
	var _eyes: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in BLOB_N:
			_blob.append(rng.randf_range(0.84, 1.12))
		# Mechas de cabelo/pelo desgrenhado em volta da massa
		var strand_count: int = 46 if horned else 28
		for i in strand_count:
			_strands.append({
				"ang": TAU * float(i) / float(strand_count) + rng.randf_range(-0.1, 0.1),
				"len": rng.randf_range(0.16, 0.5),
				"phase": rng.randf_range(0.0, TAU),
				"w": rng.randf_range(0.012, 0.03),
				"tint": rng.randf() < 0.35,
			})
		if not horned:
			_scatter_eyes(rng, 24)
		modulate.a = 0.0
		scale = Vector2.ONE * 0.75

	## Espalha "count" olhos pela massa do Rin (sem tapar o personagem nem a orbe do meio)
	func _scatter_eyes(rng: RandomNumberGenerator, count: int) -> void:
		var tries: int = 0
		while _eyes.size() < count and tries < 400:
			tries += 1
			var ang: float = rng.randf_range(0.0, TAU)
			var rad: float = sqrt(rng.randf()) * 0.95
			var p := Vector2(cos(ang) * 0.8 * rad, -0.62 + sin(ang) * 0.56 * rad)   # em unidades de "size"
			if p.y > -0.22 or p.distance_to(Vector2(0.0, -0.66)) < 0.2:
				continue
			var ok: bool = true
			for e in _eyes:
				if Vector2(e["pos"]).distance_to(p) < 0.1:
					ok = false
					break
			if ok:
				_eyes.append({
					"pos": p,
					"size": rng.randf_range(0.028, 0.075),
					"tilt": rng.randf_range(-0.5, 0.5),
					"blink": rng.randf_range(2.0, 4.5),
					"off": rng.randf_range(0.0, 4.0),
				})

	func _process(delta: float) -> void:
		_t += delta
		if _t >= rise_time + hold_time + fade_time:
			queue_free()
			return
		if not _have_base:
			_base_pos = position
			_have_base = true
		# Subir, crescer e sumir: só mexe no nó (não redesenha)
		var rise: float = clampf(_t / rise_time, 0.0, 1.0)
		var rise_e: float = 1.0 - pow(1.0 - rise, 3.0)
		modulate.a = clampf(rise * 2.0, 0.0, 1.0) \
			* (1.0 - clampf((_t - rise_time - hold_time) / fade_time, 0.0, 1.0))
		position = _base_pos + Vector2(0.0, (1.0 - rise_e) * 0.3 * size)
		scale = Vector2.ONE * lerpf(0.75, 1.0, rise_e)
		_redraw_acc += delta
		if _redraw_acc >= REDRAW_EVERY:
			_redraw_acc = 0.0
			queue_redraw()

	func _draw() -> void:
		var s: float = size
		var c: Vector2 = Vector2(0.12 * s, -0.72 * s) if horned else Vector2(0.0, -0.62 * s)
		var rx: float = (0.95 if horned else 0.78) * s
		var ry: float = (0.62 if horned else 0.58) * s

		# Brilho de fundo
		draw_circle(c, 0.95 * s, Color(glow_col, 0.10))
		draw_circle(c, 0.70 * s, Color(glow_col, 0.10))
		if horned:
			# Raios de luz saindo de trás do personagem
			for i in 14:
				var ang: float = TAU * float(i) / 14.0 + 0.2
				draw_line(Vector2(0.0, -0.1 * s) + Vector2.from_angle(ang) * 0.35 * s,
					Vector2(0.0, -0.1 * s) + Vector2.from_angle(ang) * (0.8 + 0.3 * float(i % 3)) * s,
					Color(edge_col, 0.14), 3.0)

		# Cabelo / pelo desgrenhado (mechas pontudas que balançam, caindo para baixo/direita)
		for st in _strands:
			var ang: float = float(st["ang"])
			var dir := Vector2(cos(ang), sin(ang))
			var base: Vector2 = c + Vector2(dir.x * rx, dir.y * ry) * 0.92
			var flow: Vector2 = (dir * 0.6 + Vector2(0.35, 0.8)).normalized()
			var side: Vector2 = flow.orthogonal()
			var length: float = float(st["len"]) * s
			var sway: float = sin(_t * 2.2 + float(st["phase"])) * 0.05 * s
			var tip: Vector2 = base + flow * length + side * sway
			var mid: Vector2 = base + flow * length * 0.5 + side * sway * 0.4
			var w: float = float(st["w"]) * s
			var col: Color = glow_col.darkened(0.55) if bool(st["tint"]) else body_col
			var pts := PackedVector2Array([base - side * w, mid - side * w * 0.6, tip,
				mid + side * w * 0.6, base + side * w])
			draw_colored_polygon(pts, Color(col, 0.95))
			draw_polyline(pts, Color(edge_col, 0.55), 1.5)

		# Massa do corpo
		var blob_pts := PackedVector2Array()
		for i in BLOB_N:
			var ang: float = TAU * float(i) / float(BLOB_N)
			blob_pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry) * float(_blob[i]))
		_poly(blob_pts, Color(body_col, 0.9), Color(edge_col, 0.9), 4.0)

		if horned:
			_draw_horned_demon(s, c)
		else:
			_draw_many_eyes(s)
			_draw_hand(s)

	# ---------- CHARLES: caveira de chifres, braço com bastão, mão com lâmina ----------

	func _draw_horned_demon(s: float, c: Vector2) -> void:
		# ---------- AURA DE FUNDO ----------
		draw_circle(c, 0.95 * s, Color(glow_col, 0.08))
		draw_circle(c, 0.68 * s, Color(glow_col, 0.10))
		for i in 16:
			var ang: float = TAU * float(i) / 16.0 + 0.15
			var r_out: float = (0.82 + 0.28 * float(i % 3)) * s
			var pivot := Vector2(0.0, -0.1 * s)
			draw_line(pivot + Vector2.from_angle(ang) * 0.35 * s,
				pivot + Vector2.from_angle(ang) * r_out, Color(edge_col, 0.10), 2.0)

		# ---------- CORPO: FINO EMBAIXO, LARGO EM CIMA ----------
		# A "cabeça" do corpo fica em cima (ombros) e vai afinando até uma ponta
		# perto de c onde o Charles está — o demônio parece emergir dele.
		var top_y: float = c.y - 0.62 * s       # topo dos ombros
		var base_y: float = c.y + 1.05 * s      # ponta (raiz)
		# Perfil (t, largura relativa)
		var profile: Array = [
			[0.00, 0.42],   # ombros (mais largo)
			[0.18, 0.50],   # peitoral
			[0.38, 0.44],   # cintura alta
			[0.60, 0.30],   # abdômen baixo
			[0.82, 0.14],   # quadril
			[1.00, 0.03],   # ponta fina
		]
		var body := PackedVector2Array()
		body.append(Vector2(-0.10 * s, top_y - 0.05 * s))   # topo do pescoço (esq)
		body.append(Vector2(0.10 * s, top_y - 0.05 * s))    # topo do pescoço (dir)
		for i in profile.size():
			var t: float = float(profile[i][0])
			var w: float = float(profile[i][1]) * s
			body.append(Vector2(w, lerpf(top_y, base_y, t)))
		body.append(Vector2(0.0, base_y + 0.06 * s))        # ponta
		for i in range(profile.size() - 1, -1, -1):
			var t: float = float(profile[i][0])
			var w: float = float(profile[i][1]) * s
			body.append(Vector2(-w, lerpf(top_y, base_y, t)))
		draw_colored_polygon(body, Color(body_col, 0.92))
		var body_line := body.duplicate()
		body_line.append(body[0])
		draw_polyline(body_line, Color(edge_col, 0.9), 3.5)

		# Vinheta: contorno interno mais escuro dá volume
		draw_polyline(body_line, Color(0.0, 0.0, 0.0, 0.35), 8.0)

		# ---------- PEITORAL DEFINIDO ----------
		var pec_y: float = lerpf(top_y, base_y, 0.22)
		var pec_w: float = 0.42 * s
		for sgn in [-1.0, 1.0]:
			var side: float = float(sgn)
			# Contorno superior da peitoral (ombro -> esterno)
			var p_out := Vector2(side * pec_w, pec_y - 0.10 * s)
			var p_in  := Vector2(side * 0.08 * s, pec_y + 0.05 * s)
			draw_line(p_out, p_in, Color(edge_col, 0.85), 3.5)
			draw_line(p_out, p_in, Color(glow_col, 0.6), 1.5)
			# Contorno inferior (curva)
			draw_arc(Vector2(side * 0.24 * s, pec_y + 0.12 * s), 0.20 * s,
				PI * 0.15, PI * 0.85, 18, Color(edge_col, 0.8), 3.0)
			draw_arc(Vector2(side * 0.24 * s, pec_y + 0.12 * s), 0.20 * s,
				PI * 0.15, PI * 0.85, 18, Color(glow_col, 0.5), 1.4)
			# Fibras internas (risquinhos radiais)
			for f in 3:
				var t: float = 0.30 + 0.22 * float(f)
				var mid: Vector2 = p_out.lerp(p_in, t)
				var perp: Vector2 = (p_in - p_out).orthogonal().normalized() * 0.018 * s
				draw_line(p_out.lerp(p_in, t - 0.10), mid + perp, Color(glow_col, 0.35), 1.4)
				draw_line(mid + perp, p_out.lerp(p_in, t + 0.10), Color(glow_col, 0.35), 1.4)

		# Esterno
		draw_line(Vector2(0.0, pec_y - 0.16 * s), Vector2(0.0, pec_y + 0.32 * s),
			Color(edge_col, 0.7), 2.5)
		draw_line(Vector2(0.0, pec_y - 0.16 * s), Vector2(0.0, pec_y + 0.32 * s),
			Color(glow_col, 0.55), 1.2)

		# ---------- ABDÔMEN (gomos) ----------
		var abs_top: float = pec_y + 0.34 * s
		for row in 3:
			var y: float = abs_top + float(row) * 0.13 * s
			var w: float = lerpf(0.30, 0.16, float(row) / 2.0) * s
			draw_line(Vector2(-w, y), Vector2(w, y), Color(edge_col, 0.65), 2.5)
			draw_line(Vector2(-w, y), Vector2(w, y), Color(glow_col, 0.45), 1.2)
			draw_line(Vector2(0.0, y), Vector2(0.0, y + 0.12 * s), Color(edge_col, 0.6), 2.0)
			draw_line(Vector2(0.0, y), Vector2(0.0, y + 0.12 * s), Color(glow_col, 0.4), 1.0)

		# Oblíquos (V-shape)
		for sgn in [-1.0, 1.0]:
			var side: float = float(sgn)
			var a := Vector2(side * 0.42 * s, pec_y + 0.10 * s)
			var b := Vector2(side * 0.10 * s, abs_top + 0.42 * s)
			draw_line(a, b, Color(edge_col, 0.6), 2.5)
			draw_line(a, b, Color(glow_col, 0.45), 1.2)

		# Deltoides
		draw_arc(Vector2(-0.52 * s, pec_y - 0.14 * s), 0.16 * s, PI * 0.6, PI * 1.85, 16,
			Color(glow_col, 0.55), 3.0)
		draw_arc(Vector2(0.52 * s, pec_y - 0.14 * s), 0.16 * s, PI * 1.15, PI * 2.4, 16,
			Color(glow_col, 0.55), 3.0)

		# ---------- RAÍZES/TENTÁCULOS descendo até o Charles ----------
		for i in range(-2, 3):
			var base_x: float = float(i) * 0.05 * s
			var sway: float = sin(_t * 2.5 + float(i) * 1.7) * 0.05 * s
			var end_y: float = base_y + 0.30 * s + absf(float(i)) * 0.05 * s
			var ctrl := Vector2(base_x + sway, base_y + 0.14 * s)
			var pts := PackedVector2Array()
			for k in 7:
				var u: float = float(k) / 6.0
				var pt: Vector2 = (1.0 - u) * (1.0 - u) * Vector2(base_x, base_y) \
					+ 2.0 * (1.0 - u) * u * ctrl \
					+ u * u * Vector2(base_x + sway * 2.0, end_y)
				pts.append(pt)
			draw_polyline(pts, Color(body_col, 0.75), 3.5 - absf(float(i)) * 0.6)
			draw_polyline(pts, Color(edge_col, 0.45), 1.2)
			draw_circle(Vector2(base_x + sway * 2.0, end_y), 1.5, Color(glow_col, 0.6))

		# Braços, bastão, lâmina e crânio: mantenha o resto do método original
		# (a parte abaixo é a mesma de antes; só o "corpo" mudou de forma)
		var staff_a := Vector2(1.18 * s, -1.38 * s)
		var staff_b := Vector2(0.26 * s, 0.22 * s)
		draw_line(staff_a, staff_b, Color(glow_col, 0.20), 0.13 * s)
		draw_line(staff_a, staff_b, Color(edge_col, 0.95), 0.075 * s)
		draw_line(staff_a, staff_b, Color(body_col.darkened(0.3), 0.98), 0.05 * s)
		for k in 5:
			var u: float = 0.15 + 0.18 * float(k)
			var p: Vector2 = staff_a.lerp(staff_b, u)
			draw_circle(p, 0.075 * s, Color(glow_col, 0.20))
			draw_circle(p, 0.045 * s, Color(glow_col, 0.55))
			var crystal := PackedVector2Array([
				p + Vector2(0.0, -0.042 * s), p + Vector2(0.026 * s, 0.0),
				p + Vector2(0.0, 0.042 * s), p + Vector2(-0.026 * s, 0.0)])
			draw_colored_polygon(crystal, Color(glow_col, 0.95))
			var cline := crystal.duplicate()
			cline.append(crystal[0])
			draw_polyline(cline, Color(edge_col, 1.0), 1.5)
		draw_circle(staff_b, 0.11 * s, Color(eye_col, 0.20))
		draw_circle(staff_b, 0.07 * s, Color(eye_col, 0.55))
		draw_circle(staff_b, 0.035 * s, Color(1.0, 1.0, 1.0, 0.95))

		var fist: Vector2 = staff_a.lerp(staff_b, 0.55)
		_draw_demon_arm(Vector2(0.66 * s, -0.38 * s), Vector2(0.95 * s, -0.58 * s),
			Vector2(1.05 * s, -0.85 * s), fist, s)
		_draw_demon_fist(fist, s, -1.0)
		var l_hand := Vector2(-0.85 * s, -0.32 * s)
		_draw_demon_arm(Vector2(-0.62 * s, -0.38 * s), Vector2(-0.88 * s, -0.55 * s),
			Vector2(-0.98 * s, -0.62 * s), l_hand, s)
		var blade_tip := Vector2(-1.3 * s, 0.02 * s)
		var blade_dir: Vector2 = (blade_tip - l_hand).normalized()
		var blade_side: Vector2 = blade_dir.orthogonal()
		var blade_len: float = l_hand.distance_to(blade_tip)
		draw_line(l_hand, blade_tip, Color(glow_col, 0.35), 0.08 * s)
		var blade := PackedVector2Array([
			l_hand - blade_side * 0.020 * s,
			l_hand + blade_dir * blade_len * 0.55 - blade_side * 0.030 * s,
			blade_tip,
			l_hand + blade_dir * blade_len * 0.55 + blade_side * 0.030 * s,
			l_hand + blade_side * 0.020 * s])
		draw_circle(blade_tip, 0.10 * s, Color(glow_col, 0.25))
		_poly(blade, Color(glow_col.lightened(0.5), 0.95), Color(edge_col, 1.0), 2.5)
		_draw_demon_fist(l_hand, s, 1.0)

		_draw_skull(s)

	## Braço com bíceps/tríceps marcados e antebraço afunilado
	func _draw_demon_arm(shoulder: Vector2, bicep: Vector2, elbow: Vector2, hand: Vector2, s: float) -> void:
		_draw_tube(PackedVector2Array([shoulder, bicep, elbow, hand]), 0.20 * s, 0.10 * s,
			Color(edge_col, 0.95), Color(edge_col, 0.95))
		_draw_tube(PackedVector2Array([shoulder, bicep, elbow, hand]), 0.17 * s, 0.08 * s,
			Color(body_col.lightened(0.08), 0.97), Color(body_col.lightened(0.08), 0.97))
		draw_arc(bicep, 0.10 * s, PI * 1.15, PI * 2.05, 14, Color(glow_col, 0.50), 3.0)
		draw_arc(elbow, 0.08 * s, PI * 0.35, PI * 1.10, 12, Color(glow_col, 0.40), 2.5)
		draw_line(shoulder + (bicep - shoulder) * 0.35, elbow, Color(glow_col, 0.30), 1.5)

	## Punho fechado com dedos marcados e garras. side = -1 (esq) ou +1 (dir)
	func _draw_demon_fist(center: Vector2, s: float, side: float) -> void:
		var palm := PackedVector2Array()
		for i in 12:
			var ang: float = TAU * float(i) / 12.0
			palm.append(center + Vector2(cos(ang) * 0.105, sin(ang) * 0.09) * s)
		draw_colored_polygon(palm, Color(body_col.lightened(0.12), 0.98))
		var pline := palm.duplicate()
		pline.append(palm[0])
		draw_polyline(pline, Color(edge_col, 0.95), 3.0)
		for k in 4:
			var kp: Vector2 = center + Vector2(side * 0.075 * s, (-0.065 + 0.045 * float(k)) * s)
			draw_circle(kp, 0.032 * s, Color(body_col.lightened(0.2), 1.0))
			draw_arc(kp, 0.032 * s, 0.0, TAU, 10, Color(edge_col, 0.9), 2.0)
			draw_line(kp, kp + Vector2(side * 0.095 * s, 0.065 * s), Color(eye_col, 0.95), 2.5)
			draw_line(kp, kp + Vector2(side * 0.075 * s, 0.050 * s), Color(glow_col, 0.6), 1.2)

	## Chifre que afina (contorno + miolo com espessuras variáveis)
	func _draw_tapered_horn(pts: PackedVector2Array, widths: Array[float], fill: Color, edge: Color) -> void:
		for i in range(pts.size() - 1):
			draw_line(pts[i], pts[i + 1], Color(edge, 0.95), (widths[i] + 0.015) * 2.0)
			draw_circle(pts[i], widths[i] + 0.015, Color(edge, 0.95))
		draw_circle(pts[pts.size() - 1], widths[widths.size() - 1] + 0.015, Color(edge, 0.95))
		for i in range(pts.size() - 1):
			draw_line(pts[i], pts[i + 1], Color(fill, 0.97), widths[i] * 2.0)
			draw_circle(pts[i], widths[i], Color(fill, 0.97))
		draw_circle(pts[pts.size() - 1], widths[widths.size() - 1], Color(fill, 0.97))

	## Cabeça: chifres curvos e afilados, órbitas profundas, dentes afiados
	func _draw_skull(s: float) -> void:
		draw_set_transform(Vector2(-0.5 * s, -0.98 * s), 0.35, Vector2.ONE)

		# ---------- CHIFRES ----------
		var left_horn := PackedVector2Array()
		var right_horn := PackedVector2Array()
		var lw: Array[float] = []
		var rw: Array[float] = []
		for k in 14:
			var u: float = float(k) / 13.0
			left_horn.append(Vector2(-0.15 - 0.55 * u, -0.22 - 0.50 * u + 0.55 * u * u) * s)
			lw.append(lerpf(0.075, 0.006, pow(u, 0.7)))
			right_horn.append(Vector2(0.15 + 0.55 * u, -0.22 - 0.65 * u + 0.42 * u * u) * s)
			rw.append(lerpf(0.078, 0.006, pow(u, 0.7)))
		_draw_tapered_horn(left_horn, lw, horn_col, edge_col)
		_draw_tapered_horn(right_horn, rw, horn_col, edge_col)
		# Anéis (marcas) ao longo dos chifres
		for k in 5:
			var idx: int = 2 + k * 2
			var lp: Vector2 = left_horn[idx]
			var rp: Vector2 = right_horn[idx]
			var ld: Vector2 = (left_horn[idx + 1] - left_horn[idx - 1]).normalized()
			var rd: Vector2 = (right_horn[idx + 1] - right_horn[idx - 1]).normalized()
			draw_line(lp - ld * 0.03 * s, lp + ld * 0.03 * s, Color(edge_col, 0.85), 2.0)
			draw_line(rp - rd * 0.03 * s, rp + rd * 0.03 * s, Color(edge_col, 0.85), 2.0)

		# ---------- CRÂNIO ----------
		var skull := PackedVector2Array([
			Vector2(-0.24, -0.08), Vector2(-0.20, -0.24), Vector2(-0.10, -0.32),
			Vector2(0.10, -0.32), Vector2(0.20, -0.24), Vector2(0.24, -0.08),
			Vector2(0.20, 0.06), Vector2(0.14, 0.20), Vector2(0.08, 0.26),
			Vector2(-0.08, 0.26), Vector2(-0.14, 0.20), Vector2(-0.20, 0.06)])
		var scaled := PackedVector2Array()
		for p in skull:
			scaled.append(p * s)
		draw_colored_polygon(scaled, Color(body_col.lightened(0.06), 0.98))
		var outline := scaled.duplicate()
		outline.append(scaled[0])
		draw_polyline(outline, Color(edge_col, 1.0), 3.5)
		# Maçãs do rosto
		draw_arc(Vector2(-0.14 * s, 0.0), 0.07 * s, PI * 0.2, PI * 0.9, 10, Color(glow_col, 0.35), 2.0)
		draw_arc(Vector2(0.14 * s, 0.0), 0.07 * s, PI * 0.1, PI * 0.8, 10, Color(glow_col, 0.35), 2.0)

		# ---------- ÓRBITAS E OLHOS ----------
		var pulse: float = 0.9 + 0.1 * sin(_t * 5.0)
		for sgn in [-1.0, 1.0]:
			var side: float = float(sgn)
			var socket := Vector2(side * 0.10 * s, -0.09 * s)
			draw_colored_polygon(CruelFX.lens_points(socket, 0.10 * s, 0.075 * s, -side * 0.4),
				Color(0.0, 0.0, 0.0, 0.98))
			var sp := CruelFX.lens_points(socket, 0.10 * s, 0.075 * s, -side * 0.4)
			var sline := sp.duplicate()
			sline.append(sp[0])
			draw_polyline(sline, Color(edge_col, 0.75), 2.0)
			_draw_eye(socket, 0.075 * s, 0.045 * s, -side * 0.4, pulse, 1.0)

		# Nariz + rachaduras
		draw_colored_polygon(PackedVector2Array([Vector2(-0.03 * s, 0.04 * s), Vector2(0.0, 0.0),
			Vector2(0.03 * s, 0.04 * s), Vector2(0.0, 0.07 * s)]), Color(0.0, 0.0, 0.0, 0.9))
		draw_line(Vector2(-0.16 * s, -0.22 * s), Vector2(-0.10 * s, -0.14 * s), Color(edge_col, 0.55), 1.5)
		draw_line(Vector2(-0.10 * s, -0.14 * s), Vector2(-0.13 * s, -0.08 * s), Color(edge_col, 0.55), 1.2)
		draw_line(Vector2(0.15 * s, -0.24 * s), Vector2(0.10 * s, -0.15 * s), Color(edge_col, 0.55), 1.5)

		# ---------- DENTES ----------
		var bone := Color(0.95, 0.92, 0.8, 0.98)
		for i in 9:
			var x: float = (-0.12 + 0.03 * float(i)) * s
			var tl: float = (0.05 if i % 2 == 0 else 0.075) * s
			var tooth := PackedVector2Array([Vector2(x - 0.013 * s, 0.14 * s),
				Vector2(x + 0.013 * s, 0.14 * s), Vector2(x, 0.14 * s + tl)])
			draw_colored_polygon(tooth, bone)
			draw_polyline(PackedVector2Array([tooth[0], tooth[1], tooth[2], tooth[0]]), Color(edge_col, 0.5), 1.0)
		for i in 8:
			var x: float = (-0.105 + 0.03 * float(i)) * s
			var tl: float = (0.04 if i % 2 == 0 else 0.06) * s
			var tooth := PackedVector2Array([Vector2(x - 0.012 * s, 0.21 * s),
				Vector2(x + 0.012 * s, 0.21 * s), Vector2(x, 0.21 * s - tl)])
			draw_colored_polygon(tooth, bone)
			draw_polyline(PackedVector2Array([tooth[0], tooth[1], tooth[2], tooth[0]]), Color(edge_col, 0.5), 1.0)

		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ---------- RIN: olhos por toda parte, orbe e mão ----------

	func _draw_many_eyes(s: float) -> void:
		var idx: int = 0
		for e in _eyes:
			var pulse: float = 0.9 + 0.1 * sin(_t * 5.0 + float(idx))
			# Piscar: de vez em quando o olho fecha e abre rápido
			var open: float = 1.0
			var ph: float = fposmod(_t + float(e["off"]), float(e["blink"]))
			if ph < 0.2:
				open = clampf(absf(ph / 0.1 - 1.0), 0.1, 1.0)
			var sz: float = float(e["size"]) * s
			_draw_eye(Vector2(e["pos"]) * s, sz * 1.6, sz * 0.8, float(e["tilt"]), pulse, open)
			idx += 1
		_draw_orb(Vector2(0.0, -0.66 * s), 0.13 * s)

	## Mão enorme descendo sobre o personagem, com garras brilhando e olhos na palma
	func _draw_hand(s: float) -> void:
		var palm_c := Vector2(0.5 * s, -0.62 * s)
		var target := Vector2(0.0, -0.18 * s)   # em cima do personagem
		var dir0: Vector2 = (target - palm_c).normalized()

		var palm := PackedVector2Array()
		for i in 14:
			var ang: float = TAU * float(i) / 14.0
			palm.append(palm_c + Vector2(cos(ang) * 0.2, sin(ang) * 0.16).rotated(dir0.angle()) * s)
		_poly(palm, Color(body_col, 0.95), Color(edge_col, 0.95), 3.0)
		# Olhos na palma
		_draw_eye(palm_c + Vector2(-0.05 * s, -0.04 * s), 0.05 * s, 0.026 * s, 0.3, 1.0, 1.0)
		_draw_eye(palm_c + Vector2(0.06 * s, 0.0), 0.04 * s, 0.022 * s, -0.3, 1.0, 1.0)
		_draw_eye(palm_c + Vector2(-0.01 * s, 0.06 * s), 0.035 * s, 0.02 * s, 0.1, 1.0, 1.0)

		for i in 5:
			var fa: float = (float(i) - 2.0) * 0.34
			var d: Vector2 = dir0.rotated(fa)
			var start: Vector2 = palm_c + d * 0.16 * s
			var fl: float = (0.42 + 0.06 * (1.0 - absf(float(i) - 2.0) / 2.0)) * s
			var tip: Vector2 = start + d * fl - dir0.orthogonal() * fa * 0.12 * s   # curva para dentro (garra)
			var ctrl: Vector2 = start + d * fl * 0.55 + dir0.orthogonal() * 0.07 * s
			var pts := PackedVector2Array()
			for k in 9:
				var u: float = float(k) / 8.0
				pts.append((1.0 - u) * (1.0 - u) * start + 2.0 * (1.0 - u) * u * ctrl + u * u * tip)
			_draw_tube(pts, 0.045 * s, 0.006 * s, Color(body_col, 0.95), Color(edge_col, 0.95))
			# Ponta da garra brilhando
			draw_circle(tip, 0.04 * s, Color(eye_col, 0.25))
			draw_circle(tip, 0.016 * s, Color(eye_col, 1.0))

	# ---------- PEÇAS COMUNS ----------

	## Olho em forma de amêndoa, brilhando, com uma fenda no meio. open = 1 aberto, ~0.1 fechado.
	func _draw_eye(pos: Vector2, hw: float, hh: float, tilt: float, pulse: float, open: float) -> void:
		var h2: float = maxf(hh * open, 1.0)
		for i in 3:
			draw_circle(pos, hw * (1.9 - float(i) * 0.45) * pulse, Color(glow_col, 0.10))
		_poly(CruelFX.lens_points(pos, hw, h2, tilt), Color(eye_col, 0.95), Color(edge_col, 1.0), 2.0)
		draw_colored_polygon(CruelFX.lens_points(pos, hw * 0.55, h2 * 0.55, tilt), Color(1.0, 1.0, 1.0, 0.9))
		if open > 0.4:
			draw_line(pos + Vector2(0.0, -h2 * 0.8), pos + Vector2(0.0, h2 * 0.8), Color(body_col, 1.0), 3.0)

	## Orbe grande com um olho girando (estilo "olho no centro")
	func _draw_orb(pos: Vector2, r: float) -> void:
		draw_circle(pos, r * 1.7, Color(glow_col, 0.10))
		draw_circle(pos, r * 1.3, Color(glow_col, 0.15))
		draw_circle(pos, r, Color(body_col.darkened(0.2), 0.95))
		draw_arc(pos, r, 0.0, TAU, 32, Color(edge_col, 1.0), 3.5)
		for i in 3:
			var start: float = _t * (1.5 - float(i) * 0.6) + float(i)
			draw_arc(pos, r * (0.45 + 0.15 * float(i)), start, start + PI * 1.2, 16, Color(edge_col, 0.8), 2.0)
		draw_circle(pos, r * 0.32, Color(eye_col, 0.95))
		draw_circle(pos, r * 0.16, Color(1.0, 1.0, 1.0, 0.95))

	## Polígono preenchido com contorno (só para formas simples: sempre dá para triangular)
	func _poly(pts: PackedVector2Array, fill: Color, edge: Color, width: float) -> void:
		if pts.size() < 3:
			return
		draw_colored_polygon(pts, fill)
		var closed: PackedVector2Array = pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, edge, width)

	## Tubo que afina (chifre, dedo, braço): segmentos de linha de contorno + de preenchimento
	func _draw_tube(pts: PackedVector2Array, w0: float, w1: float, fill: Color, edge: Color) -> void:
		var n: int = pts.size() - 1
		if n < 1:
			return
		for pass_i in 2:
			var col: Color = edge if pass_i == 0 else fill
			var extra: float = 4.0 if pass_i == 0 else 0.0
			for i in n:
				var w: float = lerpf(w0, w1, float(i) / float(n)) + extra
				draw_line(pts[i], pts[i + 1], col, w)
				draw_circle(pts[i], w * 0.5, col)
			draw_circle(pts[n], (w1 + extra) * 0.5, col)


## Aura que acompanha a bola (filha dela). Acaba quando alguém toca na bola, ela é segurada, passa do
## tempo máximo ou (end_when_released) ela deixa de pairar. Redesenha ~30 vezes por segundo.
class BallAura extends Node2D:
	var ball: Ball
	var touches: int = 0
	var style: int = 0   # CruelFX.Style
	var radius: float = 36.0
	var max_age: float = INF
	var end_when_released: bool = false

	var _age: float = 0.0
	var _fade: float = 1.0
	var _ending: bool = false
	var _redraw_acc: float = 0.0
	var _last_stamp: Vector2 = Vector2.ZERO
	var _has_stamp: bool = false
	var _sparks: CPUParticles2D

	func _ready() -> void:
		top_level = true   # segue a bola por código (a altura do sprite não é a do nó da bola)
		z_index = 2
		var rabona: bool = style == CruelFX.Style.RABONA
		if rabona:
			material = CruelFX.additive_material()   # tudo brilha (os brilhos herdam o material)

		_sparks = CPUParticles2D.new()
		if rabona:
			_sparks.use_parent_material = true
		else:
			_sparks.material = CruelFX.additive_material()
		_sparks.texture = CruelFX.soft_texture()
		_sparks.amount = 30 if rabona else 24
		_sparks.lifetime = 0.8
		_sparks.local_coords = false
		_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		_sparks.emission_sphere_radius = radius * 0.6
		_sparks.direction = Vector2.UP
		_sparks.spread = 180.0
		_sparks.initial_velocity_min = 10.0
		_sparks.initial_velocity_max = 70.0
		_sparks.gravity = Vector2(0.0, -40.0)
		_sparks.angle_max = 360.0
		_sparks.scale_amount_min = 0.15
		_sparks.scale_amount_max = 0.45
		_sparks.color_ramp = CruelFX.fade_ramp(CruelFX.GOLD if rabona else CruelFX.TEAL)
		add_child(_sparks)
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
				_sparks.emitting = false
			elif style == CruelFX.Style.SELF_DESTRUCTION:
				_stamp_spikes()
		if _ending:
			_fade -= delta / 0.35
			if _fade <= 0.0:
				queue_free()
				return
		_redraw_acc += delta
		if _redraw_acc >= 0.033:
			_redraw_acc = 0.0
			queue_redraw()

	## Espinhos nascendo dos dois lados da trajetória, a cada ~64 px andados
	func _stamp_spikes() -> void:
		var gp: Vector2 = ball.global_position
		if _has_stamp and gp.distance_to(_last_stamp) < 64.0:
			return
		_last_stamp = gp
		_has_stamp = true
		var dir: Vector2 = ball.velocity.normalized() if ball.velocity.length() > 1.0 else Vector2.RIGHT
		var perp: Vector2 = dir.orthogonal()
		CruelFX.spike_burst(ball, gp + perp * randf_range(30.0, 48.0), 0.9)
		CruelFX.spike_burst(ball, gp - perp * randf_range(30.0, 48.0), 0.9, 0.04)

	func _draw() -> void:
		var pulse: float = 0.5 + 0.5 * sin(_age * 9.0)
		if style == CruelFX.Style.RABONA:
			_draw_rabona(pulse)
		else:
			_draw_self_destruction(pulse)

	## Halo amarelo/azul, estrela de 8 raios e um olho de demônio dourado vigiando a bola
	func _draw_rabona(pulse: float) -> void:
		for i in 4:
			var f: float = float(4 - i) / 4.0   # 1.0 -> 0.25
			var c: Color = CruelFX.ROYAL.lerp(CruelFX.GOLD, 1.0 - f)
			c.a = 0.10 * (1.0 + (1.0 - f) * 2.0) * _fade
			draw_circle(Vector2.ZERO, radius * f * (0.9 + 0.2 * pulse), c)
		var rays: float = radius * 1.2 * (0.8 + 0.4 * pulse)
		for i in 8:
			var ang: float = _age * 1.8 + float(i) * PI / 4.0
			var col: Color = CruelFX.GOLD if i % 2 == 0 else CruelFX.ROYAL
			draw_line(Vector2.from_angle(ang) * 4.0, Vector2.from_angle(ang) * rays, Color(col, 0.85 * _fade), 2.0)
		var eye_pos := Vector2(0.0, -radius * 1.35)
		draw_colored_polygon(CruelFX.lens_points(eye_pos, radius * 0.38, radius * 0.17, 0.0, 6),
			Color(CruelFX.GOLD, 0.7 * _fade))
		draw_line(eye_pos + Vector2(0.0, -radius * 0.14), eye_pos + Vector2(0.0, radius * 0.14),
			Color(0.0, 0.0, 0.1, _fade), 3.0)

	## Bola escura de contorno azul-esverdeado, com espinhos girando e vários olhinhos na superfície
	func _draw_self_destruction(pulse: float) -> void:
		var r: float = radius * (1.0 + 0.08 * pulse)
		draw_circle(Vector2.ZERO, r * 1.6, Color(CruelFX.TEAL, 0.10 * _fade))
		draw_circle(Vector2.ZERO, r, Color(CruelFX.BLACK, 0.85 * _fade))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(CruelFX.TEAL, 0.95 * _fade), 3.0)
		draw_arc(Vector2.ZERO, r * 1.35, 0.0, TAU, 32, Color(CruelFX.TEAL, 0.4 * _fade), 2.0)
		# Espinhos em volta
		for i in 6:
			var ang: float = _age * 1.2 + float(i) * TAU / 6.0
			var d: Vector2 = Vector2.from_angle(ang)
			var base: Vector2 = d * r * 0.95
			var tip: Vector2 = d * r * (1.5 + 0.25 * sin(_age * 7.0 + float(i)))
			var side: Vector2 = d.orthogonal() * r * 0.16
			var tri := PackedVector2Array([base - side, tip, base + side])
			draw_colored_polygon(tri, Color(CruelFX.BLACK, 0.92 * _fade))
			draw_polyline(tri, Color(CruelFX.TEAL, 0.95 * _fade), 1.8)
		# Olhinhos na superfície (5, girando)
		for i in 5:
			var ang: float = -_age * 2.0 + float(i) * TAU / 5.0
			var pos: Vector2 = Vector2.from_angle(ang) * r * 0.5
			draw_colored_polygon(CruelFX.lens_points(pos, r * 0.26, r * 0.12, ang, 6),
				Color(CruelFX.TEAL_LIGHT, 0.95 * _fade))
