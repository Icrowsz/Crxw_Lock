class_name OneMoreTimeFX
extends RefCounted
## Efeitos visuais da reação química ONE MORE TIME (Isagi + Hiori). Tudo é criado por código,
## sem imagem nenhuma (só formas desenhadas), e usa apenas a API que já existe na Ball.
##
## Quem chama:
##  - hiori.gd (Ultrasadist "carregado"):  attach_frost_trail(ball, Style.ULTRASADIST) e ice_burst()
##  - isagi.gd (Go Beyond, no momento do chute): go_beyond_burst()
##
## O que cada coisa faz:
##  - attach_frost_trail: um brilho azul-gelo na bola + "geada" no chão por onde ela passa
##    (flocos de gelo e névoa fria no Ultrasadist; peças de quebra-cabeça de gelo no Go Beyond).
##    Some sozinho quando alguém toca na bola, ela para ou a bola é reposta.
##  - ice_burst: explosão de estilhaços de gelo + anel de espinhos de gelo no chão.
##  - go_beyond_burst: o pacote completo do Go Beyond (estilhaços, anéis, peças de quebra-cabeça
##    azuis voando, clarão azul, VIDRO QUEBRANDO na tela, câmera tremendo e uma micro-pausa).
##
## Ajustes rápidos: as cores (ICE_*) e as duas constantes de camada (FX_Z e GROUND_Z) logo abaixo.

enum Style { ULTRASADIST, GO_BEYOND }

const ICE_LIGHT := Color(0.85, 0.97, 1.0)    # branco gelado
const ICE_MID := Color(0.45, 0.80, 1.0)      # azul gelo
const ICE_DEEP := Color(0.10, 0.42, 0.95)    # azul profundo (Blue Lock)

## Camada dos efeitos "no ar": na frente de tudo (os jogadores usam z_index = posição y)
const FX_Z: int = 4000
## Camada da geada no chão: acima do gramado e abaixo dos jogadores. Se a geada sumir atrás do
## campo, aumente; se aparecer por cima dos jogadores, diminua (mínimo: o z_index do campo + 1).
const GROUND_Z: int = 1

## Vidro quebrando na tela. GLASS_SIZE = tamanho das rachaduras (fração da diagonal da tela;
## 0.55 era o valor antigo, bem grande). GLASS_FLASH = força do clarão azul (0 = sem clarão).
const GLASS_SIZE: float = 0.2
const GLASS_FLASH: float = 0.06


# ---------- FUNÇÕES PÚBLICAS ----------

## Brilho na bola + geada no chão por onde ela passa
static func attach_frost_trail(ball: Ball, style: Style) -> void:
	if ball == null or not ball.is_inside_tree() or ball.get_parent() == null:
		return
	var trail := FrostTrail.new()
	trail.setup(ball, style)
	ball.get_parent().add_child(trail)


## Explosão de estilhaços de gelo + anel de espinhos no chão. "from" = qualquer nó do campo
## (ex: o próprio jogador); "world_pos" = posição global.
static func ice_burst(from: Node, world_pos: Vector2, amount: int = 30) -> void:
	var parent: Node = _world_parent(from)
	if parent == null:
		return

	var shards := CPUParticles2D.new()
	shards.emitting = false
	shards.one_shot = true
	shards.explosiveness = 1.0
	shards.amount = maxi(amount, 1)
	shards.lifetime = 0.9
	shards.direction = Vector2.UP
	shards.spread = 180.0
	shards.initial_velocity_min = 140.0
	shards.initial_velocity_max = 420.0
	shards.gravity = Vector2(0.0, 520.0)
	shards.damping_min = 30.0
	shards.damping_max = 90.0
	shards.angular_velocity_min = -540.0
	shards.angular_velocity_max = 540.0
	shards.scale_amount_min = 3.0
	shards.scale_amount_max = 8.0
	var ramp := Gradient.new()
	ramp.set_color(0, ICE_LIGHT)
	ramp.set_color(1, Color(ICE_DEEP, 0.0))
	ramp.add_point(0.5, ICE_MID)
	shards.color_ramp = ramp
	shards.z_index = FX_Z
	shards.z_as_relative = false
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	shards.material = mat
	parent.add_child(shards)
	shards.global_position = world_pos
	shards.emitting = true
	from.get_tree().create_timer(shards.lifetime + 0.6).timeout.connect(shards.queue_free)

	_spawn_ring(parent, world_pos, 12.0, 90.0 + float(amount) * 2.5, 0.65, 0.0)


