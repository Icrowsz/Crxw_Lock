class_name FoulManager
extends Node
## FALTAS E PÊNALTIS.
##
## COMO UMA FALTA ACONTECE
## - SÓ O CARRINHO pode gerar falta: um jogador do time que NÃO está jogando o turno cai porque um adversário
##   deu Carrinho nele. Aí o juiz tem `whistle_chance` de apitar. Queda causada por HABILIDADE nunca é falta.
## - Quedas por erro do próprio jogador (errou o QTE do chute) NÃO contam: Player.knock_down_by_mistake().
##   Cair no turno do próprio time (ex: um contra-ataque que derruba quem deu o Carrinho) também não conta.
## - Se o jogador caído estava dentro da grande área de quem fez a falta, é PÊNALTI; senão, falta comum.
##
## O QUE ACONTECE DEPOIS DO APITO (a jogada para; as ações que sobravam do time que fez a falta se perdem)
##   1. Aviso grande "FALTA!" / "PÊNALTI!". A bola vai para o local da falta (ou para a marca do pênalti).
##   2. Tela de preparação (set_piece_screen.gd): o time que sofreu a falta escolhe o COBRADOR (clique num
##      jogador dele; começa com o que caiu) e ele vai até a bola. Os dois times podem ARRASTAR os próprios
##      jogadores para onde quiserem (no pênalti ninguém entra na grande área) e cada um confirma.
##   3. Turno da cobrança: o cobrador é o Protagonista e o time que sofreu a falta joga um turno com as MESMAS
##      ações de um turno comum (as do MatchManager: protagonist_*/secondary_*, então acompanham o modo de jogo,
##      como o Futebol Medonho). Todas as ações valem para o cobrador (Correr, Pular, Carrinho, habilidades...).
##      Cobrar (o Chutar, renomeado) = mais forte (kick_force_mult), chance 45%, e é o ÚNICO chute que abre a
##      telinha de efeito (Kick Spin Picker). Passe = alcance maior (+50). O bônus vale para a PRIMEIRA bola que o
##      cobrador bater (o MatchManager avisa por note_kick()).
##      Os secundários só podem Chutar/Passar DEPOIS da cobrança (quem bate primeiro é o cobrador); o resto vale antes.
##      No lateral o cobrador não pode Chutar (só Passar).
##   4. Acabou o turno da cobrança: a vez vai para o time que FEZ a falta (ele recomeça o turno dele, com ações novas,
##      como na rodada bônus) e depois o jogo segue a ordem de sempre. O time que cobrou NÃO joga de novo em seguida.
##
## LATERAL E ESCANTEIO (mesma tela de preparação e mesmo turno de cobrança da falta)
## - Quando a bola cruza uma linha (Field.ball_left_pitch), quem cobra é o time ADVERSÁRIO de quem tocou nela por último.
##   Linha lateral = lateral; linha de fundo tocada por quem defende aquele gol = escanteio. (Linha de fundo tocada por
##   quem ataca seria tiro de meta: ainda não existe, a bola quica como antes.)
## - A bola fica parada na linha até o turno poder ser interrompido (fim da ação em andamento).
## - O TURNO EM ANDAMENTO É PULADO: se era o do time que tirou a bola, ele conta como jogado e a vez vai para quem cobra;
##   se era o do próprio time cobrador, o turno dele vira a cobrança. O turno da cobrança conta como o turno do time e,
##   depois dele, a ordem segue normal (não há turno bônus como na falta).
## - Cobrador, preparação e regra de posicionamento são os da falta: o time que tirou a bola não fica a menos de
##   opponent_min_distance do cobrador. Lateral: o cobrador só pode PASSAR. Escanteio: Cobrar (chute) ou Passe.
## - Desligar só isto: out_enabled = false (ou use_out_of_play no MatchManager).

## Para desligar tudo: enabled = false (ou use_fouls no MatchManager).

