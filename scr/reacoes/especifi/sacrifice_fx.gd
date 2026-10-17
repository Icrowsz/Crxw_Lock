class_name SacrificeFX
extends RefCounted
## Efeitos visuais da reação química SACRIFICE (Karasu + Hiori). Tudo desenhado por código.
##
## Quem chama:
##  - karasu.gd (Wings Block): draw_grab_wings() dentro do _draw dele (asas longas e roxas de corvo
##    que seguram cada inimigo agarrado) e wings_burst() no instante em que agarra;
##  - hiori.gd (Loud Crow): loud_crow_burst() no instante do chute.
##
## O que cada coisa faz:
##  - draw_grab_wings: duas asas de corvo bem longas saem do Karasu; cada uma vai até um inimigo e
##    termina numa "gaiola" de penas girando em volta dele. Com um inimigo só, a outra asa abre
##    para o lado oposto. As asas crescem num "pop" quando o Wings Block é usado.
##  - wings_burst: penas roxas voando + anel de choque.
##  - loud_crow_burst: o pacote do Loud Crow (estilhaços e anéis de gelo, vidro quebrando na tela,
##    tremida de câmera, micro-pausa, penas no Karasu) + a trilha de gelo e a trilha de VIDRO
##    QUEBRANDO que acompanham a bola durante o trajeto.
##
## Usa as cores e funções de gelo do one_more_time_fx.gd (OneMoreTimeFX).

const VIOLET := Color(0.55, 0.25, 0.90)
const VIOLET_LIGHT := Color(0.80, 0.62, 1.0)
const VIOLET_DARK := Color(0.20, 0.06, 0.36)

## Comprimento mínimo de uma asa (px) e quanto ela passa do inimigo
const WING_MIN_LEN: float = 130.0
const WING_OVERSHOOT: float = 26.0


# ---------- ASAS DO WINGS BLOCK ----------

## Desenha as asas dentro do _draw() de "canvas" (o Karasu). Tudo em coordenadas locais dele.
## targets = posição local de cada inimigo agarrado; grow = 0..1 (entrada); time = segundos.
static func draw_grab_wings(canvas: CanvasItem, center: Vector2, targets: Array[Vector2],
		body_radius: float, grow: float, time: float) -> void:
	if grow <= 0.01 or targets.is_empty():
		return
	var pop: float = 1.0 - pow(1.0 - clampf(grow, 0.0, 1.0), 3.0)

	# Cada asa vai até um inimigo; com um só, a outra abre para o lado oposto (e um pouco para cima)
	var dirs: Array[Vector2] = []
	var reach: Array[float] = []
	for t: Vector2 in targets:
		var off: Vector2 = t - center
		dirs.append(off.normalized() if off.length() > 1.0 else Vector2.RIGHT)
		reach.append(off.length())
	if targets.size() == 1:
		dirs.append(Vector2(-dirs[0].x, -0.35).normalized())
		reach.append(0.0)

	canvas.draw_circle(center, body_radius + 22.0, Color(VIOLET, 0.10 * pop))
	for i in dirs.size():
		var is_target: bool = i < targets.size()
		var length: float = (maxf(reach[i] + WING_OVERSHOOT, WING_MIN_LEN) if is_target \
			else WING_MIN_LEN + 24.0) * pop
		_draw_raven_wing(canvas, center, dirs[i], length, time + float(i) * 0.7, pop)
	for i in targets.size():
		_draw_grip(canvas, targets[i], time + float(i), pop)


