class_name Kurona
extends Player
## Ranze Kurona. Herda tudo do Player (ações gerais) e adiciona as habilidades próprias:
##
## 1. Sharp Sharp (ação de habilidade): escolhe um aliado (no chão, até 475 de distância) e a bola
##      vai NA HORA, em passe rasteiro. O aliado ganha a MESMA habilidade para devolver, e cada
##      devolução dobra o bônus. Dura 3 rodadas; cada rodada mantida dá +3% de chance no PRÓXIMO
##      chute de quem estiver com a bola. Um aliado de FORA da dupla que tocar na bola recebe o
##      bônus (metade, veja sharp_outside_ratio) e o 1-2 acaba.
##      O 1-2 é CANCELADO (efeito acaba, começa a recarga de 3 rodadas e o aliado perde a
##      habilidade) quando passam as rodadas, alguém chuta, um inimigo toca na bola, nenhum dos
##      dois está perto da bola, um dos dois cai, sai gol ou um passe é interceptado.
##      Funciona igual ao Manipulable Array do Teddy (motor em one_two_link.gd).
##    1.1 Lie Lie (variante): com o 1-2 ativo e a bola com o Kurona, a ação geral "Pular" libera
##      este botão (no lugar do Sharp Sharp, neste turno). É o "corta-luz": passe curto para um
##      aliado de FORA da sincronia; se ele receber, ganha metade do bônus acumulado no próximo
##      chute dele. O 1-2 acaba.
## 2. Orbital Orbital (ação de habilidade): corrente com um aliado "no chão" até 300 de distância.
##      Tamanho máximo = distância original + metade dela. Enquanto durar, os dois são imunes
##      a carrinho (pulam por cima), têm Passe com mais alcance e Correr com 0.7s a mais.
##      Dura "orbital_rounds" rodadas; recarga de 3 rodadas a partir do fim.
## 3. Bite Bite (ação de habilidade): um Carrinho um pouco mais longo; se acertar a bola, ela vai
##      em passe para o aliado mais próximo (até 300).
##    3.1 Assault Assault (variante automática: Kurona E bola suspensos/voando): ele voa até a
##      bola próxima e faz um passe (que desce até o chão) para o aliado mais próximo (até 300).
##      Recarga de 2 rodadas (só desta variante).
##
## Como montar a cena: Nova Cena Herdada de player.tscn -> anexe este script ao nó raiz
## -> renomeie o nó raiz para "Kurona". Animações opcionais (nomes na SpriteFrames):
## "sharp_sharp", "orbital_orbital" (conjurar) e "assault_assault" (investida).

const SKILL_SHARP: StringName = &"sharp_sharp"
const SKILL_ORBITAL: StringName = &"orbital_orbital"
const SKILL_BITE: StringName = &"bite_bite"

## Grupos de recarga
const CD_SHARP: StringName = &"cd_sharp"
const CD_ORBITAL: StringName = &"cd_orbital"
const CD_ASSAULT: StringName = &"cd_assault"

## Variante do Bite Bite que cabe na situação atual (altura do Kurona x altura da bola)
enum BiteVariant { NONE, BITE, ASSAULT }

const SHARP_COLOR := Color(1.0, 0.45, 0.8)
const ORBITAL_COLOR := Color(1.0, 0.237, 0.972, 1.0)

@export_group("Sharp Sharp")
@export var sharp_range: float = 475.0                           # alcance para escolher o aliado
@export_range(0.0, 1.0) var sharp_bonus_per_round: float = 0.03  # +3% por rodada de 1-2
@export var sharp_touch_range: float = 120.0                     # "bola perto" de um dos dois
@export var sharp_cooldown: int = 3                              # recarga, contada a partir do fim do efeito
@export var sharp_duration: int = 3                              # rodadas de duração (a atual conta)
@export var sharp_ally_access_rounds: int = 3                    # por quantas rodadas o aliado tem a habilidade
@export var sharp_return_mult: float = 2.0                       # a devolução do aliado multiplica o bônus
@export_range(0.0, 1.0) var sharp_outside_ratio: float = 0.5     # aliado de fora recebe esta fração do bônus

