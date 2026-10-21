class_name Kurona
extends Player
## Ranze Kurona. Herda tudo do Player; script único. Visual: kurona_fx.gd (rosa opaco, tubarões e água; a marca do
## Kurona é uma mordida de tubarão). Cena: player.tscn herdada, script no nó raiz, nó raiz "Kurona".
##
## 1. Moon (recarga 2, compartilhada): bola no chão e aliado até 400. Passe rasteiro para ele e o KURONA corre (duração
##    reduzida); no fim, o aliado devolve a bola (QTE fácil) e CORRE com velocidade aumentada; por fim o Kurona devolve a
##    bola de novo (QTE fácil) e a sequência acaba. Passe interceptado ou QTE errado interrompem tudo.
##      Satellite (bola SUSPENSA): ele salta até a bola e passa rasteiro para um aliado (400). Quando o passe chega, escolhe
##      esse aliado ou outro como SATÉLITE (marca): o próximo Moon com ele tem +8% de velocidade e ele ganha +6% de chance
##      no próximo chute.
## 2. Close Quarter Dribble (recarga 2, compartilhada): bola no chão e inimigo próximo. Conduz a bola grudada em si com 3
##    dashes de 100 (a direção é escolhida a cada um). Inimigo no caminho = QTE fácil de drible: vencendo, passa por ele sem
##    perder velocidade; perdendo, é parado e a bola fica solta para a disputa. Terminou com a bola: +1 ação geral.
##      Teeth: persegue um inimigo (300) acompanhando os movimentos dele; na PRÓXIMA rodada, desabilita uma habilidade
##      ativável aleatória dele por 1 rodada.
## 3. Bite (recarga 2, compartilhada): sem a bola por perto, carrinho um pouco mais longo. Se alcançar a bola, lança-a como
##    o Carrinho normal, ativa o buff do próximo Moon (+8% de velocidade) e dá +1 ação geral.
##      Underwater (bola no chão, com ele): segura a bola e vai em direção a um aliado; chegando a 100, conecta os dois por 3
##      rodadas: o Moon ganha mais velocidade e +7% de chance, os dois ficam imunes a Carrinho. A conexão acaba se a distância
##      passar de 350 (uma ação de Correr mal planejada).
##
## O documento não dá três números, então ficaram como exports: bônus de chance base do Moon (0%), bônus de velocidade do
## Underwater no Moon (+12%) e o alcance para escolher o satélite (450).
## Animações opcionais: moon, satellite, close_quarter_dribble, teeth, bite, underwater.

const SKILL_MOON: StringName = &"moon"
const SKILL_DRIBBLE: StringName = &"close_quarter_dribble"
const SKILL_BITE: StringName = &"bite"

## Grupos de recarga (as variantes de cada habilidade compartilham o mesmo)
const CD_MOON: StringName = &"cd_moon"
const CD_DRIBBLE: StringName = &"cd_dribble"
const CD_BITE: StringName = &"cd_bite"

enum MoonVariant { NONE, MOON, SATELLITE }
enum DribbleVariant { NONE, DRIBBLE, TEETH }
enum BiteVariant { NONE, BITE, UNDERWATER }

@export_group("Moon / Satellite")
@export var moon_range: float = 400.0
@export_range(0.1, 1.0) var moon_first_run_mult: float = 0.5   # duração reduzida do Correr do Kurona
@export var moon_ally_speed_mult: float = 1.4                  # velocidade aumentada do Correr do aliado
@export_range(0.0, 1.0) var moon_shot_bonus: float = 0.0       # chance base do Moon (o documento não dá o número)
@export var moon_cooldown: int = 2
@export var satellite_reach: float = 180.0                     # até onde ele salta para pegar a bola suspensa
@export var satellite_pick_range: float = 450.0                # alcance para escolher o satélite
@export_range(0.0, 1.0) var satellite_speed_bonus: float = 0.08
@export_range(0.0, 1.0) var satellite_shot_bonus: float = 0.06

