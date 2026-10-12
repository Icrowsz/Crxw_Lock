class_name Loki
extends Player
## Loki. Herda tudo do Player (ações gerais) e adiciona as habilidades próprias.
## Visual: dourado, com raios de velocidade (raios saem dele quando corre ou avança).
##
## PASSIVAS
##  - O Correr dele é mais veloz (multiplicador 1.5).
##  - Quanto mais ele se move (Correr, Carrinho, avanços... qualquer movimento), mais enche uma
##    barra de força (a barrinha dourada em cima dele). Cada trecho percorrido dá +3% de força
##    (máximo +30%) ao PRÓXIMO chute dele (Nouveau Génie ou chute normal); chutar zera a barra.
##
## 1. Vitesse de la Lumière (recarga de 2 rodadas, compartilhada com o Nouveau Génie):
##      Avanço longo e direcional. Dá para fazer no chão ou suspenso (suspenso, ele desce ao chão
##      durante a trajetória). Se encontrar a bola (no chão ou suspensa) no caminho, ele para ao
##      lado dela, ganha +1 ação de habilidade (só dele) e libera o Nouveau Génie.
##    Nouveau Génie (complemento): chute forte com 50% de chance de gol. Com a bola no chão ela
##      sobe até Suspensa durante a trajetória. O botão da habilidade 1 vira "Nouveau Génie"
##      sozinho enquanto o complemento estiver liberado (até o fim do turno do time dele).
##      A recarga compartilhada começa no Vitesse; o Nouveau Génie usa a janela que ele abriu
##      (não é bloqueado por ela e não reinicia a recarga).
## 2. Char d'Assaut (recarga de 3 rodadas, compartilhada com Renversé e Too Slow; a variante é
##    escolhida sozinha pela situação):
##      - Loki no chão e inimigo NO CHÃO no alcance (400 px) -> Char d'Assaut: vai até o inimigo e
##        faz um confronto de sorte (70%). Ganhando, o inimigo leva um stun (fica travado) e o
##        Loki ganha um Correr curto e mais veloz.
##        Renversé (complemento automático): se, durante esse Correr, ele esbarrar em OUTRO inimigo
##        no chão, começa mais um confronto (70%). Ganhando, ganha mais um Correr, ainda mais
##        curto, e SEM stun. Repete no máximo 4 vezes (a duração só diminui na segunda corrida).
##      - Loki SUSPENSO, bola suspensa/voando próxima e um aliado a até 400 px -> Too Slow: salta
##        até a bola, domina, desce ao chão com ela e dá um passe rasteiro para o aliado.
## 3. Proie Facile (recarga de 2 rodadas): vai até um inimigo e deixa o PRÓXIMO Correr dele mais
##      lento; enquanto o inimigo corre, o Loki acompanha ele.
##
## ASSUNÇÕES (o pedido não definia; ajuste nos @export):
##  - Perder o confronto do Char d'Assaut não tem punição extra; a recarga começa de qualquer jeito.
##  - O Too Slow termina num passe rasteiro DO Loki para o aliado escolhido (alcance 400).
##  - O Nouveau Génie não tem QTE.
##  - O stun é uma trava total (apply_lock) que cobre o próximo turno do time inimigo.
##
## Como montar a cena: Nova Cena Herdada de player.tscn -> anexe este script ao nó raiz
## -> renomeie o nó raiz para "Loki". Registre o character_id "loki" onde você registra os outros
## no menu de formação.
##
## NÃO precisa de mudanças em nenhum outro arquivo: usa só a API que já existe no Player, na Ball
## e no MatchManager.
##
## Animações opcionais (SpriteFrames): vitesse, nouveau_genie, assault, too_slow, proie_facile.
## Sem a animação, a ação segue direto.

const SKILL_VITESSE: StringName = &"vitesse"          # também é o Nouveau Génie
const SKILL_ASSAULT: StringName = &"char_d_assaut"    # também é o Too Slow (e o Renversé, automático)
const SKILL_PREY: StringName = &"proie_facile"

const CD_VITESSE: StringName = &"cd_vitesse"
const CD_ASSAULT: StringName = &"cd_assault"
const CD_PREY: StringName = &"cd_prey"

const GOLD: Color = Color(1.0, 0.82, 0.15)
const GOLD_LIGHT: Color = Color(1.0, 0.95, 0.62)
const GOLD_DARK: Color = Color(0.72, 0.5, 0.05)

