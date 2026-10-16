class_name Teddy
extends Player
## Teddy. Herda tudo do Player (ações gerais) e adiciona as habilidades próprias.
## Só este arquivo foi criado: nenhum outro script precisa ser alterado.
##
## 1. Rainbow Cuts (habilidade; 4 avanços; recarga 2 rodadas, compartilhada com o complemento):
##      Teddy NO CHÃO escolhe uma direção, avança uma distância curta e repete até acabarem os
##      avanços. Cada encontro com um inimigo NO CHÃO faz ele dar um passo para trás e ganhar mais
##      um avanço, só que mais LONGO. Se estiver/encontrar a bola no chão, ela gruda nele durante
##      a sequência. Se terminar todos os avanços, ganha o complemento gratuito "Without Ego".
##      (Cancelar a mira no meio encerra a sequência e NÃO dá o complemento.)
## 1b. Without Ego (complemento, não gasta ação, só neste turno): chute forte que sobe ao nível
##      Suspenso e faz uma leve curva para a esquerda.
## 2. Skill de variantes automáticas (recarga 2 rodadas, compartilhada):
##      - Bola PRÓXIMA                 -> Manipulable Array: escolhe um aliado e passa a bola na hora
##        (rasteiro). O aliado ganha a MESMA habilidade para devolver; cada devolução dobra o bônus.
##        Dura 3 rodadas; cada rodada mantida dá +3% no próximo chute de quem estiver com a bola.
##        Aliado FORA da ligação que tocar na bola recebe o bônus e a ligação acaba.
##        Funciona igual ao Sharp Sharp do Kurona (motor em one_two_link.gd).
##      - Bola longe + Teddy no CHÃO   -> Knight Pierce: vai até um inimigo; ele fica sem Chutar
##        e com o Correr mais lento até o fim da próxima rodada.
##      - Bola longe + Teddy SUSPENSO  -> En Garde: dash aéreo; se cruzar com a bola, dá um Deflect.
## 3. His Eyes (habilidade; 3 rodadas; recarga 2 rodadas depois do fim do efeito):
##      +velocidade no Correr, Carrinho mais longo, +6% em qualquer chute.
##      Rainbow Cuts ganha +1 avanço; Without Ego sobe ao nível Voando; o bônus do Manipulable
##      Array passa a ser +5% por rodada.
##
## Visual: o personagem deve ser desenhado branco/platinado; o rastro arco-íris é criado aqui
## por código (Line2D) e some sozinho quando ele para.
##
## Animações opcionais (a SpriteFrames pode ter qualquer uma; as que faltarem são puladas):
##   rainbow_cut, without_ego, manipulable_array, knight_pierce, en_garde, his_eyes
##
## Como montar a cena: Nova Cena Herdada de player.tscn -> anexe este script ao nó raiz
## -> renomeie o nó raiz para "Teddy". Se o menu de formação tiver uma lista de
## personagens, cadastre o character_id "teddy" lá (não vi esse arquivo).

const SKILL_CUTS: StringName = &"rainbow_cuts"
const SKILL_EGO: StringName = &"without_ego"
const SKILL_ARRAY: StringName = &"manipulable_array"   # também Knight Pierce / En Garde
const SKILL_EYES: StringName = &"his_eyes"

## Grupos de recarga
const CD_CUTS: StringName = &"cd_cuts"      # Rainbow Cuts + Without Ego
const CD_ARRAY: StringName = &"cd_array"    # Manipulable Array + Knight Pierce + En Garde
const CD_EYES: StringName = &"cd_eyes"

enum ArrayVariant { NONE, ARRAY, PIERCE, GUARD }

@export_group("Rainbow Cuts")
@export var cuts_charges: int = 4
@export var cuts_short_distance: float = 130.0
@export var cuts_long_distance: float = 260.0
@export var cuts_short_time: float = 0.16
@export var cuts_long_time: float = 0.22
@export var cuts_step_back: float = 45.0
@export var cuts_cooldown: int = 2

