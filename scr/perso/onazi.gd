class_name Onazi
extends Player
## Onazi. Herda tudo do Player (ações gerais) e adiciona as habilidades próprias.
## Visual: verde escuro com branco (aura/trilha verde escura, partículas e anéis brancos).
##
## 1. Aerial Strike (ação de habilidade; recarga de 2 rodadas): chute comum MIRADO, com 45% de
##      chance de gol. Funciona com o Onazi e a bola em QUALQUER estado (chão, suspenso, voando),
##      desde que a bola esteja perto (kick_range). O tipo de chute e o QTE são os do chute comum
##      daquela situação (bola e Onazi no chão = sem QTE; o resto = QTE).
## 2. Unlimited Mobility / Hunter (mesmo botão, recarga de 3 rodadas compartilhada; a variante é
##      escolhida sozinha). Só com o Onazi no chão:
##      - SEM bola próxima -> Unlimited Mobility: um Correr mais curto, mas com ele mais rápido
##        (WASD, como o Correr normal). Se ele encontrar a bola no caminho, dá um toque e a levanta
##        para Suspensa (a corrida termina ali) e ele ganha UMA ação de habilidade extra.
##      - COM bola próxima -> Hunter: um Correr normal SEGURANDO a bola (ela anda com ele). No fim da
##        trajetória a bola é solta e ele ativa o Olhar do Predador: +8% de chance de gol nos
##        próximos 2 chutes dele (qualquer chute, inclusive o Aerial Strike).
## 3. I'm Here / Guidance (mesmo botão, recarga de 2 rodadas compartilhada; a variante é escolhida sozinha):
##      - Bola SUSPENSA ou VOANDO perto -> I'm Here: ele escolhe um aliado, salta até a bola (no nível
##        dela), domina e: bola suspensa = passe rasteiro; bola voando = passe alto que chega NA MESMA
##        RODADA (pousa Suspenso no aliado). Se o passe chegar, tira os efeitos negativos de até 2
##        aliados (penalidade de chute, confusão e trava/stun). Se nenhum aliado tem efeito negativo,
##        os secundários ganham mais uma ação geral.
##      - Bola no CHÃO perto (e o Onazi no chão) -> Guidance: passe que sobe a Suspenso e desce no aliado;
##        ao receber, o Onazi dá um avanço (dash em direção ao gol adversário) e o aliado devolve a bola
##        da mesma forma, para a posição nova do Onazi. Tudo na mesma ação.
##
## Como montar a cena: Nova Cena Herdada de player.tscn -> anexe este script ao nó raiz
## -> renomeie o nó raiz para "Onazi".
## Animações opcionais (se faltar alguma, o jogo só pula): aerial_strike, hunter, im_here, guidance.
##
## Não precisa de nenhum gancho novo no match_manager.gd nem no player.gd.

const SKILL_STRIKE: StringName = &"aerial_strike"
const SKILL_MOBILITY: StringName = &"unlimited_mobility"   # também é o Hunter (variante)
const SKILL_HERE: StringName = &"im_here"                   # também é o Guidance (variante)

## Grupos de recarga (as variantes compartilham o do pai)
const CD_STRIKE: StringName = &"cd_strike"
const CD_MOBILITY: StringName = &"cd_mobility"
const CD_HERE: StringName = &"cd_here"

const DARK_GREEN: Color = Color(0.05, 0.38, 0.18)
const LIGHT_WHITE: Color = Color(1.0, 1.0, 1.0)

enum MobilityVariant { NONE, UNLIMITED, HUNTER }
enum HereVariant { NONE, HERE, GUIDANCE }
## SEEK = correndo atrás da bola (Unlimited Mobility); CARRY = correndo com a bola (Hunter)
enum MobMode { NONE, SEEK, CARRY }

## Pico do arco da bola no Guidance (abaixo do limite do nível Voando)
const GUIDANCE_PEAK: float = 70.0

