class_name Bunny
extends Player
## Bunny. Herda tudo do Player (ações gerais) e adiciona as habilidades próprias:
##
## 1. Bun Kick (ação de habilidade, 2 variantes automáticas pela altura; recarga de 2 rodadas,
##      compartilhada entre as duas):
##      - Bunny no chão + bola no chão   -> Bun Kick: chute que sobe até Suspenso, com pouca curva (45%)
##      - bola Suspensa ou Voando        -> Hare Leap: Bunny salta até a bola e chuta com mais curva (50%)
## 2. Apathic Return (ação de habilidade, recarga de 2 rodadas): Bunny e bola no chão/suspensos.
##      Passe rasteiro para um aliado (alcance 450) -> Bunny ganha um Correr curto -> o aliado devolve
##      um passe alto com QTE difícil -> Bunny salta até a bola (fica Voando) e ganha +1 ação de habilidade.
##      Se o QTE falhar, o aliado devolve só um passe rasteiro: sem salto e sem a ação extra.
## 3. Scars (ação de habilidade, recarga de 2 rodadas): Bunny vai até um inimigo e o impede de pular
##      por 2 rodadas (ou até Bunny se afastar). Se ele tentar pular, quem sobe é o Bunny.
##
## Passivas:
## - Insensitive: ação "Planar" própria. NÃO gasta ação (geral nem de habilidade), mas tem QTE fácil.
##      Bunny precisa estar no ar. Ele (e a bola, se estiver perto) se movem no ar e continuam lá por
##      mais uma rodada. Aparece no menu como botão de habilidade gratuito (1 vez por turno).
## - Fake Fun: +4% de chance a cada gol dele, +1% a cada QTE acertado; o mesmo valor negativo ao errar
##      um QTE ou ao time dele tomar gol. Vale para os chutes dele (ex: 25% vira 29%).
##
## Como montar a cena: Nova Cena Herdada de player.tscn -> anexe este script ao nó raiz
## -> renomeie o nó raiz para "Bunny".
##
## IMPORTANTE: precisa do player.gd atualizado (jump_redirected + consume_jump_redirect), usado pelo Scars.

const SKILL_KICK: StringName = &"bun_kick"
const SKILL_APATHIC: StringName = &"apathic_return"
const SKILL_SCARS: StringName = &"scars"
const SKILL_PLANAR: StringName = &"planar"

## Grupos de recarga (Bun Kick e Hare Leap compartilham o mesmo)
const CD_KICK: StringName = &"cd_kick"
const CD_APATHIC: StringName = &"cd_apathic"
const CD_SCARS: StringName = &"cd_scars"

const LAVENDER := Color(0.72, 0.62, 0.96)
const LIGHT_RED := Color(1.0, 0.58, 0.58)
const PLANAR_BALL_OFFSET: float = 24.0   # a bola fica este tanto à frente do Bunny enquanto planam

enum KickVariant { NONE, BUN_KICK, HARE_LEAP }

@export_group("Bun Kick / Hare Leap")
@export_range(0.0, 1.0) var chance_bun_kick: float = 0.45
@export_range(0.0, 1.0) var chance_hare_leap: float = 0.50
@export var kick_cooldown: int = 2                  # recarga (rodadas), igual para as 2 variantes
## Curva total do chute (graus que a bola vira no caminho). Ela sempre curva para o lado do centro do campo.
@export var bun_kick_curve_deg: float = 12.0        # "pouca curva"
@export var hare_leap_curve_deg: float = 12.0       # "um pouco mais de curva"
@export var curve_time: float = 0.2                 # por quanto tempo a bola vai curvando (s)
@export var leap_range: float = 160.0               # distância máxima até a bola para o Hare Leap
@export var leap_time: float = 0.3                  # duração do salto até a bola (s)

@export_group("Apathic Return")
@export var apathic_range: float = 450.0            # alcance do passe rasteiro
@export var apathic_return_range: float = 550.0     # alcance da devolução (passe alto)
@export var apathic_run_time: float = 0.8           # Correr curto (s)
@export var apathic_bonus_skills: int = 1           # ações de habilidade extras ao final
@export var apathic_cooldown: int = 2