enum AssaultVariant { NONE, ASSAULT, TOO_SLOW }

@export_group("Passivas")
@export var run_speed_passive: float = 1.5               # multiplicador de velocidade do Correr
@export var charge_distance_per_step: float = 180.0      # px de movimento para cada +3% de força
@export_range(0.0, 1.0) var charge_step_bonus: float = 0.03
@export_range(0.0, 1.0) var charge_max_bonus: float = 0.30

@export_group("Vitesse de la Lumière / Nouveau Génie")
@export var vitesse_distance: float = 390.0              # alcance do avanço
@export var vitesse_time: float = 0.28
@export var vitesse_cooldown: int = 2                    # compartilhada com o Nouveau Génie
@export var vitesse_meet_radius: float = 58.0            # a que distância da bola ele "encontra" ela
@export var genie_force: float = 50.0                   # força do chute (x10 = px/s)
@export_range(0.0, 1.0) var genie_chance: float = 0.50   # chance de o chute vencer o goleiro

@export_group("Char d'Assaut / Renversé / Too Slow")
@export var assault_cooldown: int = 3                    # igual para as variantes
@export var assault_range: float = 300.0
@export var assault_dash_time: float = 0.2
@export_range(0.0, 1.0) var assault_chance: float = 0.80 # confronto de sorte (também no Renversé)
@export var assault_run_time: float = 1.0                # Correr curto depois de ganhar o 1º confronto
@export var assault_run_boost: float = 1.4               # ainda mais veloz que o Correr normal dele
@export var renverse_run_time: float = 0.6               # mais curto ainda (vale da 2ª corrida em diante)
@export var renverse_max_repeats: int = 4
@export var contact_pad: float = 6.0                     # folga para "esbarrar" em um inimigo
@export var too_slow_leap_time: float = 0.3
@export var too_slow_pass_range: float = 460.0

@export_group("Proie Facile")
@export var prey_range: float = 270.0
@export var prey_cooldown: int = 2
@export var prey_dash_time: float = 0.2
@export_range(0.1, 1.0) var prey_run_mult: float = 0.5   # velocidade do próximo Correr do inimigo
@export var prey_rounds: int = 2                         # se o inimigo não correr, o efeito acaba depois disso

@export_group("Visual do chute")
## Aura + partículas dos chutes/passes de habilidade. Vazio = usa o estilo padrão do Loki (veja _make_kick_fx)
@export var kick_fx: KickFX

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: vitesse, char_d_assaut, proie_facile.
@export var skill_icons: Dictionary = {}

## Passiva: movimento acumulado (px) desde o último chute
var _charge_px: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _bolt_timer: float = 0.0
var _dashing: bool = false          # em um avanço (para os raios)

## Multiplicador extra de velocidade do Correr de habilidade (Char d'Assaut)
var _run_boost: float = 1.0

## Vitesse: o Nouveau Génie está liberado neste turno
var _genie_ready: bool = false

## Char d'Assaut: inimigos já enfrentados nesta sequência (não enfrenta de novo)
var _fought: Array[Player] = []

## Proie Facile: inimigo marcado (o próximo Correr dele fica lento) e quanto falta para o efeito acabar
var _prey: Player = null
var _prey_offset: Vector2 = Vector2.ZERO
var _prey_until_round: int = -1
var _prey_was_running: bool = false

## Aviso curto em cima dele (resultado dos confrontos)
var _say_text: String = ""
var _say_until_msec: int = 0


func _init() -> void:
	character_id = "loki"   # o menu de formação usa isto para saber quem é quem
	display_name = "Loki"


func _ready() -> void:
	super()
	# O Proie Facile deixa o Correr de um inimigo lento: o Loki entra no grupo dos efeitos de
	# controle (ver run_speed_mult_on)
	add_to_group("control_sources")
	if kick_fx == null:
		kick_fx = _make_kick_fx()
	_last_pos = global_position
	_hook_manager.call_deferred()


## Dourado, com faíscas rápidas
func _make_kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = GOLD
	fx.trail_width = 12.0
	fx.shape = KickFX.Shape.SQUARE
	fx.particle_color = GOLD_LIGHT
	fx.amount = 24
	fx.lifetime = 0.45
	fx.speed_min = 25.0
	fx.speed_max = 95.0
	fx.gravity = Vector2(0.0, -30.0)
	fx.spin = 420.0
	fx.scale_min = 0.12
	fx.scale_max = 0.28
	fx.burst_amount = 16
	fx.burst_speed = 240.0
	return fx


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m:
		m.turn_ended.connect(_on_turn_ended)
		m.round_started.connect(_on_round_started)
	var ball: Ball = _get_ball()
	if ball:
		ball.was_reset.connect(_on_ball_reset)