@export_group("Without Ego")
@export_range(0.0, 1.0) var chance_ego: float = 0.45
@export var ego_force_mult: float = 1.2
@export var curve_deg_per_sec: float = 35.0   # curva para a esquerda (leve): 35 x 0,9 s = ~31 graus no total
@export var curve_duration: float = 0.9

@export_group("Manipulable Array")
@export var array_range: float = 450.0
@export_range(0.0, 1.0) var array_bonus: float = 0.03
@export var array_cooldown: int = 2
@export var array_duration: int = 3                     # rodadas de duração (a atual conta)
@export var array_ally_access_rounds: int = 3           # por quantas rodadas o aliado tem a habilidade
@export var array_return_mult: float = 2.0              # a devolução do aliado multiplica o bônus
@export_range(0.0, 1.0) var array_outside_ratio: float = 1.0   # aliado de fora recebe esta fração do bônus
@export var array_keep_range: float = 120.0             # "perto da bola" (px)

@export_group("Knight Pierce")
@export var pierce_range: float = 200.0
@export var pierce_dash_time: float = 0.2
@export var pierce_rounds: int = 2                      # contando a rodada atual
@export_range(0.1, 1.0) var pierce_run_speed_mult: float = 0.5

@export_group("En Garde")
@export var guard_dash_distance: float = 230.0
@export var guard_dash_time: float = 0.25
@export var guard_hit_radius: float = 55.0
@export var deflect_power: float = 500.0
@export var deflect_lift: float = 250.0
@export_range(0.0, 1.0) var deflect_chance: float = 0.30

@export_group("His Eyes")
@export var eyes_rounds: int = 3                        # duração total (contando a atual)
@export var eyes_cooldown: int = 2                      # recarga, a partir do fim do efeito
@export var eyes_extra_cuts: int = 1
@export_range(0.0, 1.0) var eyes_shot_bonus: float = 0.06
@export var eyes_run_bonus: float = 0.35                # +35% de velocidade no Correr
@export var eyes_slide_bonus: float = 0.25              # +25% de distância no Carrinho
@export_range(0.0, 1.0) var eyes_array_bonus: float = 0.05

@export_group("Rastro arco-íris")
@export var trail_max_points: int = 26
@export var trail_width: float = 14.0

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: rainbow_cuts, without_ego,
## manipulable_array, his_eyes. Sem imagem, o balão aparece só com o texto.
@export var skill_icons: Dictionary = {}

# Rainbow Cuts / Without Ego
var _ego_ready: bool = false
var _carried: Ball = null
var _carry_dir: Vector2 = Vector2.RIGHT
var _dashing: bool = false

# Manipulable Array (motor compartilhado com o Sharp Sharp do Kurona: one_two_link.gd)
var _link: OneTwoLink

# Knight Pierce
var _pierce_target: Player = null
var _pierce_until: int = -1

# His Eyes
var _eyes_until: int = -1
var _base_slide: float = 0.0

var _trail: Line2D


func _init() -> void:
	character_id = "teddy"
	display_name = "Teddy"


func _ready() -> void:
	super()
	add_to_group("control_sources")   # Knight Pierce age sobre inimigos por este grupo
	_base_slide = slide_distance
	_build_trail()
	_build_link()
	_hook_manager.call_deferred()


func _exit_tree() -> void:
	_release_ball()
	if _link != null:
		_link.clear()


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m:
		m.round_started.connect(_on_round_started)
		m.turn_ended.connect(_on_turn_ended)
		m.goal_scored.connect(_on_goal_scored)


func _on_round_started(round_number: int) -> void:
	_apply_eyes_state()
	_link.on_round_started(round_number)
	queue_redraw()


## O complemento Without Ego só vale no turno em que o Rainbow Cuts terminou
func _on_turn_ended(team_ended: int) -> void:
	if team_ended == team:
		_ego_ready = false
	_link.on_turn_ended(team_ended)


## Gol: todo mundo volta para a formação, então o 1-2 se desfaz
func _on_goal_scored(_goal: Dictionary) -> void:
	_link.on_goal()


