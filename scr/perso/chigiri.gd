class_name Chigiri
extends Player
## Chigiri Hyoma. Herda tudo do Player; script único. Visual: chigiri_fx.gd (vermelho/rosa com detalhes de velocidade,
## uma pantera vermelha translúcida que o segue e a Golden Zone dourada com bloom). Cena: player.tscn herdada, script no
## nó raiz, nó raiz "Chigiri".
##
## 1. Match Cut-In (recarga 2, compartilhada): Chigiri e bola no chão. Domina a bola (colada nele), dash de 150 para o lado
##    mais longe do inimigo próximo, dash de 180 para frente e um chute que SOBE (1.1x de força, 45% de chance).
##      Once More (Chigiri SUSPENSO, sem a bola): dash aéreo de 260. Achando a bola suspensa, domina ela e desce ao chão;
##      depois corre (Correr com 1.2x de velocidade) com a bola grudada.
## 2. Red Princess (recarga 2): Chigiri e bola no chão: cruzamento longo (530) para um aliado a pelo menos 300; cumprido o
##    requisito, ele ganha um dash de 250 (a direção é escolhida depois do cruzamento).
## 3. Non-Stop (recarga 2): dash de 200. Achando a bola no chão, joga ela para frente a mesma distância que ele andou para
##    alcançá-la; passando num QTE fácil ele vai até ela e ganha um uso GRATUITO do Match Cut-In (se não estiver em recarga).
## 4. Golden Zone (recarga 2 após o fim da zona): zona dourada na ponta ESQUERDA, fora da área do goleiro, por 2 rodadas.
##    Dentro dela: +8% em qualquer chute, +40 de alcance no Passe e o complemento 44 Pant.
##      44 Pant (uso único por zona): dentro da zona, Chigiri no chão/suspenso e bola no chão/suspensa: chute de 1.3x de
##      força que sobe até Suspenso, 47% de chance (sem o bônus da zona).
##
## NOVIDADES vs. o script anterior: a corrida acelerada passiva (Accelerate) saiu, porque o documento novo não a tem; a zona
## agora é na ponta ESQUERDA (golden_zone_flip_side inverte); o Miau! saiu. A zona conta a rodada atual como a 1ª das 2.
## Animações opcionais: match_cut_in, once_more, red_princess, non_stop, golden_zone, pant_44.
##
## PEÇAS NO RESTO DO PROJETO (já aplicadas antes): field.gd: get_goal_area_rect(team).

const SKILL_CUTIN: StringName = &"match_cut_in"
const SKILL_CUTIN_FREE: StringName = &"match_cut_in_free"
const SKILL_PRINCESS: StringName = &"red_princess"
const SKILL_NONSTOP: StringName = &"non_stop"
const SKILL_ZONE: StringName = &"golden_zone"

## Grupos de recarga (as variantes de cada habilidade compartilham o mesmo)
const CD_CUTIN: StringName = &"cd_cutin"
const CD_PRINCESS: StringName = &"cd_princess"
const CD_NONSTOP: StringName = &"cd_nonstop"
const CD_ZONE: StringName = &"cd_zone"

enum CutinVariant { NONE, MATCH_CUT_IN, ONCE_MORE }
enum ZoneVariant { NONE, CREATE, SHOT }

@export_group("Match Cut-In / Once More")
@export var cutin_side_dash: float = 150.0
@export var cutin_forward_dash: float = 180.0
@export var cutin_force_mult: float = 0.53
@export_range(0.0, 1.0) var cutin_chance: float = 0.45
@export var cutin_cooldown: int = 2
@export var dash_speed: float = 850.0              # velocidade dos dashes (px/s)
@export var ball_offset: float = 24.0              # a bola fica à frente dele enquanto ele a segura
@export var once_more_range: float = 300.0
@export var once_more_run_mult: float = 1.3        # velocidade da corrida com a bola grudada

