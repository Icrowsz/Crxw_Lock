class_name Rin
extends Player
## Rin Itoshi. Herda tudo do Player; script único (o Typing Game é a classe interna no fim).
## Visual: rin_fx.gd. Cena: player.tscn herdada, script no nó raiz, nó raiz chamado "Rin".
##
## 1. Curve Shot (recarga 2, compartilhada; a variante muda sozinha pela altura dele e da bola). Chutes curvos, sem QTE.
##    Na mira, a RODA DO MOUSE (ou Q/E) escolhe o NÍVEL DA CURVA (vale para todas as variantes).
##      os dois no chão -> Curve Shot (curva p/ a ESQUERDA, sobe até Suspenso, 1.2x a força do Chutar, 45%)
##      com o Destroyer Mode -> Parabolic Shot (esquerda, sobe até Voando, 1.3x, 45%+bônus)
##      bola Suspensa -> Trivela Shot (curva FIXA p/ a DIREITA, voleio, 1.3x, 45%)
##      Trivela + inimigo próximo -> Crash Shot (1.4x, 50%, derruba e atordoa o inimigo)
## 2. Center of Gravity (recarga 2, compartilhada): confronto físico com o oponente a até 90 (70% de vencer). Vence: derruba
##    e ganha +5% nos 2 próximos chutes. Perde: os dois se empurram. Ao derrubar, espinhos perfuram o inimigo.
##      bola no chão próxima -> Destruction: caneta no 1º inimigo (QTE fácil); ganhou = atordoa, avança 150 com a bola grudada
##      e, ao achar um 2º inimigo, faz o Center of Gravity
##      bola Suspensa próxima + aliado -> Puppets: passe curvo suspenso (QTE fácil); se chegar, avança 150, o aliado devolve
##      e o Rin ganha um Curve Shot grátis (uma mão de marionetista sobrevoa o aliado)
##      Destroyer Mode -> Mangle You: 80% de vencer; vencendo derruba, atordoa e ganha +1 ação GERAL
## 3. Destroyer Mode (3 rodadas, recarga 3 após o fim): +5% nos chutes, Parabolic Shot e Mangle You. Ativo, o botão vira
##    Opposite Direction (uso único): com a bola e o Rin no chão, Typing Game; acertou = domina a bola e faz dois avanços de 140
##    em direções diferentes (8 direções; a 2ª não repete a 1ª).
##
## Reação Química CRUEL (com o Charles, veja reaction_cruel.gd): Destroyer Mode ativo + Rabona Cross do Charles com a bola =
## o Crash Shot vira o Self Destruction (muito mais força, 93%, sombra gigante e espinhos).

const SKILL_CURVE: StringName = &"curve_shot"
const SKILL_GRAVITY: StringName = &"center_of_gravity"
const SKILL_DESTROYER: StringName = &"destroyer_mode"
const CD_CURVE: StringName = &"cd_curve"       # as variantes de cada habilidade compartilham a recarga
const CD_GRAVITY: StringName = &"cd_gravity"
const CD_DESTROYER: StringName = &"cd_destroyer"
const PREVIEW_LENGTH: float = 600.0            # tamanho da linha tracejada da mira
const PUPPETS_CURVE: float = 0.35              # curvatura do passe (fração da distância)
const PUPPETS_ARC: float = 60.0                # quanto a bola sobe no meio do passe

enum CurveVariant { NONE, CURVE, PARABOLIC, TRIVELA, CRASH }
enum GravityVariant { NONE, GRAVITY, DESTRUCTION, PUPPETS, MANGLE }
const CURVE_ANIMS: Dictionary = {CurveVariant.CURVE: &"curve_shot", CurveVariant.PARABOLIC: &"parabolic_shot",
	CurveVariant.TRIVELA: &"trivela_shot", CurveVariant.CRASH: &"crash_shot"}

@export_group("Curve Shot")
@export_range(0.0, 1.0) var chance_curve: float = 0.45     # Curve, Parabolic e Trivela
@export_range(0.0, 1.0) var chance_crash: float = 0.50
@export var curve_force_mult: float = 0.7                  # múltiplos da força do Chutar geral daquela situação
@export var parabolic_force_mult: float = 0.8
@export var trivela_force_mult: float = 0.8
@export var crash_force_mult: float = 0.8
@export var curve_turn_degrees: float = 50.0               # quanto a bola curva no nível 2 (Parabolic 65; Trivela/Crash 90)
@export var curve_level_mults: Array[float] = [0.5, 1.0, 1.6]   # os níveis de curva da mira: suave, normal, forte
@export var curve_duration: float = 1.0                    # por quanto tempo a curva vale (s)
@export var curve_aim_range: float = 200.0                 # tamanho da seta de mira
@export var crash_enemy_radius: float = 90.0               # inimigo "próximo" para virar Crash Shot
@export var curve_cooldown: int = 2

@export_group("Self Destruction (reação Cruel)")
@export_range(0.0, 1.0) var chance_self_destruction: float = 0.93   # valor final de chance
@export var self_destruction_force_mult: float = 1.8                # multiplica a força do Crash Shot
@export var self_destruction_fx: KickFX                             # vazio = estilo padrão (_make_fx)