@export_group("Lie Lie")
@export var lie_pass_range: float = 450.0                        # alcance do passe curto
@export_range(0.0, 1.0) var lie_bonus_ratio: float = 0.5         # fração do bônus acumulado que o receptor ganha

@export_group("Orbital Orbital")
@export var orbital_range: float = 330.0                         # alcance para escolher o aliado
@export var orbital_chain_extra: float = 0.5                     # corrente = distância original x (1 + isto)
@export var orbital_rounds: int = 3                              # duração total em rodadas (contando a atual)
@export var orbital_cooldown: int = 3                            # recarga, contada a partir do fim do efeito
@export var orbital_pass_range_bonus: float = 150.0              # alcance extra do Passe (px)
@export var orbital_run_bonus: float = 0.7                       # segundos a mais no Correr

@export_group("Bite Bite")
@export var bite_distance_mult: float = 1.1                      # carrinho x este valor
@export var bite_pass_range: float = 360.0                       # alcance do passe até o aliado mais próximo

@export_group("Assault Assault")
@export var assault_reach: float = 180.0                         # "bola próxima": até onde ele voa
@export var assault_dash_time: float = 0.25                      # duração da investida
@export var assault_cooldown: int = 2

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão do menu. Chaves: sharp_sharp, orbital_orbital, bite_bite.
## Sem imagem, o balão aparece só com o texto.
@export var skill_icons: Dictionary = {}

# ---------- ESTADO ----------
# Sharp Sharp (motor compartilhado com o Manipulable Array do Teddy: one_two_link.gd)
var _link: OneTwoLink
var _lie_ready: bool = false             # "Pular" com a bola liberou o Lie Lie neste turno

# Orbital Orbital
var _orb_active: bool = false
var _orb_partner: Player = null
var _orb_max_len: float = 0.0
var _orb_until_round: int = -1

# Bite Bite
var _bite_active: bool = false
var _bite_pass_running: bool = false
var _base_slide_distance: float = 0.0


func _init() -> void:
	character_id = "kurona"   # o menu de formação usa isto para saber quem é quem
	display_name = "Ranze Kurona"


func _ready() -> void:
	super()
	_base_slide_distance = slide_distance
	_build_link()
	_hook_manager.call_deferred()


func _exit_tree() -> void:
	_clear_sharp()
	_clear_orbital()


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m:
		m.round_started.connect(_on_round_started)
		m.goal_scored.connect(_on_goal_scored)
		m.turn_ended.connect(_on_turn_ended)


func _on_round_started(round_number: int) -> void:
	_link.on_round_started(round_number)
	if _orb_active and not _orbital_valid():
		_break_orbital()
	queue_redraw()


## Gol: todo mundo volta para a formação, então a corrente e o 1-2 se desfazem
func _on_goal_scored(_goal: Dictionary) -> void:
	_break_sharp()
	_break_orbital()


# ---------- UTIL ----------

## Companheiros (menos o próprio Kurona e os derrubados) a até range_px de "from"
func _allies_near(from: Vector2, range_px: float, ground_only: bool = false,
		exclude: Player = null) -> Array[Player]:
	var result: Array[Player] = []
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p == self or p == exclude or p.team != team or p.is_down:
			continue
		if ground_only and p.height_level != Heights.Level.GROUND:
			continue
		if from.distance_to(p.global_position) <= range_px:
			result.append(p)
	return result


func _nearest_ally(from: Vector2, range_px: float) -> Player:
	var best: Player = null
	var best_dist: float = INF
	for p in _allies_near(from, range_px):
		var d: float = from.distance_to(p.global_position)
		if d < best_dist:
			best_dist = d
			best = p
	return best