@export_group("Scars")
@export var scars_range: float = 175.0              # até onde Bunny escolhe o inimigo
@export var scars_rounds: int = 2                   # duração total em rodadas (contando a atual)
@export var scars_break_distance: float = 160.0     # mais longe que isso, o efeito acaba
@export var scars_stand_distance: float = 50.0      # onde Bunny para, perto do inimigo
@export var scars_dash_time: float = 0.3
@export var scars_cooldown: int = 2

@export_group("Insensitive (Planar)")
@export var planar_run_time: float = 0.5            # quanto tempo ele se move no ar (s)
@export var planar_carry_radius: float = 130.0       # "bola próxima": raio para levar a bola junto
@export var planar_extra_rounds: int = 0            # rodadas a mais no ar
@export var planar_uses_per_turn: int = 1

@export_group("Fake Fun")
@export_range(0.0, 0.2) var fun_goal_step: float = 0.04   # gol (dele: +, tomado: -)
@export_range(0.0, 0.2) var fun_qte_step: float = 0.01    # QTE (acertou: +, errou: -)

@export_group("Visual do chute")
## Aura + partículas dos chutes de habilidade. Vazio = usa o estilo padrão do Bunny (veja _make_kick_fx)
@export var kick_fx: KickFX

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: bun_kick, apathic_return, scars, planar.
@export var skill_icons: Dictionary = {}

## Fake Fun: soma na chance dos testes dele (0.04 = +4%). Pode ficar negativa.
var _fun_bonus: float = 0.0
## Scars: inimigo marcado e até que rodada vale
var _scars_target: Player = null
var _scars_until_round: int = -1
## Planar: fica no ar até o fim desta rodada (-1 = sem efeito); a bola que veio junto cai com ele
var _planar_hold_until: int = -1
var _planar_ball_hover: bool = false
var _planar_carrying: bool = false
var _planar_uses: int = 0
## Está dentro de uma habilidade de chute (o QTE do Chutar geral só conta fora delas)
var _skill_kick: bool = false
## Rodopios dos saltos (tempo restante do efeito desenhado)
var _swirl_time: float = 0.0


func _init() -> void:
	character_id = "bunny"   # o menu de formação usa isto para saber quem é quem
	display_name = "Bunny"


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = _make_kick_fx()
	_hook_manager.call_deferred()   # o MatchManager entra na árvore no mesmo frame


## Lavanda com partículas vermelho claro
func _make_kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = LAVENDER
	fx.trail_width = 16.0
	fx.particle_color = LIGHT_RED
	fx.amount = 24
	fx.lifetime = 0.6
	fx.speed_min = 15.0
	fx.speed_max = 80.0
	fx.gravity = Vector2(0.0, -40.0)
	fx.spin = 240.0
	fx.swirl = 30.0
	fx.scale_min = 0.15
	fx.scale_max = 0.35
	fx.burst_amount = 14
	fx.burst_speed = 240.0
	return fx


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m == null:
		return
	m.goal_scored.connect(_on_goal_scored)
	m.turn_started.connect(_on_turn_started)
	m.bonus_turn_started.connect(_on_turn_started)
	m.round_started.connect(func(_r: int) -> void: queue_redraw())


## Começou o turno do time do Bunny: o Planar volta a poder ser usado
func _on_turn_started(started_team: int) -> void:
	if started_team == team:
		_planar_uses = 0


# ---------- FAKE FUN ----------

func _add_fun(amount: float) -> void:
	_fun_bonus += amount
	queue_redraw()


func _register_qte(success: bool) -> void:
	_add_fun(fun_qte_step if success else -fun_qte_step)


## Gol dele = +; gol tomado pelo time dele = -. (O manager guarda o autor pelo nome mostrado.)
func _on_goal_scored(goal: Dictionary) -> void:
	var scoring_team: int = int(goal.get("team", -1))
	if scoring_team == team:
		if not bool(goal.get("own_goal", false)) and String(goal.get("scorer", "")) == get_display_name():
			_add_fun(fun_goal_step)
	else:
		_add_fun(-fun_goal_step)


## Roda um QTE e já conta no Fake Fun
func _qte(kind: KickType) -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return true
	var ok: bool = await m.run_qte(kind)
	_register_qte(ok)
	return ok


## Vale também para o Chutar geral: base do tipo de chute + Fake Fun
func get_shot_chance(kind: KickType) -> float:
	return clampf(super(kind) + _fun_bonus, 0.0, 1.0)


