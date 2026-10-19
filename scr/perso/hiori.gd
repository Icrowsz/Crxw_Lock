class_name Hiori
extends Player
## Hiori, com 3 habilidades (efeitos de neve, vidro e gelo em hiori_fx.gd):
##
## 1. Chilling Pass / No Look Cross (recarga 2, compartilhada). Passe alto para um ALIADO: a bola sobe a Voando
##      no meio do caminho, PAIRA lá e, quando o turno do time volta, desce Suspensa no aliado (igual ao Passe Alto).
##      - Hiori no chão + bola no chão ou Suspensa -> Chilling Pass (alcance 525).
##      - Hiori Suspenso + bola Suspensa -> No Look Cross: QTE fácil e, de recompensa, alcance 575.
##        Errou o QTE: a ação é gasta e o passe não sai.
##
## 2. Glacial Cut (recarga 2; Let It Go e Ultrasadist compartilham essa recarga)
##      - Hiori no chão -> Glacial Cut: corrida curta (1.1 s) e rápida (325). Se encontrar a bola no caminho, DOMINA ela
##        e libera o Ultrasadist de graça (skill_is_free: os dois contam como uma ação só).
##      - Hiori Suspenso -> Let It Go: avanço/deslize curto (alcance 180, deixa uma camada fina de gelo no chão) em que
##        ele cai para o chão. Se encontrar um inimigo, DESVIA dele e o CONGELA (bloco de gelo): atordoado = sem
##        habilidades e sem ações gerais por 1 rodada. Se encontrar a bola, domina e libera o Ultrasadist.
##      - Ultrasadist: passe para um PONTO do campo (alcance 550), QTE fácil. A bola chega Suspensa na MESMA rodada.
##        Ponto a menos de 200 -> a bola sobe só a Suspensa durante a trajetória; mais longe -> sobe a Voando.
##
## 3. Coldest Metavision (3 rodadas; recarga 3 a partir do fim do efeito): os próximos 2 Correr dele ganham +0.5 s, e os
##      chutes dele e de quem recebe um passe dele ganham +5%. Libera duas habilidades (recarga 2 compartilhada):
##      - Cryo Shot (só no lado do ataque): chute/voleio comum, Hiori e bola no chão ou Suspensos. QTE se for voleio,
##        força 1.2x do Chutar e 40% de chance pura.
##      - Frost Guard: ARMA uma detecção (raio 240) para o turno inimigo. Ao usar, escolhe a direção (para o chute
##        Voando) e, se houver aliado ao alcance, quem recebe o passe; sem aliado, o Hiori fica com a bola. Quando um
##        chute inimigo entra na área: no chão -> Hiori vai até a bola e passa para o aliado (ou fica com ela);
##        Suspenso -> Hiori salta até a bola e dá um deflect 0.4x para a esquerda; Voando -> Hiori salta até a bola e dá um deflect 0.3x na direção escolhida (QTE).
##
## Reação ONE MORE TIME (Isagi): o Ultrasadist anota last_ultrasadist e, se cumprir a reação, sai "carregado".
## Reação SACRIFICE (Karasu): com a Metavision ativa no ataque, o Cryo Shot vira o LOUD CROW (mirando no Karasu).
##
## Cena: Nova Cena Herdada de player.tscn -> anexe este script ao nó raiz -> renomeie o nó raiz para "Hiori".

const SKILL_PASS: StringName = &"chilling_pass"
const SKILL_GLACIAL: StringName = &"glacial_cut"          # no ar vira o Let It Go
const SKILL_ULTRASADIST: StringName = &"ultrasadist"
const SKILL_METAVISION: StringName = &"coldest_metavision"
const SKILL_FROST_GUARD: StringName = &"frost_guard"
const SKILL_CRYO_SHOT: StringName = &"cryo_shot"

## id da reação Sacrifice (Karasu) em reaction_sacrifice.gd
const SACRIFICE_ID: StringName = &"sacrifice"

const CD_PASS: StringName = &"cd_pass"
const CD_GLACIAL: StringName = &"cd_glacial"          # Glacial Cut, Let It Go e Ultrasadist
const CD_METAVISION: StringName = &"cd_metavision"
const CD_GUARD_CRYO: StringName = &"cd_guard_cryo"    # Frost Guard e Cryo Shot

enum PassVariant { NONE, CHILLING, NO_LOOK }
enum CutVariant { NONE, GLACIAL, LET_IT_GO }

@export_group("Chilling Pass / No Look Cross")
@export var chilling_pass_range: float = 525.0
@export var no_look_cross_range: float = 575.0
@export var pass_cooldown: int = 2

@export_group("Glacial Cut / Let It Go / Ultrasadist")
@export var glacial_cut_duration: float = 1.1
@export var glacial_cut_speed: float = 325.0
@export var let_it_go_range: float = 180.0
@export var let_it_go_time: float = 0.45               # duração do avanço
@export var let_it_go_margin: float = 30.0             # folga além dos corpos para "encontrar" um inimigo
@export var ultrasadist_range: float = 550.0
@export var ultrasadist_low_distance: float = 200.0    # abaixo disso a bola só sobe a Suspensa
@export_range(0.0, 1.0) var ultrasadist_qte_fail_range_mult: float = 0.5
@export_range(0.0, 90.0) var ultrasadist_qte_fail_angle: float = 35.0
@export var glacial_cooldown: int = 2

@export_group("Coldest Metavision")
@export var metavision_rounds: int = 3
@export var metavision_run_bonus: float = 0.5          # segundos extra em cada um dos próximos Correr
@export var metavision_run_count: int = 2
@export_range(0.0, 1.0) var metavision_self_shot_bonus: float = 0.05
@export_range(0.0, 1.0) var metavision_assist_shot_bonus: float = 0.05
@export var metavision_cooldown: int = 3               # a partir do fim do efeito
@export var guard_cryo_cooldown: int = 2

@export_group("Cryo Shot (lado do ataque)")
@export_range(0.0, 1.0) var cryo_shot_chance: float = 0.40
@export var cryo_force_mult: float = 1.2               # sobre a força do Chutar