## A bola parou encostada em "to" (passe chegou sem ninguém interceptar)?
func _ball_arrived(ball: Ball, to: Player) -> bool:
	return ball.global_position.distance_to(to.global_position) \
		<= to.body_radius + ball.collision_radius + 10.0


# ---------- SHARP SHARP ----------

## Habilidade 1: escolhe o aliado e passa a bola na hora (tudo no motor do 1-2).
## Com o 1-2 já ativo, o mesmo botão passa/devolve ou, se o Pular liberou, vira Lie Lie.
func _use_sharp_sharp() -> bool:
	return await _link.cast()


## Variante 1.1: corta-luz para um aliado de fora da sincronia
func _use_lie_lie() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var partner: Player = _link.partner
	var outside_sync: Callable = func(o: Player) -> bool:
		return o != partner and not o.is_down
	var target: Player = await m.pick_ally_for_skill(self, lie_pass_range, false, outside_sync)
	if target == null:
		return false
	var ball: Ball = _get_ball()
	# Pode ter mudado enquanto ele escolhia: confere de novo
	if ball == null or not _link.active or get_kick_type(ball) == KickType.NONE:
		return false

	_link.busy = true   # o passe do corta-luz não conta como interrupção do 1-2
	var half: float = _link.bonus * lie_bonus_ratio
	await m.run_ground_pass(self, target, ball)
	ball.collisions_paused = false
	_link.busy = false
	# Só ganha se RECEBEU o passe curto (ninguém interceptou)
	if _ball_arrived(ball, target):
		target.next_shot_bonus = maxf(target.next_shot_bonus, half)
	_break_sharp()   # a bola saiu da dupla: o 1-2 acaba
	return true


## Quando "Pular" é usado com o 1-2 ativo e a bola com o Kurona, libera o Lie Lie
func jump() -> void:
	var had_ball: bool = _link.active and get_kick_type(_get_ball()) != KickType.NONE
	await super()
	if had_ball and _link.active:
		_lie_ready = true
		queue_redraw()


func _lie_available() -> bool:
	return _link.active and _lie_ready and get_kick_type(_get_ball()) != KickType.NONE


## Lie Lie liberado E existe aliado de fora da dupla ao alcance
func _lie_usable() -> bool:
	return _lie_available() \
		and not _allies_near(global_position, lie_pass_range, false, _link.partner).is_empty()


## O corta-luz só vale no turno em que o Pular foi usado
func _on_turn_ended(team_ended: int) -> void:
	if team_ended == team:
		_lie_ready = false
	_link.on_turn_ended(team_ended)


## Acaba o 1-2 (Lie Lie usado ou gol) e começa a recarga
func _break_sharp() -> void:
	_lie_ready = false
	_link.break_link()


## Desliga o 1-2 sem recarga (usado também na partida nova)
func _clear_sharp() -> void:
	_lie_ready = false
	_link.clear()


## Valores do Sharp Sharp no motor do 1-2 (o Teddy usa o mesmo motor com valores dele)
func _build_link() -> void:
	_link = OneTwoLink.new(self)
	_link.skill_id = SKILL_SHARP
	_link.skill_name = "Sharp Sharp"
	_link.cooldown_group = CD_SHARP
	_link.cooldown_rounds = sharp_cooldown
	_link.pass_range = sharp_range
	_link.animation = &"sharp_sharp"
	_link.color = SHARP_COLOR
	_link.icon = skill_icons.get(String(SKILL_SHARP), null) as Texture2D
	_link.ally_ground_only = true
	_link.duration_rounds = sharp_duration
	_link.ally_access_rounds = sharp_ally_access_rounds
	_link.return_multiplier = sharp_return_mult
	_link.outside_ratio = sharp_outside_ratio
	_link.keep_range = sharp_touch_range
	_link.base_per_round = sharp_bonus_per_round


# ---------- ORBITAL ORBITAL ----------

