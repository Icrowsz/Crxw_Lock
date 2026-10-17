class_name SuperstarFX
extends Node2D
## Efeitos visuais da reação SUPERSTAR (Kiyora + Kaiser). Tudo desenhado por código.
##
##  - SCALE: a BALANÇA DOURADA DA JUSTIÇA que a Kiyora cria ao usar o Borderline / Even the Gods
##    sob o efeito do Empire. Ela surge acima da Kiyora com um "pop", balança e se acomoda
##    pendendo para o lado de quem RECEBE a bola (quem tem menos gols). Cada prato mostra o nome
##    e os gols do aliado. Se quem recebe é o Kaiser (reação pronta), o prato dele brilha, ganha
##    uma estrela e aparece "SUPERSTAR" embaixo da balança.
##  - ROSES: rosas azuis translúcidas (versões pequenas da rosa gigante do Herbivicus) que
##    acompanham a trajetória do Be Loved, em hélice em volta da bola, com uma explosão de
##    pétalas, clarão e tremida de câmera no instante do chute.
##  - PASS: efeitos do PASSE da Kiyora (Borderline / Even the Gods) junto com a balança: anel
##    dourado e brilhos nela no instante do passe, fios dourados ligando-a aos dois aliados
##    escolhidos (o de quem recebe é mais forte, com um halo e uma estrela), rastro de brilhos
##    na bola durante o passe e uma ondulação dourada quando a bola chega.
##
## DESEMPENHO: as flores do Be Loved são desenhadas com malhas pré-montadas (draw_mesh) em vez de
## um polígono + uma linha por pétala a cada quadro (veja _get_layer_meshes).

enum Style { SCALE, ROSES, PASS }

const GOLD := Color(1.0, 0.80, 0.22)
const GOLD_LIGHT := Color(1.0, 0.95, 0.62)
const GOLD_DARK := Color(0.60, 0.40, 0.05)
## Contorno da balança: dourado escuro (antes era quase preto), para manter a paleta
const OUTLINE := Color(0.42, 0.27, 0.03)
const WHITE := Color(1.0, 0.98, 0.94)

# Medidas da balança (em px, antes do fator de tamanho)
const BEAM_HALF: float = 54.0     # metade do comprimento da viga
const POST_LEN: float = 84.0      # do pivô até a base
const CHAIN_LEN: float = 46.0     # corrente que segura cada prato
const PAN_RADIUS: float = 22.0
const MAX_TILT: float = 0.30      # inclinação final da viga (rad)

## Intervalo entre as "levas" de flores na trilha, e limite de flores vivas
const SPAWN_EVERY: float = 0.045
const MAX_FLOWERS: int = 44

var style: Style = Style.SCALE
var target: Node2D
var duration: float = 3.4
## Fator de tamanho da balança (1.0 = medidas acima)
var size_mult: float = 0.9

# --- SCALE ---
var _left: Dictionary = {}          # {"name": String, "goals": int}; vazio = prato vazio
var _right: Dictionary = {}
var _receiver_left: bool = true     # o prato que recebe a bola desce
var _armed: bool = false            # quem recebe é o Kaiser: a Superstar está de pé

## 0 = a balança paira em cima da Kiyora; +1 / -1 = fica no chão AO LADO dela (direita / esquerda)
var _side: float = 0.0

# --- PASS ---
var _pass_ball: Ball
var _pass_chosen: Array[Player] = []
var _pass_receiver: Player
var _pass_last_pos: Vector2 = Vector2.ZERO
var _pass_moved: bool = false
var _ripple_age: float = -1.0
var _ripple_pos: Vector2 = Vector2.ZERO

# --- ROSES ---
var _flowers: Array[Dictionary] = []
var _touches: int = 0
var _spawn_timer: float = 0.0
var _phase: float = 0.0

var _age: float = 0.0
var _particles: CPUParticles2D
var _soft_tex: GradientTexture2D
var _shake_tween: Tween
var _shake_cam: Camera2D
var _shake_rest: Vector2 = Vector2.ZERO


# ---------- CRIAÇÃO ----------

