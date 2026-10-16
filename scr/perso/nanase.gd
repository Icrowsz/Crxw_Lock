class_name Nanase
extends Player
## Nanase. Herda tudo do Player (ações gerais) e adiciona as habilidades próprias.
## Visual: azul pastel (aura/trilha azul pastel, partículas azul clarinho, marca do mestre).
##
## 1. Cross Window / Left Footed Strike (mesmo botão, recarga de 2 rodadas compartilhada; a variante é
##      escolhida sozinha pela posição da bola):
##      - Bola PRÓXIMA e NO CHÃO (Nanase no chão) -> Cross Window: você escolhe um aliado (alcance 475) e
##        ela dá um passe ALTO que chega na MESMA rodada (pousa Suspenso no aliado).
##      - SEM bola próxima -> Left Footed Strike: dash médio na direção da bola (automático; você só mira
##        o chute antes). Se alcançar a bola no chão ou suspensa, dá um chute de 40%.
## 2. Survival Instinct / Ambi-Deflect (mesmo botão, recarga de 2 rodadas compartilhada; a variante é
##      escolhida sozinha pela altura dela):
##      - Nanase NO CHÃO -> Survival Instinct: um Carrinho um pouco mais longo (você mira). Se encontrar
##        a bola no chão, dá um passe para o aliado mais próximo (o resto do Carrinho funciona normal).
##      - Nanase SUSPENSA -> Ambi-Deflect: ela se joga em direção à bola (automático). Se encontrar a bola
##        SUSPENSA, dá um deflect: a bola é desviada para a frente, seguindo a direção do mergulho, e
##        fica pairando Suspensa (cai no fim do turno se ninguém tocar).
## 3. Leader Mark (recarga de 3 rodadas CONTADAS A PARTIR DO FIM do efeito): escolhe um aliado como
##      "mestre" por 4 rodadas. Melhorias das outras habilidades com ele:
##      - Cross Window para o mestre: +6% no próximo chute dele.
##      - Left Footed Strike com assistência do mestre (ele foi o último a tocar na bola): +6% de chance.
##      - Ambi-Deflect: o deflect vira um passe rasteiro para o mestre, se ele estiver ao alcance.
##
## Como montar a cena: Nova Cena Herdada de player.tscn -> anexe este script ao nó raiz
## -> renomeie o nó raiz para "Nanase".
## Animações opcionais (se faltar alguma, o jogo só pula): cross_window, left_footed_strike,
## survival_instinct, ambi_deflect, leader_mark.
##
## Não precisa de nenhum gancho novo no match_manager.gd nem no player.gd.

const SKILL_WINDOW: StringName = &"cross_window"        # também é o Left Footed Strike (variante)
const SKILL_SURVIVAL: StringName = &"survival_instinct"  # também é o Ambi-Deflect (variante)
const SKILL_MARK: StringName = &"leader_mark"

## Grupos de recarga (as variantes compartilham o do pai)
const CD_WINDOW: StringName = &"cd_window"
const CD_SURVIVAL: StringName = &"cd_survival"
const CD_MARK: StringName = &"cd_mark"

const PASTEL_BLUE: Color = Color(0.60, 0.78, 0.96)
const PALE_WHITE: Color = Color(0.88, 0.94, 1.0)

enum WindowVariant { NONE, CROSS_WINDOW, LEFT_FOOTED }
enum SurvivalVariant { NONE, SURVIVAL, AMBI_DEFLECT }

@export_group("Cross Window / Left Footed Strike")
@export var window_range: float = 475.0            # alcance do passe alto
@export var window_cooldown: int = 2               # recarga compartilhada
@export var near_range: float = 90.0               # "bola próxima": decide entre Cross Window e Left Footed Strike
@export var lfs_dash_distance: float = 260.0       # dash "médio" na direção da bola
@export var lfs_dash_time: float = 0.35
@export_range(0.0, 1.0) var lfs_chance: float = 0.40
@export var contact_margin: float = 12.0           # folga (px) para "encontrar" a bola no caminho

@export_group("Survival Instinct / Ambi-Deflect")
@export var survival_cooldown: int = 2             # recarga compartilhada
@export var slide_length_mult: float = 1.3         # Carrinho "um pouco mais longo" (vezes o slide_distance)
@export var ambi_dive_distance: float = 240.0      # quanto ela se joga em direção à bola
@export var ambi_dive_time: float = 0.3
@export var deflect_distance: float = 260.0        # quanto a bola avança no deflect (sem mestre)
@export var deflect_time: float = 0.3