@export_group("Center of Gravity")
@export var gravity_range: float = 90.0                    # alcance do confronto
@export_range(0.0, 1.0) var chance_gravity: float = 0.70   # chance do Rin vencer (Mangle You: 80%)
@export_range(0.0, 1.0) var chance_mangle: float = 0.80
@export_range(0.0, 1.0) var gravity_bonus: float = 0.05    # bônus de chute ao vencer o Center of Gravity
@export var gravity_bonus_shots: int = 2
@export var clash_push: float = 60.0                       # quanto os dois se empurram ao perder
@export var stun_rounds: int = 2                           # atordoamento (a rodada atual conta)
@export var ball_near_radius: float = 90.0                 # bola no chão "próxima" (Destruction)
@export var puppets_ball_radius: float = 110.0             # bola suspensa "próxima" (Puppets)
@export var puppets_range: float = 500.0                   # alcance do passe curvo
@export var puppets_flight_time: float = 0.9
@export var dash_distance: float = 270.0                   # avanço do Destruction e do Puppets
@export var dash_time: float = 0.25
@export var gravity_cooldown: int = 2

@export_group("Destroyer Mode")
@export var destroyer_rounds: int = 3                      # duração total (contando a atual)
@export var destroyer_cooldown: int = 3                    # a partir do fim do efeito
@export_range(0.0, 1.0) var destroyer_bonus: float = 0.05  # bônus em todos os chutes
@export var opposite_dash: float = 250.0
@export var typing_time: float = 3.0
@export var typing_words: Array[String] = ["DEVORAR", "DESTRUIR", "ANIRAP", "DESTROÇAR", "MATAR", "EGOISTA"]

@export_group("Visual")
@export var kick_fx: KickFX                                # vazio = estilo padrão (_make_fx)
@export var destroyer_fx_enabled: bool = true              # massa com espinhos e olhos nas costas (rin_fx.gd)
@export var destroyer_fx_scale: float = 1.0
@export var destroyer_fx_offset: Vector2 = Vector2.ZERO
## Imagem de cada habilidade no balão. Chaves: curve_shot, center_of_gravity, destroyer_mode, opposite_direction
@export var skill_icons: Dictionary = {}

var _destroyer_until_round: int = -1       # Destroyer Mode vale até o fim desta rodada (-1 = inativo)
var _aura: RinFX.Aura                      # a massa com espinhos e olhos nas costas (Destroyer Mode)
var _curve_level: int = 1                  # nível da curva escolhido na mira (índice de curve_level_mults)
var _opposite_used: bool = false           # Opposite Direction: uso único por Destroyer Mode
var _free_curve: bool = false              # o Puppets deu um Curve Shot grátis (vale até o fim do turno)
var _bonus_shots: int = 0                  # chutes que ainda recebem o bônus do Center of Gravity
var _aiming_curve: bool = false
var _carried: Ball = null                  # bola grudada nele (Destruction / Opposite Direction)
var _carry_dir: Vector2 = Vector2.RIGHT


func _init() -> void:
	character_id = "rin"             # o menu de formação usa isto para saber quem é quem
	display_name = "Itoshi Rin"      # aparece no placar de gols e no menu


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = _make_fx()
	if self_destruction_fx == null:
		self_destruction_fx = _make_fx(true)
	_hook_manager.call_deferred()
	_aura = RinFX.make_aura(placeholder_radius)   # só aparece com o Destroyer Mode (z_index -1: atrás do Rin)
	add_child(_aura)
	_refresh_aura()


## Verde-azulado do Rin; as partículas giram em espiral (a curva / "gravidade"). strong = Self Destruction: escuro e largo
func _make_fx(strong: bool = false) -> KickFX:
	var fx := KickFX.new()
	fx.color = Color(0.03, 0.12, 0.12) if strong else Color(0.176, 0.661, 0.569)
	fx.additive = false   # o campo é verde: mistura normal mantém a cor visível
	fx.trail_width = 34.0 if strong else 16.0
	fx.trail_points = 20
	fx.shape = KickFX.Shape.DOT
	fx.particle_color = Color(0.2, 1.0, 0.85) if strong else Color(0.314, 0.909, 0.625)
	fx.amount = 40 if strong else 26
	fx.lifetime = 0.8 if strong else 0.6
	fx.speed_min = 20.0 if strong else 10.0
	fx.speed_max = 110.0 if strong else 50.0
	fx.swirl = 200.0 if strong else 140.0
	fx.damping = 20.0
	fx.scale_min = 0.25 if strong else 0.2
	fx.scale_max = 0.55 if strong else 0.45
	fx.burst_amount = 24 if strong else 14
	fx.burst_speed = 380.0 if strong else 200.0
	return fx


func _exit_tree() -> void:
	_release_ball()


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m == null:
		return
	m.round_started.connect(func(_r: int) -> void:
		queue_redraw()
		_refresh_aura())
	m.turn_ended.connect(func(ended_team: int) -> void:
		if ended_team == team:
			_free_curve = false)   # o Curve Shot grátis só vale no turno em que foi ganho


# ---------- DESTROYER MODE ----------

## Com o Destroyer Mode ligado, o Rin parado usa "idle_destroyer" (se existir na SpriteFrames)
func _desired_anim() -> StringName:
	var a: StringName = super()
	return &"idle_destroyer" if a == ANIM_IDLE and is_destroyer_active() and _has_anim(&"idle_destroyer") else a


func _has_anim(anim: StringName) -> bool:
	return animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(anim)


func is_destroyer_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _destroyer_until_round >= 0 and m.round_number <= _destroyer_until_round


