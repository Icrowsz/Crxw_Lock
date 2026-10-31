class_name Barou
extends Player
## Shuuya Barou (vermelho e preto, com raios: veja barou_fx.gd).
##
## 1. Nero (recarga 2, compartilhada; a variante vem da altura dele e da bola):
##    - os dois no chão                         -> Nero: chute rasteiro, 1.3x a força do Chutar, 40%
##    - Barou suspenso, bola suspensa a até 200 -> Terror: avança até a bola, empurra e agarra até 2 inimigos
##                                                 (+0.2x de força cada) e dá um voleio com curva leve para dentro, 1.3x, 45%
##    - Barou suspenso, bola voando             -> Villain: bicicleta, 1.4x, 50%
## 2. Chop King (recarga 2, compartilhada): 3 dashes de 130, com a direção livre a cada um. Inimigo no caminho =
##    QTE fácil de drible: acertou, atordoa e segue sem perder velocidade; errou, perde os dashes que faltam.
##    Terminando com a bola ao alcance libera o Nutmeg (grátis): chute rasteiro 1.3x que atravessa todos os
##    jogadores, +0.2x de impulso por jogador passado, 45%.
##    - Stealth Kill Shot (variante: Barou no chão, bola suspensa e outro personagem perto): vai até a bola
##      puxando-a para cima ou para baixo e chuta 1.4x, subindo no trajeto, 45%.
## 3. Predator Eye (recarga 3 depois do fim do efeito): +1 ação geral, +10% nos próximos 3 chutes e +0.5 s no
##    Correr pelas próximas 3 rodadas; raios saem dele o tempo todo.
##    - Tyrant (variante: aliado a 250 com a bola a 70 dele): igual, e o aliado dá um passe rasteiro para o Barou.
## Devour (reação química Feeding com o Lorenzo) = o Nero melhorado (veja reaction_feeding.gd).
## Twisted Path (reação química Donkey com o Isagi) = o Nutmeg melhorado (veja reaction_donkey.gd e donkey_fx.gd).
##
## Os chutes dele soltam raios em volta da bola; os dashes deixam rastro vermelho com contorno preto.
## Cena: Nova Cena Herdada de player.tscn -> este script no nó raiz -> renomeie o nó para "Barou".
## Animações opcionais: nero, terror, villain, devour, chop_king, nutmeg, stealth_kill_shot, predator_eye.

const SKILL_SHOT: StringName = &"nero"        # também é o id de Terror, Villain e Devour
const SKILL_CHOP: StringName = &"chop_king"   # também é o id do Stealth Kill Shot
const SKILL_NUTMEG: StringName = &"nutmeg"
const SKILL_EYE: StringName = &"predator_eye" # também é o id do Tyrant
const CD_SHOT: StringName = &"cd_shot"
const CD_CHOP: StringName = &"cd_chop"        # Chop King, Stealth Kill Shot e Nutmeg
const CD_EYE: StringName = &"cd_eye"          # Predator Eye e Tyrant

enum ShotVariant { NONE, NERO, TERROR, VILLAIN }

@export_group("Nero / Terror / Villain")
@export var shot_cooldown: int = 2
@export_range(0.0, 1.0) var nero_chance: float = 0.40
@export var nero_force_mult: float = 1.3
@export_range(0.0, 1.0) var terror_chance: float = 0.45
@export var terror_force_mult: float = 1.3
@export var terror_range: float = 200.0       # alcance do avanço até a bola
@export var terror_max_grabs: int = 2
@export var terror_grab_force: float = 0.2    # +força por inimigo agarrado
@export_range(0.0, 1.0) var villain_chance: float = 0.50
@export var villain_force_mult: float = 1.4

@export_group("Devour (reação Feeding)")
@export_range(0.0, 1.0) var devour_chance: float = 0.80
@export var devour_force_mult: float = 2.4         # "mais forte e veloz" (a velocidade da bola vem da força)
@export var devour_lion_time: float = 1.7          # quanto tempo o leão fica na bola (s)
@export var devour_lion_size: float = 110.0        # tamanho do leão (raio do rosto, em px)

@export_group("Twisted Path (reação Donkey)")
@export_range(0.0, 1.0) var twisted_chance: float = 0.75   # o Predator Eye soma +10% por cima (como no Devour)
@export var twisted_force_mult: float = 2.0

