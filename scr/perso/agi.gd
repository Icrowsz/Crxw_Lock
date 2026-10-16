class_name Agi
extends Player
## Agi. Herda tudo do Player (ações gerais) e adiciona 3 habilidades. Tudo é marrom claro.
##
## 1. Doctor (ação de habilidade; recarga de 3 rodadas):
##      Agi escolhe um aliado (alcance 500) e o "cura":
##        - as recargas dele diminuem 1 rodada;
##        - +5% de chance de gol nos próximos 2 chutes dele;
##        - mais velocidade no próximo Correr dele.
##
## 2. Flick Pass (ação de habilidade; recarga de 2 rodadas, compartilhada com a variante):
##      Bola próxima, no chão ou suspensa -> passe de até 520 de alcance para um aliado.
##        - aliado a até 300 de distância: o passe vai rasteiro;
##        - mais longe que isso: a bola sobe até Voando e desce nos pés do aliado.
##    Aerial Dominance (variante, mesmo botão): bola próxima Voando -> Agi salta até ela e faz
##      um passe que vai Voando até o aliado (mesmo alcance; funciona como o passe alto comum).
##      Agi desce até o chão no fim da habilidade.
##
## 3. Long Reach (ação de habilidade; recarga de 2 rodadas):
##      Bola a até 200: Agi a puxa para si, joga para cima (Voando), salta e dá um cabeceio
##      (mirado) com 45% de chance de gol. Se a bola já está Voando, ele a alcança até 250
##      de distância e cabeceia direto. O cabeceio usa QTE (igual aos outros chutes aéreos).
##
## Como montar a cena: Nova Cena Herdada de player.tscn -> anexe este script ao nó raiz
## -> renomeie o nó raiz para "Agi".
##
## Animações opcionais (se faltar alguma, o jogo só pula): doctor, flick_pass (só no passe
## que sobe), aerial_dominance, long_reach. O passe rasteiro do Flick Pass usa a "pass".
##
## Não precisa de nenhum gancho novo no match_manager.gd nem no player.gd.
## Agi entra no grupo "control_sources" para dar a velocidade do Doctor (run_speed_mult_on)
## e para contar os chutes que o Doctor melhora (on_opponent_shot_attempt).

const SKILL_DOCTOR: StringName = &"doctor"
const SKILL_FLICK: StringName = &"flick_pass"      # também é o id do Aerial Dominance (variante)
const SKILL_REACH: StringName = &"long_reach"

## Grupos de recarga (as duas variantes do passe compartilham o mesmo)
const CD_DOCTOR: StringName = &"cd_doctor"
const CD_FLICK: StringName = &"cd_flick"
const CD_REACH: StringName = &"cd_reach"

enum FlickVariant { NONE, FLICK, DOMINANCE }

const BROWN := Color(0.78, 0.6, 0.38)

@export_group("Doctor")
@export var doctor_cooldown: int = 3
@export var doctor_range: float = 500.0
@export var doctor_cooldown_cut: int = 1                         # rodadas tiradas das recargas do aliado
@export_range(0.0, 1.0) var doctor_shot_bonus: float = 0.05      # +5% de chance de gol
@export var doctor_shot_count: int = 2                           # quantos chutes recebem o bônus
@export var doctor_run_speed_mult: float = 1.4                   # velocidade do próximo Correr

@export_group("Flick Pass / Aerial Dominance")
@export var flick_cooldown: int = 2
@export var flick_range: float = 520.0                           # alcance do passe (as duas variantes)
@export var flick_ground_distance: float = 300.0                 # até aqui o passe vai rasteiro
@export var flick_rise_time: float = 0.45                        # passe que sobe: tempo até Voando
@export var flick_fall_time: float = 0.45                        # passe que sobe: tempo da descida
@export var dominance_reach: float = 250.0                       # Aerial Dominance: o quanto longe ele alcança a bola
@export var dominance_jump_time: float = 0.3

