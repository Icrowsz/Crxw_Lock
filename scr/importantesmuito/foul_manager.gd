class_name FoulManager
extends Node
## FALTAS E PÊNALTIS.
##
## COMO UMA FALTA ACONTECE
## - Um jogador do time que NÃO está jogando o turno cai por causa de uma ação do adversário (Carrinho ou
##   qualquer habilidade que chame knock_down()). Aí o juiz tem `whistle_chance` (50%) de apitar.
## - Quedas por erro do próprio jogador (errou o QTE do chute) NÃO contam: Player.knock_down_by_mistake().
##   Cair no turno do próprio time (ex: um contra-ataque que derruba quem deu o Carrinho) também não conta.
## - Se o jogador caído estava dentro da grande área de quem fez a falta, é PÊNALTI; senão, falta comum.
##
## O QUE ACONTECE DEPOIS DO APITO (a jogada para; as ações que sobravam do time que fez a falta se perdem)
##   1. Aviso grande "FALTA!" / "PÊNALTI!". A bola vai para o local da falta (ou para a marca do pênalti).
##   2. Tela de preparação (set_piece_screen.gd): o time que sofreu a falta escolhe o COBRADOR (clique num
##      jogador dele; começa com o que caiu) e ele vai até a bola. Os dois times podem ARRASTAR os próprios
##      jogadores para onde quiserem (no pênalti ninguém entra na grande área) e cada um confirma.
##   3. Turno da cobrança: o cobrador é o Protagonista e tem UMA ação, só Chutar ou Passe:
##        Cobrar (o Chutar, renomeado) = 1.5x mais forte (kick_force_mult), chance 45%, e é o ÚNICO chute que abre a
##        telinha de efeito (Kick Spin Picker);
##        Passe  = alcance maior (+50).
##   4. Acabou a ação: o turno do time que fez a falta termina normalmente e o jogo segue a ordem de sempre
##      (o time que sofreu a falta ainda joga o turno dele depois).
##
## Para desligar tudo: enabled = false (ou use_fouls no MatchManager).

signal whistled(kind: StringName, fouled_team: int, victim: Player)
## O juiz mandou seguir (caiu, mas não apitou)
signal played_on(victim: Player)
signal set_piece_started(kind: StringName, team: int, taker: Player)
signal set_piece_finished(kind: StringName, team: int)

const KIND_FOUL: StringName = &"foul"
const KIND_PENALTY: StringName = &"penalty"

enum State { IDLE, SETUP, TAKER_TURN }

@export var enabled: bool = true
## Chance de o juiz apitar quando alguém é derrubado por uma ação do adversário
@export_range(0.0, 1.0) var whistle_chance: float = 0.35

@export_group("Cobrança")
@export_range(0.0, 1.0) var foul_shot_chance: float = 0.45      # chance do Chutar da falta
@export_range(0.0, 1.0) var penalty_shot_chance: float = 0.45   # chance do Chutar do pênalti
@export var kick_force_mult: float = 2    # o "Cobrar" (Chutar da cobrança) é bem mais forte
@export var pass_range_bonus: float = 50.0   # o Passe da cobrança alcança mais (px)
## Distância do cobrador até a bola (px, no chão). A bola fica na "ponta" dele: o círculo dele encosta nela, sem sobrepor.
## Menor que isso a bola entra "por baixo" do cobrador; maior abre um vão entre os dois.
@export var taker_distance: float = 46.0
## O time que FEZ a falta não pode posicionar ninguém mais perto da bola/cobrador que isto (px). 0 = sem limite.
## Vale para falta e pênalti.
@export var opponent_min_distance: float = 300.0
## Ninguém pode ficar dentro do gol (entre as traves, na linha de fundo): folga em px em volta das traves
@export var goal_block_margin: float = 8.0

@export_group("Aviso")
@export var banner_time: float = 1.5

var manager: MatchManager
var state: State = State.IDLE
var kind: StringName = KIND_FOUL
var fouled_team: int = -1     # quem sofreu a falta (cobra)
var fouling_team: int = -1    # quem fez a falta (era o turno dele)
var spot: Vector2 = Vector2.ZERO   # onde a bola fica (global)
var taker: Player = null
var field: Field

