class_name Nagi
extends Player
## Seishiro Nagi. Herda tudo do Player (ações gerais) e adiciona as habilidades próprias.
## No menu aparecem 4 botões; cada um MUDA de variante sozinho conforme a situação (altura do Nagi,
## altura e distância da bola), igual ao Heavy/Bicycle de antes:
##
## PASSIVA, Death: chutes do Nagi (ações gerais ou habilidades) feitos "suspenso" ou "voando" têm
##   +0.1x de força e +3% de chance de gol.
##
## 1. DIRECT HEEL LIFT (recarga 2; compartilhada com Distortion e Zero Reset Turn)
##    - Direct Heel Lift: Nagi no chão e SEM bola próxima -> avanço de 220. Se encontrar a bola no chão,
##      QTE fácil; ganhando, salta com a bola na diagonal até "voando" e recebe o Distortion (de graça).
##    - Distortion: Nagi e bola "voando" -> chuta a bola no chão na diagonal; ela volta "suspensa" e o
##      Nagi a busca, ficando os dois suspensos.
##    - Zero Reset Turn: bola próxima no chão ou suspensa -> domina e dá dois avanços (150 para longe do
##      inimigo mais próximo; 200 direcionável). No 2º, se achar um inimigo: QTE fácil e, ganhando, dá um
##      chapéu, salta, busca a bola suspensa e ganha uma ação de habilidade. A CAVEIRA cresce a cada desvio.
## 2. FAKE VOLLEY (recarga 2; compartilhada com Juggling Shot)
##    - Fake Volley: bola próxima no chão ou suspensa -> finta o chute, ATORDOA o inimigo mais próximo e
##      avança 150 trazendo a bola. Começa um DOMÍNIO que dura o turno inimigo: quem tentar chegar na bola
##      com ação geral é atordoado; quem tentar com habilidade (chute) faz um TYPING GAME e, se perder, o
##      Nagi desvia sozinho.
##    - Juggling Shot: se o inimigo errar 2 typing games durante o domínio, o Nagi desvia de novo e chuta
##      sozinho para o gol inimigo (1.3x de força do Chutar, 50% de chance).
##    - Five Stage Volley (Reação Química Miracle, com o Reo): continua como antes; veja reaction_miracle.gd.
## 3. TRAP (recarga 2; compartilhada com Ground Control)
##    - Trap: SEM bola próxima -> avanço de 170. Se no fim a bola estiver a 170, vai até ela no nível em
##      que ela está (saltando se precisar) e faz um QTE fácil para ganhar uma ação de habilidade.
##    - Ground Control: bola próxima no chão -> passe suspenso para um aliado (alcance 350), Nagi ganha um
##      correr de 1 segundo, salta no fim, o aliado devolve a bola e um QTE fácil dá uma ação de habilidade.
## 4. HEAVY (recarga 2; compartilhada com Jumping Turn, Bicycle e Curiosity)
##    - Heavy: bola próxima, Nagi no chão ou suspenso -> chute 1.2x, 45% de chance, a bola SOBE na trajetória.
##    - Jumping Turn: se a última habilidade foi o Trap -> toque curto para o lado, sobe a bola, gira e chuta (1.3x, 50%).
##    - Bicycle: bola voando e Nagi suspenso -> bicicleta giratória (1.2x, 50%).
##    - Curiosity: como o Bicycle, mas com o Nagi na área do goleiro e na lateral dela (55%).
##
## Os efeitos (caveiras brancas com variações de azul/roxo claros) estão no nagi_fx.gd.
##
## Como montar a cena: Nova Cena Herdada de player.tscn -> anexe este script ao nó raiz
## -> renomeie o nó raiz para "Nagi".
##
## Animações opcionais (nomes na SpriteFrames; as que faltarem são puladas):
##   direct_heel_lift, distortion, zero_reset_turn, fake_volley, juggling_shot, trap, ground_control,
##   heavy, jumping_turn, bicycle, curiosity, five_stage_volley
## Frame de impacto em hit_frames, ex: {"heavy": 4, "bicycle": 5}

const SKILL_HEEL: StringName = &"direct_heel_lift"   # Direct Heel Lift / Distortion / Zero Reset Turn
const SKILL_FAKE: StringName = &"fake_volley"        # Fake Volley (Five Stage Volley)
const SKILL_TRAP: StringName = &"trap"               # Trap / Ground Control
const SKILL_HEAVY: StringName = &"heavy"             # Heavy / Jumping Turn / Bicycle / Curiosity

## Grupos de recarga (cada botão tem um, e as variantes dele COMPARTILHAM)
const CD_HEEL: StringName = &"cd_heel"
const CD_FAKE: StringName = &"cd_fake"
const CD_TRAP: StringName = &"cd_trap"
const CD_HEAVY: StringName = &"cd_heavy"

## Qual variante cabe na situação atual
enum HeelVariant { NONE, HEEL, DISTORTION, ZERO_RESET }
enum FakeVariant { NONE, FAKE_VOLLEY }
enum TrapVariant { NONE, TRAP, GROUND_CONTROL }
enum HeavyVariant { NONE, HEAVY, JUMPING_TURN, BICYCLE, CURIOSITY }

@export_group("Passiva: Death")
@export var death_force_bonus: float = 0.1                       # +0.1x de força nos chutes suspenso/voando
@export_range(0.0, 1.0) var death_chance_bonus: float = 0.03     # +3% de chance de gol

@export_group("Geral")
@export var stun_rounds: int = 1                 # Atordoado = sem ações (gerais e habilidades) por esta quantidade de rodadas
@export var ball_side_distance: float = 34.0     # onde a bola fica pairando, ao lado dele
@export var easy_qtes: bool = true               # false = pula todos os QTEs fáceis das habilidades
@export var kicks_use_qte: bool = false          # QTE nos chutes (Heavy, Jumping Turn, Bicycle, Curiosity). O pedido não cita QTE
@export var skull_size_start: float = 1.0        # caveira do Zero Reset Turn: tamanho no 1º desvio
@export var skull_size_step: float = 0.6         # quanto cresce a cada desvio
@export_range(0.0, 1.0) var skull_alpha_start: float = 0.3   # opacidade no 1º desvio
@export_range(0.0, 1.0) var skull_alpha_step: float = 0.18   # quanto sobe a cada desvio

@export_group("Direct Heel Lift / Distortion")
@export var heel_cooldown: int = 2
@export var heel_dash_range: float = 220.0       # avanço
@export var heel_dash_time: float = 0.3
@export var heel_hit_radius: float = 50.0        # a que distância ele "encontra" a bola no avanço
@export var heel_lift_forward: float = 80.0      # quanto avança, na diagonal, ao subir com a bola
@export var heel_lift_time: float = 0.45
@export var distortion_range: float = 150.0      # alcance da diagonal em que a bola é chutada no chão
@export var distortion_slam_time: float = 0.22
@export var distortion_rebound_distance: float = 70.0
@export var distortion_rebound_time: float = 0.35

@export_group("Zero Reset Turn")
@export var zero_first_range: float = 150.0      # 1º avanço: para longe do inimigo mais próximo
@export var zero_second_range: float = 200.0     # 2º avanço: direcionável
@export var zero_dash_time: float = 0.28
@export var zero_hit_radius: float = 60.0        # inimigo encontrado no 2º avanço
@export var zero_nutmeg_distance: float = 110.0  # quanto passa por trás do inimigo no chapéu
@export var zero_nutmeg_time: float = 0.5
@export var zero_extra_skills: int = 1           # ação de habilidade ganha (vale neste turno)

@export_group("Fake Volley / Juggling Shot")
@export var fake_cooldown: int = 2
@export var fake_dash_range: float = 150.0       # avanço trazendo a bola
@export var fake_dash_time: float = 0.25
@export var fake_enemy_radius: float = 160.0     # "inimigo mais próximo" a atordoar
@export var dominance_trigger_radius: float = 10.0   # adversário agindo (correr/carrinho) a esta distância da bola = tentou interagir
@export var dominance_hold_distance: float = 110.0   # se Nagi se afastar mais que isso da bola, o domínio acaba
@export var typing_time: float = 1.0
@export var typing_words: Array[String] = ["CAVEIRA", "DESVIO", "SILENCIO", "VOLEIO", "NAGI", "RESET", "FINTA"]
@export var juggling_fails_needed: int = 2       # typing games errados para disparar o Juggling Shot
@export var juggling_force: float = 1.3          # em múltiplos da força do Chutar
@export_range(0.0, 1.0) var juggling_chance: float = 0.5
@export var juggling_step: float = 60.0          # passo do desvio em direção ao gol