## Liga/desliga a massa com espinhos e olhos das costas (e atualiza tamanho/posição do Inspector)
func _refresh_aura() -> void:
	if _aura != null:
		_aura.fx_scale = destroyer_fx_scale
		_aura.fx_offset = destroyer_fx_offset
		_aura.set_active(destroyer_fx_enabled and is_destroyer_active())


func _use_destroyer() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	_destroyer_until_round = m.round_number + destroyer_rounds - 1
	_opposite_used = false
	start_cooldown(CD_DESTROYER, destroyer_cooldown, _destroyer_until_round + 1)   # conta a partir do fim do efeito
	RinFX.clash(self, global_position, global_position)
	_refresh_aura()
	queue_redraw()
	return true


## Bônus de chute: Destroyer Mode + Center of Gravity ganho (2 chutes). Vale também para o Chutar geral.
func _shot_bonus() -> float:
	return (destroyer_bonus if is_destroyer_active() else 0.0) + (gravity_bonus if _bonus_shots > 0 else 0.0)


func get_shot_chance(kind: KickType) -> float:
	return minf(super(kind) + _shot_bonus(), 1.0)


func kick_ball(ball: Ball, direction: Vector2, kind: KickType, qte_success: bool = true,
		chance_override: float = -1.0, ignore_self_collision: bool = false,
		fx: KickFX = null, anim: StringName = &"", on_kick: Callable = Callable()) -> void:
	await super(ball, direction, kind, qte_success, chance_override, ignore_self_collision, fx, anim, on_kick)
	_bonus_shots = maxi(0, _bonus_shots - 1)


# ---------- SITUAÇÕES (variantes automáticas) ----------

func _nearest_enemy(max_dist: float) -> Player:
	var best: Player = null
	var best_d: float = max_dist
	for other: Player in get_tree().get_nodes_in_group("players"):
		var d: float = global_position.distance_to(other.global_position)
		if other.team != team and not other.is_down and d <= best_d:
			best = other
			best_d = d
	return best


func _ball_near(ball: Ball, radius: float, level: Heights.Level) -> bool:
	return ball != null and not ball.is_held() and ball.get_level() == level \
		and global_position.distance_to(ball.global_position) <= radius


func get_curve_variant() -> CurveVariant:
	var ball: Ball = _get_ball()
	if get_kick_type(ball) == KickType.NONE:   # confere derrubado, bola na mão do goleiro, longe, altura inalcançável
		return CurveVariant.NONE
	var ball_level: Heights.Level = ball.get_level()
	if height_level == Heights.Level.GROUND and ball_level == Heights.Level.GROUND:
		return CurveVariant.PARABOLIC if is_destroyer_active() else CurveVariant.CURVE
	if ball_level == Heights.Level.SUSPENDED:   # Rin no chão ou suspenso
		return CurveVariant.CRASH if _nearest_enemy(crash_enemy_radius) != null else CurveVariant.TRIVELA
	return CurveVariant.NONE


func get_gravity_variant() -> GravityVariant:
	if height_level != Heights.Level.GROUND:
		return GravityVariant.NONE
	var ball: Ball = _get_ball()
	if _ball_near(ball, puppets_ball_radius, Heights.Level.SUSPENDED) and _allies_in_range().size() > 0:
		return GravityVariant.PUPPETS
	if _nearest_enemy(gravity_range) == null:
		return GravityVariant.NONE
	if _ball_near(ball, ball_near_radius, Heights.Level.GROUND):
		return GravityVariant.DESTRUCTION
	return GravityVariant.MANGLE if is_destroyer_active() else GravityVariant.GRAVITY


func _allies_in_range() -> Array[Player]:
	var list: Array[Player] = []
	for other: Player in get_tree().get_nodes_in_group("players"):
		if other != self and other.team == team and global_position.distance_to(other.global_position) <= puppets_range:
			list.append(other)
	return list


func _curve_name() -> String:
	var variant: CurveVariant = get_curve_variant()
	if variant == CurveVariant.CRASH:
		return "Self Destruction" if _find_reaction() != null else "Crash Shot"   # reação disponível: muda de nome
	if variant == CurveVariant.PARABOLIC or (variant == CurveVariant.NONE and is_destroyer_active()):
		return "Parabolic Shot"
	return "Trivela Shot" if variant == CurveVariant.TRIVELA else "Curve Shot"


func _gravity_name() -> String:
	match get_gravity_variant():
		GravityVariant.DESTRUCTION:
			return "Destruction"
		GravityVariant.PUPPETS:
			return "Puppets"
		GravityVariant.MANGLE:
			return "Mangle You"
		GravityVariant.NONE:
			return "Mangle You" if is_destroyer_active() else "Center of Gravity"
	return "Center of Gravity"


# ---------- CURVE SHOT (e variantes) ----------

## Reação Química que o Rin pode usar agora (Cruel). null = nenhuma. Procura direto a Cruel (não usa
## find_available) para outra reação do Rin não esconder esta.
func _find_reaction() -> ChemicalReaction:
	var rm: ReactionManager = ReactionManager.get_for(self)
	if rm != null:
		for reaction in rm.reactions:
			if reaction is ReactionCruel and rm.is_ready(reaction, team) and reaction.find_partner(self) != null:
				return reaction
	return null


## A força do Chutar geral de cada situação
func _base_force(kind: KickType) -> float:
	match kind:
		KickType.VOLLEY:
			return kick_force_volley
		KickType.FLYING:
			return kick_force_flying
		KickType.HIGH_BALL:
			return kick_force_high_ball
	return kick_force_ground