var _pending: Dictionary = {}
var _watched: Dictionary = {}   # instance id -> true (jogadores já ligados ao sinal knocked_down)
var _taker_origin: Vector2 = Vector2.ZERO
var _saved: Dictionary = {}
var _motion: Dictionary = {}   # Player -> Tween (jogadores sendo levados para algum lugar)
var _screen: SetPieceScreen


func _ready() -> void:
	if manager == null:
		manager = get_tree().get_first_node_in_group("match_manager") as MatchManager
	if manager == null:
		push_warning("FoulManager: nenhum MatchManager encontrado; as faltas ficam desligadas.")
		enabled = false
		return
	_watch_all.call_deferred()   # o MatchManager e os jogadores entram na árvore no mesmo frame
	get_tree().node_added.connect(_on_node_added)


func _watch_all() -> void:
	for p: Player in get_tree().get_nodes_in_group("players"):
		_watch(p)


func _on_node_added(node: Node) -> void:
	if node is Player:
		_watch.call_deferred(node)   # jogadores criados depois (troca de formação, substituição)


func _watch(p: Player) -> void:
	if not is_instance_valid(p) or _watched.has(p.get_instance_id()):
		return
	_watched[p.get_instance_id()] = true
	p.knocked_down.connect(_on_knocked_down.bind(p))


# ---------- DETECÇÃO ----------

func _on_knocked_down(by_mistake: bool, p: Player) -> void:
	if not enabled or by_mistake or manager == null or manager.match_over or state != State.IDLE:
		return
	# Só vale queda no meio de uma ação (Carrinho, habilidade...) e de quem NÃO está jogando o turno
	if manager.phase != MatchManager.Phase.EXECUTING or p.team == manager.current_team:
		return
	if not _pending.is_empty():
		return   # uma falta por jogada
	if randf() >= whistle_chance:
		played_on.emit(p)
		SetPieceScreen.toast(self, "Segue o jogo!", UiStyle.MUTED_COLOR, 1.3)
		return
	_pending = {"victim": p, "pos": p.global_position, "fouling_team": manager.current_team}


## O juiz vai apitar quando a ação em andamento terminar
func has_pending() -> bool:
	return not _pending.is_empty() and is_instance_valid(_pending.get("victim"))


func clear_pending() -> void:
	_pending = {}


## true na vez do cobrador (é quando o Chutar vira "Cobrar" e abre a telinha de efeito)
func is_taking() -> bool:
	return state == State.TAKER_TURN


## true enquanto a falta está em andamento (preparação ou cobrança)
func is_active() -> bool:
	return state != State.IDLE


## Durante a cobrança só existem Chutar e Passe (o MatchManager pergunta aqui em can_use_general)
func allows_general(action: int) -> bool:
	if state != State.TAKER_TURN:
		return true
	return action == MatchManager.GeneralAction.SHOOT or action == MatchManager.GeneralAction.PASS


# ---------- APITO ----------

## Chamado pelo MatchManager quando a ação termina e has_pending(). Roda a falta inteira até a cobrança começar.
func start_foul() -> void:
	var info: Dictionary = _pending
	_pending = {}
	var victim: Player = info.get("victim") as Player
	field = get_tree().get_first_node_in_group("field") as Field
	if victim == null or not is_instance_valid(victim) or field == null or manager.match_over:
		manager._set_phase(MatchManager.Phase.CHOOSING_ACTION)   # nada a fazer: a jogada segue
		return

	state = State.SETUP
	fouled_team = victim.team
	fouling_team = int(info.get("fouling_team", manager.current_team))
	kind = KIND_PENALTY if field.is_in_penalty_area(info["pos"], fouling_team) else KIND_FOUL
	taker = null

	# A jogada para: ninguém age, nada fica pela metade
	manager._set_phase(MatchManager.Phase.SET_PIECE)
	manager._hide_pass_preview()
	manager.clear_pending_pass()
	manager._clear_roles()
	manager.protagonist = null
	manager.active_player = null
	whistled.emit(kind, fouled_team, victim)

	_screen = SetPieceScreen.new()
	_screen.foul = self
	_screen.manager = manager
	manager.add_child(_screen)
	await _screen.show_whistle()
	if manager.match_over:
		_abort()
		return

	# Bola no lugar, quem caiu levanta, pênalti organizado
	victim.get_up_now()
	spot = _penalty_spot(fouling_team) if kind == KIND_PENALTY else _clamp_to_pitch(info["pos"], 30.0)
	_place_ball(spot, true)
	if kind == KIND_PENALTY:
		_prepare_penalty()
	_choose_default_taker(victim)
	_enforce_rules_on_everyone()

	# Cada time organiza a jogada e confirma
	await _screen.run_setup()
	_screen = null
	if manager.match_over or taker == null or not is_instance_valid(taker):
		_abort()
		return
	_stop_all_motion()
	_place_ball(spot)   # recoloca na marca e volta a colidir: agora é só chutar
	_begin_taker_turn()


