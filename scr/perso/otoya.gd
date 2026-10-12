class_name Otoya
extends Player
## Otoya. Herda tudo do Player (ações gerais) e adiciona as habilidades próprias.
## Usa só o que o player.gd já tem (inclusive o on_kick do kick_ball, o mesmo do Kaiser).
##
## 1. Stealthy Steps (ação de habilidade; recarga de 2 rodadas, contada a partir do FIM do efeito,
##      compartilhada com a variante): modo FURTIVO por 3 rodadas (contando a atual):
##      - fica quase invisível (opacidade 25%)
##      - Correr x1.2 mais rápido
##      - imune a qualquer efeito (inimigo ou aliado): travas, bloqueios, confusão, penalidades
##        de chute, bônus de aliados, Carrinho... enquanto está oculto
##      - +5% de chance em qualquer chute e melhorias nas habilidades (Shh.. do Tiki Taka,
##        Shuriken e Kurigama Combo um pouco mais fortes)
##      - perde o efeito se usar chutes ou a ação geral Passe, mas só quando a rodada passar
##    Kunai Volley (variante, com o Otoya SUSPENSO): entra em modo furtivo + avanço aéreo curto
##      (você mira); se alcançar a bola, faz um voleio (45%). Esse voleio NÃO desfaz o furtivo.
## 2. Tiki Taka Cheats (ação de habilidade; recarga compartilhada com o Shh..): com o Otoya no
##      chão e a bola próxima, escolhe um aliado (alcance 475) e faz um passe rasteiro. Ele ganha
##      uma ação Correr mais curta e, ao fim dela, se estiver no alcance, o aliado devolve a bola.
##    Shh.. (com o furtivo ativo): ao receber a bola de volta, pode repetir com OUTRO aliado
##      (alcance 450; cancelar a escolha = não repete). Se não houver outro aliado ao alcance,
##      o Otoya ganha +1 ação de habilidade.
## 3. Shuriken (ação de habilidade; recarga de 2 rodadas, compartilhada com a variante): chute em
##      que a bola sobe ao nível Suspenso, com o Otoya e a bola no chão ou suspensos (45%).
##    Kurigama Combo (variante: bola e Otoya Suspensos e outro jogador próximo): um pouco mais de
##      força, um pouco de curva e 50%.
##
## Como montar a cena: Nova Cena Herdada de player.tscn -> anexe este script ao nó raiz
## -> renomeie o nó raiz para "Otoya".
##
## Animações opcionais (SpriteFrames; hit_frames diz o frame de impacto de cada uma):
## "stealthy_steps", "kunai_volley", "tiki_taka", "shuriken", "kurigama_combo". Sem elas, nada quebra.

const SKILL_STEALTH: StringName = &"stealthy_steps"
const SKILL_TIKI: StringName = &"tiki_taka_cheats"
const SKILL_SHURIKEN: StringName = &"shuriken"

## Grupos de recarga (as variantes de cada habilidade compartilham o mesmo)
const CD_STEALTH: StringName = &"cd_stealth"
const CD_TIKI: StringName = &"cd_tiki"
const CD_SHURIKEN: StringName = &"cd_shuriken"

enum StealthSkill { NONE, STEPS, KUNAI }
enum ShurikenSkill { NONE, SHURIKEN, KURIGAMA }

## Verde limão com branco
const LIME := Color(0.70, 1.0, 0.20)
const WHITE := Color(1.0, 1.0, 1.0)