@export_group("Frost Guard")
@export var frost_guard_range: float = 125.0
@export var frost_side_mult: float = 0.4               # deflect do chute Suspenso (para a esquerda)
@export var frost_air_mult: float = 0.3                # deflect do chute Voando (direção escolhida)

@export_group("Loud Crow (reação Sacrifice)")
@export_range(0.0, 1.0) var loud_crow_chance: float = 0.90
@export var loud_crow_force_mult: float = 1.35
## Tolerância (px) para a mira "acertar" o Karasu
@export var loud_crow_aim_tolerance: float = 36.0
## Altura (px) do pulo visual da bola por cima dos obstáculos
@export var loud_crow_hop_height: float = 46.0
## Visual do chute do Loud Crow (vazio = padrão)
@export var loud_crow_fx: KickFX

@export_group("Visual do chute")
## Efeito dos chutes e passes (vazio = padrão de gelo)
@export var kick_fx: KickFX
## Efeito do Ultrasadist carregado (One More Time)
@export var charged_fx: KickFX

@export_group("Gelo e neve (visual)")
## Neve, vidro e gelo (hiori_fx.gd). Desligue se o jogo ficar pesado
@export var snow_particles: bool = true
@export var ice_trail_seconds: float = 1.6             # quanto a camada de gelo do Let It Go leva para sumir
@export var ice_trail_width: float = 34.0
@export var ice_trail_step: float = 14.0               # a cada quantos px nasce um pedaço de gelo
@export var frost_area_enabled: bool = true            # círculo com floco grande marcando o alcance do Frost Guard

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: chilling_pass, glacial_cut, ultrasadist,
## coldest_metavision, frost_guard, cryo_shot.
@export var skill_icons: Dictionary = {}

## Glacial Cut / Let It Go achou a bola: Ultrasadist grátis esperando neste turno
var _glacial_ready: bool = false
var _metavision_until_round: int = -1
var _run_bonus_left: int = 0               # Correr com +0.5 s que ainda restam
var _assist_target: Player = null          # quem recebeu passe dele com a Metavision (ganha o bônus de chute)
## Último Ultrasadist (as Reações Químicas leem): {"landing": ponto, "touches": toques depois do passe}
var last_ultrasadist: Dictionary = {}

## Frost Guard: armado = esperando o turno inimigo; live = turno inimigo, procurando o chute
var _guard_armed: bool = false
var _guard_live: bool = false
var _guard_busy: bool = false
var _guard_ally: Player = null
var _guard_dir: Vector2 = Vector2.RIGHT

var _aura: CPUParticles2D                  # neve em volta dele (Metavision / Frost Guard)
var _aiming_loud_crow: bool = false
var _loud_crow_partner: Player = null


func _init() -> void:
	character_id = "hiori"
	display_name = "Hiori"


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = _make_kick_fx()
	if charged_fx == null:
		charged_fx = _make_charged_fx()
	if loud_crow_fx == null:
		loud_crow_fx = _make_loud_crow_fx()
	if snow_particles:
		HioriFX.warm_up()
		_aura = HioriFX.make_aura()
		add_child(_aura)
	_hook_manager.call_deferred()


func _make_kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = Color(0.55, 0.85, 1.0, 1.0)             # azul gelo
	fx.trail_width = 12.0
	fx.shape = KickFX.Shape.SQUARE                      # lascas de gelo
	fx.particle_color = Color(0.92, 0.98, 1.0, 1.0)     # branco gelado
	fx.amount = 18
	fx.lifetime = 0.5
	fx.speed_min = 20.0
	fx.speed_max = 70.0
	fx.gravity = Vector2(0.0, -40.0)
	fx.spin = 260.0
	fx.scale_min = 0.12
	fx.scale_max = 0.28
	fx.burst_amount = 12
	fx.burst_speed = 180.0
	return fx


## Ultrasadist "carregado" (One More Time): o mesmo estilo, só que bem mais largo, brilhante e
## cheio de lascas de gelo
func _make_charged_fx() -> KickFX:
	var fx := _make_kick_fx()
	fx.color = Color(0.75, 0.95, 1.0, 1.0)
	fx.trail_width = 24.0
	fx.particle_color = Color(1.0, 1.0, 1.0, 1.0)
	fx.amount = 50
	fx.lifetime = 0.8
	fx.speed_min = 20.0
	fx.speed_max = 100.0
	fx.gravity = Vector2(0.0, -30.0)
	fx.spin = 400.0
	fx.scale_min = 0.15
	fx.scale_max = 0.4
	fx.burst_amount = 36
	fx.burst_speed = 300.0
	return fx


## Loud Crow: gelo largo e brilhante, com lascas roxas (o corvo do Karasu)
func _make_loud_crow_fx() -> KickFX:
	var fx := _make_charged_fx()
	fx.color = Color(0.62, 0.86, 1.0, 1.0)
	fx.trail_width = 30.0
	fx.particle_color = Color(0.82, 0.68, 1.0, 1.0)
	fx.amount = 40
	fx.lifetime = 0.7
	fx.burst_amount = 30
	return fx


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m == null:
		return
	m.pass_completed.connect(_on_pass_completed)
	m.turn_ended.connect(_on_turn_ended)
	m.turn_started.connect(_on_turn_started)
	m.bonus_turn_started.connect(_on_turn_started)


## Quem recebeu o passe do Hiori com a Metavision ativa vira o alvo da assistência (ver shot_bonus_for_ally)
func _on_pass_completed(passer: Player, target: Player) -> void:
	if passer == self and is_metavision_active():
		_assist_target = target


## O turno dele acabou: a chance grátis do Ultrasadist se perde
func _on_turn_ended(ended_team: int) -> void:
	if ended_team == team and _glacial_ready:
		_glacial_ready = false
		queue_redraw()


## Frost Guard: começou o turno inimigo = procura o chute; voltou a vez do Hiori = desliga
func _on_turn_started(started_team: int) -> void:
	_guard_live = _guard_armed and started_team != team
	if started_team == team:
		_guard_armed = false
	queue_redraw()


# ---------- EFEITOS (neve, vidro e gelo: hiori_fx.gd) ----------

func _fx_burst(pos: Vector2, amount: int = 10, strong: bool = false) -> void:
	if snow_particles:
		HioriFX.burst(self, pos, amount, strong)