func _on_turn_ended(ended_team: int) -> void:
	# O Nouveau Génie (e a ação extra que veio com ele) dura até o fim do turno do time do Loki
	if ended_team == team:
		_drop_genie()


func _on_round_started(new_round: int) -> void:
	if _prey != null and new_round > _prey_until_round:
		_clear_prey()
	queue_redraw()


func _on_ball_reset() -> void:
	_drop_genie()   # gol / reposição


## Fecha a janela do Nouveau Génie e devolve a ação extra que sobrou
func _drop_genie() -> void:
	if _genie_ready:
		extra_skill_left = maxi(extra_skill_left - 1, 0)
	_genie_ready = false
	queue_redraw()


# ---------- UTIL ----------

func _get_field() -> Field:
	return get_tree().get_first_node_in_group("field") as Field


## Mantém uma posição (global) dentro do campo
func _clamp_to_pitch(global_p: Vector2) -> Vector2:
	var field: Field = _get_field()
	if field == null:
		return global_p
	var half: Vector2 = field.pitch_size * 0.5 - Vector2(20.0, 20.0)
	var l: Vector2 = field.to_local(global_p)
	l.x = clampf(l.x, -half.x, half.x)
	l.y = clampf(l.y, -half.y, half.y)
	return field.to_global(l)


## Vai (posição + altura) até um ponto, ficando no nível indicado
func _dash_to(dest: Vector2, target_height: float, level: Heights.Level, duration: float) -> void:
	height_level = level
	_dashing = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", _clamp_to_pitch(dest), duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "height", target_height, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(duration).timeout
	_dashing = false


## "Bola próxima" = ao alcance de chute e livre para o time dele tocar
func _ball_is_near(ball: Ball) -> bool:
	if ball == null or ball.is_held() or ball.is_locked_for(team):
		return false
	return global_position.distance_to(ball.global_position) <= kick_range


func _has_ally_in_range(range_px: float) -> bool:
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p != self and p.team == team and global_position.distance_to(p.global_position) <= range_px:
			return true
	return false


## Inimigo em pé (não derrubado)
func _is_standing_enemy(p: Player) -> bool:
	return p != self and p.team != team and not p.is_down


## Inimigo NO CHÃO e em pé (alvo do Char d'Assaut)
func _is_grounded_enemy(p: Player) -> bool:
	return _is_standing_enemy(p) and p.height_level == Heights.Level.GROUND


func _any_enemy_in_range(range_px: float, grounded_only: bool) -> bool:
	for p: Player in get_tree().get_nodes_in_group("players"):
		var ok: bool = _is_grounded_enemy(p) if grounded_only else _is_standing_enemy(p)
		if ok and global_position.distance_to(p.global_position) <= range_px:
			return true
	return false


## Um passo ao lado do alvo (do lado de onde o Loki vem), para ele não ficar por cima
func _spot_next_to(target: Node2D, target_radius: float) -> Vector2:
	var dir: Vector2 = global_position - target.global_position
	dir = dir.normalized() if dir.length() > 1.0 else Vector2(-facing, 0.0)
	return target.global_position + dir * (body_radius + target_radius + 4.0)


func _say(text: String) -> void:
	_say_text = text
	_say_until_msec = Time.get_ticks_msec() + 1400
	queue_redraw()


# ---------- PASSIVAS ----------

## O Correr dele é mais veloz (e mais ainda no Correr de habilidade do Char d'Assaut)
func get_run_speed_mult() -> float:
	return super() * run_speed_passive * _run_boost


func _charge_max_px() -> float:
	var steps: int = maxi(int(round(charge_max_bonus / maxf(charge_step_bonus, 0.001))), 1)
	return charge_distance_per_step * float(steps)


## Bônus de força atual: +3% por trecho percorrido, até o máximo
func _charge_bonus() -> float:
	var steps: int = int(_charge_px / maxf(charge_distance_per_step, 1.0))
	return minf(float(steps) * charge_step_bonus, charge_max_bonus)


