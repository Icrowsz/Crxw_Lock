class_name Naruhaya
extends Player
## Naruhaya. Herda tudo do Player (ações gerais) e adiciona as habilidades próprias.
## Visual: laranja sujo de marrom (aura/trilha laranja queimado, partículas marrons, zona do Blind Spot).
##
## 1. Off-Ball / On The Line (mesmo botão, recarga de 2 rodadas compartilhada; a variante é escolhida
##      sozinha pela altura dele):
##      - Naruhaya NO CHÃO e SEM bola próxima -> Off-Ball: avanço curto (você mira). Se encontrar um
##        inimigo no caminho, o avanço para ali, dá STUN nele e Naruhaya ganha mais um avanço (na mesma
##        direção, automático). Só acontece uma vez por uso.
##      - Naruhaya SUSPENSO -> On The Line: você escolhe antes um aliado ao alcance e depois mira o avanço
##        curto. Se ele encontrar a bola (suspensa ou no chão) no caminho, para ali e dá um passe
##        rasteiro (alcance 475) para o aliado escolhido. Se não encontrar a bola, só avança.
## 2. Blind Spot (recarga de 3 rodadas): cria uma pequena área no chão, perto dele (você escolhe o ponto).
##      Se ele chegar lá, ganha +0.6 s nas próximas 2 ações de Correr e +7% de chance no My Goal.
## 3. My Goal (recarga de 2 rodadas): chute comum MIRADO de 40%, com Naruhaya no chão e a bola no chão
##      ou suspensa. O QTE é o do chute comum (bola no chão = sem QTE; bola suspensa = QTE).
##
## Como montar a cena: Nova Cena Herdada de player.tscn -> anexe este script ao nó raiz
## -> renomeie o nó raiz para "Naruhaya".
## Animações opcionais (se faltar alguma, o jogo só pula): off_ball, on_the_line, blind_spot, my_goal.
##
## Não precisa de nenhum gancho novo no match_manager.gd nem no player.gd.

const SKILL_MOVE: StringName = &"off_ball"      # também é o On The Line (variante)
const SKILL_SPOT: StringName = &"blind_spot"
const SKILL_GOAL: StringName = &"my_goal"

## Grupos de recarga (as variantes compartilham o do pai)
const CD_MOVE: StringName = &"cd_move"
const CD_SPOT: StringName = &"cd_spot"
const CD_GOAL: StringName = &"cd_goal"

const DIRTY_ORANGE: Color = Color(0.80, 0.42, 0.10)
const BROWN: Color = Color(0.42, 0.25, 0.12)

enum MoveVariant { NONE, OFF_BALL, ON_THE_LINE }

@export_group("Off-Ball / On The Line")
@export var dash_distance: float = 230.0           # tamanho do avanço curto (e da seta de mira)
@export var dash_time: float = 0.25
@export var move_cooldown: int = 2                 # recarga compartilhada
@export var near_range: float = 90.0               # "bola próxima": a Off-Ball só vale sem bola por perto
@export var hit_margin: float = 10.0               # folga (px) para "encontrar" inimigo/bola no caminho
@export var stun_rounds: int = 1                   # rodadas de stun no inimigo (1 = só esta rodada)
@export var line_pass_range: float = 475.0         # alcance do passe rasteiro do On The Line

@export_group("Blind Spot")
@export var spot_cooldown: int = 3
@export var spot_range: float = 220.0              # até onde dá para criar a área
@export var spot_radius: float = 45.0              # "pequena": raio da área
@export var spot_rounds: int = 3                   # quanto tempo a área fica no campo (contando a atual)
@export var spot_run_bonus: float = 0.6            # segundos a mais no Correr
@export var spot_run_actions: int = 2              # quantas ações de Correr ganham o bônus
@export_range(0.0, 1.0) var spot_goal_bonus: float = 0.07   # +7% no próximo My Goal
@export var spot_buff_rounds: int = 3              # quanto tempo o bônus dura depois que ele chega lá (contando a atual)