## "to" = a Kiyora (a balança paira acima dela). left/right = {"name", "goals"} de cada prato
## (right vazio se só havia um aliado ao alcance). receiver_left = o prato que recebe a bola.
## armed = true quando quem recebe é o Kaiser (estrela + "SUPERSTAR").
## side = 0 em cima da Kiyora; +1 / -1 no chão ao lado dela (direita / esquerda).
static func attach_scale(to: Node2D, left: Dictionary, right: Dictionary,
		receiver_left: bool, armed: bool, seconds: float = 3.4, side: float = 0.0) -> SuperstarFX:
	if to == null:
		return null
	var fx := SuperstarFX.new()
	fx.style = Style.SCALE
	fx.target = to
	fx._side = side
	fx.duration = seconds
	fx._left = left
	fx._right = right
	fx._receiver_left = receiver_left
	fx._armed = armed
	fx.z_index = 3000
	fx.z_as_relative = false
	to.add_child(fx)
	fx.top_level = true
	fx.global_position = fx._scale_anchor()
	return fx


## Efeitos do passe da Kiyora ("from"): "chosen" são os aliados escolhidos e "receiver" quem recebe.
## Chame no instante em que a bola sai.
static func attach_pass(from: Player, ball: Ball, chosen: Array[Player], receiver: Player,
		seconds: float = 3.0) -> SuperstarFX:
	if from == null or ball == null or ball.get_parent() == null:
		return null
	var fx := SuperstarFX.new()
	fx.style = Style.PASS
	fx.target = from
	fx.duration = seconds
	fx._pass_ball = ball
	fx._pass_chosen = chosen
	fx._pass_receiver = receiver
	fx._pass_last_pos = ball.global_position
	fx.z_index = 3000
	fx.z_as_relative = false
	ball.get_parent().add_child(fx)
	fx.top_level = true
	fx.global_position = Vector2.ZERO   # tudo é desenhado em coordenadas globais
	return fx


## As flores acompanham a bola do Be Loved por "seconds" segundos (ou até alguém tocar nela)
static func attach_roses(ball: Ball, seconds: float = 3.0) -> SuperstarFX:
	if ball == null or ball.get_parent() == null:
		return null
	var fx := SuperstarFX.new()
	fx.style = Style.ROSES
	fx.target = ball
	fx.duration = seconds
	fx._touches = ball.interaction_count   # o chute do Kaiser já foi contado
	fx.z_index = 3000
	fx.z_as_relative = false
	ball.get_parent().add_child(fx)
	fx.top_level = true
	fx.global_position = Vector2.ZERO   # as flores ficam em coordenadas globais
	return fx


func _ready() -> void:
	match style:
		Style.ROSES:
			_setup_roses_fx()
			_launch_burst.call_deferred()
		Style.PASS:
			_setup_pass_fx()
			_pass_burst.call_deferred()
		_:
			_setup_scale_fx()
			_appear_burst.call_deferred()


func _setup_scale_fx() -> void:
	_particles = _make_particles(26, GOLD_LIGHT, 60.0, 1.0)
	_particles.emission_sphere_radius = 54.0 * size_mult
	_particles.gravity = Vector2(0.0, -30.0)
	add_child(_particles)
	_particles.position = Vector2(0.0, POST_LEN * 0.4 * size_mult)
	_particles.emitting = true


func _setup_pass_fx() -> void:
	# Rastro de brilhos dourados que acompanha a bola (só emite enquanto ela anda)
	_particles = _make_particles(18, GOLD_LIGHT, 55.0, 0.7)
	_particles.emission_sphere_radius = 8.0
	add_child(_particles)
	_particles.emitting = false


func _setup_roses_fx() -> void:
	_particles = _make_particles(26, HerbivicusFX.BLUE_LIGHT, 70.0, 0.8)
	_particles.emission_sphere_radius = 14.0
	add_child(_particles)
	_particles.emitting = true


func _make_particles(amount: int, color: Color, speed: float, lifetime: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _get_soft_texture()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 30.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.1
	p.damping_max = speed * 1.1
	p.gravity = Vector2.ZERO
	p.angle_max = 360.0
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.45
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 0.95))
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	return p


func _get_soft_texture() -> GradientTexture2D:
	if _soft_tex == null:
		var grad := Gradient.new()
		grad.set_color(0, Color.WHITE)
		grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		_soft_tex = GradientTexture2D.new()
		_soft_tex.gradient = grad
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(0.5, 0.0)
		_soft_tex.width = 32
		_soft_tex.height = 32
	return _soft_tex


