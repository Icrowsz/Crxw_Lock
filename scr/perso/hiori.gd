class_name Hiori
extends Player
## Hiori. Mais um personagem do time (depois de Isagi, Rin e Charles), com 3 habilidades:
##
## 1. Chilling Pass / No Look Cross (ação de habilidade, com 2 variantes automáticas pela
##      altura de Hiori; recarga de 2 rodadas, compartilhada entre as duas):
##      - Hiori no chão + bola no chão ou Suspensa -> Chilling Pass: passe alto (alcance 525)
##          para um ALIADO. Igual ao Passe Alto comum: a bola sobe ao nível Voando no meio
##          do caminho e PAIRA lá; quando o turno de Hiori voltar, desce ao nível Suspenso
##          no aliado (ou onde ele estava, se saiu do alcance). Cai sozinha se ninguém tocar.
##          Sem QTE (igual ao Passe Alto comum).
##      - Hiori Suspenso + bola próxima -> No Look Cross: a mesma mecânica do Chilling Pass,
##          só que com alcance bem maior (575px). Também sem QTE.
##
## 2. Glacial Cut + Ultrasadist (ação de habilidade; recarga de 3 rodadas):
##      - Glacial Cut: Hiori faz uma corrida curta (menos tempo que o Correr normal, mas um
##          pouco mais rápida) — NÃO é a ação geral Correr, não gasta nem conta como ela
##          (runs_this_turn não muda). Se, durante essa corrida, ele chegar perto o
##          suficiente da bola, libera o complemento Ultrasadist.
##      - Ultrasadist: só aparece depois de um Glacial Cut que alcançou a bola. É GRATUITO
##          (skill_is_free) — então os dois juntos continuam contando como uma única ação
##          de habilidade, igual ao Draconic Header do Shidou (ver player.gd). Funciona como
##          o Rabona Cross do Charles: Hiori escolhe um LOCAL do campo (alcance 550) em vez
##          de um aliado; a bola sobe a Voando e pousa lá, Suspensa, NA MESMA RODADA. QTE fácil: errar
##          encurta e desvia o local. Se o turno de Hiori terminar sem usá-lo, a chance
##          se perde.
##
## 3. Coldest Metavision (ação de habilidade; recarga de 3 rodadas, a partir do fim do
##      efeito — não especificada pelo design, ajuste à vontade):
##      Por algumas rodadas: a PRÓXIMA ação Correr de Hiori ganha mais segundos; os chutes
##      do próprio Hiori e os chutes de quem acabou de receber um passe DELE (suas
##      assistências, enquanto a habilidade durar) ganham +8% de chance de gol; e Hiori
##      ganha acesso a uma de duas habilidades extras, dependendo do lado do campo em que
##      estiver:
##      - Lado da DEFESA -> Frost Guard: com a bola Suspensa e perto, Hiori salta até ela e
##          dá um "deflect", mandando-a para a direção contrária. Recarga de 2 rodadas.
##      - Lado do ATAQUE -> Cryo Shot: chute comum, SEM QTE, com Hiori e a bola no chão ou
##          Suspensos (qualquer combinação dessas duas, menos Voando). Recarga de 2 rodadas.
##
## PEÇAS PEQUENAS NO RESTO DO PROJETO (já aplicadas, se você usou os arquivos que eu
## devolvi):
## - match_manager.gd: run_skill_high_pass() — versão pública do passe alto (_run_high_pass)
##   para habilidades, com animação/aura própria e alcance próprio. Usada pelo Chilling
##   Pass / No Look Cross.
##
## Reação Química ONE MORE TIME (com o Isagi, veja reaction_one_more_time.gd): o Ultrasadist anota
## o último uso em last_ultrasadist (a reação lê isto) e, quando cumpre as condições da reação,
## sai brilhando e congelando o chão por onde a bola passa (charged_fx + one_more_time_fx.gd).
##
## Reação Química SACRIFICE (com o Karasu, veja reaction_sacrifice.gd): se o Karasu passou para o
## Hiori e depois usou o Wings Block, e a Coldest Metavision está ativa no lado do ataque, o Cryo
## Shot vira o LOUD CROW. Mirando NO KARASU: cutscene, chute mais forte com 90% de chance de gol e a
## bola ignora a colisão do Karasu e dos inimigos (passa por cima deles), com gelo e vidro quebrando
## no trajeto (sacrifice_fx.gd). Mirando para outro lado sai o Cryo Shot normal e a reação não é gasta.
##
## Como montar a cena: igual ao Isagi/Rin/Charles — Nova Cena Herdada de player.tscn ->
## anexe este script ao nó raiz -> renomeie o nó raiz para "Hiori".

