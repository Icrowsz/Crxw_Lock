class_name CarnivalFX
extends Node2D
## Efeitos visuais da reação CARNIVAL (Shidou + Sae). Tudo desenhado por código.
##
##  - NUMBERS: tempestade de números rosa-choque com contorno preto girando em duas órbitas
##    (uma devagar, uma rápida ao contrário), números que voam para fora, números que caem
##    por baixo, anéis de energia e brilhos por trás.
##  - DRAGON: dragão serpente GIGANTE rosa/roxo que segue o chute do Shidou. Cabeça detalhada
##    (olhos, presas, chifres, bigodes, sopro de fogo), espinhos dorsais, escamas em camadas,
##    asas translúcidas batendo, duas garras com presas, cauda com ponta afiada. Ao nascer
##    dispara flash, tremor de câmera, explosão de brilhos e trovões (como o Self Destruction).

enum Style { NUMBERS, DRAGON }

const PINK := Color(1.0, 0.10, 0.60)
const PINK_LIGHT := Color(1.0, 0.65, 0.85)
const PINK_HOT := Color(1.0, 0.35, 0.75)
const PURPLE := Color(0.72, 0.20, 1.0)
const PURPLE_DEEP := Color(0.35, 0.05, 0.55)
const BLACK := Color(0.05, 0.0, 0.05)
const WHITE := Color(1.0, 0.95, 1.0)

var style: Style = Style.NUMBERS
var target: Node2D
var duration: float = 2.0
var radius: float = 44.0
var dragon_width: float = 66.0

var _age: float = 0.0
var _redraw_acc: float = 0.0
var _segments: Array = []
var _head_angle: float = 0.0
var _particles: CPUParticles2D
var _embers: CPUParticles2D
var _soft_tex: GradientTexture2D
var _shake_tween: Tween
var _shake_cam: Camera2D
var _shake_rest: Vector2 = Vector2.ZERO


# ---------- CRIAÇÃO ----------

static func attach_numbers(to: Node2D, seconds: float = 2.6, rad: float = 44.0) -> CarnivalFX:
	if to == null:
		return null
	var fx := CarnivalFX.new()
	fx.style = Style.NUMBERS
	fx.target = to
	fx.duration = seconds
	fx.radius = rad
	fx.z_index = 3000
	fx.z_as_relative = false
	to.add_child(fx)
	fx.top_level = true
	fx.global_position = fx._target_center(to)
	return fx


static func attach_dragon(ball: Ball, seconds: float = 2.6) -> CarnivalFX:
	if ball == null:
		return null
	var fx := CarnivalFX.new()
	fx.style = Style.DRAGON
	fx.target = ball
	fx.duration = seconds
	fx.z_index = 3000
	fx.z_as_relative = false
	ball.get_parent().add_child(fx)
	fx.global_position = fx._target_center(ball)
	return fx


func _ready() -> void:
	if style == Style.DRAGON:
		_setup_dragon_fx()
		_impact_burst.call_deferred()
	else:
		_setup_numbers_fx()


func _setup_numbers_fx() -> void:
	_particles = _make_particles(28, PINK, 90.0, 0.85)
	add_child(_particles)
	_particles.emitting = true


func _setup_dragon_fx() -> void:
	_particles = _make_particles(70, PINK_LIGHT, 200.0, 0.9)
	add_child(_particles)
	_particles.emitting = true
	_embers = _make_particles(40, PINK_HOT, 140.0, 0.7)
	_embers.direction = Vector2(0.0, -1.0)
	_embers.spread = 90.0
	_embers.gravity = Vector2(0.0, -80.0)
	add_child(_embers)
	_embers.emitting = true


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
	p.emission_sphere_radius = 34.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.2
	p.damping_max = speed * 1.2
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


# ---------- IMPACTO (só no dragão) ----------

func _impact_burst() -> void:
	if not is_inside_tree():
		return
	_spawn_flash(Color(1.0, 0.7, 0.9, 0.80), 0.55)
	_spawn_flash(Color(1.0, 0.2, 0.7, 0.55), 0.80)
	_shake_camera(30.0, 1.1)
	_spawn_sparkle_burst(70, PINK_LIGHT, 420.0, 0.95)
	_spawn_sparkle_burst(40, PURPLE, 280.0, 0.85)
	_spawn_sparkle_burst(24, WHITE, 220.0, 0.65)
	for i in 7:
		_spawn_bolt()