# ---------- ENTRADA ----------

func _appear_burst() -> void:
	if not is_inside_tree():
		return
	_spawn_sparkle_burst(32, GOLD_LIGHT, 220.0, 0.8)
	if _armed:
		_spawn_sparkle_burst(18, WHITE, 160.0, 0.6)


## Brilhos dourados em volta da Kiyora no instante do passe (o anel é desenhado em _draw_pass)
func _pass_burst() -> void:
	if not is_inside_tree() or not is_instance_valid(target):
		return
	var center: Vector2 = _target_center(target)
	_spawn_sparkle_burst(30, GOLD_LIGHT, 260.0, 0.75, true, center)
	_spawn_sparkle_burst(14, WHITE, 180.0, 0.55, true, center)


## Explosão de pétalas + clarão + tremida no instante do chute do Be Loved
func _launch_burst() -> void:
	if not is_inside_tree() or not is_instance_valid(target):
		return
	var center: Vector2 = _target_center(target)
	_spawn_flash(Color(0.65, 0.88, 1.0, 0.45), 0.45)
	_spawn_flash(Color(0.35, 0.5, 1.0, 0.30), 0.7)
	_shake_camera(14.0, 0.6)
	_spawn_sparkle_burst(46, HerbivicusFX.BLUE_LIGHT, 360.0, 0.9)
	_spawn_sparkle_burst(30, Color(0.5, 0.65, 1.0), 300.0, 0.8)
	for i in 18:
		var dir := Vector2.from_angle(randf() * TAU)
		_add_flower(center + dir * randf_range(0.0, 10.0), dir * randf_range(110.0, 280.0),
			randf_range(8.0, 14.0), randf_range(1.1, 1.8))


# ---------- UPDATE ----------

func _process(delta: float) -> void:
	_age += delta
	match style:
		Style.ROSES:
			_update_roses(delta)
		Style.PASS:
			_update_pass(delta)
		_:
			_update_scale()
	queue_redraw()


func _update_scale() -> void:
	if _age > duration or not is_instance_valid(target):
		if _particles:
			_particles.emitting = false
		queue_free()
		return
	global_position = _scale_anchor()


func _update_pass(delta: float) -> void:
	if _age > duration or not is_instance_valid(target):
		if _particles:
			_particles.emitting = false
		queue_free()
		return
	var ball: Ball = _pass_ball
	if is_instance_valid(ball):
		var head: Vector2 = _target_center(ball)
		var moved: bool = head.distance_to(_pass_last_pos) > 0.6
		if _particles:
			_particles.global_position = head
			_particles.emitting = moved
		if moved:
			_pass_moved = true
		elif _pass_moved and _ripple_age < 0.0:
			# A bola andou e parou: chegou. Ondulação dourada + brilhos no ponto de chegada
			_ripple_age = 0.0
			_ripple_pos = head
			_spawn_sparkle_burst(16, GOLD_LIGHT, 190.0, 0.6, true, head)
		_pass_last_pos = head
	if _ripple_age >= 0.0:
		_ripple_age += delta


func _update_roses(delta: float) -> void:
	var ball := target as Ball
	var ball_ok: bool = is_instance_valid(ball) and _age < duration
	if ball_ok and (ball.interaction_count != _touches or ball.hovering):
		ball_ok = false   # alguém tocou ou prendeu a bola: a trilha acaba aqui

	if ball_ok and ball.velocity.length() > 25.0:
		var head: Vector2 = _target_center(ball)
		if _particles:
			_particles.global_position = head
			_particles.emitting = true
		_spawn_timer -= delta
		while _spawn_timer <= 0.0:
			_spawn_timer += SPAWN_EVERY
			_spawn_trail(head, ball.velocity)
	elif _particles:
		_particles.emitting = false

	# Anima as flores vivas
	var i: int = _flowers.size() - 1
	while i >= 0:
		var f: Dictionary = _flowers[i]
		f["age"] = float(f["age"]) + delta
		if float(f["age"]) >= float(f["life"]):
			_flowers.remove_at(i)
		else:
			f["pos"] = (f["pos"] as Vector2) + (f["vel"] as Vector2) * delta
			f["vel"] = (f["vel"] as Vector2) * maxf(0.0, 1.0 - 1.8 * delta)
			f["rot"] = float(f["rot"]) + float(f["spin"]) * delta
		i -= 1

	if not ball_ok and _flowers.is_empty():
		queue_free()


