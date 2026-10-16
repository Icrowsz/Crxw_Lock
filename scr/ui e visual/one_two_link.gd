class_name OneTwoLink
extends RefCounted
## Motor do 1-2 em cadeia. Quem usa: o Sharp Sharp do Kurona e o Manipulable Array do Teddy.
## Os dois funcionam IGUAL; só mudam os valores que cada personagem preenche (nome, recarga,
## bônus por rodada, quanto vale o aliado de fora...).
##
## COMO FUNCIONA
##  1. Quem usa a habilidade (o "dono") escolhe um aliado. A bola vai NA HORA, em passe rasteiro.
##     Se o passe chegar, o 1-2 começa e dura "duration_rounds" rodadas (a rodada atual conta).
##  2. O aliado ganha acesso à MESMA habilidade (um botão extra no menu dele). Com ela, quem estiver
##     com a bola passa para o outro (passe rasteiro, gasta uma ação de habilidade como qualquer
##     outra). Quando o ALIADO devolve para o dono, o bônus é multiplicado (x2 por padrão).
##     O dono também pode passar de novo para o aliado (repete o processo).
##  3. O bônus de chance de gol começa em "+por rodada" e sobe esse tanto a cada rodada mantida.
##     Ele fica no PRÓXIMO chute de quem estiver com a bola (é gasto ao chutar).
##  4. O 1-2 é CANCELADO (a recarga começa e o aliado perde a habilidade) quando:
##      - passam as rodadas;
##      - alguém chuta (gasta o bônus);
##      - um inimigo toca na bola;
##      - nenhum dos dois está perto da bola (no fim do turno ou no início da rodada);
##      - um dos dois cai, ou sai gol;
##      - um passe do 1-2 é interceptado.
##  5. ALIADO DE FORA da conexão: se um aliado que não faz parte do 1-2 toca na bola, ele recebe
##     o bônus (vezes "outside_ratio": 1.0 = tudo, 0.5 = metade, 0 = nada) e o 1-2 acaba.
##
## O que o personagem precisa fazer (veja kurona.gd e teddy.gd):
##   _link = OneTwoLink.new(self) e preencher os valores abaixo; chamar poll() no
##   _physics_process, on_round_started() / on_turn_ended() / on_goal() nos sinais do MatchManager,
##   cast() / exchange(self) em use_skill(), clear() ao reiniciar a partida e
##   draw_link(self) no _draw.
## O "empréstimo" da habilidade ao aliado usa lend_skill() do Player (ver player.gd).

# ---------- VALORES (cada personagem preenche os seus) ----------

var owner: Player
var skill_id: StringName = &"one_two"
var skill_name: String = "1-2"
var cooldown_group: StringName = &"cd_one_two"
var cooldown_rounds: int = 2
var pass_range: float = 450.0                  # alcance para escolher o aliado e para os passes
var animation: StringName = &""                # animação da habilidade (se faltar, usa "pass")
var color: Color = Color.WHITE
var icon: Texture2D = null
var ally_ground_only: bool = false             # só aliados no chão podem ser escolhidos?
var duration_rounds: int = 3                   # duração total (a rodada atual conta)
var ally_access_rounds: int = 3                # por quantas rodadas o aliado tem a habilidade
var return_multiplier: float = 2.0             # a devolução do aliado multiplica o bônus por isto
var outside_ratio: float = 1.0                 # fração do bônus que um aliado de fora recebe
var keep_range: float = 120.0                  # "perto da bola": distância máxima de um dos dois
var base_per_round: float = 0.03               # +3% por rodada (se per_round não estiver definido)
var per_round: Callable = Callable()           # () -> float: bônus por rodada atual (ex: His Eyes)

# ---------- ESTADO ----------

var active: bool = false
var partner: Player = null
var holder: Player = null          # quem está com o bônus (quem vai chutar com ele)
var bonus: float = 0.0             # bônus acumulado (0.09 = +9%)
var busy: bool = false             # um passe do 1-2 está rolando (não conta como interrupção)
var start_round: int = 0
var until_round: int = -1
var _applied: float = 0.0          # quanto do bônus já está no next_shot_bonus do holder
var _seen: Player = null           # último a tocar na bola que já foi tratado


func _init(who: Player) -> void:
	owner = who


# ---------- CONSULTAS ----------

func _ball() -> Ball:
	return owner._get_ball()


func _round() -> int:
	return owner.get_current_round()


func _bonus_per_round() -> float:
	return float(per_round.call()) if per_round.is_valid() else base_per_round


func lent_id() -> StringName:
	return StringName("lent_" + String(skill_id))


func _valid_ally(p: Player) -> bool:
	return p != owner and p.team == owner.team and not p.is_down \
		and (not ally_ground_only or p.height_level == Heights.Level.GROUND)