@export_group("Aerial Strike")
@export_range(0.0, 1.0) var strike_chance: float = 0.45
@export var strike_cooldown: int = 2

@export_group("Unlimited Mobility / Hunter")
@export var near_range: float = 90.0               # "bola próxima": decide entre Unlimited Mobility e Hunter
@export var mobility_cooldown: int = 3             # recarga compartilhada
@export var um_duration: float = 0.8               # Correr mais curto (o normal é run_duration)
@export var um_speed_mult: float = 1.6             # ...mas mais rápido
@export var um_contact_margin: float = 14.0        # folga (px) para "encontrar" a bola
@export var um_touch_distance: float = 30.0        # quanto a bola avança ao ser tocada
@export var um_touch_time: float = 0.25
@export var um_extra_skills: int = 1               # ações de habilidade extras ao tocar na bola
@export var hunter_grab_time: float = 0.15
@export var hunter_ball_offset: float = 24.0       # a bola fica à frente dele durante a corrida
@export_range(0.0, 1.0) var gaze_bonus: float = 0.08   # Olhar do Predador: +8% de chance de gol
@export var gaze_shots: int = 2                    # ...nos próximos 2 chutes

@export_group("I'm Here / Guidance")
@export var here_range: float = 180.0              # I'm Here: distância máxima até a bola
@export var here_dash_time: float = 0.25           # tempo do salto até a bola
@export var here_cleanse_count: int = 2            # aliados que perdem os efeitos negativos
@export var here_bonus_generals: int = 1           # ações gerais dos secundários se ninguém tinha efeito negativo
@export var guidance_range: float = 400.0          # Guidance: alcance até o aliado
@export var guidance_flight_time: float = 0.45     # subida do passe
@export var guidance_arrive_time: float = 0.3      # descida até o aliado
@export var guidance_dash_distance: float = 300.0  # avanço do Onazi depois que o aliado recebe
@export var guidance_dash_time: float = 0.3
@export var here_cooldown: int = 2                 # recarga compartilhada

@export_group("Visual")
## Aura + partículas dos chutes e passes. Vazio = usa o estilo padrão do Onazi (verde escuro + branco)
@export var kick_fx: KickFX

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: aerial_strike, unlimited_mobility, im_here.
## Sem imagem, o balão aparece só com o texto.
@export var skill_icons: Dictionary = {}

## Em que fase da corrida de habilidade ele está (ver MobMode)
var _mob_mode: MobMode = MobMode.NONE
## Multiplicador de velocidade da corrida de habilidade (1.0 fora dela)
var _run_speed_mult: float = 1.0
## Toques na bola quando o Hunter a pegou: qualquer toque depois disto solta a bola
var _carry_touches: int = 0
## Muda quando a partida reinicia: corridas/passes que estavam esperando desistem
var _epoch: int = 0
## Olhar do Predador: chutes que ainda ganham o bônus
var _gaze_shots_left: int = 0:
	set(v):
		_gaze_shots_left = v
		queue_redraw()


func _init() -> void:
	character_id = "onazi"        # o menu de formação usa isto para saber quem é quem
	display_name = "Onazi"


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = _make_kick_fx()


## Verde escuro, com partículas brancas que sobem
func _make_kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = DARK_GREEN
	fx.trail_width = 14.0
	fx.shape = KickFX.Shape.SQUARE
	fx.particle_color = LIGHT_WHITE
	fx.amount = 22
	fx.lifetime = 0.55
	fx.speed_min = 15.0
	fx.speed_max = 70.0
	fx.gravity = Vector2(0.0, -50.0)
	fx.spin = 200.0
	fx.scale_min = 0.15
	fx.scale_max = 0.35
	fx.burst_amount = 14
	fx.burst_speed = 220.0
	return fx


# ---------- UTIL ----------

## Mantém uma posição (global) dentro do campo
func _clamp_to_pitch(global_p: Vector2) -> Vector2:
	var field := get_tree().get_first_node_in_group("field") as Field
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
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", dest, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "height", target_height, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(duration).timeout


