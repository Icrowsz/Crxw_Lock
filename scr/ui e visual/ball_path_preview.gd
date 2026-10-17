class_name BallPathPreview
extends RefCounted
## Pré-visualização da trajetória de um chute enquanto o jogador mira (usada pelo Bunny e pela Yukimiya).
##
## A bola é simulada do MESMO jeito que o Ball faz (gravidade, quique, atrito no chão, resistência do ar),
## com as curvas opcionais que o personagem aplica depois do chute. Só desenha: não mexe em nada do jogo.
##
## Uso (dentro do _draw do personagem, só enquanto ele mira a habilidade):
##     var launch := BallPathPreview.launch_for(self, ball, KickType.VOLLEY)
##     var data := BallPathPreview.simulate(ball, ball.global_position, ball.height,
##             dir * launch["speed"], launch["lift"], [curva_em_radianos], curve_time)
##     BallPathPreview.draw(self, data, cor)

const STEP: float = 1.0 / 60.0   # o passo da física do Ball


## Velocidade e impulso vertical que o kick_ball do Player dá à bola para esse tipo de chute
static func launch_for(player: Player, ball: Ball, kind: Player.KickType) -> Dictionary:
	var force: float = player.kick_force_ground
	match kind:
		Player.KickType.VOLLEY:
			force = player.kick_force_volley
		Player.KickType.FLYING:
			force = player.kick_force_flying
		Player.KickType.HIGH_BALL:
			force = player.kick_force_high_ball
	force *= player.next_kick_force_mult
	var lift: float = 0.0
	if kind == Player.KickType.VOLLEY or kind == Player.KickType.FLYING:
		var peak_level: Heights.Level = player.volley_peak_level if kind == Player.KickType.VOLLEY \
			else player.flying_peak_level
		var rise: float = maxf(0.0, Heights.to_height(peak_level) - ball.height)
		lift = Heights.lift_for_peak(rise, ball.gravity)
	return {"speed": force * player.kick_force_to_speed, "lift": lift}


## Simula a bola e devolve {points: posições no chão, heights: altura em cada ponto, bounces: onde quica}.
## curve_plan: curva total (radianos, com sinal) de cada trecho; cada trecho dura curve_time segundos.
## curve_until_ground: true = as curvas param quando a bola pousa de vez (como o Bunny).
## max_length: tamanho máximo do desenho (px); a bola real vai mais longe.
static func simulate(ball: Ball, start_pos: Vector2, start_height: float, velocity: Vector2, vel_z: float,
		curve_plan: Array = [], curve_time: float = 0.2, curve_until_ground: bool = false,
		max_length: float = 650.0, max_time: float = 3.5) -> Dictionary:
	var pos: Vector2 = start_pos
	var h: float = start_height
	var vel: Vector2 = velocity
	var vz: float = vel_z
	var points: Array[Vector2] = [pos]
	var heights: Array[float] = [h]
	var bounces: Array[Vector2] = []
	var seg: int = 0
	var seg_t: float = 0.0
	var length: float = 0.0
	var t: float = 0.0
	var frame: int = 0
	while t < max_time and length < max_length:
		# Curvas (a velocidade vai sendo girada aos poucos)
		if seg < curve_plan.size():
			if curve_until_ground and h <= 0.0 and vz == 0.0:
				seg = curve_plan.size()
			else:
				vel = vel.rotated(float(curve_plan[seg]) * STEP / maxf(curve_time, 0.05))
				seg_t += STEP
				if seg_t >= curve_time:
					seg += 1
					seg_t = 0.0
		# Vertical (igual ao Ball._apply_vertical)
		if h > 0.0 or vz > 0.0:
			vz -= ball.gravity * STEP
			h += vz * STEP
			if h <= 0.0:
				h = 0.0
				if absf(vz) > ball.min_bounce_speed:
					vz = -vz * ball.bounce_factor
					vel *= 0.9
					bounces.append(pos)
				else:
					vz = 0.0
		# Horizontal (igual ao Ball._apply_ground_motion)
		var on_ground: bool = h <= 0.0 and vz == 0.0
		if on_ground:
			vel = vel.move_toward(Vector2.ZERO, vel.length() * ball.ground_friction * STEP + ball.stop_speed * STEP)
		else:
			vel *= maxf(0.0, 1.0 - ball.air_drag * STEP)
		pos += vel * STEP
		length += vel.length() * STEP
		t += STEP
		frame += 1
		if frame % 3 == 0:
			points.append(pos)
			heights.append(h)
		if on_ground and vel.length() < 20.0:
			break
	points.append(pos)
	heights.append(h)
	return {"points": points, "heights": heights, "bounces": bounces}


## Desenha no nó (coordenadas locais dele): a trajetória no ar (com a altura) e a sombra no chão
static func draw(canvas: Node2D, data: Dictionary, color: Color) -> void:
	var points: Array = data.get("points", [])
	var heights: Array = data.get("heights", [])
	if points.size() < 2:
		return
	var ground := PackedVector2Array()
	var screen := PackedVector2Array()
	for i in points.size():
		var g: Vector2 = canvas.to_local(points[i])
		ground.append(g)
		screen.append(g + Vector2(0.0, -float(heights[i])))

	# Sombra da trajetória no chão (fraquinha)
	canvas.draw_polyline(ground, Color(color, 0.22), 2.0)

	# Trajetória (com a altura): grossa e forte no começo, some aos poucos
	var n: int = screen.size()
	for i in range(1, n):
		var k: float = float(i) / float(n)
		canvas.draw_line(screen[i - 1], screen[i], Color(color, lerpf(0.95, 0.3, k)), lerpf(4.0, 2.0, k))

	# Onde a bola quica no chão
	for b: Vector2 in data.get("bounces", []):
		canvas.draw_arc(canvas.to_local(b), 6.0, 0.0, TAU, 16, Color(color, 0.8), 2.0)

	# Ponta
	canvas.draw_circle(screen[n - 1], 5.0, Color(color, 0.7))
