class_name Goalkeeper
extends Node2D
## Goleiro autônomo: age sozinho, sem ser controlado pelo jogador.
##
## O Field cria um goleiro por time automaticamente (spawn_goalkeepers). Se preferir,
## coloque um nó com este script na cena e defina o "team": o Field não cria outro
## para esse time. Time 0 defende o gol da esquerda; time 1, o da direita.
##
## COMPORTAMENTO
## 1) Bola na grande área (qualquer altura, desde que ninguém a esteja segurando):
##    o goleiro se PREPARA por "prepare_rounds" rodadas (uma rodada = um ciclo completo de
##    turnos, ou seja, team_count turnos terminando). Se alguém interagir com a bola nesse
##    tempo (chute, passe, carrinho, empurrão...), o preparo recomeça.
##    Passado o tempo, o goleiro SALTA na bola e a segura.
## 2) Com a bola nas mãos, LANÇA a bola para um aliado aleatório de longo alcance assim que
##    começa o turno do PRÓPRIO time do goleiro (na rodada seguinte à defesa/agarrada).
##    A bola vai no nível VOANDO (jogadores adversários SUSPENSOS, que pularam, podem
##    interceptar) e, ao chegar no aliado, cai no CHÃO. Se um adversário interceptar, o time
##    dele ganha uma RODADA BÔNUS (veja o MatchManager) antes do turno de quem lançou seguir.
## 3) Chute em direção ao gol (ação Chutar, habilidade ou carrinho): ao entrar na área
##    acontece uma disputa de sorte. A chance de o chute vencer o goleiro vem do chute
##    (padrão 30%, voleio 35%, bola voando 40%). Se vencer, a bola segue; se perder, o
##    goleiro defende e fica com a bola (e entra no ciclo do item 2).
## 4) ACOMPANHA A BOLA: enquanto espera, o goleiro desliza pela boca do gol para o lado em que a bola
##    está, como se estivesse focado nela (e sai um pouco da linha quando ela chega perto, fechando o
##    ângulo). Um marcador na base dele aponta para a bola. Se a bola troca de lado rápido demais, ele
##    atrasa (track_speed).
## 5) DEFESA SITUACIONAL: a chance de o chute vencer o goleiro muda conforme onde ele vai (os valores
##    somam em pontos de porcentagem, antes das passivas dos goleiros especiais):
##      - PONTA CONTRÁRIA ao goleiro (longe dele, mais difícil de alcançar): +6%
##      - NO ÂNGULO (chute alto perto da trave): +4%
##      - GOLEIRO FORA DE POSIÇÃO (a bola trocou de lado e ele ainda está chegando): +5%
##      - À QUEIMA-ROUPA (bola muito perto da linha de fundo): +3%
##      - CHUTE NO MEIO, na mão do goleiro: -5%
##      - ÂNGULO FECHADO (ele saiu da linha): -3%
##    O aviso do chute lista os que valeram (ex: "ponta contrária +6%, no ângulo +4%").
##
## GOLEIROS ESPECIAIS (passivas)
## Cada time pode ter um estilo de goleiro. Os especiais estendem este script (veja bl_man.gd e
## renoir.gd) e mexem no comportamento por estes pontos:
##  - modify_shot_chance(): ajusta a chance de o chute vencer o goleiro, antes do sorteio
##  - area_extra_depth / area_extra_side: aumentam a área em que ele salta na bola
##  - throw_range: alcance do lançamento
##  - on_shot_resolved(beaten) / contest_note() / reset_for_new_match(): para passivas com
##    estado (Gagamaru)
##  - lets_player_pick_throw() / _ask_throw_target(): deixam o jogador escolher o alvo do
##    lançamento (Fukaku)
##  - art_texture: a imagem do goleiro em campo (veja KeeperRoster.ART_DIR)
##  - get_description(): texto curto e simples da passiva, mostrado na tela de formação
## Para criar um novo, registre-o no KeeperRoster (keeper_roster.gd).

enum State { IDLE, PREPARING, DIVING, HOLDING, THROWING }

## Time que o goleiro defende (0 = gol da esquerda, 1 = gol da direita)
@export var team: int = 0

## Qual goleiro é este (a tela de formação usa para trocar). Os especiais definem no _init.
var keeper_id: String = "base"
## Nome mostrado nos avisos da partida. Vazio = "Goleiro do <time>".
var display_name: String = ""

@export_group("Preparo e lançamento")
@export var prepare_rounds: int = 1           # rodadas de preparo (antes de saltar e antes de lançar)
@export var throw_range: float = 900.0         # alcance do lançamento (px)
@export var throw_speed: float = 1000.0        # velocidade da bola no ar (px/s)
@export var throw_rise_time: float = 0.2       # tempo para a bola subir ao nível Voando
@export var throw_land_time: float = 0.25      # tempo da queda ao chegar no aliado
@export var intercept_radius: float = 40.0     # adversário suspenso a esta distância intercepta