@export_group("Long Reach")
@export var reach_cooldown: int = 2
@export var reach_range: float = 200.0                           # bola no chão ou suspensa
@export var reach_range_flying: float = 250.0                    # bola já Voando
@export_range(0.0, 1.0) var reach_header_chance: float = 0.45    # chance de gol do cabeceio
@export var reach_pull_time: float = 0.2
@export var reach_toss_time: float = 0.3
@export var reach_jump_time: float = 0.3
@export var reach_qte: bool = true                               # false = cabeceio sem QTE

@export_group("Visual do chute")
## Aura + partículas dos chutes/passes de habilidade. Vazio = usa o estilo padrão (veja _make_kick_fx)
@export var kick_fx: KickFX

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: doctor, flick_pass, long_reach.
## Sem imagem, o balão aparece só com o texto.
@export var skill_icons: Dictionary = {}

## Doctor: aliados com chutes ainda melhorados (Player -> chutes restantes)
var _shots_left: Dictionary = {}
## Doctor: aliados com a velocidade extra esperando o próximo Correr (Player -> true)
var _run_buffs: Dictionary = {}


func _init() -> void:
	character_id = "agi"   # o menu de formação usa isto para saber quem é quem
	display_name = "Agi"


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = _make_kick_fx()
	add_to_group("control_sources")


## Marrom claro; as partículas são poeirinha dourada que sobe
func _make_kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = BROWN
	fx.trail_width = 14.0
	fx.particle_color = Color(0.95, 0.82, 0.6)
	fx.amount = 20
	fx.lifetime = 0.5
	fx.speed_min = 15.0
	fx.speed_max = 70.0
	fx.gravity = Vector2(0.0, -50.0)
	fx.spin = 200.0
	fx.scale_min = 0.12
	fx.scale_max = 0.28
	fx.burst_amount = 14
	fx.burst_speed = 210.0
	return fx


func _allies() -> Array[Player]:
	var found: Array[Player] = []
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p != self and p.team == team:
			found.append(p)
	return found


## Aliado que pode receber o passe (ex: o Ace Eater do Lorenzo bloqueia passes para alguém)
func _can_receive(p: Player) -> bool:
	return not p.is_pass_blocked()


func _has_ally_in_range(range_px: float, only_receivers: bool) -> bool:
	for p: Player in _allies():
		if only_receivers and not _can_receive(p):
			continue
		if global_position.distance_to(p.global_position) <= range_px:
			return true
	return false


# ---------- HABILIDADE 1: DOCTOR ----------

func _use_doctor() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	# Escolha do aliado (cancelou = não gasta nem começa a recarga)
	var ally: Player = await m.pick_ally_for_skill(self, doctor_range)
	if ally == null:
		return false
	face_towards(ally.global_position - global_position)
	if not await play_action(&"doctor"):
		return false   # ação cancelada (ex: a partida reiniciou)
	if not is_instance_valid(ally):
		return false

	# 1) Recargas dele diminuem
	ally.reduce_cooldowns(99, doctor_cooldown_cut)
	# 2) +5% nos próximos chutes (o primeiro entra já; o segundo é renovado em on_opponent_shot_attempt)
	ally.next_shot_bonus = maxf(ally.next_shot_bonus, doctor_shot_bonus)
	_shots_left[ally] = doctor_shot_count
	# 3) Mais velocidade no próximo Correr (acaba quando esse Correr termina)
	if not _run_buffs.has(ally):
		ally.run_finished.connect(_on_buffed_run_finished.bind(ally), CONNECT_ONE_SHOT)
	_run_buffs[ally] = true

	start_cooldown(CD_DOCTOR, doctor_cooldown)
	queue_redraw()
	return true


## Velocidade extra do Doctor (o Player consulta isto a cada frame do Correr)
func run_speed_mult_on(p: Player) -> float:
	return doctor_run_speed_mult if _run_buffs.has(p) else 1.0


