class_name Charles
extends Player
## Charles. Habilidades (efeitos de fogo, minas e carrossel em charles_fx.gd):
##
## 0. Mischievous Genius (passiva, Pontos de Malícia = PM, máximo 4). Ele ganha 1 PM quando faz um passe de habilidade
##      que chega ao aliado escolhido, quando gera ou faz um gol, a cada 2 desvios e ao ativar uma armadilha com
##      sucesso. Ao usar uma habilidade ele ESCOLHE quantos PM gastar nela:
##      - cada 1 PM: passes de habilidade ganham +25 de alcance e +1% de bônus, chutes ganham +2% e o Playful Trap
##        ganha mais uma armadilha;
##      - com 4 PM aparece a habilidade "Mischievous Genius": ele assusta os inimigos até 300 de distância, todos
##        ficam Confusos (habilidades embaralhadas e ocultas "???") por 2 rodadas ou até gastarem uma habilidade.
##      Os PM aparecem como diabinhos amarelos ao lado dele. A quantidade a gastar é escolhida numa barrinha que muda
##      com o SCROLL do mouse (clique confirma, Esc cancela). Quem foi afetado por uma bomba (vermelho) e o aliado
##      marcado por um passe (azul) ganham a marca de diabinho flutuando em cima.
##
## 1. Rabona Cross / Sky-Arc Pass (recarga 2, compartilhada)
##      - Charles e bola no chão -> Rabona Cross: cruzamento curvo (alcance 500) para um PONTO do campo; a bola sobe a
##        Voando e chega Suspensa no local NA MESMA RODADA. QTE fácil. Cada PM gasto deixa a trajetória mais confusa
##        (mas ela sempre chega ao alvo).
##      - Bola Suspensa e Charles no chão/suspenso -> Sky-Arc Pass: cruzamento curvo (alcance 525) para um aliado; se
##        passar pelo QTE fácil, o aliado ganha +5% no chute. Gastando 2 PM, o QTE deixa de ser necessário.
##
## 2. Gremlin Détours / Gremlin Shot / Tricheur's Metavision (recarga 2, compartilhada)
##      - Charles e bola no chão e próxima -> Gremlin Détours: domina a bola e faz dois avanços curtos (120). No fim
##        tenta segurá-la para o turno inimigo (QTE difícil). Se um inimigo tentar interagir com a bola, Charles
##        desvia para longe com ela (até 3 vezes) e solta um balão de fala ("ez", "easy", "too slow", "zzz..").
##      - Charles e bola Suspensos -> Gremlin Shot: voleio (QTE fácil), força 1.2x e 40% de chance.
##      - Sem a bola próxima -> Tricheur's Metavision: cria um carrossel (alcance 150) em volta dele, +1 ação de
##        habilidade para os Secundários (se o Charles for o Protagonista) e nenhum QTE nos chutes do Charles. Dentro
##        do carrossel, chutes inimigos perdem 5% e, se vierem Suspensos, há 50% de chance de Charles saltar nele e
##        dar um deflect (0.4x).
##
## 3. Playful Trap / Wrong Answer (recarga 3, compartilhada)
##      - Sem a bola próxima -> Playful Trap: o Charles ESCOLHE onde ficam 3 minas "ocultas" num raio de 500 (cada uma
##        pede um QTE fácil; errou, ela fica apagada). Só valem com o Charles dentro desse alcance e só agem em inimigos. No máximo 6 em
##        campo (a mais antiga quebra). Inimigo a menos de 100 de uma mina: ela explode, atordoa (sem habilidades e
##        sem ações gerais por UM turno: o do time dele) e aplica um efeito: Glissant (46%, derruba e puxa os inimigos por perto),
##        Surprise (46%, medo/confusão por 2 rodadas) ou C'est Mon Tour (8%, ele perde o turno para o time do Charles).
##      - Bola no chão/suspensa e próxima -> Wrong Answer: escolhe dois aliados (alcance 400); a bola vai para um dos
##        dois ao acaso e chega Suspensa. Se um inimigo estiver no caminho, 40% de chance da bola fazer uma curva estranha.
##
## Reação Química CRUEL (com o Rin, veja reaction_cruel.gd): o Rabona Cross anota o último uso em last_rabona e, quando
## cumpre as condições da reação, sai brilhando mais e com um demônio gigante amarelo/azul cobrindo o Charles.
##
## Como montar a cena: igual aos outros — Nova Cena Herdada de player.tscn -> anexe este script ao nó raiz ->
## renomeie o nó raiz para "Charles".

const SKILL_PASS: StringName = &"rabona_cross"
const SKILL_DETOURS: StringName = &"gremlin_detours"     # também Gremlin Shot e Tricheur's Metavision
const SKILL_TRAP: StringName = &"playful_trap"           # também Wrong Answer
const SKILL_GENIUS: StringName = &"mischievous_genius"   # só com PM cheio

const CD_PASS: StringName = &"cd_pass"
const CD_DETOURS: StringName = &"cd_detours"
const CD_TRAP: StringName = &"cd_trap"

enum PassVariant { NONE, RABONA, SKY_ARC }
enum DetourVariant { NONE, DETOURS, SHOT, METAVISION }
enum TrapVariant { NONE, TRAP, WRONG_ANSWER }
enum TrapEffect { GLISSANT, SURPRISE, MON_TOUR }

@export_group("Mischievous Genius (PM)")
@export var pm_max: int = 4
@export var pm_range_bonus: float = 25.0                # +alcance dos passes por PM gasto
@export_range(0.0, 0.1) var pm_assist_bonus: float = 0.01   # +bônus do aliado que recebe, por PM gasto
@export_range(0.0, 0.1) var pm_shot_bonus: float = 0.02     # +chance dos chutes, por PM gasto
@export var deflects_per_pm: int = 2                    # a cada quantos desvios ele ganha 1 PM
@export var genius_range: float = 300.0                 # alcance do susto (4 PM)
@export var genius_rounds: int = 2                      # rodadas de Confuso

@export_group("Rabona Cross / Sky-Arc Pass")
@export var rabona_range: float = 500.0
@export var sky_arc_range: float = 525.0
@export_range(0.0, 1.0) var sky_arc_curve_ratio: float = 0.22
@export var sky_arc_bend: float = 1.0
@export_range(0.0, 0.2) var sky_arc_bonus: float = 0.05     # bônus do aliado se passar pelo QTE
@export var sky_arc_free_qte_pm: int = 2                    # PM gastos para dispensar o QTE
@export var rabona_wobble: float = 45.0                     # quanto cada PM bagunça a trajetória (px)
@export_range(0.0, 1.0) var rabona_qte_fail_range_mult: float = 0.5
@export_range(0.0, 90.0) var rabona_qte_fail_angle: float = 35.0
@export var pass_cooldown: int = 2

