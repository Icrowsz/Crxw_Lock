class_name SelfishFX
extends RefCounted
## Efeitos visuais da reação SELFISH (Aiku + Sae): números rosas e pretos (Sae) e a serpente verde (como as do Aiku).
##
##  - pass_numbers(): números rosas com contorno preto acompanham a bola durante o Perfect Pass do Sae
##    (reaproveita o efeito NUMBERS do CarnivalFX);
##  - serpent(): uma serpente VERDE (como as do próprio Aiku) SAI do chute dele e acompanha a bola ondulando,
##    com língua bifurcada e presas;
##  - striker_burst(): no instante do chute do Striker: brilhos, clarão e tremida.
## Quem chama passa um nó que já esteja na árvore (ex: self) em "from".

const PINK: Color = Color(1.0, 0.10, 0.60)
const PINK_LIGHT: Color = Color(1.0, 0.65, 0.85)
const BLACK: Color = Color(0.05, 0.0, 0.05)
const VENOM: Color = Color(0.60, 0.95, 0.15)

# Cores da serpente (o verde-veneno do kick_fx do Aiku: 0.45, 0.65, 0.10)
const SNAKE_GREEN: Color = Color(0.45, 0.65, 0.10)
const SNAKE_DARK: Color = Color(0.17, 0.28, 0.04)
const SNAKE_LIGHT: Color = Color(0.80, 0.95, 0.40)
const SNAKE_EYE: Color = Color(1.0, 0.92, 0.25)


## Números rosas e pretos em volta da bola por "seconds" segundos (a duração do passe)
static func pass_numbers(ball: Ball, seconds: float) -> void:
	if ball == null:
		return
	CarnivalFX.attach_numbers(ball, seconds, 38.0)


## No instante do chute do Striker
static func striker_burst(from: Node, pos: Vector2) -> void:
	CruelFX.sparkle_burst(from, pos, PINK, 24, 300.0, 0.6, 1.0)
	CruelFX.sparkle_burst(from, pos, VENOM, 16, 240.0, 0.5, 0.9)
	CruelFX.sparkle_burst(from, pos, PINK_LIGHT, 10, 200.0, 0.45, 0.9)
	CruelFX.flash(from, PINK, 0.20, 0.4)
	CruelFX.shake(from, 11.0, 0.45)


## A serpente verde que sai do chute: nasce em "origin" (o Aiku) e vai crescendo atrás da bola. Chame logo depois que a bola sair.
static func serpent(from: Node, ball: Ball, origin: Vector2) -> void:
	if not is_instance_valid(from) or not from.is_inside_tree() or ball == null:
		return
	var snake := Serpent.new()
	snake.ball = ball
	snake.touches = ball.interaction_count   # qualquer toque novo na bola encerra o efeito
	snake.origin = origin
	from.get_parent().add_child(snake)
	snake.global_position = origin


