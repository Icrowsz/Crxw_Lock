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
const PURPLE_DARK := Color(0.269, 0.036, 0.445, 1.0)
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


## Silhueta corcunda com coluna visível, braços musculosos, garras e órbitas brilhando.
## A origem é a bola; ele olha para +x (o transform acima espelha se precisar).
## Zumbi magrinho: coluna saliente, costelas aparecendo, feridas com carne exposta,
## cabeça jogada para frente com maxilar caído e braços ossudos.
func _draw_zombie(a: float) -> void:
	var sway: float = sin(_t * 6.0)
	var bob: float = sin(_t * 4.0) * 4.0
	var fill := Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.42 * a)
	var fill_deep := Color(PURPLE.darkened(0.3).r, PURPLE.darkened(0.3).g, PURPLE.darkened(0.3).b, 0.55 * a)
	var wound := Color(0.85, 0.15, 0.35, 0.55 * a)   # carne exposta
	var bone := Color(0.92, 0.88, 0.95, 0.65 * a)
	var edge := Color(PURPLE_LIGHT.r, PURPLE_LIGHT.g, PURPLE_LIGHT.b, 0.78 * a)

	# --- Coluna saliente (curvada) ---
	var spine := PackedVector2Array()
	for k in 8:
		var u: float = float(k) / 7.0
		var sx: float = -20.0 + 14.0 * u * u + sway * 2.0 * u
		var sy: float = -20.0 - 92.0 * u + bob
		spine.append(Vector2(sx, sy))
	draw_polyline(spine, edge, 2.5)

	# --- Torso magro e anguloso ---
	var torso := PackedVector2Array([
		Vector2(-24.0, -86.0 + bob), Vector2(-14.0, -106.0 + bob), Vector2(12.0, -104.0 + bob),
		Vector2(22.0, -84.0 + bob), Vector2(18.0, -60.0 + bob),
		Vector2(16.0, -44.0 + bob), Vector2(12.0, -24.0 + bob), Vector2(4.0, -36.0 + bob),
		Vector2(-2.0, -22.0 + bob), Vector2(-8.0, -38.0 + bob),
		Vector2(-16.0, -28.0 + bob), Vector2(-22.0, -46.0 + bob)])
	draw_colored_polygon(torso, fill)
	var torso_line := torso.duplicate()
	torso_line.append(torso[0])
	draw_polyline(torso_line, edge, 2.0)

	# --- Costelas aparecendo (arcos finos) ---
	for i in 3:
		var y: float = -84.0 + float(i) * 10.0 + bob
		draw_arc(Vector2(-2.0, y), 14.0 - float(i) * 2.0, PI * 1.05, PI * 1.85, 12,
			Color(edge.r, edge.g, edge.b, 0.55 * a), 1.5)

	# --- Feridas com carne exposta ---
	# Ferida no ombro esquerdo
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22.0, -80.0 + bob), Vector2(-16.0, -78.0 + bob),
		Vector2(-14.0, -72.0 + bob), Vector2(-20.0, -74.0 + bob)]), wound)
	# Ferida no abdômen (rasgo vertical)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-6.0, -60.0 + bob), Vector2(0.0, -58.0 + bob),
		Vector2(2.0, -44.0 + bob), Vector2(-2.0, -40.0 + bob),
		Vector2(-6.0, -46.0 + bob), Vector2(-8.0, -54.0 + bob)]), wound)
	# Ossinho aparecendo pela ferida do abdômen
	draw_line(Vector2(-4.0, -54.0 + bob), Vector2(-2.0, -44.0 + bob),
		Color(bone.r, bone.g, bone.b, 0.85 * a), 1.5)

	# --- Cabeça (sunken cheeks, maxilar caído) ---
	var head := Vector2(28.0, -110.0 + bob)
	draw_circle(head, 18.0, fill)
	draw_arc(head, 18.0, 0.0, TAU, 28, edge, 2.0)
	# Bochecha afundada (sombra interna)
	draw_circle(head + Vector2(6.0, 6.0), 4.0, Color(fill_deep.r, fill_deep.g, fill_deep.b, 0.7 * a))
	# Maxilar aberto (boca pendurada)
	var jaw := PackedVector2Array([
		head + Vector2(-4.0, 12.0), head + Vector2(12.0, 8.0),
		head + Vector2(10.0, 22.0), head + Vector2(-4.0, 22.0)])
	draw_colored_polygon(jaw, fill)
	draw_polyline(PackedVector2Array([jaw[0], jaw[1], jaw[2], jaw[3], jaw[0]]), edge, 1.5)
	# Dentes tortos visíveis na boca aberta
	draw_line(head + Vector2(-2.0, 14.0), head + Vector2(6.0, 13.0), bone, 1.5)
	draw_line(head + Vector2(0.0, 18.0), head + Vector2(8.0, 17.0), bone, 1.5)
	# Órbitas brilhando (pontinhos)
	draw_circle(head + Vector2(2.0, -5.0), 3.0,
		Color(PURPLE_LIGHT.r, PURPLE_LIGHT.g, PURPLE_LIGHT.b, 0.95 * a))
	draw_circle(head + Vector2(11.0, -4.0), 2.4,
		Color(PURPLE_LIGHT.r, PURPLE_LIGHT.g, PURPLE_LIGHT.b, 0.95 * a))
	# Ferida na testa
	draw_line(head + Vector2(-8.0, -12.0), head + Vector2(-2.0, -8.0), wound, 2.0)

	# --- Braços ossudos com garras ---
	_draw_zombie_arm(Vector2(12.0, -100.0 + bob), Vector2(56.0, -92.0 + bob + sway * 6.0),
		Vector2(102.0, -98.0 + bob - sway * 6.0), fill, edge, wound)
	_draw_zombie_arm(Vector2(6.0, -90.0 + bob), Vector2(48.0, -74.0 + bob - sway * 5.0),
		Vector2(92.0, -82.0 + bob + sway * 5.0), fill, edge, wound)

