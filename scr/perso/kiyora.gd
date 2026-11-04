class_name Kiyora
extends Player
## Kiyora. Herda tudo do Player (ações gerais) e adiciona as habilidades próprias
## (efeitos visuais em kiyora_fx.gd).
##
## PASSIVAS
##   Backspin (passiva): os chutes e passes dele fazem freadas bruscas e rodopios antes de chegar no alvo
##      e a bola IGNORA O PRIMEIRO OBSTÁCULO (inimigo) do trajeto. Vale para os passes das habilidades e para
##      o Chutar (kick_ball é sobrescrito aqui). Para o Passe geral (ação do MatchManager) veja os dois
##      trechos opcionais de match_manager.gd no fim da resposta (should_ignore_obstacle / pass_speed_mult).
##   Ground Utility: as ações Passe e Carrinho dele, quando ele está NO CHÃO, têm +25 de alcance
##      (Carrinho: slide_distance +25; Passe: pass_range_bonus +25 enquanto ele está no chão).
##
## EFEITO "BACKSPIN" (ativo): ligado pelo Dance Battle / Breakdance, dura backspin_rounds rodadas e melhora
##      as variantes das habilidades (Even the Gods, Twister, Backspin Shot).
##
## 1. Dance Battle (recarga 2): ele no chão, bola no chão ou suspensa ao alcance -> DOMINA a bola (ela fica
##      grudada nele) e começa um confronto. No turno inimigo, quem tentar interagir com a bola:
##        - por AÇÃO GERAL (Chutar, Carrinho, Correr perto da bola): fica ATORDOADO (cai). O Passe geral
##          inimigo fica indisponível enquanto a bola está grudada.
##        - por HABILIDADE: tem que vencer um JOGO DE RITMO. Se perder, a habilidade não sai e o Kiyora ganha o
##          Backspin; se o Backspin já estava ativo, ganha +1 ação de habilidade no lugar.
##        No máximo dance_max_stuns (2) inimigos são atordoados por Dance Battle; depois disso as ações gerais
##        dos inimigos passam sem atordoar.
##      Visual: ele GIRA dançando com a bola orbitando nele, com um redemoinho de vento em volta.
##      A bola solta no fim do turno inimigo (ou quando alguém mexe nela).
##    1.1 Breakdance (compartilha a recarga): sem a bola por perto, ele no chão joga DOIS jogos de ritmo
##      consigo mesmo. Ganhou um: +1 ação de habilidade. Ganhou os dois: também o Backspin.
## 2. Borderline (recarga 2): ele no chão, bola no chão ou suspensa. Escolhe DOIS aliados e faz um passe
##      RASTEIRO (alcance 500) para o que tiver MENOS gols (empate = sorteio).
##    2.1 Even the Gods (Backspin ativo, recarga compartilhada): igual, mas ele também escolhe o ponto do campo
##      onde a bola chega rasteira (perto de quem recebe).
## 3. Windmill (recarga 2): ele e a bola no chão. Giro acrobático que alcança a bola (alcance 200) e, se
##      conseguir, passe RASTEIRO para o aliado MAIS DISTANTE (alcance 500).
##    3.1 Twister (Backspin ativo, recarga compartilhada): dois dashes curtos (alcance 150, a bola vai junto)
##      e depois passe para um aliado ESCOLHIDO (alcance 525).
## 4. Six-Step (recarga 2): ele no chão faz 6 dashes curtos (alcance 50 cada; mira um por um). Se encontrar a bola
##      (no chão ou suspensa) DOMINA ela e continua os dashes. No fim ganha uma ação GERAL extra.
##    4.1 Backspin Shot (Backspin ativo): igual, mas no fim, além da ação geral, libera este complemento GRATUITO:
##      chute com 1.1x de força, efeito Backspin e 50% de chance (some no fim do turno do time dele).
##
## Reação Química SUPERSTAR (com o Kaiser, veja reaction_superstar.gd): se a Kiyora é o Servo Garçom
## do Empire do Kaiser e usa o Borderline / Even the Gods com ele entre os dois escolhidos, ela cria
## uma BALANÇA DOURADA da justiça (superstar_fx.gd) que pende para quem recebe a bola. Se a bola
## foi para o Kaiser, o Magnus dele vira o Be Loved.
##
## Como montar a cena: Nova Cena Herdada de player.tscn -> anexe este script ao nó raiz
## -> renomeie o nó raiz para "Kiyora".
##
## Animações opcionais (SpriteFrames; hit_frames diz o frame de impacto de cada uma):
## "dance_battle", "breakdance", "borderline", "even_the_gods", "windmill", "twister", "dash"
## (um por dash do Six-Step / Twister), "backspin_shot". Sem elas, nada quebra. O passe usa "pass".
##
## JOGO DE RITMO: usa o 4-Key Rhythm Game (rhythm_game.gd, class RhythmGame; teclas D F J K).

const SKILL_DANCE: StringName = &"dance_battle"       # sem bola por perto vira o Breakdance
const SKILL_BORDER: StringName = &"borderline"
const SKILL_WIND: StringName = &"windmill"            # com o Backspin vira o Twister
const SKILL_SIX: StringName = &"six_step"
const SKILL_SHOT: StringName = &"backspin_shot"       # complemento gratuito do Six-Step

## Grupos de recarga (as variantes de cada habilidade compartilham o mesmo)
const CD_DANCE: StringName = &"cd_dance"
const CD_BORDER: StringName = &"cd_border"
const CD_WIND: StringName = &"cd_wind"
const CD_SIX: StringName = &"cd_six"

const ANIM_DASH: StringName = &"dash"

enum PassSkill { NONE, BORDERLINE, GODS }
enum WindSkill { NONE, WINDMILL, TWISTER, SIX_STEP }   # SIX_STEP não é mais devolvido (agora é botão próprio)

## Azul escuro esverdeado
const TEAL := Color(0.05, 0.30, 0.38)
const TEAL_LIGHT := Color(0.28, 0.68, 0.64)

@export_group("Passivas")
## Freadas, rodopios e "ignora o primeiro obstáculo" nos chutes e passes dele
@export var backspin_passive: bool = true
@export var backspin_brakes: int = 1                  # quantas freadas bruscas por passe / chute
@export_range(0.05, 0.9) var backspin_brake_mult: float = 0.5   # velocidade que sobra durante a freada
@export var backspin_brake_length: float = 28.0       # passes: quantos px dura cada freada
@export var backspin_brake_time: float = 0.1          # chutes: quanto dura cada freada (s)
@export var backspin_brake_first: float = 0.12        # chutes: quando vem a primeira freada (s)
@export var backspin_brake_gap: float = 0.22          # chutes: intervalo entre freadas (s)
@export var backspin_flight_time: float = 1.2         # chutes: por quanto tempo o efeito age (s)
## Ground Utility: alcance a mais do Passe e do Carrinho quando ele está no chão
@export var ground_utility_bonus: float = 25.0