## Duas flores por leva, uma de cada lado da bola e de cores alternadas: forma uma hélice
func _spawn_trail(head: Vector2, vel: Vector2) -> void:
	var dir: Vector2 = vel.normalized()
	var perp := Vector2(-dir.y, dir.x)
	_phase += 0.85
	var swing: float = sin(_phase)
	for side in [1.0, -1.0]:
		var offset: Vector2 = perp * swing * side * randf_range(10.0, 26.0) \
			+ dir * randf_range(-6.0, 6.0)
		var drift: Vector2 = perp * side * randf_range(8.0, 30.0) + Vector2(0.0, randf_range(-28.0, -8.0))
		_add_flower(head + offset, drift, randf_range(7.0, 12.0), randf_range(0.9, 1.5))


func _add_flower(pos: Vector2, vel: Vector2, flower_size: float, life: float) -> void:
	if _flowers.size() >= MAX_FLOWERS:
		_flowers.pop_front()
	_flowers.append({
		"pos": pos, "vel": vel, "age": 0.0, "life": life,
		"size": flower_size, "rot": randf() * TAU, "spin": randf_range(-3.0, 3.0),
	})


# ---------- POSIÇÃO ----------

## Onde fica o pivô da balança: acima da cabeça da Kiyora (a base fica logo acima dela)
func _scale_anchor() -> Vector2:
	if not is_instance_valid(target):
		return global_position
	var up: float = 18.0 + (POST_LEN + 8.0) * size_mult
	if target is Player:
		var p: Player = target
		if _side != 0.0:
			# AO LADO dela: a base da balança apoia no chão, ao lado do corpo (os pratos ficam
			# a uma distância que não cobre a Kiyora)
			var dx: float = _side * ((BEAM_HALF + PAN_RADIUS) * size_mult + p.placeholder_radius + 14.0)
			var dy: float = -p.height + p.placeholder_radius * 0.6 - (POST_LEN + 8.0) * size_mult
			return p.global_position + Vector2(dx, dy)
		return p.global_position + Vector2(0.0, -p.height - p.placeholder_radius - up)
	return target.global_position + Vector2(0.0, -up)


func _target_center(t: Node2D) -> Vector2:
	if t is Ball:
		var ball: Ball = t
		if ball.sprite:
			return ball.sprite.global_position
		return ball.global_position
	if t is Player:
		var p: Player = t
		return p.global_position + Vector2(0.0, -p.height - p.placeholder_radius)
	return t.global_position


# ---------- UTIL: flash, tremor, brilhos ----------

func _spawn_flash(color: Color, time: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	get_tree().root.add_child(layer)
	var tw: Tween = rect.create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(layer.queue_free)


func _shake_camera(strength: float, shake_time: float) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		if is_instance_valid(_shake_cam):
			_shake_cam.offset = _shake_rest
	_shake_cam = cam
	_shake_rest = cam.offset
	var steps: int = maxi(int(shake_time / 0.03), 2)
	_shake_tween = create_tween()
	for i in steps:
		var fade: float = 1.0 - float(i) / float(steps)
		var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * fade
		_shake_tween.tween_property(cam, "offset", _shake_rest + jitter, 0.03)
	_shake_tween.tween_property(cam, "offset", _shake_rest, 0.03)


func _spawn_sparkle_burst(amount: int, color: Color, speed: float, lifetime: float,
		use_at: bool = false, at: Vector2 = Vector2.ZERO) -> void:
	var p := CPUParticles2D.new()
	p.texture = _get_soft_texture()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.9
	p.damping_max = speed * 0.9
	p.gravity = Vector2(0.0, -20.0)
	p.angle_max = 360.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.75
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 1.0))
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	p.z_index = 3001
	p.z_as_relative = false
	add_child(p)
	if use_at:
		p.global_position = at
	elif style == Style.ROSES and is_instance_valid(target):
		p.global_position = _target_center(target)
	else:
		p.global_position = global_position + Vector2(0.0, POST_LEN * 0.4 * size_mult)
	p.emitting = true
	get_tree().create_timer(lifetime + 0.6).timeout.connect(p.queue_free)