## Uma asa de corvo estendida a partir do "ombro": braço levemente curvo para cima e penas longas
## em leque, caindo para o lado de baixo, mais longas perto da ponta.
static func _draw_raven_wing(canvas: CanvasItem, shoulder: Vector2, dir: Vector2, length: float,
		time: float, alpha: float) -> void:
	if length < 8.0:
		return
	var n: Vector2 = dir.orthogonal()
	if n.y > 0.0:
		n = -n   # o braço sempre arqueia para cima
	var flap: float = sin(time * 5.0) * 0.05
	var feather_count: int = 10

	# Penas: da ponta para o ombro, para as de perto do corpo ficarem por cima
	for k in range(feather_count - 1, -1, -1):
		var u: float = float(k) / float(feather_count - 1)   # 0 = ombro, 1 = ponta
		var base: Vector2 = shoulder + dir * length * (0.10 + 0.58 * u) \
			+ n * length * 0.10 * sin(PI * u)
		var a: float = lerpf(1.15, 0.10, u) + flap
		var fdir: Vector2 = (dir * cos(a) - n * sin(a)).normalized()
		var flen: float = length * (0.30 + 0.40 * u)
		if k == feather_count - 1:
			flen *= 1.15   # a pena da ponta é a mais longa
		var w: float = length * 0.05
		var side: Vector2 = fdir.orthogonal()
		var tip: Vector2 = base + fdir * flen
		var mid: Vector2 = base + fdir * flen * 0.55
		var pts := PackedVector2Array([base, mid + side * w, tip, mid - side * w])
		var shade: float = 0.30 + 0.35 * float(k % 2)
		canvas.draw_colored_polygon(pts, Color(VIOLET.lerp(VIOLET_DARK, shade), 0.78 * alpha))
		var outline := PackedVector2Array([base, mid + side * w, tip, mid - side * w, base])
		canvas.draw_polyline(outline, Color(VIOLET_LIGHT, 0.85 * alpha), 1.4)
		canvas.draw_line(base, tip, Color(VIOLET_LIGHT, 0.45 * alpha), 1.0)   # haste da pena

	# Braço da asa (borda da frente)
	var arm := PackedVector2Array()
	for s in 13:
		var t: float = float(s) / 12.0
		arm.append(shoulder + dir * length * (0.10 + 0.62 * t) + n * length * 0.10 * sin(PI * t))
	canvas.draw_polyline(arm, Color(VIOLET_DARK, alpha), 6.0)
	canvas.draw_polyline(arm, Color(VIOLET, alpha), 3.4)
	canvas.draw_polyline(arm, Color(VIOLET_LIGHT, 0.7 * alpha), 1.2)


## "Gaiola" de penas girando em volta do inimigo agarrado
static func _draw_grip(canvas: CanvasItem, pos: Vector2, time: float, alpha: float) -> void:
	var radius: float = 30.0
	canvas.draw_circle(pos, radius + 6.0, Color(VIOLET, 0.16 * alpha))
	for j in 3:
		var a0: float = time * 1.4 + float(j) * TAU / 3.0
		canvas.draw_arc(pos, radius, a0, a0 + 1.7, 10, Color(VIOLET_DARK, alpha), 6.0)
		canvas.draw_arc(pos, radius, a0, a0 + 1.7, 10, Color(VIOLET_LIGHT, 0.9 * alpha), 2.6)
	for j in 6:
		var a: float = -time * 0.9 + float(j) * TAU / 6.0
		var p: Vector2 = pos + Vector2.from_angle(a) * (radius + 2.0)
		var inward: Vector2 = (pos - p).rotated(0.55).normalized()
		var perp: Vector2 = inward.orthogonal()
		var pts := PackedVector2Array([p, p + inward * 12.0 + perp * 4.5, p + inward * 24.0,
			p + inward * 12.0 - perp * 4.5])
		canvas.draw_colored_polygon(pts, Color(VIOLET, 0.8 * alpha))
		canvas.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
			Color(VIOLET_LIGHT, 0.9 * alpha), 1.2)


## Penas roxas voando + anel de choque (no instante em que o Wings Block agarra)
static func wings_burst(from: Node, world_pos: Vector2) -> void:
	var parent: Node = _world_parent(from)
	if parent == null:
		return
	var feathers := CPUParticles2D.new()
	feathers.emitting = false
	feathers.one_shot = true
	feathers.explosiveness = 1.0
	feathers.amount = 34
	feathers.lifetime = 1.0
	feathers.direction = Vector2.UP
	feathers.spread = 180.0
	feathers.initial_velocity_min = 90.0
	feathers.initial_velocity_max = 320.0
	feathers.gravity = Vector2(0.0, 160.0)
	feathers.damping_min = 40.0
	feathers.damping_max = 110.0
	feathers.angular_velocity_min = -420.0
	feathers.angular_velocity_max = 420.0
	feathers.scale_amount_min = 3.0
	feathers.scale_amount_max = 7.0
	var ramp := Gradient.new()
	ramp.set_color(0, VIOLET_LIGHT)
	ramp.set_color(1, Color(VIOLET_DARK, 0.0))
	ramp.add_point(0.5, VIOLET)
	feathers.color_ramp = ramp
	feathers.z_index = OneMoreTimeFX.FX_Z
	feathers.z_as_relative = false
	parent.add_child(feathers)
	feathers.global_position = world_pos
	feathers.emitting = true
	from.get_tree().create_timer(feathers.lifetime + 0.6).timeout.connect(feathers.queue_free)

	var ring := PulseRing.new()
	ring.r0 = 14.0
	ring.r1 = 150.0
	ring.dur = 0.55
	parent.add_child(ring)
	ring.global_position = world_pos


