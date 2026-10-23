class_name Kaiser
extends Player
## Michael Kaiser. Herda tudo do Player (ações gerais) e adiciona as habilidades próprias:
##
## 1. Magnus (ação de habilidade, 3 variantes automáticas pela altura; recarga de 2 rodadas,
##      compartilhada entre as variantes):
##      - Bola no chão + Kaiser no chão ou suspenso -> Magnus: chute curvo; a bola sobe
##        suavemente até o nível Suspenso durante a trajetória
##      - Kaiser suspenso + bola Voando             -> Beinschuss: bicicleta com QTE difícil
##      - Kaiser suspenso + bola Suspensa           -> Kaiser Impact: chute reto e rápido, a
##        bola vai Suspensa durante todo o trajeto
## 2. Empire (ação de habilidade): marca aliados no alcance como servos, pela partida inteira.
##      A 1ª escolha vira o Servo Garçom (flor dourada): chutes do Kaiser com passe/assistência
##      dele ganham +% de chance. A 2ª vira o Servo Palhaço (flor azul-escura): libera o
##      Auf die Knee. Cancelar a 2ª escolha marca só o Garçom. Cada GOL do Kaiser dá +1 uso.
##    Auf die Knee (botão próprio, recarga de 3 rodadas): se a bola está perto de um Palhaço
##      e o Kaiser está ao alcance do passe dele, o Palhaço passa rasteiro para o Kaiser.
##      Gasta a ação de habilidade do Kaiser E uma ação geral do Palhaço (a pool dele).
## 3. Blue Rose (2 botões, uma variante por vez; dura 3 rodadas contando a atual; recarga de
##      2 rodadas a partir do fim do efeito; a mesma variante no máximo 2 vezes seguidas):
##      - Predator: Chutar mais forte, Carrinho mais longo e +% em qualquer chute do Kaiser
##      - Meta: +1 ação de habilidade para os Secundários nas próximas 2 rodadas, nenhum QTE
##        para o Kaiser e mais segundos no Correr
##
## Reação Química HERBIVICUS (com o Ness, veja reaction_herbivicus.gd): se o Ness (Servo Garçom) acabou
## de usar o Alohomora no Kaiser e há um inimigo perto, o Kaiser Impact vira o Emperor Impact:
## cutscene, mais forte e rápido, 75% de chance e uma rosa azul gigante no chute.
##
## Reação Química SUPERSTAR (com a Kiyora, veja reaction_superstar.gd): se a Kiyora (Servo Garçom) acabou
## de usar o Borderline / Even the Gods e a bola veio para o Kaiser, o chute dele vira o BE LOVED:
## um Magnus mais forte, com 85% de chance de gol e uma trilha de rosas azuis. Com a
## reação de pé o Be Loved vale com a bola em qualquer altura que ele alcance (o passe alto sempre
## entrega a bola Suspensa). Recarga da reação: 12 rodadas.
##
## Como montar a cena: Nova Cena Herdada de player.tscn -> anexe este script ao nó raiz
## -> renomeie o nó raiz para "Kaiser".
##
## Animações opcionais (SpriteFrames; hit_frames diz o frame de impacto de cada uma):
## "magnus", "beinschuss", "kaiser_impact", "empire", "blue_rose". Sem elas, nada quebra.
##
## REQUISITO: o kick_ball() do player.gd precisa do parâmetro on_kick (veja a conversa).

const SKILL_SHOT: StringName = &"magnus"
const SKILL_EMPIRE: StringName = &"empire"
const SKILL_KNEE: StringName = &"auf_die_knee"
const SKILL_PREDATOR: StringName = &"predator"
const SKILL_META: StringName = &"meta"

## id da reação Superstar (reaction_superstar.gd)
const SUPERSTAR_ID: StringName = &"superstar"

## Grupos de recarga (as 3 variantes do chute compartilham o mesmo)
const CD_SHOT: StringName = &"cd_shot"
const CD_KNEE: StringName = &"cd_knee"
const CD_ROSE: StringName = &"cd_blue_rose"

enum ShotVariant { NONE, MAGNUS, BEINSCHUSS, IMPACT }
enum ServantType { WAITER, CLOWN }

@export_group("Magnus / Beinschuss / Kaiser Impact")
@export_range(0.0, 1.0) var chance_magnus: float = 0.40
@export_range(0.0, 1.0) var chance_beinschuss: float = 0.55
@export_range(0.0, 1.0) var chance_impact: float = 0.45
@export var shot_cooldown: int = 2                  # recarga (rodadas), igual para as 3 variantes
## Magnus: a bola sai desviada deste ângulo e vai curvando de volta, cruzando a linha da mira
@export var magnus_bend_deg: float = 28.0
## +1 / -1 escolhe para que lado a bola faz a curva
@export var magnus_bend_sign: float = -1.0
## Tamanho máximo da linha tracejada da mira do Magnus (px)
@export var magnus_preview_length: float = 600.0
## Quanto tempo a bola é conduzida (curva + subida até o nível Suspenso); depois cai normal
@export var magnus_flight_time: float = 0.9
## Kaiser Impact: multiplicador de força (rápido) e por quanto tempo a bola fica Suspensa
@export var impact_force_mult: float = 1.1
@export var impact_flight_time: float = 0.2