func _take_charge_bonus() -> float:
	var bonus: float = _charge_bonus()
	_charge_px = 0.0
	queue_redraw()
	return bonus


## Qualquer chute dele (Nouveau Génie ou normal) leva o bônus da barra de força
func kick_ball(ball: Ball, direction: Vector2, kind: KickType, qte_success: bool = true,
		chance_override: float = -1.0, ignore_self_collision: bool = false,
		fx: KickFX = null, anim: StringName = &"", on_kick: Callable = Callable()) -> void:
	next_kick_force_mult *= 1.0 + _take_charge_bonus()
	await super(ball, direction, kind, qte_success, chance_override, ignore_self_collision,
		fx, anim, on_kick)


func _physics_process(delta: float) -> void:
	super(delta)
	_track_movement(delta)
	_update_prey_follow()


## Enche a barra com qualquer deslocamento e solta os raios quando ele corre/avança
func _track_movement(delta: float) -> void:
	var moved: Vector2 = global_position - _last_pos
	_last_pos = global_position
	var dist: float = moved.length()
	if dist < 0.01:
		return
	# Teleporte (formação, reposição depois de gol...) não conta como movimento dele
	if dist > 150.0:
		return
	if _home_tween != null and _home_tween.is_valid() and _home_tween.is_running():
		return
	_charge_px = minf(_charge_px + dist, _charge_max_px())
	if state == State.RUNNING or _dashing:
		_bolt_timer -= delta
		if _bolt_timer <= 0.0:
			_bolt_timer = 0.045
			_spawn_bolt(moved / dist)


## Raio dourado que fica para trás
func _spawn_bolt(move_dir: Vector2) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var back: Vector2 = -move_dir
	var side: Vector2 = back.orthogonal()
	var length: float = randf_range(46.0, 78.0)
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var segments: int = 4
	for i in range(1, segments + 1):
		var t: float = float(i) / float(segments)
		var jitter: float = randf_range(-9.0, 9.0) * (1.0 - t * 0.4)
		pts.append(back * length * t + side * jitter)
	var bolt := LokiBolt.new()
	bolt.points = pts
	parent.add_child(bolt)
	bolt.global_position = global_position + Vector2(0.0, -height) \
		+ side * randf_range(-6.0, 6.0)
	bolt.z_as_relative = false
	bolt.z_index = int(global_position.y) + 1


# ---------- DERRUBADO ----------

func knock_down() -> void:
	super()
	_clear_prey()
	queue_redraw()


# ---------- HABILIDADE 1: VITESSE DE LA LUMIÈRE / NOUVEAU GÉNIE ----------

func _vitesse_skill_name() -> String:
	if _genie_ready:
		return "Nouveau Génie"
	return skill_label("Vitesse de la Lumière", CD_VITESSE)


## O Nouveau Génie dá para usar agora? (liberado, Loki no chão e bola ao alcance do chute)
func _genie_possible() -> bool:
	if not _genie_ready or height_level != Heights.Level.GROUND:
		return false
	var ball: Ball = _get_ball()
	return _ball_is_near(ball) and get_kick_type(ball) != KickType.NONE


func _use_vitesse_skill() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	if _genie_ready:
		return await _use_genie(m)
	return await _use_vitesse(m)


## A bola está no caminho dele? (no chão ou suspensa, ao alcance do corpo dele no nível atual)
func _meets_ball(ball: Ball) -> bool:
	if ball == null or ball.is_held() or ball.is_locked_for(team):
		return false
	var level: Heights.Level = ball.get_level()
	if level == Heights.Level.FLYING or not can_reach_level(level):
		return false
	return global_position.distance_to(ball.global_position) <= vitesse_meet_radius