const SKILL_PASS: StringName = &"chilling_pass"
const SKILL_GLACIAL: StringName = &"glacial_cut"
const SKILL_ULTRASADIST: StringName = &"ultrasadist"
const SKILL_METAVISION: StringName = &"coldest_metavision"
const SKILL_FROST_GUARD: StringName = &"frost_guard"
const SKILL_CRYO_SHOT: StringName = &"cryo_shot"

## id da reação Sacrifice (reaction_sacrifice.gd)
const SACRIFICE_ID: StringName = &"sacrifice"

## Grupos de recarga (as variantes/complementos de cada habilidade compartilham o mesmo)
const CD_PASS: StringName = &"cd_pass"
const CD_GLACIAL: StringName = &"cd_glacial"
const CD_METAVISION: StringName = &"cd_metavision"
const CD_FROST_GUARD: StringName = &"cd_frost_guard"
const CD_CRYO_SHOT: StringName = &"cd_cryo_shot"

## Variante da habilidade 1, pela altura de Hiori
enum PassVariant { NONE, CHILLING, NO_LOOK }

@export_group("Chilling Pass / No Look Cross")
@export var chilling_pass_range: float = 525.0
@export var no_look_cross_range: float = 575.0
@export var pass_cooldown: int = 2

@export_group("Glacial Cut / Ultrasadist")
@export var glacial_cut_duration: float = 0.9          # run_duration padrão costuma ser maior
@export var glacial_cut_speed_mult: float = 1.3         # "um pouco mais veloz" que o Correr normal
@export var ultrasadist_range: float = 550.0
@export_range(0.0, 1.0) var ultrasadist_qte_fail_range_mult: float = 0.5   # alcance que sobra se errar o QTE
@export_range(0.0, 90.0) var ultrasadist_qte_fail_angle: float = 35.0      # desvio (graus) se errar o QTE
@export var glacial_cooldown: int = 3

@export_group("Coldest Metavision")
@export var metavision_rounds: int = 3
@export var metavision_run_bonus: float = 1.0                   # segundos extra na PRÓXIMA Correr
@export_range(0.0, 1.0) var metavision_self_shot_bonus: float = 0.08     # +8% nos chutes do próprio Hiori
@export_range(0.0, 1.0) var metavision_assist_shot_bonus: float = 0.08   # +8% em quem chuta após receber dele
@export var metavision_cooldown: int = 3    # a partir do fim do efeito

@export_group("Frost Guard (lado da defesa)")
@export var frost_guard_reach: float = 80.0
@export var frost_guard_force: float = 110.0
@export var frost_guard_cooldown: int = 2

@export_group("Cryo Shot (lado do ataque)")
@export_range(0.0, 1.0) var cryo_shot_chance: float = 0.30
@export var cryo_shot_cooldown: int = 2

@export_group("Loud Crow (reação Sacrifice)")
@export_range(0.0, 1.0) var loud_crow_chance: float = 0.90      # chance de gol (valor base)
@export var loud_crow_force_mult: float = 1.35                  # mais forte que o Cryo Shot (1.0)
## Tolerância da mira no Karasu (px): a linha da mira precisa passar a esta distância do corpo dele
@export var loud_crow_aim_tolerance: float = 36.0
## Altura do "pulo" visual da bola por cima do Karasu e dos inimigos (px; o nível da bola não muda)
@export var loud_crow_hop_height: float = 46.0
## Aura do chute. Vazio = usa o estilo padrão (veja _make_loud_crow_fx)
@export var loud_crow_fx: KickFX