signal whistled(kind: StringName, fouled_team: int, victim: Player)
## O juiz mandou seguir (caiu, mas não apitou)
signal played_on(victim: Player)
signal set_piece_started(kind: StringName, team: int, taker: Player)
signal set_piece_finished(kind: StringName, team: int)

const KIND_FOUL: StringName = &"foul"
const KIND_PENALTY: StringName = &"penalty"
const KIND_THROW_IN: StringName = &"throw_in"   # lateral
const KIND_CORNER: StringName = &"corner"       # escanteio

enum State { IDLE, SETUP, TAKER_TURN }

@export var enabled: bool = true
## Chance de o juiz apitar quando alguém é derrubado por uma ação do adversário
@export_range(0.0, 1.0) var whistle_chance: float = 0.4

@export_group("Cobrança")
@export_range(0.0, 1.0) var foul_shot_chance: float = 0.45      # chance do Chutar da falta
@export_range(0.0, 1.0) var penalty_shot_chance: float = 0.45   # chance do Chutar do pênalti
@export var kick_force_mult: float = 2    # o "Cobrar" (Chutar da cobrança) é bem mais forte
@export var pass_range_bonus: float = 50.0   # o Passe da cobrança alcança mais (px)
## (O número de ações do turno da cobrança é o do turno comum: vem do MatchManager, veja _begin_taker_turn.)
## Distância do cobrador até a bola (px, no chão). A bola fica na "ponta" dele: o círculo dele encosta nela, sem sobrepor.
## Menor que isso a bola entra "por baixo" do cobrador; maior abre um vão entre os dois.
@export var taker_distance: float = 46.0
## O time que FEZ a falta não pode posicionar ninguém mais perto da bola/cobrador que isto (px). 0 = sem limite.
## Vale para falta e pênalti.
@export var opponent_min_distance: float = 300.0
## Ninguém pode ficar dentro do gol (entre as traves, na linha de fundo): folga em px em volta das traves
@export var goal_block_margin: float = 8.0

@export_group("Lateral e escanteio")
## Liga o lateral e o escanteio (independe de enabled, que liga as faltas)
@export var out_enabled: bool = true
## Chance do Cobrar (chute direto) do escanteio
@export_range(0.0, 1.0) var corner_shot_chance: float = 0.3
## O Passe do lateral alcança mais (px). O do escanteio usa pass_range_bonus (o da falta).
@export var throw_in_pass_range_bonus: float = 30.0
## O lateral é cobrado a pelo menos isto (px) das pontas da linha lateral (perto demais seria quase escanteio)
@export var throw_in_corner_margin: float = 40.0

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
var _kick_done: bool = false   # o cobrador já usou a ação geral dele (a cobrança)
var _scan_wait: float = 0.0    # intervalo entre as buscas do botão "Chutar"
var _out: Dictionary = {}      # lateral/escanteio esperando a jogada poder parar (kind, spot, taking_team, sender_team)
var _cuts: int = 0             # quantos turnos já foram pulados para chegar ao time cobrador (trava de segurança)


func _ready() -> void:
	if manager == null:
		manager = get_tree().get_first_node_in_group("match_manager") as MatchManager
	if manager == null:
		push_warning("FoulManager: nenhum MatchManager encontrado; as faltas ficam desligadas.")
		enabled = false
		return
	_watch_all.call_deferred()   # o MatchManager e os jogadores entram na árvore no mesmo frame
	get_tree().node_added.connect(_on_node_added)
	_connect_field.call_deferred()