@export_group("My Goal")
@export_range(0.0, 1.0) var goal_chance: float = 0.40
@export var goal_cooldown: int = 2

@export_group("Visual")
## Aura + partículas dos chutes e passes. Vazio = usa o estilo padrão do Naruhaya (laranja sujo de marrom)
@export var kick_fx: KickFX

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: off_ball, blind_spot, my_goal.
## Sem imagem, o balão aparece só com o texto.
@export var skill_icons: Dictionary = {}

## Muda quando a partida reinicia: avanços/passes que estavam esperando desistem
var _epoch: int = 0

## Blind Spot: onde está a área e até que rodada ela vale (-1 = não há área)
var _zone_point: Vector2 = Vector2.ZERO
var _zone_until_round: int = -1
## Bônus ganho ao chegar na área: Correr (ações restantes) e My Goal, até esta rodada (-1 = sem bônus)
var _buff_until_round: int = -1
var _buff_runs_left: int = 0
var _goal_bonus_ready: bool = false
var _run_bonus_pending: bool = false


func _init() -> void:
	character_id = "naruhaya"        # o menu de formação usa isto para saber quem é quem
	display_name = "Naruhaya"


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = _make_kick_fx()
	run_finished.connect(_on_run_finished)


## Laranja sujo, com partículas marrons
func _make_kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = DIRTY_ORANGE
	fx.trail_width = 14.0
	fx.shape = KickFX.Shape.SQUARE
	fx.particle_color = BROWN
	fx.amount = 22
	fx.lifetime = 0.55
	fx.speed_min = 15.0
	fx.speed_max = 70.0
	fx.gravity = Vector2(0.0, -40.0)
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


## A bola está solta, ao alcance e a menos de near_range?
func _ball_near() -> bool:
	var ball: Ball = _get_ball()
	if ball == null or ball.is_held() or ball.is_locked_for(team):
		return false
	if not can_reach_level(ball.get_level()):
		return false
	return global_position.distance_to(ball.global_position) <= near_range


## Inimigo de pé, no chão, encostando em Naruhaya? (o avanço Off-Ball para nele)
func _enemy_in_way() -> Player:
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p.team == team or p.is_down or p.height_level != Heights.Level.GROUND:
			continue
		if global_position.distance_to(p.global_position) <= body_radius + p.body_radius + hit_margin:
			return p
	return null


## A bola (suspensa ou no chão, solta) está encostando em Naruhaya? (o avanço On The Line para nela)
func _ball_in_way() -> Ball:
	var ball: Ball = _get_ball()
	if ball == null or ball.is_held() or ball.is_locked_for(team):
		return null
	if ball.get_level() == Heights.Level.FLYING:
		return null
	if global_position.distance_to(ball.global_position) <= body_radius + ball.collision_radius + hit_margin:
		return ball
	return null


## Avanço: anda até dest em duration segundos (desacelerando). Para no primeiro contato do tipo
## pedido: "enemy" (Off-Ball), "ball" (On The Line) ou "" (nenhum). Devolve o que encontrou (ou null).
func _dash_path(dest: Vector2, duration: float, detect: StringName) -> Object:
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
		var found: Object = null
		match detect:
			&"enemy":
				found = _enemy_in_way()
			&"ball":
				found = _ball_in_way()
		if found != null:
			return found
	return null


# ---------- BLIND SPOT: estado e bônus ----------

func _zone_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _zone_until_round >= 0 and m.round_number <= _zone_until_round


func _buff_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _buff_until_round >= 0 and m.round_number <= _buff_until_round


## O bônus do My Goal está valendo agora?
func _goal_bonus_active() -> bool:
	return _goal_bonus_ready and _buff_active()


## Chegou na área: ganha o bônus e a área some
func _reach_zone() -> void:
	var m: MatchManager = _get_manager()
	if m == null:
		return
	_zone_until_round = -1
	_buff_until_round = m.round_number + spot_buff_rounds - 1   # a rodada atual conta
	_buff_runs_left = spot_run_actions
	_goal_bonus_ready = true
	queue_redraw()


