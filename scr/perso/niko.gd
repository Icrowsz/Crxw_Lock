class_name Niko
extends Player
## Niko Ikki (verde Blue Lock, com torres e radar: veja niko_fx.gd).
##
## 1. Watchtower (recarga 2, compartilhada; só na DEFESA): QTE fácil e, passando, cria uma torre de vigia fixa onde ele
##    está (alcance 300). Dentro dela os inimigos não usam habilidades. Dura 2 rodadas ou até o Niko sair de perto.
##    - Body Core (variante: enquanto a torre existe; uso único por torre): Niko no chão vai até um inimigo dentro da
##      torre (QTE fácil) e começa a marcá-lo (60%). Ganhando, bloqueia DUAS ações gerais que ele escolhe.
##    - Safe Spots (variante: no ATAQUE, recarga compartilhada com a Watchtower): QTE fácil e, passando, escolhe dois
##      pontos (alcance 600) que viram "portos seguros" de 200 de área: os aliados dentro não podem ser derrubados e
##      têm +5% nos chutes. Duram 2 rodadas.
## 2. Tactical (recarga 2, compartilhada): Niko no chão com a bola no chão. Aliado a até 200 = passe rasteiro curvo;
##    mais longe (até 475) = cruzamento por cima que chega ao aliado no chão. O aliado faz um QTE fácil e, passando,
##    ganha +4% no próximo chute (bússola verde sobre ele até chutar).
##    - Bomber Tact (variante: Niko e bola SUSPENSOS): escolhe dois aliados (500) e cruza para o primeiro, que salta,
##      domina e desce com a bola; QTE fácil do primeiro (+4% no próximo chute). Se o primeiro assistir o segundo, o
##      segundo ganha +5%.
## 3. Def Metavision (recarga 3 depois do fim do efeito): +1 ação de habilidade extra para os secundários; +10% no Body
##    Core, +100 de área e +3% nas Safe Spots, +2% no Tactical e no Bomber Tact. Um radar pequeno sai dele o tempo todo.
##
## Cena: Nova Cena Herdada de player.tscn -> este script no nó raiz -> renomeie o nó para "Niko".
## Animações opcionais: watchtower, body_core, safe_spots, tactical, bomber_tact, metavision.
##
## PEÇAS NO RESTO DO PROJETO: o player.gd precisa do gancho protects_from_knockdown (Safe Spots); está na versão
## atualizada do player.gd que acompanha este arquivo.

const SKILL_TOWER: StringName = &"watchtower"     # também é o id de Body Core e Safe Spots
const SKILL_TACTICAL: StringName = &"tactical"    # também é o id do Bomber Tact
const SKILL_METAVISION: StringName = &"metavision"
const CD_TOWER: StringName = &"cd_watchtower"     # Watchtower e Safe Spots
const CD_TACTICAL: StringName = &"cd_tactical"    # Tactical e Bomber Tact
const CD_METAVISION: StringName = &"cd_metavision"

enum TowerVariant { NONE, WATCHTOWER, BODY_CORE, SAFE_SPOTS }
enum TacticalVariant { NONE, TACTICAL, BOMBER }

@export_group("QTE fácil (Watchtower, Body Core, Safe Spots, Tactical)")
@export var easy_qte_keys: int = 2
@export var easy_qte_time: float = 0.5

@export_group("Watchtower / Body Core")
@export var tower_radius: float = 230.0
@export var tower_rounds: int = 2                 # duração total em rodadas (contando a atual)
@export var tower_cooldown: int = 2               # recarga, contada a partir do fim das rodadas da torre
@export_range(0.0, 1.0) var body_core_win_chance: float = 0.60
@export var body_core_blocked_actions: int = 2    # quantas ações gerais o Niko escolhe bloquear
@export var body_core_rounds: int = 3             # quanto tempo a marcação dura (contando a atual)
@export var body_core_break_distance: float = 120.0   # a marcação acaba se o Niko ficar mais longe que isso
@export var body_core_contact_distance: float = 44.0  # distância entre os dois na hora da disputa
@export var body_core_approach_time: float = 0.45

@export_group("Safe Spots")
@export var safe_spot_range: float = 600.0        # alcance para escolher os dois pontos
@export var safe_spot_radius: float = 120.0
@export var safe_spot_rounds: int = 2             # o documento não dá a duração: igual à Watchtower
@export_range(0.0, 1.0) var safe_spot_shot_bonus: float = 0.05
@export_range(0.3, 1.0) var safe_spot_tower_scale: float = 0.55   # tamanho da torre pequena