@export_group("Close Quarter Dribble / Teeth")
@export var dribble_dashes: int = 3
@export var dribble_dash_range: float = 150.0
@export var dribble_dash_speed: float = 720.0
@export var dribble_enemy_range: float = 300.0                 # "inimigo próximo" para poder usar
@export var dribble_hit_radius: float = 45.0                   # "encontrar" um inimigo no caminho
@export var dribble_cooldown: int = 2
@export var teeth_range: float = 300.0
@export var teeth_disable_rounds: int = 1

@export_group("Bite / Underwater")
@export var bite_distance_mult: float = 1.15                   # carrinho x este valor
@export_range(0.0, 1.0) var bite_buff_speed: float = 0.08      # buff do próximo Moon
@export var bite_cooldown: int = 2
@export var underwater_pick_range: float = 350.0
@export var underwater_stop_range: float = 100.0               # chegando aqui, a conexão começa
@export var underwater_speed: float = 460.0
@export var underwater_max_time: float = 1.6
@export var underwater_rounds: int = 3
@export var underwater_link_range: float = 350.0               # passou disso, a conexão acaba
@export_range(0.0, 1.0) var underwater_speed_bonus: float = 0.12   # extra no Moon (o documento não dá o número)
@export_range(0.0, 1.0) var underwater_shot_bonus: float = 0.07

@export_group("Descrição (hover)")
## Imagem de cada habilidade no balão. Chaves: moon, close_quarter_dribble, bite.
@export var skill_icons: Dictionary = {}

# ---------- ESTADO ----------
var _satellite: Player = null                 # marcado pelo Satellite
var _satellite_mark: KuronaFX.Mark = null
var _moon_buff: bool = false                  # buff do Bite para o próximo Moon
var _teeth_target: Player = null
var _teeth_round: int = -1
var _teeth_last: Vector2 = Vector2.ZERO
var _teeth_mark: KuronaFX.Mark = null
var _uw_active: bool = false
var _uw_partner: Player = null
var _uw_until_round: int = -1
var _uw_link: KuronaFX.Link = null
var _bite_active: bool = false
var _base_slide_distance: float = 0.0


func _init() -> void:
	character_id = "kurona"   # o menu de formação usa isto para saber quem é quem
	display_name = "Ranze Kurona"


func _ready() -> void:
	super()
	_base_slide_distance = slide_distance
	_hook_manager.call_deferred()


func _exit_tree() -> void:
	_clear_all()


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m:
		m.round_started.connect(_on_round_started)
		m.goal_scored.connect(_on_goal_scored)


func _on_round_started(round_number: int) -> void:
	if _teeth_target != null and round_number >= _teeth_round:
		_apply_teeth(round_number)
	if _uw_active and not _uw_valid():
		_end_underwater()
	queue_redraw()


## Gol: todo mundo volta para a formação, então tudo se desfaz
func _on_goal_scored(_goal: Dictionary) -> void:
	_end_underwater()
	_clear_teeth()
	_clear_satellite(false)
	_moon_buff = false


# ---------- AUXILIARES ----------

func _clamp_to_pitch(global_p: Vector2) -> Vector2:
	var field := get_tree().get_first_node_in_group("field") as Field
	if field == null:
		return global_p
	var half: Vector2 = field.pitch_size * 0.5 - Vector2(20.0, 20.0)
	var l: Vector2 = field.to_local(global_p)
	l.x = clampf(l.x, -half.x, half.x)
	l.y = clampf(l.y, -half.y, half.y)
	return field.to_global(l)


## Companheiros (menos o Kurona e os derrubados) a até range_px de "from"
func _allies_near(from: Vector2, range_px: float, ground_only: bool = false) -> Array[Player]:
	var result: Array[Player] = []
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p == self or p.team != team or p.is_down:
			continue
		if ground_only and p.height_level != Heights.Level.GROUND:
			continue
		if from.distance_to(p.global_position) <= range_px:
			result.append(p)
	return result