# ---------- LOUD CROW (chute) ----------

## O pacote do Loud Crow, chamado no instante em que a bola sai do pé do Hiori.
##  shooter = o Hiori | origin = posição global dele (com a altura) | karasu = o Karasu (ganha penas)
static func loud_crow_burst(shooter: Node2D, origin: Vector2, ball: Ball, karasu: Node2D) -> void:
	if shooter == null or not shooter.is_inside_tree() or ball == null:
		return
	var parent: Node = _world_parent(shooter)
	if parent == null:
		return
	var ball_pos: Vector2 = ball.sprite.global_position if ball.sprite != null else ball.global_position

	# Gelo: brilho na bola + geada no chão por onde ela passa, estilhaços e anéis
	OneMoreTimeFX.attach_frost_trail(ball, OneMoreTimeFX.Style.GO_BEYOND)
	OneMoreTimeFX.ice_burst(shooter, ball_pos, 70)
	OneMoreTimeFX.ice_burst(shooter, origin, 26)

	# Vidro: quebrando na tela no chute e depois acompanhando a bola
	var viewport: Viewport = shooter.get_viewport()
	var view_size: Vector2 = viewport.get_visible_rect().size
	var screen_pos: Vector2 = viewport.get_canvas_transform() * ball_pos
	screen_pos = screen_pos.clamp(Vector2(80.0, 80.0), view_size - Vector2(80.0, 80.0))
	var glass := OneMoreTimeFX.GlassBreak.new()
	glass.setup(screen_pos, view_size)
	shooter.get_tree().root.add_child(glass)
	attach_glass_trail(ball)

	if karasu != null and is_instance_valid(karasu):
		wings_burst(karasu, karasu.global_position + Vector2(0.0, -_height_of(karasu)))

	OneMoreTimeFX.shake_camera(shooter, 20.0, 0.6)
	OneMoreTimeFX.hit_stop(shooter, 0.07, 0.07)


## Trilha de vidro quebrando que acompanha a bola (acaba sozinha quando alguém toca nela, ela para
## ou a bola é reposta)
static func attach_glass_trail(ball: Ball) -> void:
	if ball == null or not ball.is_inside_tree() or ball.get_parent() == null:
		return
	var trail := GlassTrail.new()
	trail.setup(ball)
	ball.get_parent().add_child(trail)
	trail.top_level = true
	trail.global_position = Vector2.ZERO   # tudo é desenhado em coordenadas globais


static func _height_of(n: Node2D) -> float:
	var h: Variant = n.get("height")
	return float(h) if h != null else 0.0


static func _world_parent(from: Node) -> Node:
	if from == null or not from.is_inside_tree():
		return null
	var p: Node = from.get_parent()
	return p if p != null else from.get_tree().current_scene


# ---------- ANEL DE CHOQUE ----------

class PulseRing extends Node2D:
	var r0: float = 10.0
	var r1: float = 120.0
	var dur: float = 0.5
	var age: float = 0.0


	func _init() -> void:
		z_index = OneMoreTimeFX.FX_Z
		z_as_relative = false
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat


	func _process(delta: float) -> void:
		age += delta
		if age >= dur:
			queue_free()
			return
		queue_redraw()


	func _draw() -> void:
		var k: float = age / dur
		var r: float = lerpf(r0, r1, 1.0 - pow(1.0 - k, 3.0))
		var a: float = 1.0 - k
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(SacrificeFX.VIOLET_LIGHT, a), 4.0 * a + 1.0)
		draw_arc(Vector2.ZERO, r * 0.8, 0.0, TAU, 36, Color(SacrificeFX.VIOLET, a * 0.6), 2.5)