func _force_mult(variant: CurveVariant, self_destruct: bool) -> float:
	match variant:
		CurveVariant.PARABOLIC:
			return parabolic_force_mult
		CurveVariant.TRIVELA:
			return trivela_force_mult
		CurveVariant.CRASH:
			return crash_force_mult * (self_destruction_force_mult if self_destruct else 1.0)
	return curve_force_mult


func _turn_degrees(variant: CurveVariant) -> float:
	var base: float = curve_turn_degrees
	match variant:
		CurveVariant.PARABOLIC:
			base *= 1.3
		CurveVariant.TRIVELA, CurveVariant.CRASH:
			base *= 1.8
	return base * curve_level_mults[clampi(_curve_level, 0, curve_level_mults.size() - 1)]


## Curve/Parabolic curvam para a ESQUERDA; Trivela/Crash são FIXOS para a DIREITA (em relação ao sentido do chute).
## Rotação positiva = horária na tela = virar à direita de quem anda.
func _curve_side(variant: CurveVariant) -> float:
	return 1.0 if variant == CurveVariant.TRIVELA or variant == CurveVariant.CRASH else -1.0


## Na mira do chute curvo, a roda do mouse (ou Q/E) escolhe o nível da curva
func _input(event: InputEvent) -> void:
	if not _aiming_curve:
		return
	var step: int = 0
	if event is InputEventMouseButton and event.pressed:
		step = 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else 0
	elif event is InputEventKey and event.pressed and not event.echo:
		step = 1 if event.keycode == KEY_E else -1 if event.keycode == KEY_Q else 0
	if step != 0:
		_curve_level = clampi(_curve_level + step, 0, curve_level_mults.size() - 1)
		get_viewport().set_input_as_handled()
		queue_redraw()


func _use_curve_skill() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or get_curve_variant() == CurveVariant.NONE:
		return false
	_aiming_curve = true
	queue_redraw()
	var aim: Vector2 = await m.aim_for_skill(self, curve_aim_range)
	_aiming_curve = false
	queue_redraw()
	var ball: Ball = _get_ball()
	var variant: CurveVariant = get_curve_variant()   # a bola pode ter mudado enquanto ele mirava
	if aim == Vector2.ZERO or variant == CurveVariant.NONE:
		return false   # cancelou: não gasta a ação

	# Reação Cruel (só no Crash Shot): a partida congela, roda a cutscene e SÓ DEPOIS DO DIÁLOGO o chute acontece
	var reaction: ChemicalReaction = _find_reaction() if variant == CurveVariant.CRASH else null
	var rm: ReactionManager = ReactionManager.get_for(self)
	var partner: Player = reaction.find_partner(self) if reaction != null else null
	if reaction != null and partner != null and rm != null:
		await rm.play(reaction, self, partner)
		if m.match_over:
			return false
	else:
		reaction = null

	var chance: float = chance_crash if variant == CurveVariant.CRASH else chance_curve
	var anim: StringName = CURVE_ANIMS[variant]
	var fx: KickFX = kick_fx
	if reaction != null:
		anim = &"self_destruction" if _has_anim(&"self_destruction") else &"crash_shot"
		chance = chance_self_destruction
		fx = self_destruction_fx
		CruelFX.self_destruction_aura(self, global_position, height)   # sombra gigante e círculo mágico na preparação
	else:
		chance = minf(chance + _shot_bonus(), 1.0)   # os 93% do Self Destruction são o valor final

	# Quando a bola sai: o Crash Shot derruba e atordoa o inimigo; a reação lança os efeitos gigantes
	var enemy: Player = _nearest_enemy(crash_enemy_radius) if variant == CurveVariant.CRASH else null
	var on_kick := func(b: Ball) -> void:
		if enemy != null:
			_floor_enemy(enemy, true)
		if reaction != null:
			CruelFX.self_destruction_launch(self, global_position, height, b)

	var force: float = _base_force(get_kick_type(ball)) * _force_mult(variant, reaction != null)
	var peak: Heights.Level = Heights.Level.FLYING if variant == CurveVariant.PARABOLIC else Heights.Level.SUSPENDED
	await _curve_kick(ball, aim, _curve_side(variant), _turn_degrees(variant), peak, chance, anim, force, fx, on_kick)
	if _free_curve:
		_free_curve = false   # o Curve Shot grátis do Puppets: sem recarga
	else:
		start_cooldown(CD_CURVE, curve_cooldown)
	return true


## Chuta a bola e vai girando a velocidade dela durante a trajetória (a curva)
func _curve_kick(ball: Ball, dir: Vector2, side: float, turn_deg: float, peak: Heights.Level, chance: float,
		anim: StringName, force: float, fx: KickFX, on_kick: Callable) -> void:
	if not await play_action(anim, ANIM_KICK):   # a bola só sai no frame de impacto da animação
		return
	var d: Vector2 = dir.normalized()
	var rise: float = maxf(0.0, Heights.to_height(peak) - ball.height)   # sobe só o que falta até o pico
	ball.kick(d, force * kick_force_to_speed, Heights.lift_for_peak(rise, ball.gravity), self, chance)
	ball.play_fx(fx)
	on_kick.call(ball)
	_bonus_shots = maxi(0, _bonus_shots - 1)

	var touches: int = ball.interaction_count
	var elapsed: float = 0.0
	while elapsed < curve_duration:
		await get_tree().physics_frame
		var dt: float = get_physics_process_delta_time()
		elapsed += dt
		# Alguém tocou na bola, o goleiro já decidiu o chute ou a bola foi segurada: acabou a curva
		if ball.interaction_count != touches or ball.hovering or not ball.has_pending_shot():
			break
		ball.velocity = ball.velocity.rotated(side * deg_to_rad(turn_deg) / curve_duration * dt)


