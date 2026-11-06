class_name Kaiser
extends Player
## Michael Kaiser. Herda tudo do Player (ações gerais) e adiciona as habilidades próprias:
##
## 0. Vision (passiva, sem botão): o Kaiser troca sozinho entre Metavisão e Olhar do Predador.
##      Time dele GANHANDO -> Metavisão: +0.4 s no Correr e +1 ação de habilidade a cada 2 rodadas.
##      Time dele PERDENDO -> Olhar do Predador: +5% de chance e +0.1x de força nos chutes.
##      Empate: mantém a que estava.
##      Visual: Metavisão = radar circular azul em volta dele; Olhar do Predador = cortes de garra dourados
##      em volta (veja KaiserFX.vision_aura).
## 1. Magnus (ação de habilidade, variantes automáticas pela altura; recarga de 2 rodadas, compartilhada):
##      - Bola e Kaiser no chão -> Magnus: chute com curva fixa, a bola sobe até Suspenso (1.2x, 45%)
##      - Kaiser suspenso + bola no chão/suspensa -> Impact: chute reto (1.3x, 45%) e, se houver inimigos
##        a 100, dá um pequeno empurrão em até 2 deles
##      - Kaiser suspenso + bola Voando -> Beinschuss: 1.3x, 45%; com um inimigo no chão a 100 ele serve
##        de apoio (+5%)
##      - Kaiser sem a bola por perto -> Umfang: mira antes e deixa o chute armado durante este turno e o
##        do inimigo; se a bola chegar a 70 dele, ele chuta sozinho (1.4x, 45%)
## 2. Path (ação de habilidade; recarga de 2 rodadas, compartilhada com o Blitzkrieg/Blindheit):
##      escolhe um aliado ou inimigo a 230, mira a saída e faz um dash em V contornando ele (300).
##      Enquanto mira, uma linha tracejada com seta mostra por onde ele vai passar (o mesmo vale para o
##      Blitzkrieg/Blindheit: ida até a bola + dash curvo). Se alcançar a bola durante o dash, ele a DOMINA:
##      a bola gruda nele até o fim do dash e, no fim, faz um QTE fácil para ganhar uma ação de habilidade.
##      Se o escolhido for o Garçom, ele ganha um Correr de 1 s mais rápido e o efeito do Garçom sobe 4%.
##      - Blitzkrieg: Kaiser no chão e bola Suspensa a 150 -> vai até ela, salta, domina, toca num aliado a 350,
##        faz um dash curvo de 280 e o aliado devolve a bola Suspensa; Kaiser salta e chuta rápido (1.2x, 45%).
##      - Blindheit: o mesmo, mas com 2+ inimigos a 200 o chute ganha +0.1x e +5%, ignora a colisão
##        deles e o Kaiser diz "You're fucking blind." antes de chutar.
## 3. Empire (ação de habilidade): marca dois jogadores do time, pela partida inteira. A 1ª escolha vira
##      o Servo Garçom (flor dourada), a 2ª o Servo Palhaço (flor azul-escura); dá para marcar só um.
##      Cada GOL do Kaiser dá +1 uso.
##      - Garçom: chutes do Kaiser com assistência dele +4%, o Passe do Kaiser ganha +20 de alcance e
##        libera o Opfer (botão próprio, recarga de 3 rodadas): passe rasteiro (400) Garçom -> Kaiser, o
##        Garçom corre 1 s (1.1x), o Kaiser devolve e corre também, e no fim o aliado passa de novo.
##      - Palhaço: Auf die Knee (botão próprio, recarga de 3 rodadas): com a bola perto de um Palhaço, ele
##        passa rasteiro para o Kaiser. NÃO gasta a ação de habilidade do Kaiser, só uma ação geral do Palhaço.
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
## "magnus", "beinschuss", "kaiser_impact", "umfang", "path", "blitzkrieg", "empire", "opfer".
## Sem elas, nada quebra.
##
## REQUISITO: o kick_ball() do player.gd precisa do parâmetro on_kick (veja a conversa).

const SKILL_SHOT: StringName = &"magnus"
const SKILL_PATH: StringName = &"path"
const SKILL_EMPIRE: StringName = &"empire"
const SKILL_KNEE: StringName = &"auf_die_knee"
const SKILL_OPFER: StringName = &"opfer"

## id da reação Superstar (reaction_superstar.gd)
const SUPERSTAR_ID: StringName = &"superstar"

## Grupos de recarga (as variantes de cada habilidade compartilham o mesmo)
const CD_SHOT: StringName = &"cd_shot"
const CD_PATH: StringName = &"cd_path"
const CD_KNEE: StringName = &"cd_knee"
const CD_OPFER: StringName = &"cd_opfer"

enum ShotVariant { NONE, MAGNUS, BEINSCHUSS, IMPACT, UMFANG }
enum PathVariant { NONE, PATH, BLITZ }
enum ServantType { WAITER, CLOWN }
enum Vision { META, PREDATOR }
enum PathPreview { NONE, PATH, BLITZ }

@export_group("Vision (Metavisão / Olhar do Predador)")
@export var meta_run_bonus: float = 0.2              # segundos a mais no Correr (Metavisão)
@export var meta_skill_every: int = 2                # +1 ação de habilidade a cada X rodadas (Metavisão)
@export_range(0.0, 1.0) var predator_shot_bonus: float = 0.03   # +5% em qualquer chute (Olhar do Predador)
@export var predator_force_add: float = 0.1          # +0.1x de força em qualquer chute (Olhar do Predador)

