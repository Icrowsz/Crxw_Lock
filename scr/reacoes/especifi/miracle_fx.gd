class_name MiracleFX
extends Node2D
## Efeitos visuais da reação MIRACLE (Reo + Nagi): um camaleão GIGANTE roxo translúcido,
## inspirado na manifestação do Rin — cabeça enorme com boca aberta, dentes, língua e olho
## dourado de um lado; cauda enrolada em espiral do outro; veias escuras tipo galhos por
## todo o corpo; aura rosa/roxa pulsante e partículas brancas por cima.

const PURPLE := Color(0.62, 0.32, 1.0)
const PURPLE_DEEP := Color(0.30, 0.08, 0.55)
const PURPLE_DARK := Color(0.14, 0.02, 0.28)
const PINK := Color(1.0, 0.25, 0.75)
const PINK_LIGHT := Color(1.0, 0.65, 0.90)
const GOLD := Color(1.0, 0.82, 0.20)
const GOLD_LIGHT := Color(1.0, 0.95, 0.60)
const WHITE := Color(0.98, 0.98, 1.0)
const BLACK := Color(0.03, 0.0, 0.06)

var host: Player
var duration: float = 1.2
var base_r: float = 50.0          # raio base (antes era 78) — agora cobre o Reo inteiro

var _age: float = 0.0
var _redraw_acc: float = 0.0
var _particles: CPUParticles2D
var _embers: CPUParticles2D
var _soft_tex: GradientTexture2D
var _eye_shift: float = 0.0
var _veins: Array = []             # veias pré-calculadas (não mudam entre frames)
var _teeth_top: Array = []
var _teeth_bot: Array = []


# ---------- CRIAÇÃO ----------

static func attach(to: Player, seconds: float = 2.8) -> MiracleFX:
	if to == null:
		return null
	var fx := MiracleFX.new()
	fx.host = to
	fx.duration = seconds
	fx.z_index = -2
	to.add_child(fx)
	fx.position = Vector2(0.0, -to.height - to.placeholder_radius * 0.5)
	return fx


func _ready() -> void:
	show_behind_parent = true
	_build_veins()
	_build_teeth()
	_particles = _make_particles(90, WHITE, 130.0, 1.0, 70.0)
	add_child(_particles)
	_particles.emitting = true
	_embers = _make_particles(60, PINK_LIGHT, 90.0, 1.2, 90.0)
	_embers.direction = Vector2(0.0, -1.0)
	_embers.spread = 60.0
	_embers.gravity = Vector2(0.0, -70.0)
	add_child(_embers)
	_embers.emitting = true


func _make_particles(amount: int, color: Color, speed: float, lifetime: float,
		radius: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = _get_soft_texture()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.9
	p.damping_max = speed * 0.9
	p.gravity = Vector2.ZERO
	p.angle_max = 360.0
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.6
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


## Veias/galhos escuros espalhados pelo corpo (fixas — só a espessura pulsa)
func _build_veins() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7777
	_veins.clear()
	for i in 22:
		var origin := Vector2(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.6, 0.7)) * base_r
		var segs: Array = []
		var cur: Vector2 = origin
		var dir: float = rng.randf_range(0.0, TAU)
		var n: int = rng.randi_range(3, 6)
		for k in n:
			var len: float = rng.randf_range(14.0, 32.0) * (base_r / 128.0)
			var nxt: Vector2 = cur + Vector2.from_angle(dir) * len
			segs.append([cur, nxt])
			cur = nxt
			dir += rng.randf_range(-0.9, 0.9)
		_veins.append({"segs": segs, "w": rng.randf_range(1.8, 4.0)})


## Duas fileiras de dentes, com tamanhos alternados (fixas)
func _build_teeth() -> void:
	_teeth_top.clear()
	_teeth_bot.clear()
	for i in 10:
		_teeth_top.append({
			"x": -70.0 + float(i) * 15.0,
			"h": 22.0 + 10.0 * sin(float(i) * 1.3),
			"w": 9.0,
		})
	for i in 9:
		_teeth_bot.append({
			"x": -60.0 + float(i) * 15.0,
			"h": 18.0 + 8.0 * sin(float(i) * 1.7 + 1.0),
			"w": 8.0,
		})


# ---------- LOOP ----------

func _process(delta: float) -> void:
	_age += delta
	if _age > duration:
		if _particles:
			_particles.emitting = false
		if _embers:
			_embers.emitting = false
		if _age > duration + 0.9:
			queue_free()
		_redraw_acc += delta
		if _redraw_acc >= 0.04:
			_redraw_acc = 0.0
			queue_redraw()
		return
	if is_instance_valid(host):
		position = Vector2(0.0, -host.height - host.placeholder_radius * 0.5)
	_eye_shift = sin(_age * 2.4) * 3.0
	_redraw_acc += delta
	if _redraw_acc >= 0.04:
		_redraw_acc = 0.0
		queue_redraw()