# ---------- DRAW ----------

func _draw() -> void:
	match style:
		Style.ROSES:
			_draw_roses()
		Style.PASS:
			_draw_pass()
		_:
			_draw_scale()


## Efeitos do passe: anel na Kiyora, fios dourados até os dois aliados (o de quem recebe é mais
## forte, com halo e estrela) e a ondulação na chegada da bola
func _draw_pass() -> void:
	var fade: float = clampf((duration - _age) / 0.5, 0.0, 1.0) * clampf(_age / 0.12, 0.0, 1.0)
	if fade <= 0.01 or not is_instance_valid(target):
		return
	var from: Vector2 = _target_center(target)

	# Anel dourado se abrindo em volta da Kiyora
	if _age < 0.7:
		var k: float = _age / 0.7
		draw_arc(from, 20.0 + 70.0 * k, 0.0, TAU, 32, Color(GOLD, (1.0 - k) * fade), 3.0)
		draw_arc(from, 12.0 + 44.0 * k, 0.0, TAU, 28, Color(WHITE, (1.0 - k) * 0.8 * fade), 2.0)

	for p in _pass_chosen:
		if not is_instance_valid(p):
			continue
		var to: Vector2 = _target_center(p)
		var strong: bool = p == _pass_receiver
		_draw_link(from, to, strong, fade)
		var pulse: float = sin(_age * 6.0) * 3.0 if strong else 0.0
		draw_arc(to, 26.0 + pulse, 0.0, TAU, 28,
			Color(GOLD, (0.9 if strong else 0.4) * fade), 3.0 if strong else 1.5)
		if strong:
			draw_circle(to, 24.0, Color(GOLD_LIGHT, 0.12 * fade))
			_draw_star(to + Vector2(0.0, -p.placeholder_radius - 30.0 + sin(_age * 5.0) * 3.0), 9.0, fade)

	# Ondulação dourada onde a bola chegou
	if _ripple_age >= 0.0 and _ripple_age < 0.8:
		var r: float = _ripple_age / 0.8
		draw_arc(_ripple_pos, 12.0 + 54.0 * r, 0.0, TAU, 32, Color(GOLD, (1.0 - r) * fade), 3.0)
		draw_arc(_ripple_pos, 6.0 + 32.0 * r, 0.0, TAU, 24, Color(WHITE, (1.0 - r) * 0.7 * fade), 2.0)


## Fio dourado curvo de "a" até "b", com bolinhas de luz correndo por ele (só no de quem recebe)
func _draw_link(a: Vector2, b: Vector2, strong: bool, fade: float) -> void:
	var length: float = a.distance_to(b)
	if length < 4.0:
		return
	var perp := Vector2(-(b.y - a.y), b.x - a.x).normalized()
	var ctrl: Vector2 = (a + b) * 0.5 + perp * length * 0.16
	var pts := PackedVector2Array()
	var steps: int = 12
	for i in steps + 1:
		var t: float = float(i) / float(steps)
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	var alpha: float = (0.85 if strong else 0.35) * fade
	draw_polyline(pts, Color(OUTLINE, alpha * 0.8), 4.0 if strong else 2.6)
	draw_polyline(pts, Color(GOLD, alpha), 2.4 if strong else 1.3)
	if strong:
		for d in 3:
			var t: float = fposmod(_age * 0.9 + float(d) / 3.0, 1.0)
			var pos: Vector2 = a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
			draw_circle(pos, 4.5, Color(GOLD_LIGHT, 0.3 * fade))
			draw_circle(pos, 2.4, Color(WHITE, 0.95 * fade))


## Número de pétalas de cada camada da rosa pequena, da de fora para a de dentro
const FLOWER_LAYERS := [6, 5, 4]

## As 3 camadas de pétalas são montadas UMA vez como malhas (ArrayMesh) e depois só desenhadas com
## draw_mesh(). Antes, cada pétala era um polígono triangulado + uma linha suavizada a CADA QUADRO
## (mais de mil por quadro com 70 flores): era isso que derrubava o FPS na trajetória do Be Loved.
static var _layer_meshes: Array = []