@export_group("Gremlin Détours / Shot")
@export var detours_dash_distance: float = 120.0
@export var detours_dash_time: float = 0.3
@export var detours_dodges: int = 3                     # desvios com a bola segurada
@export var taunt_grab_time: float = 0.15
@export var taunt_ball_offset: float = 2.0
@export var taunt_trigger_radius: float = 75.0
@export var taunt_dodge_distance: float = 200.0
@export var taunt_dodge_time: float = 0.25
@export_range(0.0, 1.0) var gremlin_shot_chance: float = 0.40
@export var gremlin_shot_force_mult: float = 1.2
@export var detours_cooldown: int = 2

@export_group("Tricheur's Metavision")
@export var metavision_rounds: int = 3                  # rodadas depois da atual
@export var metavision_range: float = 110.0             # tamanho do carrossel
@export_range(0.0, 1.0) var metavision_enemy_shot_penalty: float = 0.05
@export_range(0.0, 1.0) var metavision_deflect_chance: float = 0.5
@export var metavision_deflect_mult: float = 0.4
@export var metavision_extra_ally_skills: int = 1

@export_group("Playful Trap / Wrong Answer")
@export var trap_range: float = 500.0
@export var trap_count: int = 3
@export var trap_max: int = 6
@export var trap_trigger_radius: float = 100.0
@export_range(0.0, 1.0) var glissant_weight: float = 0.46
@export_range(0.0, 1.0) var surprise_weight: float = 0.46   # o resto (8%) é o C'est Mon Tour
@export var glissant_slide: float = 150.0
@export var glissant_pull_radius: float = 220.0
@export var wrong_answer_range: float = 400.0
@export_range(0.0, 1.0) var wrong_answer_detour_chance: float = 0.4
@export var wrong_answer_path_width: float = 60.0
@export var trap_cooldown: int = 3

@export_group("Visual")
## Fogo amarelo com faíscas azuis nos chutes/passes. Vazio = padrão (CharlesFX.kick_fx)
@export var kick_fx: KickFX
## Aura do Rabona Cross quando ele cumpre as condições da reação Cruel. Vazio = padrão
@export var charged_fx: KickFX
@export var show_pm_marks: bool = true
## Onde ficam os diabinhos de PM: x = distância da borda do Charles, do lado do gol que o time dele ataca (vira de lado
## sozinho no 2º tempo); y = altura (positivo = mais para baixo). O tamanho é o raio de cada diabinho.
@export var pm_marks_offset: Vector2 = Vector2(12.0, 17.0)
@export var pm_marks_size: float = 4.5

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: rabona_cross, gremlin_detours, playful_trap, mischievous_genius.
@export var skill_icons: Dictionary = {}

## Pontos de Malícia
var pm: int = 0
var _deflect_count: int = 0
## Aliado que recebeu um passe dele e o bônus que ele leva no próximo chute (some no fim do turno do Charles)
var _assist_target: Player = null
var _assist_bonus: float = 0.0
## Inimigos atordoados / marcados pelas bombas: a trava e a marca caem no fim do turno do time deles (1 turno só)
var _stunned: Array[Player] = []
var _pm_side: float = 0.0   # lado em que os diabinhos de PM estão desenhados
var _marked: Array[Player] = []

## Gremlin Détours: segurando a bola? (a bola fica colada nele e travada para os adversários)
var _holding: bool = false
var _hold_touches: int = 0
var _dodging: bool = false
var _dodges_left: int = 0

var _metavision_until_round: int = -1
var _meta_busy: bool = false
var _meta_checked: int = -1

## Playful Trap: cada mina é {"pos": Vector2, "active": bool, "node": CharlesFX.Mine}
var _traps: Array[Dictionary] = []

var _carousel: CharlesFX.Carousel

## Último Rabona Cross usado (a reação Cruel lê isto): {"landing": local escolhido, "touches": toques depois}
var last_rabona: Dictionary = {}


func _init() -> void:
	character_id = "charles"
	display_name = "Charles"


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = CharlesFX.kick_fx()
	if charged_fx == null:
		charged_fx = CharlesFX.charged_fx()
	_carousel = CharlesFX.make_carousel(metavision_range)
	add_child(_carousel)
	# A Metavision reduz a chance de chute dos INIMIGOS por perto (ver get_opponent_shot_penalty no player.gd)
	add_to_group("control_sources")
	_hook_manager.call_deferred()


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m:
		m.turn_ended.connect(_on_turn_ended)
		m.goal_scored.connect(_on_goal_scored)
	var ball: Ball = _get_ball()
	if ball:
		ball.was_reset.connect(_on_ball_reset)


func _on_ball_reset() -> void:
	_end_hold(false)   # gol / reposição: a bola já foi solta pelo próprio Ball


## Fim de turno: o bônus de assistência acaba no fim do turno do Charles e a bola segurada solta no do adversário
func _on_turn_ended(ended_team: int) -> void:
	if ended_team == team:
		_set_assist(null, 0.0)
	elif _holding and not _dodging:
		_end_hold(true)
	# O atordoamento e a marca das bombas duram UM turno: acabam no fim do turno do time de quem foi afetado
	for p in _stunned.duplicate():
		if not is_instance_valid(p) or p.team == ended_team:
			if is_instance_valid(p):
				p.clear_lock()
			_stunned.erase(p)
	for p in _marked.duplicate():
		if not is_instance_valid(p) or p.team == ended_team:
			CharlesFX.unmark(p)
			_marked.erase(p)


## Aliado que ganha o bônus do passe do Charles (até o fim do turno dele): ele também ganha a marca de diabinho (azul)
func _set_assist(target: Player, bonus: float) -> void:
	if _assist_target != null and _assist_target != target:
		CharlesFX.unmark(_assist_target)
	_assist_target = target
	_assist_bonus = bonus
	if target != null:
		CharlesFX.mark(target, CharlesFX.BLUE_DEEP)


## Gols: ele ganha PM quando faz ou quando assiste (comparando pelo nome mostrado no placar)
func _on_goal_scored(goal: Dictionary) -> void:
	if int(goal.get("team", -1)) != team or bool(goal.get("own_goal", false)):
		return
	var who: String = get_display_name()
	if String(goal.get("scorer", "")) == who:
		gain_pm(1)
	if String(goal.get("assist", "")) == who:
		gain_pm(1)


func knock_down() -> void:
	super()
	_end_hold(true)   # derrubado: a bola solta
	queue_redraw()


# ---------- PM (Mischievous Genius) ----------

func gain_pm(amount: int = 1) -> void:
	var before: int = pm
	pm = clampi(pm + amount, 0, pm_max)
	if pm > before:
		CharlesFX.flame(self, global_position + Vector2(24.0, -height - 10.0), 6)
	queue_redraw()


## Conta um desvio (o do Détours ou o deflect da Metavision): a cada deflects_per_pm desvios, +1 PM
func _count_deflect() -> void:
	_deflect_count += 1
	if _deflect_count >= maxi(deflects_per_pm, 1):
		_deflect_count = 0
		gain_pm(1)