@export_group("Tactical / Bomber Tact")
@export var tactical_range: float = 475.0
@export var tactical_ground_max: float = 360.0    # até aqui o passe vai rasteiro; acima, vira cruzamento
@export var tactical_cooldown: int = 2
## Quanto a bola se desvia da reta no passe rasteiro, como fração da distância (0.25 = 25%)
@export_range(0.0, 0.6) var tactical_curve: float = 0.25
@export_range(0.0, 1.0) var tactical_shot_bonus: float = 0.04
@export var cross_rise_time: float = 0.2
@export var cross_fall_time: float = 0.55
@export var bomber_range: float = 500.0
@export_range(0.0, 1.0) var bomber_assist_bonus: float = 0.05

@export_group("Def Metavision")
@export var metavision_rounds: int = 3                          # rodadas depois da atual (igual ao Metavision do Isagi)
@export var metavision_extra_ally_skills: int = 1               # ações de habilidade extras para os Secundários
@export var metavision_cooldown: int = 3                        # recarga, contada a partir do fim do efeito
@export_range(0.0, 1.0) var meta_body_core_bonus: float = 0.10
@export var meta_spot_radius_bonus: float = 100.0
@export_range(0.0, 1.0) var meta_spot_shot_bonus: float = 0.03
@export_range(0.0, 1.0) var meta_tactical_bonus: float = 0.02

@export_group("Visual / Descrição")
@export var kick_fx: KickFX                   # vazio = NikoFX.kick_fx()
## Imagem de cada habilidade no balão do menu. Chaves: watchtower, tactical, metavision.
## Sem imagem, o balão aparece só com o texto.
@export var skill_icons: Dictionary = {}

# ---------- Watchtower ----------
var _tower: NikoFX.Tower = null
var _tower_on: bool = false
var _tower_center: Vector2 = Vector2.ZERO
var _tower_until_round: int = -1

# ---------- Body Core ----------
var _core_target: Player = null
var _core_until_round: int = -1
var _core_blocked: Array[int] = []              # ações gerais (MatchManager.GeneralAction) bloqueadas no alvo
var _core_used: bool = false                    # uso único por Watchtower

# ---------- Safe Spots ----------
var _spot_centers: Array[Vector2] = []
var _spot_fx: Array[NikoFX.Tower] = []
var _spots_until_round: int = -1

# ---------- Tactical / Bomber Tact ----------
var _marks: Dictionary = {}                     # aliado -> NikoFX.Mark (bússola enquanto ele tem o bônus)
var _bomber_first: Player = null
var _bomber_second: Player = null

# ---------- Metavision ----------
var _metavision_until_round: int = -1
var _meta_was_active: bool = false
var _radar: NikoFX.Radar = null

# ---------- Texto flutuante (resultado da disputa) ----------
var _popup_text: String = ""
var _popup_color: Color = Color.WHITE
var _popup_left: float = 0.0


func _init() -> void:
	character_id = "niko"           # o menu de formação usa isto para saber quem é quem
	display_name = "Niko Ikki"      # aparece no placar de gols e no menu


func _ready() -> void:
	super()
	add_to_group("control_sources")  # os outros perguntam por aqui se estão bloqueados / protegidos
	if kick_fx == null:
		kick_fx = NikoFX.kick_fx()
	_radar = NikoFX.make_radar()
	add_child(_radar)
	_hook_manager.call_deferred()    # o MatchManager entra na árvore no mesmo frame


func _exit_tree() -> void:
	_end_tower()
	_end_spots()
	_clear_marks()


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m:
		m.pass_completed.connect(_on_pass_completed)
		m.turn_ended.connect(_on_turn_ended)
		m.round_started.connect(_on_round_started)


## O primeiro aliado do Bomber Tact assistiu o segundo: o segundo ganha o bônus de assistência
func _on_pass_completed(passer: Player, target: Player) -> void:
	if _bomber_first != null and passer == _bomber_first and target == _bomber_second:
		_mark_ally(target, bomber_assist_bonus + _meta_tactical_extra())
		_bomber_first = null
		_bomber_second = null


## A assistência do Bomber Tact só vale no turno em que o cruzamento aconteceu
func _on_turn_ended(ended_team: int) -> void:
	if ended_team == team:
		_bomber_first = null
		_bomber_second = null


func _on_round_started(new_round: int) -> void:
	if _spots_until_round >= 0 and new_round > _spots_until_round:
		_end_spots()


# ---------- AUXILIARES ----------

func _body_point() -> Vector2:
	return global_position + Vector2(0.0, -height)


## Lado do campo em que o Niko está AGORA (metade do próprio gol; considera a troca de lado do 2º tempo)
func _is_defense_side() -> bool:
	var field := get_tree().get_first_node_in_group("field") as Field
	var x: float = global_position.x if field == null else field.to_local(global_position).x
	return x * get_attack_dir() < 0.0


## QTE fácil de uma tecla ou duas. Quem pula QTE (skips_qte) passa direto.
func _easy_qte(title: String) -> bool:
	var m: MatchManager = _get_manager()
	if m == null or skips_qte():
		return true
	var qte := QTE.new()
	m.add_child(qte)
	qte.start(QTE.EASY_KEYS, easy_qte_keys, easy_qte_time, title)
	var ok: bool = await qte.finished
	return ok