@export_group("Red Princess")
@export var red_princess_range: float = 530.0
@export var red_princess_min_range: float = 300.0  # o aliado tem que estar pelo menos este tanto longe
@export var red_princess_dash: float = 350.0
@export var red_princess_rise_time: float = 0.5
@export var red_princess_fall_time: float = 0.55
@export var red_princess_cooldown: int = 2

@export_group("Non-Stop")
@export var non_stop_range: float = 350.0
@export var non_stop_cooldown: int = 2

@export_group("Golden Zone / 44 Pant")
@export var golden_zone_rounds: int = 2
@export var golden_zone_cooldown: int = 2          # conta a partir do fim da zona
@export var golden_zone_radius: float = 90.0
## O quanto o centro do círculo fica empurrado para FORA da caixa, a partir do canto externo (maior que o raio)
@export var golden_zone_outside_margin: float = 180.0
## Inverte o lado da zona se "esquerda" saiu do lado errado na sua tela (a esquerda é a de quem ataca aquele gol)
@export var golden_zone_flip_side: bool = false
@export_range(0.0, 1.0) var zone_kick_bonus: float = 0.08
@export var zone_pass_bonus: float = 40.0
@export_range(0.0, 1.0) var pant_chance: float = 0.47
@export var pant_force_mult: float = 0.9
## Liga sozinho o glow do jogo (WorldEnvironment) para o dourado da zona brilhar de verdade; veja chigiri_fx.gd
@export var enable_golden_bloom: bool = false

@export_group("Visual / Descrição")
## Aura + partículas dos chutes. Vazio = vermelho/rosa de velocidade (veja _make_kick_fx)
@export var kick_fx: KickFX
## Imagem de cada habilidade no balão. Chaves: match_cut_in, red_princess, non_stop, golden_zone.
@export var skill_icons: Dictionary = {}

var _zone_until_round: int = -1
var _zone_center: Vector2 = Vector2.ZERO
var _zone_fx: ChigiriFX.Zone = null
var _pant_used: bool = false
var _zone_bonus_on: bool = false          # o bônus de alcance do Passe está aplicado agora
var _cutin_free: bool = false             # o Non-Stop deu um Match Cut-In grátis
var _panther: ChigiriFX.Panther = null
var _found_ball: bool = false             # um dash achou a bola no caminho
var _rise_on_kick: bool = false
var _carry_dir: Vector2 = Vector2.RIGHT


func _init() -> void:
	character_id = "chigiri"   # o menu de formação usa isto para saber quem é quem
	display_name = "Chigiri"


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = _make_kick_fx()
	_panther = ChigiriFX.panther(self)
	_hook_manager.call_deferred()


func _exit_tree() -> void:
	_end_zone()


## Vermelho/rosa com cara de velocidade: faixa larga, lascas em disparada e um estouro forte
func _make_kick_fx() -> KickFX:
	var fx := KickFX.new()
	fx.color = Color(1.0, 0.2, 0.28, 1.0)
	fx.trail_width = 18.0
	fx.shape = KickFX.Shape.SQUARE
	fx.particle_color = Color(1.0, 0.55, 0.7, 1.0)
	fx.amount = 28
	fx.lifetime = 0.4
	fx.speed_min = 80.0
	fx.speed_max = 240.0
	fx.gravity = Vector2.ZERO
	fx.spin = 0.0
	fx.scale_min = 0.1
	fx.scale_max = 0.3
	fx.burst_amount = 22
	fx.burst_speed = 340.0
	return fx


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m:
		m.round_started.connect(_on_round_started)
		m.sides_swapped.connect(_on_sides_swapped)
		m.turn_ended.connect(_on_turn_ended)


func _on_round_started(new_round: int) -> void:
	if _zone_until_round >= 0 and new_round > _zone_until_round:
		_end_zone()   # a zona expirou


