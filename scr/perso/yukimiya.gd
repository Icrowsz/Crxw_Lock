class_name Yukimiya
extends Player
## Yukimiya (Yuki). Herda tudo do Player (ações gerais) e adiciona as habilidades próprias.
## Este script NÃO exige mudanças em nenhum outro arquivo: tudo usa só a API pública que o
## Player, a Ball e o MatchManager já têm.
##
## 1. Gyro Shot (ação de habilidade; recarga de 2 rodadas, compartilhada com o Sword Screw):
##      - Yuki no chão + bola no chão       -> Gyro Shot: a bola sobe até Suspensa, cai e faz curvas
##                                             improváveis pelo caminho (45%)
##      - Yuki suspenso + bola no chão ou suspensa -> Sword Screw: a bola vai RETA, mas sobe até
##                                             Voando, desce ao chão e sobe de novo até Suspensa (50%)
## 2. Street Dribble (ação de habilidade; recarga de 3 rodadas, compartilhada com o Predator Blind):
##      duas corridas mais curtas seguidas. Se encostar na bola, ela gruda nele e libera o
##      Predator Blind (complemento gratuito, vale até o fim do turno).
##      - Predator Blind: +5% nos próximos 3 chutes do Yuki, mais curvas no Gyro Shot e mais
##        subidas e descidas no Sword Screw (enquanto ainda houver chutes do bônus).
## 3. Vs Emperor (ação de habilidade; recarga de 2 rodadas, compartilhada com o Goal in Time):
##      - Bola no chão perto do Yuki -> Vs Emperor: ele segura a bola para si até o começo do
##        próximo turno do time dele. Se um inimigo tentar tirá-la (Carrinho), ele desvia e
##        ganha +1 ação geral (só a primeira vez por Vs Emperor, igual ao Gremlin Taunt).
##      - Bola suspensa perto do Yuki e 2+ inimigos perto dele -> Goal in Time: chute curvo
##        para a direita (a curva vira para a direita de quem chuta).
##
## Ao mirar o Gyro Shot, o Sword Screw ou o Goal in Time aparece a TRAJETÓRIA do chute (a bola é simulada
## como o Ball faz). As curvas "improváveis" do Gyro Shot são sorteadas ANTES da mira e o chute usa exatamente
## essas curvas, então o desenho mostra o caminho de verdade. Precisa do ball_path_preview.gd.
## Liga/desliga em show_trajectory.
##
## Como montar a cena: Nova Cena Herdada de player.tscn -> anexe este script ao nó raiz
## -> renomeie o nó raiz para "Yukimiya".
## Animações opcionais (nomes na SpriteFrames): gyro_shot, sword_screw, street_dribble,
## predator_blind, vs_emperor, goal_in_time. As que faltarem são puladas.

const SKILL_SHOT: StringName = &"gyro_shot"
const SKILL_DRIBBLE: StringName = &"street_dribble"
const SKILL_PREDATOR: StringName = &"predator_blind"
const SKILL_EMPEROR: StringName = &"vs_emperor"

## Grupos de recarga (as variantes e complementos compartilham o mesmo)
const CD_SHOT: StringName = &"cd_gyro"
const CD_DRIBBLE: StringName = &"cd_dribble"
const CD_EMPEROR: StringName = &"cd_emperor"

enum ShotVariant { NONE, GYRO, SWORD }
enum EmperorVariant { NONE, EMPEROR, GOAL }
## Qual trajetória está sendo mirada agora (NONE = nenhuma na tela)
enum Preview { NONE, GYRO, SWORD, GOAL }

const COLOR_ORANGE := Color(1.0, 0.55, 0.1)
const COLOR_BROWN := Color(0.55, 0.32, 0.12)
const COLOR_PURPLE := Color(0.65, 0.3, 0.95)

@export_group("Gyro Shot / Sword Screw")
@export_range(0.0, 1.0) var chance_gyro: float = 0.45
@export_range(0.0, 1.0) var chance_sword: float = 0.50
@export var shot_cooldown: int = 2
## Gyro Shot: quantas curvas, quanto dura cada uma (s) e o desvio de cada curva (graus)
@export var gyro_segments: int = 2
@export var gyro_segment_time: float = 0.35
@export var gyro_curve_min_deg: float = 25.0
@export var gyro_curve_max_deg: float = 55.0
## Sword Screw: duração de cada subida/descida (s), velocidade (fração da força do voleio)
@export var screw_leg_time: float = 0.4
@export var screw_speed_mult: float = 0.7