@export_group("Leader Mark")
@export var mark_rounds: int = 4                   # duração do efeito (contando a rodada atual)
@export var mark_cooldown: int = 3                 # rodadas de recarga DEPOIS do fim do efeito
@export_range(0.0, 1.0) var mark_window_bonus: float = 0.06   # Cross Window: +6% no próximo chute do mestre
@export_range(0.0, 1.0) var mark_lfs_bonus: float = 0.06      # Left Footed Strike com assistência do mestre

@export_group("Visual")
## Aura + partículas dos chutes e passes. Vazio = usa o estilo padrão da Nanase (azul pastel)
@export var kick_fx: KickFX

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: cross_window, survival_instinct, leader_mark.
## Sem imagem, o balão aparece só com o texto.
@export var skill_icons: Dictionary = {}

## Muda quando a partida reinicia: mergulhos/passes que estavam esperando desistem
var _epoch: int = 0

## Leader Mark: o mestre e até que rodada vale
var _master: Player = null
var _mark_until_round: int = -1

## Survival Instinct: o Carrinho está em andamento / já encostou na bola / para quem vai o passe
var _si_active: bool = false
var _si_contact: bool = false
var _si_target: Player = null


func _init() -> void:
	character_id = "nanase"        # o menu de formação usa isto para saber quem é quem
	display_name = "Nanase"


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = _make_kick_fx()


## Azul pastel, com partículas claras que sobem
func _make_kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = PASTEL_BLUE
	fx.trail_width = 14.0
	fx.shape = KickFX.Shape.SQUARE
	fx.particle_color = PALE_WHITE
	fx.amount = 22
	fx.lifetime = 0.55
	fx.speed_min = 15.0
	fx.speed_max = 70.0
	fx.gravity = Vector2(0.0, -45.0)
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


func _ok_target(p: Player) -> bool:
	return p != self and not p.is_pass_blocked()


## A bola está solta, ao alcance e a menos de near_range?
func _ball_near() -> bool:
	var ball: Ball = _get_ball()
	if ball == null or ball.is_held() or ball.is_locked_for(team):
		return false
	if not can_reach_level(ball.get_level()):
		return false
	return global_position.distance_to(ball.global_position) <= near_range


## A bola está solta, no nível pedido, ao alcance de um deslocamento de "distance"?
func _ball_reachable_by_dash(distance: float, allow_ground: bool, allow_suspended: bool) -> bool:
	var ball: Ball = _get_ball()
	if ball == null or ball.is_held() or ball.is_locked_for(team):
		return false
	var level: Heights.Level = ball.get_level()
	if level == Heights.Level.FLYING or not can_reach_level(level):
		return false
	if level == Heights.Level.GROUND and not allow_ground:
		return false
	if level == Heights.Level.SUSPENDED and not allow_suspended:
		return false
	var reach: float = distance + body_radius + ball.collision_radius + contact_margin
	return global_position.distance_to(ball.global_position) <= reach


## A bola (no nível permitido, solta) está encostando na Nanase agora?
func _ball_in_way(allow_ground: bool, allow_suspended: bool) -> Ball:
	var ball: Ball = _get_ball()
	if ball == null or ball.is_held() or ball.is_locked_for(team):
		return null
	var level: Heights.Level = ball.get_level()
	if level == Heights.Level.FLYING or not can_reach_level(level):
		return null
	if level == Heights.Level.GROUND and not allow_ground:
		return null
	if level == Heights.Level.SUSPENDED and not allow_suspended:
		return null
	if global_position.distance_to(ball.global_position) <= body_radius + ball.collision_radius + contact_margin:
		return ball
	return null


## Anda até dest em duration segundos (desacelerando). Para quando encosta na bola (nos níveis
## permitidos). Devolve a bola (ou null se não encostou).
func _dash_to_ball(dest: Vector2, duration: float, allow_ground: bool, allow_suspended: bool) -> Ball:
	var epoch: int = _epoch
	var start: Vector2 = global_position
	var t: float = 0.0
	while t < duration:
		await get_tree().physics_frame
		if epoch != _epoch:
			return null
		t += get_physics_process_delta_time()
		var k: float = clampf(t / duration, 0.0, 1.0)
		global_position = start.lerp(dest, 1.0 - (1.0 - k) * (1.0 - k))
		var ball: Ball = _ball_in_way(allow_ground, allow_suspended)
		if ball != null:
			return ball
	return null