@export_group("Trap / Ground Control")
@export var trap_cooldown: int = 2
@export var trap_dash_range: float = 170.0
@export var trap_dash_time: float = 0.26
@export var trap_ball_range: float = 170.0       # a bola precisa estar a esta distância no fim do avanço
@export var trap_stop_distance: float = 32.0
@export var trap_leap_time: float = 0.3
@export var control_pass_range: float = 350.0    # Ground Control: alcance do passe suspenso
@export var control_pass_time: float = 0.45
@export var control_run_time: float = 1.3        # o "correr" de 1 segundo
@export var control_jump_time: float = 0.25
@export var control_return_time: float = 0.45
@export var control_extra_skills: int = 1        # ação de habilidade ganha com o QTE

@export_group("Heavy / Jumping Turn / Bicycle / Curiosity")
@export var heavy_cooldown: int = 2
@export var heavy_force: float = 1.2
@export_range(0.0, 1.0) var heavy_chance: float = 0.45
@export_range(0.0, 1.0) var heavy_rise_point: float = 0.7   # ponto de baixo da bola: ela SOBE na trajetória (0 = reto)
@export var jumping_force: float = 1.3
@export_range(0.0, 1.0) var jumping_chance: float = 0.5
@export var jumping_tap_distance: float = 40.0   # toque curto para o lado
@export var jumping_tap_time: float = 0.2
@export var jumping_spin_time: float = 0.4
@export var bicycle_force: float = 1.2
@export_range(0.0, 1.0) var bicycle_chance: float = 0.5
@export var bicycle_spin_time: float = 0.45
@export_range(0.0, 1.0) var curiosity_chance: float = 0.55
## Curiosity: área do goleiro INIMIGO (true) ou do próprio time (false)
@export var curiosity_enemy_area: bool = true
## "Na lateral": quão aberto (0 = qualquer ponto da área; 1 = só colado na linha de fundo lateral da área)
@export_range(0.0, 1.0) var curiosity_side_fraction: float = 0.5

@export_group("Miracle (Five Stage Volley)")
@export_range(0.0, 1.0) var five_chance: float = 0.80   # chance de gol do chute final
@export var five_force_mult: float = 2.1                # força do chute final, em múltiplos do voleio normal ("bem forte")
@export var five_uses_qte: bool = true                  # o chute final tem QTE de voleio (errou = chute fraco e cai)
@export var five_stages: int = 6                        # etapas no total: a 1ª é o Fake Volley parado, a última é o chute
@export var five_stage_time: float = 0.65               # duração do movimento de cada etapa do meio
@export var five_orbit_radius: float = 95.0             # raio da órbita do Nagi em volta da bola
@export var five_spin_turns: float = 2.0                # voltas completas que ele gira em cada etapa do meio
@export var five_return_time: float = 0.22              # tempo da volta ao ponto original, na última etapa
@export var five_travel_growth: float = 0.6             # a finta da bola vai ficando maior (0.6 = +60% na última)
@export var five_skull_start: float = 1.5               # tamanho da caveira na 1ª etapa
@export var five_skull_end: float = 6.5                 # tamanho da caveira na última
@export var five_shake: float = 8.0                     # tremor da câmera (px) na última finta; o chute final treme o dobro
@export var fake_travel: float = 70.0                   # quanto a bola sai na finta do Five Stage Volley
@export var fake_lift: float = 18.0
@export var fake_out_time: float = 0.18
@export var fake_back_time: float = 0.22
@export var five_fx: KickFX                             # vazio = estilo padrão (branco com brilho lilás, veja _make_five_fx)

@export_group("Visual dos chutes")
## Efeitos brancos com azul/roxo claros. Vazio = usa o estilo padrão do Nagi (veja _make_*_fx)
@export var soft_fx: KickFX      # avanços, domínio, Trap, Ground Control
@export var heavy_fx: KickFX     # Heavy, Jumping Turn, Juggling Shot (azul-gelo)
@export var bicycle_fx: KickFX   # Bicycle, Curiosity (branco giratório com lilás)

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: o id do botão (direct_heel_lift, fake_volley, trap, heavy)
## ou o nome da variante (distortion, zero_reset_turn, ground_control, jumping_turn, bicycle, curiosity, five_stage_volley).
@export var skill_icons: Dictionary = {}

## O Distortion que o Direct Heel Lift acabou de liberar (de graça, logo depois)
var _heel_followup: bool = false
## Última habilidade usada (para o Jumping Turn: "se a última foi o Trap")
var _last_skill: StringName = &""

## Ações extras temporárias (Zero Reset Turn / Trap / Ground Control): sobra no fim do turno do time dele = some
var _temp_extras: int = 0

## Domínio da bola (Fake Volley)
var _dom_active: bool = false
var _dom_busy: bool = false                # resolvendo uma tentativa de interação agora
var _dom_enemy_turn_pending: bool = false  # o turno do time do Nagi já acabou; falta o do adversário
var _dom_anchor: Vector2 = Vector2.ZERO    # onde a bola foi deixada
var _dom_fails: int = 0                    # typing games perdidos pelos inimigos
var _dom_stunned: Array[Player] = []       # já atordoados nesta janela (não repete)
var _dodges: int = 0                       # desvios (Zero Reset Turn / domínio): a caveira cresce a cada um

## Aura de caveirinhas (domínio e Five Stage Volley)
var _aura: CPUParticles2D
var _shake_tween: Tween
var _shake_cam: Camera2D
var _shake_rest: Vector2 = Vector2.ZERO

var _text: String = ""
var _text_tween: Tween
var _text_alpha: float = 0.0:
	set(v):
		_text_alpha = v
		queue_redraw()


func _init() -> void:
	character_id = "nagi"            # o menu de formação usa isto para saber quem é quem
	display_name = "Seishiro Nagi"   # aparece no placar de gols e no menu


func _ready() -> void:
	super()
	if soft_fx == null:
		soft_fx = _make_soft_fx()
	if heavy_fx == null:
		heavy_fx = _make_heavy_fx()
	if bicycle_fx == null:
		bicycle_fx = _make_bicycle_fx()
	_hook_manager.call_deferred()   # o MatchManager entra na árvore no mesmo frame


# ---------- VISUAL: ESTILOS DO CHUTE (branco, azul e lilás bem claros) ----------

## Fumaça clara que sobe
func _make_soft_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = Color(0.96, 0.96, 1.0)
	fx.trail_width = 12.0
	fx.particle_color = Color(0.82, 0.9, 1.0)
	fx.amount = 18
	fx.lifetime = 0.6
	fx.speed_min = 10.0
	fx.speed_max = 55.0
	fx.gravity = Vector2(0.0, -40.0)
	fx.spin = 120.0
	fx.scale_min = 0.2
	fx.scale_max = 0.45
	fx.burst_amount = 12
	fx.burst_speed = 180.0
	return fx


## Azul-gelo pesado: o rastro é grosso e as partículas CAEM
func _make_heavy_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = Color(0.86, 0.93, 1.0)
	fx.trail_width = 22.0
	fx.particle_color = Color(0.7, 0.82, 1.0)
	fx.amount = 26
	fx.lifetime = 0.7
	fx.speed_min = 20.0
	fx.speed_max = 90.0
	fx.gravity = Vector2(0.0, 260.0)
	fx.spin = 90.0
	fx.scale_min = 0.25
	fx.scale_max = 0.55
	fx.burst_amount = 22
	fx.burst_speed = 300.0
	return fx


## Branco brilhante e giratório com lilás (Bicycle, Curiosity)
func _make_bicycle_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = Color(1.0, 1.0, 1.0)
	fx.trail_width = 16.0
	fx.particle_color = Color(0.86, 0.8, 1.0)
	fx.amount = 30
	fx.lifetime = 0.5
	fx.speed_min = 30.0
	fx.speed_max = 110.0
	fx.gravity = Vector2.ZERO
	fx.spin = 540.0
	fx.swirl = 60.0
	fx.scale_min = 0.15
	fx.scale_max = 0.4
	fx.burst_amount = 24
	fx.burst_speed = 360.0
	return fx


# ---------- LIGAÇÃO COM O MATCHMANAGER ----------

func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m:
		m.turn_started.connect(_on_turn_started)
		m.turn_ended.connect(_on_turn_ended)


func _on_turn_started(turn_team: int) -> void:
	if turn_team != team:
		return
	_heel_followup = false
	_last_skill = &""
	# O turno do time dele voltou: o adversário já jogou, o domínio acabou
	if _dom_active and _dom_enemy_turn_pending:
		_end_dominance()


func _on_turn_ended(turn_team: int) -> void:
	if turn_team != team:
		return
	_heel_followup = false
	_expire_temp_extras()
	if _dom_active:
		_dom_enemy_turn_pending = true   # o domínio segue valendo durante o turno do adversário


# ---------- PASSIVA: DEATH ----------

