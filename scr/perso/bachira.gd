class_name Bachira
extends Player
## Bachira Meguru. Mais um personagem do time, com 3 habilidades:
##
## 1. Bon! (ação de habilidade, com 2 variantes automáticas pela altura; recarga de 2 rodadas,
##      compartilhada):
##      - Bachira e bola NÃO os dois suspensos (e a bola ao alcance) -> Bon!: chute que põe a
##          bola no nível Voando antes de ela cair de novo (30%). A bola QUICA SÓ UMA VEZ
##          (bon_max_bounces) e o chute sai mais forte (bon_force_mult). Sem QTE com a bola no
##          chão; se a bola estiver mais alta, o QTE é o do chute comum daquela situação.
##      - Bachira e bola os dois suspensos -> Bee Shot: voleio SEM QTE (40%).
##
## 2. Step Overs (ação de habilidade; recarga de 3 rodadas): com Bachira e a bola no chão, ele
##      faz as passadas na bola e atordoa os (até) 2 inimigos mais próximos, bem perto dele:
##      eles ficam sem poder usar as ações gerais Carrinho e Correr no PRÓXIMO turno do time
##      deles (step_stun_turns).
##
## 3. Unleash Instinct (ação de habilidade; recarga de 2 rodadas): parecido com o Glam! da Aryu.
##      Com a bola próxima, Bachira a SEGURA (ela fica à frente dele; adversários não conseguem
##      tocar nela). Dura até o fim do próximo turno do adversário.
##      - Se um adversário chegar perto, Bachira e a bola DESVIAM e ele ganha UMA ação geral
##        extra (vale para tudo, inclusive o Correr), guardada para o turno dele.
##      - Depois desse primeiro desvio ele ainda pode desviar instinct_extra_dodges (2) vezes:
##        se um adversário tentar tomar a bola de novo, ele e a bola desviam outra vez.
##      - Depois do primeiro desvio, a bola continua com ele até o fim do próximo turno do time
##        do Bachira (para ele usar a ação extra). Chutar/passar/qualquer toque solta a bola.
##
## Como montar a cena: igual aos outros — Nova Cena Herdada de player.tscn -> anexe este
## script ao nó raiz -> renomeie o nó raiz para "Bachira".
##
## PEÇAS NO RESTO DO PROJETO:
## - player.gd: usa extra_general_left (já existia) para a ação extra do Unleash Instinct.
##   O campo extra_general_no_run_left (e o tratamento dele no match_manager.gd) continua lá,
##   mas o Bachira não usa mais.
##
## Animações opcionais (se faltar alguma, o jogo só pula): bon, bee_shot, step_overs,
## unleash_instinct.

const SKILL_SHOT: StringName = &"bon"
const SKILL_STEP: StringName = &"step_overs"
const SKILL_INSTINCT: StringName = &"unleash_instinct"

## Grupos de recarga (as variantes do Bon! compartilham o mesmo)
const CD_SHOT: StringName = &"cd_shot"
const CD_STEP: StringName = &"cd_step"
const CD_INSTINCT: StringName = &"cd_instinct"

## Variante da habilidade 1, pela altura do Bachira x altura da bola
enum ShotVariant { NONE, BON, BEE }

## NONE = sem Unleash Instinct; HOLDING = segurando a bola; DODGED = já desviou (ação extra ganha)
enum InstinctState { NONE, HOLDING, DODGED }

@export_group("Bon! / Bee Shot")
@export_range(0.0, 1.0) var chance_bon: float = 0.45
@export_range(0.0, 1.0) var chance_bee: float = 0.5
@export var bon_peak_level: Heights.Level = Heights.Level.FLYING   # até onde a bola sobe no Bon!
@export var bon_max_bounces: int = 1                                # quantas vezes a bola quica depois do Bon! (-1 = sem limite)
## Multiplicador da força do chute no Bon! (1.0 = força normal do voleio). Não vale para o Bee Shot.
@export_range(0.5, 3.0, 0.05) var bon_force_mult: float = 0.60
@export var shot_cooldown: int = 2                                  # igual para as 2 variantes