@export_group("Chop King / Nutmeg / Stealth Kill Shot")
@export var chop_cooldown: int = 2
@export var chop_dashes: int = 3
@export var chop_dash_distance: float = 130.0
@export var chop_stun_rounds: int = 1         # rodadas que o inimigo driblado fica sem agir
@export var dribble_qte_keys: int = 2         # QTE fácil de drible
@export var dribble_qte_time: float = 0.8
@export_range(0.0, 1.0) var nutmeg_chance: float = 0.45
@export var nutmeg_force_mult: float = 1.3
@export var nutmeg_boost: float = 0.2         # +impulso (fração da velocidade inicial) por jogador atravessado
@export_range(0.0, 1.0) var stealth_chance: float = 0.45
@export var stealth_force_mult: float = 1.4
@export var stealth_ball_range: float = 200.0
@export var stealth_player_range: float = 220.0   # outro personagem precisa estar a esta distância

@export_group("Predator Eye / Tyrant")
@export var eye_cooldown: int = 3             # a partir do fim do efeito
@export var eye_rounds: int = 3               # rodadas depois da atual
@export var eye_shots: int = 3                # chutes que recebem o bônus
@export_range(0.0, 1.0) var eye_shot_bonus: float = 0.10
@export var eye_run_bonus: float = 0.5        # segundos a mais no Correr
@export var tyrant_range: float = 250.0
@export var tyrant_ball_range: float = 70.0

@export_group("Visual / descrição")
@export var kick_fx: KickFX                   # vazio = BarouFX.kick_fx()
@export var aura_offset: Vector2 = Vector2(0.0, -26.0)   # centro dos raios em relação aos pés (só com arte/sprite; o círculo usa o centro dele)
@export var aura_radius: float = 25.0                    # tamanho dos raios (colados no corpo; maior = mais longe)
@export var skill_icons: Dictionary = {}      # chaves: nero, chop_king, nutmeg, predator_eye

const DASH_TIME: float = 0.3                  # duração de cada dash (Terror e Chop King)
const TERROR_PUSH: float = 70.0               # quanto o Terror empurra cada inimigo
const TERROR_CURVE: Vector2 = Vector2(150.0, 0.5)   # curva leve: força lateral (px/s²) e duração (s)
const NUTMEG_MAX_FLIGHT: float = 3.0          # trava de segurança do "atravessar"
const STEALTH_PULL: float = 90.0              # quanto o Stealth Kill Shot puxa a bola
const STEALTH_PEAK: float = 100.0             # altura que o chute alcança (100 = Voando)

var _eye_until_round: int = -1
var _terror_lifted: Array[Player] = []   # inimigos levados ao Suspenso pelo Terror (soltos no fim do chute)
var _eye_shots_left: int = 0
var _base_run: float = 0.0
var _nutmeg_ready: bool = false
var _aura: BarouFX.Aura


func _init() -> void:
	character_id = "barou"   # o menu de formação usa isto para saber quem é quem
	display_name = "Shoei Barou"


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = BarouFX.kick_fx()
	_base_run = run_duration
	_aura = BarouFX.make_aura(aura_radius)
	add_child(_aura)
	_hook_manager.call_deferred()
	_register_donkey.call_deferred()


## Põe a Donkey na lista do ReactionManager, se ele ainda não a tem (tenta por alguns quadros: o manager pode
## entrar na árvore depois do Barou)
func _register_donkey() -> void:
	for _try in 20:
		var rm: ReactionManager = ReactionManager.get_for(self)
		if rm != null:
			for r: ChemicalReaction in rm.reactions:
				if r.id == &"donkey":
					return
			rm.reactions.append(ReactionDonkey.new())
			return
		await get_tree().process_frame


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m != null:
		m.round_started.connect(func(_r: int) -> void: _refresh_eye())   # o efeito acaba quando as rodadas passam


# ---------- UTIL ----------

func _body_point() -> Vector2:
	return global_position + Vector2(0.0, -height)


func _ball_point(ball: Ball) -> Vector2:
	return ball.sprite.global_position if ball.sprite != null else ball.global_position


func _ball_free(ball: Ball) -> bool:
	return ball != null and not is_down and not ball.is_held() and not ball.is_locked_for(team)