# ---------- TRILHA DE VIDRO QUEBRANDO ----------

class GlassTrail extends Node2D:
	const MAX_SHARDS: int = 140
	const MAX_CRACKS: int = 26
	const PANE_EVERY: float = 0.08     # a cada quanto tempo "um vidro" quebra na bola
	const CRACK_STEP: float = 46.0     # a cada quantos px a bola anda, racha o chão
	const CRACK_HOLD: float = 2.2
	const CRACK_FADE: float = 0.8

	var ball: Ball
	var touches: int = 0
	var time: float = 0.0
	var finished: bool = false
	var pane_timer: float = 0.0
	var last_ground: Vector2 = Vector2.ZERO
	var shards: Array[Dictionary] = []
	var panes: Array[Dictionary] = []
	var cracks: Array[Dictionary] = []
	var ground_layer: GroundLayer


	func setup(b: Ball) -> void:
		ball = b
		touches = b.interaction_count
		last_ground = b.global_position
		z_index = OneMoreTimeFX.FX_Z
		z_as_relative = false
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
		b.was_reset.connect(_finish)   # bola reposta (ex: depois de um gol): acabou


	func _ready() -> void:
		ground_layer = GroundLayer.new()
		ground_layer.trail = self
		add_child(ground_layer)


	func _finish() -> void:
		finished = true


	func _process(delta: float) -> void:
		time += delta
		if not finished:
			if not is_instance_valid(ball) or ball.interaction_count != touches or time > 7.0:
				_finish()
			elif time > 0.4 and not ball.hovering and ball.is_on_ground() \
					and ball.velocity.length() < 20.0:
				_finish()   # a bola parou
			else:
				_track(delta)

		_age_list(shards, delta)
		_age_list(panes, delta)
		_age_list(cracks, delta)
		for s: Dictionary in shards:
			var vel: Vector2 = s["vel"]
			vel *= maxf(0.0, 1.0 - 2.2 * delta)
			vel.y += 260.0 * delta
			s["vel"] = vel
			s["pos"] = Vector2(s["pos"]) + vel * delta
			s["rot"] = float(s["rot"]) + float(s["spin"]) * delta

		if finished and shards.is_empty() and panes.is_empty() and cracks.is_empty():
			queue_free()
			return
		queue_redraw()
		if ground_layer != null:
			ground_layer.queue_redraw()


	## Envelhece os itens da lista e remove os que acabaram ("life" é o tempo de vida de cada um)
	func _age_list(list: Array[Dictionary], delta: float) -> void:
		var i: int = list.size() - 1
		while i >= 0:
			var item: Dictionary = list[i]
			item["age"] = float(item["age"]) + delta
			if float(item["age"]) >= float(item["life"]):
				list.remove_at(i)
			i -= 1


	func _track(delta: float) -> void:
		var spos: Vector2 = ball.sprite.global_position if ball.sprite != null else ball.global_position
		var gpos: Vector2 = ball.global_position
		pane_timer -= delta
		if pane_timer <= 0.0:
			pane_timer = PANE_EVERY
			_add_pane(spos)
			_add_shards(spos, 4)
		if gpos.distance_to(last_ground) >= CRACK_STEP:
			last_ground = gpos
			_add_crack(gpos)


	## "Um vidro" quebrando na bola: rachaduras em estrela que somem rápido
	func _add_pane(pos: Vector2) -> void:
		var rays: Array[Vector2] = []
		var count: int = 9
		var base: float = randf() * TAU
		for i in count:
			var ang: float = base + (float(i) + randf_range(-0.3, 0.3)) * TAU / float(count)
			rays.append(Vector2.from_angle(ang) * randf_range(20.0, 44.0))
		panes.append({"pos": pos, "age": 0.0, "life": 0.32, "rays": rays})


	func _add_shards(pos: Vector2, count: int) -> void:
		for i in count:
			if shards.size() >= MAX_SHARDS:
				shards.remove_at(0)
			var dir: Vector2 = Vector2.from_angle(randf() * TAU)
			shards.append({
				"pos": pos, "vel": dir * randf_range(70.0, 280.0), "rot": randf() * TAU,
				"spin": randf_range(-9.0, 9.0), "size": randf_range(5.0, 11.0),
				"tri": PackedVector2Array([Vector2(1.0, 0.0), Vector2(-0.7, 0.35 + randf() * 0.3),
					Vector2(-0.4, -0.55 - randf() * 0.3)]),
				"age": 0.0, "life": randf_range(0.5, 0.9), "violet": randf() < 0.25,
			})


	## Rachadura no chão (em estrela, com um "joelho" em cada raio)
	func _add_crack(pos: Vector2) -> void:
		while cracks.size() >= MAX_CRACKS:
			cracks.remove_at(0)
		var rays: Array[PackedVector2Array] = []
		var count: int = 7
		var base: float = randf() * TAU
		for i in count:
			var ang: float = base + (float(i) + randf_range(-0.25, 0.25)) * TAU / float(count)
			var length: float = randf_range(26.0, 54.0)
			var d: Vector2 = Vector2.from_angle(ang)
			var mid: Vector2 = d * length * 0.55 + d.orthogonal() * randf_range(-6.0, 6.0)
			rays.append(PackedVector2Array([Vector2.ZERO, mid, d * length]))
		cracks.append({"pos": pos + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)),
			"age": 0.0, "life": CRACK_HOLD + CRACK_FADE, "rays": rays})


	func _draw() -> void:
		var light: Color = OneMoreTimeFX.ICE_LIGHT
		var mid: Color = OneMoreTimeFX.ICE_MID

		# Vidros quebrando na bola
		for p: Dictionary in panes:
			var k: float = float(p["age"]) / float(p["life"])
			var a: float = 1.0 - k
			var grow: float = 1.0 - pow(1.0 - minf(k * 2.5, 1.0), 3.0)
			var c: Vector2 = p["pos"]
			var rays: Array = p["rays"]
			for i in rays.size():
				var tip: Vector2 = c + (rays[i] as Vector2) * grow
				draw_line(c, tip, Color(mid, 0.25 * a), 4.0)
				draw_line(c, tip, Color(light, 0.9 * a), 1.5)
				# "teia" ligando uma rachadura à vizinha
				var nxt: Vector2 = c + (rays[(i + 1) % rays.size()] as Vector2) * grow
				draw_line(c.lerp(tip, 0.55), c.lerp(nxt, 0.55), Color(light, 0.55 * a), 1.2)
			draw_arc(c, 10.0 + 20.0 * grow, 0.0, TAU, 20, Color(light, 0.5 * a), 1.5)

		# Cacos de vidro voando
		for s: Dictionary in shards:
			var k: float = float(s["age"]) / float(s["life"])
			var a: float = 1.0 - k * k
			var size: float = float(s["size"]) * (1.0 - 0.3 * k)
			var col: Color = SacrificeFX.VIOLET_LIGHT if bool(s["violet"]) else light
			draw_set_transform(s["pos"], float(s["rot"]), Vector2(size, size))
			var tri: PackedVector2Array = s["tri"]
			draw_colored_polygon(tri, Color(col, 0.45 * a))
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]),
				Color(light, a), 1.8 / size)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Camada das rachaduras do chão: acima do gramado e abaixo dos jogadores (mesma regra da geada)
class GroundLayer extends Node2D:
	var trail: GlassTrail


	func _init() -> void:
		z_index = OneMoreTimeFX.GROUND_Z
		z_as_relative = false


	func _draw() -> void:
		if trail == null:
			return
		var light: Color = OneMoreTimeFX.ICE_LIGHT
		var mid: Color = OneMoreTimeFX.ICE_MID
		for c: Dictionary in trail.cracks:
			var age: float = c["age"]
			var alpha: float = 1.0
			if age > GlassTrail.CRACK_HOLD:
				alpha = clampf(1.0 - (age - GlassTrail.CRACK_HOLD) / GlassTrail.CRACK_FADE, 0.0, 1.0)
			var grow: float = 1.0 - pow(1.0 - clampf(age / 0.18, 0.0, 1.0), 3.0)
			draw_set_transform(to_local(c["pos"]), 0.0, Vector2(grow, grow * 0.6))   # achatado: visto de cima
			for ray: PackedVector2Array in c["rays"]:
				draw_polyline(ray, Color(mid, 0.22 * alpha), 4.0)
				draw_polyline(ray, Color(light, 0.85 * alpha), 1.6)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