## Valores do Manipulable Array no motor do 1-2 (o Kurona usa o mesmo motor com valores dele)
func _build_link() -> void:
	_link = OneTwoLink.new(self)
	_link.skill_id = SKILL_ARRAY
	_link.skill_name = "Manipulable Array"
	_link.cooldown_group = CD_ARRAY
	_link.cooldown_rounds = array_cooldown
	_link.pass_range = array_range
	_link.animation = &"manipulable_array"
	_link.color = Color(1.0, 1.0, 1.0, 0.6)
	_link.icon = skill_icons.get(String(SKILL_ARRAY), null) as Texture2D
	_link.ally_ground_only = false
	_link.duration_rounds = array_duration
	_link.ally_access_rounds = array_ally_access_rounds
	_link.return_multiplier = array_return_mult
	_link.outside_ratio = array_outside_ratio
	_link.keep_range = array_keep_range
	_link.per_round = func() -> float: return eyes_array_bonus if is_eyes_active() else array_bonus


# ---------- RASTRO ARCO-ÍRIS ----------

func _build_trail() -> void:
	_trail = Line2D.new()
	_trail.top_level = true   # pontos em coordenadas globais
	_trail.width = trail_width
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.round_precision = 4
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(1.0, 1.0))
	_trail.width_curve = curve
	var g := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in 7:
		offsets.append(float(i) / 6.0)
		colors.append(Color.from_hsv(float(i) / 7.0, 0.65, 1.0, 0.9))
	g.offsets = offsets
	g.colors = colors
	_trail.gradient = g
	add_child(_trail)
	move_child(_trail, 0)


func _update_trail() -> void:
	if _trail == null:
		return
	_trail.width = trail_width * (1.5 if is_eyes_active() else 1.0)
	var moving: bool = _dashing or state != State.IDLE
	if moving:
		var pt: Vector2 = global_position + Vector2(0.0, -height - 10.0)
		var n: int = _trail.get_point_count()
		if n == 0 or _trail.get_point_position(n - 1).distance_to(pt) > 5.0:
			_trail.add_point(pt)
		while _trail.get_point_count() > trail_max_points:
			_trail.remove_point(0)
	elif _trail.get_point_count() > 0:
		_trail.remove_point(0)   # a cauda vai sendo "comida" até sumir


## Aura/partículas dos chutes: branco com um tom de arco-íris diferente a cada chute
func _make_kick_fx() -> KickFX:
	var hue: float = randf()
	var fx := KickFX.new()
	fx.color = Color.from_hsv(hue, 0.45, 1.0)
	fx.trail_width = 14.0
	fx.particle_color = Color.from_hsv(fmod(hue + 0.3, 1.0), 0.35, 1.0)
	fx.amount = 22
	fx.lifetime = 0.55
	fx.speed_min = 15.0
	fx.speed_max = 70.0
	fx.gravity = Vector2(0.0, -40.0)
	fx.spin = 240.0
	fx.scale_min = 0.15
	fx.scale_max = 0.35
	fx.burst_amount = 14
	fx.burst_speed = 220.0
	return fx


# ---------- MOVIMENTO / DASH ----------

func _clamp_to_field(pos: Vector2) -> Vector2:
	var f := get_tree().get_first_node_in_group("field") as Field
	if f == null:
		return pos
	var half: Vector2 = f.pitch_size * 0.5 - Vector2(body_radius, body_radius)
	var l: Vector2 = f.to_local(pos)
	l.x = clampf(l.x, -half.x, half.x)
	l.y = clampf(l.y, -half.y, half.y)
	return f.to_global(l)