@export_group("Magnus / Impact / Beinschuss / Umfang")
@export_range(0.0, 1.0) var chance_magnus: float = 0.40
@export_range(0.0, 1.0) var chance_beinschuss: float = 0.45
@export_range(0.0, 1.0) var chance_impact: float = 0.45
@export_range(0.0, 1.0) var chance_umfang: float = 0.45
@export var shot_cooldown: int = 2                  # recarga (rodadas), igual para as variantes
@export var magnus_force_mult: float = 0.8
@export var beinschuss_force_mult: float = 1.2
@export var umfang_force_mult: float = 1.4
## Magnus: a bola sai desviada deste ângulo e vai curvando de volta, cruzando a linha da mira
@export var magnus_bend_deg: float = 14.0
## +1 / -1 escolhe para que lado a bola faz a curva
@export var magnus_bend_sign: float = 1.0
## Tamanho máximo da linha tracejada da mira do Magnus (px)
@export var magnus_preview_length: float = 500.0
## Quanto tempo a bola é conduzida (curva + subida até o nível Suspenso); depois cai normal
@export var magnus_flight_time: float = 0.1
## Kaiser Impact: multiplicador de força (rápido) e por quanto tempo a bola fica Suspensa
@export var impact_force_mult: float = 1.2
@export var impact_flight_time: float = 0.2
## Impact: empurrão nos inimigos próximos (raio, quantos no máximo, distância do empurrão)
@export var impact_push_radius: float = 100.0
@export var impact_push_max: int = 2
@export var impact_push_distance: float = 60.0
## Beinschuss: inimigo no chão a este alcance serve de apoio (+chance). Por padrão sem QTE.
@export var beinschuss_support_radius: float = 100.0
@export_range(0.0, 1.0) var beinschuss_support_bonus: float = 0.05
@export var beinschuss_needs_qte: bool = true
## Umfang: a bola a este alcance dispara o chute armado
@export var umfang_radius: float = 70.0

@export_group("Emperor Impact (reação Herbivicus)")
@export_range(0.0, 1.0) var chance_emperor: float = 0.8   # chance de gol (já é o valor final)
@export var emperor_force_mult: float = 1.9               # mais forte que o Kaiser Impact (1.3)
@export var emperor_flight_time: float = 0.3               # tempo Suspensa (o Kaiser Impact usa 0.2)
@export var emperor_rose_radius: float = 260.0             # tamanho da rosa gigante (px)
## Aura do chute. Vazio = usa o estilo padrão (veja _make_emperor_fx)
@export var emperor_fx: KickFX

@export_group("Be Loved (reação Superstar)")
@export_range(0.0, 1.0) var chance_be_loved: float = 0.85   # chance de gol (já é o valor final)
@export var be_loved_force_mult: float = 1.3               # mais forte que o Magnus (1.2)
## Quanto tempo a bola é conduzida na curva (o Magnus usa magnus_flight_time)
@export var be_loved_flight_time: float = 1.0
## Aura do chute. Vazio = usa o estilo padrão (veja _make_be_loved_fx)
@export var be_loved_fx: KickFX

@export_group("Path / Blitzkrieg / Blindheit")
@export var path_cooldown: int = 2                  # recarga (rodadas), igual para as 3
@export var path_pick_range: float = 350.0          # alcance para escolher o aliado/inimigo
@export var path_length: float = 600.0              # comprimento total do dash em V
@export var path_vertex_offset: float = 40.0        # o quanto ele passa ao lado de quem foi escolhido
@export var path_min_exit: float = 80.0             # saída mínima depois do vértice
@export var dash_speed: float = 700.0              # velocidade dos dashes (px/s)
@export var dribble_catch_margin: float = 14.0      # folga (px) para encostar na bola durante o dash
@export var path_qte_keys: int = 3                  # QTE fácil depois de achar a bola
@export var path_qte_time: float = 0.7
@export var path_waiter_run_time: float = 1.0       # Correr do Garçom escolhido (s)
@export var path_waiter_run_speed: float = 1.3      # ... com esta velocidade (x)
@export_range(0.0, 1.0) var path_waiter_gain: float = 0.04   # quanto o efeito do Garçom sobe
@export var blitz_ball_range: float = 150.0         # bola Suspensa a este alcance
@export var blitz_ally_range: float = 400.0         # alcance do aliado que recebe o toque
@export var blitz_arc_length: float = 380.0         # dash curvo
@export var blitz_pass_time: float = 0.4           # tempo do toque / devolução (s)
@export var blitz_catch_time: float = 0.15          # tempo que ele leva para dominar a bola Suspensa ao alcançá-la (0 = sem isso)
@export_range(0.0, 1.0) var chance_blitz: float = 0.45
@export var blitz_force_mult: float = 1.2
@export var blind_enemy_radius: float = 200.0       # Blindheit: inimigos próximos
@export var blind_enemies_needed: int = 2
@export var blind_force_add: float = 0.1
@export_range(0.0, 1.0) var blind_bonus: float = 0.05

@export_group("Empire")
@export var empire_range: float = 700.0           # "menu com todos os jogadores": sem limite de alcance
@export var empire_starting_uses: int = 1           # usos no começo da partida (+1 a cada gol dele)
@export_range(0.0, 1.0) var waiter_bonus: float = 0.04   # +4% no chute com passe/assistência do Garçom
@export var waiter_pass_range_bonus: float = 20.0   # Passe do Kaiser +20 de alcance com um Garçom
@export var knee_cooldown: int = 3                  # recarga do Auf die Knee
@export var opfer_range: float = 400.0              # alcance do Opfer (Garçom <-> Kaiser)
@export var opfer_run_time: float = 1.0             # Correr curto de cada um (s)
@export var opfer_run_speed: float = 1.1            # ... com esta velocidade (x)
@export var opfer_cooldown: int = 3

@export_group("Visual do chute")
## Aura + partículas dos chutes de habilidade. Vazio = usa o estilo padrão do Kaiser (veja _make_kick_fx)
@export var kick_fx: KickFX

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: magnus, path, empire, auf_die_knee, opfer.
@export var skill_icons: Dictionary = {}

## Servos marcados pelo Empire (valem até o fim da partida)
var _waiters: Array[Player] = []
var _clowns: Array[Player] = []
var _marks: Dictionary = {}          # Player -> FlowerMark
var _empire_uses_left: int = 1
var _waiter_extra: float = 0.0       # quanto o efeito do Garçom já subiu (Path em um Garçom)
var _pass_bonus_applied: bool = false

## Vision: qual está ativa e quantas rodadas de Metavisão já passaram (para a ação extra)
var _vision: Vision = Vision.META
var _meta_rounds: int = 0

var _base_run_duration: float = 0.0
## Mirando o Magnus: o desenho mostra também a curva que a bola vai fazer
var _aiming_magnus: bool = false

## Umfang: direção do chute armado e quantos fins de turno faltam para ele expirar (0 = desarmado)
var _umfang_dir: Vector2 = Vector2.ZERO
var _umfang_turns_left: int = 0
var _umfang_firing: bool = false