func _connect_field() -> void:
	field = get_tree().get_first_node_in_group("field") as Field
	if field == null:
		push_warning("FoulManager: nenhum Field encontrado; lateral e escanteio ficam desligados.")
		return
	field.ball_left_pitch.connect(_on_ball_left_pitch)


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
	# Só vale queda no meio de uma ação e de quem NÃO está jogando o turno
	if manager.phase != MatchManager.Phase.EXECUTING or p.team == manager.current_team:
		return
	# E só se a queda veio de um CARRINHO: habilidades que derrubam nunca dão falta (nem chance de apito)
	if not _slide_in_progress():
		return
	if not _pending.is_empty():
		return   # uma falta por jogada
	if randf() >= whistle_chance:
		played_on.emit(p)
		SetPieceScreen.toast(self, "Segue o jogo!", UiStyle.MUTED_COLOR, 1.3)
		return
	_pending = {"victim": p, "pos": p.global_position, "fouling_team": manager.current_team}


## Alguém do time da vez está no meio de um Carrinho agora? (o Carrinho derruba durante o próprio movimento)
func _slide_in_progress() -> bool:
	for p in manager.get_team_players(manager.current_team):
		if is_instance_valid(p) and p.state == Player.State.SLIDING:
			return true
	return false


## O MatchManager chama quando um jogador GASTA uma ação de Chutar/Passe (depois de confirmar a mira/alvo).
## A primeira do cobrador encerra a cobrança: aí os secundários também podem bater na bola.
func note_kick(actor: Player) -> void:
	if state == State.TAKER_TURN and actor == taker:
		_kick_done = true


## O juiz vai apitar (ou a bola saiu) quando a ação em andamento terminar
func has_pending() -> bool:
	if not _pending.is_empty() and is_instance_valid(_pending.get("victim")):
		return true
	if not _out.is_empty():
		if _out_still_valid():
			return true
		_drop_out()   # alguém devolveu a bola ao jogo: não há mais lateral/escanteio
	return false


## Palavra do aviso e do título da tela de preparação
func kind_title() -> String:
	match kind:
		KIND_PENALTY:
			return "PÊNALTI"
		KIND_THROW_IN:
			return "LATERAL"
		KIND_CORNER:
			return "ESCANTEIO"
	return "FALTA"


## true para lateral e escanteio (bola que saiu), false para falta e pênalti
func is_out_kind() -> bool:
	return kind == KIND_THROW_IN or kind == KIND_CORNER


func clear_pending() -> void:
	_pending = {}


## true enquanto é a COBRANÇA em si: o cobrador agindo e a ação geral dele ainda não terminou
## (é quando o Chutar vira "Cobrar" e abre a telinha de efeito; o MatchManager pergunta depois de gastar a ação)
func is_taking() -> bool:
	return state == State.TAKER_TURN and not _kick_done and manager.active_player == taker


## true enquanto a falta está em andamento (preparação ou cobrança)
func is_active() -> bool:
	return state != State.IDLE


## Regras das ações gerais no turno da cobrança (o MatchManager pergunta aqui em can_use_general)
func allows_general(action: int) -> bool:
	if state != State.TAKER_TURN:
		return true
	var is_kick: bool = action == MatchManager.GeneralAction.SHOOT or action == MatchManager.GeneralAction.PASS
	if manager.active_player == taker:
		# O cobrador age normalmente (Correr, Pular, Carrinho...). Única regra: no lateral não se chuta
		return not (kind == KIND_THROW_IN and action == MatchManager.GeneralAction.SHOOT)
	# Os outros jogam à vontade, mas só batem na bola depois que o cobrador cobrou
	return _kick_done or not is_kick


# ---------- APITO ----------