@export_group("Defesa")
@export var home_offset: float = 40.0          # distância da linha de fundo onde o goleiro fica
@export var dive_speed: float = 1100.0         # velocidade ao ir na bola (px/s)
@export var walk_speed: float = 220.0          # velocidade ao voltar para a posição
@export var catch_radius: float = 26.0         # a esta distância da bola o goleiro a segura
@export var max_dive_time: float = 1.5         # trava de segurança do salto
@export var hold_height: float = 24.0          # altura da bola nas mãos
@export var jump_height: float = 45.0          # altura do salto (visual)

@export_group("Acompanhar a bola (posicionamento)")
## O goleiro desliza pela boca do gol acompanhando a bola, como se estivesse focado nela
@export var track_ball: bool = true
@export var track_speed: float = 230.0          # velocidade lateral (px/s): bola trocando de lado rápido = ele atrasa
@export var track_far_gain: float = 0.12        # bola longe da linha de fundo: acompanha pouco (fração do y da bola)...
@export var track_near_gain: float = 0.6        # ...e bola perto: acompanha bastante
@export var track_near_distance: float = 300.0  # a esta distância (x) da linha de fundo vale o "near"
@export var track_far_distance: float = 1000.0  # a esta distância ou mais vale o "far"
@export var track_edge_margin: float = 26.0     # quanto ele para antes da trave (px)
@export var rush_depth: float = 36.0            # até onde ele sai da linha com a bola perto (fecha o ângulo)
@export var rush_start: float = 520.0           # a bola a menos desta distância da linha de fundo faz ele sair
@export var look_at_ball: bool = true           # marcador na base dele apontando para a bola

@export_group("Defesa situacional (chance do chute)")
## Ajustes na chance de o chute vencer o goleiro (somam em pontos de porcentagem)
@export var situation_mechanics: bool = true
@export var far_post_bonus: float = 0.06        # chute na ponta contrária ao goleiro (mais difícil de alcançar)
@export var far_post_reach: float = 0.28        # distância dele (fração da boca do gol) a partir da qual é a "ponta contrária"
@export var central_penalty: float = 0.05       # chute no meio, na mão dele: tira da chance
@export var central_zone: float = 0.10          # fração da boca do gol em volta dele que conta como "na mão"
@export var angle_bonus: float = 0.04           # chute alto no canto ("no ângulo")
@export var out_of_position_bonus: float = 0.05 # goleiro atrasado em relação à bola (ela trocou de lado)
@export var out_of_position_lag: float = 0.30   # atraso (fração da boca do gol) para contar
@export var point_blank_bonus: float = 0.03     # à queima-roupa: pouco tempo de reação
@export var point_blank_distance: float = 150.0 # distância da bola até a linha de fundo
@export var narrowed_angle_penalty: float = 0.03 # ele saiu da linha e fechou o ângulo: tira da chance

@export_group("Área de atuação")
## Quanto a área em que ele salta na bola cresce em direção ao meio do campo (px)
@export var area_extra_depth: float = 0.0
## Quanto ela cresce para os lados (px)
@export var area_extra_side: float = 0.0

@export_group("Balanço (visual)")
## Parado, o goleiro só inclina bem de leve (rotação; só visual, não muda a posição dele)
@export var sway_enabled: bool = true
@export var sway_degrees: float = 1.0
@export var sway_period: float = 3.6

@export_group("Time (visual)")
## Base do time no chão e marcador em cima da cabeça (identifica o time sem pintar a imagem)
@export var team_base_enabled: bool = true
@export var team_tag_enabled: bool = true

@export_group("Visual")
@export var body_radius: float = 20.0
@export var keeper_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## Imagem do goleiro em campo. Vazio = procura KeeperRoster.ART_DIR/<keeper_id>.png; sem
## arquivo, desenha o círculo placeholder.
@export var art_texture: Texture2D:
	set(value):
		art_texture = value
		queue_redraw()
## Altura da imagem em campo (px); a largura acompanha a proporção
@export var art_height: float = 64.0
## O desenho original olha para a direita? (o goleiro vira para encarar o campo)
@export var art_faces_right: bool = true

var state: State = State.IDLE:
	set(value):
		state = value
		queue_redraw()
var height: float = 0.0:
	set(value):
		height = value
		queue_redraw()

var field: Field
var ball: Ball
var manager: MatchManager

## Alcance mostrado enquanto o jogador escolhe para quem o goleiro lança (o MatchManager preenche)
var range_preview: float = 0.0:
	set(value):
		range_preview = value
		queue_redraw()