## Dashes escritos (Path / Blitzkrieg) e bola grudada
var _dashing: bool = false
var _dash_token: int = 0
var _got_ball: bool = false
var _trail: KaiserFX.DashTrail = null   # esteira azul com rosas durante os dashes
var _held_paused: bool = false          # a bola dominada teve a colisão com jogadores desligada por ele
## Prévia tracejada dos dashes (enquanto mira o Path / Blitzkrieg / Blindheit)
var _preview_kind: PathPreview = PathPreview.NONE
var _preview_target: Player = null
var _blitz_bend: float = 1.0            # lado da curva do dash do Blitzkrieg (sorteado antes da mira para a prévia bater)
## Radar (Metavisão) / garras (Olhar do Predador) em volta dele
var _vision_fx: KaiserFX.VisionAura = null
var _held_ball: Ball = null
var _hold_dir: Vector2 = Vector2.ZERO
## Correr curto (Path no Garçom / Opfer): multiplicador de velocidade por jogador
var _run_boosts: Dictionary = {}

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
	add_to_group("control_sources")   # o Garçom do Path/Opfer corre mais rápido (run_speed_mult_on)
	_empire_uses_left = empire_starting_uses
	# Se o Kaiser foi duplicado, a cópia pode ter herdado a aura do original: remove e cria a sua
	for c in get_children():
		if c is KaiserFX.VisionAura:
			c.queue_free()
	_vision_fx = KaiserFX.vision_aura(self, placeholder_radius + 26.0)
	_sync_vision_fx()
	_hook_manager.call_deferred()   # o MatchManager entra na árvore no mesmo frame


## Azul com partículas rosas (veja kaiser_fx.gd)
func _make_kick_fx() -> KickFX:
	return KaiserFX.kick_style(false)


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
	m.turn_ended.connect(_on_turn_ended)
	_update_vision()


func _on_round_started(_round_number: int) -> void:
	_update_vision()
	# Metavisão: +1 ação de habilidade a cada 2 rodadas com ela ativa
	if is_meta_active():
		_meta_rounds += 1
		if _meta_rounds % maxi(meta_skill_every, 1) == 0:
			extra_skill_left += 1
	queue_redraw()


## Cada gol DO KAISER dá mais um uso do Empire. Qualquer gol pode mudar a Vision (placar).
func _on_goal_scored(goal: Dictionary) -> void:
	_update_vision.call_deferred()   # deixa o MatchManager atualizar o placar antes
	if goal.get("own_goal", false) or goal.get("team", -1) != team:
		return
	if goal.get("scorer", "") == get_display_name():
		_empire_uses_left += 1


## O Umfang armado dura até o fim do turno do Kaiser e do turno do inimigo seguinte
func _on_turn_ended(_turn_team: int) -> void:
	if _umfang_turns_left > 0:
		_umfang_turns_left -= 1
		queue_redraw()


# ---------- VISION ----------

## Time ganhando -> Metavisão; perdendo -> Olhar do Predador; empate mantém a atual
func _update_vision() -> void:
	var m: MatchManager = _get_manager()
	if m == null or m.scores.size() < 2:
		return
	var old: Vision = _vision
	var mine: int = m.scores[team]
	var theirs: int = m.scores[1 - team]
	if mine > theirs:
		_vision = Vision.META
	elif mine < theirs:
		_vision = Vision.PREDATOR
	if old != _vision:
		queue_redraw()
		_sync_vision_fx()
		if is_inside_tree():
			KaiserFX.ring(self, global_position, 70.0)
			KaiserFX.rose_burst(self, global_position + Vector2(0.0, -height - 16.0), 8, true)


## Liga o radar (Metavisão) ou as garras (Olhar do Predador) em volta do Kaiser
func _sync_vision_fx() -> void:
	if _vision_fx == null or not is_instance_valid(_vision_fx):
		return
	if is_predator_active():
		_vision_fx.show_predator()
	else:
		_vision_fx.show_meta()


func is_predator_active() -> bool:
	return _vision == Vision.PREDATOR


func is_meta_active() -> bool:
	return _vision == Vision.META


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
		if not _pass_bonus_applied:   # com um Garçom, o Passe do Kaiser alcança mais
			pass_range_bonus += waiter_pass_range_bonus
			_pass_bonus_applied = true
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
	if _pass_bonus_applied:
		pass_range_bonus -= waiter_pass_range_bonus
		_pass_bonus_applied = false


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
		return waiter_bonus + _waiter_extra
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


# ---------- EFEITOS DA VISION ----------

## Olhar do Predador: todo chute do Kaiser sai +0.1x mais forte (soma ao multiplicador da habilidade).
## O Chutar comum (sem animação de habilidade) ainda ganha a aura azul.
func kick_ball(ball: Ball, direction: Vector2, kind: KickType, qte_success: bool = true,
		chance_override: float = -1.0, ignore_self_collision: bool = false,
		fx: KickFX = null, anim: StringName = &"", on_kick: Callable = Callable()) -> void:
	if is_predator_active():
		next_kick_force_mult += predator_force_add
		if fx == null and qte_success and anim == &"":
			fx = kick_fx
	await super(ball, direction, kind, qte_success, chance_override, ignore_self_collision,
		fx, anim, on_kick)


## Metavisão: mais tempo no Correr (checado na hora em que a corrida começa)
func start_run() -> void:
	run_duration = _base_run_duration + (meta_run_bonus if is_meta_active() else 0.0)
	super()


## Correr curto com velocidade maior (Path no Garçom / Opfer) usa este multiplicador
func get_run_speed_mult() -> float:
	return super() * float(_run_boosts.get(self, 1.0))


## Outros jogadores perguntam isto (grupo "control_sources"): o Garçom do Path/Opfer corre mais rápido
func run_speed_mult_on(p: Player) -> float:
	return float(_run_boosts.get(p, 1.0))


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
		# Sem a bola ao alcance do pé: Umfang (arma o chute de longe), se ainda não estiver armado
		if ball != null and _umfang_turns_left <= 0 \
				and global_position.distance_to(ball.global_position) > kick_range:
			return ShotVariant.UMFANG
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
			Heights.Level.GROUND, Heights.Level.SUSPENDED:
				return ShotVariant.IMPACT
			Heights.Level.FLYING:
				return ShotVariant.BEINSCHUSS
	return ShotVariant.NONE