@export_group("Stealthy Steps / Kunai Volley")
@export var stealth_rounds: int = 3                 # duração do furtivo (contando a rodada atual)
@export var stealth_cooldown: int = 2               # recarga, contada a partir do FIM do efeito
@export_range(0.0, 1.0) var stealth_alpha: float = 0.25   # opacidade enquanto oculto
@export var stealth_run_speed_mult: float = 1.2     # Correr mais rápido
@export_range(0.0, 1.0) var stealth_shot_bonus: float = 0.05   # +5% em qualquer chute
@export var stealth_force_mult: float = 1.1         # melhoria: Shuriken/Kurigama um pouco mais fortes
@export_range(0.0, 1.0) var chance_kunai: float = 0.45
@export var kunai_dash_distance: float = 220.0      # avanço aéreo curto
@export var kunai_dash_time: float = 0.3
@export var kunai_ball_radius: float = 60.0         # "alcançar a bola"

@export_group("Tiki Taka Cheats")
@export var tiki_range: float = 444.0               # alcance do passe (e da devolução)
@export var tiki_repeat_range: float = 400.0        # Shh..: alcance do segundo passe
@export var tiki_cooldown: int = 2                  # (não informado: ajuste à vontade)
@export var tiki_run_mult: float = 0.5              # o Correr dele é a metade do tempo normal
@export var shh_extra_skills: int = 1               # Shh.. sem outro aliado: ações de habilidade extras

@export_group("Shuriken / Kurigama Combo")
@export_range(0.0, 1.0) var chance_shuriken: float = 0.45
@export_range(0.0, 1.0) var chance_kurigama: float = 0.50
@export var shuriken_cooldown: int = 2
@export var kurigama_force_mult: float = 1.15       # "um pouco mais de força"
@export var kurigama_bend_deg: float = 10.0         # "um pouco de curva"
@export var kurigama_bend_sign: float = 1.0
@export var kurigama_flight_time: float = 0.7       # por quanto tempo a bola é conduzida na curva
@export var kurigama_radius: float = 130.0          # "outro jogador próximo"

@export_group("Visual do chute")
## Aura + partículas dos chutes e passes de habilidade. Vazio = verde limão com branco (veja _make_kick_fx)
@export var kick_fx: KickFX

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: stealthy_steps, tiki_taka_cheats, shuriken.
@export var skill_icons: Dictionary = {}

## Furtivo vale até o fim desta rodada (-1 = inativo)
var _stealth_until_round: int = -1
## Usou chute ou Passe: o furtivo acaba quando a rodada passar
var _stealth_broken: bool = false
## O chute/passe que está sendo feito agora é de habilidade e não desfaz o furtivo
var _safe_kick: bool = false
var _skill_pass: bool = false
## Avanço aéreo do Kunai Volley
var _dash_token: int = 0


func _init() -> void:
	character_id = "otoya"           # o menu de formação usa isto para saber quem é quem
	display_name = "Otoya"           # aparece no placar de gols e no menu (troque aqui se quiser)


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = _make_kick_fx()
	_hook_manager.call_deferred()   # o MatchManager entra na árvore no mesmo frame


## Verde limão com partículas brancas
func _make_kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = LIME
	fx.trail_width = 12.0
	fx.particle_color = WHITE
	fx.amount = 20
	fx.lifetime = 0.5
	fx.speed_min = 15.0
	fx.speed_max = 70.0
	fx.gravity = Vector2(0.0, -40.0)
	fx.spin = 260.0
	fx.scale_min = 0.15
	fx.scale_max = 0.3
	fx.burst_amount = 12
	fx.burst_speed = 200.0
	return fx


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m:
		m.round_started.connect(_on_round_started)


func _on_round_started(new_round: int) -> void:
	# Usou chute/Passe durante o furtivo: o efeito acaba agora que a rodada passou, e a recarga
	# (que só conta depois do fim do efeito) começa daqui
	if _stealth_broken and _stealth_until_round >= new_round:
		_stealth_until_round = new_round - 1
		start_cooldown(CD_STEALTH, stealth_cooldown, new_round)
	if _stealth_until_round >= 0 and new_round > _stealth_until_round:
		_stealth_broken = false
	_apply_stealth_visual()
	queue_redraw()


# ---------- MODO FURTIVO ----------