func _fx_ring(pos: Vector2, radius: float, amount: int = 14) -> void:
	if snow_particles:
		HioriFX.ring(self, pos, radius, amount)


func _fx_trail(ball: Ball, seconds: float = 0.5) -> void:
	if snow_particles:
		HioriFX.trail(ball, seconds)


func _body_pos() -> Vector2:
	return global_position + Vector2(0.0, -height)


## Chamado pelo kick_ball() logo depois que o Cryo Shot sai (on_kick)
func _launch_cryo(ball: Ball, _dir: Vector2, _speed: float) -> void:
	_fx_trail(ball, 0.6)
	_fx_burst(ball.sprite.global_position, 8)


# ---------- HABILIDADE 1: CHILLING PASS / NO LOOK CROSS ----------

func get_pass_variant() -> PassVariant:
	var ball: Ball = _get_ball()
	if ball == null or ball.is_held() or ball.is_locked_for(team) \
			or global_position.distance_to(ball.global_position) > kick_range:
		return PassVariant.NONE
	var level: Heights.Level = ball.get_level()
	if level == Heights.Level.FLYING:
		return PassVariant.NONE
	if height_level == Heights.Level.SUSPENDED:
		return PassVariant.NO_LOOK if level == Heights.Level.SUSPENDED else PassVariant.NONE
	return PassVariant.CHILLING if height_level == Heights.Level.GROUND else PassVariant.NONE


func _pass_skill_name() -> String:
	return "No Look Cross" if get_pass_variant() == PassVariant.NO_LOOK else "Chilling Pass"


func _use_pass_skill() -> bool:
	var m: MatchManager = _get_manager()
	var variant: PassVariant = get_pass_variant()
	if m == null or variant == PassVariant.NONE:
		return false
	var no_look: bool = variant == PassVariant.NO_LOOK
	var range_px: float = no_look_cross_range if no_look else chilling_pass_range
	var ball: Ball = _get_ball()
	var target: Player = await m.pick_ally_for_skill(self, range_px)
	if target == null:
		return false   # cancelou: não gasta a ação
	if get_pass_variant() != variant:
		return false   # a situação mudou enquanto ele escolhia o alvo

	# No Look Cross: QTE fácil (a recompensa é o alcance maior). Errou: gasta a ação e o passe não sai
	if no_look and not skips_qte() and not await m.run_qte(KickType.VOLLEY):
		start_cooldown(CD_PASS, pass_cooldown)
		return true

	PassFX.arm(ball, PassFX.Style.CHILLING)   # fita gelada e floquinhos: começa quando a bola sai
	await m.run_skill_high_pass(self, target, ball, range_px,
		&"no_look_cross" if no_look else &"chilling_pass", kick_fx)
	start_cooldown(CD_PASS, pass_cooldown)
	return true


# ---------- HABILIDADE 2: GLACIAL CUT / LET IT GO / ULTRASADIST ----------

func get_cut_variant() -> CutVariant:
	if is_down:
		return CutVariant.NONE
	match height_level:
		Heights.Level.GROUND:
			return CutVariant.GLACIAL
		Heights.Level.SUSPENDED:
			return CutVariant.LET_IT_GO
	return CutVariant.NONE


func _cut_skill_name() -> String:
	return "Let It Go" if get_cut_variant() == CutVariant.LET_IT_GO else "Glacial Cut"


func _use_cut_skill() -> bool:
	match get_cut_variant():
		CutVariant.GLACIAL:
			return await _use_glacial_cut()
		CutVariant.LET_IT_GO:
			return await _use_let_it_go()
	return false


## A bola está ao alcance dele agora (qualquer nível que o nível atual dele alcance)?
func _ball_in_reach() -> bool:
	var ball: Ball = _get_ball()
	return ball != null and not ball.is_held() and not ball.is_locked_for(team) \
		and can_reach_level(ball.get_level()) \
		and global_position.distance_to(ball.global_position) <= kick_range


## Dominar a bola: toque dele, ela para e o chute que ela levava (se havia) é cancelado
func _dominate_ball(ball: Ball) -> void:
	ball.register_touch(self)
	if not ball.hovering:
		ball.velocity = Vector2.ZERO
		ball.pending_shot_chance = Ball.NO_SHOT
	_fx_ring(_ball_point(ball), 28.0, 10)


func _ball_point(ball: Ball) -> Vector2:
	return ball.sprite.global_position if ball.sprite != null else ball.global_position


## Glacial Cut: corrida curta e veloz (NÃO é a ação geral Correr). Encontrou a bola: domina e libera o Ultrasadist.
func _use_glacial_cut() -> bool:
	state = State.RUNNING
	var time_left: float = glacial_cut_duration
	var reached: bool = false
	_fx_burst(_body_pos(), 8)
	while time_left > 0.0:
		await get_tree().physics_frame
		var delta: float = get_physics_process_delta_time()
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = dir * glacial_cut_speed
		move_and_slide()
		time_left -= delta
		if not reached and _ball_in_reach():
			reached = true
			_dominate_ball(_get_ball())
		queue_redraw()

	velocity = Vector2.ZERO
	state = State.IDLE
	_fx_burst(_body_pos(), 6)
	start_cooldown(CD_GLACIAL, glacial_cooldown)
	_glacial_ready = reached
	queue_redraw()
	return true