func _use_vitesse(m: MatchManager) -> bool:
	var aim: Vector2 = await m.aim_for_skill(self, vitesse_distance)
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação
	if height_level == Heights.Level.FLYING:
		return false
	face_towards(aim)
	if not await play_action(&"vitesse"):
		return false

	var ball: Ball = _get_ball()
	var start: Vector2 = global_position
	var start_h: float = height
	var was_suspended: bool = height_level != Heights.Level.GROUND
	var dest: Vector2 = _clamp_to_pitch(start + aim * vitesse_distance)
	var time: float = maxf(vitesse_time, 0.05)

	# Avanço: se estava suspenso, ele desce ao chão durante a trajetória
	_dashing = true
	var elapsed: float = 0.0
	var met: bool = false
	while elapsed < time:
		await get_tree().physics_frame
		if not is_inside_tree():
			break
		elapsed += get_physics_process_delta_time()
		var f: float = clampf(elapsed / time, 0.0, 1.0)
		var e: float = 1.0 - pow(1.0 - f, 2.0)
		global_position = start.lerp(dest, e)
		if was_suspended:
			height = lerpf(start_h, 0.0, e)
			if f >= 0.5:
				height_level = Heights.Level.GROUND
		if _meets_ball(ball):
			met = true
			break
	_dashing = false
	height = Heights.GROUND_HEIGHT
	height_level = Heights.Level.GROUND

	start_cooldown(CD_VITESSE, vitesse_cooldown)
	if met and not _genie_ready:
		# Encontrou a bola: +1 ação de habilidade (só dele) e libera o Nouveau Génie
		_genie_ready = true
		extra_skill_left += 1
		face_towards(ball.global_position - global_position)
		_say("Nouveau Génie!")
	queue_redraw()
	return true


## Nouveau Génie: chute forte (50%). Bola no chão -> sobe até Suspensa na trajetória.
func _use_genie(m: MatchManager) -> bool:
	if not _genie_possible():
		return false
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação
	if not _genie_possible():
		return false

	var ball: Ball = _get_ball()
	var on_ground: bool = ball.get_level() == Heights.Level.GROUND
	# Bola no chão: "voleio" (a bola sobe até Suspensa). Bola suspensa: chute reto e forte.
	var kind: KickType = KickType.VOLLEY if on_ground else KickType.HIGH_BALL
	var base_force: float = kick_force_volley if on_ground else kick_force_high_ball
	next_kick_force_mult = genie_force / maxf(base_force, 1.0)

	_genie_ready = false   # a ação extra que veio com ele é a que foi gasta agora
	face_towards(aim)
	await kick_ball(ball, aim, kind, true, genie_chance, false, kick_fx, &"nouveau_genie")
	queue_redraw()
	return true


# ---------- HABILIDADE 2: CHAR D'ASSAUT / RENVERSÉ / TOO SLOW ----------

func get_assault_variant() -> AssaultVariant:
	var ball: Ball = _get_ball()
	# Suspenso com a bola suspensa/voando por perto (e um aliado para receber): Too Slow
	if height_level == Heights.Level.SUSPENDED and _ball_is_near(ball):
		var level: Heights.Level = ball.get_level()
		if (level == Heights.Level.SUSPENDED or level == Heights.Level.FLYING) \
				and _has_ally_in_range(too_slow_pass_range):
			return AssaultVariant.TOO_SLOW
	# No chão com um inimigo no chão ao alcance: Char d'Assaut
	if height_level == Heights.Level.GROUND and _any_enemy_in_range(assault_range, true):
		return AssaultVariant.ASSAULT
	return AssaultVariant.NONE


func _assault_skill_name() -> String:
	var base: String = "Too Slow" if get_assault_variant() == AssaultVariant.TOO_SLOW else "Char d'Assaut"
	return skill_label(base, CD_ASSAULT)


func _use_assault_skill() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	match get_assault_variant():
		AssaultVariant.ASSAULT:
			return await _use_assault(m)
		AssaultVariant.TOO_SLOW:
			return await _use_too_slow(m)
	return false


## Stun: trava total no inimigo. Cobre o PRÓXIMO turno do time dele: se ele ainda joga nesta
## rodada, vale a rodada atual; se já jogou, vale a rodada seguinte.
func _stun(target: Player) -> void:
	var m: MatchManager = _get_manager()
	var plays_later: bool = m != null and m.turns_played < m.team_count - 1
	target.apply_lock(self, 1 if plays_later else 2, false)


func _duel() -> bool:
	return randf() < assault_chance