@export_group("Visual do chute")
## Aura + partículas dos chutes/passes de habilidade. Vazio = usa o estilo padrão (veja _make_kick_fx)
@export var kick_fx: KickFX
## Aura do Ultrasadist quando ele cumpre as condições da reação One More Time. Vazio = estilo padrão
@export var charged_fx: KickFX

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: chilling_pass, glacial_cut,
## ultrasadist, coldest_metavision, frost_guard, cryo_shot.
@export var skill_icons: Dictionary = {}

## Glacial Cut alcançou a bola: Ultrasadist está esperando ser usado (grátis) ainda
## neste turno. Vira false sozinho quando o turno de Hiori acaba.
var _glacial_ready: bool = false
## Coldest Metavision vale até o fim desta rodada (-1 = inativa)
var _metavision_until_round: int = -1
## Último aliado que recebeu um passe de Hiori com a Metavision ativa (ganha o bônus
## de chute enquanto ela durar)
var _assist_target: Player = null
## A próxima chamada de start_run() deve somar o bônus da Coldest Metavision?
var _coldest_run_bonus_pending: bool = false

## Último Ultrasadist usado (as Reações Químicas leem isto, ex: One More Time):
## {"landing": local escolhido, "touches": toques na bola logo depois do passe}
var last_ultrasadist: Dictionary = {}

## Mirando o Loud Crow: o desenho destaca o Karasu e mostra se a mira está nele
var _aiming_loud_crow: bool = false
var _loud_crow_partner: Player = null


func _init() -> void:
	character_id = "hiori"   # o menu de formação usa isto para saber quem é quem
	display_name = "Hiori"   # troque aqui se quiser o nome completo


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = _make_kick_fx()
	if charged_fx == null:
		charged_fx = _make_charged_fx()
	if loud_crow_fx == null:
		loud_crow_fx = _make_loud_crow_fx()
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
	if m:
		m.pass_completed.connect(_on_pass_completed)
		m.turn_ended.connect(_on_turn_ended)


## Quem recebeu o passe, enquanto a Coldest Metavision estiver ativa, vira o alvo da
## assistência (ver shot_bonus_for_ally)
func _on_pass_completed(passer: Player, target: Player) -> void:
	if passer == self and is_metavision_active():
		_assist_target = target


## O turno de Hiori acabou: a chance "grátis" do Ultrasadist se perde se não foi usada
func _on_turn_ended(ended_team: int) -> void:
	if ended_team == team and _glacial_ready:
		_glacial_ready = false
		queue_redraw()


# ---------- HABILIDADE 1: CHILLING PASS / NO LOOK CROSS ----------

func get_pass_variant() -> PassVariant:
	var ball: Ball = _get_ball()
	if ball == null or ball.is_held() or ball.is_locked_for(team):
		return PassVariant.NONE
	if global_position.distance_to(ball.global_position) > kick_range:
		return PassVariant.NONE
	if ball.get_level() == Heights.Level.FLYING:
		return PassVariant.NONE
	if height_level == Heights.Level.SUSPENDED:
		return PassVariant.NO_LOOK
	if height_level == Heights.Level.GROUND:
		return PassVariant.CHILLING
	return PassVariant.NONE


func _pass_skill_name() -> String:
	if get_pass_variant() == PassVariant.NO_LOOK:
		return "No Look Cross"
	return "Chilling Pass"


func _use_pass_skill() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	match get_pass_variant():
		PassVariant.CHILLING:
			return await _use_chilling_pass(m)
		PassVariant.NO_LOOK:
			return await _use_no_look_cross(m)
	return false