@export_group("Step Overs")
@export var step_range: float = 170.0          # "bem próximos": distância máxima até o inimigo
@export var step_max_targets: int = 2
## Quantos turnos do time inimigo o atordoamento dura (1 = o próximo turno deles)
@export var step_stun_turns: int = 1
@export var step_cooldown: int = 2

@export_group("Unleash Instinct")
@export var instinct_range: float = 90.0               # "bola próxima"
@export var instinct_grab_time: float = 0.15
@export var instinct_ball_offset: float = 22.0         # a bola fica à frente dele
@export var instinct_trigger_radius: float = 75.0      # adversário a esta distância da bola = tentou interagir
@export var instinct_dodge_distance: float = 160.0
@export var instinct_dodge_time: float = 0.25
@export var instinct_extra_dodges: int = 6             # desvios A MAIS depois do primeiro (o que dá a ação extra)
@export var instinct_extra_generals: int = 1           # ações gerais extras (valem para tudo, inclusive Correr)
@export var instinct_cooldown: int = 2

@export_group("Visual do chute")
## Aura + partículas dos chutes de habilidade. Vazio = usa o estilo padrão (veja _make_kick_fx)
@export var kick_fx: KickFX

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: bon, step_overs, unleash_instinct.
## Sem imagem, o balão aparece só com o texto.
@export var skill_icons: Dictionary = {}

## Estado do Unleash Instinct (segurando a bola / já desviou)
var _instinct_state: InstinctState = InstinctState.NONE
## Contagem de toques na bola quando ele a segurou: qualquer toque depois disto solta a bola
var _instinct_touches: int = 0
var _dodging: bool = false
var _dodges_left: int = 0   # desvios extras que ainda restam neste Unleash Instinct
## Inimigos atordoados pelo Step Overs: jogador -> quantos turnos do time dele ainda faltam
var _stunned: Dictionary = {}


func _init() -> void:
	character_id = "bachira"   # o menu de formação usa isto para saber quem é quem
	display_name = "Bachira"


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = _make_kick_fx()
	# O Step Overs tira ações gerais dos inimigos (ver blocks_general_action), então o
	# Bachira entra no mesmo grupo dos outros efeitos de controle (Niko, Shidou...)
	add_to_group("control_sources")
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
		m.round_started.connect(_on_round_started)
		m.turn_ended.connect(_on_turn_ended)
	var ball: Ball = _get_ball()
	if ball:
		ball.was_reset.connect(_on_ball_reset)


func _on_round_started(_round_number: int) -> void:
	queue_redraw()


func _on_ball_reset() -> void:
	_end_instinct(false)   # gol / reposição: a bola já foi solta pelo próprio Ball


## O atordoamento dura os turnos do time INIMIGO: cada vez que o turno de um time acaba, os
## atordoados daquele time perdem um turno de atordoamento
func _on_turn_ended(ended_team: int) -> void:
	# Unleash Instinct: sem desvio, solta a bola no fim do turno adversário. Depois do primeiro
	# desvio ele vale até o fim do próximo turno do time do Bachira.
	match _instinct_state:
		InstinctState.HOLDING:
			if ended_team != team and not _dodging:
				_end_instinct(true)
		InstinctState.DODGED:
			if ended_team == team:
				_end_instinct(true)
	if _stunned.is_empty():
		return
	for p in _stunned.keys():
		if not is_instance_valid(p):
			_stunned.erase(p)
			continue
		if p.team != ended_team:
			continue
		_stunned[p] = int(_stunned[p]) - 1
		if int(_stunned[p]) <= 0:
			_stunned.erase(p)
	queue_redraw()


# ---------- HABILIDADE 1: BON! / BEE SHOT ----------

func get_shot_variant() -> ShotVariant:
	var ball: Ball = _get_ball()
	# get_kick_type já confere: derrubado, bola na mão do goleiro, presa, longe demais, altura inalcançável
	if get_kick_type(ball) == KickType.NONE:
		return ShotVariant.NONE
	if height_level == Heights.Level.SUSPENDED and ball.get_level() == Heights.Level.SUSPENDED:
		return ShotVariant.BEE
	return ShotVariant.BON