func _clamp_to_field(pos: Vector2, radius: float) -> Vector2:
	var field := get_tree().get_first_node_in_group("field") as Field
	if field == null:
		return pos
	var half: Vector2 = field.pitch_size * 0.5 - Vector2(radius, radius)
	var l: Vector2 = field.to_local(pos)
	return field.to_global(Vector2(clampf(l.x, -half.x, half.x), clampf(l.y, -half.y, half.y)))


## Move Barou de a até b em "seconds", deixando o rastro; com "ball", a bola vai junto (a "ball_offset" dele)
func _glide(a: Vector2, b: Vector2, seconds: float, trail: BarouFX.Trail, ball: Ball = null,
		ball_offset: Vector2 = Vector2.ZERO) -> void:
	var elapsed: float = 0.0
	while elapsed < seconds:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		global_position = a.lerp(b, minf(elapsed / seconds, 1.0))
		if ball != null:
			ball.global_position = global_position + ball_offset
		trail.add(_body_point())


## Inimigos de pé e encostando nele (menos os de "skip"). Por padrão só os do mesmo nível de altura que
## o Barou; com any_height, de qualquer altura (no chão, suspensos ou voando)
func _enemies_touching(skip: Array[Player], any_height: bool = false) -> Array[Player]:
	var found: Array[Player] = []
	for o: Player in get_tree().get_nodes_in_group("players"):
		if o.team != team and not o.is_down and not skip.has(o) and (any_height or o.height_level == height_level) \
				and o.global_position.distance_to(global_position) <= body_radius + o.body_radius + 10.0:
			found.append(o)
	return found


# ---------- PREDATOR EYE (estado e bônus) ----------

func _eye_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _eye_until_round >= 0 and m.round_number <= _eye_until_round


## Liga/desliga o que o efeito muda (Correr e raios)
func _refresh_eye() -> void:
	var on: bool = _eye_active()
	run_duration = _base_run + (eye_run_bonus if on else 0.0)
	if _aura != null:
		_aura.active = on


func _use_eye() -> bool:
	var m: MatchManager = _get_manager()
	var ally: Player = _find_tyrant_ally()
	if m == null or not await play_action(&"predator_eye"):
		return false
	_eye_until_round = m.round_number + eye_rounds
	_eye_shots_left = eye_shots
	extra_general_left += 1                      # mais uma ação geral para ele
	start_cooldown(CD_EYE, eye_cooldown, _eye_until_round + 1)
	_refresh_eye()
	BarouFX.shock(self, _body_point(), 110.0, 0.45)
	BarouFX.burst(self, _body_point(), 22, true)
	if ally != null:   # Tyrant: o aliado é obrigado a passar rasteiro para o Barou
		BarouFX.zap(self, _body_point(), ally.global_position + Vector2(0.0, -ally.height), 0.5)
		await m.run_ground_pass(ally, self, _get_ball())
	return true


## Aliado com a bola perto (tyrant_ball_range) e a até tyrant_range de Barou
func _find_tyrant_ally() -> Player:
	var ball: Ball = _get_ball()
	var best: Player = null
	var best_dist: float = INF
	if not _ball_free(ball):
		return null
	for p: Player in get_tree().get_nodes_in_group("players"):
		var d: float = p.global_position.distance_to(ball.global_position)
		if p != self and p.team == team and not p.is_down and d <= tyrant_ball_range and d < best_dist \
				and global_position.distance_to(p.global_position) <= tyrant_range:
			best = p
			best_dist = d
	return best


## Qualquer chute (geral ou de habilidade): +10% nos primeiros chutes do Predator Eye, e raios na bola
func kick_ball(ball: Ball, direction: Vector2, kind: KickType, qte_success: bool = true,
		chance_override: float = -1.0, ignore_self_collision: bool = false,
		fx: KickFX = null, anim: StringName = &"", on_kick: Callable = Callable()) -> void:
	var boosted: bool = _eye_active() and _eye_shots_left > 0
	if boosted:
		chance_override = (chance_override if chance_override >= 0.0 else get_shot_chance(kind)) + eye_shot_bonus
	var other: Callable = on_kick
	on_kick = func(b: Ball, d: Vector2, s: float) -> void:
		BarouFX.kick(self, _ball_point(b), d, _eye_active())
		if other.is_valid():
			other.call(b, d, s)
	await super(ball, direction, kind, qte_success, chance_override, ignore_self_collision, fx, anim, on_kick)
	if boosted:
		_eye_shots_left -= 1   # gasta um dos chutes com bônus (depois do chute, que ainda usa o bônus)