## O Chutar geral roda o QTE no MatchManager (antes de chamar kick_ball): conta o resultado aqui.
## Dentro das habilidades de chute do Bunny não há QTE, então não conta.
func kick_ball(ball: Ball, direction: Vector2, kind: KickType, qte_success: bool = true,
		chance_override: float = -1.0, ignore_self_collision: bool = false,
		fx: KickFX = null, anim: StringName = &"", on_kick: Callable = Callable()) -> void:
	if not _skill_kick and kind != KickType.GROUND and not skips_qte():
		_register_qte(qte_success)
	await super(ball, direction, kind, qte_success, chance_override, ignore_self_collision, fx, anim, on_kick)


# ---------- BUN KICK / HARE LEAP ----------

func _kick_variant() -> KickVariant:
	var ball: Ball = _get_ball()
	if ball == null or is_down or ball.is_held() or ball.is_locked_for(team):
		return KickVariant.NONE
	var ball_level: Heights.Level = ball.get_level()
	if height_level == Heights.Level.GROUND and ball_level == Heights.Level.GROUND:
		# get_kick_type confere a distância (kick_range) e o resto
		return KickVariant.BUN_KICK if get_kick_type(ball) == KickType.GROUND else KickVariant.NONE
	if ball_level != Heights.Level.GROUND \
			and global_position.distance_to(ball.global_position) <= leap_range:
		return KickVariant.HARE_LEAP
	return KickVariant.NONE


func _kick_skill_name() -> String:
	return "Hare Leap" if _kick_variant() == KickVariant.HARE_LEAP else "Bun Kick"


func _use_kick_skill() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or _kick_variant() == KickVariant.NONE:
		return false

	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação

	# A bola pode ter mudado enquanto ele mirava: confere de novo
	var ball: Ball = _get_ball()
	var variant: KickVariant = _kick_variant()
	if variant == KickVariant.NONE:
		return false

	var kind: KickType = KickType.VOLLEY    # a bola sobe até o nível Suspenso
	var chance: float = chance_bun_kick
	var anim: StringName = &"bun_kick"
	var curve_deg: float = bun_kick_curve_deg
	if variant == KickVariant.HARE_LEAP:
		await _leap_to(ball)
		if ball.get_level() == Heights.Level.FLYING:
			kind = KickType.FLYING
		chance = chance_hare_leap
		anim = &"hare_leap"
		curve_deg = hare_leap_curve_deg

	# Sem QTE. Habilidades com chance própria somam o Fake Fun na mão (o kick_ball só soma os outros bônus)
	var on_kick := func(b: Ball, d: Vector2, _speed: float) -> void:
		_start_curve(b, d, curve_deg)
	_skill_kick = true
	await kick_ball(ball, aim, kind, true, minf(maxf(chance + _fun_bonus, 0.0), 1.0),
		false, kick_fx, anim, on_kick)
	_skill_kick = false
	start_cooldown(CD_KICK, kick_cooldown)
	return true


## Bunny salta até a bola (posição e altura) e fica no nível dela
func _leap_to(ball: Ball) -> void:
	var level: Heights.Level = ball.get_level()
	height_level = level
	face_towards(ball.global_position - global_position)
	_swirl_time = leap_time + 0.3
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", ball.global_position, leap_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "height", Heights.to_height(level), leap_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	global_position = ball.global_position   # a bola pode ter andado durante o salto


# ---------- CURVA DA BOLA ----------
# O Ball não tem chute curvo: aqui a velocidade da bola vai sendo girada aos poucos enquanto
# ela está no ar (para se alguém tocar nela, ela pousar ou ficar pairando).

func _start_curve(ball: Ball, dir: Vector2, total_deg: float) -> void:
	if total_deg == 0.0:
		return
	var total: float = deg_to_rad(total_deg) * _curve_sign(ball, dir)
	_curve_ball(ball, total)


## Curva para o lado em que fica o centro do campo (ajuda a bola a entrar em direção ao gol)
func _curve_sign(ball: Ball, dir: Vector2) -> float:
	var field := get_tree().get_first_node_in_group("field") as Field
	if field == null:
		return 1.0 if randf() < 0.5 else -1.0
	var to_center: Vector2 = field.global_position - ball.global_position
	return 1.0 if dir.cross(to_center) >= 0.0 else -1.0