## true enquanto espera o jogador escolher o alvo do lançamento (o MatchManager não conta o
## tempo limite dos goleiros nesse intervalo)
var _waiting_for_player: bool = false

var _turns_left: int = 0
var _interaction_mark: int = 0
var _catch_forced: bool = false
var _dive_time: float = 0.0
var _token: int = 0                 # muda ao cancelar: corrotinas antigas se encerram
var _move_tween: Tween
var _jump_tween: Tween
var _look_angle: float = 0.0         # para onde ele olha (direção da bola); só visual
var _mods_text: String = ""          # (não aparece mais no aviso; sobrou para não quebrar goleiros especiais)


func _ready() -> void:
	add_to_group("goalkeepers")
	if art_texture == null:
		art_texture = KeeperRoster.art_for(keeper_id)
	_late_setup.call_deferred()  # espera Field, Ball e MatchManager existirem


func _late_setup() -> void:
	field = get_tree().get_first_node_in_group("field") as Field
	ball = get_tree().get_first_node_in_group("ball") as Ball
	manager = get_tree().get_first_node_in_group("match_manager") as MatchManager
	if field == null or ball == null:
		push_warning("Goalkeeper: Field ou Ball não encontrados; o goleiro não vai agir.")
		return

	global_position = _home_position()
	ball.was_reset.connect(_on_ball_reset)
	if manager:
		manager.turn_started.connect(_on_turn_started)
		manager.turn_ended.connect(_on_turn_ended)
		manager.match_ended.connect(_on_match_ended)
	else:
		push_warning("Goalkeeper: MatchManager não encontrado; o preparo por rodadas não vai andar.")


# ---------- API ----------

## O MatchManager espera o goleiro terminar antes de começar o próximo turno
func is_busy() -> bool:
	return state == State.DIVING or state == State.THROWING


## Está esperando o jogador escolher algo (o alvo do lançamento)? O MatchManager não conta o
## tempo limite dos goleiros enquanto isso.
func is_waiting_for_player() -> bool:
	return _waiting_for_player


## Texto curto e simples sobre o goleiro (passivas e diferenças), mostrado na tela de formação.
## Os especiais sobrescrevem e montam o texto com os valores dos próprios exports, assim ele
## nunca fica desatualizado.
func get_description() -> String:
	return "Goleiro padrão, sem passiva. Quando a bola entra na grande área, ele se prepara por %d rodada(s), salta e segura a bola; depois lança para um aliado sorteado (até %d px). Ele acompanha a bola pela boca do gol, e a chance dos chutes muda conforme o canto (ponta contrária ao goleiro +6%%, no ângulo, à queima-roupa...)." % [
		prepare_rounds, int(throw_range)]


## Volta ao estado de começo de partida (usado quando o jogo recomeça depois do fim de jogo)
func restart() -> void:
	if field == null or ball == null:
		return
	set_physics_process(true)   # o fim de jogo desliga o goleiro
	_cancel_all()
	reset_for_new_match()
	_turns_left = 0
	_catch_forced = false
	_interaction_mark = ball.interaction_count
	global_position = _home_position()


## Interrompe o que o goleiro está fazendo (e solta a bola, se estiver com ela)
func cancel_action() -> void:
	var had_ball: bool = ball != null and ball.held_by == self
	_cancel_all()
	if had_ball:
		ball.release_hover()


# ---------- LOOP ----------

func _physics_process(delta: float) -> void:
	if field == null or ball == null or (manager != null and manager.match_over):
		return
	z_index = int(global_position.y)

	match state:
		State.IDLE:
			_process_idle(delta)
		State.PREPARING:
			_process_preparing(delta)
		State.DIVING:
			_process_diving(delta)
		State.HOLDING:
			_process_holding(delta)
		State.THROWING:
			pass  # a corrotina _throw_ball controla a bola


var _sway_time: float = randf() * 10.0
var _sway_amount: float = 0.0
var _sway_dirty: bool = false
var _sway_rot: float = 0.0


## Balanço natural: só enquanto ele espera (parado, se preparando ou segurando a bola)
func _process(delta: float) -> void:
	if look_at_ball and ball != null:
		_look_angle = lerp_angle(_look_angle, (ball.global_position - global_position).angle(), minf(1.0, delta * 7.0))
		if not team_tag_enabled:
			queue_redraw()
	if team_tag_enabled:
		queue_redraw()   # a seta do time sobe e desce
	if not sway_enabled:
		return
	var calm: bool = state == State.IDLE or state == State.PREPARING or state == State.HOLDING
	_sway_amount = move_toward(_sway_amount, 1.0 if calm else 0.0, delta * 3.0)
	if _sway_amount <= 0.0 and not _sway_dirty:
		return
	_sway_time += delta
	var phase: float = _sway_time * TAU / maxf(sway_period, 0.1)
	_sway_rot = deg_to_rad(sway_degrees) * sin(phase) * _sway_amount
	_sway_dirty = _sway_amount > 0.0
	queue_redraw()