@export_group("Dance Battle / Breakdance")
@export var dance_cooldown: int = 2
@export var dance_pull_time: float = 0.25          # tempo que a bola leva para ser puxada
@export var dance_ball_offset: float = 24.0        # a bola fica grudada à frente dele
@export var dance_trigger_radius: float = 75.0     # inimigo agindo a esta distância da bola = tentou interagir
## Duração do Backspin, em rodadas depois da atual
@export var backspin_rounds: int = 3
## O texto não diz que atordoar um inimigo (ação geral) dá o Backspin; ligue se quiser o comportamento antigo
@export var stun_gives_backspin: bool = false
@export var breakdance_games: int = 2              # jogos de ritmo do Breakdance
@export var dance_max_stuns: int = 2               # máximo de inimigos atordoados por Dance Battle
@export var dance_orbit_radius: float = 30.0       # a bola gira em volta dele a esta distância
@export var dance_orbit_speed: float = 7.0         # velocidade da bola girando (rad/s)
@export var dance_spin_sprite: bool = true         # ele próprio gira (desligue se o sprite sair do lugar)
@export var dance_spin_period: float = 0.7         # tempo de uma volta dele (s)

@export_group("Borderline / Even the Gods")
@export var border_cooldown: int = 2               # recarga, igual para as duas variantes
@export var border_range: float = 500.0            # alcance do passe rasteiro
## Reação Superstar: a balança dourada fica no chão AO LADO da Kiyora (false = em cima dela)
@export var scale_beside: bool = true
## Even the Gods: a bola chega no máximo a esta distância do aliado que vai receber
@export var gods_land_radius: float = 500.0

@export_group("Windmill / Twister")
@export var wind_cooldown: int = 2                 # recarga, igual para as 2 variantes
@export var windmill_reach: float = 200.0          # alcance do giro até a bola
@export var windmill_pass_range: float = 500.0     # passe para o aliado mais distante
@export var reach_time: float = 0.2                # tempo do giro até a bola
@export var twister_dashes: int = 2
@export var twister_dash_range: float = 150.0
@export var twister_pass_range: float = 525.0

@export_group("Six-Step / Backspin Shot")
@export var six_cooldown: int = 2
@export var six_step_dashes: int = 6
@export var six_step_dash_range: float = 100.0
@export var six_step_ball_radius: float = 70.0     # a esta distância do fim de um dash ele "encontra" a bola
@export var dash_time: float = 0.14                # duração de cada dash
@export var backspin_shot_force_mult: float = 1.2
@export_range(0.0, 1.0) var backspin_shot_chance: float = 0.5

@export_group("Visual do chute")
## Aura + partículas dos passes de habilidade. Vazio = azul esverdeado (veja _make_kick_fx)
@export var kick_fx: KickFX
## Faíscas, notas e imagens residuais (kiyora_fx.gd). Desligue se quiser a versão sem partículas.
@export var particles_fx: bool = true

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: dance_battle, borderline, windmill, six_step, backspin_shot.
@export var skill_icons: Dictionary = {}

## Backspin vale até o fim desta rodada (-1 = inativo)
var _backspin_until_round: int = -1
## A bola está grudada no Kiyora (Dance Battle, Six-Step ou Twister)
var _trap_on: bool = false
var _trap_hostile: bool = false         # true = Dance Battle (confronto); false = só domínio (Six-Step / Twister)
var _trap_reward_given: bool = false    # o Backspin / ação extra deste confronto já foi dado
var _trap_touches: int = 0              # qualquer toque depois disto solta a bola
var _stuns_this_dance: int = 0          # inimigos já atordoados neste Dance Battle
var _dance_angle: float = 0.0           # ângulo da bola girando em volta dele
var _wind: Node2D = null                # redemoinho de vento do Dance Battle
var _spin_tween: Tween = null           # giro dele
var _spin_node: Node2D = null
var _sway_before: bool = true
var _trap_ring: TrapRing = null
## Muda a cada Dance Battle / partida nova: uma espera antiga percebe e para
var _dance_token: int = 0
## Último passe do Borderline / Even the Gods que foi para o Kaiser que a tem como Servo Garçom:
## {"target": Kaiser, "touches": toques da bola logo depois do passe, "gods": bool}.
## A reação Superstar lê isto (vazio = não há passe válido).
var last_border_pass: Dictionary = {}
## Backspin Shot liberado (some no fim do turno do time dele)
var _shot_ready: bool = false
## O Six-Step / Twister dominou a bola agora (ele solta no fim)
var _dominating_here: bool = false
## Ground Utility: quanto já foi somado no pass_range_bonus
var _gu_applied: float = 0.0
## Passiva Backspin: obstáculo já ignorado no passe atual (a chave é o contador de toques da bola)
var _ignore_key: int = -1
var _ignored_obstacle: Player = null
var _brake_fx_key: int = -1
var _aura: CPUParticles2D


func _init() -> void:
	character_id = "kiyora"          # o menu de formação usa isto para saber quem é quem
	display_name = "Kiyora"          # aparece no placar de gols e no menu (troque aqui se quiser)


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = _make_kick_fx()
	slide_distance += ground_utility_bonus   # Ground Utility: Carrinho (só existe no chão)
	add_to_group("control_sources")          # blocks_general_action (Passe inimigo na bola grudada)
	if particles_fx:
		KiyoraFX.warm_up()
		_aura = KiyoraFX.make_aura()
		add_child(_aura)
	_hook_manager.call_deferred()   # o MatchManager entra na árvore no mesmo frame


## Azul escuro esverdeado
func _make_kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = TEAL
	fx.trail_width = 14.0
	fx.particle_color = TEAL_LIGHT
	fx.amount = 22
	fx.lifetime = 0.55
	fx.speed_min = 15.0
	fx.speed_max = 70.0
	fx.gravity = Vector2(0.0, -40.0)
	fx.spin = 300.0
	fx.scale_min = 0.15
	fx.scale_max = 0.35
	fx.burst_amount = 14
	fx.burst_speed = 220.0
	return fx


func _exit_tree() -> void:
	_end_trap(true)


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m:
		m.round_started.connect(_on_round_started)
		m.turn_ended.connect(_on_turn_ended)
	var ball: Ball = _get_ball()
	if ball:
		ball.was_reset.connect(_on_ball_reset)


## Dance Battle: sem ninguém tocar, a bola solta no fim do turno do adversário.
## O Backspin Shot some no fim do turno do time dele.
func _on_turn_ended(ended_team: int) -> void:
	if _trap_on and ended_team != team:
		_end_trap(true)
	if ended_team == team:
		_shot_ready = false


func _on_ball_reset() -> void:
	_end_trap(false)   # gol / reposição: a bola já foi solta pelo próprio Ball


func _on_round_started(_round_number: int) -> void:
	_refresh_aura()
	queue_redraw()   # o anel do Backspin some quando as rodadas acabam


func is_backspin_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _backspin_until_round >= 0 and m.round_number <= _backspin_until_round


## Liga o efeito Backspin pelas próximas rodadas
func _activate_backspin() -> void:
	var m: MatchManager = _get_manager()
	if m == null:
		return
	_backspin_until_round = m.round_number + backspin_rounds
	_refresh_aura()
	_fx_ring(_body_pos(), 40.0, 14)
	queue_redraw()