# ---------- DRAW ----------

func _draw() -> void:
	var alpha: float = 1.0
	if _age > duration - 0.7:
		alpha = clampf((duration - _age) / 0.7, 0.0, 1.0)
	var appear: float = clampf(_age / 0.35, 0.0, 1.0)
	var scale_k: float = lerpf(0.35, 1.0, _back_out(appear))
	var breathe: float = 1.0 + 0.03 * sin(_age * 2.6)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_k * breathe, scale_k * breathe))
	var r: float = base_r

	# ---------- AURA EM CAMADAS (rosa e roxo) ----------
	var pulse: float = 0.5 + 0.5 * sin(_age * 4.2)
	for i in 5:
		var f: float = 1.0 - float(i) * 0.13
		var col: Color = PINK.lerp(PURPLE, float(i) / 4.0)
		draw_circle(Vector2(0.0, 0.0), r * (1.35 * f) + 18.0 * pulse,
			Color(col, (0.10 + 0.04 * pulse) * alpha * f))

	# ---------- CAUDA ENROLADA (espiral, à direita) ----------
	_draw_tail_curl(Vector2(r * 0.75, r * 0.25), r * 0.68, alpha)

	# ---------- CORPO ----------
	var body := PackedVector2Array([
		Vector2(-r * 1.05, r * 0.10),
		Vector2(-r * 0.85, -r * 0.55),
		Vector2(-r * 0.30, -r * 0.90),
		Vector2(r * 0.35, -r * 0.95),
		Vector2(r * 0.85, -r * 0.65),
		Vector2(r * 1.05, -r * 0.05),
		Vector2(r * 0.90, r * 0.55),
		Vector2(r * 0.35, r * 0.85),
		Vector2(-r * 0.35, r * 0.85),
		Vector2(-r * 0.85, r * 0.55),
	])
	draw_colored_polygon(body, Color(PURPLE, 0.45 * alpha))
	var body_line := body.duplicate()
	body_line.append(body[0])
	draw_polyline(body_line, Color(BLACK, 0.85 * alpha), 4.0)
	draw_polyline(body_line, Color(PURPLE_DEEP, 0.75 * alpha), 2.0)

	# Segundo contorno interno (dá "casca" grossa, como a imagem)
	var inner := PackedVector2Array()
	for p in body:
		inner.append(p * 0.93)
	draw_colored_polygon(inner, Color(PURPLE_DEEP, 0.30 * alpha))

	# ---------- VEias/GALHOS ESCUROS ----------
	_draw_veins(alpha, pulse)

	# ---------- MANCHAS CLARAS (bolt-like, o "cluster" amarelo-claro da imagem) ----------
	for i in 7:
		var ang: float = TAU * float(i) / 7.0 + _age * 0.6
		var rad: float = r * (0.25 + 0.35 * sin(_age * 1.8 + float(i)))
		var p := Vector2(cos(ang) * rad, sin(ang) * rad * 0.7)
		draw_circle(p, 6.0, Color(GOLD_LIGHT, 0.22 * alpha))
		draw_circle(p, 3.0, Color(GOLD_LIGHT, 0.45 * alpha))

	# ---------- PATAS (com garras) ----------
	_draw_leg(Vector2(-r * 0.55, r * 0.85), r * 0.22, -1.0, alpha)
	_draw_leg(Vector2(r * 0.35, r * 0.85), r * 0.22, 1.0, alpha)

	# ---------- CABEÇA (à esquerda, grande) ----------
	_draw_head(Vector2(-r * 1.15, -r * 0.10), r * 0.85, alpha)

	# ---------- BOLHAS ROSA SUBINDO ----------
	for i in 6:
		var t: float = fposmod(_age * 0.55 + float(i) * 0.18, 1.0)
		var x: float = -r * 0.6 + float(i) * (r * 0.24)
		var y: float = -r * (0.7 + t * 0.9)
		draw_circle(Vector2(x, y), 4.0 * (1.0 - t), Color(PINK_LIGHT, 0.85 * alpha * (1.0 - t)))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------- CAUDA ----------