func _process_idle(delta: float) -> void:
	if _try_shot_contest():
		return
	_walk_home(delta)
	if _ball_in_area() and not ball.is_held():
		_begin_preparing()


func _process_preparing(delta: float) -> void:
	if _try_shot_contest():
		return
	_walk_home(delta)
	if not _ball_in_area() or ball.is_held():
		state = State.IDLE
		return
	# Alguém interagiu com a bola: o preparo recomeça do zero
	if ball.interaction_count != _interaction_mark:
		_begin_preparing()


func _process_diving(delta: float) -> void:
	_dive_time += delta
	if ball.is_held():
		state = State.IDLE  # outra pessoa (ou outro goleiro) pegou a bola
		return

	var target: Vector2 = ball.global_position
	global_position = global_position.move_toward(target, dive_speed * delta)

	var close: bool = global_position.distance_to(target) <= catch_radius
	# Defesa de um chute: a bola NUNCA passa do goleiro (ele a segura na linha)
	var passed: bool = _catch_forced and _ball_passed_line()
	var timeout: bool = _dive_time >= max_dive_time
	if close or passed or (_catch_forced and timeout):
		_catch_ball()
	elif timeout:
		state = State.IDLE  # não alcançou a bola


func _process_holding(delta: float) -> void:
	_walk_home(delta, false)  # volta para a posição base carregando a bola (sem acompanhar nada)
	if ball.held_by != self:
		_cancel_all()  # alguém tirou a bola
		return
	ball.global_position = global_position
	ball.height = hold_height + height


## Anda até a posição de espera. Com "track", ela acompanha a bola (veja _stance_local); sem, é a
## posição base de sempre.
func _walk_home(delta: float, track: bool = true) -> void:
	if _move_tween and _move_tween.is_valid():
		return
	if track and track_ball:
		global_position = global_position.move_toward(field.to_global(_stance_local()), track_speed * delta)
	else:
		global_position = global_position.move_toward(_home_position(), walk_speed * delta)


## Onde ele quer ficar agora (coordenadas do campo): na altura da bola, dentro da boca do gol.
## Bola longe = acompanha pouco; bola perto = acompanha bastante e ele sai um pouco da linha.
func _stance_local() -> Vector2:
	var home: Vector2 = _home_local()
	if not track_ball or ball == null:
		return home
	var dir: int = _dir()
	var gx: float = field.pitch_size.x * 0.5 * float(dir)
	var b: Vector2 = field.to_local(ball.global_position)
	var dx: float = maxf((gx - b.x) * float(dir), 0.0)   # distância da bola até a linha de fundo
	var near: float = 1.0 - smoothstep(track_near_distance, track_far_distance, dx)
	var gain: float = lerpf(track_far_gain, track_near_gain, near)
	var limit: float = field.goal_width * 0.5 - track_edge_margin
	var y: float = clampf(b.y * gain, -limit, limit)
	var out: float = rush_depth * (1.0 - smoothstep(0.0, rush_start, dx)) if dx < rush_start else 0.0
	return Vector2(home.x - float(dir) * out, y)


# ---------- PREPARO (conta turnos) ----------

func _begin_preparing() -> void:
	state = State.PREPARING
	_turns_left = _turns_needed()
	_interaction_mark = ball.interaction_count


func _turns_needed() -> int:
	var turns_per_round: int = manager.team_count if manager else 2
	return maxi(1, prepare_rounds) * turns_per_round

func _on_turn_ended(_ended_team: int) -> void:
	if state != State.PREPARING:
		return
	_turns_left -= 1
	if _turns_left > 0:
		return
	if _ball_in_area() and not ball.is_held():
		_start_catch(false)
	else:
		state = State.IDLE


## Começou o turno de um time: se o goleiro está com a bola e este é o time dele, lança agora
func _on_turn_started(started_team: int) -> void:
	if state == State.HOLDING and started_team == team:
		_throw_ball()


# ---------- DISPUTA DO CHUTE ----------

## GANCHO dos goleiros especiais: recebe a chance de o chute vencer o goleiro (0..1) e devolve
## a chance final. O padrão não mexe em nada. Roda uma vez por chute, antes do sorteio.
func modify_shot_chance(chance: float, _shot_ball: Ball) -> float:
	return chance


## GANCHO: o sorteio acabou. beaten = true se o chute venceu o goleiro; false = ele defendeu.
func on_shot_resolved(_beaten: bool) -> void:
	pass


## GANCHO antigo: texto extra no aviso do chute. O aviso agora mostra só a chance de marcar x a defesa, então este texto não aparece mais.
func contest_note() -> String:
	return ""