@export_group("Emperor Impact (reação Herbivicus)")
@export_range(0.0, 1.0) var chance_emperor: float = 0.8   # chance de gol (já é o valor final)
@export var emperor_force_mult: float = 1.9               # mais forte que o Kaiser Impact (1.1)
@export var emperor_flight_time: float = 0.3               # tempo Suspensa (o Kaiser Impact usa 0.2)
@export var emperor_rose_radius: float = 260.0             # tamanho da rosa gigante (px)
## Aura do chute. Vazio = usa o estilo padrão (veja _make_emperor_fx)
@export var emperor_fx: KickFX

@export_group("Be Loved (reação Superstar)")
@export_range(0.0, 1.0) var chance_be_loved: float = 0.85   # chance de gol (já é o valor final)
@export var be_loved_force_mult: float = 1.3               # mais forte que o Magnus (1.0)
## Quanto tempo a bola é conduzida na curva (o Magnus usa magnus_flight_time)
@export var be_loved_flight_time: float = 1.0
## Aura do chute. Vazio = usa o estilo padrão (veja _make_be_loved_fx)
@export var be_loved_fx: KickFX

@export_group("Empire")
@export var empire_range: float = 450.0             # alcance para marcar os servos
@export var empire_starting_uses: int = 1           # usos no começo da partida (+1 a cada gol dele)
@export_range(0.0, 1.0) var waiter_bonus: float = 0.07   # +7% no chute com passe/assistência do Garçom
@export var knee_cooldown: int = 3                  # recarga do Auf die Knee

@export_group("Blue Rose")
@export var rose_rounds: int = 3                    # duração total em rodadas (contando a atual)
@export var rose_cooldown: int = 2                  # recarga, contada a partir do fim do efeito
@export var rose_max_repeat: int = 2                # a mesma variante no máximo X vezes seguidas
@export_range(0.0, 1.0) var predator_shot_bonus: float = 0.08   # +8% em qualquer chute
@export var predator_force_mult: float = 1.3        # força do Chutar comum
@export_range(0.0, 1.0) var predator_slide_bonus: float = 0.2   # +20% na distância do Carrinho
@export var meta_ally_rounds: int = 2               # rodadas (depois da atual) com a ação extra
@export var meta_extra_ally_skills: int = 1         # ações de habilidade extras para os Secundários
@export var meta_run_bonus: float = 0.7             # segundos a mais no Correr

@export_group("Visual do chute")
## Aura + partículas dos chutes de habilidade. Vazio = usa o estilo padrão do Kaiser (veja _make_kick_fx)
@export var kick_fx: KickFX

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: magnus, empire, auf_die_knee, predator, meta.
@export var skill_icons: Dictionary = {}

## Servos marcados pelo Empire (valem até o fim da partida)
var _waiters: Array[Player] = []
var _clowns: Array[Player] = []
var _marks: Dictionary = {}          # Player -> FlowerMark
var _empire_uses_left: int = 1

## Blue Rose: variante ativa, até que rodada vale, e histórico para o limite de repetição
var _rose_variant: StringName = &""
var _rose_until_round: int = -1
var _rose_last: StringName = &""
var _rose_streak: int = 0

## Meta: rodadas em que os Secundários ganham a ação extra (e a última rodada já concedida)
var _meta_ally_from: int = -1
var _meta_ally_until: int = -1
var _meta_granted_round: int = -1

var _base_run_duration: float = 0.0
var _base_slide_distance: float = 0.0
## Mirando o Magnus: o desenho mostra também a curva que a bola vai fazer
var _aiming_magnus: bool = false


func _init() -> void:
	character_id = "kaiser"          # o menu de formação usa isto para saber quem é quem
	display_name = "Michael Kaiser"  # aparece no placar de gols e no menu


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = _make_kick_fx()
	if emperor_fx == null:
		emperor_fx = _make_emperor_fx()
	if be_loved_fx == null:
		be_loved_fx = _make_be_loved_fx()
	_base_run_duration = run_duration
	_base_slide_distance = slide_distance
	_empire_uses_left = empire_starting_uses
	_hook_manager.call_deferred()   # o MatchManager entra na árvore no mesmo frame


## Azul-escuro com partículas douradas
func _make_kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = Color(0.107, 0.193, 0.845, 1.0)
	fx.trail_width = 14.0
	fx.particle_color = Color(0.716, 0.882, 0.853, 1.0)
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


## Emperor Impact: azul elétrico, bem mais largo e cheio de brilhos
func _make_emperor_fx() -> KickFX:
	var fx := _make_kick_fx()
	fx.color = Color(0.2, 0.5, 1.0, 1.0)
	fx.trail_width = 30.0
	fx.particle_color = Color(0.85, 0.95, 1.0, 1.0)
	fx.amount = 60
	fx.lifetime = 0.8
	fx.speed_min = 20.0
	fx.speed_max = 110.0
	fx.gravity = Vector2(0.0, -60.0)
	fx.spin = 360.0
	fx.swirl = 60.0
	fx.scale_min = 0.2
	fx.scale_max = 0.5
	fx.burst_amount = 36
	fx.burst_speed = 360.0
	return fx


## Be Loved: azul elétrico com brilhos azul-claros, largo como o do Emperor Impact
func _make_be_loved_fx() -> KickFX:
	var fx := _make_emperor_fx()
	fx.color = Color(0.28, 0.42, 1.0, 1.0)
	fx.particle_color = Color(0.65, 0.88, 1.0, 1.0)
	fx.swirl = 90.0
	# Mais leve que o Emperor Impact (60 partículas / 0.8 s): o Be Loved já tem a trilha de rosas
	# (superstar_fx.gd), e partículas demais durante a trajetória custavam FPS
	fx.amount = 32
	fx.lifetime = 0.6
	fx.burst_amount = 24
	return fx