func is_stealth_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _stealth_until_round >= 0 and m.round_number <= _stealth_until_round


func _apply_stealth_visual() -> void:
	modulate.a = stealth_alpha if is_stealth_active() else 1.0


func _enter_stealth() -> void:
	var m: MatchManager = _get_manager()
	if m == null:
		return
	_stealth_until_round = m.round_number + stealth_rounds - 1   # a rodada atual conta
	_stealth_broken = false
	# A recarga só começa quando o efeito acabar
	start_cooldown(CD_STEALTH, stealth_cooldown, _stealth_until_round + 1)
	_spawn_pulse()   # antes de sumir (o anel fica no campo, não em cima dele)
	_apply_stealth_visual()
	queue_redraw()


func _spawn_pulse() -> void:
	var ring := PulseRing.new()
	ring.ring_color = LIME
	ring.global_position = global_position
	get_parent().add_child(ring)


func get_stealth_skill() -> StealthSkill:
	if is_stealth_active():
		return StealthSkill.NONE
	return StealthSkill.KUNAI if height_level == Heights.Level.SUSPENDED else StealthSkill.STEPS


func _use_stealth() -> bool:
	match get_stealth_skill():
		StealthSkill.STEPS:
			if not await play_action(&"stealthy_steps"):
				return false   # ação cancelada (ex: a partida reiniciou)
			_enter_stealth()
			return true
		StealthSkill.KUNAI:
			return await _use_kunai()
	return false


## Kunai Volley: modo furtivo + avanço aéreo curto (mirado). Se alcançar a bola, faz um voleio.
func _use_kunai() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var aim: Vector2 = await m.aim_for_skill(self, kunai_dash_distance)
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação

	_enter_stealth()
	var ball: Ball = _get_ball()
	var met: bool = await _air_dash(aim, kunai_dash_distance, true)
	if met and is_instance_valid(ball) and get_kick_type(ball) != KickType.NONE and not m.match_over:
		var kind: KickType = KickType.FLYING if ball.get_level() == Heights.Level.FLYING else KickType.VOLLEY
		var chance: float = minf(chance_kunai + _shot_bonus(), 1.0)
		_safe_kick = true   # o voleio do Kunai Volley não desfaz o furtivo que ele acabou de ativar
		await kick_ball(ball, aim, kind, true, chance, false, kick_fx, &"kunai_volley")
		_safe_kick = false
	return true


## Avanço aéreo: desliza "distance" px em kunai_dash_time s (começa rápido e desacelera, como o
## Carrinho). look_for_ball: para assim que alcançar a bola NA FRENTE dele e devolve true. Quem está
## no chão não bloqueia o avanço (ele está no ar).
func _air_dash(dir: Vector2, distance: float, look_for_ball: bool) -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	var token: int = _dash_token
	face_towards(dir)

	var met: bool = false
	var elapsed: float = 0.0
	while elapsed < kunai_dash_time:
		await get_tree().physics_frame
		if token != _dash_token or (m != null and m.match_over):
			break
		var delta: float = get_physics_process_delta_time()
		elapsed += delta
		var frac: float = clampf(1.0 - elapsed / kunai_dash_time, 0.0, 1.0)
		velocity = dir * (2.0 * distance / kunai_dash_time) * frac
		_update_dash_collision_exceptions()
		move_and_slide()
		if look_for_ball and _ball_in_dash_reach(ball, dir):
			met = true
			break

	velocity = Vector2.ZERO
	_clear_slide_collision_exceptions()   # solta as exceções de colisão (a mesma do Carrinho)
	return met


func _update_dash_collision_exceptions() -> void:
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other == self:
			continue
		if other.height_level != height_level:   # em alturas diferentes não se esbarram
			add_collision_exception_with(other)
			other.add_collision_exception_with(self)
		else:
			remove_collision_exception_with(other)
			other.remove_collision_exception_with(self)