## GANCHO: zera o que for da partida anterior (o restart() chama). Quem tem estado sobrescreve.
func reset_for_new_match() -> void:
	pass


## Chute em direção ao gol que acabou de entrar na área: sorteia contra a chance do chute.
## Devolve true se a disputa aconteceu.
func _try_shot_contest() -> bool:
	if not ball.has_pending_shot() or ball.shot_team == team or ball.is_held():
		return false
	if not _ball_in_area() or not _shot_on_target():
		return false

	var base_chance: float = ball.pending_shot_chance
	ball.pending_shot_chance = Ball.NO_SHOT  # cada chute só é disputado uma vez
	# Situação do chute (ponta contrária, ângulo...); depois as passivas dos goleiros especiais
	var situational: float = base_chance
	for mod: Dictionary in _situation_mods(_predict_goal_crossing()):
		situational += float(mod["value"])
	var chance: float = clampf(modify_shot_chance(clampf(situational, 0.0, 1.0), ball), 0.0, 1.0)
	var beaten: bool = randf() < chance
	on_shot_resolved(beaten)
	if manager:
		manager.record_shot_on_target(ball.shot_team)   # estatística da tela final
	_announce_contest(base_chance, chance, beaten)

	if beaten:
		_dive_and_miss()
	else:
		_start_catch(true)
	return true


## Ajustes de situação na chance do chute (veja a documentação no topo): {"label", "value"}.
## crossing = (y no campo, altura) onde a bola cruzaria a linha de fundo.
func _situation_mods(crossing: Vector2) -> Array[Dictionary]:
	var mods: Array[Dictionary] = []
	if not situation_mechanics or not crossing.is_finite():
		return mods
	var mouth: float = field.goal_width
	var keeper: Vector2 = field.to_local(global_position)
	var shot_y: float = crossing.x
	var shot_h: float = crossing.y
	var reach: float = absf(shot_y - keeper.y)          # o quanto o goleiro precisa se esticar
	var top: float = field.crossbar_height - field.crossbar_thickness
	var half_mouth: float = mouth * 0.5 - field.post_radius - field.ball_hit_radius

	# Ponta contrária (longe dele: mais difícil de alcançar) ou no meio (na mão dele)
	if reach >= mouth * far_post_reach:
		mods.append({"label": "ponta contrária", "value": far_post_bonus})
	elif reach <= mouth * central_zone and shot_h < top * 0.8:
		mods.append({"label": "chute no meio", "value": -central_penalty})
	# Chute alto no canto ("no ângulo")
	if shot_h >= top * 0.7 and absf(shot_y) >= half_mouth * 0.65:
		mods.append({"label": "no ângulo", "value": angle_bonus})
	# Goleiro atrasado: a bola trocou de lado e ele ainda está chegando ao lugar certo
	if absf(_stance_local().y - keeper.y) >= mouth * out_of_position_lag:
		mods.append({"label": "goleiro fora de posição", "value": out_of_position_bonus})
	# À queima-roupa: pouco tempo de reação
	var to_line: float = absf(field.pitch_size.x * 0.5 * float(_dir()) - field.to_local(ball.global_position).x)
	if to_line <= point_blank_distance:
		mods.append({"label": "à queima-roupa", "value": point_blank_bonus})
	# Ele saiu da linha e fechou o ângulo
	if absf(keeper.x - _home_local().x) >= rush_depth * 0.6:
		mods.append({"label": "ângulo fechado", "value": -narrowed_angle_penalty})
	return mods


## A bola vai cruzar a linha de fundo dentro da boca do gol e abaixo do travessão?
## (mesma regra que o Field usa para dar o gol)
func _shot_on_target() -> bool:
	var crossing: Vector2 = _predict_goal_crossing()
	if not crossing.is_finite():
		return false
	var half_mouth: float = field.goal_width * 0.5 - field.post_radius - field.ball_hit_radius
	return absf(crossing.x) < half_mouth \
		and crossing.y < field.crossbar_height - field.crossbar_thickness


## (y no campo, altura) onde a bola cruzaria a linha de fundo; Vector2.INF se não vai para o gol
func _predict_goal_crossing() -> Vector2:
	var dir: int = _dir()
	var p: Vector2 = field.to_local(ball.global_position)
	var v: Vector2 = ball.velocity
	if v.length() < 40.0 or v.x * dir <= 0.0:
		return Vector2.INF
	var gx: float = field.pitch_size.x * 0.5 * dir
	var t: float = (gx - p.x) / v.x
	if t < 0.0:
		return Vector2.INF
	var y: float = p.y + v.y * t
	var h: float = ball.height + ball.vel_z * t - 0.5 * ball.gravity * t * t
	return Vector2(y, h)