## A bola parou encostada em "to" (o passe chegou sem ninguém interceptar)?
func _arrived(ball: Ball, to: Player) -> bool:
	return ball.global_position.distance_to(to.global_position) \
		<= to.body_radius + ball.collision_radius + 10.0


## A bola está perto de um dos dois?
func _ball_with_pair() -> bool:
	var ball: Ball = _ball()
	if ball == null or ball.is_held() or not is_instance_valid(partner):
		return false
	var d: float = minf(ball.global_position.distance_to(owner.global_position),
		ball.global_position.distance_to(partner.global_position))
	return d <= keep_range


func _ally_has_access() -> bool:
	return _round() <= start_round + ally_access_rounds - 1


## Dá para ligar o 1-2 agora? (fora de recarga, bola ao alcance e algum aliado no alcance)
func can_cast() -> bool:
	if active or owner.is_on_cooldown(cooldown_group):
		return false
	var ball: Ball = _ball()
	if ball == null or owner.get_kick_type(ball) == Player.KickType.NONE:
		return false
	for p: Player in owner.get_tree().get_nodes_in_group("players"):
		if _valid_ally(p) and owner.global_position.distance_to(p.global_position) <= pass_range:
			return true
	return false


## "who" (o dono ou o aliado) pode passar para o outro agora?
func can_exchange(who: Player) -> bool:
	if not active or busy or not is_instance_valid(partner) or who == null or who.is_down:
		return false
	var other: Player = null
	if who == owner:
		other = partner
	elif who == partner and _ally_has_access():
		other = owner
	else:
		return false
	if other.is_down:
		return false
	var ball: Ball = _ball()
	if ball == null or who.get_kick_type(ball) == Player.KickType.NONE:
		return false
	return who.global_position.distance_to(other.global_position) <= pass_range


# ---------- LIGAR O 1-2 ----------

## Escolhe o aliado e passa a bola na hora. Devolve true se a habilidade foi usada
## (false = cancelou: o MatchManager devolve a ação).
func cast() -> bool:
	var m: MatchManager = owner._get_manager()
	if m == null:
		return false
	var filter: Callable = func(o: Player) -> bool: return _valid_ally(o)
	var target: Player = await m.pick_ally_for_skill(owner, pass_range, false, filter)
	if target == null:
		return false
	var ball: Ball = _ball()
	if ball == null or owner.get_kick_type(ball) == Player.KickType.NONE:
		return false   # a bola saiu do alcance enquanto ele escolhia

	busy = true
	if not await owner.play_action(animation, Player.ANIM_PASS):
		busy = false
		return false
	await m.run_ground_pass(owner, target, ball)
	ball.collisions_paused = false
	busy = false
	if m.match_over:
		return true

	# Passe interceptado: o 1-2 nem começa (a habilidade foi gasta e a recarga começa)
	if not _arrived(ball, target):
		owner.start_cooldown(cooldown_group, cooldown_rounds, _round() + 1)
		return true

	active = true
	partner = target
	start_round = m.round_number
	until_round = start_round + duration_rounds - 1
	bonus = _bonus_per_round()
	_applied = 0.0
	holder = null
	_seen = ball.last_toucher
	_set_holder(target)
	target.lend_skill(lent_id(), self)   # o aliado ganha o botão para devolver
	owner.queue_redraw()
	return true


# ---------- PASSAR / DEVOLVER ----------

## "who" passa para o outro (rasteiro). Se quem passa é o ALIADO, é uma devolução: dobra o bônus.
func exchange(who: Player) -> bool:
	var m: MatchManager = owner._get_manager()
	if m == null or not can_exchange(who):
		return false
	var other: Player = partner if who == owner else owner
	var ball: Ball = _ball()

	busy = true
	if not await who.play_action(animation, Player.ANIM_PASS):
		busy = false
		return false
	if not active:   # o 1-2 acabou durante a animação
		busy = false
		return false
	await m.run_ground_pass(who, other, ball)
	ball.collisions_paused = false
	busy = false
	if m.match_over or not active:
		return true

	if not _arrived(ball, other):
		break_link()   # interceptado
		return true

	_seen = ball.last_toucher
	if who == partner:
		bonus *= return_multiplier   # devolveram: dobra
	_set_holder(other)
	owner.queue_redraw()
	return true


# ---------- ACOMPANHAR ----------