func _draw_tail_curl(center: Vector2, size: float, alpha: float) -> void:
	# Espiral desenhada por segmentos que vão afinando
	var spiral_turns: float = 2.6
	var segments: int = 48
	var prev: Vector2 = center
	for i in range(1, segments + 1):
		var t: float = float(i) / float(segments)
		var ang: float = spiral_turns * TAU * t + _age * 1.2
		var rad: float = size * (1.0 - t * 0.85)
		var p: Vector2 = center + Vector2(cos(ang) * rad, sin(ang) * rad)
		var w: float = lerpf(size * 0.55, 4.0, t)
		draw_line(prev, p, Color(BLACK, 0.85 * alpha), w + 6.0)
		draw_line(prev, p, Color(PURPLE, 0.7 * alpha), w)
		draw_line(prev, p, Color(PURPLE_DEEP, 0.5 * alpha), w * 0.5)
		# Pequenos espinhos dorsais na cauda
		if i % 4 == 0:
			var dir: Vector2 = (p - prev).normalized()
			var perp: Vector2 = dir.orthogonal()
			var spike: Vector2 = p + perp * w * 0.9
			draw_line(p, spike, Color(BLACK, 0.9 * alpha), 3.0)
			draw_line(p, spike, Color(PINK, 0.85 * alpha), 1.5)
		prev = p
	# Ponta final
	draw_circle(prev, 5.0, Color(BLACK, 0.9 * alpha))
	draw_circle(prev, 3.0, Color(PINK, 0.95 * alpha))


# ---------- VEias ----------

func _draw_veins(alpha: float, pulse: float) -> void:
	for v in _veins:
		var w: float = float(v["w"]) * (1.0 + 0.15 * pulse)
		for seg in v["segs"]:
			var a: Vector2 = seg[0]
			var b: Vector2 = seg[1]
			draw_line(a, b, Color(BLACK, 0.75 * alpha), w + 2.0)
			draw_line(a, b, Color(PURPLE_DARK, 0.85 * alpha), w)
			# Pequenos "nós" nas bifurcações
			draw_circle(b, w * 0.9, Color(BLACK, 0.75 * alpha))
			draw_circle(b, w * 0.55, Color(PURPLE_DARK, 0.85 * alpha))


# ---------- PATAS ----------

func _draw_leg(hip: Vector2, size: float, side: float, alpha: float) -> void:
	var dir: Vector2 = Vector2(0.0, 1.0).rotated(side * 0.25)
	var knee: Vector2 = hip + dir * size * 1.3
	var foot: Vector2 = knee + Vector2(side * size * 0.4, size * 1.0)
	# Perna
	draw_line(hip, knee, Color(BLACK, 0.85 * alpha), size * 0.55 + 4.0)
	draw_line(hip, knee, Color(PURPLE, 0.75 * alpha), size * 0.55)
	draw_line(knee, foot, Color(BLACK, 0.85 * alpha), size * 0.45 + 4.0)
	draw_line(knee, foot, Color(PURPLE, 0.75 * alpha), size * 0.45)
	# 3 dedos com garras
	for k in 3:
		var ang: float = deg_to_rad(-35.0 + 35.0 * float(k)) + (0.0 if side > 0.0 else PI)
		var claw_dir: Vector2 = Vector2.from_angle(ang)
		var claw_tip: Vector2 = foot + claw_dir * size * 0.7
		draw_line(foot, claw_tip, Color(BLACK, 0.9 * alpha), size * 0.22 + 3.0)
		draw_line(foot, claw_tip, Color(PURPLE, 0.85 * alpha), size * 0.22)
		# Ponta da garra (preta com brilho)
		draw_circle(claw_tip, size * 0.10, Color(BLACK, 0.95 * alpha))
		draw_circle(claw_tip, size * 0.05, Color(GOLD_LIGHT, 0.9 * alpha))


# ---------- CABEÇA ----------