## Primeiro inimigo em pé, no chão e ainda não driblado, a até radius de "from"
func _enemy_near(from: Vector2, radius: float, skip: Array[Player] = []) -> Player:
	var best: Player = null
	var best_dist: float = INF
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p.team == team or p.is_down or p in skip:
			continue
		var d: float = from.distance_to(p.global_position)
		if d <= radius and d < best_dist:
			best_dist = d
			best = p
	return best


func _ball_ready(ball: Ball) -> bool:
	return ball != null and is_instance_valid(ball) and not ball.is_held() and not ball.is_locked_for(team)


## A bola parou encostada em "to" (o passe chegou sem ninguém interceptar)?
func _ball_arrived(ball: Ball, to: Player) -> bool:
	return ball.global_position.distance_to(to.global_position) <= to.body_radius + ball.collision_radius + 10.0


## Domina a bola: pairando nos pés dele até soltar
func _grab_ball(ball: Ball, dir: Vector2) -> void:
	ball.register_touch(self)
	var m: MatchManager = _get_manager()
	if m != null:
		m.clear_pending_pass()
	ball.hover_to(global_position + dir.normalized() * (body_radius + 18.0), 0.0, 0.08)


func _carry_ball(ball: Ball, dir: Vector2) -> void:
	ball.global_position = global_position + dir.normalized() * (body_radius + 18.0)
	ball.height = 0.0


## Uma ação de Correr (não conta no limite do turno) de "p", com duração e velocidade multiplicadas
func _timed_run(p: Player, duration_mult: float, speed_mult: float) -> void:
	var m: MatchManager = _get_manager()
	var saved_speed: float = p.move_speed
	var saved_duration: float = p.run_duration
	p.move_speed = saved_speed * speed_mult
	p.run_duration = saved_duration * duration_mult
	p.start_run()
	p.runs_this_turn = maxi(0, p.runs_this_turn - 1)
	while p.state == State.RUNNING and (m == null or not m.match_over):
		await get_tree().physics_frame
	p.move_speed = saved_speed
	p.run_duration = saved_duration


## Passe rasteiro de "from" para "to" (nadadeira de tubarão no caminho). true = a bola chegou.
func _pass_between(m: MatchManager, ball: Ball, from: Player, to: Player) -> bool:
	KuronaFX.fin(self, from.global_position, to.global_position, 0.45)
	KuronaFX.ball_trail(ball, 0.9)
	ball.collisions_paused = true
	await m.run_ground_pass(from, to, ball)
	ball.collisions_paused = false
	return _ball_arrived(ball, to)


## Devolução do Moon: QTE fácil e passe. false = errou o QTE ou interceptaram.
func _return_pass(m: MatchManager, ball: Ball, from: Player, to: Player) -> bool:
	var ok: bool = true
	if not skips_qte():
		ok = await m.run_qte(KickType.VOLLEY)
	if not ok:
		return false
	return await _pass_between(m, ball, from, to)


# ---------- HABILIDADE 1: MOON / SATELLITE ----------

func _moon_variant() -> MoonVariant:
	var ball: Ball = _get_ball()
	if is_down or not _ball_ready(ball):
		return MoonVariant.NONE
	var dist: float = global_position.distance_to(ball.global_position)
	if height_level == Heights.Level.GROUND and ball.get_level() == Heights.Level.GROUND and dist <= kick_range \
			and not _allies_near(global_position, moon_range, true).is_empty():
		return MoonVariant.MOON
	if height_level != Heights.Level.FLYING and ball.get_level() == Heights.Level.SUSPENDED and dist <= satellite_reach \
			and not _allies_near(global_position, moon_range, true).is_empty():
		return MoonVariant.SATELLITE
	return MoonVariant.NONE


