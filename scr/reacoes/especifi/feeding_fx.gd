class_name FeedingFX
extends Node2D
## Efeitos visuais da reação FEEDING (Lorenzo + Barou). TUDO é desenhado por código: não usa imagens.
## Os dois efeitos são filhos da BOLA, então seguem ela por onde ela for.
##
##  - PASS: brilho roxo em volta da bola + um zumbi roxo (só silhueta) que acompanha o Undead Pass.
##  - LION: um leão simples, vermelho com contorno preto e meio translúcido, rugindo em cima da bola
##    (chute do Devour), com raios vermelhos de contorno preto saindo da bola.
##
## Como usar (de fora, só estas duas linhas):
##   var fx := FeedingFX.attach_to_ball(ball)       # antes do passe; chame fx.finish() quando o passe acabar
##   FeedingFX.attach_lion(ball, 1.7, 110.0)        # no momento do chute; some sozinho

enum Mode { PASS, LION }
enum Phase { ARMED, ACTIVE, FADING }

const PURPLE := Color(0.62, 0.25, 0.95)
const PURPLE_LIGHT := Color(0.82, 0.62, 1.0)
const LION_RED := Color(0.85, 0.06, 0.06)
const LION_BLACK := Color(0.05, 0.0, 0.0)

var mode: Mode = Mode.PASS
var duration: float = 1.7          # LION: quanto tempo o leão fica
var lion_radius: float = 110.0     # LION: raio do rosto, em px (sem a juba)
var lion_opacity: float = 0.6      # LION: 1 = sólido, menor = mais translúcido
var bolt_count: int = 7            # LION: quantos raios saem da bola
var zombie_scale: float = 1.0      # PASS: tamanho do zumbi (1.0 = cerca de 150 px de altura)

var _ball: Ball = null
var _phase: Phase = Phase.ARMED
var _touches0: int = 0
var _t: float = 0.0
var _fade: float = 0.0
var _face_dir: float = 1.0


# ---------- CRIAÇÃO ----------

## Zumbi + brilho acompanhando a bola. Fica invisível até a bola sair no passe.
## Quem chamou deve chamar finish() quando o passe acabar.
static func attach_to_ball(ball: Ball) -> FeedingFX:
	if ball == null:
		return null
	var fx := FeedingFX.new()
	fx.mode = Mode.PASS
	fx._ball = ball
	fx._touches0 = ball.interaction_count
	fx.z_index = 30
	ball.add_child(fx)
	return fx


## Leão em cima da bola: acompanha ela e some depois de "lion_duration" segundos
static func attach_lion(ball: Ball, lion_duration: float = 1.7, radius: float = 110.0) -> FeedingFX:
	if ball == null:
		return null
	var fx := FeedingFX.new()
	fx.mode = Mode.LION
	fx._ball = ball
	fx.duration = lion_duration
	fx.lion_radius = radius
	fx.z_index = 30
	ball.add_child(fx)
	return fx


## O passe acabou: o zumbi esmaece e some
func finish() -> void:
	if mode != Mode.PASS:
		return
	if _phase == Phase.ARMED:
		queue_free()   # a bola nem chegou a sair
	else:
		_phase = Phase.FADING


# ---------- LOOP ----------

func _ready() -> void:
	if mode == Mode.PASS:
		# Mistura aditiva = tudo "brilha"
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat


func _process(delta: float) -> void:
	_t += delta
	if _ball == null or not is_instance_valid(_ball):
		queue_free()
		return
	if mode == Mode.LION:
		if _t >= duration:
			queue_free()
			return
	else:
		_update_pass(delta)
		if is_queued_for_deletion():
			return
	queue_redraw()


func _update_pass(delta: float) -> void:
	match _phase:
		Phase.ARMED:
			# Começa quando a bola sai (alguém tocou nela ou ela ganhou velocidade)
			if _ball.interaction_count != _touches0 or _ball.velocity.length() > 30.0:
				_phase = Phase.ACTIVE
				_t = 0.0
		Phase.ACTIVE:
			_fade = minf(1.0, _fade + delta * 5.0)
			if _t > 6.0:
				finish()   # trava de segurança
		Phase.FADING:
			_fade -= delta * 2.5
			if _fade <= 0.0:
				queue_free()
				return
	if absf(_ball.velocity.x) > 10.0:
		_face_dir = signf(_ball.velocity.x)


func _draw() -> void:
	if _ball == null or not is_instance_valid(_ball):
		return
	if mode == Mode.PASS:
		if _phase != Phase.ARMED:
			_draw_pass()
	else:
		_draw_lion()


## Centro visual da bola (ela sobe na tela conforme a altura)
func _ball_center() -> Vector2:
	return Vector2(0.0, -_ball.height - _ball.ball_radius)


# ---------- PASS: BRILHO + ZUMBI ROXO (SÓ SILHUETA) ----------