## O chute venceu a disputa: o goleiro se joga na direção da bola, mas não alcança (só visual)
func _dive_and_miss() -> void:
	var crossing: Vector2 = _predict_goal_crossing()
	var here: Vector2 = field.to_local(global_position)
	var shot_y: float = crossing.x if crossing.is_finite() else here.y
	# Sai de onde ele está (acompanhando a bola) e vai bem na direção do chute, mas fica curto
	var miss_point: Vector2 = field.to_global(Vector2(here.x, lerpf(here.y, shot_y, 0.65)))

	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "global_position", miss_point, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_play_jump()


# ---------- SALTAR NA BOLA E SEGURAR ----------

func _start_catch(forced: bool) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	state = State.DIVING
	Sfx.play(&"keeper_dive")
	_catch_forced = forced
	_dive_time = 0.0


func _catch_ball() -> void:
	global_position = ball.global_position
	ball.clear_touches()  # a posse recomeça do zero: próximo toque é de quem receber
	ball.hold(self)
	state = State.HOLDING
	Sfx.play(&"keeper_catch")
	if manager:
		manager.record_keeper_catch(team, _catch_forced, _keeper_label())   # estatística da tela final
	_play_jump()
	if not _catch_forced:
		_say("%s saltou na bola!" % _keeper_label())


func _ball_passed_line() -> bool:
	var p: Vector2 = field.to_local(ball.global_position)
	return (p.x - _home_local().x) * _dir() > 0.0


# ---------- LANÇAMENTO ----------

## O jogador escolhe para quem o goleiro lança? (o padrão sorteia um aliado). Quem sobrescrever
## devolve true aqui e implementa _ask_throw_target().
func lets_player_pick_throw() -> bool:
	return false


## Pergunta ao jogador para quem lançar (só roda se lets_player_pick_throw()). null = cancelou,
## e aí o goleiro sorteia. O corpo do padrão só existe para a função ser uma corrotina.
func _ask_throw_target() -> Player:
	await get_tree().process_frame
	return null


func _throw_ball() -> void:
	state = State.THROWING  # antes de qualquer await: o MatchManager já vê o goleiro ocupado
	var token: int = _token

	var target: Player = null
	if lets_player_pick_throw():
		target = await _ask_throw_target()
		if not _throw_alive(token):
			return   # a partida acabou ou recomeçou enquanto o jogador escolhia
	if target == null:
		target = _pick_throw_target()
	if target == null:
		ball.release_hover()
		state = State.IDLE
		return
	_say("%s lança a bola!" % _keeper_label())

	var start: Vector2 = ball.global_position
	var duration: float = clampf(start.distance_to(_landing_point(target, start)) / throw_speed, 0.4, 2.0)
	ball.trail_enabled = true

	# Voo: a bola vai ao aliado no nível Voando
	var elapsed: float = 0.0
	while elapsed < duration:
		await get_tree().physics_frame
		if not _throw_alive(token):
			return
		elapsed += get_physics_process_delta_time()
		var t: float = clampf(elapsed / duration, 0.0, 1.0)
		ball.global_position = start.lerp(_landing_point(target, start), t)
		var rise: float = smoothstep(0.0, 1.0, clampf(elapsed / throw_rise_time, 0.0, 1.0))
		ball.height = lerpf(hold_height, Heights.FLYING_HEIGHT, rise)

		# Só intercepta quando já está no nível Voando
		if elapsed >= throw_rise_time:
			var hit: Player = _find_interceptor()
			if hit != null:
				_intercepted(hit)
				return

	# Chegou no alvo: cai no chão
	var fall: float = 0.0
	while fall < throw_land_time:
		await get_tree().physics_frame
		if not _throw_alive(token):
			return
		fall += get_physics_process_delta_time()
		var f: float = clampf(fall / throw_land_time, 0.0, 1.0)
		ball.height = lerpf(Heights.FLYING_HEIGHT, 0.0, f * f)

	ball.height = 0.0
	ball.release_hover()  # física volta: a bola fica no chão, parada
	state = State.IDLE


func _throw_alive(token: int) -> bool:
	if token != _token or ball.held_by != self:
		return false
	return manager == null or not manager.match_over


## A bola cai ENCOSTADA no aliado (do lado de onde veio), nunca em cima dele
func _landing_point(target: Player, from: Vector2) -> Vector2:
	var away: Vector2 = (from - target.global_position).normalized()
	return target.global_position + away * (ball.collision_radius + target.body_radius + 6.0)