## Onde a bola fica quando ele a segura: à frente, na direção em que ele anda
func _hold_point() -> Vector2:
	var dir: Vector2 = Vector2(facing, 0.0)
	if velocity.length() > 10.0:
		dir = velocity.normalized()
	return global_position + dir * hunter_ball_offset


## Corrida de habilidade: igual ao Correr (WASD), mas com duração e velocidade próprias e sem
## gastar o limite de Correr do turno. Espera terminar.
func _skill_run(duration: float, speed_mult: float) -> void:
	_run_speed_mult = speed_mult
	run_time_left = maxf(0.0, (duration + run_time_bonus) * get_run_time_mult())
	_run_total = maxf(run_time_left, 0.001)
	state = State.RUNNING
	await run_finished
	_run_speed_mult = 1.0


## A velocidade do Correr passa a levar em conta a corrida de habilidade
func get_run_speed_mult() -> float:
	return super() * _run_speed_mult


# ---------- OLHAR DO PREDADOR (+chance nos próximos chutes) ----------

## Qualquer chute do Onazi (geral ou de habilidade) gasta um uso do Olhar do Predador.
## Os passes não passam por aqui (não são chutes).
func kick_ball(ball: Ball, direction: Vector2, kind: KickType, qte_success: bool = true,
		chance_override: float = -1.0, ignore_self_collision: bool = false,
		fx: KickFX = null, anim: StringName = &"", on_kick: Callable = Callable()) -> void:
	if _gaze_shots_left > 0:
		var base_chance: float = chance_override if chance_override >= 0.0 else get_shot_chance(kind)
		chance_override = base_chance + gaze_bonus
		_gaze_shots_left -= 1
	await super(ball, direction, kind, qte_success, chance_override, ignore_self_collision, fx, anim, on_kick)


# ---------- HABILIDADE 1: AERIAL STRIKE ----------

## Tipo de chute com o Onazi e a bola em QUALQUER estado: só precisa de bola solta, perto.
## (Ao contrário do chute comum, não exige níveis de altura vizinhos.)
func _strike_kind(ball: Ball) -> KickType:
	if ball == null or is_down or ball.is_held() or ball.is_locked_for(team):
		return KickType.NONE
	if global_position.distance_to(ball.global_position) > kick_range:
		return KickType.NONE
	var ball_level: Heights.Level = ball.get_level()
	if height_level == Heights.Level.GROUND:
		return KickType.GROUND if ball_level == Heights.Level.GROUND else KickType.HIGH_BALL
	return KickType.FLYING if ball_level == Heights.Level.FLYING else KickType.VOLLEY


func _use_strike() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or _strike_kind(_get_ball()) == KickType.NONE:
		return false

	# Primeiro mira; cancelar não gasta a ação
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false

	# A bola pode ter rolado enquanto ele mirava: confere de novo
	var ball: Ball = _get_ball()
	var kind: KickType = _strike_kind(ball)
	if kind == KickType.NONE:
		return false

	# QTE do chute comum: Onazi e bola no chão = sem QTE; o resto = com QTE
	var qte_ok: bool = true
	if kind != KickType.GROUND and not skips_qte():
		qte_ok = await m.run_qte(kind)

	# Errou o QTE = chute fraquinho, sem aura (e o kick_ball derruba o Onazi)
	await kick_ball(ball, aim, kind, qte_ok, strike_chance, false,
		kick_fx if qte_ok else null, &"aerial_strike")
	start_cooldown(CD_STRIKE, strike_cooldown)
	return true


# ---------- HABILIDADE 2: UNLIMITED MOBILITY / HUNTER ----------

## A bola está solta, ao alcance e a menos de near_range?
func _ball_near() -> bool:
	var ball: Ball = _get_ball()
	if ball == null or ball.is_held() or ball.is_locked_for(team):
		return false
	if not can_reach_level(ball.get_level()):
		return false
	return global_position.distance_to(ball.global_position) <= near_range