func _process(delta: float) -> void:
	_age += delta
	if _age > duration:
		if _particles:
			_particles.emitting = false
		if _embers:
			_embers.emitting = false
		queue_free()
		return

	if style == Style.NUMBERS:
		if is_instance_valid(target):
			global_position = _target_center(target)
	else:
		_update_dragon(delta)

	_redraw_acc += delta
	if _redraw_acc >= 0.04:
		_redraw_acc = 0.0
		queue_redraw()


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


# ---------- UTIL: flash, shake, brilho, trovão ----------

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


func _shake_camera(strength: float, duration: float) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		if is_instance_valid(_shake_cam):
			_shake_cam.offset = _shake_rest
	_shake_cam = cam
	_shake_rest = cam.offset
	var steps: int = maxi(int(duration / 0.03), 2)
	_shake_tween = create_tween()
	for i in steps:
		var fade: float = 1.0 - float(i) / float(steps)
		var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * fade
		_shake_tween.tween_property(cam, "offset", _shake_rest + jitter, 0.03)
	_shake_tween.tween_property(cam, "offset", _shake_rest, 0.03)


func _spawn_sparkle_burst(amount: int, color: Color, speed: float, lifetime: float) -> void:
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
	p.global_position = global_position
	p.emitting = true
	get_tree().create_timer(lifetime + 0.6).timeout.connect(p.queue_free)


func _spawn_bolt() -> void:
	var bolt := _Bolt.new()
	add_child(bolt)
	bolt.z_as_relative = false
	bolt.z_index = 3002
	bolt.position = Vector2.ZERO


# ---------- DRAGON: update ----------

