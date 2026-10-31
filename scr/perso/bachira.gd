class_name Bachira
extends Player
## Bachira Meguru. Três botões de habilidade, cada um com variantes automáticas:
##
## 1. Bon! (recarga 2, compartilhada com as variantes; a variante vem da altura dele e da bola)
##      - os dois no chão                         -> Bon!: chute de letra, a bola sobe até Voando no trajeto.
##                                                   0.9x a força do Chutar, 40%
##      - bola Suspensa; ele no chão/suspenso     -> Bee Shot: voleio, 1.2x, 45%, QTE fácil
##      - bola Voando a até 100; ele suspenso/voando -> Monster Leap: vai até a bola (subindo até ela) e a chuta
##                                                   na diagonal, de volta ao chão. 1.2x, 45%, QTE fácil
## 2. Step Overs (recarga 2, compartilhada com o Freedom)
##      - bola e ele no chão: domina a bola e anda dando passadas nela. O 1º inimigo que encontrar leva uma
##        CANETA e fica atordoado (sem habilidades e sem ações gerais por 1 turno do time dele). No fim, um
##        avanço curto de 150: o 1º OUTRO inimigo que encontrar leva um CHAPÉU e ele ganha +1 ação de habilidade.
##      - Freedom (bola Suspensa; ele no chão): ele escolhe uma DIREÇÃO, salta até a bola e a toca para cima e
##        para essa direção (ela sobe até Voando e cai mais à frente, no chão). Ele cai e ganha um Correr de
##        1.1 s, mais veloz, para ir atrás dela. Se reencontrar a bola nessa corrida, ganha +1 ação de habilidade.
## 3. Unleash Instinct (recarga 3): com a bola próxima e no chão, ele faz embaixadinhas com ela grudada nele
##      (a bola sobe em arco e desce, entre o chão e o Suspenso) e pode andar, só que mais lento (250 em vez de 300).
##      Dura até o fim do próximo turno do adversário. Se um adversário tentar interagir com a bola:
##      - Carrinho: o Bachira desvia sozinho, saltando por cima do inimigo (ninguém cai);
##      - Chutar (ação geral): quem tentou é derrubado (Passar fica bloqueado);
##      - com uma habilidade: disputa de CPS por 5 s. Bachira aperta ESPAÇO, o adversário ENTER, e o
##        Bachira começa com 5 de vantagem. Se ele ganhar, mantém a bola e o time ganha +1 ação de
##        habilidade para os secundários (no próximo turno do time dele). Se perder, perde a bola.
##
## Visual (bachira_fx.gd): labaredas pretas e amarelas em todas as habilidades, abelhinhas no Bee Shot e
## no Freedom e, no Unleash Instinct, a silhueta (o "monstro") ao lado dele. Dá para desligar com
## particles_fx; a silhueta aceita uma imagem sua em monster_texture.
##
## REAÇÃO QUÍMICA WORLD (com o Otoya, veja reaction_world.gd): ao usar o Bon (qualquer variante) com um Otoya furtivo
## do time, o monstro aparece MAIOR e com uma animação (world_monster_scale) e a bola sai armada. O Otoya então usa o
## Shuriken na mesma rodada, sem ninguém tocar na bola, e ele vira o Gotcha. O Bon anota isso em last_bon.
##
## Como montar a cena: Nova Cena Herdada de player.tscn -> anexe este script ao nó raiz
## -> renomeie o nó raiz para "Bachira".
##
## PEÇAS NO RESTO DO PROJETO: a disputa de CPS depende do bola.gd (contest_owner e is_locked_for) e do
## player.gd (kick_ball, resolve_ball_contest e o Carrinho ignorando a bola disputada). Use as versões
## atualizadas desses dois arquivos.
##
## Animações opcionais (se faltar alguma, o jogo só pula): bon, bee_shot, monster_leap, step_overs,
## freedom, unleash_instinct.

const SKILL_SHOT: StringName = &"bon"
const SKILL_STEP: StringName = &"step_overs"
const SKILL_INSTINCT: StringName = &"unleash_instinct"

## Grupos de recarga (as variantes compartilham o mesmo)
const CD_SHOT: StringName = &"cd_shot"
const CD_STEP: StringName = &"cd_step"
const CD_INSTINCT: StringName = &"cd_instinct"

enum ShotVariant { NONE, BON, BEE, LEAP }
enum StepVariant { NONE, STEP, FREEDOM }

@export_group("Bon! / Bee Shot / Monster Leap")
@export_range(0.0, 1.0) var chance_bon: float = 0.40
@export_range(0.0, 1.0) var chance_bee: float = 0.45
@export_range(0.0, 1.0) var chance_leap: float = 0.45
@export var bon_force_mult: float = 0.9           # x a força do Chutar no chão
@export var bee_force_mult: float = 1.2           # x a força do Chutar daquela situação
@export var leap_force_mult: float = 1.2
@export var bon_peak_level: Heights.Level = Heights.Level.FLYING   # até onde a bola sobe no Bon!
@export var bon_max_bounces: int = 1              # quantas vezes a bola quica depois do Bon! (-1 = sem limite)
@export var leap_range: float = 100.0             # distância máxima até a bola Voando
@export var leap_time: float = 0.2                # quanto ele leva para chegar na bola
@export var shot_cooldown: int = 2
@export var skills_use_qte: bool = true           # Bee Shot e Monster Leap: QTE fácil

