class_name PassFX
extends RefCounted
## Efeitos PEQUENOS para os passes de habilidade, só para diferenciar de um passe comum. Tudo é feito
## por código (sem imagem nem cena) e some sozinho. Este arquivo NÃO depende de nenhum outro arquivo
## de efeitos (cruel_fx.gd, one_more_time_fx.gd...), nem dos personagens.
##
## Cada habilidade tem um estilo, com cores e uma "marquinha" própria que fica caindo pelo caminho
## da bola (as marquinhas somem em menos de 1 segundo):
##   RABONA      (Charles)  dourado + azul: duas fitas trançadas e pequenos X cruzados
##   SKY_ARC     (Charles)  azul céu + branco: fita fina e pequenos arcos (asinhas)
##   ULTRASADIST (Hiori)    azul gelo: fita e pequenas lascas de gelo (losangos)
##   CHILLING    (Hiori)    branco gelado: fita macia e pequenos flocos de neve
##   OUR_DREAM   (Reo)      violeta + rosa claro: fita e pequenas estrelas de 4 pontas
## Em todos: uma fita curta atrás da bola, brilhinhos em volta dela, um anel pequeno na saída e um
## anel achatado no chão quando a bola chega (ou é tocada).
##
## COMO USAR (quem chama passa a bola; o efeito acompanha ela sozinho):
##   PassFX.attach(ball, PassFX.Style.RABONA)
##       -> use DEPOIS do ball.register_touch(self) (a saída da bola já aconteceu);
##   PassFX.arm(ball, PassFX.Style.SKY_ARC)
##       -> use ANTES de chamar uma função que faz o passe inteira (ex: m.run_curved_ground_pass).
##          O efeito espera quieto e só começa quando alguém toca na bola (a saída do passe).
##
## O efeito termina quando: alguém toca na bola, a bola é segurada, ela fica parada um instante
## (chegou ao destino) ou passa de MAX_AGE segundos.

enum Style { RABONA, SKY_ARC, ULTRASADIST, CHILLING, OUR_DREAM }
enum Mark { CROSS, WING, SHARD, FLAKE, STAR }

## Tempo máximo (s) do efeito depois da saída da bola
const MAX_AGE: float = 3.5
## Tempo máximo (s) esperando a saída da bola no modo arm()
const ARM_TIMEOUT: float = 4.0
## A cada quantos pixels andados cai uma marquinha
const MARK_STEP: float = 38.0

static var _soft_tex: GradientTexture2D = null
static var _ramps: Dictionary = {}


## Começa o efeito agora (a bola acabou de sair). Chame depois do register_touch.
static func attach(ball: Ball, style: Style) -> void:
	_spawn(ball, style, false)


## Deixa o efeito esperando: ele começa quando a bola for tocada (a saída do passe).
static func arm(ball: Ball, style: Style) -> void:
	_spawn(ball, style, true)


static func _spawn(ball: Ball, style: Style, armed: bool) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	for child in ball.get_children():
		if child is PassTrail:
			child.queue_free()   # um passe novo substitui o efeito do anterior
	var trail := PassTrail.new()
	trail.ball = ball
	trail.style = style
	trail.armed = armed
	trail.touches = ball.interaction_count
	ball.add_child(trail)


## Cores e marquinha de cada estilo
static func look_of(style: int) -> Dictionary:
	match style:
		Style.RABONA:
			return {"main": Color(1.0, 0.85, 0.2), "alt": Color(0.3, 0.6, 1.0), "mark": Mark.CROSS}
		Style.SKY_ARC:
			return {"main": Color(0.55, 0.85, 1.0), "alt": Color(1.0, 1.0, 1.0), "mark": Mark.WING}
		Style.ULTRASADIST:
			return {"main": Color(0.55, 0.95, 1.0), "alt": Color(0.2, 0.55, 0.95), "mark": Mark.SHARD}
		Style.CHILLING:
			return {"main": Color(0.82, 0.93, 1.0), "alt": Color(0.5, 0.75, 1.0), "mark": Mark.FLAKE}
	return {"main": Color(0.75, 0.45, 1.0), "alt": Color(0.98, 0.88, 1.0), "mark": Mark.STAR}


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


