class_name Aiku
extends Player
## Aiku. Herda tudo do Player; script único. Visual: aiku_fx.gd (uma cobra verde em volta dele e da bola; a área do
## Burglar Radar é uma cobra devorando o próprio corpo). Cena: player.tscn herdada, script no nó raiz, nó raiz "Aiku".
##
## 1. Snake Lunge (recarga 2, compartilhada): Aiku no chão vai até um inimigo no chão (alcance 250) e inicia um confronto
##    físico (80% de vitória). Vencendo, bloqueia as HABILIDADES dele por 2 rodadas ou até o Aiku sair de perto (60).
##      Serpentine Grasp (inimigo SUSPENSO): vai até ele, derruba e faz o Snake Lunge (chance reduzida: 70%).
## 2. Serpent Slip (recarga 2, compartilhada): Aiku no chão dá um avanço curto (100) seguido de um Carrinho (a ação padrão);
##    se o Carrinho encontrar a bola, vira um passe rasteiro para um aliado (alcance 400).
##      Venom Deflect (Aiku SUSPENSO): avanço aéreo (150); se achar a bola SUSPENSA, dá um deflect (0.4x de força).
##      Nice Shot (Aiku suspenso + bola VOANDO a até 150): deflect direcional (0.3x); quando a bola cair, Aiku vai até ela
##      e ganha +1 ação geral.
## 3. Burglar Radar (só na DEFESA; dura 2 rodadas, recarga de 2 após o fim): cria uma área fixa (350). Dentro dela: chutes
##    inimigos têm -7% de chance e, se a bola vier SUSPENSA, o Aiku tem 30% de ir até ela e dar um deflect sozinho.
##    Libera dois botões novos, cada um de USO ÚNICO durante o radar:
##      Ultimate Defense: Aiku no chão salta até a bola VOANDO (alcance 200), cabeceia (0.7x), desce e pode escolher um inimigo
##      a até 130 para ir até ele e bloquear as ações GERAIS dele por 1 rodada (até o fim do próximo turno inimigo).
##      Blooming Halt: marca um inimigo; se ele tentar chutar no turno inimigo, a marca estoura: força pela metade, -6% de
##      chance e marca outro inimigo próximo (somada à penalidade da área).
##
## REAÇÃO QUÍMICA SELFISH (com o Sae, veja reaction_selfish.gd): se o Sae, com a Ultra Vision ativa, fez um Perfect Pass
## que chegou SUSPENSO no Aiku nesta rodada e ninguém tocou na bola, o Snake Lunge vira o STRIKER: cutscene, chute com 2.0x
## de força, a bola sobe durante a trajetória (até Voando) e 75% de chance de gol, com uma serpente saindo do chute.
## O Striker NÃO precisa de inimigo por perto (só da bola ao alcance).
##
## O pedido não deu o que acontece quando o Aiku PERDE o confronto do Snake Lunge: nada acontece (só o bote falha).
## Animações opcionais (hit_frames diz o frame de impacto de cada uma): snake_lunge, serpentine_grasp, serpent_slip,
## nice_shot, burglar_radar, ultimate_defense, blooming_halt. Sem elas, nada quebra.

const SKILL_LUNGE: StringName = &"snake_lunge"
const SKILL_SLIP: StringName = &"serpent_slip"
const SKILL_RADAR: StringName = &"burglar_radar"
const SKILL_DEFENSE: StringName = &"ultimate_defense"
const SKILL_HALT: StringName = &"blooming_halt"
const CD_LUNGE: StringName = &"cd_lunge"       # as variantes de cada habilidade compartilham a recarga
const CD_SLIP: StringName = &"cd_slip"
const CD_RADAR: StringName = &"cd_radar"

enum SlipVariant { NONE, SLIP, VENOM, NICE }

@export_group("Snake Lunge / Serpentine Grasp")
@export var lunge_range: float = 250.0
@export_range(0.0, 1.0) var chance_lunge: float = 0.80
@export_range(0.0, 1.0) var chance_grasp: float = 0.70
@export var lunge_rounds: int = 2                  # bloqueio das habilidades (a rodada atual conta)
@export var lunge_leash: float = 60.0               # Aiku se afastar além disso solta o inimigo (60, como no documento)
@export var lunge_stop_distance: float = 40.0      # até onde o bote chega perto do inimigo (menor que lunge_leash)
@export var lunge_dash_time: float = 0.25
@export var lunge_cooldown: int = 2