func _use_assault(m: MatchManager) -> bool:
	var target: Player = await m.pick_ally_for_skill(self, assault_range, true,
		Callable(self, "_is_grounded_enemy"))
	if target == null:
		return false   # cancelou: não gasta a ação
	# A situação pode ter mudado enquanto ele escolhia o alvo
	if get_assault_variant() != AssaultVariant.ASSAULT or not _is_grounded_enemy(target):
		return false

	face_towards(target.global_position - global_position)
	if not await play_action(&"assault"):
		return false
	await _dash_to(_spot_next_to(target, target.body_radius), Heights.GROUND_HEIGHT,
		Heights.Level.GROUND, assault_dash_time)
	start_cooldown(CD_ASSAULT, assault_cooldown)   # a recarga começa ganhando ou perdendo

	_fought.clear()
	_fought.append(target)
	if not _duel():
		_say("Perdeu o confronto")
		return true
	_stun(target)   # o 1º inimigo leva stun
	_say("Char d'Assaut!")

	# Correr curto e mais veloz. Esbarrando em outro inimigo: Renversé (sem stun)
	var run_time: float = assault_run_time
	var repeats: int = 0
	while true:
		var met: Player = await _assault_run(run_time, assault_run_boost)
		if met == null or repeats >= renverse_max_repeats:
			break
		_fought.append(met)
		if not _duel():
			_say("Renversé falhou")
			break
		repeats += 1
		run_time = renverse_run_time   # a duração só diminui na 2ª corrida; as outras repetem essa
		_say("Renversé!")
	_fought.clear()
	queue_redraw()
	return true


## Correr de habilidade: mesma mecânica do Correr (WASD), com duração e velocidade próprias, e
## sem gastar o limite de Correr por turno. Devolve o inimigo em que esbarrou (null = acabou o tempo).
func _assault_run(duration: float, boost: float) -> Player:
	_run_boost = boost
	var saved_duration: float = run_duration
	run_duration = duration
	start_run()
	run_duration = saved_duration
	runs_this_turn = maxi(runs_this_turn - 1, 0)

	var met: Player = null
	while state == State.RUNNING and is_inside_tree():
		await get_tree().physics_frame
		if state != State.RUNNING:
			break
		met = _find_contact()
		if met != null:
			velocity = Vector2.ZERO
			state = State.IDLE
			queue_redraw()
			break
	_run_boost = 1.0
	return met


## Inimigo no chão, em pé e ainda não enfrentado, que o Loki está encostando
func _find_contact() -> Player:
	for p: Player in get_tree().get_nodes_in_group("players"):
		if not _is_grounded_enemy(p) or _fought.has(p):
			continue
		if global_position.distance_to(p.global_position) <= body_radius + p.body_radius + contact_pad:
			return p
	return null


## Too Slow: salta até a bola, domina, desce ao chão com ela e dá um passe rasteiro ao aliado
func _use_too_slow(m: MatchManager) -> bool:
	var target: Player = await m.pick_ally_for_skill(self, too_slow_pass_range, false)
	if target == null:
		return false   # cancelou: não gasta a ação
	if get_assault_variant() != AssaultVariant.TOO_SLOW:
		return false

	var ball: Ball = _get_ball()
	face_towards(ball.global_position - global_position)
	if not await play_action(&"too_slow", ANIM_VOLLEY):
		return false

	# A bola "espera" no ar enquanto ele salta até ela
	m.clear_pending_pass()   # se era um passe alto em andamento, a bola agora é do Loki
	ball.register_touch(self)
	ball.hovering = true
	var level: Heights.Level = ball.get_level()
	var dir: Vector2 = global_position - ball.global_position
	dir = dir.normalized() if dir.length() > 1.0 else Vector2(-facing, 0.0)
	var gap: float = body_radius + ball.collision_radius + 2.0
	await _dash_to(ball.global_position + dir * gap, Heights.to_height(level), level, too_slow_leap_time)

	# Domina e desce ao chão com a bola
	var land_point: Vector2 = global_position + Vector2(facing, 0.0) * gap
	ball.hover_to(land_point, Heights.GROUND_HEIGHT, 0.25)
	await _dash_to(global_position, Heights.GROUND_HEIGHT, Heights.Level.GROUND, 0.25)
	ball.release_hover()
	ball.velocity = Vector2.ZERO
	ball.vel_z = 0.0
	ball.height = Heights.GROUND_HEIGHT

	start_cooldown(CD_ASSAULT, assault_cooldown)
	# Passe rasteiro para o aliado (se ele ainda estiver ao alcance)
	if is_instance_valid(target) and not target.is_down \
			and global_position.distance_to(target.global_position) <= too_slow_pass_range:
		await m.run_ground_pass(self, target, ball)
	queue_redraw()
	return true


# ---------- HABILIDADE 3: PROIE FACILE ----------