func _curve_ball(ball: Ball, total_angle: float) -> void:
	var touches: int = ball.interaction_count
	var rate: float = total_angle / maxf(curve_time, 0.05)
	var elapsed: float = 0.0
	while elapsed < curve_time and is_instance_valid(ball):
		await get_tree().physics_frame
		var dt: float = get_physics_process_delta_time()
		elapsed += dt
		if ball.interaction_count != touches or ball.hovering or ball.is_on_ground():
			break
		ball.velocity = ball.velocity.rotated(rate * dt)


# ---------- APATHIC RETURN ----------

func _valid_apathic_ally(other: Player) -> bool:
	return other != self and other.team == team and not other.is_down and not other.is_pass_blocked()


## Bunny e bola no chão ou suspensos (nunca Voando), bola ao alcance do chute e aliado ao alcance do passe
func _apathic_ready() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false
	if height_level == Heights.Level.FLYING or ball.get_level() == Heights.Level.FLYING:
		return false
	if get_kick_type(ball) == KickType.NONE:
		return false
	for ally: Player in m.get_team_players(team):
		if _valid_apathic_ally(ally) \
				and global_position.distance_to(ally.global_position) <= apathic_range:
			return true
	return false


func _use_apathic_return() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null or not _apathic_ready():
		return false

	var ally: Player = await m.pick_ally_for_skill(self, apathic_range, false,
		Callable(self, "_valid_apathic_ally"))
	if ally == null:
		return false   # cancelou: não gasta a ação
	start_cooldown(CD_APATHIC, apathic_cooldown)

	# 1) passe rasteiro para o aliado
	await m.run_ground_pass(self, ally, ball)
	if m.match_over:
		return false

	# 2) Correr curto (não gasta ação nem conta no limite de Correr do turno)
	await _short_run(apathic_run_time)
	if m.match_over:
		return false

	# 3) o aliado devolve: QTE difícil
	var ok: bool = await _qte(KickType.FLYING)
	if ok:
		# passe alto de volta: a bola sobe a Voando e fica pairando no meio do caminho
		await m.run_skill_high_pass(ally, self, ball, apathic_return_range, &"", kick_fx)
		# 4) Bunny salta até ela, fica no mesmo nível (Voando) e ganha ação de habilidade extra
		await _leap_to(ball)
		extra_skill_left += apathic_bonus_skills
	else:
		# Errou o QTE: só um passe rasteiro de volta (sem salto e sem a ação extra)
		await m.run_ground_pass(ally, self, ball)
	return true


## Correr de duração própria, sem gastar o limite de Correr do turno
func _short_run(duration: float) -> void:
	var saved: float = run_duration
	run_duration = duration
	start_run()   # calcula o tempo na hora, então já dá para restaurar
	run_duration = saved
	runs_this_turn = maxi(0, runs_this_turn - 1)
	await run_finished


# ---------- SCARS ----------

func is_scars_active() -> bool:
	if _scars_target == null or not is_instance_valid(_scars_target):
		return false
	var m: MatchManager = _get_manager()
	if m == null or m.round_number > _scars_until_round:
		return false
	return global_position.distance_to(_scars_target.global_position) <= scars_break_distance


func _enemy_in_scars_range() -> bool:
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other.team != team and global_position.distance_to(other.global_position) <= scars_range:
			return true
	return false