static func _get_layer_meshes() -> Array:
	if not _layer_meshes.is_empty():
		return _layer_meshes
	var layers: int = FLOWER_LAYERS.size()
	for layer in layers:
		var k: float = float(layer) / float(layers - 1)   # 0 = fora, 1 = dentro
		var count: int = FLOWER_LAYERS[layer]
		var base_col: Color = HerbivicusFX.BLUE_DEEP.lerp(HerbivicusFX.BLUE_LIGHT, k)
		var fill := Color(base_col, lerpf(0.5, 0.8, k))
		var edge := Color(HerbivicusFX.BLUE_LIGHT, 0.9)
		var verts := PackedVector2Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		for i in count:
			var outline: PackedVector2Array = _petal_outline(1.0, 0.5, TAU * float(i) / float(count))
			# Preenchimento: leque a partir da base da pétala (que é um vértice do contorno)
			var base: int = verts.size()
			for pt in outline:
				verts.append(pt)
				cols.append(fill)
			for j in range(1, outline.size() - 1):
				idx.append(base)
				idx.append(base + j)
				idx.append(base + j + 1)
			# Borda: uma faixa fina em cada lado do contorno
			var n: int = outline.size()
			for j in n:
				var a: Vector2 = outline[j]
				var b: Vector2 = outline[(j + 1) % n]
				var along: Vector2 = b - a
				if along.length() < 0.0001:
					continue
				var nrm: Vector2 = Vector2(-along.y, along.x).normalized() * 0.035
				var vi: int = verts.size()
				verts.append(a - nrm)
				verts.append(a + nrm)
				verts.append(b + nrm)
				verts.append(b - nrm)
				for c in 4:
					cols.append(edge)
				idx.append(vi)
				idx.append(vi + 1)
				idx.append(vi + 2)
				idx.append(vi)
				idx.append(vi + 2)
				idx.append(vi + 3)
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_layer_meshes.append(mesh)
	return _layer_meshes


## Contorno de uma pétala em forma de gota saindo da origem, virada para "angle" (mesmo formato da
## rosa gigante). O ponto 0 é a base; o da ponta é o de índice 6.
static func _petal_outline(length: float, width: float, angle: float) -> PackedVector2Array:
	var steps: int = 6
	var pts := PackedVector2Array()
	for s in range(steps + 1):   # lado de cima, do centro até a ponta
		var t: float = float(s) / float(steps)
		var w: float = width * pow(maxf(sin(PI * pow(t, 0.8)), 0.0), 0.6)
		pts.append(Vector2(length * t, -w).rotated(angle))
	for s in range(steps - 1, 0, -1):   # lado de baixo, voltando
		var t: float = float(s) / float(steps)
		var w: float = width * pow(maxf(sin(PI * pow(t, 0.8)), 0.0), 0.6)
		pts.append(Vector2(length * t, w).rotated(angle))
	return pts


func _draw_roses() -> void:
	for f in _flowers:
		var age: float = float(f["age"])
		var life: float = float(f["life"])
		var fade: float = clampf((life - age) / 0.45, 0.0, 1.0)
		if fade <= 0.01:
			continue
		var grow: float = clampf(age / 0.18, 0.0, 1.0)
		_draw_flower(f["pos"] as Vector2, float(f["size"]) * 1.7 * (0.4 + 0.6 * grow),
			float(f["rot"]), grow, fade, age)