## Só com o Onazi no chão. Bola próxima = Hunter; sem bola próxima = Unlimited Mobility.
func get_mobility_variant() -> MobilityVariant:
	if is_down or height_level != Heights.Level.GROUND:
		return MobilityVariant.NONE
	return MobilityVariant.HUNTER if _ball_near() else MobilityVariant.UNLIMITED


func _mobility_skill_name() -> String:
	return "Hunter" if get_mobility_variant() == MobilityVariant.HUNTER else "Unlimited Mobility"


func _use_mobility() -> bool:
	match get_mobility_variant():
		MobilityVariant.UNLIMITED:
			return await _do_unlimited()
		MobilityVariant.HUNTER:
			return await _do_hunter()
	return false


## Unlimited Mobility: Correr curto e rápido; se esbarrar na bola, toca e levanta ela
func _do_unlimited() -> bool:
	var epoch: int = _epoch
	_mob_mode = MobMode.SEEK
	await _skill_run(um_duration, um_speed_mult)
	_mob_mode = MobMode.NONE
	if epoch != _epoch:
		return false   # a partida reiniciou no meio
	start_cooldown(CD_MOBILITY, mobility_cooldown)
	return true


## Enquanto corre atrás da bola: ao encostar nela, ela sobe para Suspensa e o Onazi ganha a ação extra
func _seek_ball() -> void:
	var ball: Ball = _get_ball()
	if ball == null or ball.is_held() or ball.is_locked_for(team):
		return
	if not can_reach_level(ball.get_level()):
		return
	var reach: float = body_radius + ball.collision_radius + um_contact_margin
	if global_position.distance_to(ball.global_position) > reach:
		return
	_mob_mode = MobMode.NONE   # só toca uma vez
	_touch_ball_up(ball)


func _touch_ball_up(ball: Ball) -> void:
	var m: MatchManager = _get_manager()
	if m == null:
		return
	var dir: Vector2 = velocity.normalized() if velocity.length() > 1.0 else Vector2(facing, 0.0)
	run_time_left = 0.0   # a corrida termina no toque (o _process_run encerra no próximo quadro)
	m.clear_pending_pass()
	ball.register_touch(self)
	var spot: Vector2 = _clamp_to_pitch(ball.global_position + dir * um_touch_distance)
	ball.hover_to(spot, Heights.SUSPENDED_HEIGHT, um_touch_time)
	ball.play_fx(kick_fx)
	# A bola fica pairando Suspensa; se ninguém tocar até o fim do turno, o manager a solta (cai)
	m.register_skill_pass(team, null)
	extra_skill_left += um_extra_skills


## Hunter: Correr normal segurando a bola; no fim, solta e ativa o Olhar do Predador
func _do_hunter() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null or not _ball_near():
		return false
	var epoch: int = _epoch
	face_towards(ball.global_position - global_position)
	if not await play_action(&"hunter"):
		return false
	ball = _get_ball()
	if epoch != _epoch or ball == null or not _ball_near():   # a bola pode ter saído do alcance
		return false

	m.clear_pending_pass()                       # passe alto em andamento: a bola agora é do Onazi
	ball.register_touch(self)
	ball.hover_to(_hold_point(), height, hunter_grab_time)
	await get_tree().create_timer(hunter_grab_time).timeout
	if epoch != _epoch:
		return false

	_carry_touches = ball.interaction_count      # qualquer toque depois disto solta a bola
	ball.spell_owner = self                      # ninguém mais toca na bola durante a corrida
	_mob_mode = MobMode.CARRY
	await _skill_run(run_duration, 1.0)
	_mob_mode = MobMode.NONE
	if epoch != _epoch:
		return false   # a partida reiniciou no meio

	# Fim da trajetória: solta a bola (cai ali) e ativa o Olhar do Predador
	if ball.hovering and ball.spell_owner == self and not ball.is_held():
		ball.release_hover()
	_gaze_shots_left = gaze_shots
	start_cooldown(CD_MOBILITY, mobility_cooldown)
	return true