@export_group("Trajetória do chute")
@export var show_trajectory: bool = true              # mostra o caminho da bola enquanto mira
@export var trajectory_length: float = 650.0          # tamanho máximo do desenho (px)

@export_group("Street Dribble / Predator Blind")
@export var dribble_runs: int = 2                     # quantas corridas curtas seguidas
@export_range(0.1, 1.0) var dribble_run_mult: float = 0.6   # fração do tempo normal do Correr
@export var dribble_catch_margin: float = 14.0        # folga (px) além do raio do corpo + bola
@export var dribble_cooldown: int = 3
@export var blind_shots: int = 3                      # quantos chutes recebem o bônus
@export_range(0.0, 1.0) var blind_bonus: float = 0.05
@export var blind_extra_segments: int = 2             # curvas a mais no Gyro Shot
@export var blind_extra_bounces: int = 1              # subidas/descidas a mais no Sword Screw

@export_group("Vs Emperor / Goal in Time")
@export var emperor_cooldown: int = 2
@export var emperor_extra_general: int = 1            # ações gerais ganhas ao desviar
@export_range(0.0, 1.0) var chance_goal: float = 0.45
@export var goal_enemy_radius: float = 180.0          # "inimigos perto" (px)
@export var goal_enemies_needed: int = 2
@export var goal_curve_time: float = 0.2
@export var goal_curve_deg: float = 30.0              # quanto a bola vira para a direita

@export_group("Visual do chute")
## Vazio = usa os estilos padrão do Yuki (laranja; roxo com o Predator Blind ativo)
@export var kick_fx: KickFX
@export var kick_fx_blind: KickFX

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: gyro_shot, street_dribble, predator_blind, vs_emperor.
## Sem imagem, o balão aparece só com o texto.
@export var skill_icons: Dictionary = {}

var _blind_shots_left: int = 0
var _predator_ready: bool = false       # complemento esperando (vale até o fim do turno)
var _dribbling: bool = false            # dentro do Street Dribble
var _dribble_got_ball: bool = false

var _held_ball: Ball = null             # bola grudada no Yuki (Street Dribble / Vs Emperor)
var _emperor_active: bool = false
var _emperor_bonus_used: bool = false
var _threat_seen: Array[Player] = []

var _curve_token: int = 0               # muda a cada efeito de trajetória novo (cancela o anterior)

var _preview: Preview = Preview.NONE
var _gyro_plan: Array = []              # curvas do Gyro Shot (radianos, com sinal), sorteadas antes da mira


func _init() -> void:
	character_id = "yukimiya"
	display_name = "Yukimiya"


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = _make_fx(false)
	if kick_fx_blind == null:
		kick_fx_blind = _make_fx(true)
	_hook_manager.call_deferred()


## Laranja; as partículas são marrons (ou roxas com o Predator Blind)
func _make_fx(blind: bool) -> KickFX:
	var fx := KickFX.new()
	fx.color = COLOR_ORANGE
	fx.trail_width = 14.0
	fx.particle_color = COLOR_PURPLE if blind else COLOR_BROWN
	fx.amount = 24
	fx.lifetime = 0.55
	fx.speed_min = 15.0
	fx.speed_max = 80.0
	fx.gravity = Vector2(0.0, -50.0)
	fx.spin = 240.0
	fx.scale_min = 0.15
	fx.scale_max = 0.35
	fx.burst_amount = 16
	fx.burst_speed = 220.0
	return fx


func _current_fx(blind: bool) -> KickFX:
	return kick_fx_blind if blind else kick_fx


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m:
		m.turn_started.connect(_on_turn_started)
		m.turn_ended.connect(_on_turn_ended)


func _on_turn_started(turn_team: int) -> void:
	# O Vs Emperor dura até o começo do próximo turno do time do Yuki
	if turn_team == team and _emperor_active:
		_end_emperor()