func _refresh_aura() -> void:
	if _aura != null and is_instance_valid(_aura):
		_aura.emitting = particles_fx and is_backspin_active()
		_aura.position = Vector2(0.0, -height)


# ---------- PONTES DO FX ----------

func _body_pos() -> Vector2:
	return global_position + Vector2(0.0, -height - 24.0)


func _fx_burst(pos: Vector2, amount: int = 10, strong: bool = false) -> void:
	if particles_fx:
		KiyoraFX.burst(self, pos, amount, strong)


func _fx_ring(pos: Vector2, radius: float, amount: int = 14) -> void:
	if particles_fx:
		KiyoraFX.ring(self, pos, radius, amount)


func _fx_notes(pos: Vector2, amount: int = 6) -> void:
	if particles_fx:
		KiyoraFX.notes(self, pos, amount)


func _fx_beat(pos: Vector2, rings: int = 2, strong: bool = false) -> void:
	if particles_fx:
		KiyoraFX.beat(self, pos, rings, strong)


func _fx_dash(a: Vector2, b: Vector2) -> void:
	if particles_fx:
		KiyoraFX.dash(self, self, a, b)


func _fx_spin(ball: Ball) -> void:
	if particles_fx and ball != null:
		KiyoraFX.spin_mark(ball)


func _fx_slip(pos: Vector2) -> void:
	if particles_fx:
		KiyoraFX.slip(self, pos)


# ---------- ALIADOS (alcance / escolha) ----------

## O aliado pode receber um passe do Kiyora com este alcance? (skip = quem já foi escolhido)
func _ally_ok(p: Player, range_px: float, skip: Player) -> bool:
	return p != null and is_instance_valid(p) and p != self and p != skip and p.team == team \
		and not p.is_pass_blocked() and global_position.distance_to(p.global_position) <= range_px


func _allies_in_range(range_px: float) -> Array[Player]:
	var result: Array[Player] = []
	var m: MatchManager = _get_manager()
	if m == null:
		return result
	for p: Player in m.get_team_players(team):
		if _ally_ok(p, range_px, null):
			result.append(p)
	return result


func _farthest_ally(range_px: float) -> Player:
	var best: Player = null
	var best_dist: float = -1.0
	for p in _allies_in_range(range_px):
		var d: float = global_position.distance_to(p.global_position)
		if d > best_dist:
			best = p
			best_dist = d
	return best


## Companheiros que o Kiyora consegue alcançar com o passe geral da variante (rasteiro ou alto)
func _pass_candidates(variant: int) -> Array[Player]:
	var result: Array[Player] = []
	var m: MatchManager = _get_manager()
	if m == null:
		return result
	for p: Player in m.get_team_players(team):
		if m.can_pass_to(self, p, variant):
			result.append(p)
	return result


func _nearest_ally(variant: int) -> Player:
	var best: Player = null
	var best_dist: float = INF
	for p in _pass_candidates(variant):
		var d: float = global_position.distance_to(p.global_position)
		if d < best_dist:
			best = p
			best_dist = d
	return best


# ---------- GROUND UTILITY ----------

func _physics_process(delta: float) -> void:
	super(delta)
	_sync_ground_utility()
	_update_trap()


## Passe: +25 de alcance enquanto ele está no chão (o Carrinho já ganhou o bônus no _ready)
func _sync_ground_utility() -> void:
	var want: float = ground_utility_bonus if height_level == Heights.Level.GROUND else 0.0
	if want != _gu_applied:
		pass_range_bonus += want - _gu_applied
		_gu_applied = want


# ---------- JOGO DE RITMO ----------

## true = passou no 4-Key Rhythm Game (rhythm_game.gd)
func _rhythm_game(m: MatchManager, title: String = "Ritmo!") -> bool:
	var game := RhythmGame.new()
	m.add_child(game)
	game.start(title)
	return bool(await game.finished)


# ---------- DANCE BATTLE / BREAKDANCE ----------

## Onde a bola fica grudada: à frente do Kiyora
func _trap_point() -> Vector2:
	return global_position + Vector2(facing * dance_ball_offset, 0.0)


## Sem a bola por perto (nem alcançável) a variante é o Breakdance
func _dance_is_break() -> bool:
	return not _trap_on and get_kick_type(_get_ball()) == KickType.NONE


func _use_dance() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false
	if _dance_is_break():
		return await _use_breakdance(m)

	face_towards(ball.global_position - global_position)
	if not await play_action(&"dance_battle"):
		return false   # ação cancelada (ex: a partida reiniciou)
	# A bola pode ter saído do alcance durante a animação
	if m.match_over or not is_instance_valid(ball) or get_kick_type(ball) == KickType.NONE:
		return false
	_fx_beat(global_position, 2, true)
	if not await _grab_ball(m, ball, true):
		return false
	start_cooldown(CD_DANCE, dance_cooldown)
	return true


## Breakdance: dois jogos de ritmo consigo mesmo
func _use_breakdance(m: MatchManager) -> bool:
	_end_trap(false)
	_dance_token += 1
	var token: int = _dance_token
	if not await play_action(&"breakdance"):
		return false
	if token != _dance_token or m.match_over:
		return false
	_fx_notes(_body_pos(), 8)
	var wins: int = 0
	for i in breakdance_games:
		_fx_beat(global_position, 2)
		var ok: bool = await _rhythm_game(m, "Breakdance!")
		if token != _dance_token or m.match_over or not is_instance_valid(self):
			return false
		if ok:
			wins += 1
			_fx_burst(_body_pos(), 10)
	if wins >= 1:
		extra_skill_left += 1        # ganhou um: mais uma ação de habilidade
	if wins >= breakdance_games:
		_activate_backspin()         # ganhou todos: também o Backspin
	_fx_ring(_body_pos(), 36.0, 12)
	start_cooldown(CD_DANCE, dance_cooldown)
	return true


## Onde a bola está dançando: gira em volta dele (elipse, para ficar bonito na visão 2.5D)
func _dance_point() -> Vector2:
	return global_position + Vector2(cos(_dance_angle) * dance_orbit_radius, sin(_dance_angle) * dance_orbit_radius * 0.45)


## Visual do Dance Battle: ele gira dançando e um redemoinho de vento o envolve
func _start_dance_visual() -> void:
	_stop_dance_visual()
	if particles_fx:
		_wind = KiyoraFX.attach_wind(self)
	if dance_spin_sprite:
		var node: Node2D = visual_root if visual_root != null else (animated_sprite if animated_sprite != null else tint_sprite)
		if node != null:
			_spin_node = node
			_sway_before = sway_enabled
			sway_enabled = false   # o balanço do sprite brigaria com o giro
			_spin_tween = create_tween().set_loops()
			_spin_tween.tween_property(node, "rotation", TAU, dance_spin_period).from(0.0)