## Rosa azul translúcida: versão pequena da rosa gigante do Herbivicus. 3 camadas de pétalas
## (malhas pré-montadas) girando em sentidos opostos e um coração. "grow" = o quanto já desabrochou.
## Flores pequenas pulam a camada de dentro e o brilho do coração (ninguém enxerga a diferença).
func _draw_flower(pos: Vector2, flower_size: float, rot: float, grow: float, fade: float,
		age: float) -> void:
	var meshes: Array = _get_layer_meshes()
	var layers: int = meshes.size()
	var detailed: bool = flower_size >= 15.0
	var tint := Color(1.0, 1.0, 1.0, fade)
	draw_circle(pos, flower_size * 1.05, Color(HerbivicusFX.BLUE, 0.12 * fade))   # luz suave atrás
	for layer in layers:
		if not detailed and layer == layers - 1:
			continue
		var k: float = float(layer) / float(layers - 1)   # 0 = fora, 1 = dentro
		var open: float = 1.0 - pow(1.0 - clampf(grow * (1.0 + 0.5 * k), 0.0, 1.0), 3.0)
		if open <= 0.0:
			continue
		var length: float = flower_size * lerpf(1.0, 0.3, k) * open
		var direction: float = 1.0 if layer % 2 == 0 else -1.0
		var spin: float = rot + age * 0.9 * (1.0 + k) * direction + float(layer) * 0.4
		draw_mesh(meshes[layer], null, Transform2D(spin, Vector2(length, length), 0.0, pos), tint)
	# Coração
	var heart: float = flower_size * 0.2 * grow
	draw_circle(pos, heart * 0.55, Color(HerbivicusFX.WHITE_GLOW, 0.75 * fade))
	if detailed:
		draw_arc(pos, heart, age * 2.0, age * 2.0 + PI * 1.4, 8,
			Color(HerbivicusFX.WHITE_GLOW, 0.9 * fade), maxf(1.0, flower_size * 0.1))


func _ease_out_back(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


func _draw_scale() -> void:
	var pop: float = _ease_out_back(clampf(_age / 0.4, 0.0, 1.0))
	var fade: float = clampf((duration - _age) / 0.5, 0.0, 1.0)
	var alpha: float = fade * clampf(_age / 0.12, 0.0, 1.0)
	if alpha <= 0.01:
		return
	var s: float = size_mult * pop
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))

	# Viga: mola amortecida até a inclinação final (o prato de quem recebe a bola desce)
	var final_tilt: float = -MAX_TILT if _receiver_left else MAX_TILT
	var tilt: float = final_tilt * (1.0 - exp(-3.5 * _age) * cos(9.0 * _age))
	var left_end: Vector2 = Vector2(-BEAM_HALF, 0.0).rotated(tilt)
	var right_end: Vector2 = Vector2(BEAM_HALF, 0.0).rotated(tilt)
	var left_pan: Vector2 = left_end + Vector2(0.0, CHAIN_LEN)
	var right_pan: Vector2 = right_end + Vector2(0.0, CHAIN_LEN)

	# Brilho dourado por trás
	draw_circle(Vector2(0.0, POST_LEN * 0.4), 78.0, Color(GOLD, 0.10 * alpha))
	draw_circle(Vector2(0.0, POST_LEN * 0.4), 54.0, Color(GOLD_LIGHT, 0.12 * alpha))

	# Poste e base
	_gold_line(Vector2(0.0, 0.0), Vector2(0.0, POST_LEN), 6.0, alpha)
	var base := PackedVector2Array([
		Vector2(-24.0, POST_LEN + 8.0), Vector2(-14.0, POST_LEN - 2.0),
		Vector2(14.0, POST_LEN - 2.0), Vector2(24.0, POST_LEN + 8.0)])
	draw_colored_polygon(base, Color(GOLD_DARK, alpha))
	draw_polyline(PackedVector2Array([base[0], base[1], base[2], base[3], base[0]]),
		Color(OUTLINE, alpha), 1.5)

	# Pratos (o do receptor brilha), correntes e viga por cima
	var winner_pan: Vector2 = left_pan if _receiver_left else right_pan
	draw_circle(winner_pan + Vector2(0.0, 6.0), 36.0, Color(GOLD_LIGHT, 0.22 * alpha))
	_draw_pan(left_pan, left_end, alpha)
	if not _right.is_empty():
		_draw_pan(right_pan, right_end, alpha)
	else:
		_draw_pan(right_pan, right_end, alpha * 0.6)
	_gold_line(left_end, right_end, 6.0, alpha)

	# Enfeite no pivô
	draw_circle(Vector2(0.0, 0.0), 8.0, Color(OUTLINE, alpha))
	draw_circle(Vector2(0.0, 0.0), 6.5, Color(GOLD, alpha))
	draw_arc(Vector2(0.0, -14.0), 6.0, 0.0, TAU, 16, Color(OUTLINE, alpha), 4.0)
	draw_arc(Vector2(0.0, -14.0), 6.0, 0.0, TAU, 16, Color(GOLD_LIGHT, alpha), 2.2)

	# Nomes e gols de cada prato
	_draw_pan_label(left_pan, _left, alpha)
	_draw_pan_label(right_pan, _right, alpha)

	# Superstar de pé: estrela sobre o prato do Kaiser e o título embaixo da balança
	if _armed:
		var bob: float = sin(_age * 5.0) * 3.0
		_draw_star(winner_pan + Vector2(0.0, -34.0 + bob), 11.0 + sin(_age * 7.0) * 1.2, alpha)
		var title_alpha: float = clampf((_age - 0.9) / 0.35, 0.0, 1.0) * alpha
		_draw_text("SUPERSTAR", Vector2(0.0, POST_LEN + 34.0), 17, GOLD_LIGHT, title_alpha)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _gold_line(a: Vector2, b: Vector2, width: float, alpha: float) -> void:
	draw_line(a, b, Color(OUTLINE, alpha), width + 3.0)
	draw_line(a, b, Color(GOLD, alpha), width)
	draw_line(a + Vector2(0.0, -width * 0.2), b + Vector2(0.0, -width * 0.2),
		Color(GOLD_LIGHT, 0.7 * alpha), maxf(1.0, width * 0.25))