## Avança "dist" px na direção dir em "duration" s, passando por cima de tudo.
## cut_mode = true: para no primeiro inimigo no chão que encostar (devolvido) e gruda a bola
## que estiver no chão pelo caminho. hit = inimigos que já foram encontrados nesta habilidade.
func _dash(dir: Vector2, dist: float, duration: float, hit: Array = [],
		cut_mode: bool = false, turn: bool = true) -> Player:
	var d: Vector2 = dir.normalized()
	if turn:
		face_towards(d)   # turn = false: anda sem virar o personagem (passo para trás)
	if cut_mode:
		_carry_dir = d
	var found: Player = null
	_dashing = true
	var speed: float = dist / maxf(duration, 0.01)
	var travelled: float = 0.0
	while travelled < dist:
		await get_tree().physics_frame
		var step: float = minf(speed * get_physics_process_delta_time(), dist - travelled)
		global_position = _clamp_to_field(global_position + d * step)
		travelled += step
		if cut_mode:
			_try_grab(_get_ball())
			found = _find_enemy_contact(hit)
			if found != null:
				break
	_dashing = false
	return found


func _find_enemy_contact(hit: Array) -> Player:
	for o: Player in get_tree().get_nodes_in_group("players"):
		if o.team == team or o.is_down or o in hit:
			continue
		if o.height_level != Heights.Level.GROUND or o.slide_immune:
			continue
		if global_position.distance_to(o.global_position) <= body_radius + o.body_radius + 8.0:
			return o
	return null


# ---------- BOLA GRUDADA (Rainbow Cuts) ----------

func _try_grab(ball: Ball) -> void:
	if _carried != null or ball == null or ball.is_held() or ball.is_locked_for(team):
		return
	if ball.get_level() != Heights.Level.GROUND:
		return
	if global_position.distance_to(ball.global_position) > ball.collision_radius + body_radius + 14.0:
		return
	_carried = ball
	ball.register_touch(self)
	ball.collisions_paused = true
	ball.velocity = Vector2.ZERO
	ball.height = 0.0
	ball.vel_z = 0.0
	ball.pending_shot_chance = Ball.NO_SHOT


func _carry_update() -> void:
	if _carried == null or not is_instance_valid(_carried):
		_carried = null
		return
	_carried.velocity = Vector2.ZERO
	_carried.global_position = global_position + _carry_dir * (body_radius + _carried.collision_radius + 2.0)


## Solta a bola ao lado do Teddy, parada e voltando a colidir normalmente
func _release_ball() -> void:
	if _carried != null and is_instance_valid(_carried):
		_carried.global_position = global_position + _carry_dir * (body_radius + _carried.collision_radius + 2.0)
		_carried.velocity = Vector2.ZERO
		_carried.collisions_paused = false
	_carried = null


# ---------- RAINBOW CUTS ----------

func _use_cuts() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or height_level != Heights.Level.GROUND:
		return false

	var remaining: int = cuts_charges + (eyes_extra_cuts if is_eyes_active() else 0)
	var long_pending: int = 0
	var first: bool = true
	var cancelled: bool = false
	var hit: Array = []

	_carry_dir = Vector2(facing, 0.0)
	_try_grab(_get_ball())   # já estava com a bola no chão: ela gruda de cara

	while remaining > 0 or long_pending > 0:
		var is_long: bool = long_pending > 0
		var dist: float = cuts_long_distance if is_long else cuts_short_distance
		var aim: Vector2 = await m.aim_for_skill(self, dist)
		if m.match_over:
			_release_ball()
			return true
		if aim == Vector2.ZERO:
			if first:
				_release_ball()
				return false   # cancelou logo de cara: não gasta a ação
			cancelled = true
			break
		first = false
		if is_long:
			long_pending -= 1
		else:
			remaining -= 1

		if not await play_action(&"rainbow_cut"):
			_release_ball()
			return false
		var foe: Player = await _dash(aim, dist,
			cuts_long_time if is_long else cuts_short_time, hit, true)
		if m.match_over:
			_release_ball()
			return true
		if foe != null:
			hit.append(foe)
			await _dash(-aim, cuts_step_back, 0.12, [], false, false)   # passo para trás, sem virar de costas
			long_pending += 1                                     # ganha um avanço mais longo

	_release_ball()
	start_cooldown(CD_CUTS, cuts_cooldown)
	if cancelled:
		# A última mira foi cancelada, mas a sequência JÁ aconteceu: o MatchManager não pode
		# devolver a ação nem a recarga por causa disso
		m._skill_pick_cancelled = false
	else:
		_ego_ready = true   # terminou todos os avanços: ganha o complemento
	return true