func _shot_skill_name() -> String:
	match get_shot_variant():
		ShotVariant.BEINSCHUSS:
			return "Beinschuss"
		ShotVariant.UMFANG:
			return "Umfang"
		ShotVariant.IMPACT:
			# Reação Química disponível: o botão muda de nome
			return "Emperor Impact" if _find_reaction() != null else "Impact"
	# Reação Química disponível: o botão muda de nome
	return "Be Loved" if _find_superstar() != null else "Magnus"


## Inimigos (de qualquer altura) a este alcance do Kaiser
func _enemies_near(radius: float) -> Array[Player]:
	var out: Array[Player] = []
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other.team != team and global_position.distance_to(other.global_position) <= radius:
			out.append(other)
	return out


## Beinschuss: um inimigo "no chão" a 100 serve de apoio
func _support_enemy() -> Player:
	for e in _enemies_near(beinschuss_support_radius):
		if e.height_level == Heights.Level.GROUND:
			return e
	return null


## Impact: pequeno empurrão (máximo de 2) nos inimigos mais próximos
func _push_nearby_enemies() -> void:
	var list: Array[Player] = _enemies_near(impact_push_radius)
	list.sort_custom(func(a: Player, b: Player) -> bool:
		return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	for i in mini(list.size(), impact_push_max):
		var e: Player = list[i]
		var away: Vector2 = e.global_position - global_position
		away = away.normalized() if away.length() > 1.0 else Vector2(float(facing), 0.0)
		var tw: Tween = e.create_tween()
		tw.tween_property(e, "global_position", _clamp_point(e.global_position + away * impact_push_distance), 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
	if get_shot_variant() == ShotVariant.UMFANG:
		return await _use_umfang()   # arma o chute (não chuta agora)

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
			base_chance = chance_beinschuss + (beinschuss_support_bonus if _support_enemy() != null else 0.0)
			needs_qte = beinschuss_needs_qte   # por padrão sem QTE
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
	elif variant == ShotVariant.BEINSCHUSS:
		next_kick_force_mult *= beinschuss_force_mult
	elif superstar != null:
		next_kick_force_mult *= be_loved_force_mult
	else:
		next_kick_force_mult *= magnus_force_mult

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
	KaiserFX.kick_burst(self, ball.global_position, aim, false)
	KaiserFX.ball_roses(ball, magnus_flight_time + 0.6)
	_drive_ball(ball, magnus_flight_time, _magnus_step.bind(aim.angle(), speed))


func _launch_impact(ball: Ball, _dir: Vector2, _speed: float) -> void:
	_push_nearby_enemies()   # pequeno empurrão nos inimigos próximos
	KaiserFX.kick_burst(self, ball.global_position, _dir, true)
	KaiserFX.ball_roses(ball, impact_flight_time + 0.8, true)
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


# ---------- UMFANG ----------

## Mira agora e deixa o chute armado: se a bola chegar a 70 dele durante este turno e o do inimigo, ele chuta
func _use_umfang() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação
	await play_action(&"umfang")
	_umfang_dir = aim.normalized()
	_umfang_turns_left = 2   # o fim do turno dele + o fim do turno do inimigo
	start_cooldown(CD_SHOT, shot_cooldown)
	queue_redraw()
	return true


func _check_umfang() -> void:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null or m.match_over or is_down or state != State.IDLE:
		return
	if ball.hovering or ball.held_by != null or ball.collisions_paused:
		return
	if global_position.distance_to(ball.global_position) > umfang_radius:
		return
	if get_kick_type(ball) == KickType.NONE:
		return
	_fire_umfang(ball)


func _fire_umfang(ball: Ball) -> void:
	_umfang_firing = true
	var dir: Vector2 = _umfang_dir
	_umfang_turns_left = 0
	queue_redraw()
	next_kick_force_mult *= umfang_force_mult
	var chance: float = minf(chance_umfang + _shot_bonus(), 1.0)
	await kick_ball(ball, dir, get_kick_type(ball), true, chance, false, kick_fx, &"umfang")
	_umfang_firing = false


# ---------- MOVIMENTO ESCRITO (Path / Blitzkrieg) ----------

func _clamp_point(p: Vector2) -> Vector2:
	var field: Field = get_tree().get_first_node_in_group("field") as Field
	if field == null:
		return p
	var local: Vector2 = field.to_local(p)
	var half: Vector2 = field.pitch_size * 0.5 - Vector2(body_radius, body_radius)
	return field.to_global(Vector2(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y)))


## A partida terminou, a bola foi reposta depois de um gol ou ele caiu: o dash para
func _dash_should_abort() -> bool:
	var m: MatchManager = _get_manager()
	return m == null or m.match_over or m._repositioning or is_down


func _dash_begin() -> void:
	_dashing = true
	_got_ball = false
	_trail = KaiserFX.dash_trail(self, is_predator_active())
	KaiserFX.rose_burst(self, global_position + Vector2(0.0, -8.0), 4, false)


func _dash_end() -> void:
	_dashing = false
	velocity = Vector2.ZERO
	if _trail != null:
		_trail.stop()
		_trail = null
	_release_held_ball()


## Anda até "target" a "speed" px/s (colide com os outros jogadores). Com catch_ball, domina a bola se
## encostar nela. Devolve false se foi interrompido ou bloqueado.
func _dash_to(target: Vector2, speed: float, catch_ball: bool = false) -> bool:
	var token: int = _dash_token
	var stuck: int = 0
	while true:
		await get_tree().physics_frame
		if token != _dash_token or _dash_should_abort():
			velocity = Vector2.ZERO
			return false
		var to_target: Vector2 = target - global_position
		var dist: float = to_target.length()
		if dist <= 3.0:
			break
		if catch_ball and _held_ball == null:
			var found: Ball = _ball_in_reach()
			if found != null:
				_grab_ball(found)
				_got_ball = true
		var dir: Vector2 = to_target / dist
		face_towards(dir)
		_hold_dir = dir
		var dt: float = get_physics_process_delta_time()
		var step: float = minf(speed * dt, dist)
		var before: Vector2 = global_position
		velocity = dir * (step / dt)
		move_and_slide()
		global_position = _clamp_point(global_position)
		if before.distance_to(global_position) < step * 0.2:
			stuck += 1
			if stuck >= 4:
				velocity = Vector2.ZERO
				return false   # bloqueado
		else:
			stuck = 0
	velocity = Vector2.ZERO
	return true


## Mira extra no meio de uma habilidade (cancelar aqui NÃO devolve a ação, porque já aconteceu algo)
func _aim_more(range_px: float) -> Vector2:
	begin_aim(range_px)
	var dir: Vector2 = await aim_finished
	return dir


func _run_qte(title: String, keys: int, time_per_key: float) -> bool:
	var m: MatchManager = _get_manager()
	if m == null or skips_qte():
		return true
	var qte := QTE.new()
	m.add_child(qte)
	qte.start(QTE.EASY_KEYS, keys, time_per_key, title)
	var ok: bool = await qte.finished
	return ok


## Correr curto de "p" (1 s por padrão) com velocidade maior; não gasta o limite de Correr do turno
func _short_run(p: Player, seconds: float, speed_mult: float) -> void:
	if not is_instance_valid(p):
		return
	_run_boosts[p] = speed_mult
	p.start_run()
	p.runs_this_turn = maxi(0, p.runs_this_turn - 1)
	p.run_time_left = seconds
	await p.run_finished
	_run_boosts.erase(p)


## Bola ao alcance do corpo durante o dash (no chão, solta e que ele pode pegar)
func _ball_in_reach() -> Ball:
	var ball: Ball = _get_ball()
	if ball == null or ball.is_held() or ball.hovering or ball.is_locked_for(team):
		return null
	if ball.get_level() != Heights.Level.GROUND:
		return null
	var reach: float = body_radius + ball.collision_radius + dribble_catch_margin
	if global_position.distance_to(ball.global_position) > reach:
		return null
	return ball


## Gruda a bola nele (usa só Ball.held_by, a mesma flag do goleiro: ninguém mais mexe na bola)
func _grab_ball(ball: Ball) -> void:
	ball.register_touch(self)
	ball.pending_shot_chance = Ball.NO_SHOT
	ball.velocity = Vector2.ZERO
	ball.vel_z = 0.0
	ball.height = 0.0
	ball.held_by = self
	_held_ball = ball
	# Dominada: nenhum jogador (nem ele) esbarra nela enquanto estiver grudada
	_held_paused = not ball.collisions_paused
	ball.collisions_paused = true
	_snap_held_ball()
	KaiserFX.petals(self, ball.global_position, 6)   # feedback: dominou


func _hold_offset() -> Vector2:
	var dir: Vector2 = velocity if velocity.length() > 1.0 \
		else (_hold_dir if _hold_dir != Vector2.ZERO else Vector2(float(facing), 0.0))
	return dir.normalized() * (body_radius + _held_ball.collision_radius + 4.0)


func _snap_held_ball() -> void:
	_held_ball.global_position = global_position + _hold_offset()
	_held_ball.velocity = Vector2.ZERO
	_held_ball.height = 0.0


## Solta a bola grudada: ela fica parada ao lado dele
func _release_held_ball() -> void:
	_restore_held_collisions()
	if _held_ball != null and is_instance_valid(_held_ball) and _held_ball.held_by == self:
		_held_ball.held_by = null
	_held_ball = null
	_hold_dir = Vector2.ZERO


## Religa a colisão da bola que ele desligou ao dominar
func _restore_held_collisions() -> void:
	if _held_paused and _held_ball != null and is_instance_valid(_held_ball):
		_held_ball.collisions_paused = false
	_held_paused = false


## A bola grudada deixou de ser dele? (chutou, o goleiro pegou, a bola reiniciou, passe alto...)
func _held_ball_lost() -> bool:
	return not is_instance_valid(_held_ball) or _held_ball.held_by != self or _held_ball.hovering


## Durante os dashes usa a animação de correr
func _desired_anim() -> StringName:
	if _dashing and not is_down and height <= 1.0:
		return Player.ANIM_RUN
	return super()


func _physics_process(delta: float) -> void:
	super(delta)
	# Bola grudada acompanha o Kaiser (a menos que ele já tenha se desfeito dela)
	if _held_ball != null:
		if _held_ball_lost():
			_restore_held_collisions()
			if is_instance_valid(_held_ball) and _held_ball.held_by == self:
				_held_ball.held_by = null
			_held_ball = null
		else:
			_snap_held_ball()
	# Umfang armado: a bola chegou perto?
	if _umfang_turns_left > 0 and not _umfang_firing:
		_check_umfang()


# ---------- PATH ----------

func _is_path_target(p: Player) -> bool:
	return is_instance_valid(p) and p != self


func _has_path_target() -> bool:
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p != self and global_position.distance_to(p.global_position) <= path_pick_range:
			return true
	return false


func _ally_ok(p: Player) -> bool:
	return is_instance_valid(p) and p != self and not p.is_down


## Companheiros que podem receber o toque do Blitzkrieg
func _blitz_allies() -> Array[Player]:
	var out: Array[Player] = []
	var m: MatchManager = _get_manager()
	if m == null:
		return out
	for p: Player in m.get_team_players(team):
		if _ally_ok(p) and global_position.distance_to(p.global_position) <= blitz_ally_range:
			out.append(p)
	return out


func get_path_variant() -> PathVariant:
	if height_level != Heights.Level.GROUND:
		return PathVariant.NONE
	var ball: Ball = _get_ball()
	if ball != null and not ball.is_held() and ball.get_level() == Heights.Level.SUSPENDED \
			and global_position.distance_to(ball.global_position) <= blitz_ball_range \
			and not _blitz_allies().is_empty():
		return PathVariant.BLITZ
	return PathVariant.PATH if _has_path_target() else PathVariant.NONE


func _blind_now() -> bool:
	return _enemies_near(blind_enemy_radius).size() >= blind_enemies_needed


func _path_skill_name() -> String:
	if get_path_variant() == PathVariant.BLITZ:
		return "Blindheit" if _blind_now() else "Blitzkrieg"
	return "Path"


func _use_path_skill() -> bool:
	if get_path_variant() == PathVariant.BLITZ:
		return await _use_blitz()
	return await _use_path()


## Path: escolhe alguém, mira a saída e faz o dash em V contornando a pessoa
## Vértice e ponto de saída do dash em V (o V contorna quem foi escolhido). Usado pelo dash e pela prévia.
func _path_points(target: Player, exit_dir: Vector2) -> Array[Vector2]:
	var to_t: Vector2 = target.global_position - global_position
	var l1: float = to_t.length()
	var dir1: Vector2 = to_t / maxf(l1, 0.001)
	var out_dir: Vector2 = exit_dir.normalized()
	var side: float = -1.0 if dir1.cross(out_dir) >= 0.0 else 1.0   # o vértice fica do lado oposto ao da saída
	var vertex: Vector2 = _clamp_point(target.global_position + dir1.orthogonal() * side * path_vertex_offset)
	var exit_point: Vector2 = _clamp_point(vertex + out_dir * maxf(path_length - l1, path_min_exit))
	var out: Array[Vector2] = [vertex, exit_point]
	return out


func _use_path() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	m.announce_keeper("Path: escolha um aliado (cancele para escolher um inimigo)", team)
	var target: Player = await m.pick_ally_for_skill(self, path_pick_range, false, _is_path_target)
	if target == null and not m.match_over:
		m.announce_keeper("Path: escolha um inimigo (cancele para sair)", team)
		target = await m.pick_ally_for_skill(self, path_pick_range, true, _is_path_target)
	if target == null or m.match_over:
		return false   # cancelou: não gasta a ação
	# Quanto o V é aberto = para onde ele sai depois de contornar a pessoa
	# Enquanto mira, a prévia tracejada mostra o V que ele vai fazer
	_preview_target = target
	_preview_kind = PathPreview.PATH
	queue_redraw()
	var aim: Vector2 = await m.aim_for_skill(self, path_length)
	_preview_kind = PathPreview.NONE
	_preview_target = null
	queue_redraw()
	if aim == Vector2.ZERO or m.match_over:
		return false
	if not await play_action(&"path"):
		return false
	if m.match_over or not is_instance_valid(target):
		return false

	var pts: Array[Vector2] = _path_points(target, aim)
	var vertex: Vector2 = pts[0]
	var exit_point: Vector2 = pts[1]

	add_collision_exception_with(target)   # ele passa "por dentro" de quem contorna
	target.add_collision_exception_with(self)
	_dash_begin()
	if await _dash_to(vertex, dash_speed, true):
		await _dash_to(exit_point, dash_speed, true)
	var had_ball: bool = _got_ball
	_dash_end()
	if is_instance_valid(target):
		remove_collision_exception_with(target)
		target.remove_collision_exception_with(self)

	# Achou a bola no caminho: QTE fácil para ganhar uma ação de habilidade
	if had_ball and await _run_qte("Path!", path_qte_keys, path_qte_time):
		extra_skill_left += 1
	# Garçom: ganha um Correr curto mais rápido e o efeito dele sobe
	if is_instance_valid(target) and target in _waiters:
		_waiter_extra += path_waiter_gain
		await _short_run(target, path_waiter_run_time, path_waiter_run_speed)
	start_cooldown(CD_PATH, path_cooldown)
	return true


# ---------- BLITZKRIEG / BLINDHEIT ----------

## Curva (Bézier) de 8 pontos saindo de "origin" na direção "dir", com "length" de comprimento
## bend_sign = +1 / -1 escolhe o lado da curva; 0 sorteia
func _arc_points(origin: Vector2, dir: Vector2, length: float, bend_sign: float = 0.0) -> Array[Vector2]:
	var d: Vector2 = dir.normalized()
	var bend: float = bend_sign if bend_sign != 0.0 else (1.0 if randf() < 0.5 else -1.0)
	var control: Vector2 = origin + d * length * 0.5 + d.orthogonal() * length * 0.35 * bend
	var end_point: Vector2 = origin + d * length
	var pts: Array[Vector2] = []
	for i in range(1, 9):
		var t: float = float(i) / 8.0
		pts.append(_clamp_point(origin.lerp(control, t).lerp(control.lerp(end_point, t), t)))
	return pts


func _launch_blitz(ball: Ball, _dir: Vector2, _speed: float) -> void:
	KaiserFX.kick_burst(self, ball.global_position, _dir, true)
	KaiserFX.ball_roses(ball, impact_flight_time + 0.8, true)
	_drive_ball(ball, impact_flight_time, _impact_step)


func _use_blitz() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false
	m.announce_keeper("Blitzkrieg: escolha o aliado que recebe o toque", team)
	var ally: Player = await m.pick_ally_for_skill(self, blitz_ally_range, false, _ally_ok)
	if ally == null or m.match_over:
		return false   # cancelou: não gasta a ação
	# O lado da curva é sorteado ANTES da mira, para a prévia tracejada ser a mesma do dash
	_blitz_bend = 1.0 if randf() < 0.5 else -1.0
	_preview_kind = PathPreview.BLITZ
	queue_redraw()
	var arc_dir: Vector2 = await m.aim_for_skill(self, blitz_arc_length)
	_preview_kind = PathPreview.NONE
	queue_redraw()
	if arc_dir == Vector2.ZERO or m.match_over:
		return false
	if not await play_action(&"blitzkrieg"):
		return false

	_dash_begin()
	# 1) vai até a bola, salta e domina
	var ok: bool = await _dash_to(ball.global_position, dash_speed)
	if ok:
		await jump()
		ball.register_touch(self)
		# Domina: a bola gruda nele no ar por um instante antes de ir para o aliado
		if blitz_catch_time > 0.0 and is_instance_valid(ball) and not m.match_over:
			KaiserFX.petals(self, ball.global_position + Vector2(0.0, -ball.height), 6)
			await ball.hover_to(global_position, Heights.SUSPENDED_HEIGHT, blitz_catch_time).finished
		if m.match_over or not is_instance_valid(ball) or not is_instance_valid(ally):
			ok = false
	if ok:
		# 2) toca num aliado (a bola vai Suspensa até ele)
		await ball.hover_to(ally.global_position, Heights.SUSPENDED_HEIGHT, blitz_pass_time).finished
		land()
		# 3) dash curvo de 280
		for p in _arc_points(global_position, arc_dir, blitz_arc_length, _blitz_bend):
			if not await _dash_to(p, dash_speed):
				ok = false
				break
	if not ok or m.match_over:
		_dash_end()
		if is_instance_valid(ball) and ball.hovering and ball.held_by == null:
			ball.release_hover()   # interrompido: a bola não fica pairando para sempre
		start_cooldown(CD_PATH, path_cooldown)
		return true

	# 4) o aliado devolve a bola Suspensa enquanto o Kaiser salta com ela
	_dash_end()
	ally.face_towards(global_position - ally.global_position)
	await ally.play_action(Player.ANIM_PASS_HIGH, Player.ANIM_PASS)
	ball.register_touch(ally)
	jump()   # sem await: sobe junto com a bola
	await ball.hover_to(global_position, Heights.SUSPENDED_HEIGHT, blitz_pass_time).finished

	# 5) chute rápido (a bola vai Suspensa). Blindheit: 2+ inimigos perto = mais forte e ignora a colisão deles.
	var blind: bool = _blind_now()
	var dir: Vector2 = await _aim_more(kick_aim_range)
	if dir == Vector2.ZERO:
		dir = Vector2(float(facing), 0.0)
	if blind:
		m.announce_keeper("You're fucking blind.", team)
		ball.collisions_paused = true   # nenhum jogador trava a bola durante o chute
		get_tree().create_timer(impact_flight_time + 0.4).timeout.connect(func() -> void:
			if is_instance_valid(ball):
				ball.collisions_paused = false)
	next_kick_force_mult *= blitz_force_mult + (blind_force_add if blind else 0.0)
	var chance: float = minf(chance_blitz + (blind_bonus if blind else 0.0) + _shot_bonus(), 1.0)
	await kick_ball(ball, dir, KickType.VOLLEY, true, chance, false, kick_fx, &"blitzkrieg", _launch_blitz)
	start_cooldown(CD_PATH, path_cooldown)
	return true


# ---------- OPFER (Garçom) ----------

## Garçom com a bola ao alcance do pé e o Kaiser dentro do alcance do Opfer
func _find_opfer_waiter() -> Player:
	var ball: Ball = _get_ball()
	if ball == null:
		return null
	var best: Player = null
	var best_dist: float = INF
	for w in _waiters:
		if not is_instance_valid(w) or w.is_down or w.is_locked():
			continue
		if w.get_kick_type(ball) == KickType.NONE:
			continue
		if w.global_position.distance_to(global_position) > opfer_range:
			continue
		var d: float = w.global_position.distance_to(ball.global_position)
		if d < best_dist:
			best = w
			best_dist = d
	return best


## A bola chegou perto de quem devia receber? (se um inimigo interceptou, o Opfer para)
func _pass_ok(ball: Ball, receiver: Player) -> bool:
	return is_instance_valid(ball) and is_instance_valid(receiver) \
		and ball.global_position.distance_to(receiver.global_position) <= receiver.kick_range * 1.5 + 40.0


func _use_opfer() -> bool:
	var m: MatchManager = _get_manager()
	var waiter: Player = _find_opfer_waiter()
	var ball: Ball = _get_ball()
	if m == null or waiter == null or ball == null:
		return false
	start_cooldown(CD_OPFER, opfer_cooldown)
	# 1) o Garçom passa rasteiro para o Kaiser e corre 1 s (mais rápido)
	await m.run_curved_ground_pass(waiter, self, ball, 0.0, 1.0, &"", kick_fx)
	if not _pass_ok(ball, self) or m.match_over:
		return true
	await _short_run(waiter, opfer_run_time, opfer_run_speed)
	# 2) o Kaiser devolve e corre também
	await m.run_curved_ground_pass(self, waiter, ball, 0.0, 1.0, &"", kick_fx)
	if not _pass_ok(ball, waiter) or m.match_over:
		return true
	await _short_run(self, opfer_run_time, opfer_run_speed)
	# 3) ao fim, o aliado faz um último passe rasteiro para o Kaiser
	if _pass_ok(ball, waiter):
		await m.run_curved_ground_pass(waiter, self, ball, 0.0, 1.0, &"", kick_fx)
	return true


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"id": SKILL_SHOT, "name": skill_label(_shot_skill_name(), CD_SHOT)})
	list.append({"id": SKILL_PATH, "name": skill_label(_path_skill_name(), CD_PATH)})
	list.append({"id": SKILL_EMPIRE, "name": "Empire (%d)" % _empire_uses_left})
	list.append({"id": SKILL_KNEE, "name": skill_label("Auf die Knee", CD_KNEE)})
	list.append({"id": SKILL_OPFER, "name": skill_label("Opfer", CD_OPFER)})
	return list