func _on_turn_ended(ended_team: int) -> void:
	if ended_team == team:
		_cutin_free = false   # o Match Cut-In grátis só vale neste turno


## Virou o lado no 2º tempo: a zona vai para a ponta equivalente do gol que ele ataca agora
func _on_sides_swapped() -> void:
	if _zone_until_round >= 0:
		_zone_center = _golden_zone_corner()
		if _zone_fx != null and is_instance_valid(_zone_fx):
			_zone_fx.recenter(_zone_center)


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


func _ball_ok(ball: Ball) -> bool:
	return ball != null and is_instance_valid(ball) and not ball.is_held() and not ball.is_locked_for(team)


func _near_ball(ball: Ball) -> bool:
	return global_position.distance_to(ball.global_position) <= kick_range


## Avança "dist" na direção "dir" a dash_speed, deixando a faixa de velocidade. A cada quadro chama on_step(percorrido);
## se ela devolver true, o dash para ali. Devolve o quanto andou.
func _dash(dir: Vector2, dist: float, on_step: Callable = Callable()) -> float:
	var m: MatchManager = _get_manager()
	face_towards(dir)
	var trail: ChigiriFX.Dash = ChigiriFX.dash(self, placeholder_radius)
	var travelled: float = 0.0
	while travelled < dist and (m == null or not m.match_over):
		await get_tree().physics_frame
		var step: float = minf(dash_speed * get_physics_process_delta_time(), dist - travelled)
		var next: Vector2 = _clamp_to_pitch(global_position + dir * step)
		var moved: float = global_position.distance_to(next)
		if moved < 0.5:
			break
		travelled += moved
		global_position = next
		if trail != null:
			trail.add_point(global_position)
		if on_step.is_valid() and on_step.call(travelled):
			break
	if trail != null:
		trail.finish()
	return travelled


func _hold_point() -> Vector2:
	return global_position + _carry_dir * ball_offset


## Domina a bola: ela fica pairando à frente dele, acompanhando
func _grab_ball(ball: Ball) -> void:
	var m: MatchManager = _get_manager()
	if m != null:
		m.clear_pending_pass()   # se a bola era um passe alto em andamento, ele deixa de valer
	ball.register_touch(self)
	ball.hover_to(_hold_point(), height, 0.08)
	ball.fx_during_hover = true
	if kick_fx:
		ball.play_fx(kick_fx)


func _carry(ball: Ball) -> void:
	if is_instance_valid(ball):
		ball.global_position = _hold_point()
		ball.height = height


func _drop_ball(ball: Ball) -> void:
	if is_instance_valid(ball) and ball.hovering and not ball.is_held():
		ball.release_hover()
		ball.velocity = Vector2.ZERO
		ball.fx_during_hover = false


## Quando o chute sai: a bola sobe (se pedido), estouro de velocidade e a pantera dá o bote
func _on_kick_fx(ball: Ball, dir: Vector2, _speed: float) -> void:
	if _rise_on_kick:
		var rise: float = maxf(0.0, Heights.SUSPENDED_HEIGHT - ball.height)
		ball.vel_z = Heights.lift_for_peak(rise, ball.gravity)
	ChigiriFX.kick_burst(self, ball.global_position, dir)
	if _panther != null and is_instance_valid(_panther):
		_panther.pounce(ball.global_position)


## Lado do dash curto: perpendicular à mira, para longe do inimigo mais próximo
func _side_direction(aim: Vector2) -> Vector2:
	var perp: Vector2 = aim.orthogonal()
	var nearest: Player = null
	var best: float = INF
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p.team == team or p.is_down:
			continue
		var d: float = global_position.distance_to(p.global_position)
		if d < best:
			best = d
			nearest = p
	if nearest != null and (nearest.global_position - global_position).dot(perp) > 0.0:
		return -perp
	return perp


# ---------- HABILIDADE 1: MATCH CUT-IN / ONCE MORE ----------