# ---------- WITHOUT EGO ----------

func _use_ego() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or not _ego_ready or get_kick_type(_get_ball()) == KickType.NONE:
		return false
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false
	var ball: Ball = _get_ball()
	if get_kick_type(ball) == KickType.NONE:
		return false   # a bola saiu do alcance enquanto ele mirava

	var old_peak: Heights.Level = volley_peak_level
	volley_peak_level = Heights.Level.FLYING if is_eyes_active() else Heights.Level.SUSPENDED
	next_kick_force_mult *= ego_force_mult
	var chance: float = minf(chance_ego + _eyes_shot_bonus(), 1.0)
	await kick_ball(ball, aim, KickType.VOLLEY, true, chance, false,
		_make_kick_fx(), &"without_ego", _curve_ball)
	volley_peak_level = old_peak
	_ego_ready = false
	return true


## Chamado pelo kick_ball logo depois que a bola sai: vira a trajetória levemente para a esquerda
func _curve_ball(ball: Ball, _dir: Vector2, _speed: float) -> void:
	var touches: int = ball.interaction_count
	var t: float = 0.0
	while t < curve_duration:
		await get_tree().physics_frame
		var dt: float = get_physics_process_delta_time()
		t += dt
		if ball.interaction_count != touches or ball.hovering or ball.is_held():
			return
		# Na tela (y para baixo), girar o ângulo negativo = virar à esquerda de quem anda
		ball.velocity = ball.velocity.rotated(-deg_to_rad(curve_deg_per_sec) * dt)


func skill_is_free(skill_id: StringName) -> bool:
	return skill_id == SKILL_EGO


## Enquanto o complemento puder ser usado, o turno não acaba sozinho
func has_free_followup() -> bool:
	return _ego_ready and get_kick_type(_get_ball()) != KickType.NONE


# ---------- MANIPULABLE ARRAY / KNIGHT PIERCE / EN GARDE ----------

func get_array_variant() -> ArrayVariant:
	var ball: Ball = _get_ball()
	if ball == null or is_down:
		return ArrayVariant.NONE
	if global_position.distance_to(ball.global_position) <= kick_range:
		return ArrayVariant.ARRAY
	if height_level == Heights.Level.GROUND:
		return ArrayVariant.PIERCE
	return ArrayVariant.GUARD


func _array_skill_name() -> String:
	match get_array_variant():
		ArrayVariant.PIERCE:
			return "Knight Pierce"
		ArrayVariant.GUARD:
			return "En Garde"
	return "Manipulable Array (passar)" if _link.active else "Manipulable Array"


func _valid_pierce_target(o: Player) -> bool:
	return o.team != team and o.height_level == Heights.Level.GROUND and not o.is_down


func _has_pierce_target() -> bool:
	for o: Player in get_tree().get_nodes_in_group("players"):
		if _valid_pierce_target(o) and global_position.distance_to(o.global_position) <= pierce_range:
			return true
	return false


func _use_array_skill() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var ok: bool = false
	match get_array_variant():
		ArrayVariant.ARRAY:
			# O 1-2 cuida da própria recarga (ela começa quando ele acaba)
			if _link.active:
				return await _link.exchange(self)
			return await _link.cast()
		ArrayVariant.PIERCE:
			ok = await _use_pierce(m)
		ArrayVariant.GUARD:
			ok = await _use_guard(m)
	if ok:
		start_cooldown(CD_ARRAY, array_cooldown)
	return ok


func _use_pierce(m: MatchManager) -> bool:
	var filter: Callable = func(o: Player) -> bool: return _valid_pierce_target(o)
	var foe: Player = await m.pick_ally_for_skill(self, pierce_range, true, filter)
	if foe == null:
		return false
	if not await play_action(&"knight_pierce"):
		return false
	var to: Vector2 = foe.global_position - global_position
	var dist: float = maxf(0.0, to.length() - (body_radius + foe.body_radius + 6.0))
	await _dash(to, dist, pierce_dash_time)
	_pierce_target = foe
	_pierce_until = m.round_number + pierce_rounds - 1
	m.announce_keeper("%s não pode chutar e corre mais devagar!" % foe.get_display_name(), team)
	return true