## Escolhe o cobrador (clique do jogador na tela de preparação). Devolve false se ele não pode (ex: proibido de
## ser Protagonista).
func set_taker(p: Player) -> bool:
	if p == null or p.team != fouled_team or p == taker or state != State.SETUP:
		return false
	if manager.is_protagonist_blocked(p):
		return false
	if taker != null and is_instance_valid(taker):
		_walk_to(taker, constrain_position(taker, _taker_origin), 0.45)   # o anterior volta de onde veio
	taker = p
	_taker_origin = p.global_position
	p.get_up_now()
	p.land()
	_walk_to(p, _taker_spot_for(p), 0.5)
	return true


func _choose_default_taker(victim: Player) -> void:
	if set_taker(victim):
		return
	# Quem caiu não pode cobrar: o companheiro mais perto da bola
	var best: Player = null
	for p in manager.get_team_players(fouled_team):
		if p == victim or manager.is_protagonist_blocked(p):
			continue
		if best == null or p.global_position.distance_to(spot) < best.global_position.distance_to(spot):
			best = p
	if best != null:
		set_taker(best)


func _taker_spot_for(p: Player) -> Vector2:
	var back: float = minf(taker_distance, p.kick_range * 0.7)   # sempre perto o bastante para chutar
	# O sprite da bola é desenhado ball_radius ACIMA do ponto dela no chão (Ball._update_visuals); o do jogador não.
	# Sobe o cobrador esse tanto para os dois ficarem na mesma linha, com a bola na ponta dele (de frente para o gol).
	# A bola continua exatamente na marca (spot): só o cobrador muda.
	var ball: Ball = manager._get_ball()
	var lift: float = ball.ball_radius if ball != null else 0.0
	return _clamp_to_pitch(spot - Vector2(p.get_attack_dir() * back, lift), 8.0)


# ---------- REGRAS DE POSICIONAMENTO ----------

## Onde um jogador PODE ficar quando arrastado até `pos` (global). A tela de preparação usa isto.
func constrain_position(p: Player, pos: Vector2) -> Vector2:
	var out: Vector2 = _clamp_to_pitch(pos, 14.0)
	if p == taker:
		return out
	var local: Vector2 = field.to_local(out)
	local = _push_out_of_goals(local)
	if kind == KIND_PENALTY:
		local = _push_out_of_area(local, fouling_team)
	if p.team == fouling_team and opponent_min_distance > 0.0:
		local = _push_from_taker(local)
	return _clamp_to_pitch(field.to_global(local), 14.0)


## Os adversários do cobrador ficam a pelo menos opponent_min_distance da bola (onde o cobrador está)
func _push_from_taker(local: Vector2) -> Vector2:
	var center: Vector2 = field.to_local(spot)
	var off: Vector2 = local - center
	if off.length() >= opponent_min_distance:
		return local
	var dir: Vector2 = off.normalized() if off.length() > 1.0 else (-center).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.LEFT
	var pushed: Vector2 = center + dir * opponent_min_distance
	# Se isso joga o ponto para fora do campo, empurra em direção ao meio do campo
	var half: Vector2 = field.pitch_size * 0.5 - Vector2(14.0, 14.0)
	if absf(pushed.x) > half.x or absf(pushed.y) > half.y:
		var back: Vector2 = (-center).normalized()
		if back == Vector2.ZERO:
			back = Vector2.LEFT
		pushed = center + back * opponent_min_distance
	return pushed