## Bônus de velocidade do Moon com este aliado (Satellite, buff do Bite e Underwater somam)
func _moon_speed_bonus(ally: Player) -> float:
	var bonus: float = 0.0
	if ally == _satellite:
		bonus += satellite_speed_bonus
	if _moon_buff:
		bonus += bite_buff_speed
	if _uw_active and ally == _uw_partner:
		bonus += underwater_speed_bonus
	return bonus


func _moon_shot_bonus_for(ally: Player) -> float:
	return moon_shot_bonus + (underwater_shot_bonus if _uw_active and ally == _uw_partner else 0.0)


func _use_moon() -> bool:
	var m: MatchManager = _get_manager()
	var variant: MoonVariant = _moon_variant()
	if m == null or variant == MoonVariant.NONE:
		return false
	var only_grounded: Callable = func(o: Player) -> bool:
		return o.height_level == Heights.Level.GROUND and not o.is_down
	var ally: Player = await m.pick_ally_for_skill(self, moon_range, false, only_grounded)
	if ally == null or _moon_variant() != variant:
		return false   # cancelou (ou a situação mudou): não gasta a ação
	if variant == MoonVariant.SATELLITE:
		return await _satellite_pass(m, ally)
	return await _moon_sequence(m, ally)


## Passe, Kurona corre, devolução, aliado corre, devolução final
func _moon_sequence(m: MatchManager, ally: Player) -> bool:
	var ball: Ball = _get_ball()
	var speed_bonus: float = _moon_speed_bonus(ally)
	var shot_bonus: float = _moon_shot_bonus_for(ally)
	if ally == _satellite:
		_clear_satellite(true)
	_moon_buff = false
	start_cooldown(CD_MOON, moon_cooldown)

	if not await _pass_between(m, ball, self, ally):
		return true   # interceptado: a sequência acaba aqui
	await _timed_run(self, moon_first_run_mult, 1.0)
	if not await _return_pass(m, ball, ally, self):
		return true
	await _timed_run(ally, 1.0, moon_ally_speed_mult * (1.0 + speed_bonus))
	if not await _return_pass(m, ball, self, ally):
		return true
	if shot_bonus > 0.0:
		ally.next_shot_bonus = maxf(ally.next_shot_bonus, shot_bonus)
	return true


## Satellite: salta até a bola suspensa e passa rasteiro; quando chega, escolhe o satélite
func _satellite_pass(m: MatchManager, ally: Player) -> bool:
	var ball: Ball = _get_ball()
	start_cooldown(CD_MOON, moon_cooldown)
	await _leap_to_ball(ball)
	if not await _pass_between(m, ball, self, ally):
		return true   # interceptado: sem satélite
	var chosen: Player = await m.pick_ally_for_skill(self, satellite_pick_range, false,
		func(o: Player) -> bool: return not o.is_down)
	m._skill_pick_cancelled = false   # a escolha é opcional: cancelar não desfaz o passe
	if chosen == null:
		chosen = ally
	_set_satellite(chosen)
	return true


func _leap_to_ball(ball: Ball) -> void:
	var start: Vector2 = global_position
	var start_height: float = height
	var stop_dist: float = body_radius + ball.collision_radius + 6.0
	var duration: float = 0.25
	var t: float = 0.0
	KuronaFX.fin(self, start, ball.global_position, duration)
	while t < duration and is_inside_tree():
		await get_tree().process_frame
		t += get_process_delta_time()
		var k: float = clampf(t / duration, 0.0, 1.0)
		var away: Vector2 = start - ball.global_position
		var dir: Vector2 = away.normalized() if away.length() > 0.01 else Vector2(-facing, 0.0)
		face_towards(ball.global_position - global_position)
		global_position = start.lerp(_clamp_to_pitch(ball.global_position + dir * stop_dist), k)
		height = start_height + sin(k * PI) * 34.0
	height = start_height
	KuronaFX.chomp_burst(self, ball.global_position)