func _shot_skill_name() -> String:
	return "Bee Shot" if get_shot_variant() == ShotVariant.BEE else "Bon!"


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
	var base_kind: KickType = get_kick_type(ball)   # o chute comum que caberia nesta situação

	var qte_ok: bool = true
	var chance: float = chance_bee
	var anim: StringName = &"bee_shot"
	if variant == ShotVariant.BON:
		chance = chance_bon
		anim = &"bon"
		# Bola no chão = sem QTE (como o chute no chão); mais alta = o QTE do chute comum
		if base_kind != KickType.GROUND and not skips_qte():
			qte_ok = await m.run_qte(base_kind)
	# Bee Shot: voleio sem QTE

	# Os dois usam o chute de voleio (a bola sobe). No Bon! o pico passa a ser bon_peak_level
	# (Voando); o kick_ball lê o pico DEPOIS da animação, então o ajuste fica até ele terminar.
	var previous_peak: Heights.Level = volley_peak_level
	if variant == ShotVariant.BON:
		volley_peak_level = bon_peak_level
		# Chute mais forte (o kick_ball gasta este multiplicador logo no começo)
		next_kick_force_mult *= bon_force_mult
	# Errou o QTE = chute fraquinho, sem aura
	await kick_ball(ball, aim, KickType.VOLLEY, qte_ok, chance, false,
		kick_fx if qte_ok else null, anim)
	volley_peak_level = previous_peak

	# Bon!: a bola quica só bon_max_bounces vez(es). O kick() acabou de zerar o limite, então
	# é agora que ele entra (a bola ainda está subindo: o 1º quique só vem bem depois).
	if variant == ShotVariant.BON and ball != null and not ball.hovering:
		ball.bounces_left = bon_max_bounces

	start_cooldown(CD_SHOT, shot_cooldown)
	return true


# ---------- HABILIDADE 2: STEP OVERS ----------

## Bachira e bola no chão (e ao alcance)
func _step_overs_ready() -> bool:
	if is_down or height_level != Heights.Level.GROUND:
		return false
	var ball: Ball = _get_ball()
	return ball != null and get_kick_type(ball) == KickType.GROUND