func _use_guard(m: MatchManager) -> bool:
	var aim: Vector2 = await m.aim_for_skill(self, guard_dash_distance)
	if aim == Vector2.ZERO:
		return false
	if not await play_action(&"en_garde"):
		return false
	var d: Vector2 = aim.normalized()
	face_towards(d)
	_dashing = true
	var speed: float = guard_dash_distance / maxf(guard_dash_time, 0.01)
	var travelled: float = 0.0
	var deflected: bool = false
	while travelled < guard_dash_distance:
		await get_tree().physics_frame
		var step: float = minf(speed * get_physics_process_delta_time(), guard_dash_distance - travelled)
		global_position = _clamp_to_field(global_position + d * step)
		travelled += step
		if deflected:
			continue
		var ball: Ball = _get_ball()
		if ball != null and not ball.is_held() and not ball.is_locked_for(team) \
				and Heights.can_reach(height_level, ball.get_level()) \
				and global_position.distance_to(ball.global_position) <= guard_hit_radius:
			deflected = true
			var chance: float = clampf(deflect_chance + _eyes_shot_bonus() + take_next_shot_bonus(), 0.0, 1.0)
			ball.kick(d, deflect_power, deflect_lift, self, chance)
			ball.play_fx(_make_kick_fx())
	_dashing = false
	return true


## Knight Pierce: age nos adversários pelo grupo "control_sources" (ver player.gd)
func _pierce_active_on(p: Player) -> bool:
	if p != _pierce_target or not is_instance_valid(p):
		return false
	var m: MatchManager = _get_manager()
	return m != null and m.round_number <= _pierce_until


func blocks_general_action(p: Player, action: int) -> bool:
	return _pierce_active_on(p) and action == MatchManager.GeneralAction.SHOOT


func run_speed_mult_on(p: Player) -> float:
	return pierce_run_speed_mult if _pierce_active_on(p) else 1.0


# ---------- LOOP ----------

func _physics_process(delta: float) -> void:
	super(delta)
	_carry_update()
	_link.poll()
	_update_trail()


# ---------- HIS EYES ----------

func is_eyes_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _eyes_until >= 0 and m.round_number <= _eyes_until


func _eyes_shot_bonus() -> float:
	return eyes_shot_bonus if is_eyes_active() else 0.0


func _use_eyes() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	_eyes_until = m.round_number + eyes_rounds - 1   # a rodada atual conta
	start_cooldown(CD_EYES, eyes_cooldown, _eyes_until + 1)
	_apply_eyes_state()
	queue_redraw()
	return true


## Carrinho mais longo enquanto o efeito dura (o MatchManager mira usando slide_distance)
func _apply_eyes_state() -> void:
	slide_distance = _base_slide * (1.0 + eyes_slide_bonus) if is_eyes_active() else _base_slide


## Correr mais rápido com a visão ativa (soma com os efeitos de adversários)
func get_run_speed_mult() -> float:
	return super() * (1.0 + eyes_run_bonus if is_eyes_active() else 1.0)