@export_group("Step Overs / Freedom")
@export var step_ball_range: float = 90.0         # "bola próxima"
@export var step_walk_distance: float = 220.0     # as passadas andando
@export var step_walk_speed: float = 190.0
@export var step_dash_distance: float = 150.0     # o avanço curto no fim
@export var step_dash_speed: float = 750.0
@export var step_hit_radius: float = 50.0         # "encontrar um inimigo"
@export var step_ball_offset: float = 30.0        # a bola fica à frente dele
@export var step_stun_turns: int = 1              # turnos do time inimigo atordoado (1 = o próximo)
@export var step_cooldown: int = 2
@export var freedom_range: float = 110.0          # distância máxima até a bola Suspensa
@export var freedom_jump_time: float = 0.22
@export var freedom_run_time: float = 1.1         # duração do Correr do Freedom
@export var freedom_speed_mult: float = 1.1      # fica mais veloz nesse Correr
@export var freedom_toss_distance: float = 260.0  # até onde o toque manda a bola (na direção escolhida)
@export var freedom_toss_time: float = 0.7        # tempo da bola no ar (sobe e desce)

@export_group("Unleash Instinct")
@export var instinct_range: float = 90.0          # "bola próxima"
@export var instinct_grab_time: float = 0.15
@export var instinct_ball_offset: float = 24.0    # a bola fica à frente dele
@export var instinct_move_speed: float = 250.0    # o normal é 300 (move_speed)
@export var juggle_period: float = 1.1            # segundos de cada embaixadinha (sobe, desce e toca o pé)
@export var juggle_touch_time: float = 0.12       # a bola "assenta" no pé antes de subir de novo
@export var juggle_foot_height: float = 6.0       # altura da bola quando está no pé
@export_range(0.0, 0.4) var juggle_variation: float = 0.18   # as embaixadinhas não sobem sempre iguais
@export var juggle_sway: float = 5.0              # vai de um pé ao outro (balanço lateral da bola)
@export var dodge_hop_height: float = 40.0        # o salto sobre o Carrinho de um adversário
@export var cps_seconds: float = 5.0              # duração da disputa de CPS
@export var cps_head_start: int = 3               # vantagem do Bachira (ele usa ESPAÇO; o adversário, ENTER)
@export var instinct_win_skill_actions: int = 1   # ações de habilidade para os secundários se ele ganhar
@export var instinct_cooldown: int = 3

@export_group("Visual")
## Aura + partículas dos chutes de habilidade. Vazio = usa o estilo padrão (veja _make_kick_fx)
@export var kick_fx: KickFX
## Labaredas pretas e amarelas, abelhinhas e a silhueta (bachira_fx.gd)
@export var particles_fx: bool = true
## Imagem da silhueta do Unleash Instinct (PNG com fundo transparente). Vazio = desenhada por código
@export var monster_texture: Texture2D
## Imagem de cada habilidade no balão do menu. Chaves: bon, step_overs, unleash_instinct.
@export var skill_icons: Dictionary = {}

@export_group("World (Reação Química com o Otoya)")
## Quantas vezes maior que o normal o monstro aparece quando o Bon arma a reação World
@export var world_monster_scale: float = 1.9
## Por quanto tempo (s) o monstro grande fica na tela antes de sumir
@export var world_monster_seconds: float = 1.9

## O último Bon, para a reação World (veja reaction_world.gd): {"world": Otoya, "round": rodada, "touches": toques na bola}
var last_bon: Dictionary = {}

var _instinct_on: bool = false
var _instinct_touches: int = 0          # qualquer toque na bola depois disto acaba com o Instinct
var _juggle_k: int = 0                  # número da embaixadinha atual
var _juggle_clock: float = 0.0          # tempo dentro da embaixadinha atual
var _base_speed: float = 0.0
var _contesting: bool = false           # disputa de CPS em andamento
var _team_skill_pending: int = 0        # ações de habilidade dos secundários a entregar no próximo turno do time
var _stunned: Dictionary = {}           # inimigo -> turnos do time dele que ainda faltam (Step Overs)
var _ball_lift: float = 0.0             # altura da bola durante o Step Overs (o chapéu)
var _aura: CPUParticles2D
var _monster: BachiraFX.Monster
var _wasp: Node2D

func _init() -> void:
	character_id = "bachira"   # o menu de formação usa isto para saber quem é quem
	display_name = "Bachira"

func _ready() -> void:
	super()
	# APAGUE A LINHA DA VESPA AQUI
	if kick_fx == null:
		kick_fx = _make_kick_fx()
	add_to_group("control_sources")
	if particles_fx:
		_aura = BachiraFX.make_aura()
		add_child(_aura)
	_hook_manager.call_deferred()

## Amarelo vivo; as partículas são "estrelinhas" quadradas que giram e sobem
func _make_kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = Color(1.0, 0.85, 0.2)
	fx.trail_width = 14.0
	fx.shape = KickFX.Shape.SQUARE
	fx.particle_color = Color(1.0, 0.95, 0.6)
	fx.amount = 22
	fx.lifetime = 0.55
	fx.speed_min = 15.0
	fx.speed_max = 70.0
	fx.gravity = Vector2(0.0, -60.0)
	fx.spin = 360.0
	fx.scale_min = 0.15
	fx.scale_max = 0.35
	fx.burst_amount = 14
	fx.burst_speed = 220.0
	return fx


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m:
		m.turn_ended.connect(_on_turn_ended)
		m.state_changed.connect(_on_state_changed)
	var ball: Ball = _get_ball()
	if ball:
		ball.was_reset.connect(_on_ball_reset)