## Aliado mais próximo da bola (de pé, que pode receber passe), ou null
func _nearest_ally_to(point: Vector2) -> Player:
	var m: MatchManager = _get_manager()
	if m == null:
		return null
	var best: Player = null
	var best_d: float = INF
	for p: Player in m.get_team_players(team):
		if p == self or p.is_down or p.is_pass_blocked():
			continue
		var d: float = p.global_position.distance_to(point)
		if d < best_d:
			best_d = d
			best = p
	return best


## Passe rasteiro reto (curve_ratio 0) com a aura azul pastel e a animação indicada.
## Se o passe não saiu (alvo colado, por exemplo), a bola não fica presa pairando.
func _ground_pass(m: MatchManager, ball: Ball, target: Player, anim: StringName) -> void:
	m.clear_pending_pass()
	await m.run_curved_ground_pass(self, target, ball, 0.0, 1.0, anim, kick_fx)
	if ball.hovering and not ball.is_held():
		ball.release_hover()


# ---------- LEADER MARK: estado ----------

func _mark_active() -> bool:
	return _master != null and is_instance_valid(_master) and get_current_round() <= _mark_until_round


## O mestre atual (ou null se o efeito acabou)
func _active_master() -> Player:
	return _master if _mark_active() else null


func _physics_process(delta: float) -> void:
	super(delta)
	# O efeito acabou: tira a marca (a recarga já foi marcada para depois do fim, ao usar)
	if _master != null and not _mark_active():
		_master = null
		_mark_until_round = -1
		queue_redraw()
	# Survival Instinct: ao encostar na bola no chão durante o Carrinho, o carrinho para e sai o passe
	if _si_active and not _si_contact and not is_down:
		var ball: Ball = _get_ball()
		if ball != null and not ball.is_held() and not ball.is_locked_for(team) \
				and ball.get_level() == Heights.Level.GROUND \
				and global_position.distance_to(ball.global_position) <= slide_hit_radius:
			_si_contact = true
			_si_target = _nearest_ally_to(ball.global_position)
			ball.ignore_player_until_stopped(self)   # a bola não bate na Nanase enquanto o carrinho termina
			slide_time_left = 0.0                    # o carrinho termina aqui


# ---------- HABILIDADE 1: CROSS WINDOW / LEFT FOOTED STRIKE ----------

func get_window_variant() -> WindowVariant:
	if is_down:
		return WindowVariant.NONE
	var ball: Ball = _get_ball()
	if ball == null:
		return WindowVariant.NONE
	if _ball_near():
		# Bola próxima: só vale a Cross Window, com a bola no chão e Nanase no chão
		if height_level == Heights.Level.GROUND and ball.get_level() == Heights.Level.GROUND:
			return WindowVariant.CROSS_WINDOW
		return WindowVariant.NONE
	# Sem bola próxima: Left Footed Strike, se um dash médio chega na bola (no chão ou suspensa)
	if _ball_reachable_by_dash(lfs_dash_distance, true, true):
		return WindowVariant.LEFT_FOOTED
	return WindowVariant.NONE


func _window_skill_name() -> String:
	return "Left Footed Strike" if get_window_variant() == WindowVariant.LEFT_FOOTED else "Cross Window"


func _has_ally_in_range(reach: float) -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	for other: Player in m.get_team_players(team):
		if _ok_target(other) and global_position.distance_to(other.global_position) <= reach:
			return true
	return false


func _use_window() -> bool:
	match get_window_variant():
		WindowVariant.CROSS_WINDOW:
			return await _do_cross_window()
		WindowVariant.LEFT_FOOTED:
			return await _do_left_footed()
	return false