## Enquanto corre com a bola: ela acompanha o Onazi
func _carry_ball() -> void:
	var ball: Ball = _get_ball()
	if ball == null or ball.spell_owner != self or not ball.hovering \
			or ball.interaction_count != _carry_touches:
		_mob_mode = MobMode.NONE   # alguém tocou/soltou a bola: ele só corre
		return
	ball.global_position = _hold_point()
	ball.height = height


func _physics_process(delta: float) -> void:
	super(delta)
	match _mob_mode:
		MobMode.SEEK:
			_seek_ball()
		MobMode.CARRY:
			_carry_ball()


# ---------- HABILIDADE 3: I'M HERE / GUIDANCE ----------

## Bola suspensa/voando perto = I'm Here. Bola no chão e ao alcance (Onazi no chão) = Guidance.
func get_here_variant() -> HereVariant:
	var ball: Ball = _get_ball()
	if is_down or ball == null or ball.is_held() or ball.is_locked_for(team):
		return HereVariant.NONE
	if ball.get_level() == Heights.Level.GROUND:
		return HereVariant.GUIDANCE if get_kick_type(ball) == KickType.GROUND else HereVariant.NONE
	if global_position.distance_to(ball.global_position) <= here_range:
		return HereVariant.HERE
	return HereVariant.NONE


func _here_skill_name() -> String:
	return "Guidance" if get_here_variant() == HereVariant.GUIDANCE else "I'm Here"


## Filtros do alvo: ninguém marcado contra passes (Ace Eater etc.); no Guidance, aliado caído não devolve
func _ok_here_target(p: Player) -> bool:
	return not p.is_pass_blocked()


func _ok_guidance_target(p: Player) -> bool:
	return not p.is_pass_blocked() and not p.is_down


## Tem algum aliado ao alcance da variante?
func _has_ally_in_reach(m: MatchManager, variant: HereVariant) -> bool:
	var m_reach: float = guidance_range
	if variant == HereVariant.HERE:
		m_reach = m.pass_range_for(MatchManager.PassVariant.HIGH, self)
	for other: Player in m.get_team_players(team):
		if other == self or global_position.distance_to(other.global_position) > m_reach:
			continue
		var ok: bool = _ok_guidance_target(other) if variant == HereVariant.GUIDANCE else _ok_here_target(other)
		if ok:
			return true
	return false


func _use_here() -> bool:
	match get_here_variant():
		HereVariant.HERE:
			return await _do_here()
		HereVariant.GUIDANCE:
			return await _do_guidance()
	return false


## I'm Here: salta até a bola, domina e passa (suspensa = rasteiro; voando = alto, na mesma rodada)
func _do_here() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false
	var epoch: int = _epoch
	var level: Heights.Level = ball.get_level()
	var high: bool = level == Heights.Level.FLYING
	var reach: float = m.pass_range_for(MatchManager.PassVariant.HIGH if high \
		else MatchManager.PassVariant.GROUND, self)

	# Escolhe o aliado (clique direito / Esc cancela e NÃO gasta a ação)
	var target: Player = await m.pick_ally_for_skill(self, reach, false, Callable(self, "_ok_here_target"))
	if target == null or not is_instance_valid(target):
		return false

	# A bola pode ter saído do alcance ou mudado de nível enquanto ele escolhia
	ball = _get_ball()
	if get_here_variant() != HereVariant.HERE or ball.get_level() != level:
		return false

	# Salta até a bola, no nível dela, parando "atrás" dela (do lado oposto ao do aliado)
	var gap: float = body_radius + ball.collision_radius + 2.0
	var to_target: Vector2 = target.global_position - ball.global_position
	var dir: Vector2 = to_target.normalized() if to_target.length() > 1.0 else Vector2(facing, 0.0)
	face_towards(dir)
	await _dash_to(ball.global_position - dir * gap, Heights.to_height(level), level, here_dash_time)
	if epoch != _epoch:
		return false

	# Domina a bola
	ball = _get_ball()
	m.clear_pending_pass()
	ball.register_touch(self)
	ball.hover_to(ball.global_position, height, 0.1)
	await get_tree().create_timer(0.1).timeout
	if epoch != _epoch or not is_instance_valid(target):
		return false

	var arrived: bool = false
	if high:
		arrived = await _here_high_pass(m, ball, target)
	else:
		arrived = await _here_ground_pass(m, ball, target)
	if epoch != _epoch:
		return false

	if arrived:
		_cleanse_allies(m)
	start_cooldown(CD_HERE, here_cooldown)
	return true