func _stop_dance_visual() -> void:
	if _wind != null and is_instance_valid(_wind):
		_wind.queue_free()
	_wind = null
	if _spin_tween != null and _spin_tween.is_valid():
		_spin_tween.kill()
	_spin_tween = null
	if _spin_node != null and is_instance_valid(_spin_node):
		_spin_node.rotation = 0.0
		sway_enabled = _sway_before
	_spin_node = null


## PUXA a bola (ela desliza e desce, se estava suspensa) e a GRUDA no Kiyora, travada para os adversários
## (spell_owner). hostile = true (Dance Battle) também a deixa DISPUTÁVEL (contest_owner): o adversário pode
## tentar Chutar / usar habilidade e quem decide é o resolve_ball_contest() daqui.
func _grab_ball(m: MatchManager, ball: Ball, hostile: bool) -> bool:
	_end_trap(false)
	_dance_token += 1
	var token: int = _dance_token
	m.clear_pending_pass()          # passe alto em andamento: a bola agora é do Kiyora
	ball.register_touch(self)
	ball.hover_to(_trap_point(), 0.0, dance_pull_time)
	ball.play_fx(kick_fx)
	if particles_fx:
		KiyoraFX.line(self, ball.global_position, _trap_point(), 8)
	await get_tree().create_timer(dance_pull_time + 0.02).timeout
	if token != _dance_token or not is_instance_valid(ball) or m.match_over:
		return false

	ball.velocity = Vector2.ZERO
	ball.vel_z = 0.0
	ball.height = 0.0
	ball.spell_owner = self
	if hostile:
		ball.contest_owner = self
	_trap_touches = ball.interaction_count   # qualquer toque depois disto solta a bola
	_trap_on = true
	_trap_hostile = hostile
	_trap_reward_given = false
	_stuns_this_dance = 0
	_dance_angle = 0.0
	if hostile:
		_start_dance_visual()
	_trap_ring = TrapRing.new()
	_trap_ring.ring_color = TEAL_LIGHT
	_trap_ring.core_color = TEAL
	ball.add_child(_trap_ring)
	return true


## Enquanto a bola está grudada: ela acompanha o Kiyora e, no Dance Battle e no turno do adversário,
## um inimigo que age (corre/desliza) perto da bola é atordoado.
func _update_trap() -> void:
	if not _trap_on:
		return
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null or m.match_over:
		_end_trap(false)
		return
	# Alguém do time dele tocou/chutou a bola, ou ela foi solta/segurada por fora: acabou
	if ball.spell_owner != self or not ball.hovering or ball.is_held() \
			or ball.interaction_count != _trap_touches or (_trap_hostile and ball.contest_owner != self):
		_end_trap(false)
		return
	if is_down:   # derrubado: perde a bola
		_end_trap(true)
		return

	if _trap_hostile:
		_dance_angle += dance_orbit_speed * get_physics_process_delta_time()
		ball.global_position = _dance_point()   # dançando: a bola gira em volta dele
	else:
		ball.global_position = _trap_point()
	ball.height = 0.0

	# "Tentar interagir" por ação geral só conta no Dance Battle, no turno do adversário e até o limite de atordoados
	if not _trap_hostile or m.current_team == team or _stuns_this_dance >= dance_max_stuns:
		return
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other.team == team or other.is_down or other.state == State.IDLE \
				or not other.can_reach_level(ball.get_level()):
			continue
		var radius: float = maxf(dance_trigger_radius, other.kick_range + 5.0)
		if other.global_position.distance_to(ball.global_position) <= radius:
			_dance_trigger(other, false)
			return


## Um inimigo tentou interagir por AÇÃO GERAL: ele cai (atordoado). A bola continua grudada.
func _dance_trigger(enemy: Player, from_slide: bool) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	# Quem estava correndo é parado. Quem deu Carrinho (from_slide) é derrubado sem interromper o
	# carrinho dele no meio do próprio _check_slide_hits: o carrinho acaba sozinho logo depois.
	if not from_slide:
		enemy._stop_current_action()
	enemy.knock_down()
	_stuns_this_dance += 1
	var pulse := PulseRing.new()
	pulse.ring_color = TEAL_LIGHT
	enemy.add_child(pulse)
	_fx_burst(enemy.global_position + Vector2(0.0, -height - 20.0), 8)
	hop_over()   # o pulinho de quem desvia/dança
	if stun_gives_backspin:
		_reward_from_loss()


## Um inimigo perdeu o confronto: Backspin; se já estava ativo, +1 ação de habilidade no lugar (1x por confronto)
func _reward_from_loss() -> void:
	if _trap_reward_given:
		return
	_trap_reward_given = true
	if is_backspin_active():
		extra_skill_left += 1
		_fx_notes(_body_pos(), 6)
	else:
		_activate_backspin()
	hop_over()


## Disputa de bola: chamado pelo kick_ball() de um ADVERSÁRIO que tenta chutar a bola grudada.
## true = o chute dele pode seguir; false = foi barrado.
func resolve_ball_contest(attacker: Player, by_skill: bool) -> bool:
	if not _trap_on or not _trap_hostile or attacker == null or attacker.team == team:
		return true
	if not by_skill:
		if _stuns_this_dance >= dance_max_stuns:
			return true   # limite de atordoados: o chute dele segue
		_dance_trigger(attacker, false)   # ação geral (Chutar): atordoado
		return false
	var m: MatchManager = _get_manager()
	if m == null:
		return true
	var token: int = _dance_token
	var won: bool = await _rhythm_game(m, "Dance Battle!")   # habilidade: jogo de ritmo
	if token != _dance_token or m.match_over or not is_instance_valid(self):
		return false
	_fx_beat(global_position, 1)
	if won:
		return true   # o chute segue; o toque na bola solta o Dance Battle
	_reward_from_loss()
	return false


## Enquanto a bola está grudada no Dance Battle, o Passe geral inimigo perto dela não existe
## (senão ele roubaria a bola sem nenhuma disputa).
func blocks_general_action(p: Player, action: int) -> bool:
	if not _trap_on or not _trap_hostile or p == null or p.team == team:
		return false
	if action != MatchManager.GeneralAction.PASS or _stuns_this_dance >= dance_max_stuns:
		return false
	var ball: Ball = _get_ball()
	return ball != null and ball.spell_owner == self \
		and p.global_position.distance_to(ball.global_position) <= p.kick_range + 5.0


## O Carrinho de um inimigo contra o Kiyora (com a bola grudada no Dance Battle) conta como tentar interagir:
## o Kiyora desvia e quem deu o carrinho é que cai.
func try_counter_slide(attacker: Player) -> bool:
	if not _trap_on or not _trap_hostile or is_down or attacker.team == team \
			or _stuns_this_dance >= dance_max_stuns:
		return false
	attacker._slide_hit_ball = true   # o resto do carrinho não tenta chutar a bola
	_dance_trigger(attacker, true)
	return true