func _use_chilling_pass(m: MatchManager) -> bool:
	var ball: Ball = _get_ball()
	var target: Player = await m.pick_ally_for_skill(self, chilling_pass_range)
	if target == null:
		return false   # cancelou: não gasta a ação

	# A situação pode ter mudado (Hiori pulou, a bola subiu...) enquanto ele escolhia o alvo
	if get_pass_variant() != PassVariant.CHILLING:
		return false

	PassFX.arm(ball, PassFX.Style.CHILLING)   # fita gelada e floquinhos: começa quando a bola sai
	await m.run_skill_high_pass(self, target, ball, chilling_pass_range, &"chilling_pass", kick_fx)
	start_cooldown(CD_PASS, pass_cooldown)
	return true


func _use_no_look_cross(m: MatchManager) -> bool:
	var ball: Ball = _get_ball()
	var target: Player = await m.pick_ally_for_skill(self, no_look_cross_range)
	if target == null:
		return false   # cancelou: não gasta a ação

	if get_pass_variant() != PassVariant.NO_LOOK:
		return false

	await m.run_skill_high_pass(self, target, ball, no_look_cross_range, &"no_look_cross", kick_fx)
	start_cooldown(CD_PASS, pass_cooldown)
	return true


# ---------- HABILIDADE 2: GLACIAL CUT / ULTRASADIST ----------

## Corrida curta e um pouco mais rápida que o Correr normal. NÃO é a ação geral Correr:
## não mexe em runs_this_turn nem precisa dela sobrando. Se chegar perto da bola durante
## a corrida, libera o Ultrasadist (complemento gratuito, ver can_use_skill/skill_is_free).
func _use_glacial_cut() -> bool:
	state = State.RUNNING
	var time_left: float = glacial_cut_duration
	var reached: bool = false
	while time_left > 0.0:
		await get_tree().physics_frame
		var delta: float = get_physics_process_delta_time()
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		velocity = dir * (move_speed * glacial_cut_speed_mult)
		move_and_slide()
		time_left -= delta

		if not reached:
			var ball: Ball = _get_ball()
			if ball != null and not ball.is_held() and not ball.is_locked_for(team) \
					and ball.get_level() != Heights.Level.FLYING \
					and global_position.distance_to(ball.global_position) <= kick_range:
				reached = true
		queue_redraw()

	velocity = Vector2.ZERO
	state = State.IDLE
	start_cooldown(CD_GLACIAL, glacial_cooldown)
	_glacial_ready = reached
	queue_redraw()
	return true


## Complemento gratuito do Glacial Cut (só existe se ele alcançou a bola). Igual ao Rabona
## Cross do Charles: Hiori escolhe um LOCAL do campo em vez de um aliado.
func _use_ultrasadist() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false

	var landing: Vector2 = await m.pick_point_for_skill(self, ultrasadist_range)
	if landing == Vector2.INF:
		return false   # cancelou: a chance continua valendo até o turno acabar
	if ball.is_held() or ball.is_locked_for(team):
		return false   # a bola saiu de jogo enquanto ele escolhia o local

	_glacial_ready = false   # consumida: só dá uma chance por Glacial Cut

	var dir: Vector2 = landing - global_position
	dir = dir.normalized() if dir.length() > 0.01 else Vector2(_default_facing(), 0.0)
	face_towards(dir)
	if not await play_action(&"ultrasadist", ANIM_PASS_HIGH):
		return false   # ação cancelada (ex: a partida reiniciou)

	var qte_ok: bool = true
	if not skips_qte():
		qte_ok = await m.run_qte(KickType.VOLLEY)   # QTE fácil

	if not qte_ok:
		# Errou: o local sai mais perto do que o clicado e um pouco torto
		var bad_dir: Vector2 = dir.rotated(deg_to_rad(randf_range(-ultrasadist_qte_fail_angle, ultrasadist_qte_fail_angle)))
		var dist: float = global_position.distance_to(landing) * ultrasadist_qte_fail_range_mult
		landing = global_position + bad_dir * dist

	ball.register_touch(self)   # o passe alto não usa kick(), então registra o toque aqui

	# One More Time (Hiori + Isagi): se este Ultrasadist cumpre as condições da reação, ele brilha e
	# congela o chão por onde a bola passa (até ela chegar ao local)
	var charged: bool = ReactionOneMoreTime.is_ultrasadist_charged(self)
	last_ultrasadist = {}
	if charged:
		ball.play_fx(charged_fx)
		OneMoreTimeFX.attach_frost_trail(ball, OneMoreTimeFX.Style.ULTRASADIST)
		OneMoreTimeFX.ice_burst(self, ball.sprite.global_position, 40)
	elif kick_fx:
		ball.play_fx(kick_fx)
	if not charged:
		PassFX.attach(ball, PassFX.Style.ULTRASADIST)   # lascas de gelo (o carregado já tem os efeitos da One More Time)
	var midpoint: Vector2 = (ball.global_position + landing) * 0.5
	var tween: Tween = ball.hover_to(midpoint, Heights.FLYING_HEIGHT, 0.9)
	await tween.finished

	# Chega NA MESMA RODADA: a bola desce até o local (Suspensa) agora, sem esperar o próximo turno.
	# O register_skill_pass deixa ela pairando lá até alguém tocar ou o turno acabar (aí ela cai).
	var arrive: Tween = ball.hover_to(landing, Heights.SUSPENDED_HEIGHT, m.high_pass_arrive_time)
	await arrive.finished
	m.register_skill_pass(team, null)

	# Avisa as Reações Químicas (a One More Time lê isto): o Ultrasadist saiu e a bola é dele
	last_ultrasadist = {"landing": landing, "touches": ball.interaction_count}
	if charged:
		OneMoreTimeFX.ice_burst(self, ball.sprite.global_position, 30)
	queue_redraw()
	return true