## Passe rasteiro (bola estava suspensa). Devolve true se a bola chegou no aliado.
func _here_ground_pass(m: MatchManager, ball: Ball, target: Player) -> bool:
	# curve_ratio 0 = reta; é o passe rasteiro normal, com a aura verde e a animação própria
	await m.run_curved_ground_pass(self, target, ball, 0.0, 1.0, &"im_here", kick_fx)
	# Se o passe não saiu (alvo colado, por exemplo), a bola não fica presa
	if ball.hovering and not ball.is_held():
		ball.release_hover()
	if not is_instance_valid(target):
		return false
	# Chegou = a bola parou encostada no aliado (interceptada no caminho = ficou longe dele)
	var gap_to_target: float = ball.collision_radius + target.body_radius + 2.0
	return ball.global_position.distance_to(target.global_position) <= gap_to_target + 8.0


## Passe alto (bola estava voando): sobe e pousa Suspensa no aliado NA MESMA RODADA
func _here_high_pass(m: MatchManager, ball: Ball, target: Player) -> bool:
	face_towards(target.global_position - global_position)
	if not await play_action(&"im_here", ANIM_PASS_HIGH):
		return false
	var point: Vector2 = target.global_position
	var mid: Vector2 = (ball.global_position + point) * 0.5
	ball.trail_enabled = true
	var previous_fx: bool = ball.fx_during_hover
	ball.fx_during_hover = true
	ball.play_fx(kick_fx)
	await ball.hover_to(mid, Heights.FLYING_HEIGHT, m.high_pass_flight_time).finished
	await ball.hover_to(point, Heights.SUSPENDED_HEIGHT, m.high_pass_arrive_time).finished
	ball.stop_fx()
	ball.fx_during_hover = previous_fx
	# Pairando Suspensa no aliado; se ninguém tocar até o fim do turno, o manager a solta
	m.register_skill_pass(team, target)
	m.pass_completed.emit(self, target)
	return true


# ---------- EFEITOS NEGATIVOS (I'm Here) ----------

## Quantos efeitos negativos o aliado tem: penalidade de chute, confusão e trava/stun
func _negative_count(p: Player) -> int:
	var n: int = 0
	if p.get_shot_debuff() > 0.0:
		n += 1
	if p.is_confused():
		n += 1
	if p.is_skill_locked():
		n += 1
	return n


func _cleanse(p: Player) -> void:
	p.clear_status_effects()   # penalidades de chute e confusão
	p.clear_lock()             # trava / stun (quem foi derrubado continua caído: é só Levantar)
	p.queue_redraw()


## O passe chegou: tira os efeitos de até here_cleanse_count aliados. Sem ninguém afetado,
## os secundários ganham ações gerais extras.
func _cleanse_allies(m: MatchManager) -> void:
	var afflicted: Array[Player] = []
	for p: Player in m.get_team_players(team):
		if p != self and _negative_count(p) > 0:
			afflicted.append(p)
	if afflicted.is_empty():
		m.secondary_general_left += here_bonus_generals
		m.state_changed.emit()   # atualiza os contadores do menu
		return
	# Os mais afetados primeiro
	afflicted.sort_custom(func(a: Player, b: Player) -> bool:
		return _negative_count(a) > _negative_count(b))
	for i in mini(here_cleanse_count, afflicted.size()):
		_cleanse(afflicted[i])