@export_group("Serpent Slip / Venom Deflect / Nice Shot")
@export var slip_dash: float = 100.0               # avanço antes do Carrinho
@export var slip_dash_time: float = 0.2
@export var slip_pass_range: float = 400.0         # passe rasteiro ao encontrar a bola
@export var venom_dash: float = 150.0              # avanço aéreo
@export var venom_dash_time: float = 0.3
@export var venom_force_mult: float = 0.4          # deflect: múltiplo da força do Chutar daquela altura
@export var nice_range: float = 150.0              # bola voando "ao alcance" do Nice Shot
@export var nice_force_mult: float = 0.3
@export var ball_reach_radius: float = 60.0        # "encontrar" a bola durante um avanço
@export var slip_cooldown: int = 2

@export_group("Burglar Radar")
@export var radar_radius: float = 250.0
@export var radar_rounds: int = 2                  # duração da área (a rodada atual conta)
@export var radar_cooldown: int = 2                # a partir do fim do efeito
@export_range(0.0, 1.0) var radar_penalty: float = 0.07        # -7% nos chutes inimigos dentro da área
@export_range(0.0, 1.0) var radar_catch_chance: float = 0.40   # bola suspensa entrando: chance de o Aiku ir até ela
@export var radar_deflect_mult: float = 0.4        # força do deflect automático
@export var defense_split: float = 0.0             # "na defesa": 0 = a metade do campo do próprio gol (-0.33 = só o terço)
@export var defense_range: float = 200.0           # Ultimate Defense: bola voando ao alcance
@export var header_force_mult: float = 0.7
@export var defense_block_range: float = 130.0
@export var halt_range: float = 250.0              # Blooming Halt: alcance para marcar
@export var halt_force_mult: float = 0.5           # força do chute marcado
@export_range(0.0, 1.0) var halt_penalty: float = 0.06
@export var halt_chain_radius: float = 200.0       # a marca estoura e pula para outro inimigo a até esta distância

@export_group("Striker (Reação Química Selfish, com o Sae)")
@export_range(0.0, 1.0) var chance_striker: float = 0.75   # chance de gol FINAL (nada mais soma)
@export var striker_force_mult: float = 2.0                 # força do chute (x o voleio); nada mais soma
## Aura do Striker (rosa + verde-veneno). Vazio = usa o estilo padrão (veja _make_striker_fx)
@export var striker_fx: KickFX

@export_group("Visual / Descrição")
## Aura + partículas dos deflects. Vazio = verde-veneno (veja _make_kick_fx)
@export var kick_fx: KickFX
## Imagem de cada habilidade no balão. Chaves: snake_lunge, serpent_slip, burglar_radar, ultimate_defense, blooming_halt
@export var skill_icons: Dictionary = {}

var _lunge_target: Player = null                   # inimigo travado pelo Snake Lunge
var _lunge_bind: AikuFX.Snake = null
var _radar_center: Vector2 = Vector2.ZERO
var _radar_until_round: int = -1
var _radar_fx: AikuFX.Radar = null
var _ball_inside: bool = false                     # a bola estava dentro da área no quadro anterior
var _auto_busy: bool = false                       # deflect automático em andamento
var _defense_used: bool = false                    # os dois botões do radar são de uso único
var _halt_used: bool = false
var _halt_target: Player = null
var _halt_mark: AikuFX.Snake = null
var _block_target: Player = null                   # Ultimate Defense: inimigo sem ações gerais
var _block_bind: AikuFX.Snake = null
var _radar_coil: AikuFX.Snake = null               # cobrinha enrolada nele enquanto o radar dura
var _slip_active: bool = false
var _slip_ball_found: bool = false
var _dash_token: int = 0


func _init() -> void:
	character_id = "aiku"    # o menu de formação usa isto para saber quem é quem
	display_name = "Aiku"    # aparece no placar de gols e no menu


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = _make_kick_fx()
	if striker_fx == null:
		striker_fx = _make_striker_fx()
	add_to_group("control_sources")   # penalidade de chute, trava das gerais (Player consulta este grupo)
	_hook_manager.call_deferred()


## Verde-veneno; as partículas "escorregam" para os lados, feito escamas
func _make_kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = Color(0.45, 0.65, 0.1)
	fx.additive = false   # o campo é verde: mistura normal mantém a cor visível
	fx.trail_width = 14.0
	fx.shape = KickFX.Shape.DOT
	fx.particle_color = Color(0.8, 0.95, 0.4)
	fx.amount = 20
	fx.lifetime = 0.5
	fx.speed_min = 15.0
	fx.speed_max = 65.0
	fx.swirl = 90.0
	fx.damping = 18.0
	fx.scale_min = 0.15
	fx.scale_max = 0.35
	fx.burst_amount = 12
	fx.burst_speed = 190.0
	return fx