func _on_turn_ended(turn_team: int) -> void:
	# O Predator Blind (complemento) só vale no turno em que foi liberado
	if turn_team == team and _predator_ready:
		_predator_ready = false
		queue_redraw()


# ---------- CHUTE COM A BOLA GRUDADA ----------

## Com a bola grudada nele (Street Dribble / Vs Emperor) o Yuki ainda consegue chutar:
## o Ball.is_held() bloquearia o get_kick_type do Player, então liberamos só durante a checagem.
func get_kick_type(ball: Ball) -> KickType:
	if ball != null and ball.held_by == self:
		ball.held_by = null
		var kind: KickType = super(ball)
		ball.held_by = self
		return kind
	return super(ball)


## Predator Blind: +5% nos próximos 3 chutes (qualquer chute: geral ou habilidade)
func kick_ball(ball: Ball, direction: Vector2, kind: KickType, qte_success: bool = true,
		chance_override: float = -1.0, ignore_self_collision: bool = false,
		fx: KickFX = null, anim: StringName = &"", extra_callback: Callable = Callable()) -> void:
	var final_chance: float = chance_override
	if _blind_shots_left > 0:
		_blind_shots_left -= 1
		var base: float = chance_override if chance_override >= 0.0 else get_shot_chance(kind)
		final_chance = minf(base + blind_bonus, 1.0)
		queue_redraw()
	await super(ball, direction, kind, qte_success, final_chance, ignore_self_collision, fx, anim, extra_callback)


# ---------- TRAJETÓRIAS ESPECIAIS DA BOLA ----------

## A bola ainda é "do chute" do Yuki? (parou, foi tocada por outro, pega pelo goleiro... = não)
func _ball_follows_my_shot(ball: Ball) -> bool:
	return is_instance_valid(ball) and not ball.hovering and ball.held_by == null \
		and ball.last_toucher == self and ball.velocity.length() > 30.0


## Curvas: gira a direção da bola aos poucos, alternando o lado a cada trecho.
## first_sign: +1 = começa virando para a direita (sentido horário na tela), -1 = esquerda,
## 0 = sorteia (as curvas "improváveis" do Gyro Shot).
## plan: se dado, usa estas curvas (radianos, com sinal, uma por trecho) em vez de sortear
## (é como o Gyro Shot usa as curvas que a trajetória já mostrou na mira).
func _curve_ball(ball: Ball, segments: int, seg_time: float, min_deg: float, max_deg: float,
		first_sign: float = 0.0, plan: Array = []) -> void:
	_curve_token += 1
	var token: int = _curve_token
	var side: float = first_sign if first_sign != 0.0 else (1.0 if randf() < 0.5 else -1.0)
	if not plan.is_empty():
		segments = plan.size()
	for i in segments:
		var total: float = deg_to_rad(randf_range(min_deg, max_deg)) * side
		if not plan.is_empty():
			total = float(plan[i])
		var t: float = 0.0
		while t < seg_time:
			await get_tree().physics_frame
			if token != _curve_token or not _ball_follows_my_shot(ball):
				return
			var dt: float = get_physics_process_delta_time()
			t += dt
			ball.velocity = ball.velocity.rotated(total * dt / seg_time)
		side = -side