func _on_ball_reset() -> void:
	_end_instinct(false)   # gol / reposição: a bola já foi solta pelo próprio Ball


## O atordoamento dura os turnos do time INIMIGO; o Instinct acaba no fim do turno adversário
func _on_turn_ended(ended_team: int) -> void:
	if _instinct_on and ended_team != team and not _contesting:
		_end_instinct(true)
	for p in _stunned.keys():
		if not is_instance_valid(p):
			_stunned.erase(p)
		elif p.team == ended_team:
			_stunned[p] = int(_stunned[p]) - 1
			if int(_stunned[p]) <= 0:
				_stunned.erase(p)
	queue_redraw()


## A ação de habilidade que o time ganhou na disputa de CPS entra quando o turno do time dele começa
## (a pool de ações é preenchida na escolha do protagonista, por isso não dá para somar antes)
func _on_state_changed() -> void:
	if _team_skill_pending <= 0:
		return
	var m: MatchManager = _get_manager()
	if m != null and m.phase == MatchManager.Phase.CHOOSING_ACTION and m.current_team == team \
			and m.protagonist != null:
		m.secondary_skill_left += _team_skill_pending
		_team_skill_pending = 0


# ---------- EFEITOS (veja bachira_fx.gd) ----------

func _body_point() -> Vector2:
	return global_position + Vector2(0.0, -height)


func _ball_point(ball: Ball) -> Vector2:
	return ball.sprite.global_position if ball.sprite != null else ball.global_position


func _flames(pos: Vector2, amount: int = 12, strong: bool = false) -> void:
	if particles_fx:
		BachiraFX.flames(self, pos, amount, strong)


func _bees(pos: Vector2, amount: int = 7) -> void:
	if particles_fx:
		BachiraFX.bees(self, pos, amount)


## Chamado pelo kick_ball() logo depois que a bola sai: labaredas (e abelhas no Bee Shot)
func _shot_fx(ball: Ball, _dir: Vector2, _speed: float, with_bees: bool) -> void:
	_flames(_ball_point(ball), 14)
	if with_bees:
		_bees(_ball_point(ball), 7)


# ---------- HABILIDADE 1: BON! / BEE SHOT / MONSTER LEAP ----------

func get_shot_variant() -> ShotVariant:
	var ball: Ball = _get_ball()
	if ball == null or is_down or ball.is_held() or ball.is_locked_for(team):
		return ShotVariant.NONE
	var level: Heights.Level = ball.get_level()
	if level == Heights.Level.FLYING:
		var near: bool = global_position.distance_to(ball.global_position) <= leap_range
		return ShotVariant.LEAP if near and height_level != Heights.Level.GROUND else ShotVariant.NONE
	if get_kick_type(ball) == KickType.NONE:   # confere alcance e altura inalcançável
		return ShotVariant.NONE
	if level == Heights.Level.SUSPENDED:
		return ShotVariant.BEE if height_level != Heights.Level.FLYING else ShotVariant.NONE
	if level == Heights.Level.GROUND and height_level == Heights.Level.GROUND:
		return ShotVariant.BON
	return ShotVariant.NONE


func _shot_skill_name() -> String:
	match get_shot_variant():
		ShotVariant.BEE:
			return "Bee Shot"
		ShotVariant.LEAP:
			return "Monster Leap"
	return "Bon!"


## Força base de cada tipo de chute (para comparar com o Chutar)
func _force_of(kind: KickType) -> float:
	match kind:
		KickType.VOLLEY:
			return kick_force_volley
		KickType.FLYING:
			return kick_force_flying
		KickType.HIGH_BALL:
			return kick_force_high_ball
	return kick_force_ground


func _use_shot_skill() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or get_shot_variant() == ShotVariant.NONE:
		return false
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação

	# A bola pode ter rolado enquanto ele mirava: confere de novo
	var ball: Ball = _get_ball()
	var variant: ShotVariant = get_shot_variant()
	if variant == ShotVariant.NONE:
		return false

	# World (Bachira + Otoya): com um Otoya furtivo do time e a reação pronta, o monstro aparece maior e a bola
	# sai "armada" (o Otoya confere isso em last_bon quando usar o Shuriken)
	var world_target: Player = ReactionWorld.bon_target(self)
	var touches_before: int = ball.interaction_count
	last_bon = {}
	if world_target != null:
		WorldFX.bon_armed(self, ball, _ball_point(ball))
		if particles_fx:
			WorldFX.summon_big_monster(self, monster_texture, world_monster_scale, world_monster_seconds)

	# Bee Shot e Monster Leap têm QTE fácil (o do Voleio); o Bon! no chão não tem
	var qte_ok: bool = true
	if variant != ShotVariant.BON and skills_use_qte and not skips_qte():
		qte_ok = await m.run_qte(KickType.VOLLEY)

	match variant:
		ShotVariant.BON:
			await _do_bon(ball, aim)
		ShotVariant.BEE:
			await _do_bee(ball, aim, qte_ok)
		ShotVariant.LEAP:
			await _do_leap(m, ball, aim, qte_ok)
	if world_target != null and is_instance_valid(ball) and ball.interaction_count != touches_before:
		last_bon = {"world": world_target, "round": m.round_number, "touches": ball.interaction_count}
	start_cooldown(CD_SHOT, shot_cooldown)
	return true