## Rosa-choque (Sae) com brilhos verde-veneno (Aiku): a aura do Striker
func _make_striker_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = SelfishFX.PINK
	fx.additive = false   # o campo é verde: mistura normal mantém a cor visível
	fx.trail_width = 20.0
	fx.particle_color = SelfishFX.VENOM
	fx.amount = 36
	fx.lifetime = 0.6
	fx.speed_min = 30.0
	fx.speed_max = 110.0
	fx.gravity = Vector2(0.0, -50.0)
	fx.spin = 300.0
	fx.scale_min = 0.2
	fx.scale_max = 0.4
	fx.burst_amount = 22
	fx.burst_speed = 300.0
	return fx


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m == null:
		return
	m.round_started.connect(func(_r: int) -> void:
		if _radar_until_round >= 0 and not is_radar_active():
			_end_radar())
	m.turn_ended.connect(func(ended_team: int) -> void:
		if ended_team != team:
			_clear_block())   # o bloqueio das gerais vale até o fim do próximo turno inimigo


func _exit_tree() -> void:
	_end_radar()
	_clear_lunge()


# ---------- AUXILIARES ----------

## Na defesa = na metade do campo do próprio gol (defense_split ajusta)
func is_in_defensive_sector() -> bool:
	var field := get_tree().get_first_node_in_group("field") as Field
	if field == null:
		return false
	return field.to_local(global_position).x * _default_facing() < defense_split * field.pitch_size.x * 0.5


## Inimigo que dá para escolher: de pé, no chão ou suspenso
func _is_target(p: Player) -> bool:
	return is_instance_valid(p) and p.team != team and not p.is_down \
		and (p.height_level == Heights.Level.GROUND or p.height_level == Heights.Level.SUSPENDED)


func _targets_near(radius: float) -> Array[Player]:
	var list: Array[Player] = []
	for other: Player in get_tree().get_nodes_in_group("players"):
		if _is_target(other) and global_position.distance_to(other.global_position) <= radius:
			list.append(other)
	return list


func _allies_near(radius: float) -> Array[Player]:
	var list: Array[Player] = []
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other != self and other.team == team and global_position.distance_to(other.global_position) <= radius:
			list.append(other)
	return list


func _base_force(level: Heights.Level) -> float:
	match level:
		Heights.Level.SUSPENDED:
			return kick_force_volley
		Heights.Level.FLYING:
			return kick_force_flying
	return kick_force_ground


## Deflect: toque fraco (múltiplo da força do Chutar), sem chance de gol. A cobra enrola na bola.
func _deflect(ball: Ball, dir: Vector2, mult: float) -> void:
	ball.kick(dir.normalized(), _base_force(ball.get_level()) * mult * kick_force_to_speed, 0.0, self, Ball.NO_SHOT)
	ball.play_fx(kick_fx)
	AikuFX.wrap(ball, 0.6, 14.0)
	AikuFX.burst(self, ball.global_position, 8)


func _ball_in_reach(ball: Ball, dir: Vector2, level: int) -> bool:
	if ball == null or ball.is_held() or ball.is_locked_for(team) or ball.get_level() != level:
		return false
	var to_ball: Vector2 = ball.global_position - global_position
	return to_ball.length() <= ball_reach_radius and to_ball.dot(dir) > 0.0   # só se está na frente


## Avanço de `distance` em `time` s (começa rápido e desacelera, como o Carrinho). Se look_level >= 0, para ao achar a bola
## desse nível NA FRENTE e devolve true. Quem está em outra altura não bloqueia o avanço.
func _dash(dir: Vector2, distance: float, time: float, look_level: int = -1) -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	var token: int = _dash_token
	face_towards(dir)
	var met: bool = false
	var elapsed: float = 0.0
	while elapsed < time:
		await get_tree().physics_frame
		if token != _dash_token or (m != null and m.match_over):
			break
		var dt: float = get_physics_process_delta_time()
		elapsed += dt
		velocity = dir * (2.0 * distance / time) * clampf(1.0 - elapsed / time, 0.0, 1.0)
		for other: Player in get_tree().get_nodes_in_group("players"):
			if other == self:
				continue
			if other.height_level != height_level:
				add_collision_exception_with(other)
				other.add_collision_exception_with(self)
			else:
				remove_collision_exception_with(other)
				other.remove_collision_exception_with(self)
		move_and_slide()
		if look_level >= 0 and _ball_in_reach(ball, dir, look_level):
			met = true
			break
	velocity = Vector2.ZERO
	_clear_slide_collision_exceptions()
	return met