func _physics_process(delta: float) -> void:
	super(delta)
	if _zone_until_round >= 0:
		if not _zone_active():
			_zone_until_round = -1   # a área expirou
			queue_redraw()
		elif not is_down and global_position.distance_to(_zone_point) <= spot_radius:
			_reach_zone()
	if _buff_until_round >= 0 and not _buff_active():
		_buff_until_round = -1       # o bônus expirou
		_buff_runs_left = 0
		_goal_bonus_ready = false
		queue_redraw()


## Correr: +0.6 s nas próximas 2 ações enquanto o bônus valer (tirado quando a corrida acaba)
func start_run() -> void:
	if _buff_active() and _buff_runs_left > 0:
		_buff_runs_left -= 1
		run_time_bonus += spot_run_bonus
		_run_bonus_pending = true
		queue_redraw()
	super()


func _on_run_finished() -> void:
	if _run_bonus_pending:
		_run_bonus_pending = false
		run_time_bonus -= spot_run_bonus


# ---------- HABILIDADE 1: OFF-BALL / ON THE LINE ----------

## No chão e sem bola próxima = Off-Ball; suspenso = On The Line
func get_move_variant() -> MoveVariant:
	if is_down:
		return MoveVariant.NONE
	if height_level == Heights.Level.GROUND:
		return MoveVariant.NONE if _ball_near() else MoveVariant.OFF_BALL
	if height_level == Heights.Level.SUSPENDED:
		return MoveVariant.ON_THE_LINE
	return MoveVariant.NONE


func _move_skill_name() -> String:
	return "On The Line" if get_move_variant() == MoveVariant.ON_THE_LINE else "Off-Ball"


func _ok_line_target(p: Player) -> bool:
	return not p.is_pass_blocked()


## Tem algum aliado ao alcance do passe do On The Line?
func _has_line_target(m: MatchManager) -> bool:
	for other: Player in m.get_team_players(team):
		if other != self and _ok_line_target(other) \
				and global_position.distance_to(other.global_position) <= line_pass_range:
			return true
	return false


func _use_move() -> bool:
	match get_move_variant():
		MoveVariant.OFF_BALL:
			return await _do_off_ball()
		MoveVariant.ON_THE_LINE:
			return await _do_on_the_line()
	return false


## Off-Ball: avanço curto; se esbarrar num inimigo, dá stun nele e ganha mais um avanço (1 vez)
func _do_off_ball() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var epoch: int = _epoch

	# Primeiro mira; cancelar não gasta a ação
	var aim: Vector2 = await m.aim_for_skill(self, dash_distance)
	if aim == Vector2.ZERO:
		return false
	if get_move_variant() != MoveVariant.OFF_BALL:   # a bola pode ter chegado perto enquanto ele mirava
		return false

	face_towards(aim)
	if not await play_action(&"off_ball"):
		return false
	var dir: Vector2 = aim.normalized()
	var dest: Vector2 = _clamp_to_pitch(global_position + dir * dash_distance)
	var hit: Object = await _dash_path(dest, dash_time, &"enemy")
	var enemy := hit as Player
	if epoch != _epoch:
		return false

	if enemy != null and is_instance_valid(enemy):
		# Stun (trava total: ações gerais e habilidades) e mais um avanço, na mesma direção
		enemy.apply_lock(self, stun_rounds)
		var dest2: Vector2 = _clamp_to_pitch(global_position + dir * dash_distance)
		await _dash_path(dest2, dash_time, &"")
		if epoch != _epoch:
			return false
	start_cooldown(CD_MOVE, move_cooldown)
	return true