## release = true solta a bola (ela fica onde está); false = ela já foi tocada/solta por outro
func _end_trap(release: bool) -> void:
	var was_on: bool = _trap_on
	_trap_on = false
	_trap_hostile = false
	_stop_dance_visual()
	if _trap_ring != null and is_instance_valid(_trap_ring):
		_trap_ring.queue_free()
	_trap_ring = null
	if was_on and release:
		var ball: Ball = _get_ball()
		if ball != null and is_instance_valid(ball) and ball.spell_owner == self:
			ball.release_hover()   # volta a gravidade e a trava some


# ---------- PASSE RASTEIRO DO KIYORA (Backspin passivo) ----------

## Passiva: devolve true para o PRIMEIRO obstáculo (inimigo) do trajeto da bola do último passe dele.
## O passe do MatchManager usa isto (trecho opcional em _run_ground_pass) e os passes daqui também.
func should_ignore_obstacle(obstacle: Player, ball: Ball) -> bool:
	if not backspin_passive or ball == null or obstacle == null or ball.last_toucher != self:
		return false
	if _ignore_key != ball.interaction_count:
		_ignore_key = ball.interaction_count
		_ignored_obstacle = null
	if _ignored_obstacle == null:
		_ignored_obstacle = obstacle
		_fx_slip(ball.global_position)
		return true
	return obstacle == _ignored_obstacle


## Passiva: multiplicador de velocidade do passe rasteiro (freadas bruscas), conforme o quanto já andou.
## O passe do MatchManager usa isto (trecho opcional) e os passes daqui também.
func pass_speed_mult(travelled: float, travel: float, ball: Ball = null) -> float:
	if not backspin_passive or backspin_brakes <= 0 or travel < 120.0:
		return 1.0
	for i in backspin_brakes:
		var mark: float = travel * float(i + 1) / float(backspin_brakes + 1)
		if travelled >= mark and travelled < mark + backspin_brake_length:
			if ball != null:
				var key: int = ball.interaction_count * 8 + i
				if key != _brake_fx_key:
					_brake_fx_key = key
					_fx_spin(ball)   # rodopio a cada freada
			return backspin_brake_mult
	return 1.0


## Primeiro inimigo no caminho da bola que vai parar o passe (ignora o primeiro, pela passiva)
func _pass_blocker(m: MatchManager, ball: Ball) -> Player:
	var level: Heights.Level = ball.get_level()
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other.team == team or other.is_down or other.height_level != level:
			continue
		if other.global_position.distance_to(ball.global_position) > m.ground_pass_intercept_radius:
			continue
		if should_ignore_obstacle(other, ball):
			continue
		return other
	return null


## Passe rasteiro de habilidade: igual ao run_curved_ground_pass (curva 0), mas com as freadas e o
## "ignora o primeiro obstáculo" do Backspin. aim_point = para onde vai; receiver = quem recebe
## (stop_at_receiver: a bola para ENCOSTANDO nele; false: vai exatamente até o ponto).
## max_range limita o quanto a bola anda. Devolve false se o passe não saiu.
func _ground_pass(m: MatchManager, ball: Ball, aim_point: Vector2, receiver: Player, anim: StringName,
		max_range: float, stop_at_receiver: bool = true, fx_players: Array[Player] = []) -> bool:
	face_towards(aim_point - global_position)
	var pass_anim: StringName = anim if anim != &"" else ANIM_PASS
	if not await play_action(pass_anim, ANIM_PASS):
		return false   # ação cancelada (ex: a partida reiniciou)
	if m.match_over or not is_instance_valid(ball):
		return false

	_end_trap(false)
	m.clear_pending_pass()
	var start: Vector2 = ball.global_position
	var to_end: Vector2 = aim_point - start
	var dist: float = to_end.length()
	var gap: float = 0.0
	if stop_at_receiver and receiver != null:
		gap = ball.collision_radius + receiver.body_radius + 2.0   # a bola para ENCOSTANDO no alvo
	var travel: float = minf(dist - gap, max_range)
	if travel < 1.0:
		return false
	var dir: Vector2 = to_end / dist
	var end_point: Vector2 = start + dir * travel

	ball.kick_ground(dir, m.ground_pass_speed, self, Ball.NO_SHOT)   # passe não é chute
	ball.height = 0.0
	ball.collisions_paused = true
	ball.trail_enabled = true
	ball.play_fx(kick_fx)
	if not fx_players.is_empty() and receiver != null:
		SuperstarFX.attach_pass(self, ball, fx_players, receiver)   # efeitos dourados do passe

	var travelled: float = 0.0
	var slow_zone: float = maxf(minf(travel * 0.4, 160.0), 1.0)   # reta final: a bola vai "amortecendo"
	var time_left: float = travel / m.ground_pass_speed * 3.5 + 1.5   # trava de segurança (as freadas gastam tempo)
	while time_left > 0.0:
		await get_tree().physics_frame
		if not is_instance_valid(ball):
			return false
		var delta: float = get_physics_process_delta_time()
		time_left -= delta
		if m.match_over or _pass_blocker(m, ball) != null:
			break
		var remaining: float = travel - travelled
		if remaining <= 2.0:
			ball.global_position = end_point
			break
		var speed: float = m.ground_pass_speed * clampf(remaining / slow_zone, 0.15, 1.0)
		speed *= pass_speed_mult(travelled, travel, ball)
		travelled = minf(travelled + speed * delta, travel)
		# A bola é conduzida até o ponto da reta em que ela deveria estar agora
		ball.velocity = (start + dir * travelled - ball.global_position) / delta

	if is_instance_valid(ball):
		ball.velocity = Vector2.ZERO
		ball.collisions_paused = false
		ball.trail_enabled = false
	if receiver != null and not m.match_over:
		m.pass_completed.emit(self, receiver)
	return true


# ---------- PASSIVA NOS CHUTES ----------

## Sobrescreve o chute para dar o Backspin passivo a TODO chute/passe de chute dele (Chutar, Backspin Shot...)
func kick_ball(ball: Ball, direction: Vector2, kind: KickType, qte_success: bool = true,
		chance_override: float = -1.0, ignore_self_collision: bool = false,
		fx: KickFX = null, anim: StringName = &"", on_kick: Callable = Callable()) -> void:
	await super(ball, direction, kind, qte_success, chance_override, ignore_self_collision, fx, anim,
		_kick_hook.bind(on_kick))


func _kick_hook(ball: Ball, dir: Vector2, speed: float, inner: Callable) -> void:
	if inner.is_valid():
		inner.call(ball, dir, speed)
	if backspin_passive:
		_backspin_kick_flight(ball)   # roda em paralelo (sem await)