func _use_scars() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var target: Player = await m.pick_ally_for_skill(self, scars_range, true)
	if target == null:
		return false   # cancelou: não gasta a ação

	# Bunny vai até o inimigo e para perto dele
	var away: Vector2 = global_position - target.global_position
	var dir: Vector2 = away.normalized() if away.length() > 1.0 else Vector2.RIGHT
	face_towards(-dir)
	var spot: Vector2 = target.global_position + dir * scars_stand_distance
	var tw := create_tween()
	tw.tween_property(self, "global_position", spot, scars_dash_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not await play_action(&"scars"):
		return false

	_end_scars()
	_scars_target = target
	_scars_until_round = m.round_number + scars_rounds - 1   # a rodada atual conta
	target.jumped.connect(_on_scarred_jumped)
	start_cooldown(CD_SCARS, scars_cooldown)
	queue_redraw()
	return true


func _end_scars() -> void:
	if _scars_target != null and is_instance_valid(_scars_target) \
			and _scars_target.jumped.is_connected(_on_scarred_jumped):
		_scars_target.jumped.disconnect(_on_scarred_jumped)
	_scars_target = null
	_scars_until_round = -1
	queue_redraw()


## O inimigo marcado tentou pular (qualquer pulo que passe por consume_jump_redirect do Player):
## ele não sobe e o impulso vai para o Bunny
func _on_scarred_jumped() -> void:
	if not is_scars_active():
		return
	_scars_target.jump_redirected = true
	if not is_down and height_level == Heights.Level.GROUND:
		_swirl_time = 0.8
		jump()


# ---------- INSENSITIVE (PLANAR) ----------

func _planar_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _planar_hold_until >= 0 and m.round_number <= _planar_hold_until


## Planar: precisa estar no ar, e conta como movimento (não vale travado nem sem as gerais)
func _planar_ready() -> bool:
	return height_level != Heights.Level.GROUND and not is_down and not is_locked() \
		and not is_generals_suppressed() and _planar_uses < planar_uses_per_turn


func _planar_can_carry(ball: Ball) -> bool:
	return ball != null and not ball.is_held() and not ball.is_locked_for(team) \
		and can_reach_level(ball.get_level()) \
		and global_position.distance_to(ball.global_position) <= planar_carry_radius


func _use_planar() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or not _planar_ready():
		return false
	var ball: Ball = _get_ball()
	var carry: bool = _planar_can_carry(ball)

	if not await play_action(&"planar"):
		return false
	var ok: bool = await _qte(KickType.VOLLEY)   # QTE fácil
	_planar_uses += 1
	_swirl_time = planar_run_time + 0.4

	# Deu certo e a bola está perto: ele dá um toque nela e os dois planam juntos
	if ok and carry:
		m.clear_pending_pass()
		ball.register_touch(self)
		await ball.hover_to(global_position + Vector2(facing * PLANAR_BALL_OFFSET, 0.0), height, 0.15).finished
		_planar_carrying = true
		_planar_ball_hover = true

	await _short_run(planar_run_time)
	_planar_carrying = false
	# Errou o QTE: só desliza sozinho, sem a bola e sem a rodada extra
	if ok:
		_planar_hold_until = m.round_number + planar_extra_rounds
	return true


## Enquanto planam, a bola acompanha o Bunny
func _physics_process(delta: float) -> void:
	super(delta)
	if _planar_carrying:
		var ball: Ball = _get_ball()
		if ball != null and ball.hovering and not ball.is_held():
			ball.global_position = global_position + Vector2(facing * PLANAR_BALL_OFFSET, 0.0)
			ball.height = height


## O MatchManager chama land() no começo do turno do time do Bunny: com o Planar valendo, ele fica
## no ar mais uma rodada. Quando enfim pousa, a bola que veio com ele cai junto.
func land() -> void:
	if _planar_active():
		return
	var carried: bool = _planar_ball_hover
	_planar_hold_until = -1
	_planar_ball_hover = false
	super()
	if carried:
		_release_carried_ball()


func _release_carried_ball() -> void:
	var ball: Ball = _get_ball()
	if ball != null and ball.hovering and not ball.is_held() and ball.spell_owner == null:
		ball.release_hover()


## Derrubado ou mandado de volta à formação: o Planar acaba na hora
func _end_planar_hold() -> void:
	var carried: bool = _planar_ball_hover
	_planar_hold_until = -1
	_planar_ball_hover = false
	_planar_carrying = false
	if carried:
		_release_carried_ball()


func knock_down() -> void:
	_end_planar_hold()
	super()


func return_home(duration: float = 0.0) -> void:
	_end_planar_hold()
	super(duration)


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"id": SKILL_KICK, "name": skill_label(_kick_skill_name(), CD_KICK)})
	list.append({"id": SKILL_APATHIC, "name": skill_label("Apathic Return", CD_APATHIC)})
	list.append({"id": SKILL_SCARS, "name": skill_label("Scars", CD_SCARS)})
	var planar_name: String = "Planar" if _planar_uses < planar_uses_per_turn else "Planar (usado)"
	list.append({"id": SKILL_PLANAR, "name": planar_name})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_KICK:
			return not is_on_cooldown(CD_KICK) and _kick_variant() != KickVariant.NONE
		SKILL_APATHIC:
			return not is_on_cooldown(CD_APATHIC) and _apathic_ready()
		SKILL_SCARS:
			return not is_on_cooldown(CD_SCARS) and _enemy_in_scars_range()
		SKILL_PLANAR:
			return _planar_ready()
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_KICK:
			return await _use_kick_skill()
		SKILL_APATHIC:
			return await _use_apathic_return()
		SKILL_SCARS:
			return await _use_scars()
		SKILL_PLANAR:
			return await _use_planar()
	return false