## Let It Go: avanço curto na direção mirada, caindo para o chão no meio do caminho. Desvia dos inimigos que
## encontra e os congela (atordoa); encontrou a bola: domina e libera o Ultrasadist. Deixa gelo fino no chão.
func _use_let_it_go() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var aim: Vector2 = await m.aim_for_skill(self, let_it_go_range)
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação
	if get_cut_variant() != CutVariant.LET_IT_GO:
		return false
	var dir: Vector2 = aim.normalized()
	face_towards(dir)
	if not await play_action(&"let_it_go"):
		return false

	var start: Vector2 = global_position
	var speed: float = let_it_go_range / maxf(let_it_go_time, 0.05)
	var travelled: float = 0.0
	var last_ice: Vector2 = start
	var frozen: Array[Player] = []
	var dodge_start: float = -1.0      # onde (px percorridos) o desvio começa; -1 = sem desvio
	var dodge_len: float = 0.0
	var dodge_amp: float = 0.0
	var dodge_vec: Vector2 = Vector2.ZERO
	var landed: bool = false
	var got_ball: bool = false
	_fx_burst(_body_pos(), 8)

	while travelled < let_it_go_range:
		await get_tree().physics_frame
		travelled = minf(travelled + speed * get_physics_process_delta_time(), let_it_go_range)
		var offset := Vector2.ZERO
		if dodge_start >= 0.0:
			var u: float = (travelled - dodge_start) / dodge_len
			if u >= 0.0 and u <= 1.0:
				offset = dodge_vec * dodge_amp * sin(PI * u)   # contorna o inimigo e volta para a linha
		global_position = _clamp_to_pitch(start + dir * travelled + offset, body_radius)

		if not landed and travelled >= let_it_go_range * 0.5:
			land()
			landed = true

		# Encontrou um inimigo: congela e desvia (o desvio vai para o lado oposto ao dele)
		for p: Player in get_tree().get_nodes_in_group("players"):
			if p.team == team or p.is_down or frozen.has(p) or not can_reach_level(p.height_level):
				continue
			var trigger: float = body_radius + p.body_radius + let_it_go_margin
			if global_position.distance_to(p.global_position) > trigger:
				continue
			frozen.append(p)
			_stun(p)
			if dodge_start < 0.0:
				dodge_start = travelled
				dodge_len = trigger * 2.0
				dodge_amp = body_radius + p.body_radius + 14.0
				dodge_vec = dir.orthogonal()
				if dodge_vec.dot(p.global_position - global_position) > 0.0:
					dodge_vec = -dodge_vec

		if not got_ball and _ball_in_reach():
			got_ball = true
			_dominate_ball(_get_ball())

		if snow_particles and global_position.distance_to(last_ice) >= ice_trail_step:
			HioriFX.ice_layer(self, last_ice, global_position, ice_trail_width, ice_trail_seconds)
			last_ice = global_position

	if not landed:
		land()
	_fx_burst(_body_pos(), 8)
	start_cooldown(CD_GLACIAL, glacial_cooldown)
	_glacial_ready = got_ball
	queue_redraw()
	return true


## Atordoar = sem habilidades e sem ações gerais. Dura até o fim do próximo turno do time do inimigo
## (1 rodada; se o turno dele já passou nesta rodada, vale também a seguinte). O bloco de gelo some junto.
func _stun(p: Player) -> void:
	var m: MatchManager = _get_manager()
	var rounds: int = 1
	if m != null and m.turns_played >= m.team_count - 1:
		rounds = 2
	p.apply_lock(self, rounds, false)
	HioriFX.ice_block(self, p, 0.0, true)


## Ultrasadist (grátis depois do Glacial Cut / Let It Go): passe para um PONTO do campo, QTE fácil.
## Ponto a menos de ultrasadist_low_distance: a bola só sobe a Suspensa; mais longe: sobe a Voando.
func _use_ultrasadist() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null or not _ball_in_reach():
		return false   # só com a bola próxima dele

	var landing: Vector2 = await m.pick_point_for_skill(self, ultrasadist_range)
	if landing == Vector2.INF:
		return false   # cancelou: a chance continua até o turno acabar
	if not _ball_in_reach():
		return false   # a bola saiu do alcance (ou de jogo) enquanto ele escolhia o local

	_glacial_ready = false   # consumida: só uma chance por Glacial Cut / Let It Go

	var dir: Vector2 = landing - global_position
	dir = dir.normalized() if dir.length() > 0.01 else Vector2(_default_facing(), 0.0)
	face_towards(dir)
	if not await play_action(&"ultrasadist", ANIM_PASS_HIGH):
		return false

	var qte_ok: bool = true
	if not skips_qte():
		qte_ok = await m.run_qte(KickType.VOLLEY)   # QTE fácil
	if not qte_ok:
		# Errou: o local sai mais perto e um pouco torto
		var bad_dir: Vector2 = dir.rotated(deg_to_rad(randf_range(-ultrasadist_qte_fail_angle, ultrasadist_qte_fail_angle)))
		landing = global_position + bad_dir * global_position.distance_to(landing) * ultrasadist_qte_fail_range_mult

	ball.register_touch(self)

	# One More Time (Hiori + Isagi): se cumpre a reação, o passe sai brilhando e congelando o chão
	var charged: bool = ReactionOneMoreTime.is_ultrasadist_charged(self)
	last_ultrasadist = {}
	if charged:
		ball.play_fx(charged_fx)
		OneMoreTimeFX.attach_frost_trail(ball, OneMoreTimeFX.Style.ULTRASADIST)
		OneMoreTimeFX.ice_burst(self, ball.sprite.global_position, 40)
	elif kick_fx:
		ball.play_fx(kick_fx)
	if not charged:
		PassFX.attach(ball, PassFX.Style.ULTRASADIST)
		_fx_trail(ball, 1.0)
		_fx_burst(_ball_point(ball), 10)

	var distance: float = ball.global_position.distance_to(landing)
	var peak: float = Heights.SUSPENDED_HEIGHT if distance < ultrasadist_low_distance else Heights.FLYING_HEIGHT
	var flight: float = 0.45 + 0.45 * clampf(distance / ultrasadist_range, 0.0, 1.0)   # passe curto é mais rápido
	await ball.hover_to((ball.global_position + landing) * 0.5, peak, flight).finished

	# Chega NA MESMA RODADA, Suspensa; fica pairando até alguém tocar ou o turno acabar
	await ball.hover_to(landing, Heights.SUSPENDED_HEIGHT, m.high_pass_arrive_time).finished
	m.register_skill_pass(team, null)
	_fx_ring(landing, 40.0, 10)

	# Avisa as Reações Químicas (a One More Time lê isto)
	last_ultrasadist = {"landing": landing, "touches": ball.interaction_count}
	if charged:
		OneMoreTimeFX.ice_burst(self, ball.sprite.global_position, 30)
	queue_redraw()
	return true


# ---------- HABILIDADE 3: COLDEST METAVISION (+ CRYO SHOT / FROST GUARD) ----------

func is_metavision_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _metavision_until_round >= 0 and m.round_number <= _metavision_until_round