func _on_buffed_run_finished(p: Player) -> void:
	_run_buffs.erase(p)
	queue_redraw()


## A bola avisa a cada chute com chance de gol (de qualquer jogador). Quando um aliado curado
## chuta, o bônus dele já foi gasto: se ainda sobram chutes, o bônus volta para o próximo.
func on_opponent_shot_attempt(shooter: Player) -> void:
	if not _shots_left.has(shooter):
		return
	var left: int = int(_shots_left[shooter]) - 1
	if left <= 0 or not is_instance_valid(shooter):
		_shots_left.erase(shooter)
	else:
		_shots_left[shooter] = left
		shooter.next_shot_bonus = maxf(shooter.next_shot_bonus, doctor_shot_bonus)
	queue_redraw()


# ---------- HABILIDADE 2: FLICK PASS / AERIAL DOMINANCE ----------

func get_flick_variant() -> FlickVariant:
	var ball: Ball = _get_ball()
	if ball == null or is_down or ball.is_held() or ball.is_locked_for(team):
		return FlickVariant.NONE
	var level: Heights.Level = ball.get_level()
	if level == Heights.Level.FLYING:
		var near: bool = global_position.distance_to(ball.global_position) <= dominance_reach
		return FlickVariant.DOMINANCE if near and height_level != Heights.Level.FLYING else FlickVariant.NONE
	# Bola próxima no chão ou suspensa (mesma conta do chute: distância e altura alcançável)
	return FlickVariant.FLICK if get_kick_type(ball) != KickType.NONE else FlickVariant.NONE


func _flick_skill_name() -> String:
	return "Aerial Dominance" if get_flick_variant() == FlickVariant.DOMINANCE else "Flick Pass"


func _flick_total_range() -> float:
	return flick_range + pass_range_bonus


func _flick_usable() -> bool:
	return get_flick_variant() != FlickVariant.NONE and _has_ally_in_range(_flick_total_range(), true)


func _use_flick_skill() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var variant: FlickVariant = get_flick_variant()
	if variant == FlickVariant.NONE:
		return false

	var target: Player = await m.pick_ally_for_skill(self, _flick_total_range(), false,
		Callable(self, "_can_receive"))
	if target == null:
		return false   # cancelou: não gasta a ação

	# A bola pode ter rolado enquanto ele escolhia o alvo
	if get_flick_variant() != variant:
		return false

	if variant == FlickVariant.DOMINANCE:
		await _run_dominance(m, target)
	elif global_position.distance_to(target.global_position) <= flick_ground_distance:
		await m.run_ground_pass(self, target, _get_ball())   # passe rasteiro comum
	else:
		if not await _run_lob(m, target):
			return false
	start_cooldown(CD_FLICK, flick_cooldown)
	return true


## Passe longo: a bola sobe até Voando no meio do caminho e desce NO CHÃO, encostando no aliado
func _run_lob(m: MatchManager, target: Player) -> bool:
	var ball: Ball = _get_ball()
	m.clear_pending_pass()   # se era um passe alto pairando, ele deixa de ser acompanhado
	face_towards(target.global_position - global_position)
	if not await play_action(&"flick_pass", ANIM_PASS_HIGH):
		return false   # ação cancelada (ex: a partida reiniciou)

	ball.register_touch(self)   # o passe alto não usa kick(), então registra o toque aqui
	if kick_fx:
		ball.fx_during_hover = true   # mantém a aura enquanto a bola paira
		ball.play_fx(kick_fx)

	var start: Vector2 = ball.global_position
	var to_target: Vector2 = target.global_position - start
	var dist: float = to_target.length()
	var gap: float = ball.collision_radius + target.body_radius + 2.0   # a bola para ENCOSTANDO no alvo
	var end_point: Vector2 = start
	if dist > 0.001:
		end_point = start + to_target / dist * maxf(dist - gap, 0.0)

	var rise: Tween = ball.hover_to((start + end_point) * 0.5, Heights.FLYING_HEIGHT, flick_rise_time)
	await rise.finished
	var fall: Tween = ball.hover_to(end_point, Heights.GROUND_HEIGHT, flick_fall_time)
	await fall.finished

	ball.release_hover()
	ball.velocity = Vector2.ZERO
	ball.vel_z = 0.0
	ball.height = 0.0
	ball.fx_during_hover = false
	ball.register_touch(self)   # também encerra a aura
	m.pass_completed.emit(self, target)
	return true