# ---------- NERO / TERROR / VILLAIN / DEVOUR ----------

func get_shot_variant() -> ShotVariant:
	var ball: Ball = _get_ball()
	if not _ball_free(ball):
		return ShotVariant.NONE
	var dist: float = global_position.distance_to(ball.global_position)
	var level: Heights.Level = ball.get_level()
	if height_level == Heights.Level.GROUND and level == Heights.Level.GROUND and dist <= kick_range:
		return ShotVariant.NERO
	if height_level == Heights.Level.SUSPENDED:
		if level == Heights.Level.SUSPENDED and dist <= terror_range:
			return ShotVariant.TERROR
		if level == Heights.Level.FLYING and dist <= kick_range:
			return ShotVariant.VILLAIN
	return ShotVariant.NONE


## Reação Feeding disponível agora? (só vale para o Nero)
func _find_feeding() -> ChemicalReaction:
	var rm: ReactionManager = ReactionManager.get_for(self)
	if rm == null or get_shot_variant() != ShotVariant.NERO:
		return null
	var reaction: ChemicalReaction = rm.find_available(self)
	return reaction if reaction != null and reaction.id == &"feeding" else null


func _use_shot() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or get_shot_variant() == ShotVariant.NONE:
		return false
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	var variant: ShotVariant = get_shot_variant()   # a bola pode ter rolado enquanto ele mirava
	if aim == Vector2.ZERO or variant == ShotVariant.NONE:
		return false   # cancelou: não gasta a ação nem começa a recarga
	var ball: Ball = _get_ball()

	var kind: KickType = KickType.GROUND
	var chance: float = nero_chance
	var force: float = nero_force_mult
	var anim: StringName = &"nero"
	var shot_fx: KickFX = kick_fx
	var on_kick: Callable = Callable()
	match variant:
		ShotVariant.TERROR:
			kind = KickType.VOLLEY
			chance = terror_chance
			force = terror_force_mult
			anim = &"terror"
		ShotVariant.VILLAIN:
			kind = KickType.FLYING   # força de bola voando, mas sem QTE neste personagem
			chance = villain_chance
			force = villain_force_mult
			anim = &"villain"
		_:
			var reaction: ChemicalReaction = _find_feeding()   # Feeding (Lorenzo + Barou): o Nero vira Devour
			var partner: Player = reaction.find_partner(self) if reaction != null else null
			if partner != null:
				await ReactionManager.get_for(self).play(reaction, self, partner)   # congela, cutscene, diálogo
				if not is_inside_tree():
					return false
				chance = devour_chance
				force = devour_force_mult
				anim = &"devour"
				shot_fx = BarouFX.kick_fx(true)
				on_kick = func(b: Ball, _d: Vector2, _s: float) -> void: FeedingFX.attach_lion(b, 1.7, 110.0)

	if variant == ShotVariant.TERROR:
		var grabbed: int = await _terror_dash(ball)
		force += terror_grab_force * float(grabbed)   # cada inimigo agarrado: +0.2x
	next_kick_force_mult *= force
	await kick_ball(ball, aim, kind, true, chance, false, shot_fx, anim, on_kick)
	if variant == ShotVariant.TERROR:
		_curve_inward(ball, aim)
		_release_terror()
	start_cooldown(CD_SHOT, shot_cooldown)
	return true