# ---------- CENTER OF GRAVITY (e variantes) ----------

func _use_gravity() -> bool:
	var variant: GravityVariant = get_gravity_variant()
	var ok: bool = true
	match variant:
		GravityVariant.NONE:
			return false
		GravityVariant.PUPPETS:
			ok = await _do_puppets()
		GravityVariant.DESTRUCTION:
			ok = await _do_destruction()
		_:   # Center of Gravity / Mangle You
			await play_action(&"mangle_you" if variant == GravityVariant.MANGLE else &"center_of_gravity", &"center_of_gravity")
			await _clash(_nearest_enemy(gravity_range))
	if ok:
		start_cooldown(CD_GRAVITY, gravity_cooldown)
	return ok


## Derruba o inimigo (e atordoa se pedido) com os espinhos do Rin
func _floor_enemy(enemy: Player, stun: bool) -> void:
	enemy.knock_down()
	if stun:
		enemy.apply_lock(self, stun_rounds)
	RinFX.spikes_on(enemy)


## Confronto físico: o Rin vence com 70% (80% no Destroyer Mode). Vence: derruba (Mangle You também atordoa e dá +1 ação
## geral; o Center of Gravity dá +5% nos 2 próximos chutes). Perde: os dois se empurram.
func _clash(enemy: Player) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var mangle: bool = is_destroyer_active()
	RinFX.clash(self, global_position, enemy.global_position)
	if randf() < (chance_mangle if mangle else chance_gravity):
		_floor_enemy(enemy, mangle)
		if mangle:
			extra_general_left += 1
		else:
			_bonus_shots = gravity_bonus_shots
		await get_tree().create_timer(0.15).timeout
		return
	var away: Vector2 = global_position - enemy.global_position
	away = away.normalized() if away.length() > 1.0 else Vector2(-get_attack_dir(), 0.0)
	var tw: Tween = _push(self, away)
	_push(enemy, -away)
	await tw.finished