## Companheiros (menos o Niko e os derrubados) a até range_px
func _allies_within(range_px: float) -> Array[Player]:
	var list: Array[Player] = []
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other != self and other.team == team and not other.is_down \
				and global_position.distance_to(other.global_position) <= range_px:
			list.append(other)
	return list


func _ball_arrived(ball: Ball, to: Player) -> bool:
	return ball.global_position.distance_to(to.global_position) <= to.body_radius + ball.collision_radius + 10.0


func _meta_tactical_extra() -> float:
	return meta_tactical_bonus if is_metavision_active() else 0.0


## O aliado ganha +X% no próximo chute (a bússola some quando ele chutar e gastar o bônus)
func _mark_ally(ally: Player, bonus: float) -> void:
	ally.next_shot_bonus = maxf(ally.next_shot_bonus, bonus)
	var old: Variant = _marks.get(ally)
	if old != null and is_instance_valid(old):
		old.release()
	_marks[ally] = NikoFX.mark(ally)
	NikoFX.ping(self, ally.global_position, 46.0, 0.45)
	NikoFX.blips(self, ally.global_position + Vector2(0.0, -ally.height - 20.0), 8)


func _clear_marks() -> void:
	for key in _marks.keys():
		var m: Variant = _marks[key]
		if m != null and is_instance_valid(m):
			m.release()
	_marks.clear()


func _show_popup(text: String, color: Color) -> void:
	_popup_text = text
	_popup_color = color
	_popup_left = 1.4
	queue_redraw()


# ---------- HABILIDADE 1: WATCHTOWER / BODY CORE / SAFE SPOTS ----------

func _tower_variant() -> TowerVariant:
	if is_down:
		return TowerVariant.NONE
	if is_tower_active():
		return TowerVariant.BODY_CORE
	return TowerVariant.WATCHTOWER if _is_defense_side() else TowerVariant.SAFE_SPOTS


## A torre existe agora? Confere (e encerra) sozinha: acabou o tempo ou o Niko saiu do alcance.
func is_tower_active() -> bool:
	if not _tower_on:
		return false
	var m: MatchManager = _get_manager()
	var alive: bool = m != null and m.round_number <= _tower_until_round \
		and global_position.distance_to(_tower_center) <= tower_radius
	if not alive:
		_end_tower()
	return alive


func _tower_contains(pos: Vector2) -> bool:
	return pos.distance_to(_tower_center) <= tower_radius


func _end_tower() -> void:
	_tower_on = false   # o Body Core já aplicado segue valendo: ele só acaba por rodadas ou distância
	if _tower and is_instance_valid(_tower):
		_tower.disappear()
	_tower = null
	queue_redraw()


## Chamado pelo Player de quem está sendo checado: "este adversário está proibido de usar habilidades?"
func suppresses_skills_of(p: Player) -> bool:
	return is_tower_active() and p.team != team and _tower_contains(p.global_position)


## QTE fácil e, passando, a torre aparece onde o Niko está
func _use_watchtower() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	if not await _easy_qte("Torre!"):
		_show_popup("Falhou", Color(1.0, 0.6, 0.5))
		return true   # errou o QTE: gastou a ação e não cria a torre
	if not await play_action(&"watchtower"):   # a torre aparece no frame de impacto
		return false

	_tower_center = global_position
	_tower_until_round = m.round_number + tower_rounds - 1   # a rodada atual conta
	_core_used = false
	start_cooldown(CD_TOWER, tower_cooldown, _tower_until_round + 1)
	_tower = NikoFX.tower(self, _tower_center, tower_radius)
	_tower_on = true
	NikoFX.ping(self, _tower_center, tower_radius * 0.5, 0.6)
	return true


# ---------- BODY CORE (variante da Watchtower) ----------

## Inimigos que dá para escolher: os que estão dentro da torre
func _valid_core_targets() -> Array[Player]:
	var list: Array[Player] = []
	if not is_tower_active():
		return list
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other.team != team and not other.is_down and _tower_contains(other.global_position):
			list.append(other)
	return list


func is_body_core_active() -> bool:
	if _core_target == null:
		return false
	var m: MatchManager = _get_manager()
	var alive: bool = is_instance_valid(_core_target) and m != null \
		and m.round_number <= _core_until_round \
		and global_position.distance_to(_core_target.global_position) <= body_core_break_distance
	if not alive:
		_clear_body_core()
	return alive


func _clear_body_core() -> void:
	_core_target = null
	_core_until_round = -1
	_core_blocked.clear()
	queue_redraw()