## Terror: avança até a bola (que espera no lugar); empurra para trás e agarra até 2 inimigos. Devolve quantos.
func _terror_dash(ball: Ball) -> int:
	var to_ball: Vector2 = ball.global_position - global_position
	var dir: Vector2 = to_ball.normalized() if to_ball.length() > 1.0 else Vector2(get_attack_dir(), 0.0)
	var gap: float = body_radius + ball.collision_radius + 6.0
	var end: Vector2 = global_position
	if to_ball.length() > gap:
		end = _clamp_to_field(ball.global_position - dir * gap, body_radius)
	face_towards(dir)
	ball.hover_to(ball.global_position, ball.height, DASH_TIME)
	var trail: BarouFX.Trail = BarouFX.begin_trail(self)
	var grabbed: Array[Player] = []
	var start: Vector2 = global_position
	var elapsed: float = 0.0
	while elapsed < DASH_TIME:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		global_position = start.lerp(end, minf(elapsed / DASH_TIME, 1.0))
		trail.add(_body_point())
		for foe: Player in _enemies_touching(grabbed, true):   # no chão, suspensos ou voando
			if grabbed.size() >= terror_max_grabs:
				break
			grabbed.append(foe)
			_lift_grabbed(foe)
			create_tween().tween_property(foe, "global_position",
				_clamp_to_field(foe.global_position + dir * TERROR_PUSH, foe.body_radius), 0.2) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)   # empurra para trás...
			BarouFX.zap(self, _body_point(), foe.global_position + Vector2(0.0, -foe.height), 0.4)   # ...e agarra
	trail.finish()
	return grabbed.size()


## Quem estava no chão ou voando é levado ao nível Suspenso, como o Barou, até o fim do chute
func _lift_grabbed(foe: Player) -> void:
	if foe.height_level == Heights.Level.SUSPENDED:
		return
	_terror_lifted.append(foe)
	foe.height_level = Heights.Level.SUSPENDED
	create_tween().tween_property(foe, "height", Heights.SUSPENDED_HEIGHT, 0.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Solta quem o Terror levantou: eles caem de volta ao chão
func _release_terror() -> void:
	for foe in _terror_lifted:
		if is_instance_valid(foe):
			foe.land()
	_terror_lifted.clear()


## Curva leve e fixa "para dentro" (rumo à linha central do campo): empurra a bola de lado enquanto ela anda.
## Roda sozinha, sem await de quem chamou.
func _curve_inward(ball: Ball, dir: Vector2) -> void:
	var field := get_tree().get_first_node_in_group("field") as Field
	var y: float = field.to_local(ball.global_position).y if field != null else 0.0
	var inward := Vector2(0.0, -signf(y) if absf(y) > 1.0 else 1.0)
	var side: float = 1.0 if dir.orthogonal().dot(inward) >= 0.0 else -1.0
	var t: float = 0.0
	while t < TERROR_CURVE.y:
		await get_tree().physics_frame
		if not is_instance_valid(ball) or ball.hovering or ball.is_held() or ball.velocity.length() <= ball.stop_speed:
			return
		var delta: float = get_physics_process_delta_time()
		t += delta
		ball.velocity += ball.velocity.normalized().orthogonal() * side * TERROR_CURVE.x * delta


# ---------- CHOP KING / NUTMEG / STEALTH KILL SHOT ----------

## Stealth Kill Shot: Barou no chão, bola suspensa ao alcance e outro personagem (de qualquer time) perto
func _stealth_possible() -> bool:
	var ball: Ball = _get_ball()
	if height_level != Heights.Level.GROUND or not _ball_free(ball) or ball.get_level() != Heights.Level.SUSPENDED \
			or global_position.distance_to(ball.global_position) > stealth_ball_range:
		return false
	for o: Player in get_tree().get_nodes_in_group("players"):
		if o != self and not o.is_down and o.global_position.distance_to(global_position) <= stealth_player_range:
			return true
	return false


func _use_chop() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var beaten: Array[Player] = []
	for i in chop_dashes:
		var aim: Vector2 = await m.aim_for_skill(self, chop_dash_distance)   # direção livre a cada dash
		if aim == Vector2.ZERO:
			if i == 0:
				return false   # cancelou antes de começar: não gasta a ação
			break              # cancelou no meio: a ação termina aqui
		if i == 0 and not await play_action(&"chop_king"):
			return false
		if not await _chop_dash(m, aim.normalized(), beaten):
			break              # perdeu o drible: perde os dashes que faltam
	var ball: Ball = _get_ball()
	_nutmeg_ready = _ball_free(ball) and ball.get_level() == Heights.Level.GROUND and get_kick_type(ball) != KickType.NONE
	DonkeyFX.chop_done(self, _nutmeg_ready)   # Donkey: sem Nutmeg o rastro negro some; com ele, espera o chute
	start_cooldown(CD_CHOP, chop_cooldown)
	return true


## Um dash do Chop King. Devolve false se perdeu o drible (o resto da ação é cancelado).
func _chop_dash(m: MatchManager, dir: Vector2, beaten: Array[Player]) -> bool:
	face_towards(dir)
	var start: Vector2 = global_position
	var end: Vector2 = _clamp_to_field(start + dir * chop_dash_distance, body_radius)
	var trail: BarouFX.Trail = BarouFX.begin_trail(self)
	var donkey: bool = DonkeyFX.wants_trail(self)   # reação Donkey pronta: o rastro negro fica até o Twisted Path
	var elapsed: float = 0.0
	while elapsed < DASH_TIME and not m.match_over:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		global_position = start.lerp(end, minf(elapsed / DASH_TIME, 1.0))
		trail.add(_body_point())
		if donkey:
			DonkeyFX.trail_point(self, _body_point())
		var foes: Array[Player] = _enemies_touching(beaten)
		if foes.is_empty():
			continue
		var foe: Player = foes[0]
		beaten.append(foe)
		var qte := QTE.new()   # o dash espera o QTE e depois segue na mesma velocidade
		m.add_child(qte)
		qte.start(QTE.EASY_KEYS, dribble_qte_keys, dribble_qte_time, "Drible!")
		if not await qte.finished:
			trail.finish()
			return false
		foe.apply_lock(self, chop_stun_rounds)   # passa e atordoa
		foe.hop_over()
		BarouFX.zap(self, _body_point(), foe.global_position + Vector2(0.0, -foe.height), 0.35)
	trail.finish()
	return true


func _use_stealth() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)   # direção do chute; cima/baixo na tela = para onde ele puxa a bola
	if aim == Vector2.ZERO or not _stealth_possible() or not await play_action(&"stealth_kill_shot"):
		return false
	var ball: Ball = _get_ball()
	face_towards(aim)
	var kick_dir: Vector2 = aim.normalized()
	var gap: float = body_radius + ball.collision_radius + 6.0
	var to_ball: Vector2 = ball.global_position - global_position
	var contact: Vector2 = global_position if to_ball.length() <= gap else ball.global_position - to_ball.normalized() * gap
	var drag_end: Vector2 = _clamp_to_field(contact + Vector2(0.0, -1.0 if aim.y < 0.0 else 1.0) * STEALTH_PULL, body_radius)
	var trail: BarouFX.Trail = BarouFX.begin_trail(self)
	ball.hover_to(ball.global_position, ball.height, 0.2)       # a bola espera...
	await _glide(global_position, contact, 0.2, trail)           # ...ele vai até ela...
	ball.register_touch(self)
	await _glide(contact, drag_end, 0.25, trail, ball, kick_dir * gap)   # ...e a puxa para cima ou para baixo
	trail.finish()
	var kind: KickType = get_kick_type(ball)
	next_kick_force_mult *= stealth_force_mult
	await kick_ball(ball, kick_dir, kind if kind != KickType.NONE else KickType.HIGH_BALL, true, stealth_chance, false, kick_fx, &"stealth_kill_shot")
	ball.vel_z = Heights.lift_for_peak(maxf(0.0, STEALTH_PEAK - ball.height), ball.gravity)   # sobe durante o trajeto
	start_cooldown(CD_CHOP, chop_cooldown)
	return true