func _exit_tree() -> void:
	_clear_servants()


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m == null:
		return
	m.round_started.connect(_on_round_started)
	m.goal_scored.connect(_on_goal_scored)
	m.state_changed.connect(_on_state_changed)


func _on_round_started(_round_number: int) -> void:
	_apply_rose_stats()   # o Predator acabou? o Carrinho volta ao normal
	queue_redraw()        # a aura da Blue Rose some quando as rodadas acabam


## Cada gol DO KAISER dá mais um uso do Empire
func _on_goal_scored(goal: Dictionary) -> void:
	if goal.get("own_goal", false) or goal.get("team", -1) != team:
		return
	if goal.get("scorer", "") == get_display_name():
		_empire_uses_left += 1


## Meta: nas próximas rodadas, a pool dos Secundários ganha a ação extra. O MatchManager zera as
## pools em select_protagonist(), então a extra é somada logo depois, quando a fase vira
## CHOOSING_ACTION (uma vez por rodada).
func _on_state_changed() -> void:
	if _meta_ally_until < 0:
		return
	var m: MatchManager = _get_manager()
	if m == null or m.phase != MatchManager.Phase.CHOOSING_ACTION or m.current_team != team:
		return
	var r: int = m.round_number
	if r < _meta_ally_from or r > _meta_ally_until or _meta_granted_round == r:
		return
	_meta_granted_round = r
	m.secondary_skill_left += meta_extra_ally_skills


# ---------- SERVOS (EMPIRE) ----------

func _is_servant(p: Player) -> bool:
	return p in _waiters or p in _clowns


## O jogador é um Servo Garçom do Empire? (as reações Herbivicus e Superstar usam isto)
func is_waiter(p: Player) -> bool:
	return p in _waiters


## Quem pode ser marcado: companheiro (não ele mesmo) que ainda não é servo
func _is_markable(p: Player) -> bool:
	return is_instance_valid(p) and p != self and p.team == team and not _is_servant(p)


func _is_markable_except(p: Player, skip: Player) -> bool:
	return p != skip and _is_markable(p)


## Companheiros que dá para marcar agora (ao alcance do Empire)
func _empire_candidates(skip: Player = null) -> Array[Player]:
	var result: Array[Player] = []
	var m: MatchManager = _get_manager()
	if m == null:
		return result
	for p: Player in m.get_team_players(team):
		if p != skip and _is_markable(p) \
				and global_position.distance_to(p.global_position) <= empire_range:
			result.append(p)
	return result


func _add_servant(p: Player, type: ServantType) -> void:
	var mark := FlowerMark.new()
	if type == ServantType.WAITER:
		_waiters.append(p)
		mark.petal_color = Color(0.817, 0.655, 0.0, 1.0)    # flor dourada
		mark.core_color = Color(0.08, 0.15, 0.6)
	else:
		_clowns.append(p)
		mark.petal_color = Color(0.08, 0.15, 0.6)    # flor azul-escura
		mark.core_color = Color(0.817, 0.655, 0.0, 1.0)
	p.add_child(mark)
	_marks[p] = mark


func _clear_servants() -> void:
	for mark in _marks.values():
		if is_instance_valid(mark):
			mark.queue_free()
	_marks.clear()
	_waiters.clear()
	_clowns.clear()


## Habilidade Empire: escolhe o Servo Garçom e depois o Servo Palhaço
func _use_empire() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false

	m.announce_keeper("Empire: escolha o Servo Garçom (flor dourada)", team)
	var first: Player = await m.pick_ally_for_skill(self, empire_range, false, _is_markable)
	if first == null or m.match_over:
		return false   # cancelou: não gasta a ação nem o uso

	var second: Player = null
	if not _empire_candidates(first).is_empty():
		m.announce_keeper("Empire: escolha o Servo Palhaço (flor azul) ou cancele para marcar só um", team)
		second = await m.pick_ally_for_skill(self, empire_range, false, _is_markable_except.bind(first))
		if second == null:
			# O manager trata "cancelou a última escolha" como habilidade cancelada (devolve a ação).
			# Aqui cancelar a 2ª escolha é só "não quero um Palhaço": a habilidade FOI usada.
			m._skill_pick_cancelled = false
		if m.match_over:
			return false

	if not await play_action(&"empire"):
		return false   # ação cancelada (ex: a partida reiniciou)
	_empire_uses_left = maxi(0, _empire_uses_left - 1)
	_add_servant(first, ServantType.WAITER)
	if second != null:
		_add_servant(second, ServantType.CLOWN)
	return true


## Garçom: o último toque na bola foi dele (o Kaiser está para tocar) ou o toque anterior foi dele
## (o Kaiser já encostou). Em qualquer caso, é ele quem seria o autor da assistência.
func _waiter_bonus(ball: Ball) -> float:
	if ball == null or _waiters.is_empty():
		return 0.0
	var assister: Player = ball.last_toucher
	if assister == self:
		assister = ball.previous_toucher
	if assister != null and assister in _waiters:
		return waiter_bonus
	return 0.0


# ---------- AUF DIE KNEE ----------