func _ball_in_dash_reach(ball: Ball, dir: Vector2) -> bool:
	if ball == null or ball.is_held() or ball.is_locked_for(team):
		return false
	if not can_reach_level(ball.get_level()):
		return false
	var to_ball: Vector2 = ball.global_position - global_position
	return to_ball.length() <= kunai_ball_radius and to_ball.dot(dir) > 0.0   # só se está na frente


# ---------- IMUNIDADE (enquanto oculto) ----------
## Estes métodos do Player são os pontos por onde chegam os efeitos de outros jogadores. Enquanto o
## Otoya está furtivo, todos são ignorados (inimigos E aliados).

func apply_lock(by: Node2D, rounds: int, skills_only: bool = false) -> void:
	if is_stealth_active():
		return
	super(by, rounds, skills_only)


func apply_shot_debuff(amount: float, until_round: int, source: Node2D,
		break_distance: float = 0.0) -> void:
	if is_stealth_active():
		return
	super(amount, until_round, source, break_distance)


func apply_confusion(until_round: int) -> void:
	if is_stealth_active():
		return
	super(until_round)


func get_shot_debuff() -> float:
	return 0.0 if is_stealth_active() else super()


func get_opponent_shot_penalty() -> float:
	return 0.0 if is_stealth_active() else super()


func get_team_shot_bonus(ball: Ball) -> float:
	return 0.0 if is_stealth_active() else super(ball)


func is_skills_suppressed() -> bool:
	return false if is_stealth_active() else super()


func is_generals_suppressed() -> bool:
	return false if is_stealth_active() else super()


func is_general_action_blocked(action: int) -> bool:
	return false if is_stealth_active() else super(action)


func is_pass_blocked() -> bool:
	return false if is_stealth_active() else super()


## Correr x1.2 no furtivo (e sem os efeitos de velocidade/tempo dos outros)
func get_run_speed_mult() -> float:
	return stealth_run_speed_mult if is_stealth_active() else super()


func get_run_time_mult() -> float:
	return 1.0 if is_stealth_active() else super()


## Oculto: o Carrinho passa direto por ele (nada de queda)
func try_counter_slide(attacker: Player) -> bool:
	if is_stealth_active():
		return true
	return super(attacker)


func knock_down() -> void:
	if is_stealth_active():
		return
	super()


# ---------- CHUTES E PASSES DESFAZEM O FURTIVO (só quando a rodada passar) ----------

func kick_ball(ball: Ball, direction: Vector2, kind: KickType, qte_success: bool = true,
		chance_override: float = -1.0, ignore_self_collision: bool = false,
		fx: KickFX = null, anim: StringName = &"", on_kick: Callable = Callable()) -> void:
	if is_stealth_active() and not _safe_kick:
		_stealth_broken = true
	await super(ball, direction, kind, qte_success, chance_override, ignore_self_collision,
		fx, anim, on_kick)


## Toda ação de Passe (a geral) passa por aqui para a animação do passe; os passes das habilidades
## do Otoya (Tiki Taka) avisam com _skill_pass e não desfazem o furtivo.
func play_action(anim: StringName, fallback: StringName = &"") -> bool:
	if (anim == ANIM_PASS or anim == ANIM_PASS_HIGH) and is_stealth_active() and not _skill_pass:
		_stealth_broken = true
	return await super(anim, fallback)


## +5% em qualquer chute enquanto furtivo
func _shot_bonus() -> float:
	return stealth_shot_bonus if is_stealth_active() else 0.0


func get_shot_chance(kind: KickType) -> float:
	return minf(super(kind) + _shot_bonus(), 1.0)


# ---------- TIKI TAKA CHEATS / SHH.. ----------

func _can_receive(p: Player) -> bool:
	return is_instance_valid(p) and p != self and not p.is_pass_blocked()


func _can_receive_except(p: Player, skip: Player) -> bool:
	return p != skip and _can_receive(p)