func _set_satellite(p: Player) -> void:
	_clear_satellite(false)
	_satellite = p
	_satellite_mark = KuronaFX.mark(p, true)
	p.next_shot_bonus = maxf(p.next_shot_bonus, satellite_shot_bonus)
	queue_redraw()


func _clear_satellite(burst: bool) -> void:
	if _satellite_mark != null and is_instance_valid(_satellite_mark):
		if burst:
			_satellite_mark.pop()
		else:
			_satellite_mark.queue_free()
	_satellite_mark = null
	_satellite = null


# ---------- HABILIDADE 2: CLOSE QUARTER DRIBBLE / TEETH ----------

func _dribble_variant() -> DribbleVariant:
	if is_down or height_level != Heights.Level.GROUND:
		return DribbleVariant.NONE
	var ball: Ball = _get_ball()
	if _ball_ready(ball) and ball.get_level() == Heights.Level.GROUND \
			and global_position.distance_to(ball.global_position) <= kick_range \
			and _enemy_near(global_position, dribble_enemy_range) != null:
		return DribbleVariant.DRIBBLE
	if _enemy_near(global_position, teeth_range) != null:
		return DribbleVariant.TEETH
	return DribbleVariant.NONE


func _use_dribble() -> bool:
	if _dribble_variant() == DribbleVariant.TEETH:
		return await _use_teeth()
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false
	var aim: Vector2 = await m.aim_for_skill(self, dribble_dash_range)
	if aim == Vector2.ZERO or _dribble_variant() != DribbleVariant.DRIBBLE:
		return false   # cancelou: não gasta a ação
	start_cooldown(CD_DRIBBLE, dribble_cooldown)

	_grab_ball(ball, aim)
	var shell: KuronaFX.Shell = KuronaFX.shell(ball)
	var beaten: Array[Player] = []
	var stopped: bool = false
	for i in dribble_dashes:
		if i > 0:   # muda de direção livremente entre os dashes; cancelar só encerra a ação
			aim = await m.aim_for_skill(self, dribble_dash_range)
			m._skill_pick_cancelled = false
			if aim == Vector2.ZERO:
				break
		face_towards(aim)
		stopped = await _dribble_dash(m, ball, aim, beaten)
		if stopped:
			break
	if shell != null:
		shell.release()
	ball.release_hover()   # a bola fica no chão: com ele, ou solta para a disputa se ele foi parado
	if not stopped:
		extra_general_left += 1   # terminou a ação com a bola
	return true


## Um dash de 100. true = o Kurona foi parado por um inimigo (perdeu o QTE de drible).
func _dribble_dash(m: MatchManager, ball: Ball, dir: Vector2, beaten: Array[Player]) -> bool:
	KuronaFX.fin(self, global_position, global_position + dir * dribble_dash_range,
		dribble_dash_range / dribble_dash_speed)
	var travelled: float = 0.0
	while travelled < dribble_dash_range and not m.match_over:
		await get_tree().physics_frame
		var step: float = minf(dribble_dash_speed * get_physics_process_delta_time(), dribble_dash_range - travelled)
		var next: Vector2 = _clamp_to_pitch(global_position + dir * step)
		var moved: float = global_position.distance_to(next)
		if moved < 0.5:
			break
		travelled += moved
		global_position = next
		_carry_ball(ball, dir)
		var enemy: Player = _enemy_near(global_position, dribble_hit_radius, beaten)
		if enemy != null:
			beaten.append(enemy)
			var won: bool = true
			if not skips_qte():
				won = await m.run_qte(KickType.VOLLEY)   # QTE fácil de drible
			if not won:
				KuronaFX.splash(self, global_position, 10, true)
				return true
			KuronaFX.splash(self, enemy.global_position, 8, false)   # passou direto, sem perder velocidade
	return false