## Aerial Dominance: salta até a bola Voando, passe alto de habilidade (a bola segue Voando até o
## aliado, como no passe alto comum) e Agi desce até o chão.
func _run_dominance(m: MatchManager, target: Player) -> void:
	var ball: Ball = _get_ball()
	m.clear_pending_pass()
	face_towards(ball.global_position - global_position)

	# Congela a bola no lugar e salta até ela
	ball.hover_to(ball.global_position, ball.height, dominance_jump_time)
	var gap: float = body_radius + ball.collision_radius + 2.0
	var to_ball: Vector2 = ball.global_position - global_position
	var reach_pos: Vector2 = global_position
	if to_ball.length() > gap:
		reach_pos = ball.global_position - to_ball.normalized() * gap
	height_level = Heights.Level.FLYING
	var jump: Tween = create_tween().set_parallel(true)
	jump.tween_property(self, "global_position", reach_pos, dominance_jump_time)
	jump.tween_property(self, "height", Heights.FLYING_HEIGHT, dominance_jump_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await jump.finished

	await m.run_skill_high_pass(self, target, ball, _flick_total_range(), &"aerial_dominance", kick_fx)
	await _land_now()


## Desce até o chão e espera a descida terminar
func _land_now() -> void:
	land()
	await get_tree().create_timer(land_time).timeout


# ---------- HABILIDADE 3: LONG REACH ----------

func _reach_possible() -> bool:
	var ball: Ball = _get_ball()
	if ball == null or is_down or ball.is_held() or ball.is_locked_for(team) \
			or height_level == Heights.Level.FLYING:
		return false
	var d: float = global_position.distance_to(ball.global_position)
	if ball.get_level() == Heights.Level.FLYING:
		return d <= reach_range_flying
	return d <= reach_range


func _use_long_reach() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or not _reach_possible():
		return false
	# Mira (cancelou = não gasta a ação nem a recarga)
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false
	# A bola pode ter rolado enquanto ele mirava
	if not _reach_possible():
		return false

	var ball: Ball = _get_ball()
	m.clear_pending_pass()
	face_towards(aim)
	var already_flying: bool = ball.get_level() == Heights.Level.FLYING
	if not await play_action(&"long_reach"):
		return false   # ação cancelada (ex: a partida reiniciou)

	var gap: float = body_radius + ball.collision_radius + 2.0
	var reach_pos: Vector2 = global_position
	if already_flying:
		# Bola já no ar: congela no lugar e vai até ela
		ball.hover_to(ball.global_position, ball.height, reach_jump_time)
		var to_ball: Vector2 = ball.global_position - global_position
		if to_ball.length() > gap:
			reach_pos = ball.global_position - to_ball.normalized() * gap
	else:
		# Puxa a bola para si e joga para cima, até Voando
		ball.register_touch(self)
		var hold_point: Vector2 = global_position + Vector2(facing, 0.0) * gap
		await ball.hover_to(hold_point, ball.height, reach_pull_time).finished
		await ball.hover_to(hold_point, Heights.FLYING_HEIGHT, reach_toss_time).finished

	# Salta até a altura da bola
	height_level = Heights.Level.FLYING
	var jump: Tween = create_tween().set_parallel(true)
	jump.tween_property(self, "height", Heights.FLYING_HEIGHT, reach_jump_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if already_flying:
		jump.tween_property(self, "global_position", reach_pos, reach_jump_time)
	await jump.finished

	# Cabeceio: QTE como nos outros chutes aéreos; errou = chute fraco, desviado e sem aura
	var qte_ok: bool = true
	if reach_qte and not skips_qte():
		qte_ok = await m.run_qte(KickType.FLYING)
	await kick_ball(ball, aim, KickType.FLYING, qte_ok, reach_header_chance, false,
		kick_fx if qte_ok else null, &"long_reach")

	await _land_now()
	start_cooldown(CD_REACH, reach_cooldown)
	return true


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"id": SKILL_DOCTOR, "name": skill_label("Doctor", CD_DOCTOR)})
	list.append({"id": SKILL_FLICK, "name": skill_label(_flick_skill_name(), CD_FLICK)})
	list.append({"id": SKILL_REACH, "name": skill_label("Long Reach", CD_REACH)})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_DOCTOR:
			return not is_on_cooldown(CD_DOCTOR) and _has_ally_in_range(doctor_range, false)
		SKILL_FLICK:
			return not is_on_cooldown(CD_FLICK) and _flick_usable()
		SKILL_REACH:
			return not is_on_cooldown(CD_REACH) and _reach_possible()
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_DOCTOR:
			return await _use_doctor()
		SKILL_FLICK:
			return await _use_flick_skill()
		SKILL_REACH:
			return await _use_long_reach()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_DOCTOR:
			title = "Doctor"
			text = ("Cura um aliado: as recargas dele diminuem %d rodada, +%d%% de chance de gol nos próximos %d chutes e mais velocidade no próximo Correr.\n"
				+ "Recarga: %d rodadas.") % [
				doctor_cooldown_cut, _pct(doctor_shot_bonus), doctor_shot_count, doctor_cooldown]
		SKILL_FLICK:
			var flick_text: String = "Passe para um aliado: rasteiro até %d de distância; mais longe, a bola sobe e desce nos pés dele." % int(flick_ground_distance)
			var dom_text: String = "Salta até a bola no ar e faz um passe voando até o aliado."
			match get_flick_variant():
				FlickVariant.FLICK:
					title = "Flick Pass"
					text = flick_text
				FlickVariant.DOMINANCE:
					title = "Aerial Dominance"
					text = dom_text
				_:
					title = "Flick Pass / Aerial Dominance"
					text = "Passe para um aliado (alcance %d). Com a bola voando, vira um salto com passe aéreo." % int(flick_range)
			text += "\nRecarga: %d rodadas." % flick_cooldown
		SKILL_REACH:
			title = "Long Reach"
			text = ("Puxa a bola (até %d de distância), joga para cima, salta e cabeceia com mira e %d%% de chance de gol. Com a bola já voando, alcança até %d.\n"
				+ "Recarga: %d rodadas.") % [
				int(reach_range), _pct(reach_header_chance), int(reach_range_flying), reach_cooldown]
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()
	_shots_left.clear()   # o Player já zera o next_shot_bonus dele
	_run_buffs.clear()
	queue_redraw()


# ---------- VISUAL ----------

func _process(delta: float) -> void:
	super(delta)
	# Os anéis do Doctor acompanham os aliados curados: redesenha enquanto existirem
	if not _shots_left.is_empty() or not _run_buffs.is_empty():
		queue_redraw()


func _draw() -> void:
	super()
	# Anel marrom claro em cada aliado que ainda tem efeito do Doctor
	var marked: Dictionary = {}
	for key in _shots_left.keys():
		marked[key] = true
	for key in _run_buffs.keys():
		marked[key] = true
	for key in marked.keys():
		var p: Player = key as Player
		if is_instance_valid(p):
			draw_arc(to_local(p.global_position) + Vector2(0.0, -p.height),
				p.placeholder_radius + 11.0, 0.0, TAU, 32, Color(BROWN, 0.85), 2.0)