func _draw_pass() -> void:
	var a: float = _fade
	var base: Vector2 = _ball_center()
	var pulse: float = 0.5 + 0.5 * sin(_t * 12.0)

	# Brilho roxo pulsando em volta da bola
	for i in 6:
		var k: float = float(i) / 6.0
		draw_circle(base, 16.0 + float(i) * 8.0 + pulse * 4.0,
			Color(PURPLE.r, PURPLE.g, PURPLE.b, (0.28 - k * 0.22) * a))
	draw_arc(base, 20.0 + pulse * 4.0, 0.0, TAU, 32, Color(PURPLE_LIGHT.r, PURPLE_LIGHT.g, PURPLE_LIGHT.b, 0.9 * a), 3.0)

	# Zumbi, olhando para onde a bola vai
	draw_set_transform(base + Vector2(0.0, -6.0), 0.0, Vector2(_face_dir * zombie_scale, zombie_scale))
	_draw_zombie(a)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Silhueta de um zumbi "ganancioso": corcunda, cabeça jogada para a frente e os dois braços
## esticados com garras, atrás da bola. Uma cor só (roxo), sem rosto nem detalhes.
## A origem é a bola; ele olha para +x (o transform acima espelha se precisar).
func _draw_zombie(a: float) -> void:
	var sway: float = sin(_t * 6.0)
	var bob: float = sin(_t * 4.0) * 4.0
	var fill := Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.40 * a)
	var edge := Color(PURPLE_LIGHT.r, PURPLE_LIGHT.g, PURPLE_LIGHT.b, 0.70 * a)

	# Tronco curvado (a barra de baixo é rasgada)
	var torso := PackedVector2Array([
		Vector2(-30.0, -84.0 + bob), Vector2(-10.0, -104.0 + bob), Vector2(18.0, -100.0 + bob),
		Vector2(30.0, -80.0 + bob), Vector2(22.0, -40.0 + bob), Vector2(12.0, -26.0 + bob),
		Vector2(4.0, -42.0 + bob), Vector2(-4.0, -24.0 + bob), Vector2(-12.0, -42.0 + bob),
		Vector2(-24.0, -34.0 + bob)])
	draw_colored_polygon(torso, fill)
	var torso_line := torso.duplicate()
	torso_line.append(torso[0])
	draw_polyline(torso_line, edge, 2.0)

	# Cabeça jogada para a frente (faminta)
	var head := Vector2(32.0, -112.0 + bob)
	draw_circle(head, 20.0, fill)
	draw_arc(head, 20.0, 0.0, TAU, 28, edge, 2.0)

	# Dois braços longos esticados para a bola, com garras
	var arm_a := PackedVector2Array([Vector2(14.0, -98.0 + bob), Vector2(60.0, -90.0 + bob + sway * 6.0),
		Vector2(104.0, -96.0 + bob - sway * 6.0)])
	var arm_b := PackedVector2Array([Vector2(10.0, -90.0 + bob), Vector2(52.0, -72.0 + bob - sway * 5.0),
		Vector2(92.0, -80.0 + bob + sway * 5.0)])
	for arm in [arm_a, arm_b]:
		draw_polyline(arm, fill, 11.0)
		draw_polyline(arm, edge, 2.0)
		var hand: Vector2 = arm[2]
		for c in 3:
			var ang: float = deg_to_rad(-25.0 + float(c) * 25.0)
			draw_line(hand, hand + Vector2.from_angle(ang) * 16.0, edge, 3.0)


# ---------- LION: LEÃO SIMPLES, VERMELHO COM CONTORNO PRETO ----------