## Teeth: marca e persegue um inimigo; na próxima rodada, desabilita uma habilidade dele
func _use_teeth() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var enemy: Player = await m.pick_ally_for_skill(self, teeth_range, true)
	if enemy == null:
		return false
	await play_action(&"teeth")
	_clear_teeth()
	_teeth_target = enemy
	_teeth_round = m.round_number + 1
	_teeth_last = enemy.global_position
	_teeth_mark = KuronaFX.mark(enemy, false)
	KuronaFX.jaws(self, enemy.global_position + Vector2(0.0, -enemy.height - 20.0), 40.0)
	start_cooldown(CD_DRIBBLE, dribble_cooldown)
	return true


## Acompanha os movimentos do marcado (só o que ele mesmo anda: corrida e carrinho)
func _follow_teeth() -> void:
	if _teeth_target == null:
		return
	if not is_instance_valid(_teeth_target):
		_clear_teeth()
		return
	var now: Vector2 = _teeth_target.global_position
	var d: Vector2 = now - _teeth_last
	_teeth_last = now
	if state == State.IDLE and (_teeth_target.state == State.RUNNING or _teeth_target.state == State.SLIDING) \
			and d.length() > 0.01 and d.length() < 60.0:
		global_position = _clamp_to_pitch(global_position + d)


func _apply_teeth(round_number: int) -> void:
	var target: Player = _teeth_target
	if is_instance_valid(target):
		var options: Array[StringName] = []
		for entry: Dictionary in target.get_skills():
			var id: StringName = StringName(entry["id"])
			if target.can_use_skill(id):
				options.append(id)
		if not options.is_empty():
			target.disabled_skills[options.pick_random()] = round_number + teeth_disable_rounds - 1
			KuronaFX.jaws(self, target.global_position + Vector2(0.0, -target.height - 20.0), 40.0)
	if _teeth_mark != null and is_instance_valid(_teeth_mark):
		_teeth_mark.pop()
	_teeth_mark = null
	_clear_teeth()


func _clear_teeth() -> void:
	if _teeth_mark != null and is_instance_valid(_teeth_mark):
		_teeth_mark.queue_free()
	_teeth_mark = null
	_teeth_target = null
	_teeth_round = -1


# ---------- HABILIDADE 3: BITE / UNDERWATER ----------

func _bite_variant() -> BiteVariant:
	if is_down or height_level != Heights.Level.GROUND:
		return BiteVariant.NONE
	var ball: Ball = _get_ball()
	if ball == null or global_position.distance_to(ball.global_position) > kick_range:
		return BiteVariant.BITE   # sem a bola por perto
	if _ball_ready(ball) and ball.get_level() == Heights.Level.GROUND \
			and not _allies_near(global_position, underwater_pick_range).is_empty():
		return BiteVariant.UNDERWATER
	return BiteVariant.NONE


func _use_bite() -> bool:
	if _bite_variant() == BiteVariant.UNDERWATER:
		return await _use_underwater()
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var distance: float = _base_slide_distance * bite_distance_mult
	var aim: Vector2 = await m.aim_for_skill(self, distance)
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação
	start_cooldown(CD_BITE, bite_cooldown)
	_bite_active = true
	slide_distance = distance
	KuronaFX.fin(self, global_position, global_position + aim * distance, 0.4)
	start_slide(aim)
	slides_this_turn -= 1   # é uma habilidade: não gasta o Carrinho geral do turno
	await slide_finished
	slide_distance = _base_slide_distance
	_bite_active = false
	return true


## Carrinho normal; se este carrinho de Bite acertou a bola, vem o buff do Moon e +1 ação geral
func _check_slide_hits() -> void:
	var had_ball: bool = _slide_hit_ball
	super()
	if _bite_active and not had_ball and _slide_hit_ball:
		_moon_buff = true
		extra_general_left += 1
		var ball: Ball = _get_ball()
		if ball != null:
			KuronaFX.jaws(self, ball.global_position, 36.0)
		queue_redraw()