## +5% nos chutes do próprio Hiori enquanto a Metavision estiver ativa
func get_shot_chance(kind: KickType) -> float:
	var base: float = super(kind)
	if is_metavision_active():
		base += metavision_self_shot_bonus
	return base


## +5% no chute de quem acabou de receber um passe dele (assistência), enquanto a Metavision durar
func shot_bonus_for_ally(shooter: Player, _ball: Ball) -> float:
	if is_metavision_active() and shooter == _assist_target:
		return metavision_assist_shot_bonus
	return 0.0


## Lado do campo em que ele está AGORA (metade do próprio gol), considerando a troca de lado do 2º tempo
func _is_on_defense_side() -> bool:
	var field := get_tree().get_first_node_in_group("field") as Field
	var x: float = global_position.x if field == null else field.to_local(global_position).x
	return x * get_attack_dir() < 0.0


## Os próximos metavision_run_count Correr ganham metavision_run_bonus segundos (o bônus some logo depois de usado)
func start_run() -> void:
	var boosted: bool = _run_bonus_left > 0 and is_metavision_active()
	if boosted:
		_run_bonus_left -= 1
		run_time_bonus += metavision_run_bonus
	super()
	if boosted:
		run_time_bonus -= metavision_run_bonus


func _use_metavision() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	await play_action(&"coldest_metavision")
	_fx_ring(_body_pos(), 46.0, 18)
	_fx_burst(_body_pos(), 16, true)
	_metavision_until_round = m.round_number + metavision_rounds
	_run_bonus_left = metavision_run_count
	start_cooldown(CD_METAVISION, metavision_cooldown, _metavision_until_round + 1)
	queue_redraw()
	return true


## Cryo Shot: chute comum (voleio tem QTE), 1.2x a força do Chutar e chance pura. Lado do ataque.
## Reação Sacrifice (Loud Crow): se mirar no Karasu, a cutscene roda e o chute sai especial (sem QTE).
func _use_cryo_shot() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false

	var kind: KickType = get_kick_type(ball)
	if kind == KickType.NONE or kind == KickType.FLYING:
		return false

	# Com a Sacrifice de pé, a mira destaca o Karasu
	var star: ChemicalReaction = _find_sacrifice()
	_loud_crow_partner = star.find_partner(self) if star != null else null
	_aiming_loud_crow = _loud_crow_partner != null
	queue_redraw()
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	_aiming_loud_crow = false
	queue_redraw()
	if aim == Vector2.ZERO:
		_loud_crow_partner = null
		return false   # cancelou: não gasta a ação

	kind = get_kick_type(ball)   # a situação pode ter mudado durante a mira
	if kind == KickType.NONE or kind == KickType.FLYING:
		_loud_crow_partner = null
		return false

	# Reação Química (Sacrifice): só vale se a mira passa pelo Karasu
	var chance: float = cryo_shot_chance
	var anim: StringName = &"cryo_shot"
	var fx: KickFX = kick_fx
	var on_kick: Callable = _launch_cryo
	var qte_ok: bool = true
	var sacrifice: ChemicalReaction = _find_sacrifice() if _loud_crow_partner != null else null
	var karasu: Player = sacrifice.find_partner(self) if sacrifice != null else null
	_loud_crow_partner = null
	var loud_crow: bool = false
	if karasu != null and _aim_hits_partner(aim, karasu, ball):
		var rm: ReactionManager = ReactionManager.get_for(self)
		if rm != null:
			await rm.play(sacrifice, self, karasu)
			if m.match_over:
				return false
			loud_crow = true
			chance = loud_crow_chance
			anim = _loud_crow_anim()
			fx = loud_crow_fx
			next_kick_force_mult *= loud_crow_force_mult
			on_kick = _launch_loud_crow.bind(karasu)
	if not loud_crow:
		next_kick_force_mult *= cryo_force_mult
		if kind == KickType.VOLLEY and not skips_qte():
			qte_ok = await m.run_qte(kind)   # só o voleio tem QTE

	await kick_ball(ball, aim, kind, qte_ok, chance, false, fx, anim, on_kick)
	start_cooldown(CD_GUARD_CRYO, guard_cryo_cooldown)
	return true


# ---------- FROST GUARD (detecção no turno inimigo) ----------

func _ally_in_range(range_px: float) -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	for o: Player in m.get_team_players(team):
		if o != self and not o.is_down and global_position.distance_to(o.global_position) <= range_px:
			return true
	return false


## Arma o Frost Guard e fica esperando o turno inimigo. Escolhe a direção (usada no chute Voando) e, com aliado ao
## alcance, quem recebe o passe do chute no chão; sem aliado, o Hiori fica com a bola. A detecção desliga quando o
## turno do Hiori volta ou ao pegar um chute.
func _use_frost_guard() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var ally: Player = null
	if _ally_in_range(m.ground_pass_range):
		ally = await m.pick_ally_for_skill(self, m.ground_pass_range)
		if ally == null:
			return false   # cancelou: não gasta a ação
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false
	if not await play_action(&"frost_guard"):
		return false
	_guard_ally = ally
	_guard_dir = aim.normalized()
	_guard_armed = true
	start_cooldown(CD_GUARD_CRYO, guard_cryo_cooldown)
	_fx_ring(global_position, frost_guard_range, 22)   # mostra a área de detecção
	_fx_burst(_body_pos(), 10)
	queue_redraw()
	return true


## Turno inimigo: primeiro chute inimigo que entra na área de detecção
func _scan_for_shot() -> void:
	var ball: Ball = _get_ball()
	if ball == null or _guard_busy or ball.is_held() or not ball.has_pending_shot() or ball.shot_team == team \
			or ball.global_position.distance_to(global_position) > frost_guard_range:
		return
	_guard_busy = true
	_guard_live = false
	_guard_armed = false
	queue_redraw()
	await _react_to_shot(ball)
	_guard_busy = false