## Chamado pelo MatchManager quando a ação termina e has_pending(). Roda a falta inteira até a cobrança começar.
func start_foul() -> void:
	# Só a bola saiu (sem falta pendente): lateral ou escanteio
	if _pending.is_empty() or not is_instance_valid(_pending.get("victim")):
		if not _out.is_empty():
			_start_out_of_play()
			return
	else:
		_out = {}   # falta e bola fora ao mesmo tempo: a falta vale
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
	taker.pass_range_bonus += throw_in_pass_range_bonus if kind == KIND_THROW_IN else pass_range_bonus
	taker.shot_chance_default = _shot_chance_for_kind()
	if kind != KIND_THROW_IN:   # lateral não chuta: sem bônus de força
		taker.next_kick_force_mult *= kick_force_mult
	taker.facing = taker.get_attack_dir()

	# O time que sofreu a falta joga: o cobrador vira Protagonista
	_kick_done = false
	manager.current_team = fouled_team
	manager._set_phase(MatchManager.Phase.CHOOSING_PROTAGONIST)
	manager.select_protagonist(taker)
	if manager.protagonist != taker:   # não deu para escolher o cobrador (ex: ficou proibido de ser Protagonista)
		on_turn_end()
		manager._end_turn()
		return
	# Mesmas ações de um turno comum (e não as do turno bônus), seja qual for o modo de jogo
	manager.protagonist_general_left = manager.protagonist_general_actions
	manager.protagonist_skill_left = manager.protagonist_skill_actions
	manager.secondary_general_left = manager.secondary_general_actions
	manager.secondary_skill_left = manager.secondary_skill_actions
	manager.state_changed.emit()
	set_piece_started.emit(kind, fouled_team, taker)


func _shot_chance_for_kind() -> float:
	match kind:
		KIND_PENALTY:
			return penalty_shot_chance
		KIND_CORNER:
			return corner_shot_chance
	return foul_shot_chance


## O MatchManager chama no começo de _end_turn(): fecha a cobrança e passa a vez para o time que FEZ a falta.
## Usa o mesmo mecanismo da rodada bônus: com in_bonus_turn ligado, o _end_turn() chama o _end_bonus_turn(), que
## devolve a vez ao _resume_team (aqui, o time da falta) com a escolha de protagonista aberta e ações novas.
## O turno de quem cobrou não conta como rodada (não emite turn_ended/turn_started), então não gasta recarga.
func on_turn_end() -> void:
	_pending = {}
	if state != State.TAKER_TURN:
		return
	_rename_shoot_button(false)
	_restore_taker()
	_kick_done = false
	if is_out_kind():
		# Lateral/escanteio: o turno da cobrança foi o turno do time; o _end_turn() segue a ordem normal
		state = State.IDLE
		set_piece_finished.emit(kind, fouled_team)
		return
	if not manager.in_bonus_turn:   # (se a falta foi numa rodada bônus, ela segue o caminho dela)
		manager.in_bonus_turn = true
		manager._resume_team = fouling_team
	state = State.IDLE
	set_piece_finished.emit(kind, fouled_team)
	SetPieceScreen.toast(self, "Vez de %s!" % manager.get_team_name(fouling_team), TeamStyle.color_of(fouling_team), 1.4)


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


func _process(delta: float) -> void:
	_poll_out()
	if state != State.TAKER_TURN:
		return
	# Rede de segurança: se o cobrador gastou TODAS as ações gerais sem bater na bola, a cobrança acabou
	# (senão os secundários ficariam sem poder chutar/passar). O normal é o note_kick() marcar.
	if not _kick_done and manager.protagonist_general_left <= 0 and manager.phase == MatchManager.Phase.CHOOSING_ACTION:
		_kick_done = true
	# O botão só se chama "Cobrar" durante a cobrança; o menu pode recriar os botões, então procura de novo a cada 0,1 s
	_scan_wait -= delta
	if _scan_wait > 0.0:
		return
	_scan_wait = 0.1
	if is_taking():
		_rename_shoot_button(true)
	elif not _renamed.is_empty():
		_rename_shoot_button(false)


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
	_out = {}
	_cuts = 0
	_kick_done = false
	state = State.IDLE
	taker = null


# ---------- LATERAL E ESCANTEIO ----------