## Pergunta quantos PM gastar (0 até "limit"). -1 = cancelou (a habilidade não é usada).
## Sem PM (ou limit 0) não pergunta nada e devolve 0. Os PM só são gastos quando a habilidade realmente sai.
func _ask_pm(title: String, hint: String, limit: int) -> int:
	var max_spend: int = mini(pm, limit)
	if max_spend <= 0:
		return 0
	var m: MatchManager = _get_manager()
	if m == null:
		return 0
	var picker := PmPicker.new()
	m.add_child(picker)
	picker.setup(title, hint, pm, max_spend)
	var amount: int = await picker.chosen
	picker.queue_free()
	return amount


func _spend_pm(amount: int) -> void:
	pm = maxi(pm - amount, 0)
	queue_redraw()


func _pm_text(per_pm: String) -> String:
	return "Cada PM gasto: %s" % per_pm


# ---------- HABILIDADE 1: RABONA CROSS / SKY-ARC PASS ----------

func _ball_near() -> bool:
	var ball: Ball = _get_ball()
	return ball != null and not ball.is_held() and not ball.is_locked_for(team) \
		and global_position.distance_to(ball.global_position) <= kick_range


func get_pass_variant() -> PassVariant:
	if is_down or not _ball_near():
		return PassVariant.NONE
	var ball_level: Heights.Level = _get_ball().get_level()
	if height_level == Heights.Level.GROUND and ball_level == Heights.Level.GROUND:
		return PassVariant.RABONA
	if (height_level == Heights.Level.GROUND or height_level == Heights.Level.SUSPENDED) \
			and ball_level == Heights.Level.SUSPENDED:
		return PassVariant.SKY_ARC
	return PassVariant.NONE


func _pass_skill_name() -> String:
	return "Sky-Arc Pass" if get_pass_variant() == PassVariant.SKY_ARC else "Rabona Cross"


func _use_pass_skill() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	match get_pass_variant():
		PassVariant.RABONA:
			return await _use_rabona_cross(m)
		PassVariant.SKY_ARC:
			return await _use_sky_arc_pass(m)
	return false


## Rabona Cross: o jogador CLICA no local do campo (dentro do alcance) para onde a bola vai. Ela sobe a Voando no
## meio do caminho e desce Suspensa no local NA MESMA RODADA. Cada PM gasto bagunça a trajetória (mais pontos de
## desvio no ar), mas ela sempre chega ao alvo.
func _use_rabona_cross(m: MatchManager) -> bool:
	var ball: Ball = _get_ball()
	var spend: int = await _ask_pm("Rabona Cross", _pm_text("+%d de alcance e a trajetória fica mais confusa" % int(pm_range_bonus)), pm_max)
	if spend < 0:
		return false   # cancelou
	var range_px: float = rabona_range + pm_range_bonus * float(spend)

	var landing: Vector2 = await m.pick_point_for_skill(self, range_px)
	if landing == Vector2.INF:
		return false   # cancelou: não gasta a ação
	if get_pass_variant() != PassVariant.RABONA:
		return false   # a bola rolou enquanto ele escolhia o local

	var dir: Vector2 = landing - global_position
	dir = dir.normalized() if dir.length() > 0.01 else Vector2(_default_facing(), 0.0)
	face_towards(dir)

	# Cruel (Charles + Rin): se este Rabona cumpre as condições da reação, um demônio gigante cobre o Charles
	var charged: bool = ReactionCruel.is_rabona_charged(self)
	last_rabona = {}
	if charged:
		CruelFX.summon_charles_demon(self, global_position, height)

	if not await play_action(&"rabona_cross", ANIM_PASS_HIGH):
		return false   # ação cancelada (ex: a partida reiniciou)
	_spend_pm(spend)

	var qte_ok: bool = true
	if not skips_qte():
		qte_ok = await m.run_qte(KickType.VOLLEY)   # QTE fácil
	if not qte_ok:
		# Errou: o local sai mais perto do que o clicado e um pouco torto
		var bad_dir: Vector2 = dir.rotated(deg_to_rad(randf_range(-rabona_qte_fail_angle, rabona_qte_fail_angle)))
		landing = global_position + bad_dir * global_position.distance_to(landing) * rabona_qte_fail_range_mult

	ball.register_touch(self)   # o passe alto não usa kick(), então registra o toque aqui
	if charged:
		ball.play_fx(charged_fx)
		CruelFX.attach_ball_aura(ball, CruelFX.Style.RABONA)
		CruelFX.rabona_burst(self, ball.sprite.global_position)
	elif kick_fx:
		ball.play_fx(kick_fx)
	CharlesFX.flame(self, ball.sprite.global_position, 16)
	CharlesFX.trail(ball, 1.1)

	await _fly_ball(ball, landing, spend, 0.9)
	m.register_skill_pass(team, null)

	last_rabona = {"landing": landing, "touches": ball.interaction_count}
	start_cooldown(CD_PASS, pass_cooldown)
	return true


## A bola sobe a Voando e vai até o ponto "landing", desce Suspensa nele. Com wobble_steps > 0, passa por pontos
## de desvio aleatórios no ar (trajetória confusa), mas SEMPRE termina em landing.
func _fly_ball(ball: Ball, landing: Vector2, wobble_steps: int, total_time: float) -> void:
	var m: MatchManager = _get_manager()
	var from: Vector2 = ball.global_position
	if wobble_steps <= 0:
		await ball.hover_to((from + landing) * 0.5, Heights.FLYING_HEIGHT, total_time).finished
	else:
		var legs: int = wobble_steps + 1
		var side: Vector2 = (landing - from).normalized().orthogonal()
		for i in range(1, legs + 1):
			var t: float = float(i) / float(legs)
			var wobble: Vector2 = side * randf_range(-1.0, 1.0) * rabona_wobble * float(wobble_steps) * sin(PI * t)
			var p: Vector2 = from.lerp(landing, t * 0.9) + wobble
			await ball.hover_to(p, Heights.FLYING_HEIGHT, total_time / float(legs)).finished
	# Chega NA MESMA RODADA, Suspensa, e fica pairando até alguém tocar ou o turno acabar
	await ball.hover_to(landing, Heights.SUSPENDED_HEIGHT, m.high_pass_arrive_time).finished