func get_cutin_variant() -> CutinVariant:
	if is_down:
		return CutinVariant.NONE
	if height_level == Heights.Level.SUSPENDED:
		var ball: Ball = _get_ball()
		if ball == null or not _near_ball(ball):   # "sem a bola"
			return CutinVariant.ONCE_MORE
		return CutinVariant.NONE
	if height_level == Heights.Level.GROUND:
		var b: Ball = _get_ball()
		if _ball_ok(b) and b.get_level() == Heights.Level.GROUND and _near_ball(b):
			return CutinVariant.MATCH_CUT_IN
	return CutinVariant.NONE


func _use_cutin(free: bool) -> bool:
	match get_cutin_variant():
		CutinVariant.MATCH_CUT_IN:
			return await _match_cut_in(free)
		CutinVariant.ONCE_MORE:
			return await _once_more()
	return false


## Domina a bola, dash para o lado, dash para frente (sempre com a bola) e chute que sobe
func _match_cut_in(free: bool) -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO or get_cutin_variant() != CutinVariant.MATCH_CUT_IN:
		return false   # cancelou (ou a bola saiu do alcance): não gasta a ação
	aim = aim.normalized()
	var side: Vector2 = _side_direction(aim)

	_carry_dir = aim
	face_towards(aim)
	_grab_ball(ball)
	await get_tree().create_timer(0.1).timeout   # a bola chega nos pés
	var carry: Callable = func(_t: float) -> bool:
		_carry(ball)
		return false
	_carry_dir = side
	await _dash(side, cutin_side_dash, carry)
	_carry_dir = aim
	await _dash(aim, cutin_forward_dash, carry)

	# Chute que sobe: dentro da Golden Zone, +8% (a chance é conferida na hora do chute)
	var chance: float = cutin_chance + (zone_kick_bonus if _in_golden_zone() else 0.0)
	face_towards(aim)
	ball.fx_during_hover = false
	next_kick_force_mult *= cutin_force_mult
	_rise_on_kick = true
	await kick_ball(ball, aim, KickType.GROUND, true, chance, false, kick_fx, &"match_cut_in", _on_kick_fx)
	_drop_ball(ball)   # se o chute foi cancelado, a bola não fica presa
	start_cooldown(CD_CUTIN, cutin_cooldown)
	if free:
		_cutin_free = false
	queue_redraw()
	return true


## Once More: dash aéreo; achando a bola suspensa, domina, desce ao chão e corre com ela grudada
func _once_more() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var aim: Vector2 = await m.aim_for_skill(self, once_more_range)
	if aim == Vector2.ZERO or get_cutin_variant() != CutinVariant.ONCE_MORE:
		return false
	if not await play_action(&"once_more"):
		return false
	start_cooldown(CD_CUTIN, cutin_cooldown)   # entra em recarga mesmo se não achar a bola

	var ball: Ball = _get_ball()
	_found_ball = false
	var find: Callable = func(_t: float) -> bool:
		if _ball_ok(ball) and ball.get_level() == Heights.Level.SUSPENDED \
				and global_position.distance_to(ball.global_position) <= body_radius + ball.collision_radius + 26.0:
			_found_ball = true
			return true
		return false
	await _dash(aim, once_more_range, find)
	if not _found_ball or not is_instance_valid(ball):
		return true   # não achou: continua suspenso

	land()   # dominou a bola: desce para o chão
	_carry_dir = aim
	ball.release_hover()
	ball.velocity = Vector2.ZERO
	ball.vel_z = 0.0
	_grab_ball(ball)
	ChigiriFX.sparks(self, global_position, 10)
	# Correr com 1.2x de velocidade e a bola grudada
	var saved_speed: float = move_speed
	move_speed = saved_speed * once_more_run_mult
	start_run()
	runs_this_turn = maxi(0, runs_this_turn - 1)   # é habilidade: não conta como a ação Correr
	while state == State.RUNNING and not m.match_over:
		await get_tree().physics_frame
		if velocity.length() > 1.0:
			_carry_dir = velocity.normalized()
		_carry(ball)
	move_speed = saved_speed
	_drop_ball(ball)
	return true