## Os (até) step_max_targets inimigos mais próximos que dá para enganar: de pé, no chão e
## dentro de step_range
func _step_targets() -> Array[Player]:
	var found: Array[Player] = []
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p.team == team or p.is_down or p.height_level != Heights.Level.GROUND:
			continue
		if global_position.distance_to(p.global_position) > step_range:
			continue
		found.append(p)
	found.sort_custom(func(a: Player, b: Player) -> bool:
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	if found.size() > step_max_targets:
		found.resize(step_max_targets)
	return found


func _use_step_overs() -> bool:
	if not _step_overs_ready() or _step_targets().is_empty():
		return false
	await play_action(&"step_overs")
	# Confere de novo depois da animação (a bola ou os inimigos podem ter mudado)
	if not _step_overs_ready():
		return false
	var targets: Array[Player] = _step_targets()
	if targets.is_empty():
		return false
	for e: Player in targets:
		_stunned[e] = step_stun_turns
	start_cooldown(CD_STEP, step_cooldown)
	queue_redraw()
	return true


## Chamado pelo is_general_action_blocked() do player.gd, em quem vai agir: atordoado não
## pode Correr nem dar Carrinho (as outras ações gerais continuam livres)
func blocks_general_action(p: Player, action: int) -> bool:
	if not _stunned.has(p):
		return false
	return action == MatchManager.GeneralAction.RUN or action == MatchManager.GeneralAction.SLIDE


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


## Bola próxima e alcançável (mesma regra do Glam! da Aryu)
func _can_hold_ball() -> bool:
	var ball: Ball = _get_ball()
	if ball == null or is_down or ball.is_held() or ball.is_locked_for(team):
		return false
	if not can_reach_level(ball.get_level()):
		return false
	return global_position.distance_to(ball.global_position) <= instinct_range


func _hold_point() -> Vector2:
	return global_position + Vector2(facing * instinct_ball_offset, 0.0)


func _instinct_skill_name() -> String:
	return "Unleash Instinct (segurando)" if _instinct_state != InstinctState.NONE else "Unleash Instinct"


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

	m.clear_pending_pass()                 # passe alto em andamento: a bola agora é do Bachira
	ball.register_touch(self)
	ball.hover_to(_hold_point(), height, instinct_grab_time)
	await get_tree().create_timer(instinct_grab_time).timeout

	_instinct_touches = ball.interaction_count   # qualquer toque depois disto solta a bola
	ball.spell_owner = self                      # adversários não conseguem tocar na bola enquanto ela está com ele
	_instinct_state = InstinctState.HOLDING
	_dodges_left = instinct_extra_dodges
	start_cooldown(CD_INSTINCT, instinct_cooldown)
	queue_redraw()
	return true


## Enquanto segura a bola: ela acompanha o Bachira; no turno adversário, quem chegar perto o faz desviar
func _physics_process(delta: float) -> void:
	super(delta)
	if _instinct_state == InstinctState.NONE:
		return
	var ball: Ball = _get_ball()
	if ball == null:
		_end_instinct(false)
		return
	# Alguém tocou/chutou a bola, ou ela foi solta por fora: o Unleash Instinct acabou
	if ball.interaction_count != _instinct_touches or not ball.hovering or ball.is_held():
		_end_instinct(false)
		return
	if is_down:   # derrubado: perde a bola
		_end_instinct(true)
		return

	ball.global_position = _hold_point()
	ball.height = height

	# Segurando = o primeiro desvio ainda não aconteceu; Dodged = já desviou, mas ainda pode
	# desviar mais instinct_extra_dodges vezes
	if not _dodging and (_instinct_state == InstinctState.HOLDING \
			or (_instinct_state == InstinctState.DODGED and _dodges_left > 0)):
		_check_instinct_trigger(ball)


func _check_instinct_trigger(ball: Ball) -> void:
	var m: MatchManager = _get_manager()
	# Só o turno do adversário conta (no turno do próprio Bachira ninguém "tenta" nada)
	if m == null or m.match_over or m.current_team == team:
		return
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p.team == team or p.is_down or not p.can_reach_level(ball.get_level()):
			continue
		var radius: float = maxf(instinct_trigger_radius, p.kick_range + 5.0)
		if p.global_position.distance_to(ball.global_position) <= radius:
			_instinct_dodge(p.global_position)
			return


## Bachira e a bola saem de perto de quem tentou interagir. O primeiro desvio dá a ação geral extra.
func _instinct_dodge(from: Vector2) -> void:
	if _instinct_state == InstinctState.DODGED:
		_dodges_left -= 1   # um desvio extra gasto (o primeiro é o que dá a ação extra)
	_dodging = true
	var away: Vector2 = global_position - from
	if away.length() < 1.0:
		away = Vector2(-facing, 0.0)
	var dest: Vector2 = _clamp_to_pitch(global_position + away.normalized() * instinct_dodge_distance)
	face_towards(-away)
	var tw := create_tween()
	tw.tween_property(self, "global_position", dest, instinct_dodge_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(instinct_dodge_time).timeout
	_dodging = false
	if _instinct_state == InstinctState.HOLDING:
		_instinct_state = InstinctState.DODGED
		# Ação geral extra (vale para tudo, inclusive o Correr), guardada para quando ele agir:
		# não dá para abrir um menu no meio do turno do adversário
		extra_general_left += instinct_extra_generals
		queue_redraw()


## release = true solta a bola (cai e rola); false = a bola já foi tocada/solta por outro
func _end_instinct(release: bool) -> void:
	if _instinct_state == InstinctState.NONE:
		return
	_instinct_state = InstinctState.NONE
	_dodging = false
	_dodges_left = 0
	var ball: Ball = _get_ball()
	if release and ball != null and ball.hovering and not ball.is_held():
		ball.release_hover()
	queue_redraw()


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"id": SKILL_SHOT, "name": skill_label(_shot_skill_name(), CD_SHOT)})
	list.append({"id": SKILL_STEP, "name": skill_label("Step Overs", CD_STEP)})
	list.append({"id": SKILL_INSTINCT, "name": skill_label(_instinct_skill_name(), CD_INSTINCT)})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_SHOT:
			return not is_on_cooldown(CD_SHOT) and get_shot_variant() != ShotVariant.NONE
		SKILL_STEP:
			# precisa de alguém para enganar: sem inimigo perto a habilidade seria desperdiçada
			return not is_on_cooldown(CD_STEP) and _step_overs_ready() and not _step_targets().is_empty()
		SKILL_INSTINCT:
			# sem reusar enquanto já está segurando a bola
			return not is_on_cooldown(CD_INSTINCT) and _instinct_state == InstinctState.NONE \
				and _can_hold_ball()
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_SHOT:
			return await _use_shot_skill()
		SKILL_STEP:
			return await _use_step_overs()
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
			var bon_text: String = "Chute que sobe a bola, e ela quica só %d vez(es). %d%% de chance de gol." % [
				bon_max_bounces, _pct(chance_bon)]
			var bee_text: String = "Voleio SEM QTE, com %d%% de chance de gol." % _pct(chance_bee)
			match get_shot_variant():
				ShotVariant.BEE:
					title = "Bee Shot"
					text = bee_text
				ShotVariant.BON:
					title = "Bon!"
					text = bon_text
				_:
					title = "Bon! / Bee Shot"
					text = bon_text + "\n" + bee_text
			text += "\nRecarga: %d rodadas." % shot_cooldown
		SKILL_STEP:
			title = "Step Overs"
			text = ("Bachira faz passadas e atordoa inimigos.\n"
				+ "Recarga: %d rodadas.") % [
				step_cooldown]
		SKILL_INSTINCT:
			title = "Unleash Instinct"
			text = ("Com a bola próxima, Bachira a segura. Se alguém chegar perto, ele desvia e ganha %d ação geral extra (vale para tudo, inclusive Correr), e ainda pode desviar mais %d vezes se tentarem tomar a bola de novo." % [
				instinct_extra_generals, instinct_extra_dodges])
			text += "\nRecarga: %d rodadas." % instinct_cooldown
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()
	_end_instinct(true)
	_stunned.clear()
	queue_redraw()