## Companheiros ao alcance que podem receber o passe
func _tiki_candidates(range_px: float, skip: Player = null) -> Array[Player]:
	var result: Array[Player] = []
	var m: MatchManager = _get_manager()
	if m == null:
		return result
	for p: Player in m.get_team_players(team):
		if p != skip and _can_receive(p) and global_position.distance_to(p.global_position) <= range_px:
			result.append(p)
	return result


func _use_tiki() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null or height_level != Heights.Level.GROUND \
			or get_kick_type(ball) == KickType.NONE:
		return false

	var first: Player = await m.pick_ally_for_skill(self, tiki_range, false, _can_receive)
	if first == null or m.match_over:
		return false   # cancelou: não gasta a ação

	var returned: bool = await _tiki_round(m, ball, first, tiki_range)
	start_cooldown(CD_TIKI, tiki_cooldown)

	# Shh..: com o furtivo ativo e a bola de volta, repete com OUTRO aliado (alcance 450)
	if returned and is_stealth_active() and not m.match_over:
		if _tiki_candidates(tiki_repeat_range, first).is_empty():
			extra_skill_left += shh_extra_skills   # sem outro aliado: mais uma ação de habilidade
		else:
			var second: Player = await m.pick_ally_for_skill(self, tiki_repeat_range, false,
				_can_receive_except.bind(first))
			if second != null and not m.match_over:
				await _tiki_round(m, ball, second, tiki_repeat_range)
			# Cancelar o 2º passe é só "não quero repetir": o manager trataria como habilidade
			# cancelada (devolve a ação e a recarga), mas o primeiro passe JÁ aconteceu.
			m._skill_pick_cancelled = false
	return true


## Um ciclo do Tiki Taka: passe rasteiro para o aliado, Correr mais curto e devolução.
## Devolve true se o aliado devolveu a bola.
func _tiki_round(m: MatchManager, ball: Ball, ally: Player, range_px: float) -> bool:
	_skill_pass = true   # este passe é de habilidade: não desfaz o furtivo
	await m.run_curved_ground_pass(self, ally, ball, 0.0, 1.0, &"tiki_taka", kick_fx)
	_skill_pass = false
	if m.match_over or not is_instance_valid(ball):
		return false

	# Ação Correr mais curta (não conta no limite de Correr do turno)
	var base_run: float = run_duration
	run_duration = base_run * tiki_run_mult
	start_run()
	runs_this_turn = maxi(0, runs_this_turn - 1)
	await run_finished
	run_duration = base_run
	if m.match_over or not is_instance_valid(ball):
		return false

	# Ao fim da corrida, se estiver no alcance e a bola ainda estiver com o aliado, ele devolve
	if is_down or ally.is_down or global_position.distance_to(ally.global_position) > range_px \
			or ally.get_kick_type(ball) == KickType.NONE:
		return false
	await m.run_curved_ground_pass(ally, self, ball, 0.0, 1.0, &"", kick_fx)
	return true


# ---------- SHURIKEN / KURIGAMA COMBO ----------

func get_shuriken_skill() -> ShurikenSkill:
	var ball: Ball = _get_ball()
	if get_kick_type(ball) == KickType.NONE:
		return ShurikenSkill.NONE
	var ball_level: Heights.Level = ball.get_level()
	if ball_level == Heights.Level.FLYING or height_level == Heights.Level.FLYING:
		return ShurikenSkill.NONE
	if height_level == Heights.Level.SUSPENDED and ball_level == Heights.Level.SUSPENDED \
			and _other_player_near():
		return ShurikenSkill.KURIGAMA
	return ShurikenSkill.SHURIKEN   # no chão ou suspenso, com a bola ao alcance


## Tem outro jogador (de qualquer time) por perto?
func _other_player_near() -> bool:
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other != self and not other.is_down \
				and global_position.distance_to(other.global_position) <= kurigama_radius:
			return true
	return false