## Freadas bruscas (só chute no chão), rodopios e "ignora o primeiro obstáculo" depois do chute
func _backspin_kick_flight(ball: Ball) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	var token: int = ball.interaction_count
	var on_ground: bool = ball.height <= 1.0 and absf(ball.vel_z) <= 0.01
	_fx_spin(ball)
	var ignored: bool = false
	var brakes_done: int = 0
	var brake_left: float = 0.0
	var elapsed: float = 0.0
	while elapsed < backspin_flight_time:
		await get_tree().physics_frame
		if not is_instance_valid(ball) or ball.interaction_count != token or ball.hovering:
			return
		var delta: float = get_physics_process_delta_time()
		elapsed += delta
		if not ignored:
			ignored = _ignore_first_in_path(ball)
		if not on_ground:
			continue
		if brake_left > 0.0:
			brake_left -= delta
			if brake_left <= 0.0:
				ball.velocity = ball.velocity / backspin_brake_mult   # solta a freada
		elif brakes_done < backspin_brakes \
				and elapsed >= backspin_brake_first + float(brakes_done) * backspin_brake_gap:
			if ball.velocity.length() < 90.0:
				return   # já está devagar: nada de freada
			ball.velocity = ball.velocity * backspin_brake_mult
			brake_left = backspin_brake_time
			brakes_done += 1
			_fx_spin(ball)


## O primeiro inimigo que a bola vai encostar passa a ser ignorado por ela (até ela parar)
func _ignore_first_in_path(ball: Ball) -> bool:
	var level: Heights.Level = ball.get_level()
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other.team == team or other.is_down or other.height_level != level:
			continue
		var reach: float = ball.collision_radius + other.body_radius + 14.0
		var offset: Vector2 = other.global_position - ball.global_position
		if offset.length() <= reach and offset.dot(ball.velocity) > 0.0:
			ball.ignore_player_until_stopped(other)
			_fx_slip(ball.global_position)
			return true
	return false


# ---------- BORDERLINE / EVEN THE GODS ----------

func get_pass_skill() -> PassSkill:
	return PassSkill.GODS if is_backspin_active() else PassSkill.BORDERLINE


func _use_border() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null or get_kick_type(ball) == KickType.NONE:
		return false
	var gods: bool = get_pass_skill() == PassSkill.GODS

	# Escolhe dois aliados (se só houver um ao alcance, é ele). Cancelar qualquer escolha cancela a habilidade.
	var first: Player = await m.pick_ally_for_skill(self, border_range, false, _ally_ok.bind(border_range, null))
	if first == null or m.match_over:
		return false
	var chosen: Array[Player] = [first]
	var others: int = 0
	for p in _allies_in_range(border_range):
		if p != first:
			others += 1
	if others > 0:
		var second: Player = await m.pick_ally_for_skill(self, border_range, false,
			_ally_ok.bind(border_range, first))
		if second == null or m.match_over:
			return false
		chosen.append(second)

	var receiver: Player = _fewest_goals(m, chosen)
	# Empire do Kaiser: se ele é um dos dois escolhidos, a balança da justiça pesa quem recebe
	var master: Kaiser = get_empire_master()
	var weigh: bool = master != null and master in chosen
	var touches_before: int = ball.interaction_count
	# Com a balança, o passe também ganha os efeitos dourados (fios até os aliados, rastro na bola...)
	var pass_fx_players: Array[Player] = []
	if weigh:
		pass_fx_players = chosen

	var sent: bool = false
	if not gods:
		# Borderline: passe rasteiro até quem tem menos gols
		if weigh:
			_show_justice_scale(m, chosen, receiver, master)
		sent = await _ground_pass(m, ball, receiver.global_position, receiver, &"borderline",
			border_range, true, pass_fx_players)
	else:
		# Even the Gods: ele também escolhe onde a bola chega (perto de quem vai receber)
		var point: Vector2 = await m.pick_point_for_skill(self, border_range)
		if point == Vector2.INF or m.match_over:
			return false
		var offset: Vector2 = (point - receiver.global_position).limit_length(gods_land_radius)
		if weigh:
			_show_justice_scale(m, chosen, receiver, master)
		sent = await _ground_pass(m, ball, receiver.global_position + offset, receiver, &"even_the_gods",
			border_range, false, pass_fx_players)
	if not sent:
		return false

	# Guarda o passe para a reação Superstar: só vale se o passe saiu de verdade (a bola foi tocada
	# por ela agora) e quem recebe é o Kaiser do Empire
	last_border_pass = {}
	if master != null and receiver == master and ball.interaction_count > touches_before \
			and ball.last_toucher == self:
		last_border_pass = {"target": master, "touches": ball.interaction_count, "gods": gods}

	start_cooldown(CD_BORDER, border_cooldown)
	return true


## O Kaiser do time que tem esta Kiyora como Servo Garçom do Empire (null = ela não está sob o efeito)
func get_empire_master() -> Kaiser:
	var m: MatchManager = _get_manager()
	if m == null:
		return null
	for p: Player in m.get_team_players(team):
		var kaiser := p as Kaiser
		if kaiser != null and kaiser.is_waiter(self):
			return kaiser
	return null


## Balança dourada da Superstar: cada prato é um dos dois aliados escolhidos (nome + gols) e o
## prato de quem recebe a bola desce. Se quem recebe é o Kaiser, a Superstar está de pé.
func _show_justice_scale(m: MatchManager, chosen: Array[Player], receiver: Player, master: Kaiser) -> void:
	var left: Player = chosen[0]
	var right: Player = chosen[1] if chosen.size() > 1 else null
	var right_info: Dictionary = _scale_info(m, right) if right != null else {}
	# Ao lado dela, do lado OPOSTO ao passe (para não cobrir a bola indo embora)
	var side: float = 0.0
	if scale_beside:
		var dx: float = receiver.global_position.x - global_position.x
		side = -signf(dx) if absf(dx) > 8.0 else -(1.0 if facing >= 0.0 else -1.0)
	SuperstarFX.attach_scale(self, _scale_info(m, left), right_info, receiver == left,
		receiver == master, 3.4, side)


func _scale_info(m: MatchManager, p: Player) -> Dictionary:
	return {"name": p.get_display_name(), "goals": int(m._stats_for(p)["goals"])}


## Quem tem menos gols entre os escolhidos (empate = sorteio entre os empatados)
func _fewest_goals(m: MatchManager, players: Array[Player]) -> Player:
	var best: Array[Player] = []
	var best_goals: int = 1000000
	for p in players:
		var goals: int = int(m._stats_for(p)["goals"])
		if goals < best_goals:
			best_goals = goals
			best = [p]
		elif goals == best_goals:
			best.append(p)
	return best.pick_random()


# ---------- DASHES (Windmill, Twister, Six-Step) ----------

## Dash curto: anda "dist" px na direção em dash_time segundos (respeita as colisões do corpo)
func _dash(dir: Vector2, dist: float) -> void:
	var d: Vector2 = dir.normalized()
	face_towards(d)
	var start: Vector2 = global_position
	_fx_dash(start, start + d * dist)
	var t: float = 0.0
	while t < dash_time:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		velocity = d * dist / dash_time
		move_and_slide()
	velocity = Vector2.ZERO


## A bola pode ser dominada agora? (no chão ou suspensa, ao alcance, sem outra trava)
func _can_dominate(ball: Ball) -> bool:
	return ball != null and is_instance_valid(ball) and not ball.is_held() and not ball.is_locked_for(team) \
		and ball.get_level() != Heights.Level.FLYING \
		and global_position.distance_to(ball.global_position) <= six_step_ball_radius