## O pacote do Go Beyond, chamado no instante em que a bola sai do pé do Isagi.
##  origin   = posição global do Isagi (com a altura)
##  ball_pos = posição global da bola na tela (ball.sprite.global_position)
static func go_beyond_burst(shooter: Node2D, origin: Vector2, ball_pos: Vector2, ball: Ball) -> void:
	if shooter == null or not shooter.is_inside_tree():
		return
	var parent: Node = _world_parent(shooter)
	if parent == null:
		return

	# Brilho na bola + peças de gelo congelando o chão por onde ela passa
	if ball != null:
		attach_frost_trail(ball, Style.GO_BEYOND)

	# Estilhaços e anéis de gelo (no chute e no pé do Isagi)
	ice_burst(shooter, ball_pos, 80)
	ice_burst(shooter, origin, 30)
	_spawn_ring(parent, origin, 70.0, 380.0, 0.8, 0.05)
	_spawn_ring(parent, ball_pos, 40.0, 300.0, 0.6, 0.15)

	# Os quebra-cabeças do Isagi, agora de gelo, explodindo para todos os lados
	_spawn_puzzle_burst(parent, ball_pos, 26, 640.0, 22.0, 46.0)
	_spawn_puzzle_burst(parent, origin, 12, 380.0, 14.0, 28.0)

	# Tela: clarão azul + vidro quebrando
	var viewport: Viewport = shooter.get_viewport()
	var view_size: Vector2 = viewport.get_visible_rect().size
	var screen_pos: Vector2 = viewport.get_canvas_transform() * ball_pos
	screen_pos = screen_pos.clamp(Vector2(80.0, 80.0), view_size - Vector2(80.0, 80.0))
	var glass := GlassBreak.new()
	glass.setup(screen_pos, view_size)
	shooter.get_tree().root.add_child(glass)

	shake_camera(shooter, 26.0, 0.7)
	hit_stop(shooter, 0.09, 0.06)


## Câmera tremendo (mexe no "offset" da Camera2D; sem câmera, não faz nada)
static func shake_camera(from: Node, strength: float = 22.0, duration: float = 0.6) -> void:
	var cam: Camera2D = from.get_viewport().get_camera_2d()
	if cam == null:
		return
	# Se já está tremendo, guarda o offset ORIGINAL (não o tremido)
	var base: Vector2 = cam.offset
	if cam.has_meta(&"omt_base_offset"):
		base = cam.get_meta(&"omt_base_offset")
	else:
		cam.set_meta(&"omt_base_offset", base)
	var tween: Tween = cam.create_tween()
	var steps: int = maxi(int(duration / 0.03), 1)
	for i in steps:
		var k: float = 1.0 - float(i) / float(steps)
		var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		tween.tween_property(cam, "offset", base + jitter * strength * k, 0.03)
	tween.tween_property(cam, "offset", base, 0.05)
	tween.finished.connect(func() -> void:
		if is_instance_valid(cam) and cam.has_meta(&"omt_base_offset"):
			cam.remove_meta(&"omt_base_offset"))


## Micro-pausa de impacto: o jogo quase para por uma fração de segundo e volta ao normal sozinho
static func hit_stop(from: Node, real_seconds: float = 0.08, slow_scale: float = 0.08) -> void:
	if Engine.time_scale != 1.0:
		return
	Engine.time_scale = slow_scale
	# 4º parâmetro = true: o timer ignora o time_scale (conta em tempo real)
	from.get_tree().create_timer(real_seconds, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0)