## Vale também para o Chutar geral: base do tipo de chute + His Eyes
func get_shot_chance(kind: KickType) -> float:
	return minf(super(kind) + _eyes_shot_bonus(), 1.0)


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"id": SKILL_CUTS, "name": skill_label("Rainbow Cuts", CD_CUTS)})
	if _ego_ready:
		list.append({"id": SKILL_EGO, "name": "Without Ego"})
	list.append({"id": SKILL_ARRAY, "name": skill_label(_array_skill_name(), CD_ARRAY)})
	var eyes_name: String = "His Eyes (ativo)" if is_eyes_active() else skill_label("His Eyes", CD_EYES)
	list.append({"id": SKILL_EYES, "name": eyes_name})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_CUTS:
			return height_level == Heights.Level.GROUND and not is_on_cooldown(CD_CUTS)
		SKILL_EGO:
			return _ego_ready and get_kick_type(_get_ball()) != KickType.NONE
		SKILL_ARRAY:
			match get_array_variant():
				ArrayVariant.ARRAY:
					# 1-2 ativo: o botão passa/devolve; senão, liga o 1-2 (can_cast confere a recarga)
					return _link.can_exchange(self) if _link.active else _link.can_cast()
				ArrayVariant.PIERCE:
					return not is_on_cooldown(CD_ARRAY) and _has_pierce_target()
				ArrayVariant.GUARD:
					return not is_on_cooldown(CD_ARRAY)
			return false
		SKILL_EYES:
			return not is_eyes_active() and not is_on_cooldown(CD_EYES)
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_CUTS:
			return await _use_cuts()
		SKILL_EGO:
			return await _use_ego()
		SKILL_ARRAY:
			return await _use_array_skill()
		SKILL_EYES:
			await play_action(&"his_eyes")
			return _use_eyes()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_CUTS:
			title = "Rainbow Cuts"
			text = ("Teddy, no chão, avança %d vezes em curtas distâncias. Cada inimigo no chão que encontrar o faz recuar um passo e ganhar um avanço mais longo. Gruda a bola no chão em si.\n"
				+ "Ao fim dos avanços, libera o Without Ego. Recarga: %d rodadas.") % [cuts_charges, cuts_cooldown]
		SKILL_EGO:
			title = "Without Ego"
			text = "Chute forte que sobe ao nível %s e faz uma leve curva para a esquerda. %d%% de chance de gol. Não gasta ação." % [
				"Voando" if is_eyes_active() else "Suspenso", _pct(chance_ego + _eyes_shot_bonus())]
		SKILL_ARRAY:
			title = _array_skill_name()
			match get_array_variant():
				ArrayVariant.PIERCE:
					text = "Vai até um inimigo no chão: ele fica sem Chutar e com o Correr mais lento até o fim da próxima rodada."
				ArrayVariant.GUARD:
					text = "Dash aéreo. Se encontrar a bola, dá um Deflect nela (%d%% de chance de gol)." % _pct(deflect_chance)
				_:
					if _link.active:
						text = _link.exchange_description()
					else:
						text = _link.cast_description() + "\nCom His Eyes o bônus por rodada passa de +%d%% para +%d%%." % [
							_pct(array_bonus), _pct(eyes_array_bonus)]
			if get_array_variant() != ArrayVariant.ARRAY:
				text += "\nRecarga: %d rodadas." % array_cooldown
		SKILL_EYES:
			title = "His Eyes"
			text = ("Visão de predador por %d rodadas: mais velocidade no Correr, Carrinho mais longo e +%d%% em qualquer chute.\n"
				+ "Rainbow Cuts +%d avanço; Without Ego sobe a Voando; Manipulable Array passa a +%d%%.\n"
				+ "Recarga: %d rodadas após o fim.") % [
				eyes_rounds, _pct(eyes_shot_bonus), eyes_extra_cuts, _pct(eyes_array_bonus), eyes_cooldown]
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()
	_release_ball()
	_ego_ready = false
	_link.clear()
	_pierce_target = null
	_pierce_until = -1
	_eyes_until = -1
	_dashing = false
	slide_distance = _base_slide
	if _trail != null:
		_trail.clear_points()
	queue_redraw()


# ---------- LOOP / VISUAL ----------

func _process(delta: float) -> void:
	super(delta)
	if _link.active:
		queue_redraw()   # a linha da ligação acompanha o aliado


func _draw() -> void:
	super()
	var center := Vector2(0.0, -height)

	# His Eyes: anel arco-íris em volta dele
	if is_eyes_active():
		var segs: int = 18
		for i in segs:
			draw_arc(center, placeholder_radius + 7.0,
				TAU * float(i) / float(segs), TAU * float(i + 1) / float(segs) + 0.05, 4,
				Color.from_hsv(float(i) / float(segs), 0.7, 1.0, 0.9), 2.5)

	# Manipulable Array: linha tracejada até o parceiro + bônus acumulado
	_link.draw_link(self)