## O Field avisou: a bola cruzou uma linha. Descobre quem cobra e para a bola ali até a jogada poder parar.
func _on_ball_left_pitch(local_pos: Vector2, goal_line: bool) -> void:
	# (no turno da cobrança também vale: a cobrança pode mandar a bola para fora de novo)
	if not out_enabled or manager == null or manager.match_over or state == State.SETUP or not _pending.is_empty():
		return
	if GameMode.training or manager.team_count < 2:
		return
	match manager.phase:
		MatchManager.Phase.FORMATION, MatchManager.Phase.MATCH_OVER, MatchManager.Phase.SET_PIECE:
			return
	# Resets (gol, troca de tempo, juiz carregando a bola): a bola anda fora do campo de propósito
	if manager._repositioning or manager._reset_running or manager._awaiting_goal_reset:
		return
	var ball: Ball = manager._get_ball()
	if ball == null or ball.is_held() or not is_instance_valid(ball.last_toucher):
		return
	# A bola parada na marca do lateral/escanteio/falta (antes de a cobrança sair) NÃO conta como "saiu de novo":
	# ela fica encostada na linha, e o Field avisava a cada quadro, o que recomeçava a cobrança sem parar e
	# congelava a bola (ninguém conseguia interagir com ela).
	if state == State.TAKER_TURN and not _kick_done and ball.global_position.distance_to(spot) < 40.0:
		return
	field = get_tree().get_first_node_in_group("field") as Field
	if field == null:
		return

	var sender: int = ball.last_toucher.team           # quem tirou a bola
	var taking: int = (sender + 1) % manager.team_count   # o outro time cobra
	var half: Vector2 = field.pitch_size * 0.5
	var info: Dictionary = {"sender_team": sender, "taking_team": taking}
	if goal_line:
		var side: int = 1 if local_pos.x > 0.0 else -1
		if _team_defending(side) != sender:
			return   # quem ataca mandou para fora = tiro de meta (ainda não existe): a bola quica como antes
		var corner_y: float = half.y if local_pos.y >= 0.0 else -half.y
		info["kind"] = KIND_CORNER
		info["spot"] = field.to_global(Vector2(side * half.x, corner_y))
	else:
		var x: float = clampf(local_pos.x, -half.x + throw_in_corner_margin, half.x - throw_in_corner_margin)
		var y: float = half.y if local_pos.y >= 0.0 else -half.y
		info["kind"] = KIND_THROW_IN
		info["spot"] = field.to_global(Vector2(x, y))
	_out = info
	_place_ball(field.to_global(local_pos), true)   # a bola para onde saiu e ninguém mexe nela


## Time que defende o gol deste lado (-1 esquerda / +1 direita)
func _team_defending(side: int) -> int:
	for t in manager.team_count:
		if field.defend_dir(t) == side:
			return t
	return -1


## A bola ainda está na linha (ou fora)? Se um jogador a devolveu ao campo, o lateral/escanteio cai.
func _out_still_valid() -> bool:
	var ball: Ball = manager._get_ball() if manager != null else null
	if ball == null or field == null or ball.is_held():
		return false
	var l: Vector2 = field.to_local(ball.global_position)
	var half: Vector2 = field.pitch_size * 0.5
	return absf(l.x) >= half.x - 6.0 or absf(l.y) >= half.y - 6.0


## O menu de pausa pediu para pular o turno: esquece o lateral/escanteio que esperava
func discard_out() -> void:
	if not _out.is_empty():
		_drop_out()


## Descarta o lateral/escanteio esperando e solta a bola que estava parada na linha
func _drop_out() -> void:
	_out = {}
	var ball: Ball = manager._get_ball() if manager != null else null
	if ball != null and state == State.IDLE:
		ball.collisions_paused = false