func _react_to_shot(ball: Ball) -> void:
	var m: MatchManager = _get_manager()
	var speed: float = ball.velocity.length()
	var dir: Vector2 = ball.velocity.normalized() if speed > 1.0 else Vector2(get_attack_dir(), 0.0)
	_fx_burst(_ball_point(ball), 14, true)   # interceptou o chute
	match ball.get_level():
		Heights.Level.GROUND:
			# Vai até a bola, para ela e passa para o aliado escolhido (sem aliado ao alcance, a bola fica com ele)
			ball.velocity = Vector2.ZERO
			ball.pending_shot_chance = Ball.NO_SHOT
			face_towards(ball.global_position - global_position)
			var tw := create_tween()
			tw.tween_property(self, "global_position", _clamp_to_pitch(ball.global_position, body_radius), 0.18)
			await tw.finished
			if m.match_over:
				return
			if _guard_ally != null and is_instance_valid(_guard_ally) and not _guard_ally.is_down \
					and global_position.distance_to(_guard_ally.global_position) <= m.ground_pass_range:
				if snow_particles:
					HioriFX.line(self, global_position, _guard_ally.global_position, 12)
				_fx_trail(ball)
				await m.run_ground_pass(self, _guard_ally, ball)
			else:
				await _keep_ball(ball)
		Heights.Level.SUSPENDED:
			# O HIORI salta até a bola e rebate para a esquerda
			var was_ground_s: bool = height_level == Heights.Level.GROUND
			await _jump_to_ball(ball)
			_deflect(ball, dir.rotated(-PI * 0.5), speed * frost_side_mult)
			if was_ground_s:
				await get_tree().create_timer(0.35).timeout
				land()
		Heights.Level.FLYING:
			# O HIORI salta até a bola e rebate na direção escolhida ao usar; QTE (errou: rebate fraco e torto)
			var was_ground: bool = height_level == Heights.Level.GROUND
			await _jump_to_ball(ball)
			var ok: bool = true
			if not skips_qte():
				ok = await m.run_qte(KickType.FLYING)
			var out_dir: Vector2 = _guard_dir
			var out_speed: float = speed * frost_air_mult
			if not ok:
				out_speed *= qte_fail_power_mult
				out_dir = out_dir.rotated(deg_to_rad(randf_range(-qte_fail_max_angle, qte_fail_max_angle)))
			_deflect(ball, out_dir, out_speed)
			if was_ground:   # volta ao chão logo depois do rebate
				await get_tree().create_timer(0.35).timeout
				land()


## Quem rebate é o Hiori, não a área: ele salta até a bola (que fica parada no ar) antes do deflect
func _jump_to_ball(ball: Ball) -> void:
	ball.pending_shot_chance = Ball.NO_SHOT   # chute interceptado: o goleiro não decide mais nada
	ball.velocity = Vector2.ZERO
	ball.vel_z = 0.0
	face_towards(ball.global_position - global_position)
	height_level = Heights.Level.SUSPENDED
	var spot: Vector2 = _clamp_to_pitch(ball.global_position - Vector2(facing * (body_radius + ball.collision_radius + 4.0), 0.0), body_radius)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", spot, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "height", Heights.SUSPENDED_HEIGHT, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished


func _deflect(ball: Ball, dir: Vector2, speed: float) -> void:
	var rise: float = maxf(0.0, Heights.SUSPENDED_HEIGHT - ball.height)
	ball.kick(dir, speed, Heights.lift_for_peak(rise, ball.gravity), self, Ball.NO_SHOT)
	if kick_fx:
		ball.play_fx(kick_fx)
	_fx_trail(ball, 0.5)


## Frost Guard sem aliado: a bola fica parada nos pés dele
func _keep_ball(ball: Ball) -> void:
	ball.register_touch(self)
	var spot: Vector2 = _clamp_to_pitch(global_position + Vector2(facing * (body_radius + ball.collision_radius + 6.0), 0.0), ball.collision_radius)
	await ball.hover_to(spot, 0.0, 0.15).finished
	ball.release_hover()


## Mantém um ponto dentro do campo (a margem é o raio de quem está sendo movido)
func _clamp_to_pitch(pos: Vector2, radius: float) -> Vector2:
	var field := get_tree().get_first_node_in_group("field") as Field
	if field == null:
		return pos
	var half: Vector2 = field.pitch_size * 0.5 - Vector2(radius, radius)
	var l: Vector2 = field.to_local(pos)
	return field.to_global(Vector2(clampf(l.x, -half.x, half.x), clampf(l.y, -half.y, half.y)))


# ---------- LOUD CROW (reação Sacrifice) ----------

## Reação Sacrifice que ele pode usar agora. null = nenhuma.
func _find_sacrifice() -> ChemicalReaction:
	if not is_inside_tree():
		return null
	var rm: ReactionManager = ReactionManager.get_for(self)
	if rm == null:
		return null
	for reaction in rm.reactions:
		if reaction.id != SACRIFICE_ID or reaction.trigger_id != character_id \
				or not rm.is_ready(reaction, team):
			continue
		if reaction.find_partner(self) != null:
			return reaction
	return null


## A linha da mira (saindo da bola) passa pelo corpo do Karasu, à frente do chute?
func _aim_hits_partner(aim: Vector2, partner: Player, ball: Ball) -> bool:
	if partner == null or not is_instance_valid(partner):
		return false
	var dir: Vector2 = aim.normalized()
	var to_partner: Vector2 = partner.global_position - ball.global_position
	if to_partner.dot(dir) <= 0.0:
		return false
	return absf(to_partner.cross(dir)) <= partner.body_radius + loud_crow_aim_tolerance


## Animação do Loud Crow: usa a "loud_crow" se o personagem tiver; senão, a do Cryo Shot
func _loud_crow_anim() -> StringName:
	if _has_art and animated_sprite.sprite_frames.has_animation(&"loud_crow"):
		return &"loud_crow"
	return &"cryo_shot"


## Chamado pelo kick_ball() logo depois que a bola sai (on_kick)
func _launch_loud_crow(ball: Ball, dir: Vector2, _speed: float, karasu: Player) -> void:
	SacrificeFX.loud_crow_burst(self, global_position + Vector2(0.0, -height), ball, karasu)
	_ghost_flight(ball, dir)   # roda em segundo plano