## Palhaço que tem a bola ao alcance do pé, consegue passar rasteiro para o Kaiser e ainda tem
## uma ação geral sobrando (o Auf die Knee gasta uma ação geral DELE)
func _find_knee_clown() -> Player:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return null
	var best: Player = null
	var best_dist: float = INF
	for c in _clowns:
		if not is_instance_valid(c) or c.is_down:
			continue
		# Gasta uma ação geral (Passe) do Palhaço: ele precisa ter uma e poder agir
		if c.is_locked() or c.is_generals_suppressed() \
				or c.is_general_action_blocked(MatchManager.GeneralAction.PASS) \
				or m.general_left_for(c, MatchManager.GeneralAction.PASS) <= 0:
			continue
		if c.get_kick_type(ball) == KickType.NONE:   # longe da bola, derrubado, bola presa...
			continue
		if not m.can_pass_to(c, self, MatchManager.PassVariant.GROUND):   # alcance do passe
			continue
		var d: float = c.global_position.distance_to(ball.global_position)
		if d < best_dist:
			best = c
			best_dist = d
	return best


## O Palhaço passa rasteiro para o Kaiser. Gasta uma ação geral do PALHAÇO (da pool dele) e,
## como em qualquer habilidade, a ação de habilidade do Kaiser (paga pelo MatchManager).
func _use_knee() -> bool:
	var m: MatchManager = _get_manager()
	var clown: Player = _find_knee_clown()
	if m == null or clown == null:
		return false
	var ball: Ball = _get_ball()
	_pay_general_action_of(m, clown)   # sem await antes: a conferência de cima ainda vale
	start_cooldown(CD_KNEE, knee_cooldown)
	# Passe curvilíneo com curva 0 = passe rasteiro reto, mas aceita a aura (fx) da habilidade
	await m.run_curved_ground_pass(clown, self, ball, 0.0, 1.0, &"", kick_fx)
	return true


## Gasta uma ação geral (Passe) de OUTRO jogador, na mesma ordem do MatchManager._consume_general():
## primeiro a extra "sem Correr", depois a extra só dele, depois a pool do papel dele
## (Protagonista ou Secundários). O _consume_general do manager só gasta de quem está agindo
## (o Kaiser), por isso a conta é refeita aqui.
func _pay_general_action_of(m: MatchManager, p: Player) -> void:
	if p.extra_general_no_run_left > 0:
		p.extra_general_no_run_left -= 1
	elif p.extra_general_left > 0:
		p.extra_general_left -= 1
	elif p == m.protagonist:
		m.protagonist_general_left = maxi(0, m.protagonist_general_left - 1)
	else:
		m.secondary_general_left = maxi(0, m.secondary_general_left - 1)
	m.state_changed.emit()   # os contadores do HUD atualizam


# ---------- BLUE ROSE ----------

func is_rose_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _rose_until_round >= 0 and m.round_number <= _rose_until_round


func is_predator_active() -> bool:
	return is_rose_active() and _rose_variant == SKILL_PREDATOR


func is_meta_active() -> bool:
	return is_rose_active() and _rose_variant == SKILL_META


## Pode ativar esta variante? Nada ativo, fora de recarga e sem repetir a mesma mais que o limite
func _can_use_rose(variant: StringName) -> bool:
	if is_rose_active() or is_on_cooldown(CD_ROSE):
		return false
	return not (_rose_last == variant and _rose_streak >= rose_max_repeat)


func _use_rose(variant: StringName) -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	if not await play_action(&"blue_rose"):
		return false

	var start_round: int = m.round_number
	_rose_variant = variant
	_rose_until_round = start_round + rose_rounds - 1   # a rodada atual conta
	if _rose_last == variant:
		_rose_streak += 1
	else:
		_rose_last = variant
		_rose_streak = 1
	start_cooldown(CD_ROSE, rose_cooldown, _rose_until_round + 1)

	if variant == SKILL_META:
		_meta_ally_from = start_round + 1
		_meta_ally_until = start_round + meta_ally_rounds
		_meta_granted_round = -1

	_apply_rose_stats()
	queue_redraw()
	return true


## Predator: Carrinho mais longo (o slide_distance é lido na hora da mira e do Carrinho)
func _apply_rose_stats() -> void:
	slide_distance = _base_slide_distance * (1.0 + predator_slide_bonus) \
		if is_predator_active() else _base_slide_distance


## Predator: o Chutar comum (sem animação de habilidade) sai mais forte e com aura
func kick_ball(ball: Ball, direction: Vector2, kind: KickType, qte_success: bool = true,
		chance_override: float = -1.0, ignore_self_collision: bool = false,
		fx: KickFX = null, anim: StringName = &"", on_kick: Callable = Callable()) -> void:
	if is_predator_active() and anim == &"":
		next_kick_force_mult *= predator_force_mult
		if fx == null and qte_success:
			fx = kick_fx
	await super(ball, direction, kind, qte_success, chance_override, ignore_self_collision,
		fx, anim, on_kick)


## Meta: mais tempo no Correr (checado na hora em que a corrida começa)
func start_run() -> void:
	run_duration = _base_run_duration + (meta_run_bonus if is_meta_active() else 0.0)
	super()


## Meta: nenhum QTE nos chutes do Kaiser
func skips_qte() -> bool:
	return is_meta_active()


# ---------- BÔNUS DE CHUTE (Predator + Garçom) ----------

func _shot_bonus() -> float:
	var bonus: float = 0.0
	if is_predator_active():
		bonus += predator_shot_bonus
	bonus += _waiter_bonus(_get_ball())
	return bonus