## Sword Screw: a bola vai reta e a altura é controlada por aqui (a bola fica "pairando"):
## Voando -> chão -> (Suspensa -> chão)* -> Suspensa. No fim solta a bola (ela cai e quica).
func _screw_ball(ball: Ball, dir: Vector2, extra_bounces: int) -> void:
	_curve_token += 1
	var token: int = _curve_token
	var d: Vector2 = dir.normalized()
	var speed: float = kick_force_volley * kick_force_to_speed * screw_speed_mult

	var waypoints: Array[float] = [Heights.FLYING_HEIGHT, Heights.GROUND_HEIGHT]
	for i in extra_bounces:
		waypoints.append(Heights.SUSPENDED_HEIGHT)
		waypoints.append(Heights.GROUND_HEIGHT)
	waypoints.append(Heights.SUSPENDED_HEIGHT)

	ball.velocity = Vector2.ZERO
	ball.vel_z = 0.0
	ball.hovering = true   # a gravidade e o rolar da bola ficam por minha conta nesse trecho
	ball.trail_enabled = true
	ball.fx_during_hover = true   # a aura do chute acompanha a bola enquanto ela paira

	for target_h in waypoints:
		var from_h: float = ball.height
		var t: float = 0.0
		while t < screw_leg_time:
			await get_tree().physics_frame
			# Cancelado: outro efeito, ou alguém mexeu na bola (goleiro pegou, outro chutou...)
			if token != _curve_token or not is_instance_valid(ball) \
					or not ball.hovering or ball.held_by != null:
				if is_instance_valid(ball):
					ball.fx_during_hover = false
				return
			var dt: float = get_physics_process_delta_time()
			t += dt
			var k: float = clampf(t / screw_leg_time, 0.0, 1.0)
			ball.height = lerpf(from_h, target_h, sin(k * PI * 0.5))
			ball.global_position += d * speed * dt

	if token == _curve_token and is_instance_valid(ball) and ball.hovering:
		ball.fx_during_hover = false
		ball.release_hover()
		ball.velocity = d * speed * 0.5
	elif is_instance_valid(ball):
		ball.fx_during_hover = false


# ---------- TRAJETÓRIA DO CHUTE (pré-visualização) ----------

## Sorteia as curvas do Gyro Shot (alternando o lado a cada trecho, como o _curve_ball fazia)
func _roll_gyro_plan(blind: bool) -> Array:
	var segments: int = gyro_segments + (blind_extra_segments if blind else 0)
	var side: float = 1.0 if randf() < 0.5 else -1.0
	var plan: Array = []
	for i in segments:
		plan.append(deg_to_rad(randf_range(gyro_curve_min_deg, gyro_curve_max_deg)) * side)
		side = -side
	return plan


## O caminho que a bola vai fazer com a mira atual, conforme o chute que está sendo mirado
func _trajectory_data() -> Dictionary:
	var ball: Ball = _get_ball()
	if ball == null or _preview == Preview.NONE:
		return {}
	var dir: Vector2 = aim_direction.normalized()
	match _preview:
		Preview.GYRO:
			# Voleio com as curvas sorteadas (elas continuam depois do chute, mesmo com a bola quicando)
			var launch: Dictionary = BallPathPreview.launch_for(self, ball, KickType.VOLLEY)
			return BallPathPreview.simulate(ball, ball.global_position, ball.height,
				dir * float(launch["speed"]), float(launch["lift"]),
				_gyro_plan, gyro_segment_time, false, trajectory_length)
		Preview.GOAL:
			# Um chute comum com uma curva só, para a direita de quem chuta
			var kind: KickType = get_kick_type(ball)
			if kind == KickType.NONE:
				return {}
			var launch2: Dictionary = BallPathPreview.launch_for(self, ball, kind)
			return BallPathPreview.simulate(ball, ball.global_position, ball.height,
				dir * float(launch2["speed"]), float(launch2["lift"]),
				[deg_to_rad(goal_curve_deg)], goal_curve_time, false, trajectory_length)
		Preview.SWORD:
			return _screw_trajectory(ball, dir)
	return {}


## Sword Screw: reta, com a altura subindo e descendo por trechos (igual ao _screw_ball), e a queda no fim
func _screw_trajectory(ball: Ball, dir: Vector2) -> Dictionary:
	var speed: float = kick_force_volley * kick_force_to_speed * screw_speed_mult
	var blind: bool = _blind_shots_left > 0
	var waypoints: Array[float] = [Heights.FLYING_HEIGHT, Heights.GROUND_HEIGHT]
	for i in (blind_extra_bounces if blind else 0):
		waypoints.append(Heights.SUSPENDED_HEIGHT)
		waypoints.append(Heights.GROUND_HEIGHT)
	waypoints.append(Heights.SUSPENDED_HEIGHT)

	var step: float = BallPathPreview.STEP
	var pos: Vector2 = ball.global_position
	var h: float = ball.height
	var points: Array[Vector2] = [pos]
	var heights: Array[float] = [h]
	var bounces: Array[Vector2] = []
	var length: float = 0.0
	var frame: int = 0
	for target_h in waypoints:
		var from_h: float = h
		var t: float = 0.0
		while t < screw_leg_time and length < trajectory_length:
			t += step
			var k: float = clampf(t / screw_leg_time, 0.0, 1.0)
			h = lerpf(from_h, target_h, sin(k * PI * 0.5))
			pos += dir * speed * step
			length += speed * step
			frame += 1
			if frame % 3 == 0:
				points.append(pos)
				heights.append(h)
		if target_h <= Heights.GROUND_HEIGHT:
			bounces.append(pos)   # toca o chão aqui
	# No fim a bola é solta (cai e quica) com metade da velocidade
	if length < trajectory_length:
		var tail: Dictionary = BallPathPreview.simulate(ball, pos, h, dir * speed * 0.5, 0.0,
			[], 0.2, false, trajectory_length - length)
		points.append_array(tail["points"])
		heights.append_array(tail["heights"])
		bounces.append_array(tail["bounces"])
	return {"points": points, "heights": heights, "bounces": bounces}