func _use_orbital() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var only_grounded: Callable = func(o: Player) -> bool:
		return o.height_level == Heights.Level.GROUND and not o.is_down
	var target: Player = await m.pick_ally_for_skill(self, orbital_range, false, only_grounded)
	if target == null:
		return false
	if not await play_action(&"orbital_orbital"):
		return false

	_orb_partner = target
	_orb_max_len = global_position.distance_to(target.global_position) * (1.0 + orbital_chain_extra)
	_orb_until_round = m.round_number + orbital_rounds - 1   # a rodada atual conta
	_orb_active = true
	start_cooldown(CD_ORBITAL, orbital_cooldown, _orb_until_round + 1)
	_set_orbital_effects(self, true)
	_set_orbital_effects(target, true)
	queue_redraw()
	return true


## Liga/desliga os efeitos nos dois jogadores (o Player lê estas variáveis)
func _set_orbital_effects(p: Player, on: bool) -> void:
	p.slide_immune = on
	p.pass_range_bonus = orbital_pass_range_bonus if on else 0.0
	p.run_time_bonus = orbital_run_bonus if on else 0.0


func _orbital_valid() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and is_instance_valid(_orb_partner) and m.round_number <= _orb_until_round


## A corrente acabou (duração, gol): começa a recarga a partir do fim do efeito
func _break_orbital() -> void:
	if not _orb_active:
		return
	_clear_orbital()
	start_cooldown(CD_ORBITAL, orbital_cooldown,
		mini(get_current_round() + 1, _orb_until_round + 1))


func _clear_orbital() -> void:
	if _orb_active:
		_set_orbital_effects(self, false)
		if is_instance_valid(_orb_partner):
			_set_orbital_effects(_orb_partner, false)
	_orb_active = false
	_orb_partner = null
	queue_redraw()


## A corrente é rígida: quem estiver se mexendo não passa do tamanho máximo
func _physics_process(delta: float) -> void:
	super(delta)
	_link.poll()
	if not _orb_active or not is_instance_valid(_orb_partner):
		return
	var offset: Vector2 = global_position - _orb_partner.global_position
	var dist: float = offset.length()
	if dist <= _orb_max_len or dist < 0.01:
		return
	var pull: Vector2 = offset / dist * _orb_max_len
	if _orb_partner.state != State.IDLE and state == State.IDLE:
		_orb_partner.global_position = global_position - pull   # o aliado correndo é quem a corrente segura
	else:
		global_position = _orb_partner.global_position + pull


## Mesma regra da corrente, para um ponto qualquer (a investida do Assault Assault usa)
func _chain_clamped(pos: Vector2) -> Vector2:
	if not _orb_active or not is_instance_valid(_orb_partner):
		return pos
	var offset: Vector2 = pos - _orb_partner.global_position
	if offset.length() <= _orb_max_len:
		return pos
	return _orb_partner.global_position + offset.normalized() * _orb_max_len


# ---------- BITE BITE / ASSAULT ASSAULT ----------

func _bite_variant() -> BiteVariant:
	if height_level == Heights.Level.GROUND:
		return BiteVariant.BITE
	var ball: Ball = _get_ball()
	# Kurona suspenso/voando + bola suspensa/voando
	if ball != null and ball.get_level() != Heights.Level.GROUND:
		return BiteVariant.ASSAULT
	return BiteVariant.NONE


## Bite Bite: carrinho mais longo. Acertou a bola -> passe para o aliado mais próximo.
func _use_bite() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var distance: float = _base_slide_distance * bite_distance_mult
	var aim: Vector2 = await m.aim_for_skill(self, distance)
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação

	_bite_active = true
	slide_distance = distance
	start_slide(aim)
	slides_this_turn -= 1   # é uma habilidade: não gasta o Carrinho geral do turno
	await slide_finished
	slide_distance = _base_slide_distance
	while _bite_pass_running:   # o passe pode ainda estar a caminho quando o carrinho acaba
		await get_tree().process_frame
	_bite_active = false
	return true