## Vale também para o Chutar geral: base do tipo de chute + bônus
func get_shot_chance(kind: KickType) -> float:
	return minf(super(kind) + _shot_bonus(), 1.0)


# ---------- MAGNUS / BEINSCHUSS / KAISER IMPACT ----------

func get_shot_variant() -> ShotVariant:
	var ball: Ball = _get_ball()
	# get_kick_type já confere: derrubado, bola na mão do goleiro, longe demais, altura inalcançável
	if get_kick_type(ball) == KickType.NONE:
		return ShotVariant.NONE

	# Reação Superstar de pé: o chute vira o Be Loved (um Magnus especial) em qualquer altura que
	# ele alcance, porque o passe alto da Kiyora entrega a bola Suspensa
	if _find_superstar() != null:
		return ShotVariant.MAGNUS

	var ball_level: Heights.Level = ball.get_level()
	if height_level == Heights.Level.GROUND:
		if ball_level == Heights.Level.GROUND:
			return ShotVariant.MAGNUS
	elif height_level == Heights.Level.SUSPENDED:
		match ball_level:
			Heights.Level.GROUND:
				return ShotVariant.MAGNUS
			Heights.Level.SUSPENDED:
				return ShotVariant.IMPACT
			Heights.Level.FLYING:
				return ShotVariant.BEINSCHUSS
	return ShotVariant.NONE


func _shot_skill_name() -> String:
	match get_shot_variant():
		ShotVariant.BEINSCHUSS:
			return "Beinschuss"
		ShotVariant.IMPACT:
			# Reação Química disponível: o botão muda de nome
			return "Emperor Impact" if _find_reaction() != null else "Kaiser Impact"
	# Reação Química disponível: o botão muda de nome
	return "Be Loved" if _find_superstar() != null else "Magnus"


## Reação Química do Kaiser Impact que ele pode usar agora (Herbivicus). null = nenhuma.
func _find_reaction() -> ChemicalReaction:
	return _find_available_reaction(false)


## Reação Superstar (Be Loved) que ele pode usar agora. null = nenhuma.
func _find_superstar() -> ChemicalReaction:
	return _find_available_reaction(true)


## As reações do Kaiser são separadas por chute: a Superstar vale para o Magnus (Be Loved) e as
## outras (Herbivicus) para o Kaiser Impact. Cada busca ignora as reações do outro grupo.
func _find_available_reaction(want_superstar: bool) -> ChemicalReaction:
	if not is_inside_tree():
		return null
	var rm: ReactionManager = ReactionManager.get_for(self)
	if rm == null:
		return null
	for reaction in rm.reactions:
		if (reaction.id == SUPERSTAR_ID) != want_superstar:
			continue
		if reaction.trigger_id != character_id or not rm.is_ready(reaction, team):
			continue
		if reaction.find_partner(self) != null:
			return reaction
	return null


func _use_shot_skill() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or get_shot_variant() == ShotVariant.NONE:
		return false

	# Mira. No Magnus o desenho mostra também a curva que a bola vai fazer.
	_aiming_magnus = get_shot_variant() == ShotVariant.MAGNUS
	queue_redraw()
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	_aiming_magnus = false
	queue_redraw()
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação

	# A bola pode ter rolado enquanto ele mirava: confere de novo
	var ball: Ball = _get_ball()
	var variant: ShotVariant = get_shot_variant()
	if variant == ShotVariant.NONE:
		return false

	# Reação Química (Herbivicus): só vale para o Kaiser Impact. A partida congela, roda a cutscene
	# e SÓ DEPOIS DO DIÁLOGO o chute acontece (antes do QTE e do chute).
	var reaction: ChemicalReaction = null
	if variant == ShotVariant.IMPACT:
		reaction = _find_reaction()
		if reaction != null:
			var partner: Player = reaction.find_partner(self)
			var rm: ReactionManager = ReactionManager.get_for(self)
			if partner == null or rm == null:
				reaction = null
			else:
				await rm.play(reaction, self, partner)
				if m.match_over:
					return false

	# Reação Química (Superstar): só vale para o Magnus (vira o Be Loved). Mesma ideia: a partida
	# congela, roda a cutscene e SÓ DEPOIS DO DIÁLOGO o chute acontece.
	var superstar: ChemicalReaction = null
	if variant == ShotVariant.MAGNUS:
		superstar = _find_superstar()
		if superstar != null:
			var star_partner: Player = superstar.find_partner(self)
			var star_rm: ReactionManager = ReactionManager.get_for(self)
			if star_partner == null or star_rm == null:
				superstar = null
			else:
				await star_rm.play(superstar, self, star_partner)
				if m.match_over:
					return false

	var kind: KickType = KickType.GROUND
	var anim: StringName = &"magnus"
	var base_chance: float = chance_magnus
	var dir: Vector2 = aim
	var needs_qte: bool = false
	var on_kick: Callable = Callable()

	match variant:
		ShotVariant.MAGNUS:
			# Sai desviado e vai curvando de volta; a bola é conduzida logo depois do chute
			dir = _magnus_heading(aim.angle(), 0.0)
			on_kick = _launch_magnus.bind(aim)
			if superstar != null:   # Be Loved: mesmo conceito, mais forte, e com a trilha de rosas
				anim = _be_loved_anim()
				base_chance = chance_be_loved
				on_kick = _launch_be_loved.bind(aim)
		ShotVariant.BEINSCHUSS:
			kind = KickType.FLYING
			anim = &"beinschuss"
			base_chance = chance_beinschuss
			needs_qte = true   # QTE difícil
		ShotVariant.IMPACT:
			kind = KickType.VOLLEY
			anim = &"kaiser_impact"
			base_chance = chance_impact
			on_kick = _launch_impact
			if reaction != null:   # Emperor Impact: mesmo conceito, mais forte, mais rápido e com a rosa
				anim = _emperor_anim()
				base_chance = chance_emperor
				on_kick = _launch_emperor

	var qte_ok: bool = true
	if needs_qte and not skips_qte():
		qte_ok = await m.run_qte(KickType.FLYING)

	if variant == ShotVariant.IMPACT:
		# rápido (gasto dentro do kick_ball)
		next_kick_force_mult *= emperor_force_mult if reaction != null else impact_force_mult
	elif superstar != null:
		next_kick_force_mult *= be_loved_force_mult

	# Emperor Impact: os 75% são o valor final (sem somar Garçom/Predator). Os outros chutes somam.
	# Be Loved: os 85% também são o valor final (sem somar Garçom/Predator)
	var final_value: bool = reaction != null or superstar != null
	var chance: float = base_chance if final_value else minf(base_chance + _shot_bonus(), 1.0)
	var fx: KickFX = kick_fx
	if reaction != null:
		fx = emperor_fx
	elif superstar != null:
		fx = be_loved_fx
	# Errou o QTE = chute fraquinho, sem aura
	await kick_ball(ball, dir, kind, qte_ok, chance, false,
		fx if qte_ok else null, anim, on_kick)
	start_cooldown(CD_SHOT, shot_cooldown)
	return true