func _update_dragon(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	var head: Vector2 = _target_center(target)
	_segments.push_front({"pos": head, "age": 0.0})
	for s in _segments:
		s["age"] += delta
	while _segments.size() > 0 and float(_segments[_segments.size() - 1]["age"]) > 1.2:
		_segments.pop_back()
	while _segments.size() > 46:
		_segments.pop_back()
	if target is Ball:
		var b: Ball = target
		if b.velocity.length() > 40.0:
			_head_angle = b.velocity.angle()
	if _particles:
		_particles.position = head - global_position
	if _embers:
		_embers.position = head - global_position


# ---------- DRAW ----------

func _draw() -> void:
	if style == Style.NUMBERS:
		_draw_numbers()
	else:
		_draw_dragon()


# ---------- NUMBERS ----------

func _draw_numbers() -> void:
	var alpha: float = 1.0
	if _age > duration - 0.5:
		alpha = clampf((duration - _age) / 0.5, 0.0, 1.0)

	# Aura de fundo (4 camadas rosa)
	var pulse: float = 0.5 + 0.5 * sin(_age * 5.0)
	for i in 4:
		draw_circle(Vector2.ZERO, radius + 26.0 - float(i) * 8.0,
			Color(PINK, (0.07 + 0.03 * pulse) * (1.0 - float(i) * 0.2) * alpha))

	# Anel externo: 24 números girando devagar
	var count_outer: int = 24
	var spin_outer: float = _age * 1.6
	for i in count_outer:
		var ang: float = spin_outer + TAU * float(i) / float(count_outer)
		var rad: float = radius + 22.0 + sin(_age * 3.5 + float(i) * 0.7) * 8.0
		var pos := Vector2(cos(ang) * rad, sin(ang) * rad * 0.75)
		var digit: int = absi(int(sin(float(i) * 78.233 + floor(_age * 2.0)) * 43758.5453)) % 10
		var sz: int = 18 + (i % 3) * 3
		_draw_number(pos, str(digit), sz, alpha, i % 2 == 0)

	# Anel interno: 20 números girando ao contrário
	var count_inner: int = 20
	var spin_inner: float = -_age * 2.0
	for i in count_inner:
		var ang: float = spin_inner + TAU * float(i) / float(count_inner)
		var rad: float = radius * 0.7 + sin(_age * 2.7 + float(i) * 1.3) * 5.0
		var pos := Vector2(cos(ang) * rad, sin(ang) * rad * 0.75)
		var digit: int = absi(int(sin(float(i) * 91.123 + floor(_age * 3.0)) * 12879.538)) % 10
		var sz: int = 14 + (i % 3) * 2
		_draw_number(pos, str(digit), sz, alpha * 0.9, i % 3 == 0)

	# Números que voam para fora e sobem
	var count_float: int = 14
	for i in count_float:
		var t: float = fposmod(_age * 0.9 + float(i) * 0.13, 1.0)
		var ang: float = TAU * float(i) / float(count_float) + _age * 0.5
		var rad: float = radius * (0.4 + t * 1.3)
		var pos := Vector2(cos(ang) * rad, sin(ang) * rad * 0.75 - t * 55.0)
		var digit: int = absi(int(sin(float(i) * 45.789 + floor(_age * 4.0)) * 33451.12)) % 10
		_draw_number(pos, str(digit), 14, alpha * (1.0 - t), i % 2 == 0)

	# Números que caem por baixo
	var count_fall: int = 8
	for i in count_fall:
		var t: float = fposmod(_age * 0.7 + float(i) * 0.19, 1.0)
		var x: float = (-1.0 + 2.0 * float(i) / float(count_fall - 1)) * radius * 1.1
		var pos := Vector2(x, radius * 0.5 + t * 45.0)
		var digit: int = absi(int(sin(float(i) * 63.17 + floor(_age * 3.0)) * 89123.7)) % 10
		_draw_number(pos, str(digit), 13, alpha * (1.0 - t), i % 3 == 0)

	# Anéis de contorno
	draw_arc(Vector2.ZERO, radius + 30.0, 0.0, TAU, 64, Color(PINK, 0.55 * alpha), 3.5)
	draw_arc(Vector2.ZERO, radius + 30.0, 0.0, TAU, 64, Color(BLACK, 0.70 * alpha), 1.5)
	draw_arc(Vector2.ZERO, radius * 0.85, 0.0, TAU, 64, Color(PURPLE, 0.50 * alpha), 2.5)
	draw_arc(Vector2.ZERO, radius * 0.85, 0.0, TAU, 64, Color(BLACK, 0.50 * alpha), 1.0)

	# Braços de energia girando (4 pontas brilhando)
	for i in 4:
		var ang: float = _age * 1.2 + TAU * float(i) / 4.0
		var tip: Vector2 = Vector2(cos(ang) * (radius + 36.0), sin(ang) * (radius + 36.0) * 0.75)
		draw_line(Vector2.ZERO, tip, Color(PINK, 0.25 * alpha), 3.0)
		draw_circle(tip, 4.5, Color(PINK_LIGHT, 0.9 * alpha))
		draw_arc(tip, 4.5, 0.0, TAU, 12, Color(BLACK, 0.55 * alpha), 1.2)


func _draw_number(pos: Vector2, txt: String, size: int, alpha: float, is_pink: bool) -> void:
	var w: float = 20.0
	# Contorno preto grosso
	draw_string_outline(ThemeDB.fallback_font, pos - Vector2(w * 0.5, 0.0), txt,
		HORIZONTAL_ALIGNMENT_CENTER, w, size, 6, Color(BLACK, alpha))
	# Preenchimento rosa (alterna entre PINK e PINK_LIGHT)
	var col: Color = PINK if is_pink else PINK_LIGHT
	draw_string(ThemeDB.fallback_font, pos - Vector2(w * 0.5, 0.0), txt,
		HORIZONTAL_ALIGNMENT_CENTER, w, size, Color(col, alpha))


# ---------- DRAGON: draw ----------

func _draw_dragon() -> void:
	if _segments.size() < 4:
		return
	var alpha: float = 1.0
	if _age > duration - 0.6:
		alpha = clampf((duration - _age) / 0.6, 0.0, 1.0)

	var pts: Array[Vector2] = []
	for s in _segments:
		pts.append(to_local(Vector2(s["pos"])))
	var n: int = pts.size()

	# ---------- AURA de fundo ao longo do corpo ----------
	for i in range(0, n, 4):
		var t: float = float(i) / float(n - 1)
		var w: float = dragon_width * (1.0 - t * 0.85)
		var col: Color = PINK.lerp(PURPLE, t)
		draw_circle(pts[i], w * 1.5, Color(col, 0.10 * alpha))

	# ---------- SOMBRA (deslocada pra baixo) ----------
	var shadow_off := Vector2(0.0, 8.0)
	for i in range(n - 1):
		var t: float = float(i) / float(n - 1)
		var w: float = dragon_width * (1.0 - t * 0.85)
		draw_line(pts[i] + shadow_off, pts[i + 1] + shadow_off,
			Color(0.0, 0.0, 0.0, 0.35 * alpha), w + 6.0)

	# ---------- ESPINHOS DORSAIS (antes do corpo) ----------
	for i in range(2, n - 2, 3):
		var t: float = float(i) / float(n - 1)
		var w: float = dragon_width * (1.0 - t * 0.85)
		var dir: Vector2 = (pts[i + 1] - pts[i - 1]).normalized()
		var perp := dir.orthogonal()
		var spike_h: float = w * (0.55 + 0.15 * sin(_age * 4.0 + float(i) * 0.7))
		var base_a: Vector2 = pts[i] + perp * w * 0.65
		var base_b: Vector2 = pts[i] + perp * w * 0.65 + dir * 6.0
		var tip: Vector2 = pts[i] + perp * (w * 0.65 + spike_h)
		var tri := PackedVector2Array([base_a, tip, base_b])
		draw_colored_polygon(tri, Color(PURPLE_DEEP, 0.9 * alpha))
		var tl := tri.duplicate()
		tl.append(tri[0])
		draw_polyline(tl, Color(BLACK, 0.95 * alpha), 1.5)
		draw_circle(tip, 1.6, Color(PINK_LIGHT, 0.95 * alpha))

	# ---------- CORPO: contorno preto ----------
	for i in range(n - 1):
		var t: float = float(i) / float(n - 1)
		var w: float = dragon_width * (1.0 - t * 0.85)
		draw_line(pts[i], pts[i + 1], Color(BLACK, 0.92 * alpha), w + 10.0)
		draw_circle(pts[i], (w + 10.0) * 0.5, Color(BLACK, 0.92 * alpha))

	# Preenchimento
	for i in range(n - 1):
		var t: float = float(i) / float(n - 1)
		var w: float = dragon_width * (1.0 - t * 0.85)
		var col: Color = PINK.lerp(PURPLE, t)
		draw_line(pts[i], pts[i + 1], Color(col, 0.93 * alpha), w)
		draw_circle(pts[i], w * 0.5, Color(col, 0.93 * alpha))

	# Highlight central
	for i in range(n - 1):
		var t: float = float(i) / float(n - 1)
		var w: float = dragon_width * (1.0 - t * 0.85)
		draw_line(pts[i], pts[i + 1], Color(WHITE, 0.32 * alpha), w * 0.25)

	# ---------- ESCAMAS (1 por segmento, com contorno) ----------
	for i in range(2, n - 2, 2):
		var t: float = float(i) / float(n - 1)
		var w: float = dragon_width * (1.0 - t * 0.85)
		var dir: Vector2 = (pts[i + 1] - pts[i - 1]).normalized()
		var perp := dir.orthogonal()
		var center: Vector2 = pts[i] - perp * w * 0.15
		var sc_size: float = w * 0.3
		var sc := PackedVector2Array([
			center + Vector2(0.0, -sc_size), center + dir * sc_size,
			center + Vector2(0.0, sc_size), center - dir * sc_size])
		draw_colored_polygon(sc, Color(PURPLE_DEEP, 0.6 * alpha))
		var scl := sc.duplicate()
		scl.append(sc[0])
		draw_polyline(scl, Color(BLACK, 0.85 * alpha), 1.0)
		draw_circle(center, 1.2, Color(PINK_LIGHT, 0.75 * alpha))

	# ---------- ASAS (atrás, batendo) ----------
	var wing_idx: int = clampi(int(float(n) * 0.35), 1, n - 2)
	var wing_anchor: Vector2 = pts[wing_idx]
	var wing_t: float = float(wing_idx) / float(n - 1)
	var wing_w: float = dragon_width * (1.0 - wing_t * 0.85)
	var wdir: Vector2 = (pts[wing_idx + 1] - pts[wing_idx]).normalized()
	var wperp := wdir.orthogonal()
	var flap: float = sin(_age * 8.0) * 0.15
	_draw_wing(wing_anchor, wdir, wperp, wing_w, flap, alpha)
	_draw_wing(wing_anchor, wdir, -wperp, wing_w, flap, alpha)

	# ---------- GARRAS (duas patas) ----------
	var leg1_idx: int = clampi(int(float(n) * 0.48), 1, n - 2)
	_draw_leg(pts[leg1_idx], (pts[leg1_idx + 1] - pts[leg1_idx]).normalized(),
		dragon_width * (1.0 - float(leg1_idx) / float(n - 1) * 0.85), alpha, 1.0)
	var leg2_idx: int = clampi(int(float(n) * 0.68), 1, n - 2)
	_draw_leg(pts[leg2_idx], (pts[leg2_idx + 1] - pts[leg2_idx]).normalized(),
		dragon_width * (1.0 - float(leg2_idx) / float(n - 1) * 0.85), alpha, -1.0)

	# ---------- CABEÇA ----------
	if n >= 2:
		_draw_dragon_head(pts[0], _head_angle, alpha)

	# ---------- CAUDA ----------
	if n >= 2:
		_draw_dragon_tail(pts[n - 1], pts[n - 2], alpha)


func _draw_wing(anchor: Vector2, dir: Vector2, perp: Vector2, w: float, flap: float, alpha: float) -> void:
	var wing_len: float = w * 3.2
	var wing_width: float = w * 1.6
	var tip: Vector2 = anchor + perp * wing_len * (1.0 + flap) + dir * wing_width * 0.5
	var base1: Vector2 = anchor + dir * wing_width * 0.3
	var base2: Vector2 = anchor - dir * wing_width * 0.3
	var tri := PackedVector2Array([base1, tip, base2])
	draw_colored_polygon(tri, Color(PINK, 0.35 * alpha))
	var tl := tri.duplicate()
	tl.append(tri[0])
	draw_polyline(tl, Color(BLACK, 0.9 * alpha), 2.5)
	draw_polyline(tl, Color(PINK_LIGHT, 0.55 * alpha), 1.0)
	for k in 3:
		var f: float = 0.3 + 0.25 * float(k)
		var nerve_end: Vector2 = base1.lerp(tip, f)
		draw_line(anchor, nerve_end, Color(BLACK, 0.75 * alpha), 1.5)
		draw_line(anchor, nerve_end, Color(PINK_LIGHT, 0.6 * alpha), 0.8)


func _draw_leg(anchor: Vector2, dir: Vector2, w: float, alpha: float, side: float) -> void:
	var perp := dir.orthogonal() * side
	var knee: Vector2 = anchor + perp * w * 1.0 + dir * (-w * 0.3)
	var foot: Vector2 = knee + perp * w * 1.2 + dir * (-w * 0.4)
	draw_line(anchor, knee, Color(BLACK, 0.9 * alpha), 14.0)
	draw_line(anchor, knee, Color(PINK, 0.9 * alpha), 10.0)
	draw_line(knee, foot, Color(BLACK, 0.9 * alpha), 10.0)
	draw_line(knee, foot, Color(PINK, 0.9 * alpha), 7.0)
	for k in 3:
		var claw_dir: Vector2 = perp.rotated(deg_to_rad(-40.0 + 40.0 * float(k)))
		var claw_tip: Vector2 = foot + claw_dir * w * 0.55
		draw_line(foot, claw_tip, Color(BLACK, 0.9 * alpha), 5.0)
		draw_line(foot, claw_tip, Color(PINK, 0.9 * alpha), 3.0)
		draw_circle(claw_tip, 2.0, Color(BLACK, 0.9 * alpha))
		draw_circle(claw_tip, 1.2, Color(WHITE, 0.95 * alpha))


func _draw_dragon_tail(tip: Vector2, prev: Vector2, alpha: float) -> void:
	var tdir: Vector2 = (tip - prev).normalized()
	var side: Vector2 = tdir.orthogonal()
	var tail_len: float = 90.0
	var tail_tip: Vector2 = tip + tdir * tail_len
	# Chama final
	var flame := PackedVector2Array([
		tip - side * 14.0, tail_tip + side * 10.0, tail_tip - side * 10.0, tip + side * 14.0])
	draw_colored_polygon(flame, Color(PURPLE, 0.85 * alpha))
	var fline := flame.duplicate()
	fline.append(flame[0])
	draw_polyline(fline, Color(BLACK, 0.9 * alpha), 2.5)
	# Espinho da ponta
	var tail_spike: Vector2 = tip + tdir * (tail_len + 22.0)
	var tri := PackedVector2Array([tip + side * 8.0, tail_spike, tip - side * 8.0])
	draw_colored_polygon(tri, Color(PURPLE_DEEP, 0.9 * alpha))
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(BLACK, 0.95 * alpha), 2.0)
	draw_circle(tail_spike, 3.2, Color(PINK_LIGHT, 0.9 * alpha))