## Cross Window: passe alto (alcance 475) que chega na mesma rodada, pousando Suspenso no aliado
func _do_cross_window() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var epoch: int = _epoch

	# Escolhe o aliado (clique direito / Esc cancela e NÃO gasta a ação)
	var target: Player = await m.pick_ally_for_skill(self, window_range, false, Callable(self, "_ok_target"))
	if target == null or not is_instance_valid(target):
		return false
	if get_window_variant() != WindowVariant.CROSS_WINDOW:   # a bola pode ter saído do alcance
		return false

	face_towards(target.global_position - global_position)
	if not await play_action(&"cross_window", ANIM_PASS_HIGH):
		return false
	var ball: Ball = _get_ball()
	if epoch != _epoch or get_window_variant() != WindowVariant.CROSS_WINDOW or not is_instance_valid(target):
		return false

	# A bola sobe e pousa Suspensa no aliado, tudo na mesma rodada
	m.clear_pending_pass()
	ball.register_touch(self)
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
	if epoch != _epoch:
		return false
	# Pairando Suspensa no aliado; se ninguém tocar até o fim do turno, o manager a solta
	m.register_skill_pass(team, target)
	m.pass_completed.emit(self, target)

	# Leader Mark: Cross Window para o mestre dá +6% no próximo chute dele
	if target == _active_master() and is_instance_valid(target):
		target.next_shot_bonus += mark_window_bonus
		target.queue_redraw()
	start_cooldown(CD_WINDOW, window_cooldown)
	return true


## Left Footed Strike: dash médio na direção da bola; se alcançar, chute de 40%
func _do_left_footed() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var epoch: int = _epoch

	# Primeiro mira o chute; cancelar não gasta a ação
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false
	if get_window_variant() != WindowVariant.LEFT_FOOTED:   # a bola pode ter mudado enquanto ela mirava
		return false

	var ball: Ball = _get_ball()
	face_towards(ball.global_position - global_position)
	if not await play_action(&"left_footed_strike"):
		return false
	ball = _get_ball()
	if epoch != _epoch or ball == null:
		return false

	# Dash na direção da bola (automático)
	var dir: Vector2 = (ball.global_position - global_position).normalized()
	var dest: Vector2 = _clamp_to_pitch(global_position + dir * lfs_dash_distance)
	var reached: Ball = await _dash_to_ball(dest, lfs_dash_time, true, true)
	if epoch != _epoch:
		return false

	if reached != null:
		var kind: KickType = get_kick_type(reached)   # o chute comum que caberia nesta situação
		if kind != KickType.NONE:
			var chance: float = lfs_chance
			# Leader Mark: assistência do mestre (ele foi o último a tocar na bola) = +6%
			var master: Player = _active_master()
			if master != null and reached.last_toucher == master:
				chance += mark_lfs_bonus
			# QTE do chute comum: bola no chão = sem QTE; suspensa = com QTE
			var qte_ok: bool = true
			if kind != KickType.GROUND and not skips_qte():
				qte_ok = await m.run_qte(kind)
			# Errou o QTE = chute fraquinho, sem aura (e o kick_ball derruba a Nanase)
			await kick_ball(reached, aim, kind, qte_ok, chance, false,
				kick_fx if qte_ok else null, &"left_footed_strike")
	start_cooldown(CD_WINDOW, window_cooldown)
	return true


# ---------- HABILIDADE 2: SURVIVAL INSTINCT / AMBI-DEFLECT ----------

func get_survival_variant() -> SurvivalVariant:
	if is_down:
		return SurvivalVariant.NONE
	if height_level == Heights.Level.GROUND:
		return SurvivalVariant.SURVIVAL
	if height_level == Heights.Level.SUSPENDED and _ball_reachable_by_dash(ambi_dive_distance, false, true):
		return SurvivalVariant.AMBI_DEFLECT
	return SurvivalVariant.NONE


func _survival_skill_name() -> String:
	return "Ambi-Deflect" if height_level == Heights.Level.SUSPENDED else "Survival Instinct"


func _use_survival() -> bool:
	match get_survival_variant():
		SurvivalVariant.SURVIVAL:
			return await _do_survival()
		SurvivalVariant.AMBI_DEFLECT:
			return await _do_ambi_deflect()
	return false


