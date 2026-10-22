class_name Referee
extends Node2D
## O JUIZ: bonequinho temporário (camisa amarela, shorts preto, apito) desenhado por código.
## Nos resets (gol, troca de tempo) ele entra pela lateral, vai até onde a bola parou, PEGA ela, leva até o
## centro, a COLOCA no chão, apita e sai do campo. O MatchManager cuida de tudo isso (use_referee).
##
## Uso (o MatchManager já faz isso):
##   var ref := Referee.new()
##   field.add_child(ref)
##   ref.fetch_ball(ball, onde_a_bola_parou, centro, ponto_de_entrada, ponto_de_saida)   # sem await
##   ... espera ref.is_done
##
## A bola de verdade fica escondida e parada no centro enquanto ele a "carrega" (uma bolinha desenhada na mão
## dele); ao colocar no chão ela reaparece e é solta.

@export var walk_speed: float = 300.0
@export var scale_factor: float = 1.2
@export var shirt_color: Color = Color(0.97, 0.84, 0.18)
@export var shorts_color: Color = Color(0.09, 0.09, 0.11)
@export var skin_color: Color = Color(0.95, 0.78, 0.62)

## true quando a bola já foi colocada no centro (o resto, sair do campo, acontece em segundo plano)
var is_done: bool = false

var _step: float = 0.0          # fase da caminhada
var _moving: bool = false
var _carrying: bool = false
var _crouch: float = 0.0        # 0 = em pé, 1 = agachado
var _whistle: float = 0.0       # 0..1: apito soando
var _face: int = 1


func _process(delta: float) -> void:
	if _moving:
		_step += delta * 12.0
	# Mesma regra de profundidade dos jogadores (quem está mais embaixo na tela fica na frente)
	z_as_relative = false
	z_index = int(global_position.y)
	queue_redraw()


# ---------- CENA ----------

## Entra em "entry", vai até "from" (onde a bola parou), pega a bola, leva até "center", coloca no chão,
## apita e sai por "exit_point". Termina (is_done = true) assim que a bola está no chão.
func fetch_ball(ball: Ball, from: Vector2, center: Vector2, entry: Vector2, exit_point: Vector2) -> void:
	is_done = false
	global_position = entry
	# A bola real espera escondida e parada no centro
	ball.hover_to(center, 0.0, 0.01)
	ball.visible = false

	await _walk_to(from)
	await _crouch_to(1.0, 0.28)
	_carrying = true
	await _crouch_to(0.0, 0.22)

	await _walk_to(center + Vector2(-30.0, 14.0))
	_face = 1
	await _crouch_to(1.0, 0.25)
	_place_ball(ball, center)
	await _crouch_to(0.0, 0.22)

	await _blow_whistle(0.45)
	is_done = true
	_leave(exit_point)   # sai do campo em segundo plano


## Segurança: se algo interromper a cena, coloca a bola no centro agora
func force_finish(ball: Ball, center: Vector2) -> void:
	if is_done:
		return
	_carrying = false
	if is_instance_valid(ball):
		_place_ball(ball, center)
	is_done = true
	_leave(global_position + Vector2(0.0, 400.0))


func _place_ball(ball: Ball, center: Vector2) -> void:
	_carrying = false
	ball.visible = true
	ball.global_position = center
	ball.velocity = Vector2.ZERO
	ball.vel_z = 0.0
	ball.height = 0.0
	ball.release_hover()


func _leave(exit_point: Vector2) -> void:
	await _walk_to(exit_point)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	await tw.finished
	queue_free()


# ---------- MOVIMENTO ----------

func _walk_to(target: Vector2) -> void:
	var dist: float = global_position.distance_to(target)
	if dist < 1.0:
		return
	if absf(target.x - global_position.x) > 2.0:
		_face = 1 if target.x > global_position.x else -1
	_moving = true
	var tw := create_tween()
	tw.tween_property(self, "global_position", target, dist / walk_speed)
	await tw.finished
	_moving = false