func _use_nutmeg() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null:
		return false
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO or not _ball_free(ball) or get_kick_type(ball) == KickType.NONE:
		return false   # cancelou: o complemento continua disponível
	var chance: float = nutmeg_chance
	var force: float = nutmeg_force_mult
	var shot_fx: KickFX = kick_fx
	var anim: StringName = &"nutmeg"
	var on_kick: Callable = Callable()
	var reaction: ChemicalReaction = ReactionDonkey.find_ready(self)   # Donkey (Isagi): o Nutmeg vira o Twisted Path
	var partner: Player = reaction.find_partner(self) if reaction != null else null
	if partner != null:
		await ReactionManager.get_for(self).play(reaction, self, partner)   # congela, cutscene, diálogo
		# Depois do await: confere de novo se ainda dá para chutar (partida reiniciada, bola mudou)
		if not is_inside_tree() or m.match_over or not _nutmeg_ready or not _ball_free(ball) or get_kick_type(ball) == KickType.NONE:
			return false
		chance = twisted_chance
		force = twisted_force_mult
		shot_fx = DonkeyFX.kick_fx()
		if _has_art and animated_sprite.sprite_frames.has_animation(&"twisted_path"):
			anim = &"twisted_path"
		on_kick = func(b: Ball, d: Vector2, _s: float) -> void:
			DonkeyFX.twisted_impact(self, partner if is_instance_valid(partner) else null, b, d)
	ball.collisions_paused = true   # a bola atravessa todo mundo (antes do chute)
	next_kick_force_mult *= force
	await kick_ball(ball, aim, KickType.GROUND, true, chance, false, shot_fx, anim, on_kick)
	_nutmeg_ready = false
	_nutmeg_flight(ball)
	return true