# ---------- GYRO SHOT / SWORD SCREW ----------

func get_shot_variant() -> ShotVariant:
	var ball: Ball = _get_ball()
	# get_kick_type já confere: derrubado, bola na mão do goleiro, longe demais, altura inalcançável
	if get_kick_type(ball) == KickType.NONE:
		return ShotVariant.NONE
	var ball_level: Heights.Level = ball.get_level()
	if height_level == Heights.Level.GROUND:
		if ball_level == Heights.Level.GROUND:
			return ShotVariant.GYRO
	elif height_level == Heights.Level.SUSPENDED:
		if ball_level == Heights.Level.GROUND or ball_level == Heights.Level.SUSPENDED:
			return ShotVariant.SWORD
	return ShotVariant.NONE


func _shot_skill_name() -> String:
	return "Sword Screw" if get_shot_variant() == ShotVariant.SWORD else "Gyro Shot"


func _use_shot_skill() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or get_shot_variant() == ShotVariant.NONE:
		return false

	# Trajetória na tela enquanto mira. As curvas do Gyro são sorteadas AGORA e o chute usa as mesmas
	_preview = Preview.GYRO if get_shot_variant() == ShotVariant.GYRO else Preview.SWORD
	if _preview == Preview.GYRO:
		_gyro_plan = _roll_gyro_plan(_blind_shots_left > 0)
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	_preview = Preview.NONE
	queue_redraw()
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação

	# A bola pode ter rolado enquanto ele mirava: confere de novo
	var ball: Ball = _get_ball()
	var variant: ShotVariant = get_shot_variant()
	if variant == ShotVariant.NONE:
		return false

	var blind: bool = _blind_shots_left > 0   # confere ANTES: o kick_ball gasta um chute do bônus
	var fx: KickFX = _current_fx(blind)

	# Os dois chutes usam o "voleio" do Player: a bola sobe até o pico Suspenso
	if variant == ShotVariant.GYRO:
		await kick_ball(ball, aim, KickType.VOLLEY, true, chance_gyro, false, fx, &"gyro_shot")
		start_cooldown(CD_SHOT, shot_cooldown)
		var segments: int = gyro_segments + (blind_extra_segments if blind else 0)
		if _gyro_plan.size() != segments:
			_gyro_plan = _roll_gyro_plan(blind)   # o bônus mudou durante a mira: sorteia de novo
		_curve_ball(ball, segments, gyro_segment_time, gyro_curve_min_deg, gyro_curve_max_deg, 0.0, _gyro_plan)
	else:
		await kick_ball(ball, aim, KickType.VOLLEY, true, chance_sword, false, fx, &"sword_screw")
		start_cooldown(CD_SHOT, shot_cooldown)
		_screw_ball(ball, aim, blind_extra_bounces if blind else 0)
	return true


# ---------- STREET DRIBBLE / PREDATOR BLIND ----------

func _use_dribble() -> bool:
	if _get_manager() == null:
		return false
	_dribbling = true
	_dribble_got_ball = false
	await play_action(&"street_dribble")
	for i in dribble_runs:
		await _short_run()
	_dribbling = false
	_release_held_ball()   # a bola fica parada ao lado dele
	start_cooldown(CD_DRIBBLE, dribble_cooldown)
	if _dribble_got_ball:
		_predator_ready = true
		queue_redraw()
	return true