func _use_prey_skill() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var target: Player = await m.pick_ally_for_skill(self, prey_range, true,
		Callable(self, "_is_standing_enemy"))
	if target == null:
		return false   # cancelou: não gasta a ação
	if not _is_standing_enemy(target):
		return false

	face_towards(target.global_position - global_position)
	if not await play_action(&"proie_facile"):
		return false
	await _dash_to(_spot_next_to(target, target.body_radius), Heights.GROUND_HEIGHT,
		Heights.Level.GROUND, prey_dash_time)

	_prey = target
	_prey_offset = global_position - target.global_position
	_prey_until_round = get_current_round() + prey_rounds - 1
	_prey_was_running = false
	start_cooldown(CD_PREY, prey_cooldown)
	_say("Proie Facile!")
	queue_redraw()
	return true


## O PRÓXIMO Correr do inimigo marcado fica mais lento (consultado pelo Player.get_run_speed_mult)
func run_speed_mult_on(p: Player) -> float:
	if _prey != null and p == _prey:
		return prey_run_mult
	return 1.0


## Enquanto o inimigo marcado corre, o Loki acompanha ele. Quando essa corrida acaba, o efeito
## foi usado e some.
func _update_prey_follow() -> void:
	if _prey == null:
		return
	if not is_instance_valid(_prey):
		_clear_prey()
		return
	if _prey.state == Player.State.RUNNING:
		_prey_was_running = true
		global_position = global_position.lerp(_prey.global_position + _prey_offset, 0.35)
	elif _prey_was_running:
		_clear_prey()


func _clear_prey() -> void:
	_prey = null
	_prey_was_running = false
	_prey_until_round = -1
	queue_redraw()


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"id": SKILL_VITESSE, "name": _vitesse_skill_name()})
	list.append({"id": SKILL_ASSAULT, "name": _assault_skill_name()})
	list.append({"id": SKILL_PREY, "name": skill_label("Proie Facile", CD_PREY)})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_VITESSE:
			# Com o Nouveau Génie liberado, o botão vira ele (usa a janela aberta pelo Vitesse)
			if _genie_ready:
				return _genie_possible()
			return not is_on_cooldown(CD_VITESSE) and height_level != Heights.Level.FLYING
		SKILL_ASSAULT:
			return not is_on_cooldown(CD_ASSAULT) and get_assault_variant() != AssaultVariant.NONE
		SKILL_PREY:
			return not is_on_cooldown(CD_PREY) and _prey == null and _any_enemy_in_range(prey_range, false)
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_VITESSE:
			return await _use_vitesse_skill()
		SKILL_ASSAULT:
			return await _use_assault_skill()
		SKILL_PREY:
			return await _use_prey_skill()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_VITESSE:
			if _genie_ready:
				title = "Nouveau Génie"
				text = "Chute forte com %d%% de chance de gol. Vale até o fim do turno." % _pct(genie_chance)
			else:
				title = "Vitesse de la Lumière"
				text = "Avanço longo na direção que você mirar. Se encontrar a bola, para ao lado dela, ganha +1 ação de habilidade e libera o Nouveau Génie."
			text += "\nRecarga: %d rodadas." % vitesse_cooldown
			text += "\nPassiva: corre mais rápido e, quanto mais ele se move, mais forte é o próximo chute."
		SKILL_ASSAULT:
			var ass_text: String = "Vai até um inimigo e disputa na sorte (%d%%). Ganhando, o inimigo fica atordoado e o Loki ganha um Correr curto e mais veloz. Se esbarrar em outro inimigo, disputa de novo." % _pct(assault_chance)
			var slow_text: String = "Salta até a bola no ar, a domina e passa rasteiro para um aliado."
			match get_assault_variant():
				AssaultVariant.ASSAULT:
					title = "Char d'Assaut"
					text = ass_text
				AssaultVariant.TOO_SLOW:
					title = "Too Slow"
					text = slow_text
				_:
					title = "Char d'Assaut / Too Slow"
					text = "Disputa na sorte com um inimigo ou salta até a bola no ar e passa para um aliado, conforme a situação."
			text += "\nRecarga: %d rodadas." % assault_cooldown
		SKILL_PREY:
			title = "Proie Facile"
			text = "Vai até um inimigo e deixa o próximo Correr dele %d%% mais lento.\nRecarga: %d rodadas." % [
				_pct(1.0 - prey_run_mult), prey_cooldown]
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()
	_charge_px = 0.0
	_dashing = false
	_run_boost = 1.0
	_genie_ready = false
	_fought.clear()
	_clear_prey()
	_last_pos = global_position
	queue_redraw()