## Chamado pelo Player de quem está sendo checado: "esta ação geral foi tirada deste adversário?"
func blocks_general_action(p: Player, action: int) -> bool:
	return is_body_core_active() and p == _core_target and action in _core_blocked


func _core_win_chance() -> float:
	return clampf(body_core_win_chance + (meta_body_core_bonus if is_metavision_active() else 0.0), 0.0, 1.0)


func _use_body_core() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false

	# O círculo de seleção seria de 2x o raio da torre (para alcançar qualquer inimigo dentro
	# dela) e atrapalharia a leitura: some logo depois de ser desenhado. A torre já mostra o alcance.
	_hide_own_range_preview.call_deferred()
	var in_tower := func(other: Player) -> bool:
		return _tower_contains(other.global_position) and not other.is_down
	var target: Player = await m.pick_ally_for_skill(self, tower_radius * 2.0, true, in_tower)
	if target == null:
		return false   # cancelou: não gasta a ação

	# Aproxima do inimigo (parando ao lado dele; o caminho fica sempre dentro da torre)
	face_towards(target.global_position - global_position)
	var away: Vector2 = global_position - target.global_position
	var dist: float = away.length()
	if dist > body_core_contact_distance:
		var contact_point: Vector2 = target.global_position + away / dist * body_core_contact_distance
		var tw := create_tween()
		tw.tween_property(self, "global_position", contact_point, body_core_approach_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tw.finished

	_core_used = true   # uso único por Watchtower (gasta mesmo se errar)
	face_towards(target.global_position - global_position)
	if not await _easy_qte("Marcação!"):
		_show_popup("Falhou", Color(1.0, 0.6, 0.5))
		return true
	if not await play_action(&"body_core"):
		return false

	# Começa a marcar: 60% (+10% com a Def Metavision)
	if randf() < _core_win_chance():
		var options: Array[int] = [MatchManager.GeneralAction.RUN, MatchManager.GeneralAction.JUMP,
			MatchManager.GeneralAction.SLIDE, MatchManager.GeneralAction.SHOOT, MatchManager.GeneralAction.PASS]
		var chosen: Array = await _ActionPicker.pick(self, options, body_core_blocked_actions)
		_core_blocked.clear()
		for a in chosen:
			_core_blocked.append(int(a))
		_core_target = target
		_core_until_round = m.round_number + body_core_rounds - 1   # a rodada atual conta
		_show_popup("BODY CORE!", Color(0.5, 1.0, 0.6))
		NikoFX.ping(self, target.global_position, 56.0, 0.5)
		NikoFX.blips(self, target.global_position + Vector2(0.0, -target.height - 14.0), 10)
	else:
		_show_popup("Perdeu a disputa", Color(1.0, 0.6, 0.5))
	queue_redraw()
	await get_tree().create_timer(0.6).timeout   # tempo de ler o resultado
	return true


func _hide_own_range_preview() -> void:
	range_preview = 0.0


# ---------- SAFE SPOTS (variante da Watchtower, no ataque) ----------

func is_safe_spots_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _spots_until_round >= 0 and m.round_number <= _spots_until_round


func _spot_radius() -> float:
	return safe_spot_radius + (meta_spot_radius_bonus if is_metavision_active() else 0.0)


func _spot_shot_bonus() -> float:
	return safe_spot_shot_bonus + (meta_spot_shot_bonus if is_metavision_active() else 0.0)


func _in_safe_spot(pos: Vector2) -> bool:
	if not is_safe_spots_active():
		return false
	for center: Vector2 in _spot_centers:
		if pos.distance_to(center) <= _spot_radius():
			return true
	return false


func _end_spots() -> void:
	for fx: NikoFX.Tower in _spot_fx:
		if fx != null and is_instance_valid(fx):
			fx.disappear()
	_spot_fx.clear()
	_spot_centers.clear()
	_spots_until_round = -1


## Aliados dentro de um porto seguro não podem ser derrubados (o Player pergunta por aqui em knock_down)
func protects_from_knockdown(p: Player) -> bool:
	return p.team == team and _in_safe_spot(p.global_position)


## +5% (+3% com a Def Metavision) nos chutes dos companheiros dentro de um porto seguro
func shot_bonus_for_ally(shooter: Player, _ball: Ball) -> float:
	if shooter.team == team and _in_safe_spot(shooter.global_position):
		return _spot_shot_bonus()
	return 0.0


## O Niko dentro de um porto seguro também ganha o bônus nos próprios chutes
func get_shot_chance(kind: KickType) -> float:
	var base: float = super(kind)
	if _in_safe_spot(global_position):
		base += _spot_shot_bonus()
	return base


## QTE fácil e, passando, escolhe dois pontos no alcance de 600: as torres pequenas aparecem
func _use_safe_spots() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	if not await _easy_qte("Portos seguros!"):
		_show_popup("Falhou", Color(1.0, 0.6, 0.5))
		return true   # errou o QTE: gastou a ação e não cria os pontos

	var first: Vector2 = await m.pick_point_for_skill(self, safe_spot_range)
	if first == Vector2.INF:
		return false   # cancelou: não gasta a ação
	var preview: NikoFX.Tower = NikoFX.tower(self, first, _spot_radius(), safe_spot_tower_scale)   # o 1º já aparece
	var second: Vector2 = await m.pick_point_for_skill(self, safe_spot_range)
	if second == Vector2.INF:
		if preview != null and is_instance_valid(preview):
			preview.disappear()
		return false
	if not await play_action(&"safe_spots"):
		if preview != null and is_instance_valid(preview):
			preview.disappear()
		return false

	_end_spots()
	_spot_centers = [first, second]
	_spot_fx = [preview, NikoFX.tower(self, second, _spot_radius(), safe_spot_tower_scale)]
	_spots_until_round = m.round_number + safe_spot_rounds - 1   # a rodada atual conta
	start_cooldown(CD_TOWER, tower_cooldown, _spots_until_round + 1)
	NikoFX.ping(self, first, _spot_radius() * 0.5, 0.6)
	NikoFX.ping(self, second, _spot_radius() * 0.5, 0.6)
	return true


# ---------- HABILIDADE 2: TACTICAL / BOMBER TACT ----------

## Alcance do passe: 475 + bônus de alcance de passe vindo de outros jogadores (ex: Orbital Orbital)
func _tactical_range() -> float:
	return tactical_range + pass_range_bonus


func _tactical_variant() -> TacticalVariant:
	var ball: Ball = _get_ball()
	if is_down or ball == null or get_kick_type(ball) == KickType.NONE:
		return TacticalVariant.NONE
	if height_level == Heights.Level.GROUND and ball.get_level() == Heights.Level.GROUND \
			and not _allies_within(_tactical_range()).is_empty():
		return TacticalVariant.TACTICAL
	if height_level == Heights.Level.SUSPENDED and ball.get_level() == Heights.Level.SUSPENDED \
			and _allies_within(bomber_range).size() >= 2:
		return TacticalVariant.BOMBER
	return TacticalVariant.NONE


## Cruzamento: a bola sobe a Voando no meio do caminho e chega ao aliado no nível pedido
## (no chão: Tactical; suspensa: Bomber Tact). Devolve false se a partida acabou no meio.
func _cross_to(m: MatchManager, ball: Ball, target: Player, end_height: float) -> bool:
	ball.register_touch(self)   # o cruzamento não usa kick(), então registra o toque aqui
	m.clear_pending_pass()
	if kick_fx:
		ball.fx_during_hover = true
		ball.play_fx(kick_fx)
	var start: Vector2 = ball.global_position
	var to_target: Vector2 = target.global_position - start
	var dist: float = to_target.length()
	var gap: float = ball.collision_radius + target.body_radius + 2.0   # a bola chega ENCOSTANDO no alvo
	var end_point: Vector2 = start
	if dist > 0.001:
		end_point = start + to_target / dist * maxf(dist - gap, 0.0)
	var rise: Tween = ball.hover_to((start + end_point) * 0.5, Heights.FLYING_HEIGHT, cross_rise_time)
	await rise.finished
	var fall: Tween = ball.hover_to(end_point, end_height, cross_fall_time)
	await fall.finished
	if end_height <= Heights.GROUND_HEIGHT + 0.5:
		ball.release_hover()
		ball.velocity = Vector2.ZERO
		ball.vel_z = 0.0
		ball.height = 0.0
		ball.fx_during_hover = false
		ball.register_touch(self)
	m.pass_completed.emit(self, target)
	return not m.match_over


func _use_tactical() -> bool:
	if _tactical_variant() == TacticalVariant.BOMBER:
		return await _use_bomber_tact()
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false
	var target: Player = await m.pick_ally_for_skill(self, _tactical_range())
	if target == null:
		return false   # cancelou: não gasta a ação
	if _tactical_variant() != TacticalVariant.TACTICAL:
		return false   # a bola rolou enquanto ele escolhia o alvo

	start_cooldown(CD_TACTICAL, tactical_cooldown)
	if global_position.distance_to(target.global_position) <= tactical_ground_max:
		# Até 200: passe rasteiro curvo (como sempre foi o Tactical)
		var bend: float = _best_curve_side(ball.global_position, target.global_position)
		await m.run_curved_ground_pass(self, target, ball, tactical_curve, bend, &"tactical", kick_fx)
	else:
		# Acima disso: cruzamento por cima, que chega ao aliado no chão
		face_towards(target.global_position - global_position)
		if not await play_action(&"tactical", ANIM_PASS_HIGH):
			return true
		if not await _cross_to(m, ball, target, Heights.GROUND_HEIGHT):
			return true
	if not _ball_arrived(ball, target):
		return true   # interceptado: ninguém recebe a bola
	# O aliado faz um QTE fácil na hora de receber: passando, ganha +4% no próximo chute
	if await _easy_qte("Recepção!"):
		_mark_ally(target, tactical_shot_bonus + _meta_tactical_extra())
	return true


## Escolhe para que lado a bola faz a curva: o lado em que ela passa mais longe dos adversários no chão
func _best_curve_side(from: Vector2, to: Vector2) -> float:
	var best_side: float = 1.0
	var best_clearance: float = -1.0
	for side: float in [1.0, -1.0]:
		var control: Vector2 = MatchManager.curve_control_point(from, to, tactical_curve, side)
		var clearance: float = INF
		for i in range(1, 20):
			var pt: Vector2 = MatchManager.curve_point(from, control, to, float(i) / 20.0)
			for other: Player in get_tree().get_nodes_in_group("players"):
				if other.team == team or other.is_down or other.height_level != Heights.Level.GROUND:
					continue
				clearance = minf(clearance, pt.distance_to(other.global_position))
		if clearance > best_clearance:
			best_clearance = clearance
			best_side = side
	return best_side


## Bomber Tact: cruza para o 1º aliado, que salta, domina e desce com a bola; QTE fácil dele; assistência para o 2º
func _use_bomber_tact() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false
	var first: Player = await m.pick_ally_for_skill(self, bomber_range)
	if first == null:
		return false   # cancelou: não gasta a ação
	var not_first := func(other: Player) -> bool:
		return other != first and not other.is_down
	var second: Player = await m.pick_ally_for_skill(self, bomber_range, false, not_first)
	if second == null or _tactical_variant() != TacticalVariant.BOMBER:
		return false

	start_cooldown(CD_TACTICAL, tactical_cooldown)
	face_towards(first.global_position - global_position)
	if not await play_action(&"bomber_tact", ANIM_PASS_HIGH):
		return true
	# A bola chega SUSPENSA no primeiro...
	if not await _cross_to(m, ball, first, Heights.SUSPENDED_HEIGHT):
		return true
	# ...que salta, domina e desce com ela
	first.height_level = Heights.Level.SUSPENDED
	var up := create_tween()
	up.tween_property(first, "height", Heights.SUSPENDED_HEIGHT, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await up.finished
	var down := create_tween()
	down.tween_property(first, "height", Heights.GROUND_HEIGHT, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var settle: Tween = ball.hover_to(first.global_position, Heights.GROUND_HEIGHT, 0.35)
	await down.finished
	first.land()
	if settle.is_valid() and settle.is_running():
		await settle.finished
	ball.release_hover()
	ball.velocity = Vector2.ZERO
	ball.vel_z = 0.0
	ball.height = 0.0
	ball.fx_during_hover = false
	ball.register_touch(first)
	NikoFX.ping(self, first.global_position, 50.0, 0.45)

	if await _easy_qte("Domínio!"):
		_mark_ally(first, tactical_shot_bonus + _meta_tactical_extra())
	_bomber_first = first      # se o primeiro assistir o segundo neste turno, o segundo ganha +5%
	_bomber_second = second
	return true


# ---------- HABILIDADE 3: DEF METAVISION ----------

func is_metavision_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _metavision_until_round >= 0 and m.round_number <= _metavision_until_round


func _use_metavision() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	_metavision_until_round = m.round_number + metavision_rounds
	start_cooldown(CD_METAVISION, metavision_cooldown, _metavision_until_round + 1)
	m.secondary_skill_left += metavision_extra_ally_skills
	NikoFX.ping(self, global_position, 90.0, 0.7)
	NikoFX.blips(self, _body_point(), 14)
	queue_redraw()
	return true


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func _tower_name() -> String:
	match _tower_variant():
		TowerVariant.BODY_CORE:
			if is_body_core_active():
				return "Body Core (ativo)"
			return "Body Core (usado)" if _core_used else "Body Core"
		TowerVariant.SAFE_SPOTS:
			return skill_label("Safe Spots", CD_TOWER)
	return skill_label("Watchtower", CD_TOWER)


func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"id": SKILL_TOWER, "name": _tower_name()})
	var tactical_name: String = "Bomber Tact" if _tactical_variant() == TacticalVariant.BOMBER else "Tactical"
	list.append({"id": SKILL_TACTICAL, "name": skill_label(tactical_name, CD_TACTICAL)})
	var meta_name: String = "Def Metavision (ativa)" if is_metavision_active() \
		else skill_label("Def Metavision", CD_METAVISION)
	list.append({"id": SKILL_METAVISION, "name": meta_name})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_TOWER:
			match _tower_variant():
				TowerVariant.BODY_CORE:
					return not _core_used and not is_body_core_active() \
						and height_level == Heights.Level.GROUND and not _valid_core_targets().is_empty()
				TowerVariant.WATCHTOWER:
					return not is_on_cooldown(CD_TOWER)
				TowerVariant.SAFE_SPOTS:
					return not is_on_cooldown(CD_TOWER) and not is_safe_spots_active()
			return false
		SKILL_TACTICAL:
			return not is_on_cooldown(CD_TACTICAL) and _tactical_variant() != TacticalVariant.NONE
		SKILL_METAVISION:
			return not is_metavision_active() and not is_on_cooldown(CD_METAVISION)
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_TOWER:
			match _tower_variant():
				TowerVariant.BODY_CORE:
					return await _use_body_core()
				TowerVariant.SAFE_SPOTS:
					return await _use_safe_spots()
			return await _use_watchtower()
		SKILL_TACTICAL:
			return await _use_tactical()
		SKILL_METAVISION:
			if not await play_action(&"metavision"):
				return false
			return _use_metavision()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_TOWER:
			match _tower_variant():
				TowerVariant.BODY_CORE:
					title = "Body Core"
					text = ("Niko vai até um inimigo dentro da torre (QTE fácil) e começa a marcá-lo (%d%% de chance). Ganhando, "
						+ "bloqueia %d ações gerais que você escolher.\nUso único durante a Watchtower.") % [
						_pct(_core_win_chance()), body_core_blocked_actions]
				TowerVariant.SAFE_SPOTS:
					title = "Safe Spots"
					text = ("QTE fácil e, passando, escolha dois pontos (alcance %d). Eles viram portos seguros de %d de área: aliados "
						+ "dentro não podem ser derrubados e têm +%d%% nos chutes. Duram %d rodadas.\nRecarga: %d rodadas.") % [
						int(safe_spot_range), int(_spot_radius()), _pct(_spot_shot_bonus()), safe_spot_rounds, tower_cooldown]
				_:
					title = "Watchtower"
					text = ("QTE fácil e, passando, cria uma torre onde Niko está (alcance %d): dentro do círculo, os inimigos não podem "
						+ "usar habilidades. Dura %d rodadas ou até Niko sair de perto.\nRecarga: %d rodadas.") % [
						int(tower_radius), tower_rounds, tower_cooldown]
		SKILL_TACTICAL:
			if _tactical_variant() == TacticalVariant.BOMBER:
				title = "Bomber Tact"
				text = ("Escolha dois aliados (%d): cruza para o primeiro, que salta, domina e desce com a bola. QTE fácil dele: +%d%% no "
					+ "próximo chute. Se ele assistir o segundo, o segundo ganha +%d%%.\nRecarga: %d rodadas.") % [
					int(bomber_range), _pct(tactical_shot_bonus + _meta_tactical_extra()),
					_pct(bomber_assist_bonus + _meta_tactical_extra()), tactical_cooldown]
			else:
				title = "Tactical"
				text = ("Aliado a até %d: passe rasteiro curvo. Mais longe (até %d): cruzamento que chega nele no chão. Ele faz um QTE "
					+ "fácil e, passando, ganha +%d%% no próximo chute.\nRecarga: %d rodadas.") % [
					int(tactical_ground_max), int(tactical_range), _pct(tactical_shot_bonus + _meta_tactical_extra()), tactical_cooldown]
		SKILL_METAVISION:
			title = "Def Metavision"
			text = ("Por %d rodadas: +%d ação de habilidade extra para os aliados, +%d%% no Body Core, +%d de área e +%d%% nas Safe Spots e "
				+ "+%d%% no Tactical e no Bomber Tact.\nRecarga: %d rodadas após o fim.") % [
				metavision_rounds, metavision_extra_ally_skills, _pct(meta_body_core_bonus), int(meta_spot_radius_bonus),
				_pct(meta_spot_shot_bonus), _pct(meta_tactical_bonus), metavision_cooldown]
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()
	_end_tower()
	_tower_until_round = -1
	_core_used = false
	_clear_body_core()
	_end_spots()
	_clear_marks()
	_bomber_first = null
	_bomber_second = null
	_metavision_until_round = -1
	_popup_left = 0.0
	queue_redraw()


# ---------- LOOP / VISUAL ----------

func _process(delta: float) -> void:
	super(delta)
	# Confere a cada frame: a torre acaba no instante em que o Niko sai do alcance, e o
	# Body Core no instante em que ele se afasta do alvo (e não voltam se ele retornar)
	is_tower_active()
	var core: bool = is_body_core_active()
	# Radar pequeno saindo do Niko durante a Def Metavision
	var meta: bool = is_metavision_active()
	if _radar != null and _radar.active != meta:
		_radar.active = meta
	# A Def Metavision muda a área das Safe Spots na hora (+100)
	if meta != _meta_was_active:
		_meta_was_active = meta
		for fx: NikoFX.Tower in _spot_fx:
			if fx != null and is_instance_valid(fx):
				fx.set_radius(_spot_radius())
	# A bússola some do aliado assim que ele gasta o bônus (chutou)
	for key in _marks.keys():
		var ally: Player = key as Player if is_instance_valid(key) else null
		if ally == null or ally.next_shot_bonus <= 0.0:
			var fx_mark: Variant = _marks[key]
			if fx_mark != null and is_instance_valid(fx_mark):
				fx_mark.release()
			_marks.erase(key)
	if _popup_left > 0.0:
		_popup_left -= delta
	if core or _popup_left > 0.0:
		queue_redraw()


func _draw() -> void:
	super()
	var center := Vector2(0.0, -height)

	# Body Core ativo: linha até o alvo + anel tracejado verde nele
	if _core_target != null and is_instance_valid(_core_target):
		var t: Vector2 = to_local(_core_target.global_position) + Vector2(0.0, -_core_target.height)
		draw_line(center, t, Color(0.4, 1.0, 0.6, 0.5), 2.0)
		var segments: int = 12
		for i in segments:
			if i % 2 == 0:
				var a0: float = TAU * float(i) / float(segments)
				var a1: float = TAU * float(i + 1) / float(segments)
				draw_arc(t, _core_target.placeholder_radius + 12.0, a0, a1, 6, Color(0.4, 1.0, 0.6, 0.95), 3.0)

	# Resultado da disputa, flutuando em cima do Niko
	if _popup_left > 0.0:
		var alpha: float = clampf(_popup_left / 0.4, 0.0, 1.0)
		var y: float = -placeholder_radius - 46.0 - height - (1.4 - _popup_left) * 10.0
		draw_string(ThemeDB.fallback_font, Vector2(-100.0, y), _popup_text,
			HORIZONTAL_ALIGNMENT_CENTER, 200.0, 20, Color(_popup_color, alpha))


# ====================================================================
# Escolha das ações gerais bloqueadas pelo Body Core
# ====================================================================

## Janelinha verde: o jogador marca N ações gerais e confirma. Devolve a lista (MatchManager.GeneralAction como int).
class _ActionPicker extends CanvasLayer:
	signal done(chosen: Array)

	var options: Array[int] = []
	var need: int = 2
	var _selected: Array[int] = []
	var _buttons: Dictionary = {}
	var _confirm: Button
	var _hint: Label

	static func pick(host: Node, option_list: Array[int], count: int) -> Array:
		var picker := _ActionPicker.new()
		picker.options = option_list
		picker.need = count
		var scene: Node = host.get_tree().current_scene
		(scene if scene != null else host).add_child(picker)
		var chosen: Array = await picker.done
		picker.queue_free()
		return chosen

	func _ready() -> void:
		layer = 100
		process_mode = Node.PROCESS_MODE_ALWAYS
		var root := Control.new()
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(root)
		var dim := ColorRect.new()
		dim.color = Color(0.0, 0.0, 0.0, 0.55)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(dim)   # bloqueia cliques no jogo por trás
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(center)

		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.1, 0.07, 0.96)
		style.border_color = Color(NikoFX.GREEN, 0.9)
		style.set_border_width_all(2)
		style.set_corner_radius_all(14)
		style.set_content_margin_all(22)
		panel.add_theme_stylebox_override("panel", style)
		center.add_child(panel)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 14)
		panel.add_child(box)
		var title := Label.new()
		title.text = "BODY CORE"
		title.add_theme_font_size_override("font_size", 26)
		title.add_theme_color_override("font_color", NikoFX.GREEN)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)
		_hint = Label.new()
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint.add_theme_color_override("font_color", NikoFX.LIGHT_GREEN)
		box.add_child(_hint)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(row)
		for action in options:
			var b := Button.new()
			b.text = MatchManager.GENERAL_ACTION_NAMES[action]
			b.toggle_mode = true
			b.custom_minimum_size = Vector2(110.0, 48.0)
			b.toggled.connect(_on_toggled.bind(action))
			row.add_child(b)
			_buttons[action] = b

		_confirm = Button.new()
		_confirm.text = "Confirmar"
		_confirm.custom_minimum_size = Vector2(0.0, 44.0)
		_confirm.pressed.connect(func() -> void: done.emit(_selected.duplicate()))
		box.add_child(_confirm)
		_refresh()

	func _on_toggled(on: bool, action: int) -> void:
		if on:
			_selected.append(action)
			while _selected.size() > need:   # passou do limite: solta a escolha mais antiga
				var oldest: int = _selected.pop_front()
				(_buttons[oldest] as Button).set_pressed_no_signal(false)
		else:
			_selected.erase(action)
		_refresh()

	func _refresh() -> void:
		_hint.text = "Escolha %d ações gerais para bloquear (%d/%d)" % [need, _selected.size(), need]
		_confirm.disabled = _selected.size() != need