# ---------- LOOP / VISUAL ----------

func _process(delta: float) -> void:
	super(delta)
	# Anel do Instinct e "estrelinhas" nos atordoados giram: precisa redesenhar toda hora
	if _instinct_state != InstinctState.NONE or not _stunned.is_empty():
		queue_redraw()


func _draw() -> void:
	super()
	var center := Vector2(0.0, -height)

	# Anel amarelo-esverdeado enquanto o Unleash Instinct está valendo (segurando a bola)
	if _instinct_state != InstinctState.NONE:
		var pulse: float = 1.0 + 0.1 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
		draw_arc(center, (placeholder_radius + 11.0) * pulse, 0.0, TAU, 32,
			Color(0.8, 1.0, 0.2, 0.9), 2.0)

	# Estrelinhas girando sobre a cabeça de cada inimigo atordoado pelo Step Overs
	var t: float = Time.get_ticks_msec() / 1000.0
	for e in _stunned.keys():
		if not is_instance_valid(e):
			continue
		var head: Vector2 = to_local(e.global_position) + Vector2(0.0, -e.height - e.placeholder_radius - 14.0)
		for i in 3:
			var ang: float = t * 5.0 + TAU * float(i) / 3.0
			var pos: Vector2 = head + Vector2(cos(ang) * 12.0, sin(ang) * 4.0)
			draw_circle(pos, 3.0, Color(1.0, 0.9, 0.25, 0.95))