## Tira o ponto de dentro dos gols (a faixa entre as traves, na linha de fundo e atrás dela)
func _push_out_of_goals(local: Vector2) -> Vector2:
	var half_x: float = field.pitch_size.x * 0.5
	var half_goal: float = field.goal_width * 0.5 + goal_block_margin
	var depth: float = 34.0   # quanto "para dentro" do campo a boca do gol conta
	if absf(local.y) > half_goal or absf(local.x) < half_x - depth:
		return local
	var side: float = signf(local.x)
	return Vector2(side * (half_x - depth - 1.0), local.y)


func _enforce_rules_on_everyone() -> void:
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p == taker:
			continue
		var fixed: Vector2 = constrain_position(p, p.global_position)
		if fixed.distance_to(p.global_position) > 1.0:
			_walk_to(p, fixed, 0.5)


## Tira o ponto de dentro da grande área (pelo lado da frente ou pelas laterais; nunca pela linha de fundo)
func _push_out_of_area(local: Vector2, defending_team: int) -> Vector2:
	var margin: float = 16.0
	var rect: Rect2 = field.get_penalty_area_rect(defending_team).grow(margin)
	if not rect.has_point(local):
		return local
	var dir: float = float(_defend_dir(defending_team))
	var front_x: float = rect.position.x if dir > 0.0 else rect.end.x
	var options: Array[Vector2] = [
		Vector2(front_x, local.y),
		Vector2(local.x, rect.position.y),
		Vector2(local.x, rect.end.y),
	]
	var best: Vector2 = options[0]
	for o in options:
		if o.distance_to(local) < best.distance_to(local):
			best = o
	return best


## De que lado do campo (-1 esquerda / +1 direita) o time defende. Sai da própria grande área, então
## acompanha a troca de lado do 2º tempo.
func _defend_dir(team: int) -> int:
	return -1 if field.get_penalty_area_rect(team).get_center().x < 0.0 else 1


func _penalty_spot(defending_team: int) -> Vector2:
	var half: Vector2 = field.pitch_size * 0.5
	var d: float = float(_defend_dir(defending_team))
	return field.to_global(Vector2(d * half.x - d * field.penalty_spot_distance, 0.0))


func _clamp_to_pitch(global_pos: Vector2, margin: float) -> Vector2:
	var local: Vector2 = field.to_local(global_pos)
	var half: Vector2 = field.pitch_size * 0.5 - Vector2(margin, margin)
	return field.to_global(Vector2(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y)))


# ---------- BOLA E GOLEIRO ----------

## Põe a bola parada no chão, sem efeitos, sem ninguém segurando
func _place_ball(pos: Vector2, frozen: bool = false) -> void:
	var ball: Ball = manager._get_ball()
	if ball == null:
		return
	ball.release_hover()   # solta quem segura (goleiro) e acaba o voo pairando
	ball.stop_fx()
	ball.collisions_paused = frozen   # na preparação ninguém esbarra nela (o cobrador anda até ela)
	ball.global_position = pos
	ball.velocity = Vector2.ZERO
	ball.height = 0.0
	ball.vel_z = 0.0
	ball.pending_shot_chance = Ball.NO_SHOT


## Pênalti: o goleiro de quem fez a falta volta para a linha do gol
func _prepare_penalty() -> void:
	for k: Goalkeeper in get_tree().get_nodes_in_group("goalkeepers"):
		if k.team == fouling_team:
			k.refresh_side()   # cancela o que fazia e vai para o lugar dele


# ---------- MOVIMENTO ----------