## Sky-Arc Pass: cruzamento curvo para um aliado (a bola chega a ele NO CHÃO). Passou pelo QTE fácil: o aliado ganha
## +5% no chute. Com 2 PM gastos não precisa de QTE (e o bônus vale igual).
func _use_sky_arc_pass(m: MatchManager) -> bool:
	var ball: Ball = _get_ball()
	var spend: int = await _ask_pm("Sky-Arc Pass",
		_pm_text("+%d de alcance e +%d%% no bônus. Com %d PM, sem QTE" % [int(pm_range_bonus), int(round(pm_assist_bonus * 100.0)), sky_arc_free_qte_pm]), pm_max)
	if spend < 0:
		return false
	var target: Player = await m.pick_ally_for_skill(self, sky_arc_range + pm_range_bonus * float(spend))
	if target == null:
		return false   # cancelou: não gasta a ação
	if get_pass_variant() != PassVariant.SKY_ARC:
		return false
	_spend_pm(spend)

	var qte_ok: bool = true
	if spend < sky_arc_free_qte_pm and not skips_qte():
		qte_ok = await m.run_qte(KickType.VOLLEY)   # QTE fácil
	if qte_ok:
		_set_assist(target, sky_arc_bonus + pm_assist_bonus * float(spend))

	CharlesFX.flame(self, ball.sprite.global_position, 14)
	CharlesFX.trail(ball, 1.2)
	await m.run_curved_ground_pass(self, target, ball, sky_arc_curve_ratio, sky_arc_bend, &"sky_arc_pass", kick_fx)
	gain_pm(1)   # o passe de habilidade chegou ao aliado escolhido
	start_cooldown(CD_PASS, pass_cooldown)
	return true


## Bônus de chute que o Charles dá a quem recebeu o Sky-Arc / Wrong Answer dele (até o fim do turno dele)
func shot_bonus_for_ally(shooter: Player, _ball: Ball) -> float:
	if shooter == _assist_target:
		return _assist_bonus
	return 0.0


# ---------- HABILIDADE 2: GREMLIN DÉTOURS / GREMLIN SHOT / TRICHEUR'S METAVISION ----------

func get_detour_variant() -> DetourVariant:
	if is_down:
		return DetourVariant.NONE
	var ball: Ball = _get_ball()
	if ball == null:
		return DetourVariant.NONE
	if not _ball_near():
		return DetourVariant.METAVISION
	var ball_level: Heights.Level = ball.get_level()
	if height_level == Heights.Level.GROUND and ball_level == Heights.Level.GROUND:
		return DetourVariant.DETOURS
	if height_level == Heights.Level.SUSPENDED and ball_level == Heights.Level.SUSPENDED:
		return DetourVariant.SHOT
	return DetourVariant.NONE


func _detour_skill_name() -> String:
	if _holding:
		return "Gremlin Détours (segurando)"
	match get_detour_variant():
		DetourVariant.SHOT:
			return "Gremlin Shot"
		DetourVariant.METAVISION:
			return "Tricheur's Metavision (ativa)" if is_metavision_active() else "Tricheur's Metavision"
	return "Gremlin Détours"


func _use_detour_skill() -> bool:
	match get_detour_variant():
		DetourVariant.DETOURS:
			return await _use_detours()
		DetourVariant.SHOT:
			return await _use_gremlin_shot()
		DetourVariant.METAVISION:
			return await _use_metavision()
	return false


## Gremlin Détours: domina a bola e faz dois avanços curtos (cada um numa direção que você mira). No fim, QTE
## DIFÍCIL para segurar a bola durante o turno inimigo; se errar, a bola fica no chão onde está.
func _use_detours() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null or get_detour_variant() != DetourVariant.DETOURS:
		return false

	var dir1: Vector2 = await m.aim_for_skill(self, detours_dash_distance)
	if dir1 == Vector2.ZERO:
		return false   # cancelou: não gasta a ação
	if get_detour_variant() != DetourVariant.DETOURS:
		return false
	face_towards(dir1)
	if not await play_action(&"gremlin_detours"):
		return false
	ball = _get_ball()
	if ball == null or get_detour_variant() != DetourVariant.DETOURS:
		return false

	# Domina a bola (ela fica colada nos pés e travada para os adversários)
	_end_hold(false)
	m.clear_pending_pass()
	ball.register_touch(self)
	ball.hover_to(_hold_point(ball), 0.0, taunt_grab_time)
	await get_tree().create_timer(taunt_grab_time + 0.02).timeout
	ball = _get_ball()
	if ball == null or m.match_over:
		return false
	ball.velocity = Vector2.ZERO
	ball.vel_z = 0.0
	ball.height = 0.0
	ball.spell_owner = self
	_hold_touches = ball.interaction_count
	_holding = true
	_dodging = false
	_dodges_left = detours_dodges
	CharlesFX.flame(self, ball.sprite.global_position, 10)

	# Dois avanços com a bola
	await _dash(dir1)
	var dir2: Vector2 = await m.aim_for_skill(self, detours_dash_distance)
	if dir2 == Vector2.ZERO:
		dir2 = dir1   # cancelou o segundo: repete a direção, a ação já foi gasta
	await _dash(dir2)

	# Segurar a bola para o turno inimigo: QTE difícil
	var hold_ok: bool = true
	if not skips_qte():
		hold_ok = await m.run_qte(KickType.FLYING)
	if not hold_ok:
		_end_hold(true)
	start_cooldown(CD_DETOURS, detours_cooldown)
	queue_redraw()
	return true


## Um avanço curto: Charles anda a distância na direção dada, com a bola grudada (o _update_hold a mantém colada)
func _dash(dir: Vector2) -> void:
	var start: Vector2 = global_position
	var dest: Vector2 = _clamp_to_pitch(start + dir.normalized() * detours_dash_distance)
	face_towards(dir)
	var t: float = 0.0
	while t < 1.0:
		await get_tree().physics_frame
		t = minf(t + get_physics_process_delta_time() / maxf(detours_dash_time, 0.05), 1.0)
		global_position = start.lerp(dest, smoothstep(0.0, 1.0, t))
		if t < 1.0 and randf() < 0.3:
			CharlesFX.flame(self, global_position + Vector2(0.0, -height), 3)


## Gremlin Shot: voleio (Charles e bola Suspensos), QTE fácil, 1.2x a força e 40% de chance (+2% por PM)
func _use_gremlin_shot() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false
	var spend: int = await _ask_pm("Gremlin Shot", _pm_text("+%d%% de chance" % int(round(pm_shot_bonus * 100.0))), pm_max)
	if spend < 0:
		return false
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false
	if get_detour_variant() != DetourVariant.SHOT:
		return false
	_spend_pm(spend)

	var qte_ok: bool = true
	if not skips_qte():
		qte_ok = await m.run_qte(KickType.VOLLEY)   # QTE fácil
	next_kick_force_mult *= gremlin_shot_force_mult
	CharlesFX.flame(self, ball.sprite.global_position, 14, true)
	CharlesFX.trail(ball, 1.0)
	await kick_ball(ball, aim, KickType.VOLLEY, qte_ok, gremlin_shot_chance + pm_shot_bonus * float(spend), false,
		kick_fx if qte_ok else null, &"gremlin_shot")
	start_cooldown(CD_DETOURS, detours_cooldown)
	return true


## O Carrinho de um adversário contra o Charles (com a bola segurada) conta como tentar interagir: ele desvia
func try_counter_slide(attacker: Player) -> bool:
	if not _holding or _dodging or is_down or attacker.team == team:
		return false
	attacker._slide_hit_ball = true   # o resto do carrinho dele não tenta chutar a bola de novo
	_hold_dodge(attacker.global_position)
	return true