## Uma corrida mais curta; não gasta o limite de Correr do turno
func _short_run() -> void:
	start_run()
	runs_this_turn = maxi(0, runs_this_turn - 1)
	run_time_left = run_duration * dribble_run_mult
	await run_finished


## Encostou na bola durante o Street Dribble: ela gruda nele
func _try_catch_ball() -> void:
	var ball: Ball = _get_ball()
	if ball == null or ball.is_held() or ball.hovering or ball.is_locked_for(team):
		return
	if ball.get_level() != Heights.Level.GROUND:
		return
	var reach: float = body_radius + ball.collision_radius + dribble_catch_margin
	if global_position.distance_to(ball.global_position) > reach:
		return
	_grab_ball(ball)
	_dribble_got_ball = true


func _use_predator() -> bool:
	if not _predator_ready:
		return false
	await play_action(&"predator_blind")
	_blind_shots_left = blind_shots
	_predator_ready = false
	queue_redraw()
	return true


## Complemento gratuito (não gasta ação de habilidade) e que segura o fim do turno
func skill_is_free(skill_id: StringName) -> bool:
	return skill_id == SKILL_PREDATOR and _predator_ready


func has_free_followup() -> bool:
	return _predator_ready


# ---------- VS EMPEROR / GOAL IN TIME ----------

func _enemies_near() -> int:
	var count: int = 0
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other.team != team and global_position.distance_to(other.global_position) <= goal_enemy_radius:
			count += 1
	return count


func get_emperor_variant() -> EmperorVariant:
	var ball: Ball = _get_ball()
	if ball == null or is_down or ball.is_locked_for(team):
		return EmperorVariant.NONE
	if ball.is_held() and ball.held_by != self:
		return EmperorVariant.NONE
	var ball_level: Heights.Level = ball.get_level()
	if ball_level == Heights.Level.SUSPENDED and _enemies_near() >= goal_enemies_needed \
			and get_kick_type(ball) != KickType.NONE:
		return EmperorVariant.GOAL
	if ball_level == Heights.Level.GROUND and ball.held_by != self \
			and global_position.distance_to(ball.global_position) <= kick_range:
		return EmperorVariant.EMPEROR
	return EmperorVariant.NONE


func _emperor_skill_name() -> String:
	return "Goal in Time" if get_emperor_variant() == EmperorVariant.GOAL else "Vs Emperor"


func _use_emperor_skill() -> bool:
	match get_emperor_variant():
		EmperorVariant.EMPEROR:
			return await _use_vs_emperor()
		EmperorVariant.GOAL:
			return await _use_goal_in_time()
	return false


func _use_vs_emperor() -> bool:
	await play_action(&"vs_emperor")
	var ball: Ball = _get_ball()
	if ball == null or ball.is_held() or ball.get_level() != Heights.Level.GROUND:
		return false
	_grab_ball(ball)
	_emperor_active = true
	_emperor_bonus_used = false
	_threat_seen.clear()
	start_cooldown(CD_EMPEROR, emperor_cooldown)
	queue_redraw()
	return true


func _use_goal_in_time() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	_preview = Preview.GOAL
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	_preview = Preview.NONE
	queue_redraw()
	if aim == Vector2.ZERO:
		return false
	var ball: Ball = _get_ball()
	if get_emperor_variant() != EmperorVariant.GOAL:
		return false

	var kind: KickType = get_kick_type(ball)
	await kick_ball(ball, aim, kind, true, chance_goal, false,
		_current_fx(_blind_shots_left > 0), &"goal_in_time")
	start_cooldown(CD_EMPEROR, emperor_cooldown)
	# Uma curva só, para a direita de quem chuta
	_curve_ball(ball, 1, goal_curve_time, goal_curve_deg, goal_curve_deg, 1.0)
	return true


## Um inimigo tentou tirar a bola: o Yuki desvia (e ganha +1 ação geral na primeira vez)
func _emperor_dodge(attacker: Player) -> void:
	_threat_seen.append(attacker)
	hop_over()
	if not _emperor_bonus_used:
		_emperor_bonus_used = true
		extra_general_left += emperor_extra_general
		queue_redraw()