func _walk_to(p: Player, target: Vector2, time: float) -> void:
	stop_motion(p)
	p.facing = p.get_attack_dir() if p == taker else p.facing
	var tw := p.create_tween()
	tw.tween_property(p, "global_position", target, time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion[p] = tw


## Para o movimento automático de um jogador (a tela chama quando o jogador começa a ser arrastado)
func stop_motion(p: Player) -> void:
	var tw: Tween = _motion.get(p)
	if tw != null and tw.is_valid():
		tw.kill()
	_motion.erase(p)


func _stop_all_motion() -> void:
	for p in _motion.keys():
		stop_motion(p)


# ---------- TURNO DA COBRANÇA ----------

func _begin_taker_turn() -> void:
	state = State.TAKER_TURN
	_saved = {
		"taker": taker,
		"pass_bonus": taker.pass_range_bonus,
		"chance": taker.shot_chance_default,
		"force": taker.next_kick_force_mult,
	}
	taker.pass_range_bonus += pass_range_bonus
	taker.shot_chance_default = penalty_shot_chance if kind == KIND_PENALTY else foul_shot_chance
	taker.next_kick_force_mult *= kick_force_mult
	taker.facing = taker.get_attack_dir()

	# O time que sofreu a falta joga: o cobrador vira Protagonista com UMA ação (Chutar ou Passe)
	manager.current_team = fouled_team
	manager._set_phase(MatchManager.Phase.CHOOSING_PROTAGONIST)
	manager.select_protagonist(taker)
	if manager.protagonist != taker:   # não deu para escolher o cobrador (ex: ficou proibido de ser Protagonista)
		on_turn_end()
		manager._end_turn()
		return
	manager.protagonist_general_left = 1
	manager.protagonist_skill_left = 0
	manager.secondary_general_left = 0
	manager.secondary_skill_left = 0
	manager.state_changed.emit()
	set_piece_started.emit(kind, fouled_team, taker)


## O MatchManager chama no começo de _end_turn(): fecha a cobrança e devolve o turno ao time que fez a falta
## (que simplesmente termina o turno dele), sem nenhuma outra mudança no fluxo.
func on_turn_end() -> void:
	_pending = {}
	if state != State.TAKER_TURN:
		return
	_rename_shoot_button(false)
	_restore_taker()
	manager.current_team = fouling_team
	state = State.IDLE
	set_piece_finished.emit(kind, fouled_team)


# ---------- NOME DO BOTÃO: Chutar -> Cobrar ----------

const SHOOT_NAME: String = "Chutar"
const TAKE_NAME: String = "Cobrar"
var _renamed: Array = []   # botões que mudamos (voltam ao nome normal no fim)


## Na cobrança o botão "Chutar" do menu de ações passa a se chamar "Cobrar" (e volta depois).
## Acha o botão pelo texto, então não precisa mexer no action_menu.gd.
func _rename_shoot_button(on: bool) -> void:
	if on:
		_collect_buttons(get_tree().root)
		return
	for b in _renamed:
		if is_instance_valid(b) and b.text == TAKE_NAME:
			b.text = SHOOT_NAME
	_renamed.clear()


func _collect_buttons(node: Node) -> void:
	for child in node.get_children():
		if child is Button and (child as Button).text == SHOOT_NAME and not _renamed.has(child):
			(child as Button).text = TAKE_NAME
			_renamed.append(child)
		_collect_buttons(child)


func _process(_delta: float) -> void:
	if state == State.TAKER_TURN:
		_rename_shoot_button(true)   # o menu pode recriar os botões a cada mudança de fase


func _restore_taker() -> void:
	var t: Player = _saved.get("taker") as Player
	if t != null and is_instance_valid(t):
		t.pass_range_bonus = float(_saved["pass_bonus"])
		t.shot_chance_default = float(_saved["chance"])
		t.next_kick_force_mult = float(_saved["force"])   # se ele passou, o bônus de força não fica guardado
	_saved = {}


## Partida acabou ou recomeçou no meio da falta: limpa tudo sem mexer no turno
func reset() -> void:
	_abort()


func _abort() -> void:
	_rename_shoot_button(false)
	_stop_all_motion()
	var b: Ball = manager._get_ball() if manager != null else null
	if b != null:
		b.collisions_paused = false
	_restore_taker()
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null
	_pending = {}
	state = State.IDLE
	taker = null