## Underwater: segura a bola, vai até o aliado e, a 100 dele, conecta os dois por 3 rodadas
func _use_underwater() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false
	var only_alive: Callable = func(o: Player) -> bool: return not o.is_down
	var ally: Player = await m.pick_ally_for_skill(self, underwater_pick_range, false, only_alive)
	if ally == null or _bite_variant() != BiteVariant.UNDERWATER:
		return false   # cancelou: não gasta a ação
	if not await play_action(&"underwater"):
		return false

	_grab_ball(ball, ally.global_position - global_position)
	var shell: KuronaFX.Shell = KuronaFX.shell(ball)
	var reached: bool = false
	var t: float = 0.0
	while t < underwater_max_time and not m.match_over and is_instance_valid(ally):
		await get_tree().physics_frame
		var dt: float = get_physics_process_delta_time()
		t += dt
		var to: Vector2 = ally.global_position - global_position
		if to.length() <= underwater_stop_range:
			reached = true
			break
		var dir: Vector2 = to.normalized()
		face_towards(dir)
		global_position = _clamp_to_pitch(global_position + dir * minf(underwater_speed * dt, to.length() - underwater_stop_range + 1.0))
		_carry_ball(ball, dir)
	if shell != null:
		shell.release()
	ball.release_hover()
	if reached and is_instance_valid(ally):
		_start_underwater(m, ally)
	return true


func _start_underwater(m: MatchManager, ally: Player) -> void:
	_end_underwater()
	_uw_partner = ally
	_uw_until_round = m.round_number + underwater_rounds - 1   # a rodada atual conta
	_uw_active = true
	start_cooldown(CD_BITE, bite_cooldown, _uw_until_round + 1)
	slide_immune = true
	ally.slide_immune = true
	_uw_link = KuronaFX.link(self, ally, underwater_link_range)
	KuronaFX.splash(self, (global_position + ally.global_position) * 0.5, 12, true)
	queue_redraw()


func _uw_valid() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and is_instance_valid(_uw_partner) and m.round_number <= _uw_until_round


## A conexão acabou (duração, distância, gol): a recarga conta a partir do fim do efeito
func _end_underwater() -> void:
	if not _uw_active:
		return
	slide_immune = false
	if is_instance_valid(_uw_partner):
		_uw_partner.slide_immune = false
	if _uw_link != null and is_instance_valid(_uw_link):
		_uw_link.release()
	_uw_link = null
	_uw_active = false
	_uw_partner = null
	start_cooldown(CD_BITE, bite_cooldown, mini(get_current_round() + 1, _uw_until_round + 1))
	queue_redraw()


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func _moon_name() -> String:
	return "Satellite" if _moon_variant() == MoonVariant.SATELLITE else "Moon"


func _dribble_name() -> String:
	return "Teeth" if _dribble_variant() == DribbleVariant.TEETH else "Close Quarter Dribble"


func _bite_name() -> String:
	return "Underwater" if _bite_variant() == BiteVariant.UNDERWATER else "Bite"