## O Planar não gasta ação (é a "ação geral própria" do Bunny): o MatchManager não cobra nada
func skill_is_free(skill_id: StringName) -> bool:
	return skill_id == SKILL_PLANAR


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_KICK:
			title = _kick_skill_name()
			if title == "Hare Leap":
				text = "Bunny salta até a bola suspensa/voando e chuta com um pouco mais de curva. %d%% de chance de gol." % _pct(chance_hare_leap)
			else:
				text = "Com Bunny e a bola no chão: o chute sobe até Suspenso, com pouca curva. %d%% de chance de gol." % _pct(chance_bun_kick)
			text += "\nRecarga: %d rodadas (compartilhada com o Hare Leap)." % kick_cooldown
		SKILL_APATHIC:
			title = "Apathic Return"
			text = ("Passe rasteiro para um aliado (alcance %d), Correr curto e o aliado devolve em passe alto (QTE difícil). "
				+ "Bunny salta até a bola e ganha +%d ação de habilidade.\nRecarga: %d rodadas.") % [
				int(apathic_range), apathic_bonus_skills, apathic_cooldown]
		SKILL_SCARS:
			title = "Scars"
			text = ("Bunny vai até um inimigo e o impede de pular por %d rodadas (ou até Bunny se afastar). "
				+ "Se ele tentar, quem pula é o Bunny.\nRecarga: %d rodadas.") % [scars_rounds, scars_cooldown]
		SKILL_PLANAR:
			title = "Planar"
			text = ("No ar, Bunny (e a bola, se estiver perto) se move e continua no ar por mais %d rodada. "
				+ "Não gasta ação, mas tem QTE fácil.") % planar_extra_rounds
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()
	_fun_bonus = 0.0
	_end_scars()
	_planar_hold_until = -1
	_planar_ball_hover = false
	_planar_carrying = false
	_planar_uses = 0
	_skill_kick = false
	_swirl_time = 0.0
	queue_redraw()


# ---------- LOOP / VISUAL ----------

func _process(delta: float) -> void:
	super(delta)
	if _swirl_time > 0.0:
		_swirl_time = maxf(0.0, _swirl_time - delta)
		queue_redraw()
	if _scars_target != null:
		if is_scars_active():
			queue_redraw()   # a linha acompanha o inimigo
		else:
			_end_scars()   # acabou o tempo, Bunny se afastou ou o inimigo saiu


func _draw() -> void:
	super()
	var center := Vector2(0.0, -height)

	# Rodopios lavanda e vermelho claro nos saltos / no Planar
	if _swirl_time > 0.0:
		var a: float = float(Time.get_ticks_msec()) / 1000.0 * 14.0
		for i in 3:
			var start_angle: float = a + TAU * float(i) / 3.0
			var c: Color = LAVENDER if i % 2 == 0 else LIGHT_RED
			draw_arc(center, placeholder_radius + 8.0 + 4.0 * float(i), start_angle, start_angle + 1.6, 12, c, 3.0)

	# Anel lavanda: ainda planando (rodada extra do Planar)
	if _planar_active():
		draw_arc(center, placeholder_radius + 6.0, 0.0, TAU, 40, Color(LAVENDER, 0.9), 2.0)

	# Scars: linha tracejada até o inimigo marcado e um anel vermelho claro nele
	if is_scars_active():
		var t: Vector2 = to_local(_scars_target.global_position + Vector2(0.0, -_scars_target.height))
		draw_dashed_line(center, t, LIGHT_RED, 2.0, 8.0)
		draw_arc(t, _scars_target.placeholder_radius + 14.0, 0.0, TAU, 32, LIGHT_RED, 2.0)

	# Fake Fun: acumulado atual em cima dele
	if absf(_fun_bonus) > 0.0001:
		var label: String = "%+d%%" % int(round(_fun_bonus * 100.0))
		draw_string(ThemeDB.fallback_font, Vector2(-14.0, -placeholder_radius - 42.0 - height),
			label, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, LAVENDER if _fun_bonus > 0.0 else LIGHT_RED)