## Enquanto o chute dura, a bola NÃO colide com ninguém (Karasu, inimigos...) e, até passar dos
## obstáculos, faz um pulo visual por cima deles. Acaba quando o chute acaba (o goleiro sorteou, ela
## parou, foi reposta, pairou ou a partida terminou).
func _ghost_flight(ball: Ball, dir: Vector2) -> void:
	var m: MatchManager = _get_manager()
	var touches: int = ball.interaction_count   # o chute do Hiori já foi contado
	var origin: Vector2 = ball.global_position
	var base_height: float = ball.height
	var span: float = _ghost_span(origin, dir)
	var state: Dictionary = {"abort": false}
	var on_reset: Callable = func() -> void: state["abort"] = true
	ball.was_reset.connect(on_reset, CONNECT_ONE_SHOT)
	ball.collisions_paused = true

	var hopping: bool = true
	var elapsed: float = 0.0
	while true:
		await get_tree().physics_frame
		if not is_instance_valid(ball) or state["abort"] or ball.hovering or ball.is_held() \
				or ball.interaction_count != touches or (m != null and m.match_over):
			break
		var delta: float = get_physics_process_delta_time()
		elapsed += delta
		if elapsed > 5.0 or (elapsed > 0.25 and not ball.has_pending_shot()):
			break
		if hopping:
			var u: float = clampf(origin.distance_to(ball.global_position) / span, 0.0, 1.0)
			ball.height = base_height + loud_crow_hop_height * sin(PI * u)
			ball.vel_z = ball.gravity * delta   # cancela a gravidade deste frame: a altura é conduzida aqui
			if u >= 1.0:
				hopping = false
				ball.height = base_height
				ball.vel_z = 0.0

	if not is_instance_valid(ball):
		return
	if ball.was_reset.is_connected(on_reset):
		ball.was_reset.disconnect(on_reset)
	ball.collisions_paused = false
	if hopping:
		ball.vel_z = 0.0   # solta: a gravidade assume


## Até onde (px, contados do chute) a bola precisa "pular": o obstáculo mais distante (o Karasu ou
## um inimigo) perto da linha do chute, mais uma folga. Entre 260 e 480 px.
func _ghost_span(origin: Vector2, dir: Vector2) -> float:
	var far: float = 0.0
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p == self or p.is_down:
			continue
		if p.team == team and not (p is Karasu):
			continue
		var off: Vector2 = p.global_position - origin
		var along: float = off.dot(dir)
		if along > 0.0 and absf(off.cross(dir)) <= 140.0:
			far = maxf(far, along)
	return clampf(far + 90.0, 260.0, 480.0)


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"id": SKILL_PASS, "name": skill_label(_pass_skill_name(), CD_PASS)})
	list.append({"id": SKILL_GLACIAL, "name": skill_label(_cut_skill_name(), CD_GLACIAL)})
	if _glacial_ready:
		list.append({"id": SKILL_ULTRASADIST, "name": "Ultrasadist (grátis)"})
	var meta_name: String = "Coldest Metavision (ativa)" if is_metavision_active() \
		else skill_label("Coldest Metavision", CD_METAVISION)
	list.append({"id": SKILL_METAVISION, "name": meta_name})
	if is_metavision_active():
		var guard_name: String = "Frost Guard (armado)" if _guard_armed else skill_label("Frost Guard", CD_GUARD_CRYO)
		list.append({"id": SKILL_FROST_GUARD, "name": guard_name})
		if not _is_on_defense_side():
			var cryo_name: String = "Loud Crow" if _find_sacrifice() != null else "Cryo Shot"
			list.append({"id": SKILL_CRYO_SHOT, "name": skill_label(cryo_name, CD_GUARD_CRYO)})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_PASS:
			return not is_on_cooldown(CD_PASS) and get_pass_variant() != PassVariant.NONE
		SKILL_GLACIAL:
			return not is_on_cooldown(CD_GLACIAL) and get_cut_variant() != CutVariant.NONE
		SKILL_ULTRASADIST:
			return _glacial_ready and _ball_in_reach()
		SKILL_METAVISION:
			return not is_metavision_active() and not is_on_cooldown(CD_METAVISION)
		SKILL_FROST_GUARD:
			var m: MatchManager = _get_manager()
			return m != null and is_metavision_active() and not is_on_cooldown(CD_GUARD_CRYO) \
				and not _guard_armed and height_level != Heights.Level.FLYING
		SKILL_CRYO_SHOT:
			if not is_metavision_active() or is_on_cooldown(CD_GUARD_CRYO) or _is_on_defense_side():
				return false
			var ball: Ball = _get_ball()
			var kind: KickType = get_kick_type(ball) if ball != null else KickType.NONE
			return kind == KickType.GROUND or kind == KickType.VOLLEY or kind == KickType.HIGH_BALL
	return false


## Ultrasadist é o complemento GRATUITO do Glacial Cut / Let It Go (ver player.gd: skill_is_free / has_free_followup)
func skill_is_free(skill_id: StringName) -> bool:
	return skill_id == SKILL_ULTRASADIST