## Durante o Bite Bite: se o carrinho acerta a bola e há aliado até 300, vira passe.
## Sem aliado por perto, cai no comportamento normal do carrinho (chuta na direção dele).
func _check_slide_hits() -> void:
	if _bite_active and not _slide_hit_ball:
		var ball: Ball = _get_ball()
		if ball != null and not ball.is_held() and ball.get_level() == Heights.Level.GROUND \
				and global_position.distance_to(ball.global_position) <= slide_hit_radius:
			var ally: Player = _nearest_ally(global_position, bite_pass_range)
			if ally != null:
				_slide_hit_ball = true   # o super() não chuta a bola: o passe decide
				_bite_pass(ball, ally)
	super()   # derruba os inimigos no caminho (e chuta a bola se não virou passe)


func _bite_pass(ball: Ball, ally: Player) -> void:
	var m: MatchManager = _get_manager()
	if m == null:
		return
	_bite_pass_running = true
	ball.velocity = Vector2.ZERO
	ball.collisions_paused = true   # o corpo deslizando do Kurona não empurra a bola
	await m.run_ground_pass(self, ally, ball)
	ball.collisions_paused = false
	_bite_pass_running = false


func _assault_possible() -> bool:
	var ball: Ball = _get_ball()
	if ball == null or ball.is_held() or ball.is_locked_for(team):
		return false
	if global_position.distance_to(ball.global_position) > assault_reach:
		return false
	return _nearest_ally(ball.global_position, bite_pass_range) != null


## Assault Assault: voa até a bola e passa (rasteiro: a bola desce até o chão) para o aliado
func _use_assault() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null or not _assault_possible():
		return false

	_play_oneshot(&"assault_assault")
	ball.collisions_paused = true
	await _dash_to_ball(ball)
	var ally: Player = _nearest_ally(global_position, bite_pass_range)
	if ally == null:
		ally = _nearest_ally(ball.global_position, bite_pass_range)
	if ally != null:
		await m.run_ground_pass(self, ally, ball)
	ball.collisions_paused = false
	start_cooldown(CD_ASSAULT, assault_cooldown)
	return true


## Leva o Kurona até encostar na bola (acompanha a bola se ela ainda estiver se mexendo)
func _dash_to_ball(ball: Ball) -> void:
	var start: Vector2 = global_position
	var stop_dist: float = body_radius + ball.collision_radius + 6.0
	var t: float = 0.0
	while t < assault_dash_time and is_inside_tree():
		await get_tree().process_frame
		t += get_process_delta_time()
		var away: Vector2 = start - ball.global_position
		var dir: Vector2 = away.normalized() if away.length() > 0.01 else Vector2(-facing, 0.0)
		var dest: Vector2 = _chain_clamped(ball.global_position + dir * stop_dist)
		face_towards(ball.global_position - global_position)
		global_position = start.lerp(dest, clampf(t / assault_dash_time, 0.0, 1.0))


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func _sharp_skill_name() -> String:
	if _link.active:
		if _lie_usable():
			return "Lie Lie"
		return "Sharp Sharp (passar, +%d%%)" % roundi(_link.bonus * 100.0)
	return skill_label("Sharp Sharp", CD_SHARP)


func _bite_skill_name() -> String:
	if _bite_variant() == BiteVariant.ASSAULT:
		return skill_label("Assault Assault", CD_ASSAULT)
	return "Bite Bite"