## Carrinho de um inimigo NELE: desvia em vez de cair (a bola grudada o carrinho não leva,
## porque Ball.is_held() faz o Carrinho ignorá-la)
func try_counter_slide(attacker: Player) -> bool:
	if not _emperor_active or _held_ball == null or attacker.team == team:
		return false
	if not (attacker in _threat_seen):
		_emperor_dodge(attacker)
	return true


## O Carrinho também pode passar perto sem acertar o corpo (ex: Yuki suspenso): se o inimigo
## desliza em direção à bola segura, conta como "tentou pegar".
func _check_emperor_threats() -> void:
	if _held_ball == null:
		return
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other.team == team or other.state != State.SLIDING or other in _threat_seen:
			continue
		if other.global_position.distance_to(_held_ball.global_position) <= other.slide_hit_radius * 1.5:
			_emperor_dodge(other)


func _end_emperor() -> void:
	_emperor_active = false
	_threat_seen.clear()
	_release_held_ball()
	queue_redraw()


# ---------- BOLA GRUDADA ----------

## Gruda a bola no Yuki. Usa só Ball.held_by (a mesma flag que o goleiro usa): quem não é o
## Yuki não consegue chutar, passar nem pegar a bola, e o Carrinho a ignora.
func _grab_ball(ball: Ball) -> void:
	ball.register_touch(self)
	ball.pending_shot_chance = Ball.NO_SHOT
	ball.velocity = Vector2.ZERO
	ball.vel_z = 0.0
	ball.height = 0.0
	ball.held_by = self
	_held_ball = ball
	_snap_held_ball()


func _hold_offset() -> Vector2:
	var dir: Vector2 = velocity if velocity.length() > 1.0 else Vector2(facing, 0.0)
	return dir.normalized() * (body_radius + _held_ball.collision_radius + 4.0)


func _snap_held_ball() -> void:
	_held_ball.global_position = global_position + _hold_offset()
	_held_ball.height = 0.0


## Solta a bola grudada: ela fica parada ao lado dele
func _release_held_ball() -> void:
	if _held_ball != null and is_instance_valid(_held_ball) and _held_ball.held_by == self:
		_held_ball.held_by = null
	_held_ball = null


## A bola grudada deixou de ser do Yuki? (ele chutou/passou, o goleiro pegou, a bola reiniciou,
## ou um passe alto a pôs para pairar)
func _held_ball_lost() -> bool:
	return not is_instance_valid(_held_ball) or _held_ball.held_by != self or _held_ball.hovering


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"id": SKILL_SHOT, "name": skill_label(_shot_skill_name(), CD_SHOT)})
	list.append({"id": SKILL_DRIBBLE, "name": skill_label("Street Dribble", CD_DRIBBLE)})
	var blind_name: String = "Predator Blind"
	if not _predator_ready and _blind_shots_left > 0:
		blind_name = "Predator Blind (%d chutes)" % _blind_shots_left
	list.append({"id": SKILL_PREDATOR, "name": blind_name})
	list.append({"id": SKILL_EMPEROR, "name": skill_label(_emperor_skill_name(), CD_EMPEROR)})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_SHOT:
			return not is_on_cooldown(CD_SHOT) and get_shot_variant() != ShotVariant.NONE
		SKILL_DRIBBLE:
			return height_level == Heights.Level.GROUND and not is_on_cooldown(CD_DRIBBLE)
		SKILL_PREDATOR:
			return _predator_ready
		SKILL_EMPEROR:
			return not is_on_cooldown(CD_EMPEROR) and get_emperor_variant() != EmperorVariant.NONE
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_SHOT:
			return await _use_shot_skill()
		SKILL_DRIBBLE:
			return await _use_dribble()
		SKILL_PREDATOR:
			return await _use_predator()
		SKILL_EMPEROR:
			return await _use_emperor_skill()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_SHOT:
			title = _shot_skill_name()
			match get_shot_variant():
				ShotVariant.GYRO:
					text = "Chute em que a bola sobe, cai e faz curvas improváveis pelo caminho. %d%% de chance de gol." % _pct(chance_gyro)
				ShotVariant.SWORD:
					text = "Chute reto em que a bola sobe, desce e sobe de novo. %d%% de chance de gol." % _pct(chance_sword)
				_:
					text = "Chute especial que muda conforme a altura dele. De %d%% a %d%% de chance de gol." % [
						_pct(minf(chance_gyro, chance_sword)), _pct(maxf(chance_gyro, chance_sword))]
			text += "\nRecarga: %d rodadas." % shot_cooldown
		SKILL_DRIBBLE:
			title = "Street Dribble"
			text = ("%d corridas curtas seguidas. Se encostar na bola, ela gruda nele e libera o Predator Blind de graça.\n"
				+ "Recarga: %d rodadas.") % [dribble_runs, dribble_cooldown]
		SKILL_PREDATOR:
			title = "Predator Blind"
			text = "Complemento grátis: os próximos %d chutes do Yuki ganham +%d%% de chance de gol e as curvas e subidas dos chutes aumentam." % [
				blind_shots, _pct(blind_bonus)]
		SKILL_EMPEROR:
			title = _emperor_skill_name()
			match get_emperor_variant():
				EmperorVariant.EMPEROR:
					text = "Yuki segura a bola até o próximo turno do time dele. Se um inimigo tentar tirá-la, ele desvia e ganha +%d ação geral." % emperor_extra_general
				EmperorVariant.GOAL:
					text = "Chute curvo para a direita. %d%% de chance de gol." % _pct(chance_goal)
				_:
					text = "Segura a bola e desvia dos inimigos, ou dá um chute curvo, conforme a situação."
			text += "\nRecarga: %d rodadas." % emperor_cooldown
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}
# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()
	_curve_token += 1
	_preview = Preview.NONE
	_release_held_ball()
	_blind_shots_left = 0
	_predator_ready = false
	_dribbling = false
	_dribble_got_ball = false
	_emperor_active = false
	_emperor_bonus_used = false
	_threat_seen.clear()
	queue_redraw()