## Braço do zumbi: cotovelo marcado, antebraço afunilando, mão com 4 garras
func _draw_zombie_arm(start: Vector2, mid: Vector2, hand: Vector2,
		fill: Color, edge: Color, wound: Color) -> void:
	# Braço afunilado (ombro mais grosso, pulso fino) - desenha em segmentos
	draw_polyline(PackedVector2Array([start, mid, hand]), fill, 9.0)
	draw_polyline(PackedVector2Array([start, mid, hand]), edge, 2.0)
	# Cotovelo marcado
	draw_arc(mid, 5.0, 0.0, PI, 8, edge, 1.5)
	# Marca de ferida no antebraço
	draw_line(mid.lerp(hand, 0.5) + Vector2(-3.0, -3.0),
		mid.lerp(hand, 0.5) + Vector2(3.0, 3.0), wound, 2.0)
	# Mão com 4 dedos longos e garras
	draw_circle(hand, 5.0, fill)
	draw_arc(hand, 5.0, 0.0, TAU, 12, edge, 1.5)
	for c in 4:
		var ang: float = deg_to_rad(-45.0 + float(c) * 28.0)
		var knuckle: Vector2 = hand + Vector2.from_angle(ang) * 8.0
		var tip: Vector2 = knuckle + Vector2.from_angle(ang) * 10.0
		draw_line(hand, knuckle, fill, 3.5)
		draw_line(knuckle, tip, fill, 2.5)
		draw_line(hand, knuckle, edge, 1.0)
		draw_line(knuckle, tip, edge, 1.0)
		draw_circle(tip, 1.3, edge)