## Survival Instinct: Carrinho mais longo; se encontrar a bola no chão, passa para o aliado mais próximo
func _do_survival() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var epoch: int = _epoch
	var base_distance: float = slide_distance

	# Primeiro mira; cancelar não gasta a ação
	var aim: Vector2 = await m.aim_for_skill(self, base_distance * slide_length_mult)
	if aim == Vector2.ZERO:
		return false
	if get_survival_variant() != SurvivalVariant.SURVIVAL:
		return false

	face_towards(aim)
	# Carrinho "de verdade" (derruba inimigos do jeito normal), só que mais longo e sem gastar o
	# Carrinho do turno
	slide_distance = base_distance * slide_length_mult
	_si_active = true
	_si_contact = false
	_si_target = null
	start_slide(aim)
	slides_this_turn -= 1
	# Se há alguém para passar, a bola é tratada aqui (o Carrinho normal chutaria ela para a frente)
	if _nearest_ally_to(global_position) != null:
		_slide_hit_ball = true
	await slide_finished
	slide_distance = base_distance
	_si_active = false
	if epoch != _epoch:
		return false

	# Encostou na bola no chão: passe rasteiro para o aliado mais próximo
	var ball: Ball = _get_ball()
	if _si_contact and ball != null and _si_target != null and is_instance_valid(_si_target):
		await _ground_pass(m, ball, _si_target, &"survival_instinct")
		if epoch != _epoch:
			return false
	_si_target = null
	start_cooldown(CD_SURVIVAL, survival_cooldown)
	return true


## Ambi-Deflect: se joga em direção à bola; se encontrar a bola suspensa, dá um deflect nela
func _do_ambi_deflect() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false
	var epoch: int = _epoch

	face_towards(ball.global_position - global_position)
	if not await play_action(&"ambi_deflect"):
		return false
	ball = _get_ball()
	if epoch != _epoch or ball == null or get_survival_variant() != SurvivalVariant.AMBI_DEFLECT:
		return false

	# Mergulho na direção da bola (automático)
	var dir: Vector2 = (ball.global_position - global_position).normalized()
	var dest: Vector2 = _clamp_to_pitch(global_position + dir * ambi_dive_distance)
	var reached: Ball = await _dash_to_ball(dest, ambi_dive_time, false, true)
	if epoch != _epoch:
		return false

	if reached != null:
		await _deflect(m, reached, dir)
		if epoch != _epoch:
			return false
	start_cooldown(CD_SURVIVAL, survival_cooldown)
	return true


## Deflect: desvia a bola para a frente (Suspensa). Com o mestre ao alcance (Leader Mark),
## vira um passe rasteiro para ele.
func _deflect(m: MatchManager, ball: Ball, dir: Vector2) -> void:
	m.clear_pending_pass()
	var master: Player = _active_master()
	var pass_reach: float = m.pass_range_for(MatchManager.PassVariant.GROUND, self)
	if master != null and not master.is_pass_blocked() \
			and global_position.distance_to(master.global_position) <= pass_reach:
		await _ground_pass(m, ball, master, &"ambi_deflect")
		return
	ball.register_touch(self)
	var spot: Vector2 = _clamp_to_pitch(ball.global_position + dir * deflect_distance)
	ball.hover_to(spot, Heights.SUSPENDED_HEIGHT, deflect_time)
	ball.play_fx(kick_fx)
	# A bola fica pairando Suspensa; se ninguém tocar até o fim do turno, o manager a solta (cai)
	m.register_skill_pass(team, null)


# ---------- HABILIDADE 3: LEADER MARK ----------

func _use_mark() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false

	# Escolhe o mestre (qualquer aliado; clique direito / Esc cancela e NÃO gasta a ação)
	var target: Player = await m.pick_ally_for_skill(self, 100000.0, false, Callable(self, "_ok_master"))
	if target == null or not is_instance_valid(target):
		return false

	face_towards(target.global_position - global_position)
	if not await play_action(&"leader_mark"):
		return false
	if not is_instance_valid(target):
		return false

	_master = target
	_mark_until_round = get_current_round() + mark_rounds - 1   # a rodada atual conta
	# A recarga só começa a contar depois do fim do efeito (rodada seguinte à última do efeito)
	start_cooldown(CD_MARK, mark_cooldown, _mark_until_round + 1)
	queue_redraw()
	return true