## Posição da bola segurada: nos pés do Charles, do lado para onde ele está virado
func _hold_point(ball: Ball) -> Vector2:
	return global_position + Vector2(facing, 0.0) * (body_radius + ball.collision_radius + taunt_ball_offset)


## Mantém a bola colada e, no turno do adversário, vigia quem chega perto. Se alguém tocou/soltou a bola, acabou.
func _update_hold() -> void:
	if not _holding:
		return
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null or m.match_over:
		_end_hold(false)
		return
	if ball.spell_owner != self or not ball.hovering or ball.is_held() or ball.interaction_count != _hold_touches:
		_end_hold(false)
		return
	if is_down:
		_end_hold(true)
		return
	ball.global_position = _hold_point(ball)
	ball.height = 0.0
	if not _dodging:
		_check_hold_trigger(ball)


func _check_hold_trigger(ball: Ball) -> void:
	var m: MatchManager = _get_manager()
	if m == null or m.current_team == team:
		return   # só o turno do adversário conta
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p.team == team or p.is_down or not p.can_reach_level(ball.get_level()):
			continue
		var radius: float = maxf(taunt_trigger_radius, p.kick_range + 5.0)
		if p.global_position.distance_to(ball.global_position) <= radius:
			_hold_dodge(p.global_position)
			return