# ---------- LOOP / VISUAL ----------

func _physics_process(delta: float) -> void:
	super(delta)

	# Street Dribble: durante a corrida, procura a bola para grudar
	if _dribbling and state == State.RUNNING and _held_ball == null:
		_try_catch_ball()

	# Bola grudada: acompanha o Yuki (a menos que ele já tenha se desfeito dela)
	if _held_ball != null:
		if _held_ball_lost():
			if is_instance_valid(_held_ball) and _held_ball.held_by == self:
				_held_ball.held_by = null   # alguém a pôs para pairar: solta sem mexer nela
			_held_ball = null
			if _emperor_active:
				_emperor_active = false
				_threat_seen.clear()
				queue_redraw()
		else:
			_snap_held_ball()
			if _emperor_active:
				_check_emperor_threats()


func _draw() -> void:
	super()
	var center := Vector2(0.0, -height)

	# Trajetória do chute enquanto mira (roxa com o Predator Blind ativo, laranja sem ele)
	if show_trajectory and is_aiming and _preview != Preview.NONE:
		var data: Dictionary = _trajectory_data()
		if not data.is_empty():
			BallPathPreview.draw(self, data, COLOR_PURPLE if _blind_shots_left > 0 else COLOR_ORANGE)

	# Laranja: com a bola segura (Vs Emperor); marrom tracejado enquanto o complemento espera
	if _emperor_active:
		draw_arc(center, placeholder_radius + 7.0, 0.0, TAU, 40, Color(COLOR_ORANGE, 0.95), 2.5)
	if _predator_ready:
		var segments: int = 10
		for i in segments:
			if i % 2 == 0:
				var a0: float = TAU * float(i) / float(segments)
				var a1: float = TAU * float(i + 1) / float(segments)
				draw_arc(center, placeholder_radius + 12.0, a0, a1, 6, Color(COLOR_BROWN, 0.95), 3.0)

	# Roxo: Predator Blind ativo, com um pontinho para cada chute que ainda tem o bônus
	if _blind_shots_left > 0:
		draw_arc(center, placeholder_radius + 17.0, 0.0, TAU, 40, Color(COLOR_PURPLE, 0.9), 2.0)
		for i in _blind_shots_left:
			var x: float = (float(i) - float(_blind_shots_left - 1) * 0.5) * 9.0
			draw_circle(center + Vector2(x, -placeholder_radius - 28.0), 3.0, COLOR_PURPLE)