# ---------- GUIDANCE ----------

## Leva a bola em arco até um ponto: sobe a Suspenso (um pouco acima, no meio) e desce no ponto,
## tudo na mesma rodada, e fica pairando Suspensa lá.
func _arc_ball(ball: Ball, point: Vector2) -> void:
	var mid: Vector2 = (ball.global_position + point) * 0.5
	ball.trail_enabled = true
	var previous_fx: bool = ball.fx_during_hover
	ball.fx_during_hover = true
	ball.play_fx(kick_fx)
	await ball.hover_to(mid, GUIDANCE_PEAK, guidance_flight_time).finished
	await ball.hover_to(point, Heights.SUSPENDED_HEIGHT, guidance_arrive_time).finished
	ball.stop_fx()
	ball.fx_during_hover = previous_fx


func _do_guidance() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or _get_ball() == null:
		return false
	var epoch: int = _epoch

	# Escolhe o aliado (clique direito / Esc cancela e NÃO gasta a ação)
	var target: Player = await m.pick_ally_for_skill(self, guidance_range, false,
		Callable(self, "_ok_guidance_target"))
	if target == null or not is_instance_valid(target):
		return false

	# A bola pode ter saído do alcance enquanto ele escolhia
	var ball: Ball = _get_ball()
	if get_here_variant() != HereVariant.GUIDANCE:
		return false

	face_towards(target.global_position - global_position)
	if not await play_action(&"guidance", ANIM_PASS_HIGH):
		return false
	ball = _get_ball()
	if epoch != _epoch or get_kick_type(ball) != KickType.GROUND or not is_instance_valid(target):
		return false

	# 1) Passe: a bola sobe a Suspenso e desce no aliado
	m.clear_pending_pass()
	ball.register_touch(self)
	await _arc_ball(ball, target.global_position)
	if epoch != _epoch or not is_instance_valid(target):
		return false

	# 2) O aliado recebe e o Onazi avança (em direção ao gol adversário)
	await _guidance_dash()
	if epoch != _epoch or not is_instance_valid(target):
		return false

	# 3) O aliado devolve da mesma forma, para a posição nova do Onazi
	target.face_towards(global_position - target.global_position)
	await target.play_action(ANIM_PASS_HIGH)
	ball.register_touch(target)
	await _arc_ball(ball, global_position)
	if epoch != _epoch:
		return false

	# Pairando Suspensa no Onazi; se ninguém tocar até o fim do turno, o manager a solta
	m.register_skill_pass(team, self)
	m.pass_completed.emit(self, target)
	m.pass_completed.emit(target, self)
	start_cooldown(CD_HERE, here_cooldown)
	return true