## Vai (deslizando) até ficar a `stop` px do ponto
func _go_near(point: Vector2, stop: float, time: float) -> void:
	var offset: Vector2 = global_position - point
	if offset.length() < 1.0:
		return
	var tw: Tween = create_tween()
	tw.tween_property(self, "global_position", point + offset.normalized() * stop, time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished


# ---------- SNAKE LUNGE / SERPENTINE GRASP ----------

func _lunge_name() -> String:
	for p in _targets_near(lunge_range):
		if p.height_level == Heights.Level.GROUND:
			return "Snake Lunge"
	return "Serpentine Grasp" if not _targets_near(lunge_range).is_empty() else "Snake Lunge"


func _use_lunge() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	if _striker_partner() != null:
		return await _use_striker()   # reação Selfish pronta: o Snake Lunge vira o Striker
	var target: Player = await m.pick_ally_for_skill(self, lunge_range, true, _is_target)
	if target == null or not _is_target(target):
		return false   # cancelou: não gasta a ação
	var grasp: bool = target.height_level == Heights.Level.SUSPENDED
	face_towards(target.global_position - global_position)
	await play_action(&"serpentine_grasp" if grasp else &"snake_lunge", ANIM_SLIDE)
	AikuFX.wrap(self, 0.45)   # a cobra se enrola nele e dá o bote
	AikuFX.strike(self, global_position, target.global_position)
	await _go_near(target.global_position, lunge_stop_distance, lunge_dash_time)
	if grasp:
		target.knock_down()   # o suspenso é derrubado antes do confronto
	if randf() < (chance_grasp if grasp else chance_lunge):
		_clear_lunge()
		_lunge_target = target
		target.apply_lock(self, lunge_rounds, true)   # só as habilidades
		_lunge_bind = AikuFX.bind(target)             # a cobra fica enrolada nele enquanto vale
	else:
		AikuFX.burst(self, target.global_position, 10)   # perdeu: o bote falha
	start_cooldown(CD_LUNGE, lunge_cooldown)
	return true


## Solta o inimigo se o bloqueio acabou ou se o Aiku se afastou demais (60)
func _update_lunge() -> void:
	if _lunge_target == null:
		return
	if not is_instance_valid(_lunge_target) or _lunge_target.locked_by != self or not _lunge_target.is_skill_locked():
		_clear_lunge()
	elif global_position.distance_to(_lunge_target.global_position) > lunge_leash:
		_lunge_target.clear_lock()
		_clear_lunge()


func _clear_lunge() -> void:
	AikuFX.release(_lunge_bind)
	_lunge_bind = null
	_lunge_target = null


# ---------- STRIKER (Reação Química Selfish, com o Sae) ----------

## A reação Selfish (criada na primeira vez que precisa; não depende de registro no ReactionManager)
var _selfish_rx: ReactionSelfish = null


func _selfish_rx_get() -> ReactionSelfish:
	if _selfish_rx == null:
		_selfish_rx = ReactionSelfish.new()
	return _selfish_rx


## A Sae (parceira) se as condições da Selfish estão cumpridas e a bola está ao alcance; senão null
func _striker_partner() -> Player:
	var ball: Ball = _get_ball()
	if ball == null or get_kick_type(ball) == KickType.NONE:
		return null
	return _selfish_rx_get().find_partner(self)


## Usa a animação preferida se o personagem tiver; senão a reserva
func _anim_or(preferred: StringName, fallback: StringName) -> StringName:
	if _has_art and animated_sprite.sprite_frames.has_animation(preferred):
		return preferred
	return fallback


## Striker: cutscene e depois um chute 2.0x que sobe durante a trajetória, com 75% de chance de gol
func _use_striker() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or _striker_partner() == null:
		return false
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação

	# A bola pode ter rolado enquanto ele mirava: confere de novo
	var ball: Ball = _get_ball()
	var partner: Player = _striker_partner()
	if ball == null or partner == null:
		return false

	# A partida congela e roda a cutscene + diálogo. SÓ DEPOIS vem o chute.
	# (A mira já foi confirmada: cancelar a mira não gasta a reação nem a recarga dela.)
	var reaction: ReactionSelfish = _selfish_rx_get()
	await ReactionManager.get_for(self).play(reaction, self, partner)
	reaction.mark_used(team, m.round_number)

	next_shot_bonus = 0.0                       # o número final é o do Striker: o bônus do passe do Sae não soma
	next_kick_force_mult = striker_force_mult   # força final: nada mais soma
	var saved_peak: Heights.Level = volley_peak_level
	volley_peak_level = Heights.Level.FLYING    # a bola sobe durante a trajetória
	var touches: int = ball.interaction_count
	await kick_ball(ball, aim, KickType.VOLLEY, true, chance_striker, false, striker_fx,
		_anim_or(&"striker", &""), _striker_burst)
	volley_peak_level = saved_peak
	if ball.interaction_count == touches:
		return false   # o chute não saiu (ação cancelada)
	start_cooldown(CD_LUNGE, lunge_cooldown)
	return true


## Chamado pelo kick_ball() logo depois que a bola do Striker sai: a serpente sai do chute + brilhos
func _striker_burst(ball: Ball, _dir: Vector2, _speed: float) -> void:
	SelfishFX.serpent(self, ball, global_position + Vector2(0.0, -24.0))
	SelfishFX.striker_burst(self, ball.sprite.global_position if ball.sprite != null else ball.global_position)


# ---------- SERPENT SLIP / VENOM DEFLECT / NICE SHOT ----------

func get_slip_variant() -> SlipVariant:
	if is_down:
		return SlipVariant.NONE
	if height_level == Heights.Level.GROUND:
		return SlipVariant.SLIP
	if height_level == Heights.Level.SUSPENDED:
		var ball: Ball = _get_ball()
		if ball != null and not ball.is_held() and ball.get_level() == Heights.Level.FLYING \
				and global_position.distance_to(ball.global_position) <= nice_range:
			return SlipVariant.NICE
		return SlipVariant.VENOM
	return SlipVariant.NONE


func _use_slip() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	match get_slip_variant():
		SlipVariant.SLIP:
			return await _do_slip(m)
		SlipVariant.VENOM:
			return await _do_venom(m)
		SlipVariant.NICE:
			return await _do_nice(m)
	return false


## Avanço curto + Carrinho. Se o Carrinho achar a bola, ele acaba ali e vira um passe rasteiro.
func _do_slip(m: MatchManager) -> bool:
	var aim: Vector2 = await m.aim_for_skill(self, slip_dash + slide_distance)
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação
	face_towards(aim)
	AikuFX.slither(self, global_position, global_position + aim * (slip_dash + slide_distance), 0.9)
	await _dash(aim, slip_dash, slip_dash_time)
	_slip_active = true
	_slip_ball_found = false
	start_slide(aim)
	slides_this_turn = maxi(0, slides_this_turn - 1)   # é habilidade: não gasta o limite de Carrinhos do turno
	await slide_finished
	_slip_active = false

	var ball: Ball = _get_ball()
	if _slip_ball_found and is_instance_valid(ball) and not m.match_over \
			and not _allies_near(slip_pass_range).is_empty():
		var target: Player = await m.pick_ally_for_skill(self, slip_pass_range)
		if target == null:
			m._skill_pick_cancelled = false   # a ação já foi gasta: cancelar o passe não pode devolvê-la
		else:
			AikuFX.slither(self, ball.global_position, target.global_position, 0.7)
			await m.run_ground_pass(self, target, ball)
	start_cooldown(CD_SLIP, slip_cooldown)
	return true


## O Carrinho do Slip trata a bola aqui (passe) em vez do chute padrão do Carrinho
func _check_slide_hits() -> void:
	if not _slip_active:
		super()
		return
	_slide_hit_ball = true   # impede o chute padrão na bola; os inimigos continuam caindo normalmente
	super()
	if _slip_ball_found:
		return
	var ball: Ball = _get_ball()
	if ball and not ball.is_held() and not ball.is_locked_for(team) and ball.get_level() == Heights.Level.GROUND \
			and global_position.distance_to(ball.global_position) <= slide_hit_radius:
		_slip_ball_found = true
		slide_time_left = 0.0   # encontrou a bola: o Carrinho termina aqui


## Avanço aéreo; se achar a bola suspensa, deflect
func _do_venom(m: MatchManager) -> bool:
	var aim: Vector2 = await m.aim_for_skill(self, venom_dash)
	if aim == Vector2.ZERO:
		return false
	var ball: Ball = _get_ball()
	AikuFX.slither(self, global_position, global_position + aim * venom_dash, 0.5)
	var met: bool = await _dash(aim, venom_dash, venom_dash_time, Heights.Level.SUSPENDED)
	if met and is_instance_valid(ball) and not m.match_over:
		_deflect(ball, aim, venom_force_mult)
	start_cooldown(CD_SLIP, slip_cooldown)
	return true


## Deflect direcional na bola voando; quando ela cair, o Aiku vai até ela e ganha +1 ação geral
func _do_nice(m: MatchManager) -> bool:
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false
	var ball: Ball = _get_ball()
	if get_slip_variant() != SlipVariant.NICE:
		return false   # a bola saiu do alcance enquanto ele mirava
	face_towards(aim)
	await play_action(&"nice_shot", ANIM_KICK)
	_deflect(ball, aim, nice_force_mult)
	land()
	if await _wait_ball_down(ball):
		AikuFX.slither(self, global_position, ball.global_position, 0.5)
		await _go_near(ball.global_position, body_radius + ball.collision_radius + 2.0, 0.3)
		extra_general_left += 1
	start_cooldown(CD_SLIP, slip_cooldown)
	return true


## Espera a bola voltar ao chão (true) ou alguém mexer nela / passar o tempo (false)
func _wait_ball_down(ball: Ball, timeout: float = 4.0) -> bool:
	var touches: int = ball.interaction_count
	var waited: float = 0.0
	while waited < timeout:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
		if not is_instance_valid(ball) or ball.interaction_count != touches or ball.is_held():
			return false
		if ball.get_level() == Heights.Level.GROUND and ball.height <= 1.0:
			return true
	return false


# ---------- BURGLAR RADAR ----------

func is_radar_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _radar_until_round >= 0 and m.round_number <= _radar_until_round


## Dentro da área do radar o Aiku libera Ultimate Defense e Blooming Halt
func _inside_radar() -> bool:
	return is_radar_active() and global_position.distance_to(_radar_center) <= radar_radius


func _use_radar() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or not await play_action(&"burglar_radar"):
		return false
	_radar_center = global_position   # a área é FIXA: fica onde foi criada
	_radar_until_round = m.round_number + radar_rounds - 1
	start_cooldown(CD_RADAR, radar_cooldown, _radar_until_round + 1)   # conta a partir do fim do efeito
	_defense_used = false
	_halt_used = false
	_ball_inside = false
	AikuFX.wrap(self, 0.8, 30.0)
	_radar_fx = AikuFX.radar(self, _radar_center, radar_radius)   # a cobra devorando o próprio corpo
	AikuFX.release(_radar_coil)
	_radar_coil = AikuFX.bind(self)   # e uma cobrinha enrolada nele enquanto o radar durar
	return true


func _end_radar() -> void:
	if _radar_fx != null and is_instance_valid(_radar_fx):
		_radar_fx.release()
	_radar_fx = null
	AikuFX.release(_radar_coil)
	_radar_coil = null
	_radar_until_round = -1
	_clear_halt()
	_clear_block()


## Penalidade nos chutes INIMIGOS (o Player consulta o grupo control_sources): -7% dentro da área, +6% do Halt
func shot_penalty_on(shooter: Player) -> float:
	var total: float = 0.0
	if is_radar_active() and shooter.global_position.distance_to(_radar_center) <= radar_radius:
		total += radar_penalty
	if _halt_target != null and shooter == _halt_target:
		total += halt_penalty
	return total


## Blooming Halt: o inimigo marcado chutou. A marca estoura (força pela metade), e passa para outro inimigo perto
func on_opponent_shot_attempt(shooter: Player) -> void:
	if _halt_target == null or shooter != _halt_target or not is_radar_active():
		return
	var ball: Ball = _get_ball()
	var next: Player = null
	var best: float = halt_chain_radius
	for other: Player in get_tree().get_nodes_in_group("players"):
		var d: float = shooter.global_position.distance_to(other.global_position)
		if other != shooter and _is_target(other) and d <= best:
			next = other
			best = d
	AikuFX.pop(_halt_mark, self, shooter.global_position)
	_halt_mark = null
	_halt_target = null
	if next != null:
		_set_halt(next)
	await get_tree().physics_frame   # a velocidade da bola só é definida depois do aviso do chute
	if is_instance_valid(ball) and ball.last_toucher == shooter and ball.has_pending_shot():
		ball.velocity *= halt_force_mult


func _set_halt(target: Player) -> void:
	AikuFX.release(_halt_mark)
	_halt_target = target
	_halt_mark = AikuFX.mark(target)


func _clear_halt() -> void:
	AikuFX.release(_halt_mark)
	_halt_mark = null
	_halt_target = null


## Ultimate Defense: inimigo sem ações gerais (o Player consulta o grupo control_sources)
func suppresses_generals_of(p: Player) -> bool:
	return _block_target != null and p == _block_target


func _clear_block() -> void:
	AikuFX.release(_block_bind)
	_block_bind = null
	_block_target = null


## Se a bola vier SUSPENSA para dentro da área, 30% de chance de o Aiku ir até ela e dar um deflect sozinho
func _update_radar_watch() -> void:
	if not is_radar_active():
		_ball_inside = false
		return
	var ball: Ball = _get_ball()
	var inside: bool = ball != null and ball.global_position.distance_to(_radar_center) <= radar_radius
	var entering: bool = inside and not _ball_inside
	_ball_inside = inside
	if not entering or _auto_busy or is_down or state != State.IDLE or height_level != Heights.Level.GROUND:
		return
	var thrower := ball.last_toucher as Player
	if ball.get_level() != Heights.Level.SUSPENDED or ball.velocity.length() < 120.0 or ball.is_held() \
			or thrower == null or thrower.team == team:
		return
	if randf() < radar_catch_chance:
		_auto_catch(ball)


func _auto_catch(ball: Ball) -> void:
	_auto_busy = true
	AikuFX.strike(self, global_position, ball.global_position, 0.5)
	var spot: Vector2 = ball.global_position + ball.velocity * 0.15   # a bola vem rápido: vai onde ela estará
	height_level = Heights.Level.SUSPENDED
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", spot, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "height", Heights.to_height(Heights.Level.SUSPENDED), 0.15)
	await tw.finished
	if is_instance_valid(ball) and not ball.is_held() and ball.get_level() == Heights.Level.SUSPENDED \
			and global_position.distance_to(ball.global_position) <= ball_reach_radius * 1.6:
		_deflect(ball, Vector2(_default_facing(), 0.0).rotated(deg_to_rad(randf_range(-25.0, 25.0))), radar_deflect_mult)
	land()
	_auto_busy = false


func _defense_ready() -> bool:
	var ball: Ball = _get_ball()
	return _inside_radar() and not _defense_used and height_level == Heights.Level.GROUND and ball != null \
		and not ball.is_held() and ball.get_level() == Heights.Level.FLYING \
		and global_position.distance_to(ball.global_position) <= defense_range


## Salta até a bola voando, cabeceia (0.7x), desce e pode ir até um inimigo para bloquear as ações gerais dele
func _use_defense() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or not _defense_ready():
		return false
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)   # a direção do cabeceio
	var ball: Ball = _get_ball()
	if aim == Vector2.ZERO or not _defense_ready():
		return false   # cancelou (ou a bola saiu do alcance): não gasta a ação
	face_towards(aim)
	await play_action(&"ultimate_defense", ANIM_JUMP)
	AikuFX.wrap(self, 0.6)
	height_level = Heights.Level.FLYING
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "height", Heights.to_height(Heights.Level.FLYING), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", ball.global_position, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	if is_instance_valid(ball) and not ball.is_held():
		_deflect(ball, aim, header_force_mult)
	land()
	_defense_used = true

	if not _targets_near(defense_block_range).is_empty():   # opcional: escolher quem bloquear
		var target: Player = await m.pick_ally_for_skill(self, defense_block_range, true, _is_target)
		if target == null:
			m._skill_pick_cancelled = false   # a ação já foi gasta: cancelar a escolha não pode devolvê-la
		else:
			AikuFX.strike(self, global_position, target.global_position)
			await _go_near(target.global_position, lunge_stop_distance, lunge_dash_time)
			_clear_block()
			_block_target = target
			_block_bind = AikuFX.bind(target)
	return true