## Chute de letra: usa o voleio (a bola sobe), com o pico em Voando e a força de 0.9x o Chutar no chão
func _do_bon(ball: Ball, aim: Vector2) -> void:
	next_kick_force_mult *= bon_force_mult * kick_force_ground / maxf(kick_force_volley, 0.001)
	var previous_peak: Heights.Level = volley_peak_level
	volley_peak_level = bon_peak_level   # o kick_ball lê o pico DEPOIS da animação: só volta ao normal depois
	await kick_ball(ball, aim, KickType.VOLLEY, true, chance_bon, false, kick_fx, &"bon", _shot_fx.bind(false))
	volley_peak_level = previous_peak
	# O kick() acabou de zerar o limite de quiques: é agora que o Bon! o aplica
	if ball != null and not ball.hovering:
		ball.bounces_left = bon_max_bounces


## Voleio de 1.2x o Chutar daquela situação
func _do_bee(ball: Ball, aim: Vector2, qte_ok: bool) -> void:
	next_kick_force_mult *= bee_force_mult * _force_of(get_kick_type(ball)) / maxf(kick_force_volley, 0.001)
	await kick_ball(ball, aim, KickType.VOLLEY, qte_ok, chance_bee, false,
		kick_fx if qte_ok else null, &"bee_shot", _shot_fx.bind(true))


## Vai até a bola Voando (subindo até a altura dela) e a chuta na diagonal, de volta ao chão: o chute
## sai rente e a bola desce por conta da gravidade
func _do_leap(m: MatchManager, ball: Ball, aim: Vector2, qte_ok: bool) -> void:
	m.clear_pending_pass()
	var dir: Vector2 = aim.normalized()
	face_towards(dir)
	_flames(_body_point(), 14, true)
	var start: Vector2 = global_position
	var start_h: float = height
	var elapsed: float = 0.0
	while elapsed < leap_time and not m.match_over:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		var k: float = clampf(elapsed / leap_time, 0.0, 1.0)
		var spot: Vector2 = _clamp_to_pitch(ball.global_position - dir * (body_radius + ball.collision_radius + 6.0))
		global_position = start.lerp(spot, k)
		height = lerpf(start_h, maxf(start_h, ball.height), k)
	height_level = Heights.Level.FLYING if ball.get_level() == Heights.Level.FLYING else Heights.Level.SUSPENDED
	next_kick_force_mult *= leap_force_mult * _force_of(KickType.FLYING) / maxf(kick_force_ground, 0.001)
	await kick_ball(ball, aim, KickType.GROUND, qte_ok, chance_leap, false,
		kick_fx if qte_ok else null, &"monster_leap", _shot_fx.bind(false))
	land()


# ---------- HABILIDADE 2: STEP OVERS / FREEDOM ----------

func get_step_variant() -> StepVariant:
	var ball: Ball = _get_ball()
	if ball == null or is_down or height_level != Heights.Level.GROUND or ball.is_held() \
			or ball.is_locked_for(team):
		return StepVariant.NONE
	var dist: float = global_position.distance_to(ball.global_position)
	match ball.get_level():
		Heights.Level.GROUND:
			return StepVariant.STEP if dist <= step_ball_range else StepVariant.NONE
		Heights.Level.SUSPENDED:
			return StepVariant.FREEDOM if dist <= freedom_range else StepVariant.NONE
	return StepVariant.NONE


func _use_step_skill() -> bool:
	match get_step_variant():
		StepVariant.STEP:
			return await _use_step_overs()
		StepVariant.FREEDOM:
			return await _use_freedom()
	return false


func _dribble_point(dir: Vector2, t: float, weave: bool) -> Vector2:
	var side: Vector2 = dir.orthogonal() * (sin(t * 16.0) * 13.0 if weave else 0.0)   # a bola vai de um pé ao outro
	return global_position + dir * step_ball_offset + side


func _use_step_overs() -> bool:
	var m: MatchManager = _get_manager()
	var aim: Vector2 = await m.aim_for_skill(self, step_walk_distance)
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação
	var ball: Ball = _get_ball()
	var dir: Vector2 = aim.normalized()
	face_towards(dir)
	if not await play_action(&"step_overs") or get_step_variant() != StepVariant.STEP:
		return false
	start_cooldown(CD_STEP, step_cooldown)

	# Domina a bola: ela passa a acompanhar os pés dele
	m.clear_pending_pass()
	ball.register_touch(self)
	_ball_lift = 0.0
	ball.hover_to(_dribble_point(dir, 0.0, false), 0.0, 0.05)
	var started: Vector2 = global_position
	var hit: Array[Player] = []   # quem já foi driblado (o chapéu é em OUTRO inimigo)

	await _dribble(m, ball, dir, step_walk_distance, step_walk_speed, true, hit, false)   # passadas + caneta
	await _dribble(m, ball, dir, step_dash_distance, step_dash_speed, false, hit, true)   # avanço + chapéu
	if particles_fx:
		BachiraFX.flame_line(self, started, global_position, 16)
	ball.release_hover()
	queue_redraw()
	return true


## Anda "distance" px na direção "dir" levando a bola. O 1º inimigo (de pé, no chão e ainda não
## driblado) que ele encontrar leva a caneta (dash = false) ou o chapéu (dash = true)
func _dribble(m: MatchManager, ball: Ball, dir: Vector2, distance: float, speed: float, weave: bool,
		hit: Array[Player], dash: bool) -> void:
	var travelled: float = 0.0
	var t: float = 0.0
	var found: bool = false
	while travelled < distance and not m.match_over:
		await get_tree().physics_frame
		var dt: float = get_physics_process_delta_time()
		t += dt
		var step: float = minf(speed * dt, distance - travelled)
		var next: Vector2 = _clamp_to_pitch(global_position + dir * step)
		if next.distance_to(global_position) < 0.01:
			break   # bateu na linha do campo
		travelled += step
		global_position = next
		ball.global_position = _dribble_point(dir, t, weave)
		ball.height = _ball_lift
		if not found:
			var enemy: Player = _enemy_in_the_way(hit)
			if enemy != null:
				found = true
				hit.append(enemy)
				if dash:
					_chapeu(enemy)
				else:
					_caneta(enemy)