## Auf die Knee NÃO gasta a ação de habilidade do Kaiser (só uma ação geral do Palhaço)
func skill_is_free(skill_id: StringName) -> bool:
	return skill_id == SKILL_KNEE


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_SHOT:
			return not is_on_cooldown(CD_SHOT) and get_shot_variant() != ShotVariant.NONE
		SKILL_PATH:
			return not is_on_cooldown(CD_PATH) and get_path_variant() != PathVariant.NONE
		SKILL_EMPIRE:
			return _empire_uses_left > 0 and not _empire_candidates().is_empty()
		SKILL_KNEE:
			return not is_on_cooldown(CD_KNEE) and _find_knee_clown() != null
		SKILL_OPFER:
			return not is_on_cooldown(CD_OPFER) and _find_opfer_waiter() != null
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_SHOT:
			return await _use_shot_skill()
		SKILL_PATH:
			return await _use_path_skill()
		SKILL_EMPIRE:
			return await _use_empire()
		SKILL_KNEE:
			return await _use_knee()
		SKILL_OPFER:
			return await _use_opfer()
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
						text = "Chute com curva fixa que sobe até Suspenso durante o trajeto. %.1fx de força e %d%% de chance de gol." % [
							magnus_force_mult, _pct(chance_magnus)]
				ShotVariant.BEINSCHUSS:
					text = "Bicicleta no ar. %.1fx de força e %d%% de chance de gol. Com um inimigo no chão a %d, ele serve de apoio (+%d%%)." % [
						beinschuss_force_mult, _pct(chance_beinschuss), int(beinschuss_support_radius), _pct(beinschuss_support_bonus)]
				ShotVariant.IMPACT:
					var reaction: ChemicalReaction = _find_reaction()
					if reaction != null:
						title = "Emperor Impact"
						text = "Reação Química Herbivicus com o Ness: chute reto, mais forte e mais rápido, com uma rosa azul gigante. %d%% de chance de gol.\nA reação recarrega em %d rodadas." % [
							_pct(chance_emperor), reaction.cooldown_rounds]
					else:
						text = "Chute reto e rápido, %.1fx de força e %d%% de chance de gol. Inimigos a %d levam um pequeno empurrão (até %d)." % [
							impact_force_mult, _pct(chance_impact), int(impact_push_radius), impact_push_max]
				ShotVariant.UMFANG:
					text = "Sem a bola por perto: mira agora e deixa um chute instantâneo armado neste turno e no do inimigo (um círculo azul mostra o alcance e a seta, a direção). Se a bola chegar a %d dele, chuta com %.1fx de força e %d%% de chance de gol." % [
						int(umfang_radius), umfang_force_mult, _pct(chance_umfang)]
				_:
					text = "Chute especial que muda conforme a altura dele e da bola. De %d%% a %d%% de chance de gol." % [
						_pct(minf(chance_magnus, minf(chance_beinschuss, chance_impact))),
						_pct(maxf(chance_magnus, maxf(chance_beinschuss, chance_impact)))]
			text += "\nRecarga: %d rodadas." % shot_cooldown
		SKILL_PATH:
			title = _path_skill_name()
			if get_path_variant() == PathVariant.BLITZ:
				text = "Vai até a bola Suspensa, salta e a domina, toca num aliado (até %d), faz um dash curvo de %d (uma linha tracejada mostra o caminho antes) e o aliado devolve a bola; Kaiser salta e chuta rápido (%.1fx, %d%%)." % [
					int(blitz_ally_range), int(blitz_arc_length), blitz_force_mult, _pct(chance_blitz)]
				text += "\nBlindheit: com %d+ inimigos a %d, o chute ganha +%.1fx e +%d%% e ignora a colisão deles." % [
					blind_enemies_needed, int(blind_enemy_radius), blind_force_add, _pct(blind_bonus)]
			else:
				text = "Escolhe um aliado ou inimigo (até %d) e faz um dash em V contornando a pessoa (%d). Uma linha tracejada mostra o caminho antes de ele ir. Se alcançar a bola durante o dash, domina (ela gruda nele) e faz um QTE fácil para ganhar uma ação de habilidade. Em um Garçom, ele ganha um Correr de %d s mais rápido e o efeito do Garçom sobe %d%%." % [
					int(path_pick_range), int(path_length), int(path_waiter_run_time), _pct(path_waiter_gain)]
			text += "\nRecarga: %d rodadas (compartilhada)." % path_cooldown
		SKILL_EMPIRE:
			title = "Empire"
			text = (("Marca dois jogadores do time pela partida toda (dá para marcar só um). O Garçom dá +%d%% de chance de gol aos chutes do Kaiser depois de um passe dele, +%d de alcance no Passe e libera o Opfer; o Palhaço libera o Auf die Knee.\n"
				+ "Usos restantes: %d.") % [_pct(waiter_bonus + _waiter_extra), int(waiter_pass_range_bonus), _empire_uses_left])
		SKILL_KNEE:
			title = "Auf die Knee"
			text = "Obriga o Palhaço a passar a bola para o Kaiser. Não gasta a ação de habilidade do Kaiser, só uma ação geral do Palhaço.\nRecarga: %d rodadas." % knee_cooldown
		SKILL_OPFER:
			title = "Opfer"
			text = "Passe rasteiro (até %d) do Garçom para o Kaiser; o Garçom corre %d s (%.1fx), o Kaiser devolve e corre também, e no fim o aliado passa de novo para o Kaiser.\nRecarga: %d rodadas." % [
				int(opfer_range), int(opfer_run_time), opfer_run_speed, opfer_cooldown]
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()
	_pass_bonus_applied = false   # o super() já zerou o pass_range_bonus
	_clear_servants()
	_empire_uses_left = empire_starting_uses
	_waiter_extra = 0.0
	_vision = Vision.META
	_sync_vision_fx()
	_meta_rounds = 0
	_aiming_magnus = false
	_preview_kind = PathPreview.NONE
	_preview_target = null
	_umfang_turns_left = 0
	_umfang_firing = false
	_dash_token += 1
	_dashing = false
	if _trail != null:
		_trail.stop()
		_trail = null
	_release_held_ball()
	_run_boosts.clear()
	run_duration = _base_run_duration
	queue_redraw()