func _draw_lion() -> void:
	var p: float = clampf(_t / duration, 0.0, 1.0)
	var appear: float = clampf(_t / 0.2, 0.0, 1.0)
	var a: float = 1.0 - clampf((p - 0.75) / 0.25, 0.0, 1.0)      # some no fim
	var r: float = lion_radius * lerpf(0.4, 1.0, _back_out(appear))   # "estoura" ao aparecer
	var line_w: float = maxf(2.0, r * 0.06)
	var red: Color = _with_a(LION_RED, a * lion_opacity)
	var black: Color = _with_a(LION_BLACK, a * minf(1.0, lion_opacity + 0.2))   # contorno um pouco mais forte

	# Tudo fica centrado na bola; um tremorzinho deixa o rugido mais forte
	var shake := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 3.0 * (1.0 - p)
	draw_set_transform(_ball_center() + shake, 0.0, Vector2.ONE)

	# Raios vermelhos com contorno preto saindo da bola (mudam de forma todo frame, como os do Predator Eye).
	# São desenhados primeiro: ficam atrás do leão e aparecem além da juba.
	var bolt_alpha: float = a * minf(1.0, lion_opacity + 0.2)
	for i in bolt_count:
		var bolt_ang: float = TAU * float(i) / float(bolt_count) + randf() * 0.4
		_draw_bolt(bolt_ang, r * (1.6 + randf() * 0.7), line_w, bolt_alpha)

	# Juba: espetos vermelhos com contorno preto
	var spikes: int = 18
	var step: float = TAU / float(spikes)
	for i in spikes:
		var ang: float = step * float(i)
		var wob: float = 1.0 + 0.07 * sin(_t * 18.0 + float(i) * 1.7)
		var half: float = step * 0.6
		var pts := PackedVector2Array([
			Vector2.from_angle(ang - half) * 0.6 * r,
			Vector2.from_angle(ang) * 1.25 * r * wob,
			Vector2.from_angle(ang + half) * 0.6 * r])
		draw_colored_polygon(pts, red)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, black, line_w)

	# Orelhas
	for sx in [-1.0, 1.0]:
		var ear := Vector2(sx * 0.5 * r, -0.55 * r)
		draw_circle(ear, 0.18 * r, red)
		draw_arc(ear, 0.18 * r, 0.0, TAU, 16, black, line_w)

	# Rosto
	draw_circle(Vector2.ZERO, 0.62 * r, red)
	draw_arc(Vector2.ZERO, 0.62 * r, 0.0, TAU, 40, black, line_w * 1.4)

	# Olhos: vermelhos com contorno preto + sobrancelha brava (preto)
	for sx in [-1.0, 1.0]:
		var ec := Vector2(sx * 0.25 * r, -0.12 * r)
		var eye := PackedVector2Array([
			ec + Vector2(-sx * 0.12 * r, 0.05 * r), ec + Vector2(0.0, -0.08 * r),
			ec + Vector2(sx * 0.14 * r, -0.04 * r), ec + Vector2(0.0, 0.06 * r)])
		draw_colored_polygon(eye, red)
		var eye_line := eye.duplicate()
		eye_line.append(eye[0])
		draw_polyline(eye_line, black, line_w)
		draw_line(ec + Vector2(-sx * 0.18 * r, -0.07 * r), ec + Vector2(sx * 0.2 * r, -0.2 * r), black, line_w * 1.6)

	# Nariz e focinho (preto)
	draw_colored_polygon(PackedVector2Array([Vector2(-0.09 * r, 0.03 * r), Vector2(0.09 * r, 0.03 * r),
		Vector2(0.0, 0.12 * r)]), black)
	draw_line(Vector2(0.0, 0.12 * r), Vector2(0.0, 0.2 * r), black, line_w)

	# Boca rugindo (abre e fecha): cavidade preta com presas vermelhas
	var open: float = clampf(0.55 + 0.45 * sin(_t * 16.0), 0.2, 1.0)
	var m_top: float = 0.2 * r
	var m_w: float = 0.3 * r
	var depth: float = (0.1 + 0.28 * open) * r
	var mouth := PackedVector2Array()
	var n: int = 12
	for i in range(n + 1):
		var ang2: float = PI * float(i) / float(n)
		mouth.append(Vector2(cos(ang2) * m_w, m_top + sin(ang2) * depth))
	draw_colored_polygon(mouth, black)
	for sx in [-1.0, 1.0]:
		var fx_x: float = sx * 0.18 * r
		draw_colored_polygon(PackedVector2Array([Vector2(fx_x - 0.045 * r, m_top), Vector2(fx_x + 0.045 * r, m_top),
			Vector2(fx_x, m_top + 0.13 * r)]), red)

	# Ondas do rugido (pretas, finas)
	for k in 2:
		var f: float = fposmod(_t * 1.6 + float(k) * 0.5, 1.0)
		var wave_r: float = (0.5 + f * 0.8) * r
		draw_arc(Vector2(0.0, m_top + depth * 0.4), wave_r, deg_to_rad(40.0), deg_to_rad(140.0), 20,
			Color(LION_BLACK.r, LION_BLACK.g, LION_BLACK.b, (1.0 - f) * 0.8 * a), line_w)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Um raio em zig-zag saindo do centro (a bola): contorno preto grosso por baixo, vermelho por cima
func _draw_bolt(angle: float, length: float, width: float, alpha: float) -> void:
	var dir: Vector2 = Vector2.from_angle(angle)
	var perp: Vector2 = dir.orthogonal()
	var steps: int = 6
	var pts := PackedVector2Array()
	for s in range(steps + 1):
		var f: float = float(s) / float(steps)
		var off: float = 0.0 if s == 0 else (randf() - 0.5) * 0.22 * length   # o zig-zag
		pts.append(dir * length * f + perp * off)
	draw_polyline(pts, Color(LION_BLACK.r, LION_BLACK.g, LION_BLACK.b, alpha), width * 2.6)
	draw_polyline(pts, Color(LION_RED.r, LION_RED.g, LION_RED.b, alpha), width * 1.2)


func _with_a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)


## Curva "estoura e assenta" (easeOutBack)
static func _back_out(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