## Contorno de peça de quebra-cabeça (quadrado com um "dente" em cima), tamanho 1 (vai de -1 a 1)
static func piece_polygon() -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(-1.0, 1.0))
	pts.append(Vector2(-1.0, -1.0))
	# o dente: um arco que sai pela borda de cima
	var x0: float = 0.18
	var d: float = 0.12
	var radius: float = sqrt(x0 * x0 + d * d)
	var alpha: float = atan2(d, x0)
	var sweep: float = PI + 2.0 * alpha
	var knob_center := Vector2(0.0, -1.0 - d)
	for i in 13:
		var ang: float = PI - alpha + sweep * float(i) / 12.0
		pts.append(knob_center + Vector2(cos(ang), sin(ang)) * radius)
	pts.append(Vector2(1.0, -1.0))
	pts.append(Vector2(1.0, 1.0))
	return pts


## O mesmo contorno fechado (último ponto = primeiro), para draw_polyline
static func closed_outline(poly: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = poly.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out


# ---------- APOIO ----------

static func _world_parent(from: Node) -> Node:
	if from == null or not from.is_inside_tree():
		return null
	var p: Node = from.get_parent()
	return p if p != null else from.get_tree().current_scene


static func _spawn_ring(parent: Node, pos: Vector2, r0: float, r1: float, dur: float,
		delay: float) -> void:
	var ring := IceRing.new()
	ring.r0 = r0
	ring.r1 = r1
	ring.dur = dur
	ring.delay = delay
	parent.add_child(ring)
	ring.global_position = pos


static func _spawn_puzzle_burst(parent: Node, pos: Vector2, count: int, speed: float,
		size_min: float, size_max: float) -> void:
	var burst := PuzzleBurst.new()
	burst.setup(count, speed, size_min, size_max)
	parent.add_child(burst)
	burst.global_position = pos


# ---------- GEADA NO CHÃO + BRILHO NA BOLA ----------

class FrostTrail extends Node2D:
	const MAX_PATCHES: int = 90

	var ball: Ball
	var style: OneMoreTimeFX.Style = OneMoreTimeFX.Style.ULTRASADIST
	var patches: Array[Dictionary] = []
	var piece: PackedVector2Array = OneMoreTimeFX.piece_polygon()
	var outline: PackedVector2Array = OneMoreTimeFX.closed_outline(piece)
	var halo: Halo = null
	var touches: int = 0
	var last_pos: Vector2 = Vector2.ZERO
	var time: float = 0.0
	var finished: bool = false
	var step: float = 26.0     # a cada quantos px a bola anda, nasce uma marca de gelo
	var hold: float = 3.5      # segundos que a geada fica inteira
	var fade: float = 2.0      # segundos que ela leva para sumir


	func setup(b: Ball, s: OneMoreTimeFX.Style) -> void:
		ball = b
		style = s
		touches = b.interaction_count
		last_pos = b.global_position
		z_index = OneMoreTimeFX.GROUND_Z
		z_as_relative = false
		if style == OneMoreTimeFX.Style.GO_BEYOND:
			step = 20.0
			hold = 2.5
			fade = 1.5
		b.was_reset.connect(_finish)   # bola reposta (ex: depois de um gol): acabou


	func _ready() -> void:
		halo = Halo.new()
		halo.ball = ball
		halo.style = style
		add_child(halo)
		_add_patch(last_pos)   # a primeira marca já nasce no ponto de partida


	## Para de gerar gelo novo (o que já existe some sozinho)
	func _finish() -> void:
		if finished:
			return
		finished = true
		if halo != null and is_instance_valid(halo):
			halo.dying = true


	func _process(delta: float) -> void:
		time += delta
		if not finished:
			if not is_instance_valid(ball):
				_finish()
			elif ball.interaction_count != touches:
				_finish()   # alguém tocou na bola
			elif time > 0.4 and not ball.hovering and ball.is_on_ground() \
					and ball.velocity.length() < 20.0:
				_finish()   # a bola parou
			else:
				_track()

		var i: int = patches.size() - 1
		while i >= 0:
			var p: Dictionary = patches[i]
			p["age"] = float(p["age"]) + delta
			if float(p["age"]) > hold + fade:
				patches.remove_at(i)
			i -= 1

		if finished and patches.is_empty() and (halo == null or not is_instance_valid(halo)):
			queue_free()
			return
		queue_redraw()


	func _track() -> void:
		var pos: Vector2 = ball.global_position
		var dist: float = pos.distance_to(last_pos)
		if dist < step:
			return
		var n: int = mini(int(dist / step), 14)
		for i in n:
			last_pos = last_pos.move_toward(pos, step)
			_add_patch(last_pos)
		if dist > step * 14.0:
			last_pos = pos   # a bola "teleportou": não enche o campo de gelo


	func _add_patch(at: Vector2) -> void:
		var big: bool = style == OneMoreTimeFX.Style.GO_BEYOND
		patches.append({
			"pos": at + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)),
			"r": randf_range(20.0, 34.0) if big else randf_range(14.0, 24.0),
			"rot": randf() * TAU,
			"age": 0.0,
			"piece": big and randf() < 0.5,
		})
		while patches.size() > MAX_PATCHES:
			patches.remove_at(0)


	func _draw() -> void:
		var light: Color = OneMoreTimeFX.ICE_LIGHT
		var mid: Color = OneMoreTimeFX.ICE_MID
		for p: Dictionary in patches:
			var age: float = p["age"]
			var alpha: float = 1.0
			if age > hold:
				alpha = clampf(1.0 - (age - hold) / fade, 0.0, 1.0)
			var grow: float = clampf(age / 0.25, 0.0, 1.0)
			grow = 1.0 - pow(1.0 - grow, 3.0)   # nasce rápido e desacelera
			var c: Vector2 = to_local(p["pos"])
			var r: float = float(p["r"]) * grow
			var rot: float = p["rot"]
			if r < 1.0:
				continue

			if bool(p["piece"]):
				# Go Beyond: peça de quebra-cabeça de gelo grudada no chão
				draw_set_transform(c, rot, Vector2(r, r))
				draw_colored_polygon(piece, Color(mid, 0.30 * alpha))
				draw_polyline(outline, Color(light, 0.9 * alpha), 2.0 / r)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				# Flocos de gelo: disco brilhante + 6 hastes com ramificações
				draw_circle(c, r, Color(mid, 0.16 * alpha))
				draw_arc(c, r, 0.0, TAU, 20, Color(light, 0.45 * alpha), 1.5)
				for k in 6:
					var d: Vector2 = Vector2.from_angle(rot + float(k) * TAU / 6.0)
					var tip: Vector2 = c + d * r
					draw_line(c + d * r * 0.15, tip, Color(light, 0.85 * alpha), 2.0)
					var branch: Vector2 = c + d * r * 0.6
					draw_line(branch, branch + d.rotated(0.7) * r * 0.3, Color(light, 0.7 * alpha), 1.5)
					draw_line(branch, branch + d.rotated(-0.7) * r * 0.3, Color(light, 0.7 * alpha), 1.5)

			# Névoa fria subindo (só no Ultrasadist)
			if style == OneMoreTimeFX.Style.ULTRASADIST:
				var mist_age: float = minf(age, 4.0)
				var mist_pos: Vector2 = c + Vector2(sin(rot + age * 1.3) * 6.0, -mist_age * 16.0)
				draw_circle(mist_pos, r * (0.7 + mist_age * 0.12), Color(light, 0.07 * alpha))