func _push(who: Node2D, dir: Vector2) -> Tween:
	var tw: Tween = create_tween()
	tw.tween_property(who, "global_position", _clamp_to_field(who.global_position + dir * clash_push), 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tw


func _clamp_to_field(pos: Vector2) -> Vector2:
	var field := get_tree().get_first_node_in_group("field") as Field
	if field == null:
		return pos
	var half: Vector2 = field.pitch_size * 0.5 - Vector2(body_radius, body_radius)
	var l: Vector2 = field.to_local(pos)
	return field.to_global(Vector2(clampf(l.x, -half.x, half.x), clampf(l.y, -half.y, half.y)))


## Avanço de `dist` com a bola grudada (se estiver). Com clash_on_contact, ao encontrar outro inimigo (que não esteja em
## `skip`) para e faz o Center of Gravity com ele.
func _dash(dir: Vector2, dist: float, skip: Array[Player] = [], clash_on_contact: bool = false) -> void:
	var m: MatchManager = _get_manager()
	_carry_dir = dir.normalized()
	face_towards(_carry_dir)
	var start: Vector2 = global_position
	var end: Vector2 = _clamp_to_field(start + _carry_dir * dist)
	var elapsed: float = 0.0
	while elapsed < dash_time and not m.match_over:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		global_position = start.lerp(end, minf(elapsed / dash_time, 1.0))
		if not clash_on_contact:
			continue
		for other: Player in get_tree().get_nodes_in_group("players"):
			if other.team != team and not other.is_down and not skip.has(other) \
					and global_position.distance_to(other.global_position) <= body_radius + other.body_radius + 8.0:
				await _clash(other)
				return


## Destruction: caneta no 1º inimigo (QTE fácil). Ganhou: atordoa, avança com a bola e, no 2º inimigo, faz o Center of Gravity
func _do_destruction() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	var enemy: Player = _nearest_enemy(gravity_range)
	if m == null or enemy == null or not _ball_near(ball, ball_near_radius, Heights.Level.GROUND):
		return false
	var dir: Vector2 = enemy.global_position - global_position
	dir = dir.normalized() if dir.length() > 1.0 else Vector2(get_attack_dir(), 0.0)
	face_towards(dir)
	await play_action(&"destruction", &"center_of_gravity")
	if not await m.run_qte(KickType.VOLLEY):
		return true   # errou a caneta: gastou a ação
	enemy.apply_lock(self, stun_rounds)
	RinFX.spikes_on(enemy, true)
	_grab_ball(ball, dir)
	await _dash(dir, dash_distance, [enemy], true)
	_release_ball()
	return true


## Puppets: passe curvo suspenso até um aliado (QTE fácil). Se chegar: Rin avança, o aliado devolve a bola e o Rin ganha
## um Curve Shot grátis.
func _do_puppets() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or ball == null:
		return false
	var target: Player = await m.pick_ally_for_skill(self, puppets_range)
	if target == null or not _ball_near(ball, puppets_ball_radius, Heights.Level.SUSPENDED):
		return false   # cancelou: não gasta a ação
	face_towards(target.global_position - global_position)
	await play_action(&"puppets")
	RinFX.puppeteer_hand(target, puppets_flight_time + 1.0)
	if not await m.run_qte(KickType.VOLLEY):
		return true   # errou o QTE: o passe não saiu, mas gastou a ação
	await _curved_pass(ball, target)
	var dir: Vector2 = await m.aim_for_skill(self, dash_distance)   # o avanço do Rin (cancelar = não avança)
	m._skill_pick_cancelled = false   # a ação já foi gasta: cancelar a mira não pode devolvê-la
	if dir != Vector2.ZERO:
		await _dash(dir, dash_distance)
	if not m.match_over:
		m.clear_pending_pass()
		await m.run_ground_pass(target, self, ball)   # o aliado devolve para o Rin
		_free_curve = true
	return true


## Passe em arco até o aliado; a curva desvia do inimigo mais perto da linha reta
func _curved_pass(ball: Ball, target: Player) -> void:
	var a: Vector2 = ball.global_position
	var b: Vector2 = target.global_position
	var normal: Vector2 = (b - a).orthogonal().normalized()
	var enemy: Player = _nearest_enemy(INF)
	if enemy != null:   # vai para o lado oposto ao inimigo
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, a, b)
		normal *= -signf((enemy.global_position - closest).dot(normal))
	var control: Vector2 = (a + b) * 0.5 + normal * a.distance_to(b) * PUPPETS_CURVE
	var h: float = ball.height
	ball.register_touch(self)   # o passe conta como toque (autor do gol / assistência)
	await ball.hover_to(a, h, 0.02).finished   # pairando (sem física) para o tween conduzir
	ball.trail_enabled = true
	var step := func(t: float) -> void:
		var u: float = 1.0 - t
		ball.global_position = u * u * a + 2.0 * u * t * control + t * t * b
		ball.height = lerpf(h, Heights.SUSPENDED_HEIGHT, t) + sin(t * PI) * PUPPETS_ARC
	var tw: Tween = create_tween()
	tw.tween_method(step, 0.0, 1.0, puppets_flight_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	ball.trail_enabled = false


# ---------- BOLA GRUDADA ----------

func _grab_ball(ball: Ball, dir: Vector2) -> void:
	_carry_dir = dir.normalized()
	_carried = ball
	ball.register_touch(self)
	ball.collisions_paused = true
	ball.velocity = Vector2.ZERO
	ball.height = 0.0
	ball.vel_z = 0.0
	ball.pending_shot_chance = Ball.NO_SHOT


func _physics_process(delta: float) -> void:
	super(delta)
	if _carried != null and is_instance_valid(_carried):   # a bola acompanha o Rin
		_carried.velocity = Vector2.ZERO
		_carried.global_position = global_position + _carry_dir * (body_radius + _carried.collision_radius + 2.0)


## Solta a bola ao lado do Rin, parada e voltando a colidir normalmente
func _release_ball() -> void:
	if _carried != null and is_instance_valid(_carried):
		_carried.global_position = global_position + _carry_dir * (body_radius + _carried.collision_radius + 2.0)
		_carried.velocity = Vector2.ZERO
		_carried.collisions_paused = false
	_carried = null


# ---------- OPPOSITE DIRECTION (Destroyer Mode) ----------

func _opposite_ready() -> bool:
	return is_destroyer_active() and not _opposite_used and height_level == Heights.Level.GROUND \
		and _ball_near(_get_ball(), ball_near_radius, Heights.Level.GROUND)


## Typing Game; acertou = domina a bola e faz 2 avanços de 140 em direções (de 8) diferentes
func _use_opposite() -> bool:
	var m: MatchManager = _get_manager()
	var ball: Ball = _get_ball()
	if m == null or not _opposite_ready():
		return false
	_opposite_used = true   # uso único: tentar já gasta
	await play_action(&"opposite_direction", &"destroyer_mode")
	var game := Typing.new()
	m.add_child(game)
	game.start(String(typing_words.pick_random()), typing_time, "Opposite Direction!")
	if not await game.finished:
		return true
	_grab_ball(ball, _carry_dir)
	var previous: Vector2 = Vector2.ZERO
	for i in 2:
		var dir: Vector2 = Vector2.ZERO
		while dir == Vector2.ZERO or (previous != Vector2.ZERO and dir.dot(previous) > 0.99):   # a 2ª não repete a 1ª
			var aim: Vector2 = await m.aim_for_skill(self, opposite_dash)
			if aim == Vector2.ZERO:
				break
			dir = Vector2.RIGHT.rotated(roundf(aim.angle() / (PI / 4.0)) * (PI / 4.0))
		if dir == Vector2.ZERO:
			break   # cancelou: encerra os avanços
		await _dash(dir, opposite_dash)
		previous = dir
	_release_ball()
	m._skill_pick_cancelled = false   # a ação já foi gasta
	return true


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var curve_label: String = _curve_name() + " (grátis)" if _free_curve else skill_label(_curve_name(), CD_CURVE)
	var destroyer_label: String = skill_label("Destroyer Mode", CD_DESTROYER)
	if is_destroyer_active():   # com o modo ativo, o botão vira o Opposite Direction
		destroyer_label = "Destroyer Mode (ativo)" if _opposite_used else "Opposite Direction"
	return [
		{"id": SKILL_CURVE, "name": curve_label},
		{"id": SKILL_GRAVITY, "name": skill_label(_gravity_name(), CD_GRAVITY)},
		{"id": SKILL_DESTROYER, "name": destroyer_label},
	]


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_CURVE:
			return (_free_curve or not is_on_cooldown(CD_CURVE)) and get_curve_variant() != CurveVariant.NONE
		SKILL_GRAVITY:
			return not is_on_cooldown(CD_GRAVITY) and get_gravity_variant() != GravityVariant.NONE
		SKILL_DESTROYER:
			return _opposite_ready() if is_destroyer_active() else not is_on_cooldown(CD_DESTROYER)
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_CURVE:
			return await _use_curve_skill()
		SKILL_GRAVITY:
			return await _use_gravity()
		SKILL_DESTROYER:
			if is_destroyer_active():
				return await _use_opposite()
			await play_action(&"destroyer_mode")
			return _use_destroyer()
	return false


## O Curve Shot ganho no Puppets não gasta ação, e o turno não termina enquanto ele não for usado
func skill_is_free(skill_id: StringName) -> bool:
	return skill_id == SKILL_CURVE and _free_curve


func has_free_followup() -> bool:
	return _free_curve and get_curve_variant() != CurveVariant.NONE


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	var icon_key: String = String(skill_id)
	match skill_id:
		SKILL_CURVE:
			title = _curve_name()
			var variant: CurveVariant = get_curve_variant()
			text = "Chute curvo; a bola sobe até %s. %.1fx a força do Chutar, %d%% de chance de gol." % [
				"voando" if variant == CurveVariant.PARABOLIC else "suspenso", _force_mult(variant, false),
				int(round((chance_crash if variant == CurveVariant.CRASH else chance_curve) * 100.0))]
			if variant == CurveVariant.CRASH:
				text += "\nDerruba e atordoa o inimigo próximo. Reação Cruel com o Charles: Self Destruction (%d%%)." % int(round(chance_self_destruction * 100.0))
			text += "\nCurva para a %s. Na mira, a roda do mouse (ou Q/E) escolhe o nível da curva. Recarga: %d rodadas." % [
				"direita" if _curve_side(variant) > 0.0 else "esquerda", curve_cooldown]
		SKILL_GRAVITY:
			title = _gravity_name()
			match get_gravity_variant():
				GravityVariant.DESTRUCTION:
					text = "Caneta no inimigo (QTE fácil): atordoa e avança %d com a bola; no 2º inimigo, faz o Center of Gravity." % int(dash_distance)
				GravityVariant.PUPPETS:
					text = "Passe curvo suspenso (QTE fácil). Se chegar, Rin avança, o aliado devolve e ele ganha um Curve Shot grátis."
				GravityVariant.MANGLE:
					text = "Confronto físico (%d%% de vencer): derruba, atordoa e dá +1 ação geral. Perdendo, os dois se empurram." % int(round(chance_mangle * 100.0))
				_:
					text = "Confronto físico (%d%% de vencer): derruba e dá +%d%% nos próximos %d chutes. Perdendo, os dois se empurram." % [
						int(round(chance_gravity * 100.0)), int(round(gravity_bonus * 100.0)), gravity_bonus_shots]
			text += "\nRecarga: %d rodadas." % gravity_cooldown
		SKILL_DESTROYER:
			if is_destroyer_active():
				title = "Opposite Direction"
				icon_key = "opposite_direction"
				text = "Typing Game (%.1f s): acertando, Rin domina a bola e faz dois avanços de %d em direções diferentes. Uso único." % [typing_time, int(opposite_dash)]
			else:
				title = "Destroyer Mode"
				text = "%d rodadas: +%d%% nos chutes, Parabolic Shot, Mangle You e Opposite Direction.\nRecarga: %d rodadas após o fim." % [
					destroyer_rounds, int(round(destroyer_bonus * 100.0)), destroyer_cooldown]
		_:
			return {}
	return {"title": title, "description": text, "icon": skill_icons.get(icon_key, skill_icons.get(StringName(icon_key))) as Texture2D}


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()   # também zera as recargas
	_destroyer_until_round = -1
	_opposite_used = false
	_free_curve = false
	_bonus_shots = 0
	_aiming_curve = false
	_curve_level = 1
	_release_ball()
	_refresh_aura()
	queue_redraw()


# ---------- VISUAL ----------

func _draw() -> void:
	super()
	if is_destroyer_active():   # anéis verde-água enquanto o Destroyer Mode vale
		draw_arc(Vector2(0.0, -height), placeholder_radius + 7.0, 0.0, TAU, 40, Color(0.176, 0.661, 0.569, 0.9), 2.5)
		draw_arc(Vector2(0.0, -height), placeholder_radius + 11.0, 0.0, TAU, 40, Color(0.293, 0.513, 0.595, 0.5), 1.5)
	if is_aiming and _aiming_curve:
		_draw_curve_preview()
		_draw_curve_level()


## "Curva ●●○": o nível escolhido (roda do mouse / Q E) ao lado do Rin durante a mira
func _draw_curve_level() -> void:
	var levels: int = curve_level_mults.size()
	var dots: String = ""
	for i in levels:
		dots += "●" if i <= _curve_level else "○"
	draw_string(ThemeDB.fallback_font, Vector2(-34.0, -placeholder_radius - 30.0), "Curva %s  (roda do mouse / Q E)" % dots,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.314, 0.909, 0.625))