## Chutes "suspenso" ou "voando" (ação geral Chutar ou qualquer habilidade): +0.1x de força, +3% de chance
func kick_ball(ball: Ball, direction: Vector2, kind: KickType, qte_success: bool = true,
		chance_override: float = -1.0, ignore_self_collision: bool = false,
		fx: KickFX = null, anim: StringName = &"", on_kick: Callable = Callable()) -> void:
	var airborne: bool = height_level != Heights.Level.GROUND
	var prior_bonus: float = next_shot_bonus
	if airborne:
		next_kick_force_mult += death_force_bonus
		if chance_override >= 0.0:
			chance_override = minf(chance_override + death_chance_bonus, 1.0)
		else:
			next_shot_bonus += death_chance_bonus   # o kick_ball gasta isto na chance do Chutar
		NagiFX.puff(self, 4)
	await super(ball, direction, kind, qte_success, chance_override, ignore_self_collision, fx, anim, on_kick)
	if airborne and chance_override < 0.0 and next_shot_bonus > 0.0:
		next_shot_bonus = prior_bonus   # o chute foi cancelado antes de gastar: devolve ao que era


# ---------- AÇÕES EXTRAS TEMPORÁRIAS ----------

## Dá ações de habilidade só ao Nagi. O que sobrar no fim do turno do time dele some.
func _grant_temp_extra(amount: int) -> void:
	extra_skill_left += amount
	_temp_extras += amount


func _expire_temp_extras() -> void:
	var expiring: int = mini(_temp_extras, extra_skill_left)
	if expiring > 0:
		extra_skill_left -= expiring
	_temp_extras = 0


# ---------- AUXILIARES ----------

## Usa a animação própria se a SpriteFrames tiver; senão cai no fallback
func _anim_or(anim: StringName, fallback: StringName) -> StringName:
	if _has_art and animated_sprite.sprite_frames.has_animation(anim):
		return anim
	return fallback


func _enemies_within(radius: float) -> Array[Player]:
	var list: Array[Player] = []
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other.team != team and not other.is_down \
				and global_position.distance_to(other.global_position) <= radius:
			list.append(other)
	return list


func _nearest_enemy(max_distance: float = INF) -> Player:
	var best: Player = null
	var best_d: float = max_distance
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other.team == team or other.is_down:
			continue
		var d: float = global_position.distance_to(other.global_position)
		if d <= best_d:
			best_d = d
			best = other
	return best


## Direção até o inimigo mais próximo (ou para onde o Nagi olha, se não houver)
func _nearest_enemy_dir(enemies: Array[Player]) -> Vector2:
	if enemies.is_empty():
		return Vector2(facing, 0.0)
	var nearest: Player = enemies[0]
	for e: Player in enemies:
		if e.global_position.distance_to(global_position) < nearest.global_position.distance_to(global_position):
			nearest = e
	var to_enemy: Vector2 = nearest.global_position - global_position
	return to_enemy.normalized() if to_enemy.length() > 1.0 else Vector2(facing, 0.0)


## Para onde fugir no 1º avanço do Zero Reset Turn: o lado oposto ao inimigo mais próximo
func _away_dir() -> Vector2:
	var enemy: Player = _nearest_enemy()
	if enemy == null:
		return Vector2(-_default_facing(), 0.0)
	var away: Vector2 = global_position - enemy.global_position
	return away.normalized() if away.length() > 1.0 else Vector2(-_default_facing(), 0.0)


## Ponto do gol inimigo (centro), em coordenadas globais
func _enemy_goal_point() -> Vector2:
	var f: Field = get_tree().get_first_node_in_group("field") as Field
	if f == null:
		return global_position + Vector2(_default_facing() * 800.0, 0.0)
	var half: Vector2 = f.pitch_size * 0.5
	return f.to_global(Vector2(-float(f.defend_dir(team)) * half.x, 0.0))


func _near_ball() -> bool:
	var ball: Ball = _get_ball()
	return ball != null and get_kick_type(ball) != KickType.NONE


func _ball_level() -> Heights.Level:
	var ball: Ball = _get_ball()
	return ball.get_level() if ball != null else Heights.Level.GROUND


## QTE fácil (devolve true se acertou ou se o QTE está desligado)
func _easy_qte(m: MatchManager) -> bool:
	if not easy_qtes or skips_qte():
		return true
	return await m.run_qte(KickType.VOLLEY)


## Aura da habilidade na bola por alguns segundos (mesmo pairando). Chame DEPOIS do register_touch.
func _ball_aura(ball: Ball, fx: KickFX, seconds: float) -> void:
	if fx == null or ball == null:
		return
	var previous: bool = ball.fx_during_hover
	ball.fx_during_hover = true
	ball.play_fx(fx)
	NagiFX.trail(ball, seconds)
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(ball):
		ball.stop_fx()
		ball.fx_during_hover = previous


## Atordoa um adversário: ele perde as ações (gerais e habilidades) por stun_rounds
func _stun(p: Player) -> void:
	if p == null or not is_instance_valid(p) or p.is_down:
		return
	p.apply_lock(self, stun_rounds)
	NagiFX.stun(p)