# ---------- HABILIDADE 3: COLDEST METAVISION (+ FROST GUARD / CRYO SHOT) ----------

func is_metavision_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _metavision_until_round >= 0 and m.round_number <= _metavision_until_round


## +8% nos chutes do próprio Hiori enquanto a Metavision estiver ativa
func get_shot_chance(kind: KickType) -> float:
	var base: float = super(kind)
	if is_metavision_active():
		base += metavision_self_shot_bonus
	return base


## +8% no chute de quem acabou de receber um passe de Hiori (a assistência), enquanto a
## Metavision durar (ver _on_pass_completed)
func shot_bonus_for_ally(shooter: Player, _ball: Ball) -> float:
	if is_metavision_active() and shooter == _assist_target:
		return metavision_assist_shot_bonus
	return 0.0


## Lado do campo em que Hiori está AGORA (metade do próprio gol). Considera a troca de lado
## do 2º tempo (ver o comentário de cabeçalho do field.gd).
func _is_on_defense_side() -> bool:
	var field := get_tree().get_first_node_in_group("field") as Field
	var x: float = global_position.x if field == null else field.to_local(global_position).x
	return x * get_attack_dir() < 0.0


## Soma o bônus de tempo na PRÓXIMA corrida (gasto na hora: start_run() some com o
## bônus de novo depois de usá-lo, pra não valer pra corridas futuras)
func start_run() -> void:
	var bonus_applied: bool = _coldest_run_bonus_pending
	if bonus_applied:
		run_time_bonus += metavision_run_bonus
		_coldest_run_bonus_pending = false
	super()
	if bonus_applied:
		run_time_bonus -= metavision_run_bonus


func _use_metavision() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	await play_action(&"coldest_metavision")
	_metavision_until_round = m.round_number + metavision_rounds
	_coldest_run_bonus_pending = true
	start_cooldown(CD_METAVISION, metavision_cooldown, _metavision_until_round + 1)
	queue_redraw()
	return true


## Frost Guard: bola Suspensa e perto, lado da defesa -> Hiori salta até ela e deflete
## para a direção contrária (um "chute" sem chance de gol: é defesa, não ataque).
func _use_frost_guard() -> bool:
	var ball: Ball = _get_ball()
	if ball == null:
		return false

	face_towards(ball.global_position - global_position)
	await jump()
	if not await play_action(&"frost_guard", ANIM_JUMP):
		return false

	var reflect_dir: Vector2 = -ball.velocity.normalized() if ball.velocity.length() > 1.0 \
		else Vector2(-facing, 0.0)
	ball.kick(reflect_dir, frost_guard_force,
		Heights.lift_for_peak(Heights.SUSPENDED_HEIGHT, ball.gravity), self, Ball.NO_SHOT)
	if kick_fx:
		ball.play_fx(kick_fx)

	start_cooldown(CD_FROST_GUARD, frost_guard_cooldown)
	return true