## Mira do chute curvo: simula a MESMA física do _curve_kick (velocidade inicial, air_drag, taxa de rotação e duração da
## curva), então o desenho bate com o voo real. Sai da posição da BOLA, não do pé do Rin.
func _draw_curve_preview() -> void:
	var ball: Ball = _get_ball()
	if ball == null:
		return
	var variant: CurveVariant = get_curve_variant()
	var dt: float = 1.0 / 60.0
	var pos: Vector2 = to_local(ball.global_position)
	var dir: Vector2 = aim_direction
	var speed: float = _base_force(get_kick_type(ball)) * _force_mult(variant, variant == CurveVariant.CRASH and _find_reaction() != null) * kick_force_to_speed
	var turn_per_sec: float = _curve_side(variant) * deg_to_rad(_turn_degrees(variant)) / curve_duration
	var drag: float = maxf(0.0, 1.0 - ball.air_drag * dt)   # mesmo decay do Ball
	var travelled: float = 0.0
	var steps: int = 0
	while steps < 240 and travelled < PREVIEW_LENGTH and speed > 20.0:
		var seg: Vector2 = dir * speed * dt
		if steps % 2 == 0:
			draw_line(pos, pos + seg, Color(0.314, 0.909, 0.625, 0.961), 3.0)
		pos += seg
		travelled += seg.length()
		if float(steps) * dt < curve_duration:   # só gira enquanto a curva está valendo
			dir = dir.rotated(turn_per_sec * dt)
		speed *= drag
		steps += 1