func _crouch_to(value: float, time: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_crouch", value, time).set_trans(Tween.TRANS_SINE)
	await tw.finished


func _blow_whistle(time: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_whistle", 1.0, 0.08)
	tw.tween_interval(time)
	tw.tween_property(self, "_whistle", 0.0, 0.12)
	await tw.finished


# ---------- DESENHO ----------

func _draw() -> void:
	var s: float = scale_factor
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(_face) * s, s))

	# Sombra no chão
	draw_colored_polygon(_ellipse(Vector2.ZERO, 13.0, 5.0), Color(0, 0, 0, 0.28))

	var swing: float = sin(_step) if _moving else 0.0
	var bob: float = absf(cos(_step)) * 2.0 if _moving else 0.0
	var squat: float = _crouch * 11.0
	var hip := Vector2(0.0, -19.0 + squat * 0.55 - bob)
	var shoulder := Vector2(0.0, -37.0 + squat - bob)

	# Pernas (meias pretas, chuteiras)
	for side in [-1.0, 1.0]:
		var lift: float = maxf(0.0, swing * float(side)) * 4.0
		var foot := Vector2(float(side) * 5.0 + swing * float(side) * 6.0, -lift)
		draw_line(hip + Vector2(float(side) * 3.0, 0.0), foot + Vector2(0.0, -2.0), Color(0.08, 0.08, 0.1), 4.0)
		draw_circle(foot, 3.2, Color(0.05, 0.05, 0.06))

	# Shorts e camisa amarela
	draw_rect(Rect2(hip + Vector2(-8.0, -3.0), Vector2(16.0, 9.0)), shorts_color)
	var torso := PackedVector2Array([
		shoulder + Vector2(-8.0, 0.0), shoulder + Vector2(8.0, 0.0),
		hip + Vector2(7.0, -2.0), hip + Vector2(-7.0, -2.0)])
	draw_colored_polygon(torso, shirt_color)
	draw_line(shoulder + Vector2(-8.0, 3.0), shoulder + Vector2(8.0, 3.0), shirt_color.darkened(0.25), 1.5)
	draw_polyline(PackedVector2Array([torso[0], torso[3], torso[2], torso[1], torso[0]]), Color(0.1, 0.1, 0.1, 0.7), 1.5)

	# Braços: balançam na caminhada; carregando a bola, os dois seguram na frente
	var hand_front := Vector2(11.0, shoulder.y + 10.0)
	for side in [-1.0, 1.0]:
		var hand := Vector2(float(side) * 9.0 - swing * float(side) * 4.0, shoulder.y + 14.0)
		if _carrying:
			hand = hand_front + Vector2(0.0, float(side) * 1.5)
		draw_line(shoulder + Vector2(float(side) * 7.0, 2.0), hand, shirt_color.darkened(0.1), 3.5)
		draw_circle(hand, 2.6, skin_color)

	# Bola nas mãos
	if _carrying:
		var ball_pos := hand_front + Vector2(3.0, -2.0)
		draw_circle(ball_pos, 7.0, Color(0.97, 0.97, 0.97))
		draw_arc(ball_pos, 7.0, 0.0, TAU, 16, Color(0.1, 0.1, 0.1), 1.5)
		draw_circle(ball_pos, 2.6, Color(0.1, 0.1, 0.1))

	# Cabeça, boné preto e apito
	var head := shoulder + Vector2(1.0, -9.0)
	draw_circle(head, 7.5, skin_color)
	draw_arc(head, 7.5, PI, TAU, 14, Color(0.1, 0.1, 0.1), 4.0)   # boné
	draw_circle(head + Vector2(3.0, -1.0), 1.1, Color(0.1, 0.1, 0.1))   # olho
	draw_circle(head + Vector2(6.0, 3.0), 1.8, Color(0.92, 0.92, 0.92))   # apito
	if _whistle > 0.0:
		for i in 3:
			var r: float = 6.0 + float(i) * 5.0
			draw_arc(head + Vector2(8.0, 3.0), r, -0.7, 0.7, 8, Color(1, 1, 1, _whistle * (0.8 - float(i) * 0.22)), 1.8)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 16:
		var a: float = float(i) * TAU / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