## Aliado aleatório de longo alcance. Prefere quem está fora da área; se ninguém
## estiver ao alcance, lança para o aliado mais próximo.
func _pick_throw_target() -> Player:
	var allies: Array[Player] = []
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p.team == team:
			allies.append(p)
	if allies.is_empty():
		return null

	var in_range: Array[Player] = []
	var outside_area: Array[Player] = []
	for p in allies:
		if global_position.distance_to(p.global_position) > throw_range:
			continue
		in_range.append(p)
		if not _in_defense_area(p.global_position):
			outside_area.append(p)

	if not outside_area.is_empty():
		return outside_area.pick_random()
	if not in_range.is_empty():
		return in_range.pick_random()

	var nearest: Player = allies[0]
	for p in allies:
		if global_position.distance_to(p.global_position) < global_position.distance_to(nearest.global_position):
			nearest = p
	return nearest


## Adversário que pulou (nível Suspenso alcança o Voando) e está debaixo da bola
func _find_interceptor() -> Player:
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other.team == team or other.is_down:
			continue
		if not other.can_reach_level(Heights.Level.FLYING):
			continue
		if other.global_position.distance_to(ball.global_position) <= intercept_radius:
			return other
	return null


func _intercepted(by: Player) -> void:
	ball.release_hover()  # a gravidade volta: a bola cai onde foi interceptada
	ball.velocity = Vector2.ZERO
	ball.register_touch(by)
	if manager:
		manager.on_keeper_throw_intercepted(by)   # o time de quem interceptou ganha uma rodada bônus
	state = State.IDLE
	_say("%s interceptou o lançamento!" % by.get_display_name(), by.team)


# ---------- RESET / CANCELAR ----------

func _on_ball_reset() -> void:
	_cancel_all()
	global_position = _home_position()


## Troca de lado: o goleiro vai para o gol novo e vira para o campo
func refresh_side() -> void:
	_cancel_all()
	global_position = _home_position()
	queue_redraw()


func _on_match_ended(_winner: int) -> void:
	_cancel_all()
	set_physics_process(false)


func _cancel_all() -> void:
	_token += 1
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	if _jump_tween and _jump_tween.is_valid():
		_jump_tween.kill()
	height = 0.0
	state = State.IDLE


# ---------- UTIL ----------

## -1 = defende o gol da esquerda, +1 = o da direita (vem do Field: muda na troca de lado)
func _dir() -> int:
	if field != null:
		return field.defend_dir(team)
	return -1 if team == 0 else 1


func _home_local() -> Vector2:
	var dir: int = _dir()
	return Vector2(field.pitch_size.x * 0.5 * dir - dir * home_offset, 0.0)


func _home_position() -> Vector2:
	return field.to_global(_home_local())


## Grande área do time, aumentada pelo que o goleiro tiver de extra (Renoir). O lado da
## linha de fundo não cresce. Sem extras, é exatamente a grande área do Field.
func _defense_rect() -> Rect2:
	var rect: Rect2 = field.get_penalty_area_rect(team)
	if _dir() < 0:
		return rect.grow_individual(0.0, area_extra_side, area_extra_depth, area_extra_side)
	return rect.grow_individual(area_extra_depth, area_extra_side, 0.0, area_extra_side)


func _in_defense_area(global_pos: Vector2) -> bool:
	return _defense_rect().has_point(field.to_local(global_pos))


func _ball_in_area() -> bool:
	return _in_defense_area(ball.global_position)