func _halt_ready() -> bool:
	return _inside_radar() and not _halt_used and height_level == Heights.Level.GROUND \
		and not _targets_near(halt_range).is_empty()


## Blooming Halt: marca um inimigo (no chão ou suspenso)
func _use_halt() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or not _halt_ready():
		return false
	var target: Player = await m.pick_ally_for_skill(self, halt_range, true, _is_target)
	if target == null or not _is_target(target):
		return false   # cancelou: não gasta a ação
	face_towards(target.global_position - global_position)
	await play_action(&"blooming_halt", ANIM_KICK)
	AikuFX.strike(self, global_position, target.global_position, 0.6)
	_set_halt(target)
	_halt_used = true
	return true


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var slip_name: String = "Serpent Slip"
	match get_slip_variant():
		SlipVariant.VENOM:
			slip_name = "Venom Deflect"
		SlipVariant.NICE:
			slip_name = "Nice Shot"
	var radar_name: String = "Burglar Radar (ativo)" if is_radar_active() else skill_label("Burglar Radar", CD_RADAR)
	return [
		{"id": SKILL_LUNGE, "name": skill_label("Striker" if _striker_partner() != null else _lunge_name(), CD_LUNGE)},
		{"id": SKILL_SLIP, "name": skill_label(slip_name, CD_SLIP)},
		{"id": SKILL_RADAR, "name": radar_name},
		{"id": SKILL_DEFENSE, "name": "Ultimate Defense" + (" (usado)" if _defense_used else "")},
		{"id": SKILL_HALT, "name": "Blooming Halt" + (" (usado)" if _halt_used else "")},
	]


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_LUNGE:
			if is_on_cooldown(CD_LUNGE):
				return false
			if _striker_partner() != null:
				return true   # Striker (reação Selfish): não precisa de inimigo por perto
			return height_level == Heights.Level.GROUND and not _targets_near(lunge_range).is_empty()
		SKILL_SLIP:
			return not is_on_cooldown(CD_SLIP) and get_slip_variant() != SlipVariant.NONE
		SKILL_RADAR:
			return not is_radar_active() and not is_on_cooldown(CD_RADAR) and is_in_defensive_sector()
		SKILL_DEFENSE:
			return _defense_ready()
		SKILL_HALT:
			return _halt_ready()
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_LUNGE:
			return await _use_lunge()
		SKILL_SLIP:
			return await _use_slip()
		SKILL_RADAR:
			return await _use_radar()
		SKILL_DEFENSE:
			return await _use_defense()
		SKILL_HALT:
			return await _use_halt()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_LUNGE:
			title = _lunge_name()
			text = ("Aiku no chão vai até um inimigo no chão (alcance %d) e inicia um confronto físico (%d%% de vitória). Vencendo, "
				+ "bloqueia as habilidades dele por %d rodadas ou até o Aiku sair de perto (%d).\n"
				+ "• Serpentine Grasp (inimigo suspenso): vai até ele, derruba e faz o Snake Lunge (%d%%).\nRecarga: %d rodadas.") % [
				int(lunge_range), int(round(chance_lunge * 100.0)), lunge_rounds, int(lunge_leash),
				int(round(chance_grasp * 100.0)), lunge_cooldown]
		SKILL_SLIP:
			title = get_skills()[1]["name"].split(" (")[0]
			text = ("Aiku no chão dá um avanço curto (%d) seguido de um Carrinho; se o Carrinho achar a bola, vira um passe rasteiro "
				+ "para um aliado (alcance %d).\n"
				+ "• Venom Deflect (Aiku suspenso): avanço aéreo (%d); achando a bola suspensa, dá um deflect (%.1fx de força).\n"
				+ "• Nice Shot (suspenso, bola voando a até %d): deflect direcional (%.1fx); quando a bola cair, o Aiku vai até ela "
				+ "e ganha +1 ação geral.\nRecarga: %d rodadas, compartilhada.") % [
				int(slip_dash), int(slip_pass_range), int(venom_dash), venom_force_mult, int(nice_range), nice_force_mult, slip_cooldown]
		SKILL_RADAR:
			title = "Burglar Radar"
			text = ("Só na defesa. Cria uma área fixa (alcance %d) por %d rodadas: chutes inimigos dentro dela têm -%d%% de chance e, "
				+ "se a bola vier suspensa, o Aiku tem %d%% de ir até ela e dar um deflect. Libera Ultimate Defense e Blooming Halt "
				+ "(uso único cada).\nRecarga: %d rodadas após o fim.") % [
				int(radar_radius), radar_rounds, int(round(radar_penalty * 100.0)), int(round(radar_catch_chance * 100.0)), radar_cooldown]
		SKILL_DEFENSE:
			title = "Ultimate Defense"
			text = ("Durante o radar: salta até a bola voando (alcance %d), cabeceia (%.1fx de força), desce e pode escolher um "
				+ "inimigo a até %d para ir até ele e bloquear as ações gerais dele por 1 rodada. Uso único.") % [
				int(defense_range), header_force_mult, int(defense_block_range)]
		SKILL_HALT:
			title = "Blooming Halt"
			text = ("Durante o radar: marca um inimigo. Se ele tentar chutar no turno inimigo, a marca estoura: a força cai pela "
				+ "metade, o chute perde %d%% e outro inimigo próximo é marcado (somado à penalidade da área). Uso único.") % int(round(halt_penalty * 100.0))
		_:
			return {}
	if skill_id == SKILL_LUNGE and _striker_partner() != null:
		title = "Striker (Reação Selfish)"
		text = "Com o Sae: chute %.1fx mais forte, a bola sobe durante a trajetória e %d%% de chance de gol. Uma serpente sai do chute.\nRecarga: %d rodadas." % [
			striker_force_mult, int(round(chance_striker * 100.0)), lunge_cooldown]
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()   # também solta a trava que o Aiku sofreu, se houver
	_dash_token += 1   # um avanço em andamento percebe e para
	if _lunge_target != null and is_instance_valid(_lunge_target):
		_lunge_target.clear_lock()
	_clear_lunge()
	_end_radar()
	_defense_used = false
	_halt_used = false
	_slip_active = false
	_auto_busy = false
	_clear_slide_collision_exceptions()


func _physics_process(delta: float) -> void:
	super(delta)
	_update_lunge()
	_update_radar_watch()