# ---------- VISUAL ----------

func _draw() -> void:
	super()
	var center := Vector2(0.0, -height)

	# (Metavisão = radar e Olhar do Predador = garras: nós próprios, veja KaiserFX.VisionAura)

	# Umfang armado: um círculo azul no alcance do disparo e uma seta simples na direção do chute
	if _umfang_turns_left > 0 and _umfang_dir != Vector2.ZERO:
		var ucol := Color(0.35, 0.58, 1.0, 0.9)
		draw_circle(center, umfang_radius, Color(ucol, 0.1))
		draw_arc(center, umfang_radius, 0.0, TAU, 40, ucol, 3.0, true)
		var d: Vector2 = _umfang_dir
		var side: Vector2 = d.orthogonal() * 8.0
		var head_base: Vector2 = center + d * (umfang_radius - 16.0)
		draw_line(center + d * 8.0, head_base, ucol, 3.0, true)
		draw_colored_polygon(PackedVector2Array([center + d * (umfang_radius - 2.0), head_base + side, head_base - side]), ucol)

	# Magnus: linha tracejada = o caminho real da bola (a seta laranja do Player é a linha da mira)
	if is_aiming and _aiming_magnus:
		_draw_magnus_preview()

	# Path / Blitzkrieg / Blindheit: prévia tracejada de para onde o dash vai
	if is_aiming and _preview_kind != PathPreview.NONE:
		_draw_dash_preview()


## Linha tracejada com seta: o caminho que o Kaiser fará (mesmas contas do dash de verdade)
func _draw_dash_preview() -> void:
	var pts: Array[Vector2] = [Vector2.ZERO]
	match _preview_kind:
		PathPreview.PATH:
			if not is_instance_valid(_preview_target):
				return
			for pt: Vector2 in _path_points(_preview_target, aim_direction):
				pts.append(to_local(pt))
		PathPreview.BLITZ:
			var ball: Ball = _get_ball()
			if ball == null:
				return
			pts.append(to_local(ball.global_position))   # 1º trecho: até a bola
			for pt: Vector2 in _arc_points(ball.global_position, aim_direction, blitz_arc_length, _blitz_bend):
				pts.append(to_local(pt))                  # 2º trecho: o dash curvo
	KaiserFX.draw_dash_preview(self, pts, Color(0.45, 0.68, 1.0))


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
	else:
		speed *= magnus_force_mult
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