## Direção da bola no ponto u (0 = chute, 1 = fim da condução) do Magnus. Começa desviada para
## um lado e termina desviada para o outro: o desvio total é zero, então ela cruza a linha da mira.
func _magnus_heading(aim_angle: float, u: float) -> Vector2:
	var bend: float = deg_to_rad(magnus_bend_deg) * magnus_bend_sign
	return Vector2.from_angle(aim_angle + bend * (1.0 - 2.0 * u))


## Chamado pelo kick_ball() logo depois que a bola sai (on_kick)
func _launch_magnus(ball: Ball, _dir: Vector2, speed: float, aim: Vector2) -> void:
	_drive_ball(ball, magnus_flight_time, _magnus_step.bind(aim.angle(), speed))


func _launch_impact(ball: Ball, _dir: Vector2, _speed: float) -> void:
	_drive_ball(ball, impact_flight_time, _impact_step)


## Emperor Impact: igual ao Kaiser Impact (bola reta e Suspensa), só que por mais tempo, e no
## instante do chute nasce a rosa azul gigante (+ clarão e tremida de câmera)
func _launch_emperor(ball: Ball, _dir: Vector2, _speed: float) -> void:
	_drive_ball(ball, emperor_flight_time, _impact_step)
	HerbivicusFX.emperor_burst(self, global_position + Vector2(0.0, -height), ball, emperor_rose_radius)


## Be Loved: a mesma condução curva do Magnus, só que mais longa, partindo da altura em que a bola
## estiver (a bola do passe alto chega Suspensa) e com a trilha de rosas azuis e rosas
func _launch_be_loved(ball: Ball, _dir: Vector2, speed: float, aim: Vector2) -> void:
	_drive_ball(ball, be_loved_flight_time, _be_loved_step.bind(aim.angle(), speed, ball.height))
	SuperstarFX.attach_roses(ball, be_loved_flight_time + 1.6)


## Animação do Be Loved: usa a "be_loved" se o personagem tiver; senão, a do Magnus
func _be_loved_anim() -> StringName:
	if _has_art and animated_sprite.sprite_frames.has_animation(&"be_loved"):
		return &"be_loved"
	return &"magnus"


## Animação do Emperor Impact: usa a "emperor_impact" se o personagem tiver; senão, a do Kaiser Impact
func _emperor_anim() -> StringName:
	if _has_art and animated_sprite.sprite_frames.has_animation(&"emperor_impact"):
		return &"emperor_impact"
	return &"kaiser_impact"


## Um passo da condução do Magnus: curva a velocidade e sobe suavemente até o nível Suspenso
func _magnus_step(b: Ball, u: float, delta: float, aim_angle: float, speed: float) -> void:
	b.velocity = _magnus_heading(aim_angle, u) * speed * lerpf(1.0, 0.85, u)
	b.height = Heights.SUSPENDED_HEIGHT * smoothstep(0.0, 1.0, u)
	b.vel_z = b.gravity * delta   # cancela a gravidade deste frame: a altura é conduzida aqui


## Um passo do Be Loved: igual ao do Magnus, mas a altura parte de onde a bola estava
func _be_loved_step(b: Ball, u: float, delta: float, aim_angle: float, speed: float, start_height: float) -> void:
	b.velocity = _magnus_heading(aim_angle, u) * speed * lerpf(1.0, 0.85, u)
	b.height = lerpf(start_height, Heights.SUSPENDED_HEIGHT, smoothstep(0.0, 1.0, u))
	b.vel_z = b.gravity * delta


## Um passo do Kaiser Impact: segura a bola no nível Suspenso (a velocidade fica como saiu do chute)
func _impact_step(b: Ball, _u: float, delta: float) -> void:
	b.height = move_toward(b.height, Heights.SUSPENDED_HEIGHT, 300.0 * delta)
	b.vel_z = b.gravity * delta