func _draw_head(center: Vector2, size: float, alpha: float) -> void:
	draw_set_transform(center, 0.0, Vector2.ONE)

	# Aura de fundo da cabeça
	for i in 3:
		draw_circle(Vector2(0.0, 0.0), size * (1.15 - float(i) * 0.15),
			Color(PINK, (0.14 - float(i) * 0.04) * alpha))

	# Crânio (com bico para a esquerda, o maxilar fica por baixo)
	var skull := PackedVector2Array([
		Vector2(size * 0.55, -size * 0.55),
		Vector2(size * 0.95, -size * 0.30),
		Vector2(size * 0.95, size * 0.15),
		Vector2(size * 0.55, size * 0.35),
		Vector2(-size * 0.55, size * 0.20),
		Vector2(-size * 1.05, 0.0),
		Vector2(-size * 0.55, -size * 0.30),
	])
	draw_colored_polygon(skull, Color(PURPLE, 0.55 * alpha))
	var skull_line := skull.duplicate()
	skull_line.append(skull[0])
	draw_polyline(skull_line, Color(BLACK, 0.9 * alpha), 4.0)
	draw_polyline(skull_line, Color(PURPLE_DEEP, 0.75 * alpha), 2.0)

	# Veias na cabeça (galhos escuros)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in 6:
		var start: Vector2 = Vector2(rng.randf_range(-size * 0.4, size * 0.6),
			rng.randf_range(-size * 0.3, size * 0.2))
		var prev: Vector2 = start
		var dir: float = rng.randf_range(-PI, PI)
		for k in 4:
			var nxt: Vector2 = prev + Vector2.from_angle(dir) * size * rng.randf_range(0.14, 0.24)
			draw_line(prev, nxt, Color(BLACK, 0.75 * alpha), 3.0)
			draw_line(prev, nxt, Color(PURPLE_DARK, 0.9 * alpha), 1.5)
			draw_circle(nxt, 1.8, Color(BLACK, 0.85 * alpha))
			prev = nxt
			dir += rng.randf_range(-0.8, 0.8)

	# ---------- CRISTA (espinhos no topo da cabeça) ----------
	for i in 5:
		var cs: Vector2 = Vector2(size * 0.0 + float(i) * size * 0.20, -size * 0.55)
		var spike_h: float = size * (0.18 + 0.08 * sin(float(i) * 1.4 + _age * 3.0))
		draw_colored_polygon(PackedVector2Array([
			cs + Vector2(-size * 0.08, 0.0),
			cs + Vector2(0.0, -spike_h),
			cs + Vector2(size * 0.08, 0.0)]), Color(PURPLE_DEEP, 0.9 * alpha))
		draw_polyline(PackedVector2Array([
			cs + Vector2(-size * 0.08, 0.0),
			cs + Vector2(0.0, -spike_h),
			cs + Vector2(size * 0.08, 0.0),
			cs + Vector2(-size * 0.08, 0.0)]), Color(BLACK, 0.95 * alpha), 2.0)
		draw_circle(cs + Vector2(0.0, -spike_h), 2.5, Color(PINK_LIGHT, 0.9 * alpha))

	# ---------- CHIFRES curtos (atrás) ----------
	for sgn in [-1.0, 1.0]:
		var s: float = float(sgn)
		var horn := PackedVector2Array()
		for k in 8:
			var u: float = float(k) / 7.0
			horn.append(Vector2(size * 0.85 + size * 0.35 * u,
				s * (size * 0.10 + size * 0.30 * u - size * 0.10 * u * u)))
		draw_polyline(horn, Color(BLACK, 0.95 * alpha), 7.0)
		draw_polyline(horn, Color(PURPLE_DEEP, 0.95 * alpha), 4.0)
		draw_circle(horn[horn.size() - 1], 3.0, Color(GOLD_LIGHT, 0.85 * alpha))

	# ---------- MANDÍBULA (aberta, embaixo) ----------
	var jaw_open: float = 1.0 + 0.15 * sin(_age * 4.0)
	var jaw := PackedVector2Array([
		Vector2(size * 0.45, size * 0.30),
		Vector2(-size * 0.50, size * 0.25 * jaw_open),
		Vector2(-size * 0.85, size * 0.55 * jaw_open),
		Vector2(-size * 0.10, size * 0.75 * jaw_open),
		Vector2(size * 0.55, size * 0.55),
	])
	draw_colored_polygon(jaw, Color(PURPLE_DEEP, 0.85 * alpha))
	var jaw_line := jaw.duplicate()
	jaw_line.append(jaw[0])
	draw_polyline(jaw_line, Color(BLACK, 0.95 * alpha), 3.0)

	# ---------- GARGANTA (interior escuro, com língua) ----------
	draw_colored_polygon(PackedVector2Array([
		Vector2(size * 0.30, size * 0.28),
		Vector2(-size * 0.45, size * 0.28 * jaw_open),
		Vector2(-size * 0.55, size * 0.55 * jaw_open),
		Vector2(size * 0.25, size * 0.45),
	]), Color(BLACK, 0.9 * alpha))

	# ---------- DENTES (em cima e embaixo) ----------
	for t in _teeth_top:
		var tx: float = float(t["x"]) * (size / 128.0)
		var th: float = float(t["h"]) * (size / 128.0)
		var tw: float = float(t["w"]) * (size / 128.0)
		var ty: float = size * 0.10
		var tri := PackedVector2Array([
			Vector2(tx - tw, ty), Vector2(tx + tw, ty), Vector2(tx, ty + th)])
		draw_colored_polygon(tri, Color(WHITE, 0.98 * alpha))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]),
			Color(BLACK, 0.9 * alpha), 1.5)
	for t in _teeth_bot:
		var tx: float = float(t["x"]) * (size / 128.0)
		var th: float = float(t["h"]) * (size / 128.0)
		var tw: float = float(t["w"]) * (size / 128.0)
		var ty: float = size * (0.55 * jaw_open)
		var tri := PackedVector2Array([
			Vector2(tx - tw, ty), Vector2(tx + tw, ty), Vector2(tx, ty - th)])
		draw_colored_polygon(tri, Color(WHITE, 0.98 * alpha))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]),
			Color(BLACK, 0.9 * alpha), 1.5)

	# ---------- LÍNGUA (sai da boca e ondula) ----------
	var tongue_base := Vector2(-size * 0.20, size * 0.55 * jaw_open)
	var tongue_len: float = size * (0.55 + 0.10 * sin(_age * 5.0))
	var tongue_tip: Vector2 = tongue_base + Vector2(-tongue_len, size * (0.30 + 0.10 * sin(_age * 4.5)))
	var ctrl: Vector2 = tongue_base + Vector2(-tongue_len * 0.5, -size * 0.10)
	var tongue_pts := PackedVector2Array()
	for k in 10:
		var u: float = float(k) / 9.0
		var pt: Vector2 = (1.0 - u) * (1.0 - u) * tongue_base \
			+ 2.0 * (1.0 - u) * u * ctrl + u * u * tongue_tip
		tongue_pts.append(pt)
	draw_polyline(tongue_pts, Color(BLACK, 0.95 * alpha), 14.0)
	draw_polyline(tongue_pts, Color(PINK, 0.95 * alpha), 10.0)
	draw_polyline(tongue_pts, Color(PINK_LIGHT, 0.75 * alpha), 4.0)
	# Ponta da língua bifurcada
	draw_circle(tongue_tip, 6.0, Color(BLACK, 0.95 * alpha))
	draw_circle(tongue_tip, 4.0, Color(PINK, 0.95 * alpha))

	# ---------- OLHO GRANDE (dourado, com pupila vertical) ----------
	var eye_pos: Vector2 = Vector2(size * 0.15 + _eye_shift, -size * 0.10)
	var eye_r: float = size * 0.30
	# Órbita saliente (o "cone" do camaleão)
	draw_circle(eye_pos, eye_r * 1.20, Color(BLACK, 0.95 * alpha))
	draw_circle(eye_pos, eye_r * 1.10, Color(PURPLE_DEEP, 0.95 * alpha))
	draw_circle(eye_pos, eye_r, Color(PURPLE, 0.95 * alpha))
	draw_circle(eye_pos, eye_r * 0.85, Color(BLACK, 0.85 * alpha))
	# Íris dourada
	draw_circle(eye_pos, eye_r * 0.72, Color(GOLD, 0.98 * alpha))
	draw_circle(eye_pos, eye_r * 0.72, Color(GOLD_LIGHT, 0.45 * alpha))
	# Pupila vertical (bem fina)
	var pupil_w: float = eye_r * 0.18
	var pupil_h: float = eye_r * 0.65
	draw_rect(Rect2(eye_pos.x - pupil_w, eye_pos.y - pupil_h, pupil_w * 2.0, pupil_h * 2.0),
		Color(BLACK, 0.98 * alpha))
	# Brilho de luz
	draw_circle(eye_pos + Vector2(-eye_r * 0.22, -eye_r * 0.22), eye_r * 0.14,
		Color(WHITE, 0.95 * alpha))
	# Anel brilhante em volta do olho (dá "vivo")
	for i in 2:
		draw_arc(eye_pos, eye_r * (1.05 + float(i) * 0.10), 0.0, TAU, 32,
			Color(GOLD_LIGHT, (0.45 - float(i) * 0.18) * alpha), 2.5)

	# ---------- Segunda órbita menor (o camaleão da imagem tem os dois olhos) ----------
	var eye2: Vector2 = Vector2(size * 0.65, -size * 0.30)
	draw_circle(eye2, eye_r * 0.55, Color(BLACK, 0.85 * alpha))
	draw_circle(eye2, eye_r * 0.45, Color(PURPLE_DEEP, 0.85 * alpha))
	draw_circle(eye2, eye_r * 0.32, Color(GOLD, 0.85 * alpha))
	draw_rect(Rect2(eye2.x - 1.6, eye2.y - eye_r * 0.28, 3.2, eye_r * 0.56), Color(BLACK, 0.9 * alpha))


# ---------- HELPERS ----------

func _back_out(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