func _use_shuriken() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or get_shuriken_skill() == ShurikenSkill.NONE:
		return false

	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação

	# A bola pode ter rolado enquanto ele mirava: confere de novo
	var ball: Ball = _get_ball()
	var variant: ShurikenSkill = get_shuriken_skill()
	if variant == ShurikenSkill.NONE:
		return false

	var dir: Vector2 = aim
	var base_chance: float = chance_shuriken
	var force: float = 1.0
	var anim: StringName = &"shuriken"
	var on_kick: Callable = Callable()
	if variant == ShurikenSkill.KURIGAMA:
		base_chance = chance_kurigama
		force = kurigama_force_mult
		anim = &"kurigama_combo"
		dir = _curve_heading(aim.angle(), 0.0)   # sai desviado e curva de volta
		on_kick = _launch_curve.bind(aim)
	if is_stealth_active():
		force *= stealth_force_mult   # melhoria do furtivo

	next_kick_force_mult *= force   # gasto dentro do kick_ball
	var chance: float = minf(base_chance + _shot_bonus(), 1.0)
	# VOLLEY sempre: a bola sobe ao nível Suspenso (se já estiver suspensa, só segue)
	await kick_ball(ball, dir, KickType.VOLLEY, true, chance, false, kick_fx, anim, on_kick)
	start_cooldown(CD_SHURIKEN, shuriken_cooldown)
	return true


## Direção da bola no ponto u (0 = chute, 1 = fim da condução) do Kurigama Combo: sai desviada
## para um lado e termina desviada para o outro (desvio total zero: cruza a linha da mira).
func _curve_heading(aim_angle: float, u: float) -> Vector2:
	var bend: float = deg_to_rad(kurigama_bend_deg) * kurigama_bend_sign
	return Vector2.from_angle(aim_angle + bend * (1.0 - 2.0 * u))


## Chamado pelo kick_ball() logo depois que a bola sai (on_kick)
func _launch_curve(ball: Ball, _dir: Vector2, speed: float, aim: Vector2) -> void:
	_drive_ball(ball, kurigama_flight_time, _curve_step.bind(aim.angle(), speed))


## Um passo da condução: só curva a velocidade (a subida/queda continua com a física da bola)
func _curve_step(b: Ball, u: float, _delta: float, aim_angle: float, speed: float) -> void:
	b.velocity = _curve_heading(aim_angle, u) * speed * lerpf(1.0, 0.9, u)