## On The Line: escolhe o aliado, mira o avanço; se encontrar a bola, passe rasteiro para o aliado
func _do_on_the_line() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var epoch: int = _epoch

	# 1) Aliado (clique direito / Esc cancela e NÃO gasta a ação)
	var target: Player = await m.pick_ally_for_skill(self, line_pass_range, false,
		Callable(self, "_ok_line_target"))
	if target == null or not is_instance_valid(target):
		return false

	# 2) Mira do avanço (a escolha feita por último é a que vale no cancelamento)
	var aim: Vector2 = await m.aim_for_skill(self, dash_distance)
	if aim == Vector2.ZERO:
		return false
	if get_move_variant() != MoveVariant.ON_THE_LINE or not is_instance_valid(target):
		return false

	face_towards(aim)
	if not await play_action(&"on_the_line"):
		return false
	var dest: Vector2 = _clamp_to_pitch(global_position + aim.normalized() * dash_distance)
	var hit: Object = await _dash_path(dest, dash_time, &"ball")
	var ball := hit as Ball
	if epoch != _epoch:
		return false

	if ball != null and is_instance_valid(target):
		m.clear_pending_pass()   # se a bola era um passe alto em andamento, ele deixa de valer
		# curve_ratio 0 = reta; é o passe rasteiro normal, com a aura laranja e a animação própria
		await m.run_curved_ground_pass(self, target, ball, 0.0, 1.0, &"on_the_line", kick_fx)
		# Se o passe não saiu (alvo colado, por exemplo), a bola não fica presa
		if ball.hovering and not ball.is_held():
			ball.release_hover()
		if epoch != _epoch:
			return false
	start_cooldown(CD_MOVE, move_cooldown)
	return true


# ---------- HABILIDADE 2: BLIND SPOT ----------

func _use_spot() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false

	# Onde criar a área (clique direito / Esc cancela e NÃO gasta a ação)
	var point: Vector2 = await m.pick_point_for_skill(self, spot_range)
	if point == Vector2.INF:
		return false
	# Colada nele a área já valeria na hora: empurra para fora, para ele precisar "chegar lá"
	var away: Vector2 = point - global_position
	var min_dist: float = spot_radius + 20.0
	if away.length() < min_dist:
		var dir: Vector2 = away.normalized() if away.length() > 1.0 else Vector2(facing, 0.0)
		point = global_position + dir * min_dist
	point = _clamp_to_pitch(point)

	face_towards(point - global_position)
	if not await play_action(&"blind_spot"):
		return false
	_zone_point = point
	_zone_until_round = m.round_number + spot_rounds - 1   # a rodada atual conta
	start_cooldown(CD_SPOT, spot_cooldown)
	queue_redraw()
	return true


# ---------- HABILIDADE 3: MY GOAL ----------

## Naruhaya NO CHÃO e a bola no chão ou suspensa (ao alcance)
func _goal_kind(ball: Ball) -> KickType:
	if ball == null or is_down or height_level != Heights.Level.GROUND:
		return KickType.NONE
	var kind: KickType = get_kick_type(ball)   # já confere alcance, bola presa, etc.
	if kind == KickType.GROUND or kind == KickType.HIGH_BALL:
		return kind
	return KickType.NONE