## A serpente (verde): um corpo de bolinhas que segue o caminho da bola (a cabeça fica na bola), ondulando.
## Some sozinha quando a bola para, é tocada, segurada ou reposta (ou depois de MAX_LIFE segundos).
class Serpent extends Node2D:
	const SPACING: float = 13.0         # distância entre as bolinhas do corpo
	const MAX_SEGMENTS: int = 30        # tamanho máximo do corpo
	const WAVE_AMP: float = 9.0         # quanto o corpo ondula para os lados
	const GROW_TIME: float = 0.30       # tempo para "sair" do Aiku
	const MAX_LIFE: float = 3.5
	const FADE_SPEED: float = 2.5

	var ball: Ball
	var touches: int = 0
	var origin: Vector2 = Vector2.ZERO

	var _pts: Array[Vector2] = []       # caminho da cabeça (posições globais), do mais antigo ao mais novo
	var _len: float = 0.0               # comprimento do caminho
	var _sp: Array[Vector2] = []        # pontos do corpo (cabeça primeiro)
	var _sd: Array[Vector2] = []        # direção do movimento em cada ponto
	var _t: float = 0.0
	var _still: float = 0.0
	var _fade: float = 1.0
	var _dying: bool = false

	func _ready() -> void:
		z_as_relative = false
		z_index = 3400
		_pts.append(origin)
		if is_instance_valid(ball):
			ball.was_reset.connect(_start_dying, CONNECT_ONE_SHOT)

	func _start_dying() -> void:
		_dying = true

	func _process(delta: float) -> void:
		_t += delta
		if not _dying:
			if not is_instance_valid(ball) or ball.interaction_count != touches or ball.hovering or _t > MAX_LIFE:
				_dying = true
			else:
				var head: Vector2 = ball.sprite.global_position if ball.sprite != null else ball.global_position
				if _pts[_pts.size() - 1].distance_to(head) > 2.0:
					_len += _pts[_pts.size() - 1].distance_to(head)
					_pts.append(head)
					var limit: float = SPACING * float(MAX_SEGMENTS)
					while _len > limit and _pts.size() > 2:
						_len -= _pts[0].distance_to(_pts[1])
						_pts.pop_front()
				# bola parada no chão por um tempinho: a serpente vai embora
				if ball.velocity.length() < 25.0 and ball.height < 2.0:
					_still += delta
					if _still > 0.35:
						_dying = true
				else:
					_still = 0.0
		if _dying:
			_fade -= delta * FADE_SPEED
			if _fade <= 0.0:
				queue_free()
				return
		_build_body()
		queue_redraw()

	## Calcula os pontos do corpo andando para trás pelo caminho da cabeça
	func _build_body() -> void:
		_sp.clear()
		_sd.clear()
		var n: int = _pts.size()
		if n < 2:
			return
		var grow: float = clampf(_t / GROW_TIME, 0.0, 1.0)
		var count: int = mini(int(ceil(float(MAX_SEGMENTS) * grow)), int(_len / SPACING) + 1)
		count = maxi(count, 2)
		var seg: int = n - 1            # segmento entre _pts[seg] (perto da cabeça) e _pts[seg - 1]
		var seg_start: float = 0.0      # distância da cabeça até _pts[seg]
		for k in count:
			var d: float = float(k) * SPACING
			while seg > 1 and d > seg_start + _pts[seg].distance_to(_pts[seg - 1]):
				seg_start += _pts[seg].distance_to(_pts[seg - 1])
				seg -= 1
			var a: Vector2 = _pts[seg]
			var b: Vector2 = _pts[seg - 1]
			var seg_len: float = maxf(a.distance_to(b), 0.001)
			var u: float = clampf((d - seg_start) / seg_len, 0.0, 1.0)
			_sp.append(a.lerp(b, u))
			_sd.append((a - b) / seg_len)

	func _draw() -> void:
		var count: int = _sp.size()
		if count < 2:
			return
		var a: float = clampf(_fade, 0.0, 1.0)

		# Corpo: da cauda para a cabeça, bolinhas alternando verde e verde-escuro, afinando até a cauda
		for k in range(count - 1, 0, -1):
			var kt: float = float(k) / float(count - 1)
			var dir: Vector2 = _sd[k]
			var normal: Vector2 = Vector2(-dir.y, dir.x)
			var amp: float = WAVE_AMP * (0.25 + 0.75 * sin(PI * kt))
			var pos: Vector2 = to_local(_sp[k]) + normal * sin(_t * 9.0 - float(k) * 0.7) * amp
			var r: float = lerpf(12.0, 3.5, kt)
			var fill: Color = SelfishFX.SNAKE_GREEN if k % 2 == 1 else SelfishFX.SNAKE_DARK
			var rim: Color = SelfishFX.SNAKE_DARK if k % 2 == 1 else SelfishFX.SNAKE_LIGHT
			draw_circle(pos, r + 1.8, Color(rim, a))
			draw_circle(pos, r, Color(fill, a))

		# Cabeça: focinho alongado virado para onde a bola vai, olhos verdes, presas e língua bifurcada
		var hdir: Vector2 = _sd[0]
		var head_pos: Vector2 = to_local(_sp[0])
		draw_set_transform(head_pos, hdir.angle(), Vector2.ONE)
		var skull := PackedVector2Array([Vector2(-14, -12), Vector2(10, -10), Vector2(24, 0), Vector2(10, 10), Vector2(-14, 12)])
		draw_colored_polygon(skull, Color(SelfishFX.SNAKE_DARK, a))
		var outline := PackedVector2Array(skull)
		outline.append(skull[0])
		draw_polyline(outline, Color(SelfishFX.SNAKE_LIGHT, a), 2.5)
		draw_circle(Vector2(4, -6), 3.4, Color(SelfishFX.SNAKE_EYE, a))
		draw_circle(Vector2(4, 6), 3.4, Color(SelfishFX.SNAKE_EYE, a))
		draw_circle(Vector2(5, -6), 1.2, Color(SelfishFX.BLACK, a))
		draw_circle(Vector2(5, 6), 1.2, Color(SelfishFX.BLACK, a))
		draw_colored_polygon(PackedVector2Array([Vector2(18, -3), Vector2(24, -1), Vector2(20, 6)]), Color(1, 1, 1, a))
		draw_colored_polygon(PackedVector2Array([Vector2(18, 3), Vector2(24, 1), Vector2(20, -6)]), Color(1, 1, 1, a))
		if sin(_t * 14.0) > 0.2:
			draw_line(Vector2(24, 0), Vector2(36, 0), Color(SelfishFX.PINK, a), 2.0)
			draw_line(Vector2(36, 0), Vector2(43, -5), Color(SelfishFX.PINK, a), 2.0)
			draw_line(Vector2(36, 0), Vector2(43, 5), Color(SelfishFX.PINK, a), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