## Avanço rápido até "dest". Devolve {"ball": bool, "enemy": Player ou null}.
## carry: bola que vem junto (fica ao lado dele, na altura carry_height).
## stop_for_ball: para ao encontrar a bola NO CHÃO; stop_for_enemy: para ao encontrar um inimigo.
func _dash(dest: Vector2, time: float, carry: Ball = null, carry_dir: Vector2 = Vector2.ZERO,
		carry_height: float = 0.0, stop_for_ball: bool = false, stop_for_enemy: bool = false) -> Dictionary:
	var result: Dictionary = {"ball": false, "enemy": null}
	NagiFX.line(self, global_position, dest, 10)
	var tw: Tween = create_tween()
	tw.tween_property(self, "global_position", dest, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var ball_tw: Tween = null
	if carry != null:
		var side: Vector2 = carry_dir.normalized() if carry_dir.length() > 0.01 else Vector2(facing, 0.0)
		ball_tw = carry.hover_to(dest + side * ball_side_distance, carry_height, time)
	while tw.is_valid() and tw.is_running():
		await get_tree().physics_frame
		if stop_for_ball:
			var b: Ball = _get_ball()
			if b != null and not b.is_held() and b.get_level() == Heights.Level.GROUND \
					and global_position.distance_to(b.global_position) <= heel_hit_radius:
				result["ball"] = true
				break
		if stop_for_enemy:
			for other: Player in get_tree().get_nodes_in_group("players"):
				if other.team != team and not other.is_down \
						and global_position.distance_to(other.global_position) <= zero_hit_radius:
					result["enemy"] = other
					break
			if result["enemy"] != null:
				break
	if tw.is_valid() and tw.is_running():
		tw.kill()
		if ball_tw != null and ball_tw.is_valid():
			ball_tw.kill()
	return result


## Sobe/desce o Nagi até um nível, com o salto visual
func _go_to_level(level: Heights.Level, time: float) -> void:
	height_level = level
	var tw: Tween = create_tween()
	tw.tween_property(self, "height", Heights.to_height(level), time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished


## Giro do corpo (bicicleta, Jumping Turn): mexe na rotação do nó que sobe com o Nagi
func _spin(turns: float, time: float) -> void:
	if _lift_node == null:
		return
	var tw: Tween = create_tween()
	tw.tween_property(_lift_node, "rotation", TAU * turns * facing, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Voltar ao normal = deixar o próprio Player refazer o visual dele (também respeita o "deitado" de quem caiu).
func _reset_spin() -> void:
	if _lift_node != null:
		_update_visual()


## Um desvio: a caveira sai de cima dele, MAIOR e MAIS OPACA a cada desvio
func _dodge_skull() -> void:
	var size_mult: float = NagiFX.stage_size(_dodges, skull_size_start, skull_size_step)
	var alpha: float = NagiFX.stage_alpha(_dodges, skull_alpha_start, skull_alpha_step)
	_dodges += 1
	NagiFX.skull(self, size_mult, alpha, 1.2)


# ---------- 1. DIRECT HEEL LIFT / DISTORTION / ZERO RESET TURN ----------

func get_heel_variant() -> HeelVariant:
	var ball: Ball = _get_ball()
	if ball == null or is_down:
		return HeelVariant.NONE
	if get_kick_type(ball) == KickType.NONE:
		# Sem bola próxima: o avanço, só com o Nagi no chão
		return HeelVariant.HEEL if height_level == Heights.Level.GROUND else HeelVariant.NONE
	var level: Heights.Level = ball.get_level()
	if height_level == Heights.Level.FLYING:
		return HeelVariant.DISTORTION if level == Heights.Level.FLYING else HeelVariant.NONE
	if level == Heights.Level.GROUND or level == Heights.Level.SUSPENDED:
		return HeelVariant.ZERO_RESET
	return HeelVariant.NONE


## O Distortion está de graça agora? Só como complemento do Direct Heel Lift
func _distortion_is_followup() -> bool:
	return _heel_followup and get_heel_variant() == HeelVariant.DISTORTION


func _use_heel_skill() -> bool:
	match get_heel_variant():
		HeelVariant.HEEL:
			return await _use_direct_heel_lift()
		HeelVariant.DISTORTION:
			return await _use_distortion()
		HeelVariant.ZERO_RESET:
			return await _use_zero_reset()
	return false


func _use_direct_heel_lift() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or get_heel_variant() != HeelVariant.HEEL:
		return false
	var dir: Vector2 = await m.aim_for_skill(self, heel_dash_range)
	if dir == Vector2.ZERO:
		return false   # cancelou: não gasta a ação
	dir = dir.normalized()
	face_towards(dir)
	if not await play_action(&"direct_heel_lift"):
		return false

	m.clear_pending_pass()
	NagiFX.puff(self, 6)
	var res: Dictionary = await _dash(global_position + dir * heel_dash_range, heel_dash_time, null, Vector2.ZERO, 0.0, true)
	var ball: Ball = _get_ball()
	if res["ball"] and ball != null and not ball.is_held() and ball.get_level() == Heights.Level.GROUND:
		# Encontrou a bola no chão: QTE fácil
		if await _easy_qte(m):
			ball = _get_ball()
			if ball != null:
				await _heel_lift_up(ball, dir)
				_heel_followup = true   # recebe o Distortion
	start_cooldown(CD_HEEL, heel_cooldown)
	_last_skill = &"heel"
	return true


## Salta com a bola, na diagonal, até "voando" (os dois pairam lá)
func _heel_lift_up(ball: Ball, dir: Vector2) -> void:
	ball.register_touch(self)
	height_level = Heights.Level.FLYING
	var dest: Vector2 = global_position + dir * heel_lift_forward
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", dest, heel_lift_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "height", Heights.FLYING_HEIGHT, heel_lift_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ball.hover_to(dest + dir * ball_side_distance, Heights.FLYING_HEIGHT, heel_lift_time)
	NagiFX.ring(self, global_position, 40.0, 12)
	await tw.finished
	ball.register_touch(self)
	_ball_aura(ball, soft_fx, 0.5)
	_say("HEEL LIFT")


## Distortion: chuta a bola no chão na diagonal; ela volta suspensa e o Nagi a busca
func _use_distortion() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or get_heel_variant() != HeelVariant.DISTORTION:
		return false
	var was_followup: bool = _distortion_is_followup()
	var dir: Vector2 = await m.aim_for_skill(self, distortion_range)
	if dir == Vector2.ZERO:
		return false
	dir = dir.normalized()
	face_towards(dir)
	if not await play_action(&"distortion", ANIM_FLYING_KICK):
		return false
	var ball: Ball = _get_ball()
	if ball == null or get_heel_variant() != HeelVariant.DISTORTION:
		return false

	m.clear_pending_pass()
	ball.register_touch(self)
	NagiFX.puff(self, 6)
	_ball_aura(ball, heavy_fx, distortion_slam_time + distortion_rebound_time + 0.2)
	# A bola vai ao chão na diagonal...
	var slam_to: Vector2 = ball.global_position + dir * distortion_range
	var slam: Tween = ball.hover_to(slam_to, Heights.GROUND_HEIGHT, distortion_slam_time)
	await slam.finished
	NagiFX.burst(self, slam_to, 8, false)
	# ...e volta SUSPENSA. O Nagi a busca e fica Suspenso também
	var rebound_to: Vector2 = slam_to + dir * distortion_rebound_distance
	ball.hover_to(rebound_to, Heights.SUSPENDED_HEIGHT, distortion_rebound_time)
	height_level = Heights.Level.SUSPENDED
	var fetch: Tween = create_tween().set_parallel(true)
	fetch.tween_property(self, "global_position", rebound_to - dir * ball_side_distance, distortion_rebound_time + 0.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fetch.tween_property(self, "height", Heights.SUSPENDED_HEIGHT, distortion_rebound_time + 0.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await fetch.finished
	ball = _get_ball()
	if ball != null:
		ball.register_touch(self)
	_say("DISTORTION")
	if not was_followup:
		start_cooldown(CD_HEEL, heel_cooldown)   # como complemento, a recarga já começou no Direct Heel Lift
	_heel_followup = false
	_last_skill = &"distortion"
	return true


## Zero Reset Turn: domina a bola e dá dois avanços; no 2º, se achar um inimigo, QTE fácil e chapéu
func _use_zero_reset() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null or get_heel_variant() != HeelVariant.ZERO_RESET:
		return false
	# Primeiro escolhe a direção do 2º avanço; só gasta a ação se confirmar
	var second_dir: Vector2 = await m.aim_for_skill(self, zero_second_range)
	if second_dir == Vector2.ZERO:
		return false
	second_dir = second_dir.normalized()
	ball = _get_ball()
	if ball == null or get_heel_variant() != HeelVariant.ZERO_RESET:
		return false
	if not await play_action(&"zero_reset_turn"):
		return false
	ball = _get_ball()
	if ball == null:
		return false

	m.clear_pending_pass()
	ball.register_touch(self)
	var ball_h: float = Heights.to_height(ball.get_level())
	_dodges = 0
	_ball_aura(ball, soft_fx, 1.2)
	NagiFX.puff(self, 6)

	# Avanço 1: para LONGE do inimigo mais próximo (desvio)
	var away: Vector2 = _away_dir()
	face_towards(away)
	_dodge_skull()
	_say("RESET")
	await _dash(global_position + away * zero_first_range, zero_dash_time, ball, away, ball_h)

	# Avanço 2: direcionável (desvio). Se achar um inimigo, para e tenta o chapéu
	face_towards(second_dir)
	_dodge_skull()
	var res: Dictionary = await _dash(global_position + second_dir * zero_second_range, zero_dash_time,
		ball, second_dir, ball_h, false, true)
	var enemy: Player = res["enemy"] as Player
	if enemy != null and is_instance_valid(enemy):
		if await _easy_qte(m):
			await _nutmeg(enemy, second_dir)
			_grant_temp_extra(zero_extra_skills)
			_say("CHAPÉU!")
		else:
			var b: Ball = _get_ball()
			if b != null and b.hovering:
				b.release_hover()   # perdeu a bola no encontro
			_say("...")
	start_cooldown(CD_HEEL, heel_cooldown)
	_last_skill = &"zero"
	return true


## Chapéu: a bola passa por cima do inimigo, o Nagi salta atrás dela e a busca suspensa no fim
func _nutmeg(enemy: Player, dir: Vector2) -> void:
	var ball: Ball = _get_ball()
	if ball == null:
		return
	_dodge_skull()
	var beyond: Vector2 = enemy.global_position + dir * zero_nutmeg_distance
	height_level = Heights.Level.SUSPENDED
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", beyond, zero_nutmeg_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "height", Heights.SUSPENDED_HEIGHT, zero_nutmeg_time * 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ball.hover_to(beyond + dir * ball_side_distance, Heights.SUSPENDED_HEIGHT, zero_nutmeg_time)
	await tw.finished
	ball = _get_ball()
	if ball != null:
		ball.register_touch(self)
		_ball_aura(ball, soft_fx, 0.6)


# ---------- 2. FAKE VOLLEY / DOMÍNIO / JUGGLING SHOT ----------

func get_fake_variant() -> FakeVariant:
	var ball: Ball = _get_ball()
	if ball == null or is_down or get_kick_type(ball) == KickType.NONE:
		return FakeVariant.NONE
	if height_level == Heights.Level.FLYING:
		return FakeVariant.NONE
	var level: Heights.Level = ball.get_level()
	if level == Heights.Level.GROUND or level == Heights.Level.SUSPENDED:
		return FakeVariant.FAKE_VOLLEY
	return FakeVariant.NONE


func _use_fake_skill() -> bool:
	if get_fake_variant() == FakeVariant.NONE:
		return false
	# Reação Química Miracle: com as condições cumpridas, o Fake Volley vira o Five Stage Volley
	if _miracle_available() != null:
		return await _use_five_stage_volley()
	return await _use_fake_volley()


## Finta o chute, atordoa o inimigo mais próximo, avança trazendo a bola e começa o domínio
func _use_fake_volley() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or get_fake_variant() != FakeVariant.FAKE_VOLLEY:
		return false
	var dir: Vector2 = await m.aim_for_skill(self, fake_dash_range)
	if dir == Vector2.ZERO:
		return false
	dir = dir.normalized()
	face_towards(dir)
	if not await play_action(&"fake_volley", ANIM_VOLLEY):
		return false
	var ball: Ball = _get_ball()
	if ball == null or get_fake_variant() != FakeVariant.FAKE_VOLLEY:
		return false

	m.clear_pending_pass()
	ball.register_touch(self)
	NagiFX.puff(self, 8)
	# Atordoa o inimigo mais próximo
	var target: Player = _nearest_enemy(fake_enemy_radius)
	if target != null:
		_stun(target)
		_say("FINTA!")
	# Avanço curto trazendo a bola (na altura em que ela estava)
	var ball_h: float = Heights.to_height(ball.get_level())
	_ball_aura(ball, soft_fx, fake_dash_time + 0.3)
	await _dash(global_position + dir * fake_dash_range, fake_dash_time, ball, dir, ball_h)
	ball = _get_ball()
	if ball != null:
		_start_dominance(ball)
	start_cooldown(CD_FAKE, fake_cooldown)
	_last_skill = &"fake"
	return true


func _start_dominance(ball: Ball) -> void:
	_dom_active = true
	_dom_busy = false
	_dom_enemy_turn_pending = false
	_dom_fails = 0
	_dom_stunned.clear()
	_dodges = 0
	_dom_anchor = ball.global_position
	ball.contest_owner = self   # o chute de um adversário passa pelo resolve_ball_contest abaixo
	_start_aura()
	queue_redraw()


func _end_dominance() -> void:
	if not _dom_active:
		return
	_dom_active = false
	_dom_busy = false
	_dom_enemy_turn_pending = false
	_dom_stunned.clear()
	var ball: Ball = _get_ball()
	if ball != null and is_instance_valid(ball) and ball.contest_owner == self:
		ball.contest_owner = null
		# Só solta a bola se ela ainda está onde ele a deixou (se alguém a moveu, ela já tem dono novo)
		if ball.hovering and not ball.is_held() and ball.global_position.distance_to(_dom_anchor) <= 8.0:
			ball.release_hover()
	_stop_aura()
	queue_redraw()


## Chamado todo frame: encerra o domínio se a bola foi mexida/solta ou se o Nagi se afastou, e
## ATORDOA o adversário que tenta chegar na bola com uma ação geral (correr / carrinho) no turno dele.
func _check_dominance() -> void:
	if not _dom_active:
		return
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null or ball.contest_owner != self or is_down \
			or ball.global_position.distance_to(_dom_anchor) > 8.0 \
			or global_position.distance_to(ball.global_position) > dominance_hold_distance:
		_end_dominance()
		return
	if _dom_busy or m.current_team == team:
		return
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other.team == team or other.is_down or other.state == State.IDLE or other in _dom_stunned:
			continue
		if other.global_position.distance_to(ball.global_position) <= dominance_trigger_radius:
			_dom_stunned.append(other)
			_stun(other)
			_say("DESVIOU!")
			if not is_down:
				hop_over()
			return


## Um adversário tenta CHUTAR a bola dominada (veja Player.kick_ball). true = o chute dele segue;
## false = foi barrado.
##  - ação geral (Chutar): ele é atordoado;
##  - habilidade: typing game. Perdeu = o Nagi desvia sozinho (e, no 2º erro, o Juggling Shot).
func resolve_ball_contest(attacker: Player, by_skill: bool) -> bool:
	if not _dom_active or attacker.team == team or is_down:
		return true
	var m: MatchManager = _get_manager()
	if m == null:
		return true
	_dom_busy = true
	if not by_skill:
		_stun(attacker)
		hop_over()
		_dodge_skull()
		_say("DESVIOU!")
		_dom_busy = false
		return false
	var title: String = "Nagi desvia!"
	var won: bool = await m.run_typing_game(title, typing_words, typing_time)
	if won:
		_end_dominance()   # a bola é do adversário
		return true
	_dom_fails += 1
	hop_over()
	_dodge_skull()
	_say("DESVIOU!")
	if _dom_fails >= juggling_fails_needed:
		await _juggling_shot()
	_dom_busy = false
	return false


## Juggling Shot: desvia de novo e chuta sozinho para o gol inimigo
func _juggling_shot() -> void:
	var ball: Ball = _get_ball()
	if ball == null or is_down:
		_end_dominance()
		return
	var goal: Vector2 = _enemy_goal_point()
	var dir: Vector2 = (goal - ball.global_position)
	dir = dir.normalized() if dir.length() > 1.0 else Vector2(_default_facing(), 0.0)
	# Libera o domínio para o próprio chute não ser barrado
	_dom_active = false
	ball.contest_owner = null
	_stop_aura()
	face_towards(dir)
	# O desvio: um passo em direção ao gol, com a bola junto
	var level_h: float = ball.height
	var step_to: Vector2 = global_position + dir * juggling_step
	var step: Tween = create_tween()
	step.tween_property(self, "global_position", step_to, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ball.hover_to(step_to + dir * ball_side_distance, level_h, 0.2)
	await step.finished
	ball = _get_ball()
	if ball == null:
		return
	var kind: KickType = get_kick_type(ball)
	if kind == KickType.NONE:
		kind = KickType.VOLLEY if ball.get_level() != Heights.Level.GROUND else KickType.GROUND
	_say("JUGGLING!")
	NagiFX.burst(self, global_position + Vector2(0.0, -height - 20.0), 12, true)
	next_kick_force_mult = juggling_force   # 1.3x da força do Chutar
	await kick_ball(ball, dir, kind, true, juggling_chance, false, heavy_fx,
		_anim_or(&"juggling_shot", ANIM_VOLLEY))
	_end_dominance()


## O Carrinho de um adversário não derruba o Nagi enquanto ele domina a bola: ele desvia e o atacante é atordoado
func try_counter_slide(attacker: Player) -> bool:
	if not _dom_active or attacker.team == team or is_down:
		return false
	_stun(attacker)
	hop_over()
	_dodge_skull()
	_say("DESVIOU!")
	return true


# ---------- 2a. FIVE STAGE VOLLEY (Reação Química Miracle, com o Reo) ----------

## A reação Miracle está disponível agora? Devolve a reação ou null. Confere o que é do Nagi
## (os dois suspensos e próximos + inimigo por perto); o resto (Our Dream do Reo, bola intocada, recarga
## do time) é do reaction_miracle.gd e do ReactionManager.
func _miracle_available() -> ChemicalReaction:
	if height_level != Heights.Level.SUSPENDED or not _near_ball() or _ball_level() != Heights.Level.SUSPENDED:
		return null
	if _enemies_within(fake_enemy_radius).is_empty():
		return null
	var rm: ReactionManager = ReactionManager.get_for(self)
	if rm == null:
		return null
	var reaction: ChemicalReaction = rm.find_available(self)
	if reaction == null or reaction.id != &"miracle":
		return null
	return reaction


func _use_five_stage_volley() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	var reaction: ChemicalReaction = _miracle_available()
	if m == null or ball == null or reaction == null:
		return false
	var partner: Player = reaction.find_partner(self)
	if partner == null:
		return false

	# 1) Mira do chute final. Cancelar aqui NÃO gasta nada: a cutscene e a recarga só começam depois
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false
	# Tudo pode ter mudado enquanto ele mirava: confere de novo
	ball = _get_ball()
	reaction = _miracle_available()
	if ball == null or reaction == null:
		return false
	partner = reaction.find_partner(self)
	if partner == null:
		return false

	# 2) Cutscene: a partida congela, toca o diálogo e SÓ DEPOIS o movimento acontece
	var rm: ReactionManager = ReactionManager.get_for(self)
	if rm == null:
		return false
	await rm.play(reaction, self, partner)
	ball = _get_ball()
	if ball == null:
		return false

	# 3) Prepara a sequência
	if five_fx == null:
		five_fx = _make_five_fx()
	var origin: Vector2 = global_position
	var to_ball: Vector2 = ball.global_position - global_position
	var rest_dir: Vector2 = to_ball.normalized() if to_ball.length() > 1.0 else Vector2(facing, 0.0)
	var home: Vector2 = origin + rest_dir * ball_side_distance   # onde a bola fica pairando, do lado dele
	var level_height: float = Heights.SUSPENDED_HEIGHT
	var out_dir: Vector2 = _nearest_enemy_dir(_enemies_within(fake_enemy_radius))
	var base_angle: float = (origin - home).angle()               # de que lado da bola ele começou
	var stage_count: int = maxi(five_stages, 2)

	var previous_hover_fx: bool = ball.fx_during_hover
	ball.fx_during_hover = true   # a aura da bola continua mesmo com ela pairando
	_start_aura()

	# 4) Etapas de finta: a 1ª é o Fake Volley parado; as do meio andam em órbita e giram, suspenso
	for k in range(stage_count - 1):
		var progress: float = float(k) / float(stage_count - 1)
		_show_skull(lerpf(five_skull_start, five_skull_end, progress), five_stage_time + 0.4,
			lerpf(0.35, 0.95, progress))
		_say("STAGE %d" % (k + 1))
		_pulse(five_stage_time)
		_shake_camera(lerpf(1.5, five_shake, progress), 0.25)

		var move_tw: Tween = null
		if k > 0:
			var angle: float = base_angle + TAU * float(k) / float(stage_count - 1)
			var spot: Vector2 = home + Vector2.from_angle(angle) * five_orbit_radius
			face_towards(home - spot)
			move_tw = create_tween().set_parallel(true)
			move_tw.tween_property(self, "global_position", spot, five_stage_time) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			if _lift_node != null:
				move_tw.tween_property(_lift_node, "rotation", TAU * five_spin_turns * facing, five_stage_time) \
					.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		else:
			face_towards(home - origin)

		if not await play_action(&"fake_volley", ANIM_VOLLEY):
			_five_cleanup(ball, previous_hover_fx)
			return false
		ball = _get_ball()
		if ball == null:
			_five_cleanup(null, previous_hover_fx)
			return false

		# A bola "sai" na direção do inimigo e volta; a cada etapa vai um pouco mais longe
		var travel: float = fake_travel * (1.0 + five_travel_growth * progress)
		ball.register_touch(self)
		ball.play_fx(five_fx)   # chamado DEPOIS do register_touch: recomeça a aura e solta uma explosão
		var out_tween: Tween = ball.hover_to(home + out_dir * travel, level_height + fake_lift, fake_out_time)
		await out_tween.finished
		var back_tween: Tween = ball.hover_to(home, level_height, fake_back_time)
		await back_tween.finished

		# Espera o Nagi acabar de andar/girar (se o tween já acabou, ele não é mais válido: não espera)
		if move_tw != null and move_tw.is_valid():
			await move_tw.finished
		_reset_spin()

	# 5) Última etapa: volta ao ponto original e dispara
	_show_skull(five_skull_end, 1.0, 1.0)
	_say("MIRACLE!")
	_pulse(0.6)
	_shake_camera(five_shake, 0.35)
	face_towards(aim)
	var dash: Tween = create_tween()
	dash.tween_property(self, "global_position", origin, five_return_time) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await dash.finished

	ball = _get_ball()
	if ball == null:
		_five_cleanup(null, previous_hover_fx)
		return false
	var qte_ok: bool = true
	if five_uses_qte and not skips_qte():
		qte_ok = await m.run_qte(KickType.VOLLEY)
	var touches_before: int = ball.interaction_count
	next_kick_force_mult = five_force_mult   # "bem forte": o kick_ball gasta isto no chute
	# Os dois estão Suspensos, então é um voleio. 80% (five_chance) no lugar da chance padrão do voleio
	await kick_ball(ball, aim, KickType.VOLLEY, qte_ok, five_chance, false,
		five_fx if qte_ok else null, _anim_or(&"five_stage_volley", _anim_or(&"fake_volley", ANIM_VOLLEY)),
		_on_five_kick)

	var kicked: bool = is_instance_valid(ball) and ball.interaction_count != touches_before
	_five_cleanup(ball, previous_hover_fx)
	if not kicked:
		return false   # a ação foi cancelada antes do chute (ex: a partida reiniciou)
	start_cooldown(CD_FAKE, fake_cooldown)   # a recarga do Fake Volley vale também para a versão da reação
	_last_skill = &"fake"
	return true




## Chamado pelo kick_ball no instante em que a bola sai: tremor forte + clarão branco
func _on_five_kick(_ball: Ball, _dir: Vector2, _speed: float) -> void:
	_shake_camera(five_shake * 2.0, 0.5)
	_screen_flash(Color(1.0, 1.0, 1.0, 0.85), 0.5)
	_pulse(0.7)
	NagiFX.burst(self, global_position + Vector2(0.0, -height - 20.0), 18, true)


## Limpa o que a sequência deixou (giro, aura de caveirinhas, aura da bola)
func _five_cleanup(ball: Ball, previous_hover_fx: bool) -> void:
	_reset_spin()
	_stop_aura()
	if ball != null and is_instance_valid(ball):
		ball.fx_during_hover = previous_hover_fx


## Branco com brilho lilás (a cor do Reo): rastro grosso e giratório, explosão grande
func _make_five_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = Color(1.0, 1.0, 1.0)
	fx.trail_width = 26.0
	fx.particle_color = Color(0.84, 0.76, 1.0)
	fx.amount = 40
	fx.lifetime = 0.65
	fx.speed_min = 40.0
	fx.speed_max = 150.0
	fx.gravity = Vector2.ZERO
	fx.spin = 600.0
	fx.swirl = 90.0
	fx.scale_min = 0.2
	fx.scale_max = 0.55
	fx.burst_amount = 36
	fx.burst_speed = 420.0
	return fx


## Caveirinhas que sobem do Nagi enquanto dura o domínio / a sequência
func _start_aura() -> void:
	if _aura == null:
		_aura = NagiFX.make_aura(placeholder_radius * 1.4)
		_aura.z_index = 1
		add_child(_aura)
	_aura.emitting = true


func _stop_aura() -> void:
	if _aura != null:
		_aura.emitting = false


## Tremor da câmera (mexe no offset da Camera2D ativa e devolve ao normal no fim)
func _shake_camera(strength: float, duration: float) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		if is_instance_valid(_shake_cam):
			_shake_cam.offset = _shake_rest   # um tremor novo começou no meio de outro: volta ao zero antes
	_shake_cam = cam
	_shake_rest = cam.offset
	var steps: int = maxi(int(duration / 0.03), 2)
	_shake_tween = create_tween()
	for i in steps:
		var fade: float = 1.0 - float(i) / float(steps)
		var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * fade
		_shake_tween.tween_property(cam, "offset", _shake_rest + jitter, 0.03)
	_shake_tween.tween_property(cam, "offset", _shake_rest, 0.03)


## Clarão de tela cheia que some rápido
func _screen_flash(color: Color, time: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	get_tree().root.add_child(layer)
	var tw: Tween = rect.create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, time)
	tw.tween_callback(layer.queue_free)


# ---------- 3. TRAP / GROUND CONTROL ----------

func get_trap_variant() -> TrapVariant:
	var ball: Ball = _get_ball()
	if ball == null or is_down:
		return TrapVariant.NONE
	if get_kick_type(ball) == KickType.NONE:
		return TrapVariant.TRAP if not ball.is_held() else TrapVariant.NONE
	if ball.get_level() == Heights.Level.GROUND:
		return TrapVariant.GROUND_CONTROL
	return TrapVariant.NONE


func _use_trap_skill() -> bool:
	match get_trap_variant():
		TrapVariant.TRAP:
			return await _use_trap()
		TrapVariant.GROUND_CONTROL:
			return await _use_ground_control()
	return false


## Trap: avanço de 170; se a bola estiver a 170 no fim, vai até ela (no nível dela) e faz um QTE fácil
func _use_trap() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or get_trap_variant() != TrapVariant.TRAP:
		return false
	var dir: Vector2 = await m.aim_for_skill(self, trap_dash_range)
	if dir == Vector2.ZERO:
		return false
	dir = dir.normalized()
	face_towards(dir)
	if not await play_action(&"trap", ANIM_JUMP):
		return false

	m.clear_pending_pass()
	NagiFX.puff(self, 6)
	await _dash(global_position + dir * trap_dash_range, trap_dash_time)

	var ball: Ball = _get_ball()
	if ball != null and not ball.is_held() and not ball.is_locked_for(team) \
			and global_position.distance_to(ball.global_position) <= trap_ball_range:
		await _trap_fetch(m, ball)
	start_cooldown(CD_TRAP, trap_cooldown)
	_last_skill = &"trap"
	return true


## Vai até a bola no nível em que ela está (saltando se precisar) e faz o QTE fácil
func _trap_fetch(m: MatchManager, ball: Ball) -> void:
	var level: Heights.Level = ball.get_level()
	var to_ball: Vector2 = ball.global_position - global_position
	var dir: Vector2 = to_ball.normalized() if to_ball.length() > 1.0 else Vector2(facing, 0.0)
	var stop_at: Vector2 = global_position
	if to_ball.length() > trap_stop_distance:
		stop_at = ball.global_position - dir * trap_stop_distance
	face_towards(dir)
	height_level = level
	var leap: Tween = create_tween().set_parallel(true)
	leap.tween_property(self, "global_position", stop_at, trap_leap_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	leap.tween_property(self, "height", Heights.to_height(level), trap_leap_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await leap.finished
	if not await _easy_qte(m):
		return
	ball = _get_ball()
	if ball == null:
		return
	# Domina: a bola para e fica pairando do lado dele, e ele ganha uma ação de habilidade
	var hold: Tween = ball.hover_to(ball.global_position, Heights.to_height(ball.get_level()), 0.15)
	await hold.finished
	ball.register_touch(self)
	_ball_aura(ball, soft_fx, 0.5)
	NagiFX.ring(self, global_position, 36.0, 10)
	_grant_temp_extra(control_extra_skills)
	_say("TRAP!")


## Ground Control: passe suspenso, correr de 1 s, salto, o aliado devolve a bola e QTE fácil
func _use_ground_control() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or get_trap_variant() != TrapVariant.GROUND_CONTROL:
		return false
	var ally: Player = await m.pick_ally_for_skill(self, control_pass_range)
	if ally == null:
		return false   # cancelou: não gasta a ação
	var ball: Ball = _get_ball()
	if ball == null or get_trap_variant() != TrapVariant.GROUND_CONTROL:
		return false
	face_towards(ally.global_position - global_position)
	if not await play_action(&"ground_control", ANIM_PASS_HIGH):
		return false
	ball = _get_ball()
	if ball == null:
		return false

	m.clear_pending_pass()
	ball.register_touch(self)
	NagiFX.puff(self, 6)
	# Passe SUSPENSO para o aliado
	ball.hover_to(ally.global_position + Vector2(0.0, 0.0), Heights.SUSPENDED_HEIGHT, control_pass_time)
	_ball_aura(ball, soft_fx, control_pass_time + 0.2)
	# Nagi ganha um correr de 1 segundo (não conta no limite de Correr do turno)
	start_run()
	run_time_left = control_run_time
	_run_total = maxf(control_run_time, 0.001)
	runs_this_turn = maxi(runs_this_turn - 1, 0)
	await run_finished
	# Salta no fim da corrida
	await _go_to_level(Heights.Level.SUSPENDED, control_jump_time)
	if not is_instance_valid(ally):
		return false
	# O aliado devolve a bola ao Nagi
	ball = _get_ball()
	if ball == null:
		return false
	ball.hover_to(ally.global_position, Heights.SUSPENDED_HEIGHT, 0.05)
	var back: Tween = ball.hover_to(global_position + Vector2(facing * ball_side_distance, 0.0),
		Heights.SUSPENDED_HEIGHT, control_return_time)
	await back.finished
	ball.register_touch(self)
	if await _easy_qte(m):
		_grant_temp_extra(control_extra_skills)
		NagiFX.ring(self, global_position, 36.0, 10)
		_say("CONTROL!")
	start_cooldown(CD_TRAP, trap_cooldown)
	_last_skill = &"ground_control"
	return true


# ---------- 4. HEAVY / JUMPING TURN / BICYCLE / CURIOSITY ----------

## Nagi na área do goleiro E na lateral dela (Curiosity)
func _in_curiosity_spot() -> bool:
	var f: Field = get_tree().get_first_node_in_group("field") as Field
	if f == null:
		return false
	var local: Vector2 = f.to_local(global_position)
	var teams: Array[int] = []
	if curiosity_enemy_area:
		var count: int = 2
		var m: MatchManager = _get_manager()
		if m != null:
			count = m.team_count
		for t in count:
			if t != team:
				teams.append(t)
	else:
		teams.append(team)
	for t in teams:
		var rect: Rect2 = f.get_penalty_area_rect(t)
		if rect.has_point(local):
			var side: float = absf(local.y - rect.get_center().y)
			if side >= rect.size.y * 0.5 * curiosity_side_fraction:
				return true
	return false


func get_heavy_variant() -> HeavyVariant:
	var ball: Ball = _get_ball()
	if ball == null or is_down or get_kick_type(ball) == KickType.NONE:
		return HeavyVariant.NONE
	var level: Heights.Level = ball.get_level()
	if height_level == Heights.Level.FLYING:
		return HeavyVariant.NONE
	# Bola voando e Nagi suspenso: bicicleta (Curiosity na área do goleiro, na lateral)
	if height_level == Heights.Level.SUSPENDED and level == Heights.Level.FLYING:
		return HeavyVariant.CURIOSITY if _in_curiosity_spot() else HeavyVariant.BICYCLE
	if level == Heights.Level.FLYING:
		return HeavyVariant.NONE
	# A última habilidade foi o Trap: Jumping Turn
	if _last_skill == &"trap":
		return HeavyVariant.JUMPING_TURN
	return HeavyVariant.HEAVY


func _use_heavy_skill() -> bool:
	var m: MatchManager = _get_manager()
	var variant: HeavyVariant = get_heavy_variant()
	if m == null or variant == HeavyVariant.NONE:
		return false

	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação

	# A situação pode ter mudado enquanto ele mirava: confere de novo
	var ball: Ball = _get_ball()
	variant = get_heavy_variant()
	if ball == null or variant == HeavyVariant.NONE:
		return false
	var kind: KickType = get_kick_type(ball)
	if kind == KickType.NONE:
		return false

	var force: float = heavy_force
	var chance: float = heavy_chance
	var fx: KickFX = heavy_fx
	var anim: StringName = _anim_or(&"heavy", ANIM_FLYING_KICK if kind == KickType.FLYING else ANIM_VOLLEY)
	var rise: float = heavy_rise_point
	var spin_turns: float = 0.0
	var spin_time: float = 0.0
	match variant:
		HeavyVariant.JUMPING_TURN:
			force = jumping_force
			chance = jumping_chance
			rise = 0.0
			anim = _anim_or(&"jumping_turn", ANIM_VOLLEY)
			spin_turns = 1.0
			spin_time = jumping_spin_time
		HeavyVariant.BICYCLE, HeavyVariant.CURIOSITY:
			force = bicycle_force
			chance = curiosity_chance if variant == HeavyVariant.CURIOSITY else bicycle_chance
			fx = bicycle_fx
			rise = 0.0
			anim = _anim_or(&"curiosity" if variant == HeavyVariant.CURIOSITY else &"bicycle", ANIM_FLYING_KICK)
			spin_turns = 1.0
			spin_time = bicycle_spin_time

	var qte_ok: bool = true
	if kicks_use_qte and kind != KickType.GROUND and not skips_qte():
		qte_ok = await m.run_qte(kind)

	# Jumping Turn: toque curto para o lado, sobe a bola e o Nagi (suspenso), e só então gira e chuta
	if variant == HeavyVariant.JUMPING_TURN:
		await _jumping_prelude(ball, aim)
		ball = _get_ball()
		if ball == null:
			return false
		kind = KickType.VOLLEY

	if spin_turns > 0.0:
		_spin(spin_turns, spin_time)
	NagiFX.puff(self, 6)
	if rise > 0.0 and kick_spin_enabled:
		pending_spin_point = Vector2(0.0, rise)   # o ponto de baixo da bola: ela SOBE na trajetória
	var touches_before: int = ball.interaction_count
	next_kick_force_mult = force
	await kick_ball(ball, aim, kind, qte_ok, chance, false, fx if qte_ok else null, anim)
	pending_spin_point = Vector2.ZERO
	if spin_turns > 0.0:
		_reset_spin()
	if is_instance_valid(ball) and ball.interaction_count == touches_before:
		return false   # a ação foi cancelada antes do chute (ex: a partida reiniciou)

	start_cooldown(CD_HEAVY, heavy_cooldown)
	match variant:
		HeavyVariant.JUMPING_TURN:
			_last_skill = &"jumping"
		HeavyVariant.BICYCLE:
			_last_skill = &"bicycle"
		HeavyVariant.CURIOSITY:
			_last_skill = &"curiosity"
		_:
			_last_skill = &"heavy"
	return true


## Jumping Turn: toque curto para o lado, a bola sobe e o Nagi salta (suspensos) antes do giro e do chute
func _jumping_prelude(ball: Ball, aim: Vector2) -> void:
	var side: Vector2 = aim.normalized().rotated(PI * 0.5)
	if side.x * facing < 0.0:
		side = -side
	ball.register_touch(self)
	var spot: Vector2 = global_position + side * jumping_tap_distance
	height_level = Heights.Level.SUSPENDED
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(self, "height", Heights.SUSPENDED_HEIGHT, jumping_tap_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ball.hover_to(spot, Heights.SUSPENDED_HEIGHT, jumping_tap_time)
	await tw.finished
	_ball_aura(ball, soft_fx, 0.4)


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []

	var heel_name: String
	match get_heel_variant():
		HeelVariant.DISTORTION:
			heel_name = "Distortion" if _distortion_is_followup() else skill_label("Distortion", CD_HEEL)
		HeelVariant.ZERO_RESET:
			heel_name = skill_label("Zero Reset Turn", CD_HEEL)
		_:
			heel_name = skill_label("Direct Heel Lift", CD_HEEL)
	list.append({"id": SKILL_HEEL, "name": heel_name})

	# Reação Química Miracle: com as condições cumpridas, o botão vira Five Stage Volley
	var fake_name: String = "Five Stage Volley" if _miracle_available() != null else "Fake Volley"
	if _dom_active:
		fake_name += " (domínio)"
	list.append({"id": SKILL_FAKE, "name": skill_label(fake_name, CD_FAKE)})

	var trap_name: String = "Ground Control" if get_trap_variant() == TrapVariant.GROUND_CONTROL else "Trap"
	list.append({"id": SKILL_TRAP, "name": skill_label(trap_name, CD_TRAP)})

	var heavy_name: String
	match get_heavy_variant():
		HeavyVariant.JUMPING_TURN:
			heavy_name = "Jumping Turn"
		HeavyVariant.BICYCLE:
			heavy_name = "Bicycle"
		HeavyVariant.CURIOSITY:
			heavy_name = "Curiosity"
		_:
			heavy_name = "Heavy"
	list.append({"id": SKILL_HEAVY, "name": skill_label(heavy_name, CD_HEAVY)})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_HEEL:
			var variant: HeelVariant = get_heel_variant()
			if variant == HeelVariant.NONE:
				return false
			if variant == HeelVariant.DISTORTION and _heel_followup:
				return true   # complemento: ignora a recarga que o Direct Heel Lift acabou de começar
			return not is_on_cooldown(CD_HEEL)
		SKILL_FAKE:
			return get_fake_variant() != FakeVariant.NONE and not is_on_cooldown(CD_FAKE)
		SKILL_TRAP:
			return get_trap_variant() != TrapVariant.NONE and not is_on_cooldown(CD_TRAP)
		SKILL_HEAVY:
			return get_heavy_variant() != HeavyVariant.NONE and not is_on_cooldown(CD_HEAVY)
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	# Usar outra habilidade depois do Direct Heel Lift desfaz o "Distortion grátis" (só vale logo depois)
	if skill_id != SKILL_HEEL:
		_heel_followup = false
	match skill_id:
		SKILL_HEEL:
			return await _use_heel_skill()
		SKILL_FAKE:
			return await _use_fake_skill()
		SKILL_TRAP:
			return await _use_trap_skill()
		SKILL_HEAVY:
			return await _use_heavy_skill()
	return false


## O Distortion não gasta ação de habilidade quando é o complemento do Direct Heel Lift
func skill_is_free(skill_id: StringName) -> bool:
	return skill_id == SKILL_HEEL and _distortion_is_followup()


## Sobrou o Distortion de graça? Então o turno não acaba sozinho quando as ações acabam
func has_free_followup() -> bool:
	return _distortion_is_followup()


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	var key: String = String(skill_id)
	match skill_id:
		SKILL_HEEL:
			match get_heel_variant():
				HeelVariant.DISTORTION:
					title = "Distortion"
					key = "distortion"
					text = "Nagi chuta a bola no chão, na diagonal; ela volta suspensa e ele a busca, os dois suspensos. De graça logo depois do Direct Heel Lift."
				HeelVariant.ZERO_RESET:
					title = "Zero Reset Turn"
					key = "zero_reset_turn"
					text = ("Domina a bola e dá dois avanços: %d para longe do inimigo mais próximo e %d direcionável. "
						+ "Se achar um inimigo no 2º, QTE fácil e, ganhando, chapéu, salto e +%d ação de habilidade.") \
						% [int(zero_first_range), int(zero_second_range), zero_extra_skills]
				_:
					title = "Direct Heel Lift"
					text = ("Sem bola por perto: avanço de %d. Se encontrar a bola no chão, QTE fácil e, ganhando, "
						+ "salta com ela na diagonal até voando e libera o Distortion.") % int(heel_dash_range)
			text += "\nRecarga: %d rodadas (compartilhada)." % heel_cooldown
		SKILL_FAKE:
			if _miracle_available() != null:
				var miracle: ChemicalReaction = _miracle_available()
				title = "Five Stage Volley"
				key = "five_stage_volley"
				text = ("Reação Química Miracle com o Reo: cutscene, cinco etapas do Fake Volley (o Nagi anda e gira suspenso, a caveira cresce) e, na última, um chute fortíssimo com %d%% de chance de gol.\n"
					+ "Recarga do Fake Volley: %d rodadas. Recarga da reação: %d rodadas.") % [_pct(five_chance), fake_cooldown, miracle.cooldown_rounds]
			else:
				title = "Fake Volley"
				text = ("Finta o chute, atordoa o inimigo mais próximo e avança %d trazendo a bola. Depois domina a bola durante o turno inimigo: "
					+ "ação geral = atordoado; habilidade = typing game (perdeu, o Nagi desvia). Com %d erros, o Juggling Shot chuta sozinho para o gol (%.1fx, %d%%).\n"
					+ "Recarga: %d rodadas.") % [int(fake_dash_range), juggling_fails_needed, juggling_force, _pct(juggling_chance), fake_cooldown]
		SKILL_TRAP:
			if get_trap_variant() == TrapVariant.GROUND_CONTROL:
				title = "Ground Control"
				key = "ground_control"
				text = ("Passe suspenso para um aliado (alcance %d), correr de %.0f s, salto, o aliado devolve a bola e um QTE fácil dá +%d ação de habilidade.") \
					% [int(control_pass_range), control_run_time, control_extra_skills]
			else:
				title = "Trap"
				text = ("Sem bola por perto: avanço de %d. Se a bola estiver a %d no fim, vai até ela no nível dela (saltando se precisar) e um QTE fácil dá +%d ação de habilidade.") \
					% [int(trap_dash_range), int(trap_ball_range), control_extra_skills]
			text += "\nRecarga: %d rodadas (compartilhada)." % trap_cooldown
		SKILL_HEAVY:
			match get_heavy_variant():
				HeavyVariant.JUMPING_TURN:
					title = "Jumping Turn"
					key = "jumping_turn"
					text = "Depois do Trap: toque curto para o lado, sobe a bola, gira e chuta (%.1fx, %d%% de chance)." % [jumping_force, _pct(jumping_chance)]
				HeavyVariant.BICYCLE:
					title = "Bicycle"
					key = "bicycle"
					text = "Bicicleta giratória com a bola voando (%.1fx, %d%% de chance)." % [bicycle_force, _pct(bicycle_chance)]
				HeavyVariant.CURIOSITY:
					title = "Curiosity"
					key = "curiosity"
					text = "A bicicleta na área do goleiro, na lateral: %d%% de chance." % _pct(curiosity_chance)
				_:
					title = "Heavy"
					text = "Chute %.1fx em que a bola sobe durante a trajetória. %d%% de chance de gol." % [heavy_force, _pct(heavy_chance)]
			text += "\nRecarga: %d rodadas (compartilhada)." % heavy_cooldown
		_:
			return {}
	var icon: Texture2D = skill_icons.get(key, skill_icons.get(StringName(key), skill_icons.get(String(skill_id)))) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()   # zera também extra_skill_left e as recargas
	_heel_followup = false
	_last_skill = &""
	_temp_extras = 0
	_end_dominance()
	_dodges = 0
	_text_alpha = 0.0
	_stop_aura()
	_reset_spin()
	queue_redraw()


# ---------- LOOP ----------

func _process(delta: float) -> void:
	super(delta)
	_check_dominance()
	if _dom_active:
		queue_redraw()   # os anéis em volta da bola pulsam
	if _aura != null:
		_aura.position = Vector2(0.0, -height - 4.0)


# ---------- VISUAL ----------

## Anel de caveirinhas em volta dele (as ativações)
func _pulse(_duration: float = 0.45) -> void:
	NagiFX.ring(self, global_position, 30.0, 10)


## Texto curto que sobe e some em cima do Nagi
func _say(text: String) -> void:
	_text = text
	if _text_tween and _text_tween.is_valid():
		_text_tween.kill()
	_text_alpha = 1.0
	_text_tween = create_tween()
	_text_tween.tween_interval(0.5)
	_text_tween.tween_property(self, "_text_alpha", 0.0, 0.5)


## Caveira grande que sai dele (tamanho e opacidade dados). Usada pelo Five Stage Volley
func _show_skull(size_mult: float = 1.0, duration: float = 1.3, alpha: float = 0.6) -> void:
	NagiFX.skull(self, size_mult, alpha, duration)


func _draw() -> void:
	super()

	# Domínio da bola: anéis claros pulsando em volta dela + fio até o Nagi
	if _dom_active:
		var ball: Ball = _get_ball()
		if ball != null and is_instance_valid(ball):
			var bp: Vector2 = to_local(ball.global_position)
			var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
			draw_line(Vector2.ZERO, bp, Color(0.85, 0.92, 1.0, 0.25), 1.5)
			draw_set_transform(bp, 0.0, Vector2(1.0, 0.5))   # achatado, como a sombra
			draw_arc(Vector2.ZERO, 24.0 + pulse * 3.0, 0.0, TAU, 40, Color(1, 1, 1, 0.85), 2.5)
			draw_arc(Vector2.ZERO, 34.0 + pulse * 5.0, 0.0, TAU, 40, Color(0.84, 0.78, 1.0, 0.6), 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Texto curto em cima dele
	if _text_alpha > 0.0:
		var tp := Vector2(-40.0, -height - placeholder_radius - 46.0 - (1.0 - _text_alpha) * 14.0)
		draw_string_outline(ThemeDB.fallback_font, tp, _text, HORIZONTAL_ALIGNMENT_CENTER,
			80.0, 16, 4, Color(0, 0, 0, _text_alpha * 0.8))
		draw_string(ThemeDB.fallback_font, tp, _text, HORIZONTAL_ALIGNMENT_CENTER,
			80.0, 16, Color(1, 1, 1, _text_alpha))