## Enquanto a bola passa pelos jogadores: eles pulam e cada um dá +impulso. Depois devolve a colisão.
## Roda sozinha, sem await de quem chamou.
func _nutmeg_flight(ball: Ball) -> void:
	var base_speed: float = ball.velocity.length()
	var passed: Array[Player] = []
	var t: float = 0.0
	while t < NUTMEG_MAX_FLIGHT and is_instance_valid(ball):
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		for p: Player in get_tree().get_nodes_in_group("players"):
			if p == self or p.is_down or passed.has(p) or p.height_level != Heights.Level.GROUND \
					or p.global_position.distance_to(ball.global_position) > ball.collision_radius + p.body_radius + 14.0:
				continue
			passed.append(p)
			p.hop_over()
			if ball.velocity.length() > ball.stop_speed:
				ball.velocity += ball.velocity.normalized() * base_speed * nutmeg_boost   # +0.2x para continuar
		if ball.hovering or (ball.is_on_ground() and ball.velocity.length() <= ball.stop_speed):
			break
	if is_instance_valid(ball):
		ball.collisions_paused = false


# Nutmeg: complemento grátis, só depois do Chop King e enquanto a bola estiver ao alcance
func has_free_followup() -> bool:
	return _nutmeg_ready and can_use_skill(SKILL_NUTMEG)


func skill_is_free(skill_id: StringName) -> bool:
	return skill_id == SKILL_NUTMEG and _nutmeg_ready


func has_turn_end_effect() -> bool:
	return _nutmeg_ready   # se o turno acabar sem o Nutmeg, ele expira


func on_turn_end() -> void:
	_nutmeg_ready = false


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		{"id": SKILL_SHOT, "name": skill_label("Devour" if _find_feeding() != null else _info(SKILL_SHOT)[0], CD_SHOT)},
		{"id": SKILL_CHOP, "name": skill_label(_info(SKILL_CHOP)[0], CD_CHOP)}]
	if _nutmeg_ready:
		list.append({"id": SKILL_NUTMEG, "name": "Twisted Path (complemento)" if ReactionDonkey.find_ready(self) != null else "Nutmeg (complemento)"})
	list.append({"id": SKILL_EYE, "name": "Predator Eye (ativo)" if _eye_active() else skill_label(_info(SKILL_EYE)[0], CD_EYE)})
	return list


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	var ball: Ball = _get_ball()
	match skill_id:
		SKILL_SHOT:
			return not is_on_cooldown(CD_SHOT) and get_shot_variant() != ShotVariant.NONE
		SKILL_CHOP:
			return not is_on_cooldown(CD_CHOP) and height_level == Heights.Level.GROUND
		SKILL_NUTMEG:
			return _nutmeg_ready and _ball_free(ball) and get_kick_type(ball) != KickType.NONE
		SKILL_EYE:
			return not _eye_active() and not is_on_cooldown(CD_EYE)
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_SHOT:
			return await _use_shot()
		SKILL_CHOP:
			if _stealth_possible():
				return await _use_stealth()
			return await _use_chop()
		SKILL_NUTMEG:
			return await _use_nutmeg()
		SKILL_EYE:
			return await _use_eye()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