## Avanço do Onazi: dash rente ao chão em direção ao gol adversário
func _guidance_dash() -> void:
	var dir: Vector2 = Vector2(facing, 0.0)
	var field := get_tree().get_first_node_in_group("field") as Field
	if field:
		var to_goal: Vector2 = field.get_attack_goal_center(team) - global_position
		if to_goal.length() > 1.0:
			dir = to_goal.normalized()
	face_towards(dir)
	var dest: Vector2 = _clamp_to_pitch(global_position + dir * guidance_dash_distance)
	await _dash_to(dest, height, height_level, guidance_dash_time)


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"id": SKILL_STRIKE, "name": skill_label("Aerial Strike", CD_STRIKE)})
	list.append({"id": SKILL_MOBILITY, "name": skill_label(_mobility_skill_name(), CD_MOBILITY)})
	list.append({"id": SKILL_HERE, "name": skill_label(_here_skill_name(), CD_HERE)})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_STRIKE:
			return not is_on_cooldown(CD_STRIKE) and _strike_kind(_get_ball()) != KickType.NONE
		SKILL_MOBILITY:
			return not is_on_cooldown(CD_MOBILITY) and get_mobility_variant() != MobilityVariant.NONE
		SKILL_HERE:
			var m: MatchManager = _get_manager()
			var variant: HereVariant = get_here_variant()
			return m != null and not is_on_cooldown(CD_HERE) and variant != HereVariant.NONE \
				and _has_ally_in_reach(m, variant)
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_STRIKE:
			return await _use_strike()
		SKILL_MOBILITY:
			return await _use_mobility()
		SKILL_HERE:
			return await _use_here()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_STRIKE:
			title = "Aerial Strike"
			text = "Chute comum com mira, com Onazi e a bola em qualquer estado. %d%% de chance de gol.\nRecarga: %d rodadas." % [
				_pct(strike_chance), strike_cooldown]
		SKILL_MOBILITY:
			var um_text: String = "Sem bola próxima, Onazi corre mais curto, porém mais rápido. Se encontrar a bola, toca e a levanta (Suspensa) e ganha %d ação de habilidade extra." % um_extra_skills
			var hunter_text: String = "Com a bola próxima, Onazi corre segurando a bola. No fim, ativa o Olhar do Predador: +%d%% de chance de gol nos próximos %d chutes." % [
				_pct(gaze_bonus), gaze_shots]
			match get_mobility_variant():
				MobilityVariant.HUNTER:
					title = "Hunter"
					text = hunter_text
				MobilityVariant.UNLIMITED:
					title = "Unlimited Mobility"
					text = um_text
				_:
					title = "Unlimited Mobility / Hunter"
					text = um_text + "\n" + hunter_text
			text += "\nRecarga: %d rodadas." % mobility_cooldown
		SKILL_HERE:
			var here_text: String = "Com a bola suspensa ou voando perto, Onazi salta até ela, domina e passa (rasteiro se suspensa; alto, que chega na mesma rodada, se voando). Se o passe chegar, tira os efeitos negativos de %d aliados (sem nenhum efeito, os secundários ganham %d ação geral)." % [
				here_cleanse_count, here_bonus_generals]
			var guidance_text: String = "Com a bola no chão perto, Onazi dá um passe que sobe e desce no aliado; ao receber, Onazi avança e o aliado devolve da mesma forma."
			match get_here_variant():
				HereVariant.GUIDANCE:
					title = "Guidance"
					text = guidance_text
				HereVariant.HERE:
					title = "I'm Here"
					text = here_text
				_:
					title = "I'm Here / Guidance"
					text = here_text + "\n" + guidance_text
			text += "\nRecarga: %d rodadas." % here_cooldown
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	_epoch += 1   # corridas/passes que estavam esperando desistem (o super() encerra a corrida)
	super()
	_mob_mode = MobMode.NONE
	_run_speed_mult = 1.0
	_gaze_shots_left = 0
	queue_redraw()


# ---------- VISUAL ----------

func _draw() -> void:
	super()
	var center := Vector2(0.0, -height)
	# Olhar do Predador: anel verde escuro com um fio branco por fora e um pontinho branco por chute que resta
	if _gaze_shots_left > 0:
		draw_arc(center, placeholder_radius + 10.0, 0.0, TAU, 40, Color(DARK_GREEN, 0.95), 3.0)
		draw_arc(center, placeholder_radius + 13.0, 0.0, TAU, 40, Color(LIGHT_WHITE, 0.8), 1.5)
		for i in _gaze_shots_left:
			var x: float = (float(i) - float(_gaze_shots_left - 1) * 0.5) * 10.0
			draw_circle(center + Vector2(x, -placeholder_radius - 22.0), 3.0, LIGHT_WHITE)
	# Anel verde escuro fino enquanto corre com a bola (Hunter)
	if _mob_mode == MobMode.CARRY:
		draw_arc(center, placeholder_radius + 5.0, 0.0, TAU, 40, Color(DARK_GREEN, 0.7), 2.0)