func _enemy_in_the_way(skip: Array[Player]) -> Player:
	var best: Player = null
	var best_dist: float = step_hit_radius
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p.team == team or p.is_down or p.height_level != Heights.Level.GROUND or skip.has(p):
			continue
		var d: float = global_position.distance_to(p.global_position)
		if d <= best_dist:
			best = p
			best_dist = d
	return best


## Caneta: a bola passa entre as pernas e o inimigo fica atordoado
func _caneta(enemy: Player) -> void:
	_stunned[enemy] = step_stun_turns
	_flames(enemy.global_position, 14, true)
	queue_redraw()


## Chapéu: a bola sobe por cima do inimigo e o Bachira ganha +1 ação de habilidade
func _chapeu(enemy: Player) -> void:
	extra_skill_left += 1
	_flames(enemy.global_position, 14, true)
	var tw := create_tween()
	tw.tween_property(self, "_ball_lift", Heights.SUSPENDED_HEIGHT * 0.8, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_ball_lift", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Freedom: ele escolhe uma direção, salta até a bola Suspensa e a toca para cima E para essa direção (ela sobe
## até Voando e cai no chão mais à frente). Ele cai e ganha um Correr de 1.1 s, mais veloz, para ir buscá-la;
## se achar a bola de novo nesse Correr, ganha +1 ação de habilidade
func _use_freedom() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	var aim: Vector2 = await m.aim_for_skill(self, freedom_toss_distance)
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação
	if get_step_variant() != StepVariant.FREEDOM:
		return false   # a situação mudou enquanto ele mirava
	var dir: Vector2 = aim.normalized()
	face_towards(ball.global_position - global_position)
	if not await play_action(&"freedom") or get_step_variant() != StepVariant.FREEDOM:
		return false
	start_cooldown(CD_STEP, step_cooldown)
	m.clear_pending_pass()

	# Salta até a bola
	height_level = Heights.Level.SUSPENDED
	var start: Vector2 = global_position
	var start_h: float = height
	var spot: Vector2 = _clamp_to_pitch(ball.global_position - Vector2(facing * (body_radius + ball.collision_radius + 4.0), 0.0))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", spot, freedom_jump_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "height", maxf(start_h, ball.height), freedom_jump_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished

	# O toque: a bola sai para cima e para a direção escolhida, enquanto ele já cai e corre atrás dela
	ball.register_touch(self)
	face_towards(dir)
	_bees(_ball_point(ball), 8)
	_flames(_ball_point(ball), 12)
	var landing: Vector2 = _clamp_to_pitch(ball.global_position + dir * freedom_toss_distance)
	_freedom_toss(ball, landing)   # roda em segundo plano
	land()
	await get_tree().create_timer(land_time).timeout

	var found: bool = await _freedom_run(m, ball)
	while _toss_busy and not m.match_over:   # a bola ainda está no ar: espera ela pousar
		await get_tree().physics_frame
	if found:
		extra_skill_left += 1
	return true


## A bola do Freedom: sobe até Voando indo para o ponto de queda e desce no chão ali
var _toss_busy: bool = false

func _freedom_toss(ball: Ball, landing: Vector2) -> void:
	_toss_busy = true
	var half: float = freedom_toss_time * 0.5
	await ball.hover_to((ball.global_position + landing) * 0.5, Heights.FLYING_HEIGHT, half).finished
	await ball.hover_to(landing, Heights.GROUND_HEIGHT, half).finished
	ball.release_hover()
	_bees(_ball_point(ball), 6)
	_toss_busy = false


## O Correr do Freedom: 1.1 s, mais veloz, e que NÃO gasta o limite de Correr do turno.
## Devolve true se ele alcançou a bola de novo no caminho.
func _freedom_run(m: MatchManager, ball: Ball) -> bool:
	var speed_before: float = move_speed
	var duration_before: float = run_duration
	move_speed = speed_before * freedom_speed_mult
	run_duration = freedom_run_time
	start_run()
	runs_this_turn -= 1
	var found: bool = false
	while state == State.RUNNING and not m.match_over:
		await get_tree().physics_frame
		if not found and get_kick_type(ball) != KickType.NONE:
			found = true
	move_speed = speed_before
	run_duration = duration_before
	return found


## Atordoado (Step Overs): sem habilidades e sem ações gerais (veja control_sources no player.gd)
func suppresses_skills_of(p: Player) -> bool:
	return _stunned.has(p)


func suppresses_generals_of(p: Player) -> bool:
	return _stunned.has(p)


## Enquanto o Instinct segura a bola, o adversário não pode Passar (Chutar e Carrinho caem na derrubada)
func blocks_general_action(p: Player, action: int) -> bool:
	return _instinct_on and p.team != team and action == MatchManager.GeneralAction.PASS


# ---------- HABILIDADE 3: UNLEASH INSTINCT ----------

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


## Bola próxima, no chão, e ele também no chão
func _can_hold_ball() -> bool:
	var ball: Ball = _get_ball()
	if ball == null or is_down or height_level != Heights.Level.GROUND or ball.is_held() \
			or ball.is_locked_for(team) or ball.get_level() != Heights.Level.GROUND:
		return false
	return global_position.distance_to(ball.global_position) <= instinct_range


func _hold_point() -> Vector2:
	return global_position + Vector2(facing * instinct_ball_offset, 0.0)


func _use_instinct() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or not _can_hold_ball():
		return false
	face_towards(_get_ball().global_position - global_position)
	if not await play_action(&"unleash_instinct"):
		return false
	var ball: Ball = _get_ball()
	if not _can_hold_ball():   # a bola pode ter saído do alcance durante a animação
		return false

	m.clear_pending_pass()                       # passe alto em andamento: a bola agora é do Bachira
	ball.register_touch(self)
	ball.hover_to(_hold_point(), 0.0, instinct_grab_time)
	await get_tree().create_timer(instinct_grab_time).timeout

	_instinct_touches = ball.interaction_count   # qualquer toque depois disto acaba com o Instinct
	ball.spell_owner = self                      # a bola é dele: o adversário só consegue TENTAR (disputa)
	ball.contest_owner = self                    # chute/habilidade dele caem no resolve_ball_contest()
	slide_immune = true                          # Carrinho: ele salta por cima sozinho (hop_over)
	_juggle_k = 0
	_juggle_clock = 0.0
	_base_speed = move_speed
	move_speed = instinct_move_speed             # um pouco mais lento (250 em vez de 300)
	_instinct_on = true
	start_cooldown(CD_INSTINCT, instinct_cooldown)

	_flames(_body_point(), 16, true)
	if _aura:
		_aura.emitting = true
	if particles_fx and _monster == null:
		_monster = BachiraFX.summon_monster(self, monster_texture)
	queue_redraw()
	return true


## Enquanto segura a bola: ela acompanha o Bachira fazendo embaixadinhas (em arco, entre o chão e o
## Suspenso). O Carrinho de um adversário não derruba ninguém: ele é imune (slide_immune) e salta por
## cima sozinho (veja hop_over).
func _physics_process(delta: float) -> void:
	super(delta)
	if not _instinct_on:
		return
	var ball: Ball = _get_ball()
	# Alguém tocou/chutou a bola, ou ela foi solta por fora: o Instinct acabou
	if ball == null or ball.interaction_count != _instinct_touches or not ball.hovering or ball.is_held():
		_end_instinct(false)
		return
	if is_down:   # derrubado: perde a bola
		_end_instinct(true)
		return
	var juggle: Vector2 = _juggle_step(delta)   # x = altura da bola, y = balanço lateral
	# Quando ele salta sobre um Carrinho, a bola vai junto (sem passar do nível Suspenso)
	ball.global_position = _hold_point() + Vector2(0.0, juggle.y)
	ball.height = minf(juggle.x + minf(height, 30.0), Heights.SUSPENDED_HEIGHT * 1.4)


## O pico de cada embaixadinha varia um pouquinho (estável, sem sortear), como no pé de verdade
func _juggle_peak(k: int) -> float:
	var v: float = 0.5 + 0.5 * sin(float(k) * 2.4 + 0.7)
	return Heights.SUSPENDED_HEIGHT * (1.0 - juggle_variation * v)


## Tempo no ar: proporcional à raiz do pico (queda livre), então um toque mais baixo é mais curto
func _juggle_air_time(k: int) -> float:
	var air: float = maxf(juggle_period - juggle_touch_time, 0.2)
	return air * sqrt(_juggle_peak(k) / Heights.SUSPENDED_HEIGHT)


## Uma embaixadinha: o pé dá o toque, a bola sobe RÁPIDO no começo e vai desacelerando até o topo,
## fica um instante quase parada lá em cima, desce acelerando (parábola, como a gravidade faz) e
## assenta no pé antes do próximo toque. Devolve x = altura da bola, y = balanço de um pé ao outro.
func _juggle_step(delta: float) -> Vector2:
	_juggle_clock += delta
	var air: float = _juggle_air_time(_juggle_k)
	var cycle: float = air + juggle_touch_time
	while _juggle_clock >= cycle:
		_juggle_clock -= cycle
		_juggle_k += 1
		air = _juggle_air_time(_juggle_k)
		cycle = air + juggle_touch_time
	if _juggle_clock >= air:
		return Vector2(juggle_foot_height, 0.0)   # assentada no pé
	var u: float = _juggle_clock / air
	var peak: float = _juggle_peak(_juggle_k)
	var h: float = juggle_foot_height + 4.0 * (peak - juggle_foot_height) * u * (1.0 - u)
	var sway: float = sin(PI * (float(_juggle_k) + u)) * juggle_sway   # 0 no pé, vai para um lado e volta
	return Vector2(h, sway)


## Carrinho de adversário (o player.gd chama hop_over() em quem é slide_immune quando o carrinho chega
## perto): durante o Instinct o salto é bem mais alto, para ele passar por cima do inimigo
func hop_over(peak: float = 34.0, duration: float = 0.45) -> void:
	if _instinct_on:
		var already_hopping: bool = _hop_tween != null and _hop_tween.is_valid()
		peak = maxf(peak, dodge_hop_height)
		duration = maxf(duration, 0.5)
		if not already_hopping and not is_down:
			_flames(_body_point(), 8)
	super(peak, duration)


func _punish(p: Player) -> void:
	p.knock_down()
	_flames(p.global_position, 14, true)


## Chamado pelo kick_ball() de um ADVERSÁRIO (patch no player.gd) ANTES do chute acontecer.
## true = o chute dele pode seguir; false = foi barrado.
func resolve_ball_contest(attacker: Player, by_skill: bool) -> bool:
	if not _instinct_on:
		return true
	if not by_skill:
		_punish(attacker)   # ação geral contra a bola: é derrubado
		return false
	# Habilidade: disputa de CPS. Bachira (ESPAÇO) começa com vantagem; o adversário usa ENTER.
	_contesting = true
	var won: bool = await _cps_duel(attacker)
	_contesting = false
	if won:
		_team_skill_pending += instinct_win_skill_actions   # entra no próximo turno do time dele
		_flames(_body_point(), 18, true)
		return false
	_end_instinct(true)   # perdeu a bola: o chute do adversário segue
	return true


func _cps_duel(attacker: Player) -> bool:
	var duel := CpsDuel.new()
	duel.setup(get_display_name(), attacker.get_display_name(), cps_seconds, cps_head_start)
	get_tree().root.add_child(duel)
	var won: bool = await duel.finished
	return won


## release = true solta a bola (cai e rola); false = a bola já foi tocada/solta por outro
func _end_instinct(release: bool) -> void:
	if not _instinct_on:
		return
	_instinct_on = false
	_contesting = false
	slide_immune = false
	move_speed = _base_speed
	var ball: Ball = _get_ball()
	if ball != null:
		if ball.contest_owner == self:
			ball.contest_owner = null
		if release and ball.hovering and not ball.is_held():
			ball.release_hover()
		elif ball.spell_owner == self:
			ball.spell_owner = null
	if _aura:
		_aura.emitting = false
	if _monster != null:
		_monster.dismiss()
		_monster = null
	queue_redraw()


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var step_name: String = "Freedom" if get_step_variant() == StepVariant.FREEDOM else "Step Overs"
	var instinct_name: String = "Unleash Instinct (ativo)" if _instinct_on else "Unleash Instinct"
	return [
		{"id": SKILL_SHOT, "name": skill_label(_shot_skill_name(), CD_SHOT)},
		{"id": SKILL_STEP, "name": skill_label(step_name, CD_STEP)},
		{"id": SKILL_INSTINCT, "name": skill_label(instinct_name, CD_INSTINCT)},
	]


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_SHOT:
			return not is_on_cooldown(CD_SHOT) and get_shot_variant() != ShotVariant.NONE
		SKILL_STEP:
			return not is_on_cooldown(CD_STEP) and get_step_variant() != StepVariant.NONE
		SKILL_INSTINCT:
			return not is_on_cooldown(CD_INSTINCT) and not _instinct_on and _can_hold_ball()
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_SHOT:
			return await _use_shot_skill()
		SKILL_STEP:
			return await _use_step_skill()
		SKILL_INSTINCT:
			return await _use_instinct()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_SHOT:
			var bon_text: String = "Chute de letra: a bola sobe até Voando no trajeto. %.1fx a força do Chutar, %d%% de chance de gol." % [bon_force_mult, _pct(chance_bon)]
			var bee_text: String = "Voleio com a bola Suspensa. %.1fx a força, %d%% de chance de gol. QTE fácil." % [bee_force_mult, _pct(chance_bee)]
			var leap_text: String = "Com a bola Voando a até %d, vai até ela e a chuta na diagonal, de volta ao chão. %.1fx a força, %d%% de chance de gol. QTE fácil." % [int(leap_range), leap_force_mult, _pct(chance_leap)]
			match get_shot_variant():
				ShotVariant.BEE:
					title = "Bee Shot"
					text = bee_text
				ShotVariant.LEAP:
					title = "Monster Leap"
					text = leap_text
				ShotVariant.BON:
					title = "Bon!"
					text = bon_text
				_:
					title = "Bon! / Bee Shot / Monster Leap"
					text = "Muda conforme a altura dele e da bola.\n%s\n%s\n%s" % [bon_text, bee_text, leap_text]
			text += "\nRecarga: %d rodadas." % shot_cooldown
		SKILL_STEP:
			if get_step_variant() == StepVariant.FREEDOM:
				title = "Freedom"
				text = "Você escolhe uma direção: ele salta até a bola Suspensa e a toca para cima e para lá (cai no chão a %d de distância). Ao cair, ganha um Correr de %.1f s, mais veloz, para ir buscá-la; se reencontrar a bola, ganha +1 ação de habilidade." % [int(freedom_toss_distance), freedom_run_time]
			else:
				title = "Step Overs"
				text = "Domina a bola e anda dando passadas nela. O 1º inimigo que encontrar leva uma caneta e fica atordoado (sem habilidades e ações gerais por %d turno). No fim, um avanço de %d: o 1º outro inimigo leva um chapéu e ele ganha +1 ação de habilidade." % [step_stun_turns, int(step_dash_distance)]
			text += "\nRecarga: %d rodadas (compartilhada com o Freedom)." % step_cooldown
		SKILL_INSTINCT:
			title = "Unleash Instinct"
			text = "Com a bola próxima e no chão, faz embaixadinhas com ela grudada nele e pode andar mais devagar (%d). Se um adversário der Carrinho, ele salta por cima sozinho; quem tentar Chutar é derrubado; com uma habilidade, entra numa disputa de CPS de %d s (ESPAÇO dele contra ENTER do adversário, ele começa com %d de vantagem). Se ganhar, mantém a bola e os secundários ganham +%d ação de habilidade.\nRecarga: %d rodadas." % [
				int(instinct_move_speed), int(cps_seconds), cps_head_start, instinct_win_skill_actions, instinct_cooldown]
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()
	_end_instinct(true)
	_stunned.clear()
	_team_skill_pending = 0
	last_bon = {}
	if _base_speed > 0.0:
		move_speed = _base_speed
	queue_redraw()


# ---------- LOOP / VISUAL ----------

func _process(delta: float) -> void:
	super(delta)
	# O anel do Instinct e as "estrelinhas" dos atordoados giram: precisa redesenhar toda hora
	if _instinct_on or not _stunned.is_empty():
		queue_redraw()


func _draw() -> void:
	super()
	var center := Vector2(0.0, -height)

	# Anel preto e amarelo enquanto o Unleash Instinct está valendo
	if _instinct_on:
		var pulse: float = 1.0 + 0.1 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
		var radius: float = (placeholder_radius + 11.0) * pulse
		draw_arc(center, radius, 0.0, TAU, 32, Color(0.05, 0.04, 0.03, 0.9), 4.0)
		draw_arc(center, radius, 0.0, TAU, 32, Color(1.0, 0.84, 0.12, 0.95), 2.0)

	# Estrelinhas girando sobre a cabeça de cada inimigo atordoado pelo Step Overs
	var t: float = Time.get_ticks_msec() / 1000.0
	for e in _stunned.keys():
		if not is_instance_valid(e):
			continue
		var head: Vector2 = to_local(e.global_position) + Vector2(0.0, -e.height - e.placeholder_radius - 14.0)
		for i in 3:
			var ang: float = t * 5.0 + TAU * float(i) / 3.0
			draw_circle(head + Vector2(cos(ang) * 12.0, sin(ang) * 4.0), 3.0, Color(1.0, 0.9, 0.25, 0.95))


# ---------- DISPUTA DE CPS (Unleash Instinct) ----------

## Janela da disputa: o Bachira aperta ESPAÇO e o adversário ENTER durante "seconds" segundos. O
## Bachira começa com "head_start" de vantagem e ganha se terminar com mais ou o mesmo que o outro.
class CpsDuel extends CanvasLayer:
	signal finished(bachira_won: bool)

	var bachira_name: String = "Bachira"
	var enemy_name: String = "Adversário"
	var seconds: float = 5.0
	var head_start: int = 5
	var _space: int = 0
	var _enter: int = 0
	var _left: float = 0.0
	var _panel: Control

	func setup(b_name: String, e_name: String, secs: float, start: int) -> void:
		bachira_name = b_name
		enemy_name = e_name
		seconds = secs
		head_start = start

	func _ready() -> void:
		layer = 100
		process_mode = Node.PROCESS_MODE_ALWAYS
		_left = seconds
		_panel = Control.new()
		_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.draw.connect(_draw_panel)
		add_child(_panel)

	func _input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key == null or not key.pressed or key.echo:
			return
		if key.keycode == KEY_SPACE:
			_space += 1
		elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			_enter += 1
		else:
			return
		get_viewport().set_input_as_handled()   # o botão focado do menu não deve reagir ao ESPAÇO/ENTER

	func _process(delta: float) -> void:
		_left -= delta
		_panel.queue_redraw()
		if _left <= 0.0:
			set_process(false)
			finished.emit(_space + head_start >= _enter)
			queue_free()

	func _draw_panel() -> void:
		var size: Vector2 = _panel.size
		var box := Rect2(size * 0.5 - Vector2(280.0, 105.0), Vector2(560.0, 210.0))
		var font: Font = ThemeDB.fallback_font
		_panel.draw_rect(box, Color(0.03, 0.03, 0.03, 0.85))
		_panel.draw_rect(box, Color(1.0, 0.84, 0.12), false, 3.0)
		_panel.draw_string(font, box.position + Vector2(0.0, 34.0), "DISPUTA DE BOLA!", HORIZONTAL_ALIGNMENT_CENTER,
			box.size.x, 26, Color(1.0, 0.84, 0.12))
		_panel.draw_string(font, box.position + Vector2(0.0, 62.0), "%.1f s" % maxf(_left, 0.0), HORIZONTAL_ALIGNMENT_CENTER,
			box.size.x, 20, Color.WHITE)
		var b_total: int = _space + head_start
		var top: float = maxf(20.0, float(maxi(b_total, _enter)) + 5.0)
		_draw_bar(box, 0, "%s  [ESPAÇO]" % bachira_name, "%d (+%d)" % [_space, head_start],
			float(b_total) / top, Color(1.0, 0.84, 0.12))
		_draw_bar(box, 1, "%s  [ENTER]" % enemy_name, "%d" % _enter, float(_enter) / top, Color(0.9, 0.9, 0.95))

	func _draw_bar(box: Rect2, row: int, label: String, value: String, fill: float, color: Color) -> void:
		var font: Font = ThemeDB.fallback_font
		var y: float = box.position.y + 90.0 + float(row) * 52.0
		_panel.draw_string(font, Vector2(box.position.x + 20.0, y), label, HORIZONTAL_ALIGNMENT_LEFT, 360.0, 16, Color.WHITE)
		_panel.draw_string(font, Vector2(box.position.x, y), value, HORIZONTAL_ALIGNMENT_RIGHT, box.size.x - 20.0, 16, color)
		var bar := Rect2(Vector2(box.position.x + 20.0, y + 8.0), Vector2(box.size.x - 40.0, 14.0))
		_panel.draw_rect(bar, Color(0.15, 0.15, 0.15, 0.9))
		_panel.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(fill, 0.0, 1.0), bar.size.y)), color)