## Leão: juba em CAMADAS (raios longos por fora + pelagem curta por dentro), orelhas, focinho
## com caninos visíveis, olhos com sobrancelha. Tudo continua vermelho/preto.
func _draw_lion() -> void:
	var p: float = clampf(_t / duration, 0.0, 1.0)
	var appear: float = clampf(_t / 0.2, 0.0, 1.0)
	var a: float = 1.0 - clampf((p - 0.75) / 0.25, 0.0, 1.0)
	var r: float = lion_radius * lerpf(0.4, 1.0, _back_out(appear))
	var line_w: float = maxf(2.0, r * 0.06)
	var red: Color = _with_a(LION_RED, a * lion_opacity)
	var black: Color = _with_a(LION_BLACK, a * minf(1.0, lion_opacity + 0.2))

	var shake := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 3.0 * (1.0 - p)
	draw_set_transform(_ball_center() + shake, 0.0, Vector2.ONE)

	# Raios vermelhos/preto saindo da bola (por trás da juba)
	var bolt_alpha: float = a * minf(1.0, lion_opacity + 0.2)
	for i in bolt_count:
		var bolt_ang: float = TAU * float(i) / float(bolt_count) + randf() * 0.4
		_draw_bolt(bolt_ang, r * (1.6 + randf() * 0.7), line_w, bolt_alpha)

	# ---------- JUBA (2 camadas) ----------
	_draw_lion_mane(r, red, black, line_w, 0.60, 22, 1.25, 0.10)   # camada externa longa
	_draw_lion_mane(r, red, black, line_w, 0.42, 18, 1.15, 0.16)   # camada interna curta

	# ---------- ORELHAS ----------
	for sx in [-1.0, 1.0]:
		var ear := Vector2(sx * 0.52 * r, -0.55 * r)
		draw_circle(ear, 0.18 * r, red)
		draw_arc(ear, 0.18 * r, 0.0, TAU, 16, black, line_w)
		# Interior da orelha
		draw_circle(ear + Vector2(0.0, -0.02 * r), 0.08 * r, black)
		draw_circle(ear + Vector2(0.0, -0.02 * r), 0.05 * r, red)

	# ---------- ROSTO ----------
	# Cabeça
	draw_circle(Vector2.ZERO, 0.62 * r, red)
	draw_arc(Vector2.ZERO, 0.62 * r, 0.0, TAU, 40, black, line_w * 1.4)
	# Testa: marca leve no meio
	draw_line(Vector2(0.0, -0.55 * r), Vector2(0.0, -0.35 * r), black, line_w * 0.6)

	# ---------- OLHOS (com sobrancelha brava) ----------
	var pulse: float = 0.6 + 0.4 * sin(_t * 12.0)
	for sx in [-1.0, 1.0]:
		var ec := Vector2(sx * 0.25 * r, -0.13 * r)
		# Sobrancelha (linha grossa preta em diagonal)
		draw_line(ec + Vector2(-sx * 0.22 * r, -0.10 * r), ec + Vector2(sx * 0.18 * r, -0.18 * r),
			black, line_w * 1.8)
		# Olho: amêndoa vermelha com contorno preto
		var eye := PackedVector2Array([
			ec + Vector2(-sx * 0.13 * r, 0.05 * r), ec + Vector2(0.0, -0.09 * r),
			ec + Vector2(sx * 0.15 * r, -0.04 * r), ec + Vector2(0.0, 0.07 * r)])
		draw_colored_polygon(eye, red)
		var eye_line := eye.duplicate()
		eye_line.append(eye[0])
		draw_polyline(eye_line, black, line_w)
		# Pupila brilhando (mesmo em paleta restrita, o glow dá vida)
		draw_circle(ec, 0.035 * r * (0.9 + 0.2 * pulse), Color(1.0, 0.5, 0.4, 0.9 * a))
		draw_circle(ec, 0.015 * r, black)

	# ---------- FOCINHO ----------
	# Ponte do nariz (leve sombra)
	draw_line(Vector2(0.0, -0.05 * r), Vector2(0.0, 0.10 * r), black, line_w * 0.8)
	# Nariz (triângulo arredondado)
	var nose := PackedVector2Array([
		Vector2(-0.11 * r, 0.06 * r), Vector2(0.11 * r, 0.06 * r),
		Vector2(0.09 * r, 0.14 * r), Vector2(0.0, 0.17 * r), Vector2(-0.09 * r, 0.14 * r)])
	draw_colored_polygon(nose, black)
	# Narinas
	draw_circle(Vector2(-0.045 * r, 0.11 * r), 0.015 * r, red)
	draw_circle(Vector2(0.045 * r, 0.11 * r), 0.015 * r, red)
	# Linha do focinho até a boca
	draw_line(Vector2(0.0, 0.17 * r), Vector2(0.0, 0.22 * r), black, line_w * 1.2)

	# ---------- BOCA RUGINDO ----------
	var open: float = clampf(0.55 + 0.45 * sin(_t * 16.0), 0.2, 1.0)
	var m_top: float = 0.22 * r
	var m_w: float = 0.30 * r
	var depth: float = (0.10 + 0.28 * open) * r
	var mouth := PackedVector2Array()
	var n: int = 14
	for i in range(n + 1):
		var ang2: float = PI * float(i) / float(n)
		mouth.append(Vector2(cos(ang2) * m_w, m_top + sin(ang2) * depth))
	draw_colored_polygon(mouth, black)
	draw_polyline(mouth, black, line_w * 0.5)
	# Caninos grandes + dentes pequenos
	for sx in [-1.0, 1.0]:
		var fang_x: float = sx * 0.20 * r
		# Canino superior (para baixo)
		var upper := PackedVector2Array([
			Vector2(fang_x - 0.05 * r, m_top), Vector2(fang_x + 0.05 * r, m_top),
			Vector2(fang_x, m_top + 0.16 * r)])
		draw_colored_polygon(upper, red)
		draw_polyline(PackedVector2Array([upper[0], upper[1], upper[2], upper[0]]), black, line_w * 0.5)
		# Canino inferior (para cima)
		var lower := PackedVector2Array([
			Vector2(fang_x - 0.045 * r, m_top + depth), Vector2(fang_x + 0.045 * r, m_top + depth),
			Vector2(fang_x, m_top + depth - 0.13 * r)])
		draw_colored_polygon(lower, red)
		draw_polyline(PackedVector2Array([lower[0], lower[1], lower[2], lower[0]]), black, line_w * 0.5)
	# Dentes pequenos no meio
	for k in 4:
		var tx: float = -0.08 * r + 0.053 * r * float(k)
		draw_colored_polygon(PackedVector2Array([Vector2(tx - 0.018 * r, m_top),
			Vector2(tx + 0.018 * r, m_top), Vector2(tx, m_top + 0.06 * r)]), red)

	# ---------- ONDAS DO RUGIDO ----------
	for k in 3:
		var f: float = fposmod(_t * 1.6 + float(k) * 0.33, 1.0)
		var wave_r: float = (0.5 + f * 0.9) * r
		draw_arc(Vector2(0.0, m_top + depth * 0.4), wave_r, deg_to_rad(35.0), deg_to_rad(145.0), 22,
			Color(LION_BLACK.r, LION_BLACK.g, LION_BLACK.b, (1.0 - f) * 0.7 * a), line_w * 0.9)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Uma camada de juba: "espetos" de alturas variadas na circunferência. base_frac = raio base,
## spikes = quantos espetos, len = comprimento relativo do espeto, wobble = variação aleatória.
func _draw_lion_mane(r: float, fill: Color, edge: Color, line_w: float,
		base_frac: float, spikes: int, len: float, wobble: float) -> void:
	var step: float = TAU / float(spikes)
	for i in spikes:
		var ang: float = step * float(i) + _t * 0.4   # rotação lenta pra dar "movimento"
		var wob: float = 1.0 + wobble * sin(_t * 18.0 + float(i) * 1.7)
		var half: float = step * 0.58
		var base: float = base_frac * r
		var tip: float = len * r * wob
		var pts := PackedVector2Array([
			Vector2.from_angle(ang - half) * base,
			Vector2.from_angle(ang) * tip,
			Vector2.from_angle(ang + half) * base])
		draw_colored_polygon(pts, fill)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, edge, line_w)

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