## Brilho azul-gelo que acompanha a bola (aparece por cima de tudo)
class Halo extends Node2D:
	var ball: Ball
	var style: OneMoreTimeFX.Style = OneMoreTimeFX.Style.ULTRASADIST
	var dying: bool = false
	var fade: float = 1.0
	var t: float = 0.0
	var piece: PackedVector2Array = OneMoreTimeFX.piece_polygon()
	var outline: PackedVector2Array = OneMoreTimeFX.closed_outline(piece)


	func _init() -> void:
		z_index = OneMoreTimeFX.FX_Z
		z_as_relative = false
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat


	func _process(delta: float) -> void:
		t += delta
		if not is_instance_valid(ball):
			dying = true
		if dying:
			fade -= delta * 3.0
			if fade <= 0.0:
				queue_free()
				return
		queue_redraw()


	func _draw() -> void:
		if not is_instance_valid(ball):
			return
		var light: Color = OneMoreTimeFX.ICE_LIGHT
		var mid: Color = OneMoreTimeFX.ICE_MID
		var big: bool = style == OneMoreTimeFX.Style.GO_BEYOND
		var c: Vector2 = to_local(ball.sprite.global_position)
		var pulse: float = 0.5 + 0.5 * sin(t * 9.0)
		var r: float = (30.0 if big else 22.0) * (1.0 + 0.18 * pulse)

		# Brilho em camadas (soma de luz)
		for i in 5:
			draw_circle(c, r * (1.0 + float(i) * 0.5), Color(mid, (0.12 - float(i) * 0.02) * fade))
		draw_circle(c, r * 0.75, Color(light, 0.30 * fade))

		# Raios de gelo girando
		for k in 6:
			var a: float = t * 2.2 + float(k) * TAU / 6.0
			var d: Vector2 = Vector2.from_angle(a)
			draw_line(c + d * r * 0.5, c + d * r * (1.7 + 0.5 * pulse), Color(light, 0.85 * fade), 2.0)

		# Go Beyond: peças de quebra-cabeça orbitando a bola
		if big:
			for k in 4:
				var a2: float = -t * 3.0 + float(k) * TAU / 4.0
				var pos: Vector2 = c + Vector2.from_angle(a2) * r * 2.2
				draw_set_transform(pos, a2 * 2.0, Vector2(9.0, 9.0))
				draw_colored_polygon(piece, Color(light, 0.55 * fade))
				draw_polyline(outline, Color(light, fade), 2.0 / 9.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------- ANEL DE ESPINHOS DE GELO ----------

class IceRing extends Node2D:
	var r0: float = 10.0
	var r1: float = 260.0
	var dur: float = 0.7
	var delay: float = 0.0
	var squash: float = 0.55    # achata o círculo (visão de cima inclinada)
	var spikes: int = 18
	var age: float = 0.0


	func _init() -> void:
		z_index = OneMoreTimeFX.FX_Z
		z_as_relative = false
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat


	func _process(delta: float) -> void:
		age += delta
		if age - delay >= dur:
			queue_free()
			return
		queue_redraw()


	func _draw() -> void:
		var t: float = age - delay
		if t < 0.0:
			return
		var k: float = t / dur
		var e: float = 1.0 - pow(1.0 - k, 3.0)
		var r: float = lerpf(r0, r1, e)
		var a: float = 1.0 - k
		var light: Color = OneMoreTimeFX.ICE_LIGHT
		var mid: Color = OneMoreTimeFX.ICE_MID

		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(light, a), 5.0 * a + 1.0)
		draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 48, Color(mid, a * 0.6), 3.0)
		for i in spikes:
			var d: Vector2 = Vector2.from_angle(float(i) * TAU / float(spikes))
			var base: Vector2 = d * r
			var tip: Vector2 = d * (r + 26.0 * a + 6.0)
			var side: Vector2 = d.orthogonal() * 5.0
			draw_colored_polygon(PackedVector2Array([base + side, tip, base - side]), Color(light, a * 0.9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------- PEÇAS DE QUEBRA-CABEÇA DE GELO VOANDO ----------

class PuzzleBurst extends Node2D:
	var pieces: Array[Dictionary] = []
	var unit: PackedVector2Array = OneMoreTimeFX.piece_polygon()
	var outline: PackedVector2Array = OneMoreTimeFX.closed_outline(unit)
	var life: float = 1.5
	var t: float = 0.0


	func _init() -> void:
		z_index = OneMoreTimeFX.FX_Z
		z_as_relative = false
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat


	func setup(count: int, speed: float, size_min: float, size_max: float) -> void:
		for i in count:
			var dir: Vector2 = Vector2.from_angle(randf() * TAU)
			pieces.append({
				"pos": Vector2.ZERO,
				"vel": Vector2(dir.x, dir.y * 0.7) * randf_range(speed * 0.35, speed),
				"rot": randf() * TAU,
				"spin": randf_range(-8.0, 8.0),
				"size": randf_range(size_min, size_max),
				"tint": randf(),
			})


	func _process(delta: float) -> void:
		t += delta
		if t >= life:
			queue_free()
			return
		for p: Dictionary in pieces:
			var vel: Vector2 = p["vel"]
			vel *= maxf(0.0, 1.0 - 2.4 * delta)   # o ar vai freando as peças
			vel.y += 140.0 * delta
			p["vel"] = vel
			p["pos"] = Vector2(p["pos"]) + vel * delta
			p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
		queue_redraw()


	func _draw() -> void:
		var k: float = t / life
		var a: float = 1.0 - k * k
		for p: Dictionary in pieces:
			var s: float = float(p["size"]) * (1.0 - 0.4 * k)
			var col: Color = OneMoreTimeFX.ICE_LIGHT.lerp(OneMoreTimeFX.ICE_DEEP, float(p["tint"]))
			draw_set_transform(p["pos"], p["rot"], Vector2(s, s))
			draw_colored_polygon(unit, Color(col, 0.5 * a))
			draw_polyline(outline, Color(OneMoreTimeFX.ICE_LIGHT, a), 2.2 / s)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------- VIDRO QUEBRANDO NA TELA ----------

## Fica num CanvasLayer (por cima de toda a interface) e some sozinho
class GlassBreak extends CanvasLayer:
	func setup(screen_pos: Vector2, view_size: Vector2) -> void:
		layer = 110
		var canvas := GlassCanvas.new()
		canvas.setup(screen_pos, view_size)
		add_child(canvas)


## Fase 1: as rachaduras crescem a partir do impacto. Fase 2: o vidro se parte em cacos que
## caem, giram e somem.
class GlassCanvas extends Node2D:
	const CRACK_TIME: float = 0.16
	const HOLD_TIME: float = 0.12
	const FALL_TIME: float = 0.7

	var center: Vector2 = Vector2.ZERO
	var view_size: Vector2 = Vector2(1920.0, 1080.0)
	var rays: Array = []      # cada item: PackedVector2Array (centro -> ponta da rachadura)
	var shards: Array = []    # cada item: Dictionary com os triângulos do caco
	var t: float = 0.0
	var total: float = 0.0


	func _init() -> void:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat


	func setup(c: Vector2, view: Vector2) -> void:
		center = c
		view_size = view
		total = CRACK_TIME + HOLD_TIME + FALL_TIME + 0.4

		var ray_count: int = 14
		var ring_count: int = 4
		var max_len: float = view.length() * OneMoreTimeFX.GLASS_SIZE

		# Rachaduras: linhas quebradas saindo do ponto de impacto
		for i in ray_count:
			var ang: float = (float(i) + randf_range(-0.3, 0.3)) * TAU / float(ray_count)
			var length: float = max_len * randf_range(0.85, 1.0)
			var pts := PackedVector2Array()
			pts.append(c)
			for k in range(1, ring_count + 1):
				var rr: float = length * pow(float(k) / float(ring_count), 1.5)
				var wobble: float = ang + randf_range(-0.035, 0.035)
				pts.append(c + Vector2.from_angle(wobble) * rr)
			rays.append(pts)

		# Cacos: o espaço entre duas rachaduras vizinhas e dois "anéis" vira um caco
		for i in ray_count:
			var ra: PackedVector2Array = rays[i]
			var rb: PackedVector2Array = rays[(i + 1) % ray_count]
			for k in range(0, ring_count):
				var tris: Array = []
				var mid_pt: Vector2 = Vector2.ZERO
				if k == 0:
					_add_tri(tris, ra[0], ra[1], rb[1])
					mid_pt = (ra[0] + ra[1] + rb[1]) / 3.0
				else:
					_add_tri(tris, ra[k], ra[k + 1], rb[k + 1])
					_add_tri(tris, ra[k], rb[k + 1], rb[k])
					mid_pt = (ra[k] + ra[k + 1] + rb[k + 1] + rb[k]) * 0.25
				if tris.is_empty():
					continue
				# os triângulos ficam relativos ao centro do caco (para girar em torno dele)
				var rel: Array = []
				for tri: PackedVector2Array in tris:
					rel.append(PackedVector2Array([tri[0] - mid_pt, tri[1] - mid_pt, tri[2] - mid_pt]))
				var away: Vector2 = (mid_pt - c).normalized()
				shards.append({
					"tris": rel,
					"mid": mid_pt,
					"vel": away * randf_range(40.0, 170.0),
					"spin": randf_range(-3.5, 3.5),
					"delay": randf_range(0.0, 0.14) + float(k) * 0.03,
				})


	func _add_tri(list: Array, p0: Vector2, p1: Vector2, p2: Vector2) -> void:
		# triângulo quase reto (sem área) quebraria o desenho: ignora
		if absf((p1 - p0).cross(p2 - p0)) < 4.0:
			return
		list.append(PackedVector2Array([p0, p1, p2]))


	func _process(delta: float) -> void:
		t += delta
		if t >= total:
			get_parent().queue_free()   # leva o CanvasLayer junto
			return
		queue_redraw()


	func _draw_ray(pts: PackedVector2Array, f: float, color: Color, width: float) -> void:
		var seg: int = int(f)
		for j in range(mini(seg, pts.size() - 1)):
			draw_line(pts[j], pts[j + 1], color, width)
		if seg < pts.size() - 1:
			draw_line(pts[seg], pts[seg].lerp(pts[seg + 1], f - float(seg)), color, width)


	func _draw() -> void:
		var light: Color = OneMoreTimeFX.ICE_LIGHT
		var mid: Color = OneMoreTimeFX.ICE_MID
		var fall_start: float = CRACK_TIME + HOLD_TIME

		# Clarão azul na tela toda + onda de choque saindo do impacto
		if t < 0.4:
			var fa: float = 1.0 - t / 0.4
			draw_rect(Rect2(Vector2.ZERO, view_size), Color(mid, OneMoreTimeFX.GLASS_FLASH * fa * fa))
			draw_circle(center, 25.0 + 130.0 * (1.0 - fa), Color(light, 0.10 * fa))

		# Estrela do impacto
		if t < 0.25:
			var sa: float = 1.0 - t / 0.25
			for k in 8:
				var d: Vector2 = Vector2.from_angle(0.2 + float(k) * TAU / 8.0)
				draw_line(center, center + d * (30.0 + 80.0 * (1.0 - sa)), Color(light, 0.7 * sa), 2.5 * sa + 1.0)

		# Rachaduras (crescem em CRACK_TIME e esmaecem quando o vidro cai)
		var grow: float = clampf(t / CRACK_TIME, 0.0, 1.0)
		var crack_alpha: float = 1.0
		if t > fall_start:
			crack_alpha = maxf(0.0, 1.0 - (t - fall_start) / 0.35)
		if crack_alpha > 0.0:
			for i in rays.size():
				var pts: PackedVector2Array = rays[i]
				var f: float = grow * float(pts.size() - 1)
				_draw_ray(pts, f, Color(mid, 0.2 * crack_alpha), 4.0)    # brilho
				_draw_ray(pts, f, Color(light, 0.8 * crack_alpha), 1.5)  # linha
				# "teia": liga cada rachadura à vizinha onde as duas já chegaram
				var nxt: PackedVector2Array = rays[(i + 1) % rays.size()]
				for k in range(1, pts.size()):
					if f >= float(k):
						draw_line(pts[k], nxt[k], Color(light, 0.6 * crack_alpha), 1.5)

		# Cacos: parados (trincados) e depois caindo
		if t >= CRACK_TIME:
			for s: Dictionary in shards:
				var mid_pt: Vector2 = s["mid"]
				var tris: Array = s["tris"]
				var ts: float = t - fall_start - float(s["delay"])
				if ts <= 0.0:
					draw_set_transform(mid_pt, 0.0, Vector2.ONE)
					for tri: PackedVector2Array in tris:
						draw_colored_polygon(tri, Color(mid, 0.05))
					continue
				var a: float = 1.0 - clampf(ts / FALL_TIME, 0.0, 1.0)
				if a <= 0.0:
					continue
				var vel: Vector2 = s["vel"]
				var pos: Vector2 = mid_pt + vel * ts + Vector2(0.0, 300.0 * ts * ts)
				var sc: float = 1.0 + ts * 0.12
				draw_set_transform(pos, float(s["spin"]) * ts, Vector2(sc, sc))
				for tri: PackedVector2Array in tris:
					draw_colored_polygon(tri, Color(light, 0.14 * a))
					draw_line(tri[0], tri[1], Color(light, 0.7 * a), 1.5)
					draw_line(tri[1], tri[2], Color(light, 0.9 * a), 1.5)
					draw_line(tri[2], tri[0], Color(light, 0.9 * a), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