# ---------- HABILIDADE 2: RED PRINCESS ----------

func _princess_ready() -> bool:
	var ball: Ball = _get_ball()
	if is_down or height_level != Heights.Level.GROUND or not _ball_ok(ball):
		return false
	if ball.get_level() != Heights.Level.GROUND or not _near_ball(ball):
		return false
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p != self and p.team == team and not p.is_down:
			var d: float = global_position.distance_to(p.global_position)
			if d >= red_princess_min_range and d <= red_princess_range:
				return true
	return false


## Cruzamento longo: a bola sobe a Voando no meio do caminho e desce NO CHÃO nos pés do aliado; depois, um dash
func _use_red_princess() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false
	var far_enough: Callable = func(other: Player) -> bool:
		return global_position.distance_to(other.global_position) >= red_princess_min_range
	var target: Player = await m.pick_ally_for_skill(self, red_princess_range, false, far_enough)
	if target == null or not _princess_ready():
		return false   # cancelou (ou a situação mudou): não gasta a ação

	face_towards(target.global_position - global_position)
	if not await play_action(&"red_princess", ANIM_PASS_HIGH):
		return false
	start_cooldown(CD_PRINCESS, red_princess_cooldown)

	ball.register_touch(self)   # o cruzamento não usa kick(), então registra o toque aqui
	if kick_fx:
		ball.fx_during_hover = true
		ball.play_fx(kick_fx)
	ChigiriFX.kick_burst(self, ball.global_position, target.global_position - global_position)
	if _panther != null and is_instance_valid(_panther):
		_panther.pounce(ball.global_position)

	var start: Vector2 = ball.global_position
	var to_target: Vector2 = target.global_position - start
	var dist: float = to_target.length()
	var gap: float = ball.collision_radius + target.body_radius + 2.0
	var end_point: Vector2 = start
	if dist > 0.001:
		end_point = start + to_target / dist * maxf(dist - gap, 0.0)
	var rise: Tween = ball.hover_to((start + end_point) * 0.5, Heights.FLYING_HEIGHT, red_princess_rise_time)
	await rise.finished
	var fall: Tween = ball.hover_to(end_point, Heights.GROUND_HEIGHT, red_princess_fall_time)
	await fall.finished
	ball.release_hover()
	ball.velocity = Vector2.ZERO
	ball.vel_z = 0.0
	ball.height = 0.0
	ball.fx_during_hover = false
	ball.register_touch(self)
	m.pass_completed.emit(self, target)

	# Requisito de distância cumprido: ganha um dash (a direção é escolhida agora; cancelar só pula o dash)
	var aim: Vector2 = await m.aim_for_skill(self, red_princess_dash)
	m._skill_pick_cancelled = false
	if aim != Vector2.ZERO:
		await _dash(aim, red_princess_dash)
	return true


# ---------- HABILIDADE 3: NON-STOP ----------

func _nonstop_ready() -> bool:
	return not is_down and height_level == Heights.Level.GROUND