## Conduz a bola por "duration" segundos chamando step(bola, u 0..1, delta) a cada frame de física.
## Para sozinho se alguém tocar na bola, ela for segurada, reposta ou a partida acabar. Se chegou
## ao fim, solta a bola e a gravidade volta. Quem chama NÃO precisa esperar (roda em segundo plano).
func _drive_ball(ball: Ball, duration: float, step: Callable) -> void:
	var m: MatchManager = _get_manager()
	var touches: int = ball.interaction_count   # o chute do Kaiser já foi contado
	var state: Dictionary = {"abort": false}
	var on_reset: Callable = func() -> void: state["abort"] = true
	ball.was_reset.connect(on_reset, CONNECT_ONE_SHOT)

	var elapsed: float = 0.0
	var completed: bool = false
	while true:
		await get_tree().physics_frame
		if not is_instance_valid(ball) or state["abort"] or ball.interaction_count != touches \
				or ball.hovering or (m != null and m.match_over):
			break
		var delta: float = get_physics_process_delta_time()
		elapsed += delta
		step.call(ball, clampf(elapsed / duration, 0.0, 1.0), delta)
		if elapsed >= duration:
			completed = true
			break

	if not is_instance_valid(ball):
		return
	if ball.was_reset.is_connected(on_reset):
		ball.was_reset.disconnect(on_reset)
	if completed:
		ball.vel_z = 0.0   # solta: a gravidade assume e a bola cai


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"id": SKILL_SHOT, "name": skill_label(_shot_skill_name(), CD_SHOT)})
	list.append({"id": SKILL_EMPIRE, "name": "Empire (%d)" % _empire_uses_left})
	list.append({"id": SKILL_KNEE, "name": skill_label("Auf die Knee", CD_KNEE)})
	list.append({"id": SKILL_PREDATOR, "name": _rose_label("Predator", SKILL_PREDATOR)})
	list.append({"id": SKILL_META, "name": _rose_label("Meta", SKILL_META)})
	return list


func _rose_label(title: String, variant: StringName) -> String:
	var full: String = "Blue Rose: " + title
	if is_rose_active() and _rose_variant == variant:
		return "%s (ativo)" % full
	if not is_rose_active() and not is_on_cooldown(CD_ROSE) \
			and _rose_last == variant and _rose_streak >= rose_max_repeat:
		return "%s (alterne)" % full
	return skill_label(full, CD_ROSE)


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_SHOT:
			return not is_on_cooldown(CD_SHOT) and get_shot_variant() != ShotVariant.NONE
		SKILL_EMPIRE:
			return _empire_uses_left > 0 and not _empire_candidates().is_empty()
		SKILL_KNEE:
			return not is_on_cooldown(CD_KNEE) and _find_knee_clown() != null
		SKILL_PREDATOR, SKILL_META:
			return _can_use_rose(skill_id)
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_SHOT:
			return await _use_shot_skill()
		SKILL_EMPIRE:
			return await _use_empire()
		SKILL_KNEE:
			return await _use_knee()
		SKILL_PREDATOR:
			return await _use_rose(SKILL_PREDATOR)
		SKILL_META:
			return await _use_rose(SKILL_META)
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
				ShotVariant.MAGNUS:
					var star: ChemicalReaction = _find_superstar()
					if star != null:
						title = "Be Loved"
						text = "Reação Química Superstar com a Kiyora: um Magnus mais forte, com uma trilha de rosas azuis. %d%% de chance de gol.\nA reação recarrega em %d rodadas." % [
							_pct(chance_be_loved), star.cooldown_rounds]
					else:
						text = "Chute curvo que sobe durante o trajeto. %d%% de chance de gol." % _pct(chance_magnus)
				ShotVariant.BEINSCHUSS:
					text = "Bicicleta no ar. %d%% de chance de gol." % _pct(chance_beinschuss)
				ShotVariant.IMPACT:
					var reaction: ChemicalReaction = _find_reaction()
					if reaction != null:
						title = "Emperor Impact"
						text = "Reação Química Herbivicus com o Ness: chute reto, mais forte e mais rápido, com uma rosa azul gigante. %d%% de chance de gol.\nA reação recarrega em %d rodadas." % [
							_pct(chance_emperor), reaction.cooldown_rounds]
					else:
						text = "Chute reto e rápido. %d%% de chance de gol." % _pct(chance_impact)
				_:
					text = "Chute especial que muda conforme a altura dele e da bola. De %d%% a %d%% de chance de gol." % [
						_pct(minf(chance_magnus, minf(chance_beinschuss, chance_impact))),
						_pct(maxf(chance_magnus, maxf(chance_beinschuss, chance_impact)))]
			text += "\nRecarga: %d rodadas." % shot_cooldown
		SKILL_EMPIRE:
			title = "Empire"
			text = ("Marca dois aliados como servos pela partida toda. O Garçom dá +%d%% de chance de gol aos chutes do Kaiser depois de um passe dele; o Palhaço libera o Auf die Knee.\n"
				+ "Usos restantes: %d.") % [_pct(waiter_bonus), _empire_uses_left]
		SKILL_KNEE:
			title = "Auf die Knee"
			text = "Obriga o Palhaço a passar a bola para o Kaiser.\nRecarga: %d rodadas." % knee_cooldown
		SKILL_PREDATOR:
			title = "Blue Rose: Predator"
			text = ("Por %d rodadas: o Kaiser chuta mais forte, o Carrinho vai mais longe e os chutes ganham +%d%% de chance de gol.\n"
				+ "Recarga: %d rodadas.") % [
				rose_rounds, _pct(predator_shot_bonus), rose_cooldown]
		SKILL_META:
			title = "Blue Rose: Meta"
			text = ("Por %d rodadas: o Kaiser chuta sem QTE e corre por mais tempo. Os Secundários ganham +%d ação de habilidade.\n"
				+ "Recarga: %d rodadas.") % [
				rose_rounds, meta_extra_ally_skills, rose_cooldown]
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()
	_clear_servants()
	_empire_uses_left = empire_starting_uses
	_rose_variant = &""
	_rose_until_round = -1
	_rose_last = &""
	_rose_streak = 0
	_meta_ally_from = -1
	_meta_ally_until = -1
	_meta_granted_round = -1
	_aiming_magnus = false
	run_duration = _base_run_duration
	slide_distance = _base_slide_distance
	queue_redraw()