## Cryo Shot: chute comum sem QTE, Hiori e bola no chão ou Suspensos (qualquer combinação
## dessas duas, nunca Voando), lado do ataque.
## Reação Sacrifice (Loud Crow): se mirar no Karasu, a cutscene roda e o chute sai especial.
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

	# Reação Química (Sacrifice): só vale se a mira passa pelo Karasu. A partida congela, roda a
	# cutscene e SÓ DEPOIS DO DIÁLOGO o chute acontece.
	var chance: float = cryo_shot_chance
	var anim: StringName = &"cryo_shot"
	var fx: KickFX = kick_fx
	var on_kick: Callable = Callable()
	var sacrifice: ChemicalReaction = _find_sacrifice() if _loud_crow_partner != null else null
	var karasu: Player = sacrifice.find_partner(self) if sacrifice != null else null
	_loud_crow_partner = null
	if karasu != null and _aim_hits_partner(aim, karasu, ball):
		var rm: ReactionManager = ReactionManager.get_for(self)
		if rm != null:
			await rm.play(sacrifice, self, karasu)
			if m.match_over:
				return false
			chance = loud_crow_chance
			anim = _loud_crow_anim()
			fx = loud_crow_fx
			next_kick_force_mult *= loud_crow_force_mult
			on_kick = _launch_loud_crow.bind(karasu)

	# qte_success = true direto: Cryo Shot / Loud Crow nunca têm QTE (nem errada, nem o knock_down do erro)
	await kick_ball(ball, aim, kind, true, chance, false, fx, anim, on_kick)
	start_cooldown(CD_CRYO_SHOT, cryo_shot_cooldown)
	return true


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
	list.append({"id": SKILL_GLACIAL, "name": skill_label("Glacial Cut", CD_GLACIAL)})
	if _glacial_ready:
		list.append({"id": SKILL_ULTRASADIST, "name": "Ultrasadist (grátis)"})
	var meta_name: String = "Coldest Metavision (ativa)" if is_metavision_active() \
		else skill_label("Coldest Metavision", CD_METAVISION)
	list.append({"id": SKILL_METAVISION, "name": meta_name})
	if is_metavision_active():
		if _is_on_defense_side():
			list.append({"id": SKILL_FROST_GUARD, "name": skill_label("Frost Guard", CD_FROST_GUARD)})
		else:
			var cryo_name: String = "Loud Crow" if _find_sacrifice() != null else "Cryo Shot"
			list.append({"id": SKILL_CRYO_SHOT, "name": skill_label(cryo_name, CD_CRYO_SHOT)})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_PASS:
			return not is_on_cooldown(CD_PASS) and get_pass_variant() != PassVariant.NONE
		SKILL_GLACIAL:
			return not is_on_cooldown(CD_GLACIAL)
		SKILL_ULTRASADIST:
			return _glacial_ready
		SKILL_METAVISION:
			return not is_metavision_active() and not is_on_cooldown(CD_METAVISION)
		SKILL_FROST_GUARD:
			if not is_metavision_active() or is_on_cooldown(CD_FROST_GUARD) or not _is_on_defense_side():
				return false
			var ball: Ball = _get_ball()
			return ball != null and ball.get_level() == Heights.Level.SUSPENDED \
				and global_position.distance_to(ball.global_position) <= frost_guard_reach
		SKILL_CRYO_SHOT:
			if not is_metavision_active() or is_on_cooldown(CD_CRYO_SHOT) or _is_on_defense_side():
				return false
			var ball: Ball = _get_ball()
			var kind: KickType = get_kick_type(ball) if ball != null else KickType.NONE
			return kind == KickType.GROUND or kind == KickType.VOLLEY or kind == KickType.HIGH_BALL
	return false