func _use_goal() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or _goal_kind(_get_ball()) == KickType.NONE:
		return false

	# Primeiro mira; cancelar não gasta a ação nem o bônus do Blind Spot
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false

	# A bola pode ter rolado enquanto ele mirava: confere de novo
	var ball: Ball = _get_ball()
	var kind: KickType = _goal_kind(ball)
	if kind == KickType.NONE:
		return false

	var chance: float = goal_chance
	if _goal_bonus_active():
		chance += spot_goal_bonus
		_goal_bonus_ready = false   # o bônus vale para este chute
		queue_redraw()

	# QTE do chute comum: bola no chão = sem QTE; suspensa = com QTE
	var qte_ok: bool = true
	if kind != KickType.GROUND and not skips_qte():
		qte_ok = await m.run_qte(kind)

	# Errou o QTE = chute fraquinho, sem aura (e o kick_ball derruba o Naruhaya)
	await kick_ball(ball, aim, kind, qte_ok, chance, false,
		kick_fx if qte_ok else null, &"my_goal")
	start_cooldown(CD_GOAL, goal_cooldown)
	return true


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"id": SKILL_MOVE, "name": skill_label(_move_skill_name(), CD_MOVE)})
	var spot_name: String = "Blind Spot (área ativa)" if _zone_active() else skill_label("Blind Spot", CD_SPOT)
	list.append({"id": SKILL_SPOT, "name": spot_name})
	list.append({"id": SKILL_GOAL, "name": skill_label("My Goal", CD_GOAL)})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_MOVE:
			if is_on_cooldown(CD_MOVE):
				return false
			match get_move_variant():
				MoveVariant.OFF_BALL:
					return true
				MoveVariant.ON_THE_LINE:
					var m: MatchManager = _get_manager()
					return m != null and _has_line_target(m)
			return false
		SKILL_SPOT:
			return not is_on_cooldown(CD_SPOT) and not _zone_active()
		SKILL_GOAL:
			return not is_on_cooldown(CD_GOAL) and _goal_kind(_get_ball()) != KickType.NONE
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_MOVE:
			return await _use_move()
		SKILL_SPOT:
			return await _use_spot()
		SKILL_GOAL:
			return await _use_goal()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_MOVE:
			var off_text: String = "Sem bola próxima, Naruhaya no chão dá um avanço curto. Se encontrar um inimigo no caminho, dá stun nele e ganha mais um avanço (só uma vez)."
			var line_text: String = "Naruhaya suspenso escolhe um aliado e dá um avanço curto. Se encontrar a bola (suspensa ou no chão), dá um passe rasteiro (alcance %d) para o aliado." % int(line_pass_range)
			match get_move_variant():
				MoveVariant.OFF_BALL:
					title = "Off-Ball"
					text = off_text
				MoveVariant.ON_THE_LINE:
					title = "On The Line"
					text = line_text
				_:
					title = "Off-Ball / On The Line"
					text = off_text + "\n" + line_text
			text += "\nRecarga: %d rodadas." % move_cooldown
		SKILL_SPOT:
			title = "Blind Spot"
			text = "Cria uma pequena área perto de Naruhaya. Se ele chegar lá, ganha +%.1f s nas próximas %d ações de Correr e +%d%% no My Goal.\nRecarga: %d rodadas." % [
				spot_run_bonus, spot_run_actions, _pct(spot_goal_bonus), spot_cooldown]
		SKILL_GOAL:
			title = "My Goal"
			text = "Chute comum com mira (QTE só com a bola suspensa). Naruhaya precisa estar no chão; a bola no chão ou suspensa. %d%% de chance de gol.\nRecarga: %d rodadas." % [
				_pct(goal_chance), goal_cooldown]
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	_epoch += 1   # avanços/passes que estavam esperando desistem
	super()
	_zone_until_round = -1
	_buff_until_round = -1
	_buff_runs_left = 0
	_goal_bonus_ready = false
	_run_bonus_pending = false
	queue_redraw()


# ---------- LOOP / VISUAL ----------

func _process(delta: float) -> void:
	super(delta)
	if _zone_until_round >= 0:
		queue_redraw()   # a área é desenhada em coordenadas do campo: acompanha o movimento dele


func _draw() -> void:
	super()
	var center := Vector2(0.0, -height)

	# A área do Blind Spot, no chão: elipse laranja suja com borda marrom
	if _zone_active():
		var z: Vector2 = to_local(_zone_point)
		draw_set_transform(z, 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, spot_radius, Color(DIRTY_ORANGE, 0.25))
		draw_arc(Vector2.ZERO, spot_radius, 0.0, TAU, 40, Color(BROWN, 0.9), 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Anel laranja sujo com fio marrom enquanto o bônus do Blind Spot está valendo
	if _buff_active() and (_buff_runs_left > 0 or _goal_bonus_ready):
		draw_arc(center, placeholder_radius + 10.0, 0.0, TAU, 40, Color(DIRTY_ORANGE, 0.95), 3.0)
		draw_arc(center, placeholder_radius + 13.0, 0.0, TAU, 40, Color(BROWN, 0.85), 1.5)