# ---------- VISUAL ----------

func _draw() -> void:
	super()
	var center := Vector2(0.0, -height)
	var ring: float = placeholder_radius + 26.0
	var gold := Color(0.816, 0.655, 0.0, 0.588)
	var blue := Color(0.102, 0.2, 0.749, 0.588)

	# Predator: anel dourado com "espinhos"
	if is_predator_active():
		draw_arc(center, ring, 0.0, TAU, 40, gold, 3.0)
		for i in 8:
			var d := Vector2.from_angle(TAU * float(i) / 8.0)
			draw_line(center + d * ring, center + d * (ring + 7.0), gold, 3.0)

	# Meta: anel azul-escuro tracejado com um fio dourado por dentro
	elif is_meta_active():
		var segments: int = 12
		for i in segments:
			if i % 2 == 0:
				var a0: float = TAU * float(i) / float(segments)
				var a1: float = TAU * float(i + 1) / float(segments)
				draw_arc(center, ring, a0, a1, 6, blue, 3.0)
		draw_arc(center, ring - 5.0, 0.0, TAU, 40, Color(gold, 0.6), 1.5)

	# Magnus: linha tracejada = o caminho real da bola (a seta laranja do Player é a linha da mira)
	if is_aiming and _aiming_magnus:
		_draw_magnus_preview()


## Previsão do Magnus (estilo do Rin): simula a MESMA condução do _drive_ball (velocidade que
## vira com o tempo e vai perdendo 15%), e depois a bola seguindo reta no rumo final.
func _draw_magnus_preview() -> void:
	var ball: Ball = _get_ball()
	if ball == null:
		return
	var start: Vector2 = to_local(ball.global_position)   # sai da bola, não do pé dele
	var a: float = aim_direction.angle()
	var speed: float = kick_force_ground * kick_force_to_speed
	if _find_superstar() != null:
		speed *= be_loved_force_mult   # Be Loved: mais forte, então a linha vai mais longe
	var dt: float = 1.0 / 60.0
	var air_factor: float = maxf(0.0, 1.0 - ball.air_drag * dt)
	var pos: Vector2 = start
	var elapsed: float = 0.0
	var travelled: float = 0.0
	var steps: int = 0
	var last_dir: Vector2 = Vector2.from_angle(a)
	var color := Color(0.35, 0.58, 1.0, 0.95)
	var flight: float = be_loved_flight_time if _find_superstar() != null else magnus_flight_time
	while steps < 300 and travelled < magnus_preview_length and speed > 20.0:
		var cur: float = speed
		var dir: Vector2 = last_dir
		if elapsed < flight:
			var u: float = clampf(elapsed / maxf(flight, 0.05), 0.0, 1.0)
			dir = _magnus_heading(a, u)
			cur = speed * lerpf(1.0, 0.85, u)
		else:
			speed *= air_factor   # depois da condução só o ar freia a bola
			cur = speed * 0.85
		last_dir = dir
		var seg: Vector2 = dir * cur * air_factor * dt
		if steps % 2 == 0:
			draw_line(pos, pos + seg, color, 4.0)
		pos += seg
		travelled += seg.length()
		steps += 1
		elapsed += dt
	draw_circle(pos, 6.0, color)
	draw_arc(pos, 10.0, 0.0, TAU, 20, Color(color, 0.6), 2.0)


## Flor que fica em cima de um servo (dourada = Garçom, azul-escura = Palhaço).
## É filha do jogador marcado, então acompanha ele (e sobe quando ele pula).
class FlowerMark extends Node2D:
	var petal_color: Color = Color(1.0, 0.82, 0.22)
	var core_color: Color = Color(0.08, 0.15, 0.6)
	var offset: Vector2 = Vector2(20.0, -40.0)
	var _target: Player = null

	func _ready() -> void:
		_target = get_parent() as Player
		z_index = 10
		_follow()

	func _process(_delta: float) -> void:
		_follow()

	func _follow() -> void:
		var h: float = _target.height if _target != null else 0.0
		position = offset + Vector2(0.0, -h)

	func _draw() -> void:
		var outline := Color(0.0, 0.0, 0.0, 0.75)
		var petals: int = 6
		for i in petals:
			draw_circle(Vector2.from_angle(TAU * float(i) / float(petals)) * 6.0, 5.0, outline)
		draw_circle(Vector2.ZERO, 4.0, outline)
		for i in petals:
			draw_circle(Vector2.from_angle(TAU * float(i) / float(petals)) * 6.0, 4.0, petal_color)
		draw_circle(Vector2.ZERO, 3.2, core_color)