func _draw_dragon_head(pos: Vector2, ang: float, alpha: float) -> void:
	draw_set_transform(pos, ang, Vector2.ONE * 1.6)

	# ---------- AURA ----------
	for i in 3:
		draw_circle(Vector2(10.0, 0.0), 50.0 - float(i) * 8.0,
			Color(PINK, (0.10 - float(i) * 0.03) * alpha))

	# ---------- SOPRO DE FOGO (à frente da boca) ----------
	var breath: float = 0.7 + 0.3 * sin(_age * 8.0)
	for i in 4:
		var x: float = 48.0 + float(i) * 14.0
		var r: float = (10.0 - float(i) * 2.0) * breath
		draw_circle(Vector2(x, 0.0), r, Color(1.0, 0.6, 0.9, (0.6 - float(i) * 0.12) * alpha))
	for i in 3:
		var x: float = 52.0 + float(i) * 16.0
		draw_circle(Vector2(x, randf_range(-3.0, 3.0)), 3.0, Color(WHITE, 0.9 * alpha))

	# ---------- CHIFRES (curvos, com contorno) ----------
	for sgn in [-1.0, 1.0]:
		var s: float = float(sgn)
		var horn := PackedVector2Array()
		for k in 12:
			var u: float = float(k) / 11.0
			horn.append(Vector2(-8.0 - 44.0 * u, s * (-18.0 - 34.0 * u + 26.0 * u * u)))
		draw_polyline(horn, Color(BLACK, 0.95 * alpha), 9.0)
		draw_polyline(horn, Color(PURPLE, 0.95 * alpha), 6.0)
		draw_polyline(horn, Color(PINK_LIGHT, 0.6 * alpha), 2.0)
		draw_circle(horn[horn.size() - 1], 3.2, Color(WHITE, 0.95 * alpha))

	# ---------- CRISTA / ORBE na testa ----------
	draw_circle(Vector2(6.0, 0.0), 6.0, Color(PURPLE_DEEP, 0.9 * alpha))
	draw_circle(Vector2(6.0, 0.0), 4.0, Color(PINK, 0.95 * alpha))
	draw_circle(Vector2(6.0, 0.0), 2.0, Color(WHITE, 0.95 * alpha))

	# ---------- CRÂNIO ----------
	var head := PackedVector2Array([
		Vector2(-16.0, -26.0), Vector2(14.0, -30.0), Vector2(38.0, -20.0),
		Vector2(52.0, -6.0), Vector2(54.0, 8.0), Vector2(38.0, 22.0),
		Vector2(14.0, 30.0), Vector2(-16.0, 26.0), Vector2(-24.0, 0.0)])
	draw_colored_polygon(head, Color(PINK, 0.85 * alpha))
	var hline := head.duplicate()
	hline.append(head[0])
	draw_polyline(hline, Color(BLACK, 0.95 * alpha), 4.0)
	draw_polyline(hline, Color(PINK_LIGHT, 0.5 * alpha), 1.5)

	# ---------- MANDÍBULA ----------
	var jaw := PackedVector2Array([
		Vector2(4.0, 18.0), Vector2(44.0, 14.0), Vector2(56.0, 24.0),
		Vector2(42.0, 36.0), Vector2(10.0, 32.0)])
	draw_colored_polygon(jaw, Color(PURPLE, 0.9 * alpha))
	var jline := jaw.duplicate()
	jline.append(jaw[0])
	draw_polyline(jline, Color(BLACK, 0.95 * alpha), 3.0)

	# ---------- DENTES ----------
	for i in 8:
		var dx: float = 8.0 + float(i) * 5.0
		var th: float = 8.0 + 3.0 * sin(float(i) * 1.3)
		var tri := PackedVector2Array([
			Vector2(dx, 16.0), Vector2(dx + 5.0, 16.0), Vector2(dx + 2.5, 16.0 + th)])
		draw_colored_polygon(tri, Color(WHITE, 0.98 * alpha))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]),
			Color(BLACK, 0.9 * alpha), 1.2)
	for i in 6:
		var dx: float = 14.0 + float(i) * 5.5
		var th: float = 6.0 + 2.0 * sin(float(i) * 1.7)
		var tri := PackedVector2Array([
			Vector2(dx, 28.0), Vector2(dx + 5.0, 28.0), Vector2(dx + 2.5, 28.0 - th)])
		draw_colored_polygon(tri, Color(WHITE, 0.98 * alpha))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]),
			Color(BLACK, 0.9 * alpha), 1.2)

	# ---------- OLHOS ----------
	_draw_eye(Vector2(16.0, -8.0), 9.0, 6.0, alpha)
	_draw_eye(Vector2(34.0, -4.0), 6.0, 4.0, alpha)

	# ---------- BIGODES ----------
	for sgn in [-1.0, 1.0]:
		var s: float = float(sgn)
		var whisker := PackedVector2Array()
		for k in 8:
			var u: float = float(k) / 7.0
			whisker.append(Vector2(42.0 + 34.0 * u, s * (6.0 + 26.0 * u - 12.0 * u * u)))
		draw_polyline(whisker, Color(BLACK, 0.9 * alpha), 4.5)
		draw_polyline(whisker, Color(PINK_LIGHT, 0.95 * alpha), 2.0)
		draw_circle(whisker[whisker.size() - 1], 2.5, Color(WHITE, 0.9 * alpha))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_eye(pos: Vector2, w: float, h: float, alpha: float) -> void:
	var pts := PackedVector2Array([
		pos + Vector2(-w, 0.0), pos + Vector2(0.0, -h),
		pos + Vector2(w, 0.0), pos + Vector2(0.0, h)])
	draw_colored_polygon(pts, Color(WHITE, 0.98 * alpha))
	var line := pts.duplicate()
	line.append(pts[0])
	draw_polyline(line, Color(BLACK, 0.95 * alpha), 2.5)
	draw_circle(pos, w * 0.35, Color(PINK, 0.95 * alpha))
	draw_line(pos + Vector2(0.0, -h * 0.6), pos + Vector2(0.0, h * 0.6),
		Color(PINK_HOT, 0.95 * alpha), w * 0.25)
	draw_circle(pos + Vector2(-w * 0.2, -h * 0.2), 1.5, Color(WHITE, 0.98 * alpha))


# ---------- BOLT (raio) ----------

class _Bolt extends Node2D:
	var life: float = 0.35
	var _t: float = 0.0
	var _pts: Array = []

	func _ready() -> void:
		var base_ang: float = randf_range(0.0, TAU)
		var length: float = randf_range(180.0, 340.0)
		var dir: Vector2 = Vector2.from_angle(base_ang)
		var perp: Vector2 = dir.orthogonal()
		var n: int = 9
		for i in range(n + 1):
			var f: float = float(i) / float(n)
			var off: float = 0.0 if i == 0 else randf_range(-42.0, 42.0)
			_pts.append(dir * length * f + perp * off)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var a: float = 1.0 - _t / life
		var pts := PackedVector2Array()
		for p in _pts:
			pts.append(p)
		draw_polyline(pts, Color(0.0, 0.0, 0.0, a * 0.9), 7.0)
		draw_polyline(pts, Color(PINK, a * 0.95), 3.5)
		draw_polyline(pts, Color(WHITE, a * 0.8), 1.5)