## Conduz a bola por "duration" segundos chamando step(bola, u 0..1, delta) a cada frame de física.
## Para sozinho se alguém tocar na bola, ela for segurada, reposta ou a partida acabar.
## Quem chama NÃO precisa esperar (roda em segundo plano).
func _drive_ball(ball: Ball, duration: float, step: Callable) -> void:
	var m: MatchManager = _get_manager()
	var touches: int = ball.interaction_count   # o chute do Otoya já foi contado
	var state: Dictionary = {"abort": false}
	var on_reset: Callable = func() -> void: state["abort"] = true
	ball.was_reset.connect(on_reset, CONNECT_ONE_SHOT)

	var elapsed: float = 0.0
	while elapsed < duration:
		await get_tree().physics_frame
		if not is_instance_valid(ball) or state["abort"] or ball.interaction_count != touches \
				or ball.hovering or (m != null and m.match_over):
			break
		var delta: float = get_physics_process_delta_time()
		elapsed += delta
		step.call(ball, clampf(elapsed / duration, 0.0, 1.0), delta)

	if is_instance_valid(ball) and ball.was_reset.is_connected(on_reset):
		ball.was_reset.disconnect(on_reset)


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []

	var stealth_name: String = "Stealthy Steps"
	if is_stealth_active():
		stealth_name += " (ativo)"
	else:
		if get_stealth_skill() == StealthSkill.KUNAI:
			stealth_name = "Kunai Volley"
		stealth_name = skill_label(stealth_name, CD_STEALTH)
	list.append({"id": SKILL_STEALTH, "name": stealth_name})

	var tiki_name: String = "Shh.. Tiki Taka Cheats" if is_stealth_active() else "Tiki Taka Cheats"
	list.append({"id": SKILL_TIKI, "name": skill_label(tiki_name, CD_TIKI)})

	var shuriken_name: String = "Kurigama Combo" if get_shuriken_skill() == ShurikenSkill.KURIGAMA else "Shuriken"
	list.append({"id": SKILL_SHURIKEN, "name": skill_label(shuriken_name, CD_SHURIKEN)})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_STEALTH:
			return not is_on_cooldown(CD_STEALTH) and get_stealth_skill() != StealthSkill.NONE
		SKILL_TIKI:
			return not is_on_cooldown(CD_TIKI) and height_level == Heights.Level.GROUND \
				and get_kick_type(_get_ball()) != KickType.NONE \
				and not _tiki_candidates(tiki_range).is_empty()
		SKILL_SHURIKEN:
			return not is_on_cooldown(CD_SHURIKEN) and get_shuriken_skill() != ShurikenSkill.NONE
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_STEALTH:
			return await _use_stealth()
		SKILL_TIKI:
			return await _use_tiki()
		SKILL_SHURIKEN:
			return await _use_shuriken()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_STEALTH:
			if get_stealth_skill() == StealthSkill.KUNAI:
				title = "Kunai Volley"
				text = "Entra em furtivo e avança no ar. Se alcançar a bola, faz um voleio com %d%% de chance de gol." % _pct(chance_kunai)
			else:
				title = "Stealthy Steps"
				text = "Modo furtivo por %d rodadas: o Otoya fica quase invisível, corre mais rápido, é imune a efeitos e ganha +%d%% de chance de gol. Acaba se ele chutar ou passar." % [
					stealth_rounds, _pct(stealth_shot_bonus)]
			text += "\nRecarga: %d rodadas." % stealth_cooldown
		SKILL_TIKI:
			title = "Shh.. Tiki Taka Cheats" if is_stealth_active() else "Tiki Taka Cheats"
			text = "Passe rasteiro para um aliado; o Otoya corre um pouco e o aliado devolve a bola."
			if is_stealth_active():
				text += " Furtivo: pode repetir com outro aliado, ou ganha +%d ação de habilidade." % shh_extra_skills
			text += "\nRecarga: %d rodadas." % tiki_cooldown
		SKILL_SHURIKEN:
			if get_shuriken_skill() == ShurikenSkill.KURIGAMA:
				title = "Kurigama Combo"
				text = "Chute com curva em que a bola sobe. %d%% de chance de gol." % _pct(chance_kurigama)
			else:
				title = "Shuriken"
				text = "Chute em que a bola sobe. %d%% de chance de gol." % _pct(chance_shuriken)
			text += "\nRecarga: %d rodadas." % shuriken_cooldown
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()
	_dash_token += 1   # um avanço em andamento percebe e para
	_stealth_until_round = -1
	_stealth_broken = false
	_safe_kick = false
	_skill_pass = false
	_clear_slide_collision_exceptions()
	modulate.a = 1.0
	queue_redraw()


# ---------- VISUAL ----------

## Anel verde limão com branco que se abre e some (ao entrar no modo furtivo). Fica no campo
## (não em cima do Otoya), por isso aparece mesmo com ele a 25% de opacidade.
class PulseRing extends Node2D:
	var ring_color: Color = Color(0.70, 1.0, 0.20)
	var _time: float = 0.0
	const LIFE: float = 0.6

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
		draw_arc(Vector2.ZERO, 16.0 + 40.0 * k, 0.0, TAU, 36, Color(ring_color, 1.0 - k), 3.0)
		draw_arc(Vector2.ZERO, 10.0 + 30.0 * k, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, 1.0 - k), 2.0)