func _play_jump() -> void:
	if _jump_tween and _jump_tween.is_valid():
		_jump_tween.kill()
	_jump_tween = create_tween()
	_jump_tween.tween_property(self, "height", jump_height, 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_jump_tween.tween_property(self, "height", 0.0, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## 0.08 -> 8 (para os textos)
func _pct(value: float) -> int:
	return int(round(value * 100.0))


func _team_name(t: int) -> String:
	return manager.get_team_name(t) if manager else "Time %d" % t


func _say(text: String, for_team: int = -1) -> void:
	if manager:
		manager.announce_keeper(text, team if for_team < 0 else for_team)


## "Goleiro do Azul" no padrão; "Renoir (Azul)" nos especiais
func _keeper_label() -> String:
	if display_name == "":
		return "Goleiro do %s" % _team_name(team)
	return "%s (%s)" % [display_name, _team_name(team)]


## Aviso do chute contra o goleiro: só a chance de marcar contra a defesa dele (já com tudo somado e
## subtraído), sem mostrar os ajustes um a um
func _announce_contest(_base_chance: float, chance: float, beaten: bool) -> void:
	var scoring: int = int(round(chance * 100.0))
	var versus: String = "Chance de marcar %d%% x Defesa do goleiro %d%%" % [scoring, 100 - scoring]
	if beaten:
		var shooter: int = ball.shot_team if ball.shot_team >= 0 else team
		_say("O chute passou pelo goleiro! %s" % versus, shooter)
	else:
		_say("DEFENDEU! %s pegou o chute. %s" % [_keeper_label(), versus])


# ---------- VISUAL (imagem do goleiro; sem imagem, um círculo placeholder) ----------

## Altura do "topo da cabeça" acima do chão (para barras e avisos em cima do goleiro)
func _visual_top() -> float:
	return art_height if art_texture != null else body_radius


func _draw() -> void:
	var team_color: Color = TeamStyle.color_of(team)
	if art_texture != null:
		_draw_art(team_color)
	else:
		_draw_placeholder(team_color)
	# Alcance do lançamento enquanto o jogador escolhe o alvo (Fukaku)
	if range_preview > 0.0:
		draw_arc(Vector2.ZERO, range_preview, 0.0, TAU, 96, Color(1, 1, 1, 0.4), 2.0)


## Marcador de "olhar" na base dele: um ponto branco que gira para a direção da bola
func _draw_gaze(radius: float) -> void:
	if not look_at_ball or state == State.HOLDING or ball == null:
		return
	var tip: Vector2 = Vector2.from_angle(_look_angle) * (radius + 3.0)
	draw_circle(tip, 5.5, Color(0, 0, 0, 0.5))
	draw_circle(tip, 3.8, Color(1, 1, 1, 0.95))


## Marcador do time em cima da cabeça: triângulo com contorno escuro
func _draw_team_tag(team_color: Color) -> void:
	if not team_tag_enabled:
		return
	# Seta do time: sobe e desce devagar (cada um num ritmo)
	var bob: float = sin(Time.get_ticks_msec() * 0.001 * 4.2 + float(get_instance_id() % 1000) * 0.0063) * 2.5
	var tip := Vector2(0.0, -_visual_top() - 12.0 - height + bob)
	draw_colored_polygon(PackedVector2Array([
			tip + Vector2(0.0, 3.0), tip + Vector2(-12.0, -15.0), tip + Vector2(12.0, -15.0)]),
			Color(0, 0, 0, 0.6))
	draw_colored_polygon(PackedVector2Array([
			tip, tip + Vector2(-9.0, -12.0), tip + Vector2(9.0, -12.0)]), team_color)


func _draw_placeholder(team_color: Color) -> void:
	draw_circle(Vector2.ZERO, body_radius, Color(0, 0, 0, 0.3))  # sombra no chão
	var center := Vector2(0, -height)
	draw_circle(center, body_radius, keeper_color)
	draw_arc(center, body_radius, 0.0, TAU, 32, team_color, 4.0)
	match state:
		State.PREPARING:
			draw_arc(center, body_radius + 6.0, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 2.0)
		State.HOLDING:
			draw_arc(center, body_radius + 6.0, 0.0, TAU, 32, Color(0.4, 0.9, 1.0, 0.9), 2.0)
	if look_at_ball and state != State.HOLDING and ball != null:   # o "olhar": um ponto na direção da bola
		draw_circle(center + Vector2.from_angle(_look_angle) * body_radius * 0.55, 3.5, Color(0.1, 0.1, 0.1, 0.9))


func _draw_art(team_color: Color) -> void:
	# No chão (achatados, como no Player): sombra, anel do time e anéis de estado
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, body_radius, Color(0, 0, 0, 0.3))
	if team_base_enabled:
		var base_r: float = body_radius + 7.0
		draw_circle(Vector2.ZERO, base_r, Color(team_color, 0.40))
		draw_arc(Vector2.ZERO, base_r, 0.0, TAU, 40, team_color.lightened(0.15), 4.0)
		draw_arc(Vector2.ZERO, base_r + 5.0, 0.0, TAU, 40, Color(team_color, 0.35), 2.0)
	else:
		draw_arc(Vector2.ZERO, body_radius + 2.0, 0.0, TAU, 32, Color(team_color, 0.9), 3.0)
	match state:
		State.PREPARING:
			draw_arc(Vector2.ZERO, body_radius + 8.0, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 2.0)
		State.HOLDING:
			draw_arc(Vector2.ZERO, body_radius + 8.0, 0.0, TAU, 32, Color(0.4, 0.9, 1.0, 0.9), 2.0)
	_draw_gaze(body_radius + 7.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# A imagem: pés no chão, sobe junto com o salto, virada para o campo
	var tex_size: Vector2 = art_texture.get_size()
	var h: float = art_height
	var w: float = h * tex_size.x / maxf(tex_size.y, 1.0)
	var flip: bool = (_dir() < 0) != art_faces_right   # quem defende a esquerda olha para a direita
	# Pés no chão: o balanço gira em volta dos pés
	draw_set_transform(Vector2.ZERO, _sway_rot, Vector2(-1.0, 1.0) if flip else Vector2.ONE)
	draw_texture_rect(art_texture, Rect2(-w * 0.5, -height - h, w, h), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_team_tag(team_color)