## Dash de 200. Achando a bola no chão, joga ela para frente a mesma distância que ele andou; QTE fácil: vai até ela e
## ganha um Match Cut-In grátis (se não estiver em recarga)
func _use_nonstop() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var aim: Vector2 = await m.aim_for_skill(self, non_stop_range)
	if aim == Vector2.ZERO or not _nonstop_ready():
		return false
	start_cooldown(CD_NONSTOP, non_stop_cooldown)

	var ball: Ball = _get_ball()
	_found_ball = false
	var find: Callable = func(_t: float) -> bool:
		if _ball_ok(ball) and ball.get_level() == Heights.Level.GROUND \
				and global_position.distance_to(ball.global_position) <= body_radius + ball.collision_radius + 26.0:
			_found_ball = true
			return true
		return false
	var travelled: float = await _dash(aim, non_stop_range, find)
	if not _found_ball or not is_instance_valid(ball):
		return true   # não achou a bola: foi só o dash

	# Joga a bola para frente (a mesma distância que ele andou para alcançá-la)
	var dest: Vector2 = _clamp_to_pitch(ball.global_position + aim * maxf(travelled, 60.0))
	m.clear_pending_pass()
	ball.register_touch(self)
	var throw: Tween = ball.hover_to(dest, 0.0, 0.3)
	ChigiriFX.kick_burst(self, ball.global_position, aim)
	ChigiriFX.ball_trail(ball, 0.6)
	var ok: bool = true
	if not skips_qte():
		ok = await m.run_qte(KickType.VOLLEY)   # QTE fácil
	if throw.is_valid() and throw.is_running():
		await throw.finished
	if is_instance_valid(ball):
		ball.release_hover()
		ball.velocity = Vector2.ZERO
	if ok and is_instance_valid(ball):
		var to_ball: Vector2 = ball.global_position - global_position
		var reach: float = to_ball.length() - (body_radius + ball.collision_radius + 4.0)
		if reach > 1.0:
			await _dash(to_ball.normalized(), reach)
		_cutin_free = not is_on_cooldown(CD_CUTIN)   # o complemento só vale se o Match Cut-In não estiver em recarga
		queue_redraw()
	return true


# ---------- HABILIDADE 4: GOLDEN ZONE / 44 PANT ----------

func is_zone_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _zone_until_round >= 0 and m.round_number <= _zone_until_round


## Chigiri está DENTRO da zona ativa agora?
func _in_golden_zone() -> bool:
	return is_zone_active() and global_position.distance_to(_zone_center) <= golden_zone_radius


func get_zone_variant() -> ZoneVariant:
	if not is_zone_active():
		return ZoneVariant.CREATE
	if is_down or _pant_used or height_level == Heights.Level.FLYING or not _in_golden_zone():
		return ZoneVariant.NONE
	var ball: Ball = _get_ball()
	if ball != null and _ball_ok(ball) and ball.get_level() != Heights.Level.FLYING and get_kick_type(ball) != KickType.NONE:
		return ZoneVariant.SHOT
	return ZoneVariant.NONE


## +8% em qualquer chute dele de dentro da zona (os chutes de habilidade com chance própria somam por conta própria)
func get_shot_chance(kind: KickType) -> float:
	var base: float = super(kind)
	if _in_golden_zone():
		base += zone_kick_bonus
	return base


## Ponta ESQUERDA (de quem ataca aquele gol) e para FORA da pequena área do gol que o adversário defende. Empurrada para
## fora da caixa, a partir do canto externo. Se saiu do lado errado na sua tela, use golden_zone_flip_side.
func _golden_zone_corner() -> Vector2:
	var field := get_tree().get_first_node_in_group("field") as Field
	if field == null:
		return global_position
	var enemy_team: int = 1 - team
	var rect: Rect2 = field.get_goal_area_rect(enemy_team)
	var forward: Vector2 = Vector2(get_attack_dir(), 0.0)
	var left: Vector2 = -forward.rotated(deg_to_rad(90.0))   # a esquerda de quem ataca
	if golden_zone_flip_side:
		left = -left
	var external_x: float = rect.position.x if forward.x > 0.0 else rect.end.x
	var corner_y: float = rect.end.y if left.y > 0.0 else rect.position.y
	var corner := Vector2(external_x, corner_y)
	var safe_margin: float = maxf(golden_zone_outside_margin, golden_zone_radius + 20.0)
	var push := Vector2(-forward.x, signf(corner_y - rect.get_center().y)) * safe_margin
	var spot: Vector2 = corner + push
	var half: Vector2 = field.pitch_size * 0.5
	spot = Vector2(clampf(spot.x, -half.x, half.x), clampf(spot.y, -half.y, half.y))
	return field.to_global(spot)