## Ultrasadist é o complemento GRATUITO do Glacial Cut (ver player.gd: skill_is_free /
## has_free_followup, mesmo padrão do Draconic Header do Shidou)
func skill_is_free(skill_id: StringName) -> bool:
	return skill_id == SKILL_ULTRASADIST


func has_free_followup() -> bool:
	return _glacial_ready


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_PASS:
			return await _use_pass_skill()
		SKILL_GLACIAL:
			return await _use_glacial_cut()
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
			match get_pass_variant():
				PassVariant.CHILLING:
					title = "Chilling Pass"
					text = "Passe alto para um aliado: a bola sobe no meio do caminho e chega nele no ar."
				PassVariant.NO_LOOK:
					title = "No Look Cross"
					text = "O mesmo passe alto, mas com muito mais alcance."
				_:
					title = "Chilling Pass / No Look Cross"
					text = "Passe alto para um aliado. Com o Hiori no ar, ele chega bem mais longe."
			text += "\nRecarga: %d rodadas." % pass_cooldown
		SKILL_GLACIAL:
			title = "Glacial Cut"
			text = "Corrida curta e rápida. Se alcançar a bola, libera o Ultrasadist de graça.\nRecarga: %d rodadas." % glacial_cooldown
		SKILL_ULTRASADIST:
			title = "Ultrasadist"
			text = "Complemento grátis do Glacial Cut: passe alto para o local do campo que você escolher. A bola chega na mesma rodada."
		SKILL_METAVISION:
			title = "Coldest Metavision (ativa)" if is_metavision_active() else "Coldest Metavision"
			text = ("Por %d rodadas: +%.1f s no próximo Correr e +%d%% de chance de gol nos chutes do Hiori e nos chutes depois de um passe dele. Libera uma habilidade nova, conforme o lado do campo.\n"
				+ "Recarga: %d rodadas.") % [
				metavision_rounds, metavision_run_bonus, _pct(metavision_self_shot_bonus), metavision_cooldown]
		SKILL_FROST_GUARD:
			title = "Frost Guard"
			text = "Salta até a bola no ar e a rebate para a direção contrária.\nRecarga: %d rodadas." % frost_guard_cooldown
		SKILL_CRYO_SHOT:
			var star: ChemicalReaction = _find_sacrifice()
			if star != null:
				title = "Loud Crow"
				text = "Reação Química Sacrifice com o Karasu: MIRE NO KARASU e o chute sai mais forte, com %d%% de chance de gol, e a bola passa por cima dele e dos inimigos. Mirando para outro lado, sai o Cryo Shot (%d%%).\nA reação recarrega em %d rodadas. Recarga: %d rodadas." % [
					_pct(loud_crow_chance), _pct(cryo_shot_chance), star.cooldown_rounds, cryo_shot_cooldown]
			else:
				title = "Cryo Shot"
				text = "Chute comum, sem QTE. %d%% de chance de gol.\nRecarga: %d rodadas." % [
					_pct(cryo_shot_chance), cryo_shot_cooldown]
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()
	_glacial_ready = false
	_metavision_until_round = -1
	_assist_target = null
	_coldest_run_bonus_pending = false
	last_ultrasadist = {}
	_aiming_loud_crow = false
	_loud_crow_partner = null
	queue_redraw()


# ---------- VISUAL ----------

func _draw() -> void:
	super()
	var center := Vector2(0.0, -height)

	# Auréola gelada enquanto a Coldest Metavision está ativa
	if is_metavision_active():
		var aura_color := Color(0.6, 0.9, 1.0, 0.9)
		draw_circle(center, placeholder_radius + 8.0, Color(aura_color, 0.12))
		draw_arc(center, placeholder_radius + 8.0, 0.0, TAU, 28, aura_color, 2.0)

	# Anel branco-gelo enquanto o Ultrasadist está esperando ser usado
	if _glacial_ready:
		draw_arc(center, placeholder_radius + 14.0, 0.0, TAU, 20, Color(0.9, 0.98, 1.0, 0.95), 2.0)

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