## Alguém tentou pegar a bola: Charles salta, desvia COM ela para longe e solta um balão de fala. Conta como desvio.
## Depois de detours_dodges desvios, ele perde a bola.
func _hold_dodge(from: Vector2) -> void:
	_dodging = true
	_dodges_left -= 1
	hop_over()
	CharlesFX.speech(self, String(["ez", "easy", "too slow", "zzz.."].pick_random()))
	_count_deflect()

	var away: Vector2 = global_position - from
	if away.length() < 1.0:
		away = Vector2(-facing, 0.0)
	var dest: Vector2 = _clamp_to_pitch(global_position + away.normalized() * taunt_dodge_distance)
	face_towards(-away)
	CharlesFX.flame(self, global_position + Vector2(0.0, -height), 8)
	var tw := create_tween()
	tw.tween_property(self, "global_position", dest, taunt_dodge_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(taunt_dodge_time).timeout
	_dodging = false
	if _dodges_left <= 0:
		_end_hold(true)   # acabaram os desvios: a bola solta
	queue_redraw()


## release = true solta a bola (cai e rola); false = ela já foi tocada/solta por outro meio
func _end_hold(release: bool) -> void:
	if not _holding:
		return
	_holding = false
	_dodging = false
	var ball: Ball = _get_ball()
	if release and ball != null and ball.spell_owner == self:
		ball.release_hover()   # volta a gravidade e a trava some
	queue_redraw()


func _get_field() -> Field:
	return get_tree().get_first_node_in_group("field") as Field


## Mantém uma posição (global) dentro do campo
func _clamp_to_pitch(global_p: Vector2) -> Vector2:
	var field: Field = _get_field()
	if field == null:
		return global_p
	var half: Vector2 = field.pitch_size * 0.5 - Vector2(20.0, 20.0)
	var l: Vector2 = field.to_local(global_p)
	l.x = clampf(l.x, -half.x, half.x)
	l.y = clampf(l.y, -half.y, half.y)
	return field.to_global(l)


# ---------- TRICHEUR'S METAVISION (o carrossel) ----------

func is_metavision_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _metavision_until_round >= 0 and m.round_number <= _metavision_until_round


## Nenhum QTE nos chutes do Charles enquanto a Metavision estiver ativa
func skips_qte() -> bool:
	return is_metavision_active()


## Chamado pelo kick_ball() de quem chuta (ver get_opponent_shot_penalty() no player.gd): só vale para chutes de
## ADVERSÁRIOS dados de dentro do carrossel, com a Metavision ativa.
func shot_penalty_on(shooter: Player) -> float:
	if not is_metavision_active() or shooter.team == team:
		return 0.0
	if global_position.distance_to(shooter.global_position) > metavision_range:
		return 0.0
	return metavision_enemy_shot_penalty


func _use_metavision() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	await play_action(&"tricheur_metavision")
	_metavision_until_round = m.round_number + metavision_rounds
	start_cooldown(CD_DETOURS, detours_cooldown)
	if m.protagonist == self:   # +1 ação de habilidade para os Secundários (só se ele for o Protagonista)
		m.secondary_skill_left += metavision_extra_ally_skills
	CharlesFX.scare(self, global_position, metavision_range)
	queue_redraw()
	return true


## Turno inimigo: chute Suspenso entrando no carrossel -> 50% de chance de Charles saltar nele e dar um deflect
func _scan_metavision_shot() -> void:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null or _meta_busy or is_down or m.current_team == team:
		return
	if not ball.has_pending_shot() or ball.shot_team == team or ball.is_held():
		return
	if ball.get_level() != Heights.Level.SUSPENDED \
			or ball.global_position.distance_to(global_position) > metavision_range:
		return
	if ball.interaction_count == _meta_checked:
		return   # este chute já foi sorteado
	_meta_checked = ball.interaction_count
	if randf() > metavision_deflect_chance:
		return
	_meta_busy = true
	await _jump_deflect(ball)
	_meta_busy = false


## Charles salta até a bola (parada no ar) e dá um deflect para um dos lados
func _jump_deflect(ball: Ball) -> void:
	var was_ground: bool = height_level == Heights.Level.GROUND
	var speed: float = ball.velocity.length()
	var dir: Vector2 = ball.velocity.normalized() if speed > 1.0 else Vector2(get_attack_dir(), 0.0)
	ball.pending_shot_chance = Ball.NO_SHOT   # interceptado: o goleiro não decide mais nada
	ball.velocity = Vector2.ZERO
	ball.vel_z = 0.0
	face_towards(ball.global_position - global_position)
	height_level = Heights.Level.SUSPENDED
	var spot: Vector2 = _clamp_to_pitch(ball.global_position - Vector2(facing * (body_radius + ball.collision_radius + 4.0), 0.0))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", spot, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "height", Heights.SUSPENDED_HEIGHT, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	var side: float = 1.0 if randf() < 0.5 else -1.0
	var rise: float = maxf(0.0, Heights.SUSPENDED_HEIGHT - ball.height)
	ball.kick(dir.rotated(PI * 0.5 * side), speed * metavision_deflect_mult,
		Heights.lift_for_peak(rise, ball.gravity), self, Ball.NO_SHOT)
	CharlesFX.flame(self, ball.sprite.global_position, 12, true)
	_count_deflect()
	if was_ground:
		await get_tree().create_timer(0.35).timeout
		land()


# ---------- HABILIDADE 3: PLAYFUL TRAP / WRONG ANSWER ----------

func get_trap_variant() -> TrapVariant:
	if is_down:
		return TrapVariant.NONE
	if not _ball_near():
		return TrapVariant.TRAP
	var ball_level: Heights.Level = _get_ball().get_level()
	if ball_level == Heights.Level.GROUND or ball_level == Heights.Level.SUSPENDED:
		return TrapVariant.WRONG_ANSWER
	return TrapVariant.NONE


func _trap_skill_name() -> String:
	return "Wrong Answer" if get_trap_variant() == TrapVariant.WRONG_ANSWER else "Playful Trap"


func _use_trap_skill() -> bool:
	match get_trap_variant():
		TrapVariant.TRAP:
			return await _use_playful_trap()
		TrapVariant.WRONG_ANSWER:
			return await _use_wrong_answer()
	return false


## Playful Trap: o Charles ESCOLHE onde cada mina fica (clique no campo, dentro do alcance; 3 minas, +1 por PM gasto).
## Uma prévia aparece em cada lugar escolhido. Cada mina pede um QTE fácil; errou, ela fica apagada. No máximo trap_max
## em campo: as mais antigas quebram. Cancelar (Esc / botão direito) em qualquer escolha desiste de tudo.
func _use_playful_trap() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var spend: int = await _ask_pm("Playful Trap", _pm_text("+1 armadilha"), pm_max)
	if spend < 0:
		return false
	var count: int = trap_count + spend
	var spots: Array[Vector2] = []
	var previews: Array[CharlesFX.Mine] = []
	for i in count:
		var spot: Vector2 = await m.pick_point_for_skill(self, trap_range)
		if spot == Vector2.INF:
			break   # cancelou: desiste de tudo
		spot = _clamp_to_pitch(spot)
		spots.append(spot)
		previews.append(CharlesFX.mine(self, spot, true))   # prévia do lugar escolhido
	var complete: bool = spots.size() == count and get_trap_variant() == TrapVariant.TRAP
	for pv in previews:
		if pv != null and is_instance_valid(pv):
			pv.queue_free()
	if not complete or not await play_action(&"playful_trap"):
		return false
	_spend_pm(spend)
	for spot in spots:
		var ok: bool = true
		if not skips_qte():
			ok = await m.run_qte(KickType.VOLLEY)   # QTE fácil para cada armadilha
		_add_trap(spot, ok)
		CharlesFX.flame(self, spot, 6)
	start_cooldown(CD_TRAP, trap_cooldown)
	return true


func _add_trap(pos: Vector2, active: bool) -> void:
	_traps.append({"pos": pos, "active": active, "node": CharlesFX.mine(self, pos, active)})
	while _traps.size() > trap_max:   # a mais antiga quebra
		var oldest: Dictionary = _traps.pop_front()
		var node: CharlesFX.Mine = oldest["node"] as CharlesFX.Mine
		if node != null and is_instance_valid(node):
			node.pop()


## Vigia as minas: só valem com o Charles dentro de trap_range e só agem em inimigos no chão a menos de trap_trigger_radius
func _update_traps() -> void:
	if _traps.is_empty():
		return
	var enemies: Array[Player] = []
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p.team != team and not p.is_down and p.height_level == Heights.Level.GROUND:
			enemies.append(p)
	var triggered: Array[Dictionary] = []
	for t: Dictionary in _traps:
		var pos: Vector2 = t["pos"] as Vector2
		var node: CharlesFX.Mine = t["node"] as CharlesFX.Mine
		var in_range: bool = not is_down and global_position.distance_to(pos) <= trap_range
		if node != null and is_instance_valid(node):
			node.dormant = not in_range
		if not bool(t["active"]) or not in_range:
			continue
		for e in enemies:
			if e.global_position.distance_to(pos) <= trap_trigger_radius:
				triggered.append(t)
				_explode_trap(t, e)
				break
	for t in triggered:
		_traps.erase(t)


## A mina explode: atordoa (sem habilidades e ações gerais) e aplica um dos 3 efeitos. Cada explosão tem uma cor.
func _explode_trap(trap: Dictionary, enemy: Player) -> void:
	var pos: Vector2 = trap["pos"] as Vector2
	var node: CharlesFX.Mine = trap["node"] as CharlesFX.Mine
	if node != null and is_instance_valid(node):
		node.queue_free()
	CharlesFX.boom(self, pos, CharlesFX.next_boom_color())
	gain_pm(1)   # ativou uma armadilha com sucesso

	_stun(enemy)
	var roll: float = randf()
	var effect: TrapEffect = TrapEffect.MON_TOUR
	if roll < glissant_weight:
		effect = TrapEffect.GLISSANT
	elif roll < glissant_weight + surprise_weight:
		effect = TrapEffect.SURPRISE
	match effect:
		TrapEffect.GLISSANT:
			_glissant(enemy, pos)
		TrapEffect.SURPRISE:
			_surprise(enemy)
		TrapEffect.MON_TOUR:
			_mon_tour(enemy)


## Atordoar = sem habilidades e sem ações gerais, por UM turno só: a trava cai no fim do turno do time dele
## (_on_turn_ended). Se a bomba explodiu no turno dele, vale pelo resto desse turno; se foi no do Charles, pelo próximo.
func _stun(p: Player) -> void:
	p.apply_lock(self, 3, false)   # rodadas de sobra: quem solta é o fim do turno
	if not _stunned.has(p):
		_stunned.append(p)
	_mark_victim(p)


## Quem foi afetado por uma bomba ganha a marca de diabinho (contorno vermelho) até o fim do turno do time dele
func _mark_victim(p: Player) -> void:
	CharlesFX.mark(p, CharlesFX.RED_LINE)
	if not _marked.has(p):
		_marked.append(p)


## Glissant: o inimigo escorrega para longe da mina e é derrubado; quem estiver perto dele é puxado junto e derrubado
func _glissant(enemy: Player, from: Vector2) -> void:
	var away: Vector2 = enemy.global_position - from
	if away.length() < 1.0:
		away = Vector2.from_angle(randf() * TAU)
	var dest: Vector2 = _clamp_to_pitch(enemy.global_position + away.normalized() * glissant_slide)
	var victims: Array[Player] = [enemy]
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p != enemy and p.team != team and not p.is_down \
				and p.global_position.distance_to(enemy.global_position) <= glissant_pull_radius:
			victims.append(p)
	var i: int = 0
	for v in victims:
		var spot: Vector2 = _clamp_to_pitch(dest + Vector2.from_angle(float(i) * 2.4) * (30.0 if i > 0 else 0.0))
		var tw := v.create_tween()
		tw.tween_property(v, "global_position", spot, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		v.knock_down()
		_mark_victim(v)   # quem foi puxado também fica marcado
		i += 1


## Surprise: o inimigo fica assustado (Confuso) por 2 rodadas
func _surprise(enemy: Player) -> void:
	var m: MatchManager = _get_manager()
	if m != null:
		enemy.apply_confusion(m.round_number + 1)
	CharlesFX.speech(enemy, "!?")


## C'est Mon Tour: o inimigo perde o turno, que passa para o time do Charles
func _mon_tour(enemy: Player) -> void:
	CharlesFX.speech(enemy, "...")
	_force_end_turn(enemy.team)


## Se for a vez do time do inimigo, encerra o turno dele assim que o jogo voltar a esperar uma ação.
## (Fora da vez dele, o atordoamento já o impede de agir no próximo turno.)
func _force_end_turn(enemy_team: int) -> void:
	var m: MatchManager = _get_manager()
	if m == null or m.current_team != enemy_team:
		return
	var waited: float = 0.0
	while m.phase != MatchManager.Phase.CHOOSING_ACTION and waited < 6.0 and not m.match_over:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	if not m.match_over and m.current_team == enemy_team and m.phase == MatchManager.Phase.CHOOSING_ACTION:
		m.request_end_turn()


## Wrong Answer: escolhe DOIS aliados e a bola vai para um deles ao acaso (chega Suspensa). Se um inimigo estiver no
## caminho, 40% de chance de ela fazer uma curva estranha (mas ainda chega).
func _use_wrong_answer() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false
	var spend: int = await _ask_pm("Wrong Answer",
		_pm_text("+%d de alcance e +%d%% no bônus" % [int(pm_range_bonus), int(round(pm_assist_bonus * 100.0))]), pm_max)
	if spend < 0:
		return false
	var range_px: float = wrong_answer_range + pm_range_bonus * float(spend)
	var first: Player = await m.pick_ally_for_skill(self, range_px)
	if first == null:
		return false
	var second: Player = await m.pick_ally_for_skill(self, range_px, false, func(o: Player) -> bool: return o != first)
	if second == null:
		return false
	if get_trap_variant() != TrapVariant.WRONG_ANSWER:
		return false
	if not await play_action(&"wrong_answer", ANIM_PASS_HIGH):
		return false
	_spend_pm(spend)

	var target: Player = first if randf() < 0.5 else second   # a bola vai para um dos dois ao acaso
	var landing: Vector2 = target.global_position
	ball = _get_ball()
	ball.register_touch(self)
	m.clear_pending_pass()
	CharlesFX.flame(self, ball.sprite.global_position, 14)
	CharlesFX.trail(ball, 1.1)

	var weird: bool = _enemy_on_path(ball.global_position, landing) and randf() < wrong_answer_detour_chance
	await _fly_ball(ball, landing, 3 if weird else 0, 0.9)   # curva estranha = mais desvios no ar
	m.register_skill_pass(team, target)

	_set_assist(target, pm_assist_bonus * float(spend))
	gain_pm(1)   # o passe de habilidade chegou a um dos aliados escolhidos
	start_cooldown(CD_TRAP, trap_cooldown)
	return true


## Tem algum inimigo perto da linha reta entre os dois pontos?
func _enemy_on_path(a: Vector2, b: Vector2) -> bool:
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p.team == team or p.is_down:
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p.global_position, a, b)
		if closest.distance_to(p.global_position) <= wrong_answer_path_width:
			return true
	return false


# ---------- HABILIDADE 4: MISCHIEVOUS GENIUS (4 PM) ----------

## Charles espanta os inimigos num raio de genius_range: todos ficam Confusos (habilidades embaralhadas e ocultas)
## por 2 rodadas ou até gastarem uma habilidade. Gasta TODOS os PM.
func _use_genius() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or pm < pm_max:
		return false
	await play_action(&"mischievous_genius")
	_spend_pm(pm_max)
	CharlesFX.scare(self, global_position, genius_range)
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p.team != team and not p.is_down and p.global_position.distance_to(global_position) <= genius_range:
			p.apply_confusion(m.round_number + genius_rounds - 1)
			CharlesFX.speech(p, "???")
	return true


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"id": SKILL_PASS, "name": skill_label(_pass_skill_name(), CD_PASS)})
	list.append({"id": SKILL_DETOURS, "name": skill_label(_detour_skill_name(), CD_DETOURS)})
	list.append({"id": SKILL_TRAP, "name": skill_label(_trap_skill_name(), CD_TRAP)})
	if pm >= pm_max:
		list.append({"id": SKILL_GENIUS, "name": "Mischievous Genius"})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_PASS:
			return not is_on_cooldown(CD_PASS) and get_pass_variant() != PassVariant.NONE
		SKILL_DETOURS:
			if is_on_cooldown(CD_DETOURS) or _holding:
				return false   # sem reativar enquanto já está segurando a bola
			return get_detour_variant() != DetourVariant.NONE
		SKILL_TRAP:
			return not is_on_cooldown(CD_TRAP) and get_trap_variant() != TrapVariant.NONE
		SKILL_GENIUS:
			return pm >= pm_max
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_PASS:
			return await _use_pass_skill()
		SKILL_DETOURS:
			return await _use_detour_skill()
		SKILL_TRAP:
			return await _use_trap_skill()
		SKILL_GENIUS:
			return await _use_genius()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_PASS:
			if get_pass_variant() == PassVariant.SKY_ARC:
				title = "Sky-Arc Pass"
				text = "Cruzamento curvo (alcance %d) para um aliado. Passando pelo QTE fácil, ele ganha +%d%% no chute. Com %d PM, sem QTE." % [int(sky_arc_range), _pct(sky_arc_bonus), sky_arc_free_qte_pm]
			else:
				title = "Rabona Cross"
				text = "Cruzamento curvo (alcance %d) para um ponto do campo, QTE fácil. A bola sobe e chega Suspensa na mesma rodada. Cada PM deixa a trajetória mais confusa (mas ela sempre chega)." % int(rabona_range)
			text += "\nRecarga: %d rodadas." % pass_cooldown
		SKILL_DETOURS:
			match get_detour_variant():
				DetourVariant.SHOT:
					title = "Gremlin Shot"
					text = "Voleio com QTE fácil, %.1fx de força e %d%% de chance." % [gremlin_shot_force_mult, _pct(gremlin_shot_chance)]
				DetourVariant.METAVISION:
					title = "Tricheur's Metavision"
					text = "Cria um carrossel (alcance %d) em volta dele por %d rodadas: sem QTE nos chutes do Charles, +%d ação de habilidade para os Secundários (se ele for o Protagonista), chutes inimigos dentro perdem %d%% e os Suspensos têm %d%% de chance de levar um deflect dele." % [int(metavision_range), metavision_rounds, metavision_extra_ally_skills, _pct(metavision_enemy_shot_penalty), _pct(metavision_deflect_chance)]
				_:
					title = "Gremlin Détours"
					text = "Domina a bola e faz dois avanços curtos (%d). No fim tenta segurá-la (QTE difícil). Se um inimigo tentar pegar a bola, Charles desvia com ela (até %d vezes)." % [int(detours_dash_distance), detours_dodges]
			text += "\nRecarga: %d rodadas." % detours_cooldown
		SKILL_TRAP:
			if get_trap_variant() == TrapVariant.WRONG_ANSWER:
				title = "Wrong Answer"
				text = "Escolhe dois aliados (alcance %d): a bola vai para um deles ao acaso e chega Suspensa. Se houver inimigo no caminho, %d%% de chance de uma curva estranha." % [int(wrong_answer_range), _pct(wrong_answer_detour_chance)]
			else:
				title = "Playful Trap"
				text = "Você escolhe onde ficam %d minas ocultas num raio de %d (QTE fácil em cada uma, +1 por PM). Só valem com o Charles por perto e só agem em inimigos: explodem, atordoam por um turno e aplicam Glissant (%d%%), Surprise (%d%%) ou C'est Mon Tour (%d%%). Máximo de %d em campo." % [
					trap_count, int(trap_range), _pct(glissant_weight), _pct(surprise_weight),
					100 - _pct(glissant_weight) - _pct(surprise_weight), trap_max]
			text += "\nRecarga: %d rodadas." % trap_cooldown
		SKILL_GENIUS:
			title = "Mischievous Genius"
			text = "Gasta todos os %d PM: assusta os inimigos até %d de distância, deixando todos Confusos (habilidades embaralhadas e ocultas) por %d rodadas ou até gastarem uma habilidade." % [pm_max, int(genius_range), genius_rounds]
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()
	pm = 0
	_deflect_count = 0
	_set_assist(null, 0.0)
	for p in _stunned:
		if is_instance_valid(p):
			p.clear_lock()
	_stunned.clear()
	for p in _marked:
		CharlesFX.unmark(p)
	_marked.clear()
	_metavision_until_round = -1
	_meta_checked = -1
	_meta_busy = false
	last_rabona = {}
	_end_hold(true)
	for t: Dictionary in _traps:
		var node: CharlesFX.Mine = t["node"] as CharlesFX.Mine
		if node != null and is_instance_valid(node):
			node.queue_free()
	_traps.clear()
	queue_redraw()