func _create_golden_zone() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	await play_action(&"golden_zone")
	_zone_center = _golden_zone_corner()
	_zone_until_round = m.round_number + golden_zone_rounds - 1   # a rodada atual conta
	_pant_used = false
	start_cooldown(CD_ZONE, golden_zone_cooldown, _zone_until_round + 1)   # recarga a partir do fim da zona
	if enable_golden_bloom:
		ChigiriFX.enable_bloom(self)
	if _zone_fx != null and is_instance_valid(_zone_fx):
		_zone_fx.dismiss()
	_zone_fx = ChigiriFX.zone(self, _zone_center, golden_zone_radius)
	if _zone_fx != null:
		_zone_fx.pulse()
	queue_redraw()
	return true


func _end_zone() -> void:
	_zone_until_round = -1
	if _zone_fx != null and is_instance_valid(_zone_fx):
		_zone_fx.dismiss()
	_zone_fx = null
	if _zone_bonus_on:
		pass_range_bonus -= zone_pass_bonus
		_zone_bonus_on = false


## 44 Pant: chute de dentro da zona, 1.3x de força, sobe até Suspenso, 47% de chance. Uso único por zona.
func _use_44_pant() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO or get_zone_variant() != ZoneVariant.SHOT:
		return false   # cancelou (ou saiu da zona / a bola fugiu): não gasta a ação
	var kind: KickType = get_kick_type(ball)
	var qte_ok: bool = true
	if kind != KickType.GROUND and not skips_qte():
		qte_ok = await m.run_qte(kind)
	_pant_used = true
	next_kick_force_mult *= pant_force_mult
	_rise_on_kick = kind == KickType.GROUND or kind == KickType.HIGH_BALL   # o voleio já sobe sozinho
	await kick_ball(ball, aim, kind, qte_ok, pant_chance, false, kick_fx if qte_ok else null, &"pant_44", _on_kick_fx)
	if _zone_fx != null and is_instance_valid(_zone_fx):
		_zone_fx.pulse()
	return true


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func _cutin_name() -> String:
	return "Once More" if get_cutin_variant() == CutinVariant.ONCE_MORE else "Match Cut-In"


func _zone_name() -> String:
	return "44 Pant" if get_zone_variant() == ZoneVariant.SHOT or (is_zone_active() and _in_golden_zone()) else "Golden Zone"


func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	list.append({"id": SKILL_CUTIN, "name": skill_label(_cutin_name(), CD_CUTIN)})
	if _cutin_free:
		list.append({"id": SKILL_CUTIN_FREE, "name": "Match Cut-In (grátis)"})
	list.append({"id": SKILL_PRINCESS, "name": skill_label("Red Princess", CD_PRINCESS)})
	list.append({"id": SKILL_NONSTOP, "name": skill_label("Non-Stop", CD_NONSTOP)})
	list.append({"id": SKILL_ZONE, "name": skill_label(_zone_name(), CD_ZONE)})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_CUTIN:
			return not is_on_cooldown(CD_CUTIN) and get_cutin_variant() != CutinVariant.NONE
		SKILL_CUTIN_FREE:
			return _cutin_free and get_cutin_variant() == CutinVariant.MATCH_CUT_IN
		SKILL_PRINCESS:
			return not is_on_cooldown(CD_PRINCESS) and _princess_ready()
		SKILL_NONSTOP:
			return not is_on_cooldown(CD_NONSTOP) and _nonstop_ready()
		SKILL_ZONE:
			match get_zone_variant():
				ZoneVariant.CREATE:
					return not is_on_cooldown(CD_ZONE)
				ZoneVariant.SHOT:
					return true   # sem recarga própria: uso único por zona
			return false
	return false