# ---------- LOOP / VISUAL ----------

func _has_visual_state() -> bool:
	return _charge_px > 0.5 or _genie_ready or _prey != null \
		or Time.get_ticks_msec() < _say_until_msec


func _process(delta: float) -> void:
	super(delta)
	if _has_visual_state():
		queue_redraw()


func _draw() -> void:
	super()
	var center := Vector2(0.0, -height)
	var t: float = Time.get_ticks_msec() / 1000.0

	# Barra de força (passiva): enche com o movimento; brilha quando está cheia
	if _charge_px > 0.5:
		var ratio: float = clampf(_charge_px / _charge_max_px(), 0.0, 1.0)
		var bar_w: float = 36.0
		var bar_pos: Vector2 = center + Vector2(-bar_w * 0.5, -placeholder_radius - 24.0)
		draw_rect(Rect2(bar_pos, Vector2(bar_w, 5.0)), Color(0.0, 0.0, 0.0, 0.55))
		draw_rect(Rect2(bar_pos, Vector2(bar_w * ratio, 5.0)), GOLD)
		draw_rect(Rect2(bar_pos, Vector2(bar_w, 5.0)), GOLD_DARK, false, 1.0)
		if ratio >= 1.0:
			var glow: float = 0.5 + 0.5 * sin(t * 12.0)
			draw_rect(Rect2(bar_pos - Vector2(2.0, 2.0), Vector2(bar_w + 4.0, 9.0)),
				Color(GOLD_LIGHT, 0.4 + 0.4 * glow), false, 2.0)

	# Nouveau Génie liberado: anel dourado pulsando em volta dele
	if _genie_ready:
		var pulse: float = 0.5 + 0.5 * sin(t * 9.0)
		draw_arc(center, placeholder_radius + 8.0 + pulse * 3.0, 0.0, TAU, 40,
			Color(GOLD, 0.6 + 0.35 * pulse), 3.0)
		_draw_zigzag(center + Vector2(-5.0, -placeholder_radius - 12.0),
			center + Vector2(3.0, -placeholder_radius - 4.0), GOLD_LIGHT)

	# Ligação em raio até o inimigo marcado (Proie Facile)
	if _prey != null and is_instance_valid(_prey):
		var end: Vector2 = to_local(_prey.global_position) + Vector2(0.0, -_prey.height)
		_draw_zigzag(center, end, Color(GOLD, 0.85))
		draw_arc(end, _prey.placeholder_radius + 8.0, 0.0, TAU, 32, Color(GOLD, 0.8), 2.0)

	# Resultado dos confrontos
	if Time.get_ticks_msec() < _say_until_msec and _say_text != "":
		draw_string(ThemeDB.fallback_font, center + Vector2(-60.0, -placeholder_radius - 34.0),
			_say_text, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, GOLD_LIGHT)


## Linha em zigue-zague (raio) entre dois pontos locais
func _draw_zigzag(a: Vector2, b: Vector2, col: Color) -> void:
	var dir: Vector2 = b - a
	var dist: float = dir.length()
	if dist < 1.0:
		return
	dir /= dist
	var perp: Vector2 = dir.orthogonal()
	var links: int = clampi(int(dist / 16.0), 2, 14)
	var prev: Vector2 = a
	for i in range(1, links + 1):
		var p: Vector2 = a.lerp(b, float(i) / float(links))
		if i < links:
			p += perp * (5.0 if i % 2 == 0 else -5.0)
		draw_line(prev, p, Color(col, col.a * 0.35), 5.0)
		draw_line(prev, p, col, 2.0)
		prev = p


# ---------- RAIO (nó visual) ----------

## Um raio dourado que fica para trás quando o Loki corre ou avança e some rápido
class LokiBolt extends Node2D:
	var points: PackedVector2Array = PackedVector2Array()
	var life: float = 0.2
	var _age: float = 0.0

	func _process(delta: float) -> void:
		_age += delta
		if _age >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if points.size() < 2:
			return
		var a: float = 1.0 - _age / life
		draw_polyline(points, Color(Loki.GOLD, 0.35 * a), 6.0)
		draw_polyline(points, Color(Loki.GOLD_LIGHT, a), 2.0)