# ---------- TYPING GAME (era o typing_game.gd) ----------

## Minigame de digitação: aparece uma palavra e o jogador digita as letras em ordem antes de o tempo acabar. Letra errada
## não passa a vez e ainda tira um pedacinho do tempo. Uso: Typing.new(), start(palavra, tempo, título), await finished.
class Typing extends CanvasLayer:
	signal finished(success: bool)

	var _word: String = ""
	var _index: int = 0
	var _limit: float = 4.0
	var _left: float = 0.0
	var _delay: float = 0.6   # "prepare-se" antes de poder digitar
	var _running: bool = false
	var _letters: Array[Label] = []
	var _bar: ProgressBar
	var _result: Label
	var _panel: PanelContainer

	func start(word: String, time_limit: float, title: String = "") -> void:
		layer = 10   # acima do menu da partida (igual ao QTE)
		_word = word.to_upper()
		_limit = time_limit
		_left = time_limit
		_panel = PanelContainer.new()
		_panel.set_anchors_preset(Control.PRESET_CENTER)
		_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		UiStyle.style_panel(_panel, UiStyle.ACCENT_COLOR)
		add_child(_panel)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		_panel.add_child(vbox)
		vbox.add_child(UiStyle.make_label(title, 28))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)
		for ch in _word:
			var l := UiStyle.make_label(ch, 48)
			row.add_child(l)
			_letters.append(l)
		_bar = ProgressBar.new()
		_bar.custom_minimum_size = Vector2(320, 18)
		_bar.show_percentage = false
		_bar.max_value = 1.0
		_bar.value = 1.0
		vbox.add_child(_bar)
		_result = UiStyle.make_label("Digite a palavra!", 24)
		_result.custom_minimum_size = Vector2(0, 40)
		vbox.add_child(_result)
		UiStyle.pop(_panel, 0.85, 0.25)
		_highlight()
		_running = true

	## Letras já digitadas = verde, a atual = amarela, as próximas = neutras
	func _highlight() -> void:
		for i in _letters.size():
			_letters[i].add_theme_color_override("font_color",
				UiStyle.GOOD_COLOR if i < _index else Color.YELLOW if i == _index else UiStyle.TEXT_COLOR)
		if _index < _letters.size():
			UiStyle.pop(_letters[_index], 1.25, 0.2)

	func _process(delta: float) -> void:
		if not _running:
			return
		if _delay > 0.0:
			_delay -= delta
			_result.text = "" if _delay <= 0.0 else _result.text
			return
		_left -= delta
		var ratio: float = clampf(_left / _limit, 0.0, 1.0)
		_bar.value = ratio
		_bar.modulate = UiStyle.BAD_COLOR.lerp(UiStyle.GOOD_COLOR, ratio)   # vai do verde ao vermelho
		if _left <= 0.0:
			_finish(false)

	func _input(event: InputEvent) -> void:
		if not _running or _delay > 0.0 or not (event is InputEventKey and event.pressed and not event.echo) or event.unicode <= 32:
			return   # Shift, setas etc. são ignorados
		get_viewport().set_input_as_handled()
		if char(event.unicode).to_upper() == _word[_index]:
			_index += 1
			_highlight()
			if _index >= _word.length():
				_finish(true)
		else:
			_left -= 0.4
			_flash(0.2)

	func _flash(time: float) -> void:   # painel avermelhado que volta ao normal
		_panel.modulate = Color(1.0, 0.6, 0.6)
		create_tween().tween_property(_panel, "modulate", Color.WHITE, time)

	func _finish(success: bool) -> void:
		if not _running:
			return
		_running = false
		_result.text = "Perfeito!" if success else "Errou!"
		_result.add_theme_color_override("font_color", UiStyle.GOOD_COLOR if success else UiStyle.BAD_COLOR)
		UiStyle.pop(_result, 1.5, 0.3)
		if not success:
			_flash(0.4)
		await get_tree().create_timer(0.5).timeout
		finished.emit(success)
		queue_free()