## Fora de uma ação (menus, goleiros, efeitos), começa assim que o jogo está parado numa escolha
func _poll_out() -> void:
	if _out.is_empty() or state == State.SETUP or manager == null:
		return
	if manager.match_over:
		_drop_out()
		return
	if manager.phase != MatchManager.Phase.CHOOSING_PROTAGONIST and manager.phase != MatchManager.Phase.CHOOSING_ACTION:
		return
	if manager.paused or manager._repositioning or manager._reset_running or manager._picking_skill_target \
			or manager._picking_skill_point:
		return
	if manager.active_player != null and manager.active_player.is_aiming:
		return
	if not _out_still_valid():
		_drop_out()
		return
	_start_out_of_play()


## Pula o turno em andamento (se não for do time que cobra) e roda a cobrança no turno de quem cobra
func _start_out_of_play() -> void:
	var taking: int = int(_out["taking_team"])
	if state == State.TAKER_TURN:
		# A bola saiu de novo durante uma cobrança: ela acaba aqui (devolve o que o cobrador tinha)
		_rename_shoot_button(false)
		_restore_taker()
		_kick_done = false
		state = State.IDLE
		set_piece_finished.emit(kind, fouled_team)
	if manager.current_team != taking and _cuts < manager.team_count + 1:
		_cuts += 1
		_stop_current_play()
		manager._set_phase(MatchManager.Phase.SET_PIECE)   # só volta a CHOOSING_PROTAGONIST no turno de quem cobra
		SetPieceScreen.toast(self, "Bola fora! O turno de %s é pulado" % manager.get_team_name(manager.current_team),
			UiStyle.MUTED_COLOR, 1.6)
		manager._end_turn()   # conta como turno jogado; a vez passa ao próximo time (o cobrador)
		return
	if manager.current_team != taking:   # (não deveria acontecer: segura o jogo certo mesmo assim)
		manager.current_team = taking
	_cuts = 0
	_run_out_of_play()


## Cancela o que estava em andamento (mira, passe escolhido, papéis): nada fica pela metade
func _stop_current_play() -> void:
	if manager.active_player != null and manager.active_player.is_aiming:
		manager.active_player.cancel_aim()
	manager._hide_pass_preview()
	manager.clear_pending_pass()
	manager._clear_roles()
	manager.protagonist = null
	manager.active_player = null


func _run_out_of_play() -> void:
	var info: Dictionary = _out
	_out = {}
	field = get_tree().get_first_node_in_group("field") as Field
	if field == null or manager.match_over:
		manager._set_phase(MatchManager.Phase.CHOOSING_PROTAGONIST)
		return

	state = State.SETUP
	kind = info["kind"]
	fouled_team = int(info["taking_team"])    # (nos campos da falta: "fouled" = quem cobra, "fouling" = quem tirou a bola)
	fouling_team = int(info["sender_team"])
	taker = null
	_stop_current_play()
	manager._set_phase(MatchManager.Phase.SET_PIECE)

	_screen = SetPieceScreen.new()
	_screen.foul = self
	_screen.manager = manager
	manager.add_child(_screen)
	await _screen.show_whistle()
	if manager.match_over:
		_abort()
		return

	# A bola da cobrança fica um pouco DENTRO da linha (e não em cima dela): em cima, qualquer arredondamento
	# a deixava "fora do campo" e o Field/limites a seguravam ou a empurravam de volta
	spot = _clamp_to_pitch(info["spot"], 8.0)
	_place_ball(spot, true)
	_choose_taker_near_ball()
	_enforce_rules_on_everyone()

	await _screen.run_setup()
	_screen = null
	if manager.match_over or taker == null or not is_instance_valid(taker):
		_abort()
		return
	_stop_all_motion()
	_place_ball(spot)
	_begin_taker_turn()


## Cobrador inicial: o companheiro mais perto da bola (o jogador troca na lista da tela)
func _choose_taker_near_ball() -> void:
	var best: Player = null
	for p in manager.get_team_players(fouled_team):
		if manager.is_protagonist_blocked(p):
			continue
		if best == null or p.global_position.distance_to(spot) < best.global_position.distance_to(spot):
			best = p
	if best != null:
		set_taker(best)