func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"id": SKILL_MOON, "name": skill_label(_moon_name(), CD_MOON)})
	list.append({"id": SKILL_DRIBBLE, "name": skill_label(_dribble_name(), CD_DRIBBLE)})
	var bite_name: String = "Underwater (ativo)" if _uw_active else skill_label(_bite_name(), CD_BITE)
	list.append({"id": SKILL_BITE, "name": bite_name})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_MOON:
			return not is_on_cooldown(CD_MOON) and _moon_variant() != MoonVariant.NONE
		SKILL_DRIBBLE:
			return not is_on_cooldown(CD_DRIBBLE) and _dribble_variant() != DribbleVariant.NONE
		SKILL_BITE:
			var variant: BiteVariant = _bite_variant()
			return not is_on_cooldown(CD_BITE) and (variant == BiteVariant.BITE \
				or (variant == BiteVariant.UNDERWATER and not _uw_active))
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_MOON:
			return await _use_moon()
		SKILL_DRIBBLE:
			return await _use_dribble()
		SKILL_BITE:
			return await _use_bite()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_MOON:
			if _moon_variant() == MoonVariant.SATELLITE:
				title = "Satellite"
				text = ("Salta até a bola suspensa e passa rasteiro para um aliado (%d). Quando o passe chega, escolhe esse ou outro "
					+ "aliado como satélite: o próximo Moon com ele tem +%d%% de velocidade e ele ganha +%d%% de chance no próximo chute.\n"
					+ "Recarga: %d rodadas.") % [int(moon_range), _pct(satellite_speed_bonus), _pct(satellite_shot_bonus), moon_cooldown]
			else:
				title = "Moon"
				text = ("Passe rasteiro para um aliado (%d) e o Kurona corre (duração reduzida). O aliado devolve a bola (QTE fácil) e "
					+ "corre mais rápido; o Kurona devolve de novo (QTE fácil) e acaba. Passe interceptado interrompe a sequência.\n"
					+ "Recarga: %d rodadas.") % [int(moon_range), moon_cooldown]
		SKILL_DRIBBLE:
			if _dribble_variant() == DribbleVariant.TEETH:
				title = "Teeth"
				text = ("Persegue um inimigo (%d), acompanhando os movimentos dele. Na próxima rodada, desabilita uma habilidade "
					+ "ativável aleatória dele por %d rodada.\nRecarga: %d rodadas.") % [int(teeth_range), teeth_disable_rounds, dribble_cooldown]
			else:
				title = "Close Quarter Dribble"
				text = ("Conduz a bola colada em si com %d dashes de %d, mudando de direção a cada um. Inimigo no caminho = QTE fácil de "
					+ "drible: vencendo, passa por ele; perdendo, é parado e a bola fica solta. Terminou com a bola: +1 ação geral.\n"
					+ "Recarga: %d rodadas.") % [dribble_dashes, int(dribble_dash_range), dribble_cooldown]
		SKILL_BITE:
			if _bite_variant() == BiteVariant.UNDERWATER or _uw_active:
				title = "Underwater"
				text = ("Segura a bola e vai até um aliado; a %d dele, conecta os dois por %d rodadas: o Moon ganha mais velocidade e "
					+ "+%d%% de chance, e os dois ficam imunes a Carrinho. Acaba se a distância passar de %d.\nRecarga: %d rodadas.") % [
					int(underwater_stop_range), underwater_rounds, _pct(underwater_shot_bonus), int(underwater_link_range), bite_cooldown]
			else:
				title = "Bite"
				text = ("Carrinho um pouco mais longo. Se alcançar a bola, lança-a como o Carrinho normal, ativa o buff do próximo Moon "
					+ "(+%d%% de velocidade) e dá +1 ação geral.\nRecarga: %d rodadas.") % [_pct(bite_buff_speed), bite_cooldown]
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA ----------

func _clear_all() -> void:
	_end_underwater()
	_clear_teeth()
	_clear_satellite(false)
	_moon_buff = false


func reset_for_new_match() -> void:
	super()
	_clear_all()
	_bite_active = false
	slide_distance = _base_slide_distance


# ---------- LOOP / VISUAL ----------

func _physics_process(delta: float) -> void:
	super(delta)
	_follow_teeth()
	if _uw_active:
		if not _uw_valid() or global_position.distance_to(_uw_partner.global_position) > underwater_link_range:
			_end_underwater()   # a rodada acabou ou uma corrida mal planejada passou do alcance


func _draw() -> void:
	super()
	# Buff do Bite para o próximo Moon: anel rosa em volta dele
	if _moon_buff:
		var center := Vector2(0.0, -height)
		draw_arc(center, placeholder_radius + 9.0, 0.0, TAU, 28, Color(KuronaFX.PINK, 0.9), 2.0)
		draw_arc(center, placeholder_radius + 13.0, 0.0, TAU, 28, Color(KuronaFX.PINK_LIGHT, 0.5), 1.5)