## Prato: duas correntes + tigela de meia-lua dourada
func _draw_pan(center: Vector2, beam_end: Vector2, alpha: float) -> void:
	var rim_l: Vector2 = center + Vector2(-PAN_RADIUS, 0.0)
	var rim_r: Vector2 = center + Vector2(PAN_RADIUS, 0.0)
	draw_line(beam_end, rim_l, Color(OUTLINE, alpha), 2.6)
	draw_line(beam_end, rim_r, Color(OUTLINE, alpha), 2.6)
	draw_line(beam_end, rim_l, Color(GOLD, alpha), 1.4)
	draw_line(beam_end, rim_r, Color(GOLD, alpha), 1.4)
	var bowl := PackedVector2Array()
	for i in 17:
		var a: float = PI * float(i) / 16.0
		bowl.append(center + Vector2(cos(a) * PAN_RADIUS, sin(a) * 12.0))
	draw_colored_polygon(bowl, Color(GOLD, alpha))
	draw_polyline(bowl, Color(OUTLINE, alpha), 2.0)
	draw_line(rim_l, rim_r, Color(OUTLINE, alpha), 4.5)
	draw_line(rim_l, rim_r, Color(GOLD_LIGHT, alpha), 2.5)
	# reflexo na tigela
	draw_arc(center + Vector2(-4.0, 1.0), PAN_RADIUS * 0.6, PI * 0.15, PI * 0.5, 6,
		Color(WHITE, 0.55 * alpha), 2.0)


func _draw_pan_label(pan: Vector2, info: Dictionary, alpha: float) -> void:
	if info.is_empty():
		return
	var goals: int = int(info.get("goals", 0))
	_draw_text(String(info.get("name", "")), pan + Vector2(0.0, 30.0), 12, WHITE, alpha)
	_draw_text("%d gol%s" % [goals, "" if goals == 1 else "s"], pan + Vector2(0.0, 44.0), 12,
		GOLD_LIGHT, alpha)


func _draw_text(txt: String, pos: Vector2, font_size: int, color: Color, alpha: float) -> void:
	if alpha <= 0.01:
		return
	var w: float = 120.0
	var origin: Vector2 = pos - Vector2(w * 0.5, 0.0)
	draw_string_outline(ThemeDB.fallback_font, origin, txt, HORIZONTAL_ALIGNMENT_CENTER, w,
		font_size, 6, Color(OUTLINE, alpha))
	draw_string(ThemeDB.fallback_font, origin, txt, HORIZONTAL_ALIGNMENT_CENTER, w,
		font_size, Color(color, alpha))


func _draw_star(center: Vector2, radius: float, alpha: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var r: float = radius if i % 2 == 0 else radius * 0.45
		var a: float = -PI * 0.5 + TAU * float(i) / 10.0
		pts.append(center + Vector2.from_angle(a) * r)
	draw_circle(center, radius * 1.5, Color(GOLD_LIGHT, 0.20 * alpha))
	draw_colored_polygon(pts, Color(GOLD, alpha))
	var closed: PackedVector2Array = pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color(OUTLINE, alpha), 1.8)