func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"id": SKILL_SHARP, "name": _sharp_skill_name()})
	var orbital_name: String = "Orbital Orbital (ativo)" if _orb_active \
		else skill_label("Orbital Orbital", CD_ORBITAL)
	list.append({"id": SKILL_ORBITAL, "name": orbital_name})
	list.append({"id": SKILL_BITE, "name": _bite_skill_name()})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_SHARP:
			if _link.active:
				# Já está no 1-2: o botão passa/devolve ou, liberado pelo Pular, vira Lie Lie
				return _lie_usable() or _link.can_exchange(self)
			# can_cast confere recarga, bola ao alcance e aliado (no chão) ao alcance
			return height_level == Heights.Level.GROUND and _link.can_cast()
		SKILL_ORBITAL:
			# Kurona no chão ou suspenso (não voando); o aliado precisa estar no chão
			return not _orb_active and not is_on_cooldown(CD_ORBITAL) \
				and height_level != Heights.Level.FLYING \
				and not _allies_near(global_position, orbital_range, true).is_empty()
		SKILL_BITE:
			match _bite_variant():
				BiteVariant.BITE:
					return true
				BiteVariant.ASSAULT:
					return not is_on_cooldown(CD_ASSAULT) and _assault_possible()
			return false
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_SHARP:
			if _link.active:
				if _lie_usable():
					return await _use_lie_lie()
				return await _link.exchange(self)
			return await _use_sharp_sharp()
		SKILL_ORBITAL:
			return await _use_orbital()
		SKILL_BITE:
			if _bite_variant() == BiteVariant.ASSAULT:
				return await _use_assault()
			return await _use_bite()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_SHARP:
			if _link.active and _lie_usable():
				title = "Lie Lie"
				text = "Passe curto para um aliado de fora da dupla, que ganha parte do bônus acumulado no próximo chute. O 1-2 termina."
			elif _link.active:
				title = "Sharp Sharp (1-2 ativo)"
				text = _link.exchange_description()
			else:
				title = "Sharp Sharp"
				text = _link.cast_description()
		SKILL_ORBITAL:
			title = "Orbital Orbital"
			text = ("Liga o Kurona a um aliado por uma corrente. Por %d rodadas, os dois ficam imunes a Carrinho, passam a bola mais longe e correm por mais tempo.\n"
				+ "Recarga: %d rodadas.") % [orbital_rounds, orbital_cooldown]
		SKILL_BITE:
			match _bite_variant():
				BiteVariant.BITE:
					title = "Bite Bite"
					text = "Carrinho mais longo que derruba inimigos. Se acertar a bola, ela vai em passe para o aliado mais próximo."
				BiteVariant.ASSAULT:
					title = "Assault Assault"
					text = "Voa até a bola no ar e passa rasteiro para o aliado mais próximo.\nRecarga: %d rodadas." % assault_cooldown
				_:
					title = "Bite Bite / Assault Assault"
					text = "Carrinho que derruba inimigos ou voo até a bola no ar, conforme a situação."
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()
	_clear_sharp()
	_clear_orbital()
	_bite_active = false
	_bite_pass_running = false
	slide_distance = _base_slide_distance


# ---------- LOOP / VISUAL ----------

func _process(delta: float) -> void:
	super(delta)
	if _orb_active and not _orbital_valid():
		_break_orbital()
	if _link.active or _orb_active:
		queue_redraw()   # as linhas acompanham os jogadores se mexendo


func _draw() -> void:
	super()
	var center := Vector2(0.0, -height)

	# Orbital: corrente de elos até o aliado (fica vermelha quando esticada no limite)
	if _orb_active and is_instance_valid(_orb_partner):
		var end: Vector2 = to_local(_orb_partner.global_position) + Vector2(0.0, -_orb_partner.height)
		var tension: float = global_position.distance_to(_orb_partner.global_position) / maxf(_orb_max_len, 1.0)
		var color: Color = ORBITAL_COLOR.lerp(Color(1.0, 0.35, 0.3), clampf((tension - 0.8) / 0.2, 0.0, 1.0))
		var length: float = center.distance_to(end)
		if length > 1.0:
			var dir: Vector2 = (end - center) / length
			var links: int = maxi(int(length / 14.0), 1)
			for i in range(links + 1):
				draw_arc(center + dir * (length * float(i) / float(links)), 5.0, 0.0, TAU, 12, color, 2.0)

	# Sharp Sharp: linha tracejada até o parceiro + bônus acumulado
	_link.draw_link(self, "  Lie Lie!" if _lie_ready else "")