## Até "count" dashes seguidos. A mira do primeiro já vem pronta; as outras são pedidas uma a uma
## (cancelar uma delas só encerra a sequência). hunt = ao fim de cada dash, se encontrou a bola, DOMINA ela.
## Devolve quantos dashes fez.
func _dash_chain(m: MatchManager, count: int, range_px: float, first_dir: Vector2, hunt: bool) -> int:
	var done: int = 0
	var dir: Vector2 = first_dir
	for i in count:
		if i > 0:
			dir = await m.aim_for_skill(self, range_px)
			if dir == Vector2.ZERO or m.match_over or not is_instance_valid(self):
				break
		if not await play_action(ANIM_DASH):
			break
		if m.match_over:
			break
		await _dash(dir, range_px)
		done += 1
		if m.match_over:
			break
		if hunt and not _trap_on:
			var ball: Ball = _get_ball()
			if _can_dominate(ball):
				if await _grab_ball(m, ball, false):
					_dominating_here = true
	if done > 0:
		m._skill_pick_cancelled = false   # cancelar um dash do meio NÃO cancela a habilidade (ela já foi usada)
	return done


## Giro acrobático até a bola (a bola está dentro do alcance do giro)
func _reach_ball(ball: Ball) -> void:
	var to_ball: Vector2 = ball.global_position - global_position
	var d: float = to_ball.length()
	var stop: float = body_radius + ball.collision_radius + 6.0
	if d <= stop:
		return
	var dest: Vector2 = global_position + to_ball.normalized() * (d - stop)
	_fx_dash(global_position, dest)
	var tw: Tween = create_tween()
	tw.tween_property(self, "global_position", dest, reach_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _ball_in_reach(ball: Ball, radius: float) -> bool:
	return ball != null and is_instance_valid(ball) and not ball.is_held() and not ball.is_locked_for(team) \
		and ball.get_level() == Heights.Level.GROUND \
		and global_position.distance_to(ball.global_position) <= radius


# ---------- WINDMILL / TWISTER ----------

func get_wind_skill() -> WindSkill:
	if height_level != Heights.Level.GROUND:
		return WindSkill.NONE
	if not _ball_in_reach(_get_ball(), windmill_reach):
		return WindSkill.NONE
	return WindSkill.TWISTER if is_backspin_active() else WindSkill.WINDMILL


func _wind_skill_name() -> String:
	return "Twister" if is_backspin_active() else "Windmill"


func _use_wind() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	var variant: WindSkill = get_wind_skill()
	if m == null or ball == null or variant == WindSkill.NONE:
		return false
	if variant == WindSkill.TWISTER:
		return await _use_twister(m, ball)

	# Windmill: giro até a bola e passe rasteiro para o aliado MAIS DISTANTE
	if _farthest_ally(windmill_pass_range) == null:
		return false
	face_towards(ball.global_position - global_position)
	if not await play_action(&"windmill"):
		return false
	if m.match_over or not _ball_in_reach(ball, windmill_reach):
		return false   # a bola saiu do alcance durante a animação: não alcançou
	await _reach_ball(ball)
	if m.match_over or not is_instance_valid(ball):
		return false
	var target: Player = _farthest_ally(windmill_pass_range)
	if target == null:
		return false
	if not await _ground_pass(m, ball, target.global_position, target, &"", windmill_pass_range):
		return false
	start_cooldown(CD_WIND, wind_cooldown)
	return true


## Twister: giro até a bola, dois dashes curtos com ela e passe para um aliado ESCOLHIDO
func _use_twister(m: MatchManager, ball: Ball) -> bool:
	var ally: Player = await m.pick_ally_for_skill(self, twister_pass_range, false,
		_ally_ok.bind(twister_pass_range, null))
	if ally == null or m.match_over:
		return false
	var first_dir: Vector2 = await m.aim_for_skill(self, twister_dash_range)
	if first_dir == Vector2.ZERO or m.match_over:
		return false
	face_towards(ball.global_position - global_position)
	if not await play_action(&"twister"):
		return false
	if m.match_over or not _ball_in_reach(ball, windmill_reach):
		return false
	await _reach_ball(ball)
	if m.match_over or not is_instance_valid(ball) or not await _grab_ball(m, ball, false):
		_end_trap(true)
		return false
	_dominating_here = true
	await _dash_chain(m, twister_dashes, twister_dash_range, first_dir, false)
	_dominating_here = false
	if m.match_over or not is_instance_valid(ally) or not is_instance_valid(ball):
		_end_trap(true)
		return false
	# O passe sai da bola grudada (o _ground_pass solta o domínio sozinho)
	if not await _ground_pass(m, ball, ally.global_position, ally, &"", twister_pass_range):
		_end_trap(true)
		return true   # os dashes já aconteceram: a habilidade foi usada
	start_cooldown(CD_WIND, wind_cooldown)
	return true


# ---------- SIX-STEP / BACKSPIN SHOT ----------

## Six-Step: 6 dashes curtos. Se encontrar a bola, domina e continua. No fim: ação geral extra
## (e, com o Backspin, libera o Backspin Shot).
func _use_six_step(m: MatchManager) -> bool:
	var first_dir: Vector2 = await m.aim_for_skill(self, six_step_dash_range)
	if first_dir == Vector2.ZERO or m.match_over:
		return false   # cancelou: não gasta a ação
	var with_backspin: bool = is_backspin_active()
	_dominating_here = false
	var done: int = await _dash_chain(m, six_step_dashes, six_step_dash_range, first_dir, true)
	if _dominating_here:
		_end_trap(true)   # a bola fica no chão, aos pés dele, para a ação geral extra
	_dominating_here = false
	if done <= 0:
		return false
	if m.match_over or not is_instance_valid(self):
		return true
	extra_general_left += 1
	_fx_burst(_body_pos(), 12, true)
	if with_backspin:
		_shot_ready = true
		_fx_notes(_body_pos(), 6)
	start_cooldown(CD_SIX, six_cooldown)
	return true


## Complemento do Six-Step com Backspin: chute 1.1x, efeito Backspin (passiva) e 50% de chance
func _use_backspin_shot() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false
	var kind: KickType = get_kick_type(ball)
	if kind == KickType.NONE:
		return false
	var dir: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if dir == Vector2.ZERO or m.match_over:
		return false
	var qte_ok: bool = true
	if kind != KickType.GROUND and not skips_qte():
		qte_ok = await m.run_qte(kind)
		if m.match_over or not is_instance_valid(ball):
			return false
	_shot_ready = false
	next_kick_force_mult *= backspin_shot_force_mult
	await kick_ball(ball, dir, kind, qte_ok, backspin_shot_chance, false, kick_fx, SKILL_SHOT, _on_backspin_shot)
	return true


func _on_backspin_shot(ball: Ball, _dir: Vector2, _speed: float) -> void:
	_fx_burst(ball.global_position + Vector2(0.0, -ball.height), 14, true)


## Complemento gratuito: não gasta ação de habilidade
func skill_is_free(skill_id: StringName) -> bool:
	return skill_id == SKILL_SHOT and _shot_ready


## O turno não acaba sozinho enquanto o Backspin Shot pode ser usado
func has_free_followup() -> bool:
	return _shot_ready and not is_down and get_kick_type(_get_ball()) != KickType.NONE


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var dance_name: String = "Dance Battle (grudada)" if _trap_on \
		else ("Breakdance" if _dance_is_break() else "Dance Battle")
	list.append({"id": SKILL_DANCE, "name": skill_label(dance_name, CD_DANCE)})
	var border_name: String = "Even the Gods" if get_pass_skill() == PassSkill.GODS else "Borderline"
	list.append({"id": SKILL_BORDER, "name": skill_label(border_name, CD_BORDER)})
	list.append({"id": SKILL_WIND, "name": skill_label(_wind_skill_name(), CD_WIND)})
	list.append({"id": SKILL_SIX, "name": skill_label("Six-Step", CD_SIX)})
	if _shot_ready:
		list.append({"id": SKILL_SHOT, "name": "Backspin Shot"})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_DANCE:
			return not _trap_on and not is_on_cooldown(CD_DANCE) and height_level == Heights.Level.GROUND
		SKILL_BORDER:
			return not is_on_cooldown(CD_BORDER) and height_level == Heights.Level.GROUND \
				and get_kick_type(_get_ball()) != KickType.NONE \
				and not _allies_in_range(border_range).is_empty()
		SKILL_WIND:
			if is_on_cooldown(CD_WIND):
				return false
			match get_wind_skill():
				WindSkill.WINDMILL:
					return _farthest_ally(windmill_pass_range) != null
				WindSkill.TWISTER:
					return not _allies_in_range(twister_pass_range).is_empty()
		SKILL_SIX:
			return not is_on_cooldown(CD_SIX) and height_level == Heights.Level.GROUND
		SKILL_SHOT:
			return _shot_ready and get_kick_type(_get_ball()) != KickType.NONE
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_DANCE:
			return await _use_dance()
		SKILL_BORDER:
			return await _use_border()
		SKILL_WIND:
			return await _use_wind()
		SKILL_SIX:
			var m: MatchManager = _get_manager()
			return m != null and await _use_six_step(m)
		SKILL_SHOT:
			return await _use_backspin_shot()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_DANCE:
			if _dance_is_break():
				title = "Breakdance"
				text = ("Sem a bola por perto, Kiyora joga %d jogos de ritmo consigo mesmo. Ganhou um: +1 ação de habilidade. Ganhou todos: também o Backspin (%d rodadas).\n"
					+ "Recarga: %d rodadas.") % [breakdance_games, backspin_rounds, dance_cooldown]
			else:
				title = "Dance Battle"
				text = ("Kiyora dança com a bola. No turno inimigo, quem tentar pegá-la com ação geral (até %d inimigos) fica atordoado; com habilidade, joga um jogo de ritmo e, se perder, Kiyora ganha o Backspin por %d rodadas (ou +1 ação de habilidade se já o tiver).\n"
					+ "Recarga: %d rodadas.") % [dance_max_stuns, backspin_rounds, dance_cooldown]
		SKILL_BORDER:
			if get_pass_skill() == PassSkill.GODS:
				title = "Even the Gods"
				text = "Escolhe dois aliados: passe rasteiro (alcance %d) para quem tiver menos gols, e você escolhe o ponto onde a bola chega." % int(border_range)
			else:
				title = "Borderline"
				text = "Escolhe dois aliados: passe rasteiro (alcance %d) para quem tiver menos gols." % int(border_range)
			text += "\nRecarga: %d rodadas." % border_cooldown
		SKILL_WIND:
			title = _wind_skill_name()
			if is_backspin_active():
				text = "Giro até a bola, %d dashes curtos (alcance %d) e passe para um aliado escolhido (alcance %d)." \
					% [twister_dashes, int(twister_dash_range), int(twister_pass_range)]
			else:
				text = "Giro acrobático até a bola (alcance %d) e passe rasteiro para o aliado mais distante (alcance %d)." \
					% [int(windmill_reach), int(windmill_pass_range)]
			text += "\nRecarga: %d rodadas." % wind_cooldown
		SKILL_SIX:
			title = "Six-Step"
			text = "%d dashes curtos (alcance %d). Se encontrar a bola, domina e continua. No fim ganha uma ação geral." \
				% [six_step_dashes, int(six_step_dash_range)]
			if is_backspin_active():
				text += "\nCom o Backspin: no fim também libera o Backspin Shot (chute %.1fx, %d%% de chance)." \
					% [backspin_shot_force_mult, int(backspin_shot_chance * 100.0)]
			text += "\nRecarga: %d rodadas." % six_cooldown
		SKILL_SHOT:
			title = "Backspin Shot"
			text = "Chute com %.1fx de força, efeito Backspin e %d%% de chance. Não gasta ação de habilidade." \
				% [backspin_shot_force_mult, int(backspin_shot_chance * 100.0)]
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()
	_dance_token += 1   # uma espera de Dance Battle em andamento percebe e para
	_end_trap(true)
	_backspin_until_round = -1
	last_border_pass = {}
	_shot_ready = false
	_dominating_here = false
	_gu_applied = 0.0           # o super zerou o pass_range_bonus: o bônus volta no próximo quadro
	_ignored_obstacle = null
	_ignore_key = -1
	_refresh_aura()
	queue_redraw()


# ---------- VISUAL ----------

func _draw() -> void:
	super()
	var center := Vector2(0.0, -height)

	# Backspin ativo: anel azul-esverdeado "girando" (3 arcos) com um fio claro por dentro
	if is_backspin_active():
		var r: float = placeholder_radius + 8.0
		for i in 3:
			var a0: float = TAU * float(i) / 3.0
			draw_arc(center, r, a0, a0 + TAU / 3.0 * 0.7, 10, Color(TEAL_LIGHT, 0.95), 3.0)
		draw_arc(center, r - 4.0, 0.0, TAU, 40, Color(TEAL, 0.9), 2.0)


## Anel que gira em volta da bola armada pelo Dance Battle / domínio
class TrapRing extends Node2D:
	var ring_color: Color = Color(0.28, 0.68, 0.64)
	var core_color: Color = Color(0.05, 0.30, 0.38)

	func _ready() -> void:
		z_index = 5

	func _process(delta: float) -> void:
		rotation += delta * 3.5
		queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, Color(core_color, 0.9), 2.0)
		for i in 3:
			var a0: float = TAU * float(i) / 3.0
			draw_arc(Vector2.ZERO, 22.0, a0, a0 + 1.4, 10, ring_color, 3.0)


## Anel que se abre e some (usado no inimigo que caiu no Dance Battle)
class PulseRing extends Node2D:
	var ring_color: Color = Color(0.28, 0.68, 0.64)
	var _time: float = 0.0
	const LIFE: float = 0.5

	func _ready() -> void:
		z_index = 10

	func _process(delta: float) -> void:
		_time += delta
		if _time >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k: float = clampf(_time / LIFE, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 18.0 + 30.0 * k, 0.0, TAU, 32, Color(ring_color, 1.0 - k), 3.0)