## O Match Cut-In que o Non-Stop dá é GRATUITO (ver player.gd: skill_is_free / has_free_followup)
func skill_is_free(skill_id: StringName) -> bool:
	return skill_id == SKILL_CUTIN_FREE


func has_free_followup() -> bool:
	return _cutin_free


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_CUTIN:
			return await _use_cutin(false)
		SKILL_CUTIN_FREE:
			return await _use_cutin(true)
		SKILL_PRINCESS:
			return await _use_red_princess()
		SKILL_NONSTOP:
			return await _use_nonstop()
		SKILL_ZONE:
			if get_zone_variant() == ZoneVariant.SHOT:
				return await _use_44_pant()
			return await _create_golden_zone()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_CUTIN, SKILL_CUTIN_FREE:
			if get_cutin_variant() == CutinVariant.ONCE_MORE:
				title = "Once More"
				text = ("Dash aéreo de %d (sem a bola). Achando a bola suspensa, domina ela, desce ao chão e corre com ela grudada "
					+ "(%.1fx de velocidade).\nRecarga: %d rodadas.") % [int(once_more_range), once_more_run_mult, cutin_cooldown]
			else:
				title = "Match Cut-In" + (" (grátis)" if skill_id == SKILL_CUTIN_FREE else "")
				text = ("Domina a bola, dash de %d para o lado mais longe do inimigo, dash de %d para frente e um chute que sobe "
					+ "(%.1fx de força, %d%% de chance, +%d%% na Golden Zone).\nRecarga: %d rodadas.") % [
					int(cutin_side_dash), int(cutin_forward_dash), cutin_force_mult, _pct(cutin_chance), _pct(zone_kick_bonus), cutin_cooldown]
		SKILL_PRINCESS:
			title = "Red Princess"
			text = ("Cruzamento longo (%d) para um aliado a pelo menos %d; a bola desce nos pés dele. Cumprido o requisito, "
				+ "Chigiri ganha um dash de %d.\nRecarga: %d rodadas.") % [
				int(red_princess_range), int(red_princess_min_range), int(red_princess_dash), red_princess_cooldown]
		SKILL_NONSTOP:
			title = "Non-Stop"
			text = ("Dash de %d. Achando a bola no chão, joga ela para frente a mesma distância que andou; com um QTE fácil, vai até ela "
				+ "e ganha um Match Cut-In grátis (se não estiver em recarga).\nRecarga: %d rodadas.") % [int(non_stop_range), non_stop_cooldown]
		SKILL_ZONE:
			if get_zone_variant() == ZoneVariant.SHOT:
				title = "44 Pant"
				text = "Dentro da zona: chute de %.1fx de força que sobe até Suspenso, %d%% de chance (sem o bônus da zona). Uso único por zona." % [
					pant_force_mult, _pct(pant_chance)]
			else:
				title = "Golden Zone"
				text = ("Cria uma zona dourada na ponta esquerda, fora da área do goleiro, por %d rodadas. Dentro dela: +%d%% em qualquer "
					+ "chute, +%d de alcance no Passe e o 44 Pant.\nRecarga: %d rodadas após o fim da zona.") % [
					golden_zone_rounds, _pct(zone_kick_bonus), int(zone_pass_bonus), golden_zone_cooldown]
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- PARTIDA NOVA / LOOP ----------

func reset_for_new_match() -> void:
	super()
	_end_zone()
	_pant_used = false
	_cutin_free = false
	_found_ball = false
	_rise_on_kick = false


func _physics_process(delta: float) -> void:
	super(delta)
	var inside: bool = _in_golden_zone()
	if _zone_fx != null and is_instance_valid(_zone_fx):
		_zone_fx.inside = inside
	if inside != _zone_bonus_on:   # +40 de alcance no Passe enquanto ele está dentro da zona
		pass_range_bonus += zone_pass_bonus if inside else -zone_pass_bonus
		_zone_bonus_on = inside