func has_free_followup() -> bool:
	return _glacial_ready and _ball_in_reach()


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_PASS:
			return await _use_pass_skill()
		SKILL_GLACIAL:
			return await _use_cut_skill()
		SKILL_ULTRASADIST:
			return await _use_ultrasadist()
		SKILL_METAVISION:
			return await _use_metavision()
		SKILL_FROST_GUARD:
			return await _use_frost_guard()
		SKILL_CRYO_SHOT:
			return await _use_cryo_shot()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_PASS:
			if get_pass_variant() == PassVariant.NO_LOOK:
				title = "No Look Cross"
				text = "Passe alto para um aliado, com QTE fácil. De recompensa, o alcance sobe para %d." % int(no_look_cross_range)
			else:
				title = "Chilling Pass"
				text = "Passe alto para um aliado (alcance %d): a bola sobe no meio do caminho e chega nele Suspensa. No ar, vira No Look Cross." % int(chilling_pass_range)
			text += "\nRecarga: %d rodadas." % pass_cooldown
		SKILL_GLACIAL:
			if get_cut_variant() == CutVariant.LET_IT_GO:
				title = "Let It Go"
				text = "Avanço curto (alcance %d) em que o Hiori cai para o chão. Desvia dos inimigos que encontrar e os congela (sem habilidades e ações gerais por 1 rodada). Se encontrar a bola, domina e libera o Ultrasadist.\nRecarga: %d rodadas." % [int(let_it_go_range), glacial_cooldown]
			else:
				title = "Glacial Cut"
				text = "Corrida curta (%.1f s) e veloz. Se encontrar a bola, domina e libera o Ultrasadist de graça.\nRecarga: %d rodadas." % [glacial_cut_duration, glacial_cooldown]
		SKILL_ULTRASADIST:
			title = "Ultrasadist"
			text = "Complemento grátis (só com a bola perto do Hiori): passe para o ponto do campo que você escolher (alcance %d), QTE fácil. A bola chega Suspensa na mesma rodada; abaixo de %d ela só sobe a Suspensa, acima sobe a Voando." % [int(ultrasadist_range), int(ultrasadist_low_distance)]
		SKILL_METAVISION:
			title = "Coldest Metavision (ativa)" if is_metavision_active() else "Coldest Metavision"
			text = ("Por %d rodadas: os próximos %d Correr ganham +%.1f s e os chutes do Hiori e depois de um passe dele ganham +%d%% de chance. Libera Frost Guard e Cryo Shot.\n"
				+ "Recarga: %d rodadas depois do efeito.") % [
				metavision_rounds, metavision_run_count, metavision_run_bonus, _pct(metavision_self_shot_bonus), metavision_cooldown]
		SKILL_FROST_GUARD:
			title = "Frost Guard"
			text = "Você escolhe a direção e, com aliado ao alcance, quem recebe o passe (sem aliado, o Hiori fica com a bola). A detecção (raio %d) fica armada para o turno inimigo. Chute no chão: ele vai até a bola e passa (ou fica com ela). Suspenso: ele salta até a bola e dá um deflect %.1fx para a esquerda. Voando: ele salta até a bola e dá um deflect %.1fx na direção escolhida (QTE).\nRecarga: %d rodadas (compartilhada com o Cryo Shot)." % [
				int(frost_guard_range), frost_side_mult, frost_air_mult, guard_cryo_cooldown]
		SKILL_CRYO_SHOT:
			var star: ChemicalReaction = _find_sacrifice()
			if star != null:
				title = "Loud Crow"
				text = "Reação Química Sacrifice com o Karasu: MIRE NO KARASU e o chute sai mais forte, com %d%% de chance de gol, e a bola passa por cima dele e dos inimigos. Mirando para outro lado, sai o Cryo Shot (%d%%).\nA reação recarrega em %d rodadas. Recarga: %d rodadas." % [
					_pct(loud_crow_chance), _pct(cryo_shot_chance), star.cooldown_rounds, guard_cryo_cooldown]
			else:
				title = "Cryo Shot"
				text = "Chute comum com %.1fx a força do Chutar e %d%% de chance pura (voleio tem QTE).\nRecarga: %d rodadas (compartilhada com o Frost Guard)." % [
					cryo_force_mult, _pct(cryo_shot_chance), guard_cryo_cooldown]
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()
	_glacial_ready = false
	_metavision_until_round = -1
	_run_bonus_left = 0
	_assist_target = null
	last_ultrasadist = {}
	_guard_armed = false
	_guard_live = false
	_guard_busy = false
	_guard_ally = null
	_aiming_loud_crow = false
	_loud_crow_partner = null
	if _aura != null:
		_aura.emitting = false
	queue_redraw()


# ---------- LOOP / VISUAL ----------

func _process(delta: float) -> void:
	super(delta)
	if _aura != null:   # neve em volta dele enquanto a Metavision está valendo ou o Frost Guard está armado
		var want: bool = is_metavision_active() or _guard_armed or _guard_live
		if _aura.emitting != want:
			_aura.emitting = want
		if want:
			_aura.position = Vector2(0.0, -height)
	if _frost_area_shown() or _glacial_ready:
		queue_redraw()   # o floco gira devagar / o anel do Ultrasadist acompanha a bola


func _physics_process(delta: float) -> void:
	super(delta)
	if _guard_live and not _guard_busy:
		_scan_for_shot()


func _frost_area_shown() -> bool:
	return frost_area_enabled and (_guard_armed or _guard_live)


func _draw() -> void:
	super()
	var center := Vector2(0.0, -height)

	# Auréola gelada enquanto a Coldest Metavision está ativa
	if is_metavision_active():
		var aura_color := Color(0.6, 0.9, 1.0, 0.9)
		draw_circle(center, placeholder_radius + 8.0, Color(aura_color, 0.12))
		draw_arc(center, placeholder_radius + 8.0, 0.0, TAU, 28, aura_color, 2.0)

	# Anel branco-gelo enquanto o Ultrasadist está esperando ser usado
	if _glacial_ready and _ball_in_reach():
		draw_arc(center, placeholder_radius + 14.0, 0.0, TAU, 20, Color(0.9, 0.98, 1.0, 0.95), 2.0)

	# Frost Guard: círculo do alcance com um floco grande (mais forte no turno inimigo, quando está procurando)
	if _frost_area_shown():
		HioriFX.draw_frost_area(self, Vector2.ZERO, frost_guard_range, 1.0 if _guard_live else 0.5,
			Time.get_ticks_msec() / 1000.0 * 0.3)

	# Loud Crow: destaca o Karasu enquanto mira (mais forte quando a mira passa por ele)
	if is_aiming and _aiming_loud_crow:
		_draw_loud_crow_hint()


## Anel roxo em volta do Karasu: fraco = "mire nele"; forte e duplo = a mira passa por ele
func _draw_loud_crow_hint() -> void:
	var p: Player = _loud_crow_partner
	var ball: Ball = _get_ball()
	if p == null or not is_instance_valid(p) or ball == null:
		return
	var hit: bool = _aim_hits_partner(aim_direction, p, ball)
	var c: Vector2 = to_local(p.global_position) + Vector2(0.0, -p.height)
	var pulse: float = sin(Time.get_ticks_msec() / 1000.0 * 8.0) * 2.0
	var col := Color(0.75, 0.5, 1.0, 0.95 if hit else 0.45)
	draw_arc(c, p.body_radius + 16.0 + pulse, 0.0, TAU, 32, col, 4.0 if hit else 2.0)
	if hit:
		draw_arc(c, p.body_radius + 28.0 - pulse, 0.0, TAU, 32, Color(col, 0.55), 2.0)