# ---------- LOOP / VISUAL ----------

func _process(delta: float) -> void:
	super(delta)
	_update_hold()
	if get_attack_dir() != _pm_side:   # virou o lado (2º tempo): os diabinhos de PM trocam de lado
		_pm_side = get_attack_dir()
		queue_redraw()
	if _carousel != null:
		_carousel.visible = is_metavision_active()


func _physics_process(delta: float) -> void:
	super(delta)
	_update_traps()
	if is_metavision_active():
		_scan_metavision_shot()


func _draw() -> void:
	super()
	var center := Vector2(0.0, -height)
	# Anel laranja enquanto o Gremlin Détours está segurando a bola
	if _holding:
		draw_arc(center, placeholder_radius + 11.0, 0.0, TAU, 24, Color(1.0, 0.75, 0.1, 0.9), 2.0)
	# Marquinhas de PM ao lado dele
	if show_pm_marks:
		var side: float = get_attack_dir()   # +1 = direita, -1 = esquerda, conforme o lado que o time ataca
		CharlesFX.draw_pm_marks(self, center + Vector2(side * (placeholder_radius + pm_marks_offset.x), pm_marks_offset.y), pm, pm_max, pm_marks_size)


# ---------- SELETOR DE PM ----------

## Janelinha "quantos PM gastar?": uma barrinha com os diabinhos que muda com o SCROLL do mouse (ou setas / W S).
## Clique esquerdo ou Enter confirma; Esc ou clique direito desiste (-1).
class PmPicker extends CanvasLayer:
	signal chosen(amount: int)
	var _amount: int = 0
	var _have: int = 0
	var _max: int = 0
	var _done: bool = false
	var _bar: Control
	var _value_label: Label

	func setup(title: String, hint: String, have: int, max_spend: int) -> void:
		layer = 40
		_have = have
		_max = max_spend
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.35)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_STOP   # bloqueia cliques no jogo enquanto escolhe
		add_child(dim)

		var panel := PanelContainer.new()
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.07, 0.1, 0.94)
		sb.border_color = CharlesFX.YELLOW
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 16
		sb.content_margin_bottom = 16
		panel.add_theme_stylebox_override("panel", sb)
		add_child(panel)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 10)
		panel.add_child(box)
		box.add_child(UiStyle.make_label("%s — gastar PM? (você tem %d)" % [title, have], 20, CharlesFX.YELLOW))
		var hint_label := UiStyle.make_label(hint, 15, UiStyle.MUTED_COLOR)
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_label.custom_minimum_size = Vector2(380, 0)
		box.add_child(hint_label)
		_bar = Control.new()   # os diabinhos (acesos = serão gastos) e a barrinha embaixo
		_bar.custom_minimum_size = Vector2(maxf(float(have) * 36.0 + 40.0, 300.0), 76.0)
		_bar.draw.connect(_draw_bar)
		box.add_child(_bar)
		_value_label = UiStyle.make_label("", 22, CharlesFX.YELLOW_LIGHT)
		box.add_child(_value_label)
		box.add_child(UiStyle.make_label("Scroll do mouse muda · clique confirma · Esc cancela", 14, UiStyle.MUTED_COLOR))
		_refresh()

	func _step(delta: int) -> void:
		_amount = clampi(_amount + delta, 0, _max)
		_refresh()

	func _refresh() -> void:
		_value_label.text = "Gastar: %d PM" % _amount
		_bar.queue_redraw()

	func _draw_bar() -> void:
		var w: float = _bar.size.x
		var spacing: float = 36.0
		var x0: float = (w - spacing * float(_have - 1)) * 0.5
		for i in _have:   # os diabinhos de baixo para cima na tela: os primeiros _amount ficam acesos
			CharlesFX.draw_devil(_bar, Vector2(x0 + spacing * float(i), 28.0), 12.0, i < _amount)
		var rect := Rect2(12.0, 58.0, w - 24.0, 10.0)   # a barrinha: cheia na proporção do que vai gastar
		_bar.draw_rect(rect, Color(1, 1, 1, 0.12))
		_bar.draw_rect(Rect2(rect.position, Vector2(rect.size.x * float(_amount) / float(maxi(_max, 1)), rect.size.y)), CharlesFX.YELLOW)
		for i in range(_max + 1):   # marquinha de cada valor possível
			var x: float = rect.position.x + rect.size.x * float(i) / float(maxi(_max, 1))
			_bar.draw_line(Vector2(x, rect.position.y - 3.0), Vector2(x, rect.end.y + 3.0), Color(1, 1, 1, 0.5), 1.5)

	func _finish(amount: int) -> void:
		if _done:
			return
		_done = true
		chosen.emit(amount)

	func _input(event: InputEvent) -> void:
		if _done:
			return
		if event is InputEventMouseButton and event.pressed:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_step(1)
				MOUSE_BUTTON_WHEEL_DOWN:
					_step(-1)
				MOUSE_BUTTON_LEFT:
					_finish(_amount)
				MOUSE_BUTTON_RIGHT:
					_finish(-1)
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_UP, KEY_RIGHT, KEY_W, KEY_D:
					_step(1)
				KEY_DOWN, KEY_LEFT, KEY_S, KEY_A:
					_step(-1)
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					_finish(_amount)
				KEY_ESCAPE:
					_finish(-1)
				_:
					return
			get_viewport().set_input_as_handled()