## Chame todo frame de física (no _physics_process do dono)
func poll() -> void:
	if not active or busy:
		return
	if not is_instance_valid(owner) or not is_instance_valid(partner) \
			or owner.is_down or partner.is_down:
		break_link()
		return
	# Quem estava com o bônus chutou: gastou, acabou
	if _applied > 0.0 and is_instance_valid(holder) \
			and holder.next_shot_bonus < _applied - 0.0001:
		break_link()
		return
	var ball: Ball = _ball()
	if ball == null or ball.is_held():
		break_link()
		return
	var t: Player = ball.last_toucher
	if t == null or t == _seen:
		return
	_seen = t
	if t == owner or t == partner:
		_set_holder(t)   # um dos dois tocou: o bônus acompanha a bola
	elif t.team == owner.team:
		# Aliado de FORA da conexão: o bônus (ou parte dele) vai para ele e o 1-2 acaba
		var gift: float = bonus * outside_ratio
		_strip()
		if gift > 0.0:
			t.next_shot_bonus += gift
		break_link()
	else:
		break_link()   # inimigo tocou na bola


func on_round_started(round_number: int) -> void:
	if not active:
		return
	if round_number > until_round or not _ball_with_pair():
		break_link()
		return
	bonus += _bonus_per_round()   # +X% por rodada mantida
	_sync()
	if not _ally_has_access() and is_instance_valid(partner):
		partner.revoke_lent_skill(lent_id())
	owner.queue_redraw()


## No fim do turno do time do dono, a bola precisa estar com um dos dois
func on_turn_ended(team_ended: int) -> void:
	if active and team_ended == owner.team and not busy and not _ball_with_pair():
		break_link()


func on_goal() -> void:
	break_link()


# ---------- BÔNUS ----------

func _set_holder(p: Player) -> void:
	_strip()
	holder = p
	_sync()


## Deixa no próximo chute do holder exatamente o bônus acumulado
func _sync() -> void:
	if not is_instance_valid(holder):
		return
	holder.next_shot_bonus = maxf(0.0, holder.next_shot_bonus - _applied + bonus)
	_applied = bonus


func _strip() -> void:
	if _applied > 0.0 and is_instance_valid(holder):
		holder.next_shot_bonus = maxf(0.0, holder.next_shot_bonus - _applied)
	_applied = 0.0


# ---------- FIM ----------

## O 1-2 acabou (duração, chute, interrupção...): começa a recarga e o aliado perde a habilidade
func break_link() -> void:
	if not active:
		return
	var until: int = until_round
	clear()
	owner.start_cooldown(cooldown_group, cooldown_rounds, mini(_round() + 1, until + 1))


## Desliga tudo SEM recarga (partida nova, personagem saindo da cena)
func clear() -> void:
	_strip()
	if is_instance_valid(partner):
		partner.revoke_lent_skill(lent_id())
	active = false
	partner = null
	holder = null
	busy = false
	bonus = 0.0
	_applied = 0.0
	_seen = null
	if is_instance_valid(owner):
		owner.queue_redraw()


# ---------- HABILIDADE EMPRESTADA (o Player chama estas 4 funções no aliado) ----------

func lent_skill_name(_who: Player) -> String:
	return "%s (devolver)" % skill_name


func lent_can_use(who: Player) -> bool:
	return can_exchange(who)


func lent_use(who: Player) -> bool:
	return await exchange(who)


func lent_info(_who: Player) -> Dictionary:
	return {
		"title": "%s (devolver)" % skill_name,
		"description": "Passe rasteiro de volta para %s. Devolver dobra o bônus de chance de gol (atual: +%d%%)." % [
			owner.get_display_name(), roundi(bonus * 100.0)],
		"icon": icon,
	}


## Texto da habilidade para o balão do dono
func cast_description() -> String:
	return ("Passa a bola na hora (rasteiro) para um aliado e liga o 1-2 por %d rodadas. O aliado ganha esta habilidade para devolver, e cada devolução dobra o bônus. Cada rodada mantida dá +%d%% de chance de gol no próximo chute de quem estiver com a bola. Aliado de fora que tocar na bola recebe o bônus e o 1-2 acaba.\n"
		+ "Recarga: %d rodadas.") % [duration_rounds, roundi(_bonus_per_round() * 100.0), cooldown_rounds]


func exchange_description() -> String:
	return "Passe rasteiro para o parceiro do 1-2, que segue ativo. Bônus atual: +%d%%." % roundi(bonus * 100.0)


# ---------- DESENHO ----------

## Linha tracejada até o parceiro + bônus acumulado. Chame no _draw() do dono.
func draw_link(ci: Node2D, extra: String = "") -> void:
	if not active or not is_instance_valid(partner):
		return
	var center := Vector2(0.0, -owner.height)
	var partner_pos: Vector2 = ci.to_local(partner.global_position) + Vector2(0.0, -partner.height)
	ci.draw_dashed_line(center, partner_pos, color, 2.0, 8.0)
	var text: String = "1-2 +%d%%%s" % [roundi(bonus * 100.0), extra]
	ci.draw_string(ThemeDB.fallback_font, Vector2(-34.0, -owner.placeholder_radius - 30.0 - owner.height),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