func _ok_master(p: Player) -> bool:
	return p != self


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"id": SKILL_WINDOW, "name": skill_label(_window_skill_name(), CD_WINDOW)})
	list.append({"id": SKILL_SURVIVAL, "name": skill_label(_survival_skill_name(), CD_SURVIVAL)})
	var mark_name: String = skill_label("Leader Mark", CD_MARK)
	if _mark_active():
		mark_name = "Leader Mark (mestre: %s)" % _master.display_name
	list.append({"id": SKILL_MARK, "name": mark_name})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_WINDOW:
			if is_on_cooldown(CD_WINDOW):
				return false
			match get_window_variant():
				WindowVariant.CROSS_WINDOW:
					return _has_ally_in_range(window_range)
				WindowVariant.LEFT_FOOTED:
					return true
			return false
		SKILL_SURVIVAL:
			return not is_on_cooldown(CD_SURVIVAL) and get_survival_variant() != SurvivalVariant.NONE
		SKILL_MARK:
			# A recarga já inclui os 4 rodadas do efeito: enquanto a marca vale, não dá para refazer
			var m: MatchManager = _get_manager()
			return m != null and not is_on_cooldown(CD_MARK) and not _mark_active() \
				and m.get_team_players(team).size() > 1
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_WINDOW:
			return await _use_window()
		SKILL_SURVIVAL:
			return await _use_survival()
		SKILL_MARK:
			return await _use_mark()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_WINDOW:
			var cross_text: String = "Com a bola próxima no chão, Nanase prepara um passe alto (alcance %d) que chega na mesma rodada." % int(window_range)
			var lfs_text: String = "Sem a bola próxima, Nanase dá um dash médio na direção da bola. Se alcançar a bola no chão ou suspensa, dá um chute de %d%% de chance." % _pct(lfs_chance)
			match get_window_variant():
				WindowVariant.CROSS_WINDOW:
					title = "Cross Window"
					text = cross_text
				WindowVariant.LEFT_FOOTED:
					title = "Left Footed Strike"
					text = lfs_text
				_:
					title = "Cross Window / Left Footed Strike"
					text = cross_text + "\n" + lfs_text
			text += "\nRecarga: %d rodadas." % window_cooldown
		SKILL_SURVIVAL:
			var survival_text: String = "Nanase no chão dá um Carrinho um pouco mais longo. Se encontrar a bola no chão, passa para o aliado mais próximo."
			var ambi_text: String = "Nanase suspensa se joga em direção da bola. Se encontrar a bola suspensa, dá um deflect nela."
			match height_level:
				Heights.Level.SUSPENDED:
					title = "Ambi-Deflect"
					text = ambi_text
				Heights.Level.GROUND:
					title = "Survival Instinct"
					text = survival_text
				_:
					title = "Survival Instinct / Ambi-Deflect"
					text = survival_text + "\n" + ambi_text
			text += "\nRecarga: %d rodadas." % survival_cooldown
		SKILL_MARK:
			title = "Leader Mark"
			text = "Escolhe um aliado como mestre por %d rodadas. Com ele: Cross Window dá +%d%% no próximo chute dele; Left Footed Strike com assistência dele tem +%d%% de chance; o deflect do Ambi-Deflect vira passe rasteiro para ele (se estiver ao alcance).\nRecarga: %d rodadas após o fim do efeito." % [
				mark_rounds, _pct(mark_window_bonus), _pct(mark_lfs_bonus), mark_cooldown]
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	_epoch += 1   # mergulhos/passes que estavam esperando desistem (o super() encerra o Carrinho)
	super()
	_master = null
	_mark_until_round = -1
	_si_active = false
	_si_contact = false
	_si_target = null
	queue_redraw()


# ---------- LOOP / VISUAL ----------

func _process(delta: float) -> void:
	super(delta)
	if _master != null:
		queue_redraw()   # a marca no mestre acompanha o movimento dele


func _draw() -> void:
	super()
	# Leader Mark: anel azul pastel com um pontinho claro em cima do mestre
	var master: Player = _active_master()
	if master != null:
		var c: Vector2 = to_local(master.global_position) + Vector2(0.0, -master.height)
		draw_arc(c, placeholder_radius + 12.0, 0.0, TAU, 40, Color(PASTEL_BLUE, 0.95), 3.0)
		draw_arc(c, placeholder_radius + 15.0, 0.0, TAU, 40, Color(PALE_WHITE, 0.8), 1.5)
		draw_circle(c + Vector2(0.0, -placeholder_radius - 26.0), 3.5, PALE_WHITE)