## [nome, texto] da habilidade na situação atual (o nome também vai para o menu)
func _info(skill_id: StringName) -> Array:
	match skill_id:
		SKILL_SHOT:
			match get_shot_variant():
				ShotVariant.TERROR:
					return ["Terror", "Avança até a bola (%d), empurra e agarra até %d inimigos (no chão, suspensos ou voando: todos vão para o Suspenso como ele, +%.1fx de força cada) e dá um voleio com curva leve para dentro. %.1fx, %d%% de chance de gol." % [
						int(terror_range), terror_max_grabs, terror_grab_force, terror_force_mult, _pct(terror_chance)]]
				ShotVariant.VILLAIN:
					return ["Villain", "Bicicleta com bola voando, %.1fx a força. %d%% de chance de gol." % [villain_force_mult, _pct(villain_chance)]]
			if _find_feeding() != null:
				return ["Devour", "Reação Química (Feeding) com o Lorenzo: chute rasteiro %.1fx mais forte. %d%% de chance de gol." % [devour_force_mult, _pct(devour_chance)]]
			return ["Nero", "Chute rasteiro, %.1fx a força do Chutar. %d%% de chance de gol.\nTerror (suspenso, bola suspensa) e Villain (suspenso, bola voando) aparecem aqui." % [nero_force_mult, _pct(nero_chance)]]
		SKILL_CHOP:
			if _stealth_possible():
				return ["Stealth Kill Shot", "Vai até a bola suspensa puxando-a para cima ou para baixo e chuta %.1fx, subindo no trajeto. %d%% de chance de gol." % [stealth_force_mult, _pct(stealth_chance)]]
			return ["Chop King", "%d dashes de %d com direção livre. Inimigo no caminho = QTE fácil de drible: acertou, atordoa e segue; errou, perde os dashes restantes. Terminando com a bola, libera o Nutmeg." % [chop_dashes, int(chop_dash_distance)]]
		SKILL_NUTMEG:
			if ReactionDonkey.find_ready(self) != null:
				return ["Twisted Path", "Reação Química (Donkey) com o Isagi: chute rasteiro %.1fx que atravessa todos os jogadores (+%.1fx de impulso por jogador). %d%% de chance de gol." % [twisted_force_mult, nutmeg_boost, _pct(twisted_chance)]]
			return ["Nutmeg", "Chute rasteiro %.1fx que atravessa todos os jogadores (+%.1fx de impulso por jogador). %d%% de chance de gol." % [nutmeg_force_mult, nutmeg_boost, _pct(nutmeg_chance)]]
		SKILL_EYE:
			var tyrant: bool = _find_tyrant_ally() != null
			return ["Tyrant" if tyrant else "Predator Eye", "+1 ação geral, +%d%% nos próximos %d chutes e +%.1f s no Correr pelas próximas %d rodadas.%s" % [
				_pct(eye_shot_bonus), eye_shots, eye_run_bonus, eye_rounds, " O aliado com a bola dá um passe rasteiro para o Barou." if tyrant else ""]]
	return []


func get_skill_info(skill_id: StringName) -> Dictionary:
	var info: Array = _info(skill_id)
	if info.is_empty():
		return {}
	var cooldown: String = ""
	match skill_id:
		SKILL_SHOT:
			cooldown = "\nRecarga: %d rodadas." % shot_cooldown
		SKILL_CHOP:
			cooldown = "\nRecarga: %d rodadas." % chop_cooldown
		SKILL_EYE:
			cooldown = "\nRecarga: %d rodadas depois do fim do efeito." % eye_cooldown
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": info[0], "description": info[1] + cooldown, "icon": icon}


# ---------- PARTIDA NOVA / VISUAL ----------

func reset_for_new_match() -> void:
	super()
	_eye_until_round = -1
	_eye_shots_left = 0
	_nutmeg_ready = false
	_release_terror()
	_refresh_eye()


func _process(delta: float) -> void:
	super(delta)
	if _aura != null and _aura.active:
		# Com sprite, o centro é o meio do corpo (aura_offset); com o círculo/retrato, é o próprio centro dele
		_aura.position = (aura_offset if _has_art else Vector2.ZERO) + Vector2(0.0, -height)   # acompanha o salto


func _draw() -> void:
	super()
	# Sem arte: o corpo fica vermelho com contorno preto (com sprite, pinte a arte na SpriteFrames)
	if draw_placeholder and not is_down and state != State.SLIDING:
		draw_circle(Vector2(0.0, -height), placeholder_radius, Color(0.8, 0.05, 0.05))
		draw_arc(Vector2(0.0, -height), placeholder_radius, 0.0, TAU, 32, Color.BLACK, 3.0)