## Degradê da cor até transparente (um por cor, reaproveitado)
static func fade_ramp(color: Color) -> Gradient:
	if _ramps.has(color):
		return _ramps[color] as Gradient
	var g := Gradient.new()
	g.set_color(0, Color(color, 1.0))
	g.set_color(1, Color(color, 0.0))
	_ramps[color] = g
	return g


## O efeito em si: um nó filho da bola. Redesenha todo quadro, mas só desenha umas poucas linhas.
class PassTrail extends Node2D:
	var ball: Ball
	var style: int = 0
	var armed: bool = false
	var touches: int = 0

	var _main: Color = Color.WHITE
	var _alt: Color = Color.WHITE
	var _mark: int = 0
	var _age: float = 0.0
	var _points: Array[Vector2] = []     # onde a bola esteve (posição na tela), da mais velha à mais nova
	var _sample_acc: float = 0.0
	var _marks: Array = []               # {pos, t, rot, size}
	var _last_mark_pos: Vector2 = Vector2.ZERO
	var _has_mark: bool = false
	var _last_ground: Vector2 = Vector2.ZERO
	var _last_height: float = 0.0
	var _still: float = 0.0              # há quanto tempo a bola está parada
	var _ending: bool = false
	var _end_t: float = 0.0
	var _fade: float = 1.0
	var _launch_t: float = 1.0           # anel da saída (0 -> 1)
	var _launch_pos: Vector2 = Vector2.ZERO
	var _land_t: float = 1.0             # anel da chegada (0 -> 1)
	var _land_pos: Vector2 = Vector2.ZERO
	var _motes: CPUParticles2D           # brilhinhos que acompanham a bola
	var _burst: CPUParticles2D           # estouro pequeno na saída

	func _ready() -> void:
		top_level = true   # os pontos são posições da tela; o nó fica na origem do mundo
		z_index = 2
		global_position = Vector2.ZERO
		var look: Dictionary = PassFX.look_of(style)
		_main = look["main"]
		_alt = look["alt"]
		_mark = int(look["mark"])
		_motes = _make_particles(false)
		_burst = _make_particles(true)
		add_child(_motes)
		add_child(_burst)
		if not armed:
			_launch()

	func _make_particles(burst: bool) -> CPUParticles2D:
		var p := CPUParticles2D.new()
		p.emitting = false
		p.texture = PassFX.soft_texture()
		p.local_coords = false
		p.amount = 9 if burst else 10
		p.lifetime = 0.45 if burst else 0.5
		p.one_shot = burst
		p.explosiveness = 1.0 if burst else 0.0
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 5.0
		p.direction = Vector2.UP
		p.spread = 180.0
		p.initial_velocity_min = 25.0 if burst else 8.0
		p.initial_velocity_max = 80.0 if burst else 36.0
		p.damping_min = 60.0 if burst else 0.0
		p.damping_max = 60.0 if burst else 0.0
		p.gravity = Vector2(0.0, -20.0)
		p.angle_max = 360.0
		p.scale_amount_min = 0.12
		p.scale_amount_max = 0.28
		p.color_ramp = PassFX.fade_ramp(_alt if burst else _main)
		return p

	## Posição da bola na tela (já com a altura)
	func _head() -> Vector2:
		return ball.sprite.global_position

	## A bola saiu: o efeito começa
	func _launch() -> void:
		armed = false
		touches = ball.interaction_count
		_age = 0.0
		_launch_pos = _head()
		_launch_t = 0.0
		_burst.position = _launch_pos
		_burst.restart()
		_burst.emitting = true
		_motes.emitting = true
		_last_ground = ball.global_position
		_last_height = ball.height

	func _process(delta: float) -> void:
		if not is_instance_valid(ball):
			queue_free()
			return
		_age += delta

		# Esperando a saída da bola (arm): começa quando alguém toca nela
		if armed:
			if ball.interaction_count != touches:
				_launch()
			elif _age > PassFX.ARM_TIMEOUT:
				queue_free()
			return

		if _launch_t < 1.0:
			_launch_t = minf(1.0, _launch_t + delta / 0.3)
		if _land_t < 1.0:
			_land_t = minf(1.0, _land_t + delta / 0.45)
		var i: int = _marks.size() - 1
		while i >= 0:
			_marks[i]["t"] = float(_marks[i]["t"]) + delta
			if float(_marks[i]["t"]) > 0.7:
				_marks.remove_at(i)
			i -= 1

		if not _ending:
			if ball.interaction_count != touches or ball.is_held() or _age > PassFX.MAX_AGE:
				_begin_end()
			else:
				_track(delta)
		else:
			_end_t += delta
			_fade = 1.0 - clampf(_end_t / 0.4, 0.0, 1.0)
			if not _points.is_empty():
				_points.pop_front()   # a fita vai encurtando até sumir
			if _end_t >= 0.5 and _land_t >= 1.0:
				queue_free()
				return

		_motes.position = _head()
		queue_redraw()

	## Enquanto a bola anda: anota o caminho, solta as marquinhas e vê se ela parou
	func _track(delta: float) -> void:
		var head: Vector2 = _head()
		_sample_acc += delta
		if _sample_acc >= 0.025:
			_sample_acc = 0.0
			_points.append(head)
			if _points.size() > 16:
				_points.pop_front()

		if not _has_mark or head.distance_to(_last_mark_pos) >= PassFX.MARK_STEP:
			_has_mark = true
			_last_mark_pos = head
			_marks.append({"pos": head, "t": 0.0, "rot": randf() * TAU, "size": randf_range(0.85, 1.2)})
			if _marks.size() > 10:
				_marks.pop_front()

		# Parada = chegou ao destino (mede o chão e a altura, que não "balançam" como o sprite)
		var moved: float = ball.global_position.distance_to(_last_ground) + absf(ball.height - _last_height)
		_last_ground = ball.global_position
		_last_height = ball.height
		_still = _still + delta if moved < 0.6 else 0.0
		if _still >= 0.35:
			_begin_end()

	func _begin_end() -> void:
		_ending = true
		_motes.emitting = false
		if _age > 0.2:   # só faz o anel de chegada se a bola chegou a andar
			_land_pos = ball.global_position
			_land_t = 0.0

	func _draw() -> void:
		if armed:
			return
		var a: float = _fade

		# Fita atrás da bola (sem o último ponto, para não tampar a bola)
		var n: int = _points.size()
		for k in range(1, n - 1):
			var t: float = float(k) / float(n - 1)
			if _mark == PassFX.Mark.CROSS:
				# Rabona: duas fitas finas trançadas (dourada e azul)
				draw_line(_braid(k - 1, 1.0), _braid(k, 1.0), Color(_main, 0.9 * t * a), lerpf(0.8, 2.6, t))
				draw_line(_braid(k - 1, -1.0), _braid(k, -1.0), Color(_alt, 0.9 * t * a), lerpf(0.8, 2.6, t))
			else:
				draw_line(_points[k - 1], _points[k], Color(_main, 0.5 * t * a), lerpf(1.0, 5.0, t))
				draw_line(_points[k - 1], _points[k], Color(_alt, 0.85 * t * a), lerpf(0.5, 1.8, t))

		# Marquinhas que caem pelo caminho
		for m in _marks:
			var life: float = 1.0 - clampf(float(m["t"]) / 0.7, 0.0, 1.0)
			_draw_mark(Vector2(m["pos"]), float(m["rot"]) + float(m["t"]) * 1.5,
				4.5 * float(m["size"]), 0.85 * life * a)

		# Brilho piscando em cima da bola (a mesma marquinha do estilo, maior)
		if not _ending and not _points.is_empty():
			var twinkle: float = 0.5 + 0.5 * sin(_age * 16.0)
			_draw_mark(_head() + Vector2(0.0, -9.0), _age * 2.0, 6.0 + 2.0 * twinkle, 0.55 + 0.4 * twinkle)

		# Anel pequeno na saída
		if _launch_t < 1.0:
			var e: float = 1.0 - pow(1.0 - _launch_t, 3.0)
			draw_arc(_launch_pos, lerpf(6.0, 26.0, e), 0.0, TAU, 20, Color(_main, 0.8 * (1.0 - e)), 2.0)

		# Anel achatado no chão na chegada
		if _land_t < 1.0:
			var e2: float = 1.0 - pow(1.0 - _land_t, 3.0)
			draw_set_transform(_land_pos, 0.0, Vector2(1.0, 0.5))
			draw_arc(Vector2.ZERO, lerpf(6.0, 32.0, e2), 0.0, TAU, 24, Color(_main, 0.85 * (1.0 - e2)), 2.0)
			draw_arc(Vector2.ZERO, lerpf(3.0, 18.0, e2), 0.0, TAU, 20, Color(_alt, 0.7 * (1.0 - e2)), 1.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## Ponto da fita trançada (Rabona): balança de um lado para o outro, mais forte perto da bola
	func _braid(k: int, side: float) -> Vector2:
		var p: Vector2 = _points[k]
		var prev: Vector2 = _points[maxi(k - 1, 0)]
		var nxt: Vector2 = _points[mini(k + 1, _points.size() - 1)]
		var dir: Vector2 = nxt - prev
		if dir.length() < 0.01:
			return p
		var t: float = float(k) / float(maxi(_points.size() - 1, 1))
		return p + dir.normalized().orthogonal() * sin(_age * 16.0 + float(k) * 0.8) * 3.2 * t * side

	## Desenha a marquinha do estilo em "pos" (rot = giro, r = tamanho em px, alpha = opacidade)
	func _draw_mark(pos: Vector2, rot: float, r: float, alpha: float) -> void:
		if alpha <= 0.01:
			return
		var c_main := Color(_main, alpha)
		var c_alt := Color(_alt, alpha)
		match _mark:
			PassFX.Mark.CROSS:   # X cruzado
				var d1: Vector2 = Vector2.from_angle(rot + PI * 0.25) * r
				var d2: Vector2 = Vector2.from_angle(rot - PI * 0.25) * r
				draw_line(pos - d1, pos + d1, c_main, 2.0)
				draw_line(pos - d2, pos + d2, c_alt, 2.0)
			PassFX.Mark.WING:    # arquinho (asinha)
				draw_arc(pos, r, rot, rot + PI * 0.85, 7, c_main, 2.0)
				draw_arc(pos, r * 0.55, rot + 0.2, rot + PI * 0.7, 6, c_alt, 1.5)
			PassFX.Mark.SHARD:   # lasca de gelo (losango alongado)
				var u: Vector2 = Vector2.from_angle(rot)
				var v: Vector2 = u.orthogonal()
				var shard := PackedVector2Array([pos + u * r * 1.3, pos + v * r * 0.45,
					pos - u * r * 1.3, pos - v * r * 0.45])
				draw_colored_polygon(shard, Color(_alt, alpha * 0.7))
				shard.append(shard[0])
				draw_polyline(shard, c_main, 1.3)
			PassFX.Mark.FLAKE:   # floquinho de neve (3 traços cruzados)
				for k in 3:
					var d: Vector2 = Vector2.from_angle(rot + PI * float(k) / 3.0) * r
					draw_line(pos - d, pos + d, c_main if k % 2 == 0 else c_alt, 1.6)
			_:                   # estrelinha de 4 pontas
				var pts := PackedVector2Array()
				for k in 8:
					var rad: float = r if k % 2 == 0 else r * 0.3
					pts.append(pos + Vector2.from_angle(rot + PI * 0.25 * float(k)) * rad)
				draw_colored_polygon(pts, c_alt)
				pts.append(pts[0])
				draw_polyline(pts, c_main, 1.2)
