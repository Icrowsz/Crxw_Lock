class_name WorldFX
extends RefCounted
## Efeitos visuais da reação WORLD (Bachira + Otoya): amarelo e preto do Bachira com o verde limão e branco do Otoya.
##
## Este arquivo reaproveita o que já existe (BachiraFX, CruelFX) e só cria UM desenho novo, o ShurikenSlash.
##
##  - summon_big_monster(): o monstro do Bachira MAIOR, com uma animaçãozinha (entra crescendo, passa do tamanho,
##    assenta, "respira" e some). Usa o BachiraFX.summon_monster e só mexe no tamanho (scale) dele;
##  - bon_armed(): no Bon que arma a reação: brilhos, clarão e a aura na bola;
##  - gotcha_slash(): o Shuriken gigante girando junto com a bola do Gotcha, deixando um rastro que corta o campo;
##  - result_burst(): no instante do chute do Gotcha: brilhos amarelos, verdes e brancos, clarão e tremida.
## Quem chama passa um nó que já esteja na árvore (ex: self) em "from".

const YELLOW: Color = Color(1.0, 0.85, 0.10)
const LIME: Color = Color(0.70, 1.0, 0.20)
const WHITE: Color = Color(1.0, 1.0, 1.0)


## O monstro do Bachira maior e com animação. "scale_mult" = quantas vezes maior que o normal do Instinct;
## "hold" = por quanto tempo fica antes de sumir. Não espere por esta função (roda em segundo plano).
static func summon_big_monster(bachira: Node2D, texture: Texture2D, scale_mult: float = 1.9, hold: float = 1.9) -> void:
	if not is_instance_valid(bachira) or not bachira.is_inside_tree():
		return
	var monster = BachiraFX.summon_monster(bachira, texture)   # sem tipo de propósito: só usamos scale e dismiss()
	if monster == null:
		return

	# Entrada: nasce pequeno, cresce passando do tamanho final (efeito "pop"), assenta e depois "respira"
	monster.scale = Vector2.ONE * scale_mult * 0.35
	var tw: Tween = monster.create_tween()
	tw.tween_property(monster, "scale", Vector2.ONE * scale_mult * 1.18, 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(monster, "scale", Vector2.ONE * scale_mult, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in 3:
		tw.tween_property(monster, "scale", Vector2.ONE * scale_mult * 1.06, 0.30) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(monster, "scale", Vector2.ONE * scale_mult * 0.97, 0.30) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var center: Vector2 = bachira.global_position + Vector2(0.0, -40.0)
	BachiraFX.flames(bachira, center, 24, true)
	CruelFX.sparkle_burst(bachira, center, YELLOW, 18, 240.0, 0.6, 0.9)
	CruelFX.sparkle_burst(bachira, center, LIME, 12, 200.0, 0.55, 0.9)
	CruelFX.shake(bachira, 6.0, 0.5)

	await bachira.get_tree().create_timer(hold).timeout
	if is_instance_valid(monster) and monster.has_method("dismiss"):
		monster.dismiss()


## No Bon que arma a reação: brilhos amarelos e verdes, clarão e a aura que segue a bola
static func bon_armed(from: Node, ball: Ball, pos: Vector2) -> void:
	if ball == null:
		return
	CruelFX.attach_ball_aura(ball, CruelFX.Style.RABONA)
	CruelFX.sparkle_burst(from, pos, YELLOW, 16, 260.0, 0.55, 0.9)
	CruelFX.sparkle_burst(from, pos, LIME, 14, 220.0, 0.5, 0.9)
	CruelFX.flash(from, YELLOW, 0.14, 0.3)


## No instante do chute do Gotcha
static func result_burst(from: Node, pos: Vector2) -> void:
	CruelFX.sparkle_burst(from, pos, LIME, 26, 300.0, 0.6, 1.0)
	CruelFX.sparkle_burst(from, pos, YELLOW, 20, 260.0, 0.5, 1.0)
	CruelFX.sparkle_burst(from, pos, WHITE, 12, 200.0, 0.45, 0.9)
	CruelFX.flash(from, WHITE, 0.22, 0.4)
	CruelFX.shake(from, 12.0, 0.45)


## O Shuriken gigante que acompanha a bola do Gotcha e vai cortando o campo. Chame logo depois que a bola sair.
static func gotcha_slash(from: Node, ball: Ball) -> void:
	if not is_instance_valid(from) or not from.is_inside_tree() or ball == null:
		return
	var slash := ShurikenSlash.new()
	slash.ball = ball
	slash.touches = ball.interaction_count   # qualquer toque novo na bola encerra o efeito
	from.get_parent().add_child(slash)
	slash.global_position = ball.sprite.global_position if ball.sprite != null else ball.global_position


## Shuriken de quatro pontas girando em cima da bola, com um rastro afinando que "corta" o campo.
## Some sozinho quando a bola para, é tocada, segurada ou reposta (ou depois de MAX_LIFE segundos).
class ShurikenSlash extends Node2D:
	const RADIUS: float = 46.0
	const SPIN_SPEED: float = 16.0      # radianos por segundo
	const MAX_TRAIL: int = 28           # pontos do rastro (quanto maior, mais longo o corte)
	const MAX_LIFE: float = 3.5
	const FADE_SPEED: float = 3.0

	var ball: Ball
	var touches: int = 0

	var _spin: float = 0.0
	var _life: float = 0.0
	var _still: float = 0.0             # há quanto tempo a bola está parada
	var _fade: float = 1.0
	var _dying: bool = false
	var _trail: Array[Vector2] = []     # posições globais da bola

	func _ready() -> void:
		z_as_relative = false
		z_index = 3500                  # acima de jogadores e bola
		if is_instance_valid(ball):
			ball.was_reset.connect(_start_dying, CONNECT_ONE_SHOT)

	func _start_dying() -> void:
		_dying = true

	func _process(delta: float) -> void:
		_spin += delta * SPIN_SPEED
		_life += delta
		if not _dying:
			if not is_instance_valid(ball) or ball.interaction_count != touches or ball.hovering \
					or _life > MAX_LIFE:
				_dying = true
			else:
				global_position = ball.sprite.global_position if ball.sprite != null else ball.global_position
				if _trail.is_empty() or _trail[_trail.size() - 1].distance_to(global_position) > 4.0:
					_trail.append(global_position)
					if _trail.size() > MAX_TRAIL:
						_trail.pop_front()
				# bola parada no chão por um tempinho: o corte termina
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
		queue_redraw()

	func _draw() -> void:
		var a: float = clampf(_fade, 0.0, 1.0)
		# Rastro: faixa verde larga e translúcida com um fio branco por cima, afinando até a cauda
		var n: int = _trail.size()
		for i in range(1, n):
			var k: float = float(i) / float(n)
			var p0: Vector2 = to_local(_trail[i - 1])
			var p1: Vector2 = to_local(_trail[i])
			draw_line(p0, p1, Color(WorldFX.LIME, 0.50 * k * a), 3.0 + 16.0 * k)
			draw_line(p0, p1, Color(WorldFX.WHITE, 0.90 * k * a), 1.0 + 4.0 * k)

		# O shuriken: estrela de quatro pontas girando
		draw_set_transform(Vector2.ZERO, _spin, Vector2.ONE)
		var pts := PackedVector2Array()
		for i in 8:
			var r: float = RADIUS if i % 2 == 0 else RADIUS * 0.30
			pts.append(Vector2.from_angle(TAU * float(i) / 8.0) * r)
		draw_colored_polygon(pts, Color(WorldFX.WHITE, a))
		var outline := PackedVector2Array(pts)
		outline.append(pts[0])
		draw_polyline(outline, Color(WorldFX.LIME, a), 3.0)
		draw_circle(Vector2.ZERO, RADIUS * 0.17, Color(0.08, 0.12, 0.04, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
