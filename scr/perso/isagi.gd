class_name Isagi
extends Player
## Isagi Yoichi. Herda tudo do Player (ações gerais) e adiciona as habilidades próprias:
##
## 1. Backheel Shot (recarga 2, compartilhada; a variante vem da altura dele e da bola):
##      - os dois no chão                    -> Backheel Shot: calcanhar para trás, força do Chutar, 40%
##      - bola Suspensa; ele no chão/suspenso -> Direct Shot: 1.2x a força do Chutar, 45%
##      - bola Voando; ele suspenso           -> Two Gun Volley: 1.4x a força do Chutar, 50%
## 2. Pieces (recarga 3 após o fim): 3 peças fixas no campo por 4 rodadas. Dentro de cada uma:
##      - Ataque: +5% e +0.2x de força nos chutes   - Meio: +0.6 s no Correr e +25 no alcance do Passe
##      - Defesa: +20 no alcance do Carrinho
##    Com as peças ativas o botão vira a variante da peça em que ele está (recarga 2, compartilhada):
##      - Ataque, My Own Goal: aliado no chão com a bola a 90 dele e a 170 do Isagi passa rasteiro; chute 1.1x, 45%
##      - Meio (no chão), Naruhaya Footwork: avanço de 240 que empurra quem está no chão; achou a bola = +1 ação geral
##      - Defesa, See It: no turno inimigo, um chute que entra a 250 dele é interceptado (no chão: passa para o aliado
##        mais próximo num raio de 300 e, se não houver nenhum, a bola fica com ele; suspenso: ele salta até a bola e dá
##        deflect 0.4x para a direita; voando: ele salta até a bola e dá deflect 0.3x para trás)
## 3. Metavision (recarga 3 após o fim): 3 rodadas sem QTE, +8% nos próximos 3 chutes e, se ele for o protagonista,
##    +1 ação de habilidade para os secundários. Com a bola a 110 (no chão/suspensa) vira Territory:
##    puxa a bola para si e o bônus sobe para 10%.
##
## Reação Química ONE MORE TIME (com o Hiori, reaction_one_more_time.gd): com a Metavision dele e a Coldest Metavision
## do Hiori ativas, e o Ultrasadist como dono da bola, o Direct Shot vira o Go Beyond (muito mais forte, 85%).
##
## Cena: Nova Cena Herdada de player.tscn -> anexe este script ao nó raiz -> renomeie o nó raiz para "Isagi".
## A peça de quebra-cabeça é a classe interna Piece (no fim do arquivo): o piece_zone.gd não é mais necessário.
##
## Visual: todas as habilidades soltam peças de quebra-cabeça azul-escuras e azul-claras (isagi_fx.gd, leve:
## poucas partículas, vida curta). Dá para desligar com puzzle_particles.

const SKILL_SHOT: StringName = &"backheel_shot"
const SKILL_PIECES: StringName = &"pieces"
const SKILL_METAVISION: StringName = &"metavision"
const CD_SHOT: StringName = &"cd_shot"           # as 3 variantes do chute compartilham
const CD_PIECES: StringName = &"cd_pieces"
const CD_VARIANT: StringName = &"cd_piece_variant"   # My Own Goal, Footwork e See It compartilham
const CD_METAVISION: StringName = &"cd_metavision"   # Metavision e Territory compartilham

enum ShotVariant { NONE, BACKHEEL, DIRECT, TWO_GUN }
enum PieceSkill { NONE, MAIN, OWN_GOAL, FOOTWORK, SEE_IT }

@export_group("Backheel Shot")
@export_range(0.0, 1.0) var chance_backheel: float = 0.40
@export_range(0.0, 1.0) var chance_direct: float = 0.45
@export_range(0.0, 1.0) var chance_two_gun: float = 0.50
@export var direct_force_mult: float = 1.1    # múltiplos da força do Chutar
@export var two_gun_force_mult: float = 1.2
@export var shot_cooldown: int = 2
@export var shot_skills_use_qte: bool = false  # ligue para o Direct Shot e o Two Gun voltarem a ter QTE

@export_group("Go Beyond (reação One More Time)")
@export_range(0.0, 1.0) var chance_go_beyond: float = 0.85   # valor final de chance
@export var go_beyond_force_mult: float = 2.2
@export var go_beyond_fx: KickFX                             # vazio = estilo padrão (_make_fx)

@export_group("Pieces")
@export var piece_size: Vector2 = Vector2(500.0, 650.0)
## Posição de cada peça no eixo do campo (fração da metade do comprimento; positivo = rumo ao gol que o time ataca)
@export var attack_piece_x: float = 0.55
@export var midfield_piece_x: float = 0.0
@export var defense_piece_x: float = -0.55
@export var pieces_rounds: int = 4                 # duração total (contando a atual)
@export var pieces_cooldown: int = 3               # recarga a partir do fim do efeito
@export var variant_cooldown: int = 2              # recarga das variantes (My Own Goal / Footwork / See It)
@export_range(0.0, 1.0) var attack_piece_bonus: float = 0.05
@export var attack_piece_force: float = 0.2        # soma na força dos chutes
@export var midfield_run_bonus: float = 0.6        # segundos a mais no Correr
@export var midfield_pass_bonus: float = 25.0      # alcance a mais no Passe
@export var defense_slide_bonus: float = 20.0      # alcance a mais no Carrinho

@export_group("My Own Goal")
@export var own_goal_ally_range: float = 170.0     # do Isagi até o aliado
@export var own_goal_ball_radius: float = 90.0     # da bola até o aliado
@export var own_goal_force_mult: float = 1.1
@export_range(0.0, 1.0) var chance_own_goal: float = 0.45

@export_group("Naruhaya Footwork")
@export var footwork_distance: float = 240.0
@export var footwork_push: float = 70.0            # quanto empurra para o lado
@export var footwork_time: float = 0.28

@export_group("See It")
@export var see_it_range: float = 125.0
@export var see_it_pass_range: float = 300.0     # no chão: raio (a partir do Isagi) do aliado que recebe o passe; sem aliado, a bola fica com ele
@export var deflect_side_mult: float = 0.4         # suspenso: deflect para a direita
@export var deflect_air_mult: float = 0.3          # voando: deflect para trás
@export var deflect_lift: float = 60.0

@export_group("Metavision / Territory")
@export var metavision_rounds: int = 3             # rodadas depois da atual
@export_range(0.0, 1.0) var metavision_bonus: float = 0.08
@export var metavision_shots: int = 3              # chutes que recebem o bônus
@export var metavision_extra_ally_skills: int = 1  # só se o Isagi for o protagonista
@export var metavision_cooldown: int = 3           # a partir do fim do efeito
@export var territory_range: float = 110.0
@export_range(0.0, 1.0) var territory_bonus: float = 0.10

@export_group("Visual / descrição")
## Peças de quebra-cabeça azuis nas habilidades (isagi_fx.gd)
@export var puzzle_particles: bool = true
@export var kick_fx: KickFX                        # vazio = estilo padrão (_make_fx)
## Imagem de cada habilidade no balão do menu. Chaves: backheel_shot, pieces, metavision
@export var skill_icons: Dictionary = {}

var _pieces: Array[Piece] = []
var _pieces_until_round: int = -1                  # peças valem até o fim desta rodada (-1 = inativas)
var _pieces_shown: bool = false
var _base_run: float = 0.0
var _base_slide: float = 0.0
var _pass_buff: float = 0.0                        # bônus de passe da peça do meio já somado
var _no_piece_bonus: bool = false                  # My Own Goal: o chute não recebe o bônus da peça
var _see_it_armed: bool = false                    # See It ligado, esperando o turno inimigo
var _see_it_live: bool = false                     # turno inimigo em andamento: procurando o chute
var _reacting: bool = false
var _metavision_until_round: int = -1
var _meta_bonus: float = 0.0
var _meta_shots_left: int = 0
var _aiming_backheel: bool = false                 # mirando o Backheel: desenha para onde a bola vai
var _aura: CPUParticles2D                          # peças que giram em volta dele (Metavision / See It)


func _init() -> void:
	character_id = "isagi"          # o menu de formação usa isto para saber quem é quem
	display_name = "Yoichi Isagi"   # aparece no placar de gols e no menu


func _ready() -> void:
	super()
	if kick_fx == null:
		kick_fx = _make_fx()
	if go_beyond_fx == null:
		go_beyond_fx = _make_fx(true)
	_base_run = run_duration
	_base_slide = slide_distance
	_build_pieces.call_deferred()   # o Field e o MatchManager entram na árvore no mesmo frame
	_hook_manager.call_deferred()
	if puzzle_particles:
		_aura = IsagiFX.make_aura()
		add_child(_aura)


## Azul Blue Lock; as partículas são "peças" quadradas que giram e sobem. strong = Go Beyond: elétrico, mais largo e cheio de brilhos
func _make_fx(strong: bool = false) -> KickFX:
	var fx := KickFX.new()
	fx.color = Color(0.25, 0.7, 1.0) if strong else Color(0.2, 0.6, 1.0)
	fx.particle_color = Color(0.85, 0.97, 1.0) if strong else Color(0.7, 0.95, 1.0)
	fx.shape = KickFX.Shape.SQUARE
	fx.trail_width = 30.0 if strong else 14.0
	fx.amount = 60 if strong else 22
	fx.lifetime = 0.8 if strong else 0.55
	fx.speed_min = 15.0
	fx.speed_max = 120.0 if strong else 70.0
	fx.gravity = Vector2(0.0, -60.0)
	fx.spin = 480.0 if strong else 360.0
	fx.scale_min = 0.2 if strong else 0.15
	fx.scale_max = 0.5 if strong else 0.35
	fx.burst_amount = 40 if strong else 14
	fx.burst_speed = 380.0 if strong else 220.0
	return fx


func _exit_tree() -> void:
	for z in _pieces:
		if is_instance_valid(z):
			z.queue_free()


func _hook_manager() -> void:
	var m: MatchManager = _get_manager()
	if m == null:
		return
	m.round_started.connect(_on_round_started)
	m.sides_swapped.connect(_place_pieces)   # virou o lado: as peças acompanham o ataque
	m.turn_started.connect(_on_turn_started)
	m.bonus_turn_started.connect(_on_turn_started)


func _on_round_started(_round_number: int) -> void:
	queue_redraw()   # a aura da Metavision some quando as rodadas acabam
	if _pieces_shown and not is_pieces_active():
		_pieces_shown = false
		for z in _pieces:
			z.fade(false)


## See It: começou o turno do inimigo = procura o chute; voltou a vez do Isagi = desliga
func _on_turn_started(started_team: int) -> void:
	_see_it_live = _see_it_armed and started_team != team
	if started_team == team:
		_see_it_armed = false
	queue_redraw()


# ---------- PEÇAS ----------

func _build_pieces() -> void:
	var field := get_tree().get_first_node_in_group("field") as Field
	if field == null:
		push_warning("Isagi: nenhum Field encontrado; as peças do Pieces não foram criadas.")
		return
	var looks: Array = [["ATAQUE", Color(0.0, 0.429, 0.89, 1.0)], ["MEIO-CAMPO", Color(0.0, 0.341, 0.719, 1.0)],
		["DEFESA", Color(0.0, 0.267, 0.574, 1.0)]]
	for i in 3:
		var z := Piece.new(i as Piece.Kind, piece_size, looks[i][1], looks[i][0])
		field.add_child(z)
		_pieces.append(z)
	_place_pieces()


## Coloca as peças de acordo com o lado que o time ataca AGORA (virada de lado, uso do Pieces, partida nova)
func _place_pieces() -> void:
	var field := get_tree().get_first_node_in_group("field") as Field
	if field == null:
		return
	var fractions: Array[float] = [attack_piece_x, midfield_piece_x, defense_piece_x]
	for z in _pieces:
		if is_instance_valid(z):
			var x: float = get_attack_dir() * fractions[z.kind] * field.pitch_size.x * 0.5
			z.global_position = field.to_global(Vector2(x, 0.0))


func is_pieces_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _pieces_until_round >= 0 and m.round_number <= _pieces_until_round


func _in_piece(kind: Piece.Kind) -> bool:
	if not is_pieces_active():
		return false
	for z in _pieces:
		if z.kind == kind and z.contains(global_position):
			return true
	return false


## Meio: Correr maior e Passe mais longo. Defesa: Carrinho mais longo. Só atualiza com ele parado, para o
## valor não mudar no meio de uma corrida/carrinho (e os previews já mostram o alcance certo).
func _update_piece_buffs() -> void:
	var mid: bool = _in_piece(Piece.Kind.MIDFIELD)
	run_duration = _base_run + (midfield_run_bonus if mid else 0.0)
	slide_distance = _base_slide + (defense_slide_bonus if _in_piece(Piece.Kind.DEFENSE) else 0.0)
	var pass_buff: float = midfield_pass_bonus if mid else 0.0
	pass_range_bonus += pass_buff - _pass_buff
	_pass_buff = pass_buff


## Ataque: +0.2x de força em qualquer chute (soma ao multiplicador que o chute já tiver)
func kick_ball(ball: Ball, direction: Vector2, kind: KickType, qte_success: bool = true,
		chance_override: float = -1.0, ignore_self_collision: bool = false,
		fx: KickFX = null, anim: StringName = &"", on_kick: Callable = Callable()) -> void:
	if not _no_piece_bonus and _in_piece(Piece.Kind.ATTACK):
		next_kick_force_mult += attack_piece_force
	var counts_for_metavision: bool = is_metavision_active() and _meta_shots_left > 0
	await super(ball, direction, kind, qte_success, chance_override, ignore_self_collision, fx, anim, on_kick)
	if counts_for_metavision:
		_meta_shots_left -= 1   # gasta um dos chutes com bônus da Metavision (depois do chute, que ainda usa o bônus)


# ---------- BÔNUS DE CHUTE (peça de ataque + Metavision) ----------

func _shot_bonus() -> float:
	var bonus: float = 0.0
	if not _no_piece_bonus and _in_piece(Piece.Kind.ATTACK):
		bonus += attack_piece_bonus
	if is_metavision_active() and _meta_shots_left > 0:
		bonus += _meta_bonus
	return bonus


## Vale também para o Chutar geral: base do tipo de chute + bônus
func get_shot_chance(kind: KickType) -> float:
	return minf(super(kind) + _shot_bonus(), 1.0)


## Com a Metavision ativa o MatchManager não roda o QTE dos chutes dele
func skips_qte() -> bool:
	return is_metavision_active()


# ---------- BACKHEEL SHOT (e variantes) ----------

func get_shot_variant() -> ShotVariant:
	var ball: Ball = _get_ball()
	# get_kick_type já confere: derrubado, bola na mão do goleiro, longe demais, altura inalcançável
	if get_kick_type(ball) == KickType.NONE:
		return ShotVariant.NONE
	var ball_level: Heights.Level = ball.get_level()
	if height_level == Heights.Level.GROUND:
		if ball_level == Heights.Level.GROUND:
			return ShotVariant.BACKHEEL
		return ShotVariant.DIRECT if ball_level == Heights.Level.SUSPENDED else ShotVariant.NONE
	if ball_level == Heights.Level.FLYING:
		return ShotVariant.TWO_GUN
	# Isagi e bola os dois suspensos: também é Direct Shot
	if height_level == Heights.Level.SUSPENDED and ball_level == Heights.Level.SUSPENDED:
		return ShotVariant.DIRECT
	return ShotVariant.NONE


func _shot_skill_name() -> String:
	match get_shot_variant():
		ShotVariant.DIRECT:
			return "Go Beyond" if _find_reaction() != null else "Direct Shot"   # Reação Química disponível
		ShotVariant.TWO_GUN:
			return "Two Gun Volley"
	return "Backheel Shot"


## Reação Química que o Isagi pode usar agora (One More Time). null = nenhuma.
func _find_reaction() -> ChemicalReaction:
	var rm: ReactionManager = ReactionManager.get_for(self)
	return rm.find_available(self) if rm != null else null


## A partida congela, roda a cutscene e SÓ DEPOIS DO DIÁLOGO o chute acontece. null = sem reação.
func _play_reaction() -> ChemicalReaction:
	var reaction: ChemicalReaction = _find_reaction()
	var rm: ReactionManager = ReactionManager.get_for(self)
	var partner: Player = reaction.find_partner(self) if reaction != null else null
	if reaction == null or partner == null or rm == null:
		return null
	await rm.play(reaction, self, partner)
	return reaction


func _use_shot_skill() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or get_shot_variant() == ShotVariant.NONE:
		return false

	# Mira. No Backheel a seta laranja é para onde ele "olha"; a bola vai para o lado oposto.
	_aiming_backheel = get_shot_variant() == ShotVariant.BACKHEEL
	queue_redraw()
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	_aiming_backheel = false
	queue_redraw()
	var ball: Ball = _get_ball()
	var variant: ShotVariant = get_shot_variant()   # a bola pode ter rolado enquanto ele mirava
	if aim == Vector2.ZERO or variant == ShotVariant.NONE:
		return false   # cancelou: não gasta a ação

	var reaction: ChemicalReaction = null
	if variant == ShotVariant.DIRECT:
		reaction = await _play_reaction()
		if m.match_over:
			return false

	var kind: KickType = KickType.GROUND
	var dir: Vector2 = aim
	var chance: float = chance_backheel
	var force: float = 1.0
	var anim: StringName = &"backheel_shot"
	var fx: KickFX = kick_fx
	var on_kick: Callable = Callable()
	match variant:
		ShotVariant.BACKHEEL:
			dir = -aim
		ShotVariant.DIRECT:
			kind = get_kick_type(ball)   # a força é a do Chutar dessa situação
			chance = chance_direct
			force = direct_force_mult
			anim = &"direct_shot"
			if reaction != null:   # Go Beyond: mesmo chute, muito mais forte e com o vidro quebrando
				chance = chance_go_beyond
				force = go_beyond_force_mult
				fx = go_beyond_fx
				anim = &"go_beyond" if _has_art and animated_sprite.sprite_frames.has_animation(&"go_beyond") else &"direct_shot"
				on_kick = _launch_go_beyond
		ShotVariant.TWO_GUN:
			kind = KickType.FLYING
			chance = chance_two_gun
			force = two_gun_force_mult
			anim = &"two_gun_volley"

	var qte_ok: bool = true
	if shot_skills_use_qte and variant != ShotVariant.BACKHEEL and reaction == null and not skips_qte():
		qte_ok = await m.run_qte(KickType.FLYING if variant == ShotVariant.TWO_GUN else KickType.VOLLEY)
	if on_kick.is_null() and qte_ok:
		on_kick = _launch_shot_fx   # peças no chute (o Go Beyond tem o seu, que já chama este)
	next_kick_force_mult *= force   # gasto dentro do kick_ball
	if reaction == null:
		chance = minf(chance + _shot_bonus(), 1.0)   # os 85% do Go Beyond são o valor final
	# Backheel: a bola ignora a colisão do próprio Isagi. Errou o QTE = chute fraquinho, sem aura.
	await kick_ball(ball, dir, kind, qte_ok, chance, variant == ShotVariant.BACKHEEL,
		fx if qte_ok else null, anim, on_kick)
	start_cooldown(CD_SHOT, shot_cooldown)
	return true


## Go Beyond: chamado pelo kick_ball() logo depois que a bola sai. Peças de gelo, clarão, tremida e vidro quebrando.
func _launch_go_beyond(ball: Ball, _dir: Vector2, _speed: float) -> void:
	OneMoreTimeFX.go_beyond_burst(self, global_position + Vector2(0.0, -height),
		ball.sprite.global_position, ball)
	_launch_shot_fx(ball, Vector2.ZERO, 0.0, true)


# ---------- PIECES (e variantes) ----------

## O que o botão Pieces faz agora. Sem peças ativas: criar as peças. Com elas ativas: a variante da peça
## em que o Isagi está (se as condições dela valerem e a recarga compartilhada estiver pronta).
func _piece_skill() -> PieceSkill:
	if not is_pieces_active():
		var can_make: bool = not _pieces.is_empty() and not is_on_cooldown(CD_PIECES)
		return PieceSkill.MAIN if can_make else PieceSkill.NONE
	if is_on_cooldown(CD_VARIANT):
		return PieceSkill.NONE
	if _in_piece(Piece.Kind.ATTACK) and height_level != Heights.Level.FLYING and _own_goal_ready():
		return PieceSkill.OWN_GOAL
	if _in_piece(Piece.Kind.MIDFIELD) and height_level == Heights.Level.GROUND:
		return PieceSkill.FOOTWORK
	if _in_piece(Piece.Kind.DEFENSE) and not _see_it_armed:
		return PieceSkill.SEE_IT
	return PieceSkill.NONE


func _pieces_label() -> String:
	match _piece_skill():
		PieceSkill.OWN_GOAL:
			return skill_label("My Own Goal", CD_VARIANT)
		PieceSkill.FOOTWORK:
			return skill_label("Naruhaya Footwork", CD_VARIANT)
		PieceSkill.SEE_IT:
			return skill_label("See It", CD_VARIANT)
		PieceSkill.NONE:
			if is_pieces_active():
				return "Pieces (ativo)"
	return skill_label("Pieces", CD_PIECES)


func _use_piece_skill() -> bool:
	match _piece_skill():
		PieceSkill.MAIN:
			await play_action(&"pieces")   # as peças aparecem no frame de impacto
			return _use_pieces()
		PieceSkill.OWN_GOAL:
			return await _use_own_goal()
		PieceSkill.FOOTWORK:
			return await _use_footwork()
		PieceSkill.SEE_IT:
			await play_action(&"see_it")
			_see_it_armed = true
			_puzzle_ring(global_position, see_it_range, 18)   # mostra a área de detecção
			_puzzle_burst(_body_point(), 8)
			start_cooldown(CD_VARIANT, variant_cooldown)
			queue_redraw()
			return true
	return false


func _use_pieces() -> bool:
	var m: MatchManager = _get_manager()
	if m == null or _pieces.is_empty():
		return false
	_pieces_until_round = m.round_number + pieces_rounds - 1   # a rodada atual conta
	start_cooldown(CD_PIECES, pieces_cooldown, _pieces_until_round + 1)
	_pieces_shown = true
	_place_pieces()   # garante o lado certo antes de aparecerem
	for z in _pieces:
		z.fade(true)
		_puzzle_area(z.global_position, piece_size * 0.9, 16)   # as peças se montando em cada zona
	_puzzle_burst(_body_point(), 10)
	return true


## My Own Goal: aliado no chão, com a bola (no chão/suspensa) a 90 dele, a 170 do Isagi
func _own_goal_ally_ok(o: Player) -> bool:
	var ball: Ball = _get_ball()
	return o != self and o.team == team and not o.is_down and o.height_level == Heights.Level.GROUND \
		and ball != null and ball.get_level() != Heights.Level.FLYING and not ball.is_held() \
		and o.global_position.distance_to(ball.global_position) <= own_goal_ball_radius


func _own_goal_ready() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	for o in m.get_team_players(team):
		if _own_goal_ally_ok(o) and global_position.distance_to(o.global_position) <= own_goal_ally_range:
			return true
	return false


## O aliado é obrigado a passar rasteiro para o Isagi; se a bola chegar, ele chuta com 1.1x (sem o bônus da peça)
func _use_own_goal() -> bool:
	var m: MatchManager = _get_manager()
	var ally: Player = await m.pick_ally_for_skill(self, own_goal_ally_range, false, _own_goal_ally_ok)
	if ally == null:
		return false
	var aim: Vector2 = await m.aim_for_skill(self, kick_aim_range)
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação
	start_cooldown(CD_VARIANT, variant_cooldown)
	var ball: Ball = _get_ball()
	_puzzle_line(ally.global_position, global_position, 14)   # o passe forçado: aliado -> Isagi
	_puzzle_burst(ally.global_position, 8)
	await m.run_ground_pass(ally, self, ball)
	var kind: KickType = get_kick_type(ball)
	if kind == KickType.NONE or m.match_over:
		return true   # a bola não chegou: o passe foi o que valeu
	_no_piece_bonus = true
	next_kick_force_mult *= own_goal_force_mult
	await kick_ball(ball, aim, kind, true, minf(chance_own_goal + _shot_bonus(), 1.0), false, kick_fx, &"direct_shot", _launch_shot_fx)
	_no_piece_bonus = false
	return true


## Naruhaya Footwork: avanço que empurra para o lado quem está no chão (os outros são ignorados).
## Se achar a bola no caminho, ganha mais uma ação geral.
func _use_footwork() -> bool:
	var m: MatchManager = _get_manager()
	var aim: Vector2 = await m.aim_for_skill(self, footwork_distance)
	if aim == Vector2.ZERO:
		return false   # cancelou: não gasta a ação
	var dir: Vector2 = aim.normalized()
	face_towards(dir)
	if not await play_action(&"naruhaya_footwork"):
		return false
	start_cooldown(CD_VARIANT, variant_cooldown)

	var start: Vector2 = global_position
	var end: Vector2 = _clamp_to_field(start + dir * footwork_distance, body_radius)
	_puzzle_line(start, end, 18)   # o rastro do avanço
	_puzzle_burst(start, 8)
	var ball: Ball = _get_ball()
	var pushed: Array[Player] = []
	var got_ball: bool = false
	var elapsed: float = 0.0
	while elapsed < footwork_time and not m.match_over:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		global_position = start.lerp(end, minf(elapsed / footwork_time, 1.0))
		for o: Player in get_tree().get_nodes_in_group("players"):
			if o == self or pushed.has(o) or o.height_level != Heights.Level.GROUND:
				continue   # quem não está no chão é ignorado
			var rel: Vector2 = o.global_position - global_position
			if rel.length() > body_radius + o.body_radius + 8.0:
				continue
			pushed.append(o)
			var side: Vector2 = -dir.orthogonal() * (1.0 if dir.cross(rel) >= 0.0 else -1.0)
			create_tween().tween_property(o, "global_position",
				_clamp_to_field(o.global_position + side * footwork_push, o.body_radius), 0.2) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if not got_ball and ball != null and not ball.is_held() and can_reach_level(ball.get_level()) \
				and global_position.distance_to(ball.global_position) <= body_radius + ball.collision_radius + 8.0:
			got_ball = true
			extra_general_left += 1
			_puzzle_burst(_ball_point(ball), 8)   # achou a bola: +1 ação geral
	return true


## Mantém um ponto dentro do campo (a margem é o raio de quem está sendo movido)
func _clamp_to_field(pos: Vector2, radius: float) -> Vector2:
	var field := get_tree().get_first_node_in_group("field") as Field
	if field == null:
		return pos
	var half: Vector2 = field.pitch_size * 0.5 - Vector2(radius, radius)
	var l: Vector2 = field.to_local(pos)
	return field.to_global(Vector2(clampf(l.x, -half.x, half.x), clampf(l.y, -half.y, half.y)))


## See It (turno inimigo): primeiro chute inimigo que entra na área de detecção
func _scan_for_shot() -> void:
	var ball: Ball = _get_ball()
	if ball == null or _reacting or not ball.has_pending_shot() or ball.shot_team == team \
			or ball.global_position.distance_to(global_position) > see_it_range:
		return
	_reacting = true
	_see_it_live = false
	_see_it_armed = false
	queue_redraw()
	await _react_to_shot(ball)
	_reacting = false


func _react_to_shot(ball: Ball) -> void:
	var m: MatchManager = _get_manager()
	var speed: float = ball.velocity.length()
	var dir: Vector2 = ball.velocity.normalized() if speed > 1.0 else Vector2(get_attack_dir(), 0.0)
	_puzzle_burst(_ball_point(ball), 14, true)   # interceptou o chute
	match ball.get_level():
		Heights.Level.GROUND:
			# Vai até a bola, para ela e passa para o aliado mais próximo
			ball.velocity = Vector2.ZERO
			ball.pending_shot_chance = Ball.NO_SHOT
			face_towards(ball.global_position - global_position)
			var tw := create_tween()
			tw.tween_property(self, "global_position", _clamp_to_field(ball.global_position, body_radius), 0.18)
			await tw.finished
			# O aliado MAIS PRÓXIMO, mas só dentro do alcance (see_it_pass_range); se não houver nenhum, a bola fica com ele
			var ally: Player = null
			for o in m.get_team_players(team):
				if o == self or o.is_down or global_position.distance_to(o.global_position) > see_it_pass_range:
					continue
				if ally == null or o.global_position.distance_to(global_position) \
						< ally.global_position.distance_to(global_position):
					ally = o
			if m.match_over:
				return
			if ally != null:
				_puzzle_line(global_position, ally.global_position, 12)
				_puzzle_trail(ball)
				await m.run_ground_pass(self, ally, ball)
			else:
				await _keep_ball(ball)
		Heights.Level.SUSPENDED:
			# O ISAGI salta até a bola e rebate para a direita
			var was_ground_s: bool = height_level == Heights.Level.GROUND
			await _jump_to_ball(ball)
			ball.kick(dir.rotated(PI * 0.5), speed * deflect_side_mult, deflect_lift, self, Ball.NO_SHOT)
			if was_ground_s:
				await get_tree().create_timer(0.35).timeout
				land()
		Heights.Level.FLYING:
			# O ISAGI salta até a bola (Suspenso) e a devolve para trás
			var was_ground: bool = height_level == Heights.Level.GROUND
			await _jump_to_ball(ball)
			ball.kick(-dir, speed * deflect_air_mult, deflect_lift, self, Ball.NO_SHOT)
			if was_ground:
				await get_tree().create_timer(0.35).timeout
				land()


## Quem rebate é o Isagi, não a área: ele salta até a bola (parada no ar) antes do deflect
func _jump_to_ball(ball: Ball) -> void:
	ball.pending_shot_chance = Ball.NO_SHOT   # chute interceptado: o goleiro não decide mais nada
	ball.velocity = Vector2.ZERO
	ball.vel_z = 0.0
	face_towards(ball.global_position - global_position)
	height_level = Heights.Level.SUSPENDED
	var spot: Vector2 = _clamp_to_field(ball.global_position - Vector2(facing * (body_radius + ball.collision_radius + 4.0), 0.0), body_radius)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", spot, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "height", Heights.SUSPENDED_HEIGHT, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished


# ---------- METAVISION / TERRITORY ----------

func is_metavision_active() -> bool:
	var m: MatchManager = _get_manager()
	return m != null and _metavision_until_round >= 0 and m.round_number <= _metavision_until_round


## Territory: bola próxima (no chão ou suspensa)
func _territory_ready() -> bool:
	var ball: Ball = _get_ball()
	return ball != null and not ball.is_held() and not ball.is_locked_for(team) \
		and ball.get_level() != Heights.Level.FLYING \
		and global_position.distance_to(ball.global_position) <= territory_range


func _use_metavision() -> bool:
	var m: MatchManager = _get_manager()
	if m == null:
		return false
	var territory: bool = _territory_ready()
	if territory:   # puxa a bola para os pés dele e depois ativa a Metavision
		var ball: Ball = _get_ball()
		_puzzle_line(_ball_point(ball), _body_point(), 10)   # Territory: a bola sendo puxada
		var spot: Vector2 = global_position + Vector2(facing * (body_radius + ball.collision_radius + 6.0), 0.0)
		ball.register_touch(self)
		await ball.hover_to(spot, 0.0, 0.3).finished
		ball.release_hover()
	_metavision_until_round = m.round_number + metavision_rounds
	_meta_bonus = territory_bonus if territory else metavision_bonus
	_meta_shots_left = metavision_shots
	start_cooldown(CD_METAVISION, metavision_cooldown, _metavision_until_round + 1)
	if role == Role.PROTAGONIST:
		m.secondary_skill_left += metavision_extra_ally_skills
	_puzzle_ring(_body_point(), 40.0, 16)
	_puzzle_burst(_body_point(), 8)
	queue_redraw()
	return true


# ---------- SISTEMA DE HABILIDADES (menu) ----------

func get_skills() -> Array[Dictionary]:
	var meta_name: String = "Territory" if _territory_ready() else "Metavision"
	return [
		{"id": SKILL_SHOT, "name": skill_label(_shot_skill_name(), CD_SHOT)},
		{"id": SKILL_PIECES, "name": _pieces_label()},
		{"id": SKILL_METAVISION, "name": "Metavision (ativa)" if is_metavision_active() else skill_label(meta_name, CD_METAVISION)},
	]


func can_use_skill(skill_id: StringName = &"default") -> bool:
	if not super(skill_id):
		return false
	match skill_id:
		SKILL_SHOT:
			return not is_on_cooldown(CD_SHOT) and get_shot_variant() != ShotVariant.NONE
		SKILL_PIECES:
			return _piece_skill() != PieceSkill.NONE
		SKILL_METAVISION:
			return not is_metavision_active() and not is_on_cooldown(CD_METAVISION)
	return false


func use_skill(skill_id: StringName = &"default") -> bool:
	match skill_id:
		SKILL_SHOT:
			return await _use_shot_skill()
		SKILL_PIECES:
			return await _use_piece_skill()
		SKILL_METAVISION:
			await play_action(&"territory" if _territory_ready() else &"metavision")
			return await _use_metavision()
	return false


# ---------- DESCRIÇÃO (balão do menu, ver action_menu.gd) ----------

func _pct(value: float) -> int:
	return int(round(value * 100.0))


func get_skill_info(skill_id: StringName) -> Dictionary:
	var title: String = ""
	var text: String = ""
	match skill_id:
		SKILL_SHOT:
			title = _shot_skill_name()
			var chances: Array[float] = [chance_backheel, chance_direct, chance_two_gun]
			match get_shot_variant():
				ShotVariant.BACKHEEL:
					text = "Calcanhar: a bola vai para o lado contrário da mira. %d%% de chance de gol." % _pct(chance_backheel)
				ShotVariant.DIRECT:
					var reaction: ChemicalReaction = _find_reaction()
					text = "Reação Química One More Time: voleio muito mais forte com vidro quebrando. %d%% de chance de gol." % _pct(chance_go_beyond) \
						if reaction != null else "Chute direto, %.1fx a força do Chutar. %d%% de chance de gol." % [direct_force_mult, _pct(chance_direct)]
				ShotVariant.TWO_GUN:
					text = "Chute direto no ar, %.1fx a força do Chutar. %d%% de chance de gol." % [two_gun_force_mult, _pct(chance_two_gun)]
				_:
					text = "Muda conforme a altura dele e da bola. De %d%% a %d%% de chance de gol." % [_pct(chances.min()), _pct(chances.max())]
			text += "\nRecarga: %d rodadas." % shot_cooldown
		SKILL_PIECES:
			var skill: PieceSkill = _piece_skill()
			title = ["Pieces", "Pieces", "My Own Goal", "Naruhaya Footwork", "See It"][skill]
			var pieces_text: String = "Cria 3 peças fixas por %d rodadas (Ataque: +%d%% e +%.1fx de força nos chutes; Meio: +%.1f s no Correr e +%d no Passe; Defesa: +%d no Carrinho). Dentro de cada uma, o botão vira uma habilidade.\nRecarga: %d após o fim." % [
					pieces_rounds, _pct(attack_piece_bonus), attack_piece_force, midfield_run_bonus, int(midfield_pass_bonus), int(defense_slide_bonus), pieces_cooldown]
			text = [
				pieces_text,
				pieces_text,
				"Um aliado no chão com a bola perto passa rasteiro para o Isagi, que chuta com %.1fx a força (sem o bônus da peça). %d%% de chance de gol." % [own_goal_force_mult, _pct(chance_own_goal)],
				"Avanço de %d que empurra para o lado quem está no chão. Achou a bola: +1 ação geral." % int(footwork_distance),
				"No turno inimigo, o 1º chute que entrar a %d dele é interceptado: no chão vira passe para o aliado mais próximo num raio de %d (se não houver nenhum, a bola fica com ele); suspenso, ele salta até a bola e dá deflect para a direita; voando, ele salta até a bola e dá deflect para trás." % [int(see_it_range), int(see_it_pass_range)],
			][skill]
			if skill >= PieceSkill.OWN_GOAL:
				text += "\nRecarga: %d rodadas (compartilhada com as outras variantes)." % variant_cooldown
		SKILL_METAVISION:
			var territory: bool = _territory_ready()
			title = "Territory" if territory else "Metavision"
			text = "%sPor %d rodadas: chutes sem QTE e +%d%% nos próximos %d chutes. Se ele for o protagonista, os secundários ganham +%d ação de habilidade.\nRecarga: %d após o fim." % [
				"Puxa a bola para ele e ativa a Metavision. " if territory else "", metavision_rounds,
				_pct(territory_bonus if territory else metavision_bonus), metavision_shots, metavision_extra_ally_skills, metavision_cooldown]
		_:
			return {}
	var icon: Texture2D = skill_icons.get(String(skill_id), skill_icons.get(skill_id)) as Texture2D
	return {"title": title, "description": text, "icon": icon}


# ---------- EFEITOS (peças de quebra-cabeça, veja isagi_fx.gd) ----------

func _body_point() -> Vector2:
	return global_position + Vector2(0.0, -height)


func _ball_point(ball: Ball) -> Vector2:
	return ball.sprite.global_position if ball.sprite != null else ball.global_position


func _puzzle_burst(pos: Vector2, amount: int = 10, strong: bool = false) -> void:
	if puzzle_particles:
		IsagiFX.burst(self, pos, amount, strong)


func _puzzle_ring(pos: Vector2, radius: float, amount: int = 14) -> void:
	if puzzle_particles:
		IsagiFX.ring(self, pos, radius, amount)


func _puzzle_line(a: Vector2, b: Vector2, amount: int = 12) -> void:
	if puzzle_particles:
		IsagiFX.line(self, a, b, amount)


func _puzzle_area(center: Vector2, size: Vector2, amount: int = 16) -> void:
	if puzzle_particles:
		IsagiFX.area(self, center, size, amount)


func _puzzle_trail(ball: Ball, seconds: float = 0.5) -> void:
	if puzzle_particles:
		IsagiFX.trail(ball, seconds)


## Chamado pelo kick_ball() logo depois que a bola sai (Backheel, Direct, Two Gun, My Own Goal e Go Beyond)
func _launch_shot_fx(ball: Ball, _dir: Vector2, _speed: float, strong: bool = false) -> void:
	_puzzle_burst(_ball_point(ball), 18 if strong else 12, strong)
	_puzzle_trail(ball, 0.7 if strong else 0.5)


## See It sem aliado ao alcance: a bola fica com o Isagi (parada nos pés dele)
func _keep_ball(ball: Ball) -> void:
	ball.register_touch(self)
	var spot: Vector2 = _clamp_to_field(global_position + Vector2(facing * (body_radius + ball.collision_radius + 6.0), 0.0), ball.collision_radius)
	await ball.hover_to(spot, 0.0, 0.15).finished
	ball.release_hover()


# ---------- PARTIDA NOVA ----------

func reset_for_new_match() -> void:
	super()
	_metavision_until_round = -1
	_meta_shots_left = 0
	_aiming_backheel = false
	_pieces_until_round = -1
	_pieces_shown = false
	_see_it_armed = false
	_see_it_live = false
	_reacting = false
	_no_piece_bonus = false
	_pass_buff = 0.0   # o Player zera o pass_range_bonus
	run_duration = _base_run
	slide_distance = _base_slide
	for z in _pieces:
		z.hide_now()
	_place_pieces()   # a partida nova volta ao lado de origem
	if _aura != null:
		_aura.emitting = false
	queue_redraw()


# ---------- LOOP / VISUAL ----------

func _process(delta: float) -> void:
	super(delta)
	if _aura != null:   # peças girando em volta dele enquanto a Metavision ou o See It estão valendo
		var want_aura: bool = is_metavision_active() or _see_it_armed or _see_it_live
		if _aura.emitting != want_aura:
			_aura.emitting = want_aura
		if want_aura:
			_aura.position = Vector2(0.0, -height)
	var active: bool = is_pieces_active()
	for z in _pieces:
		z.lit = active and z.contains(global_position)
	if state == State.IDLE:
		_update_piece_buffs()


func _physics_process(delta: float) -> void:
	super(delta)
	if _see_it_live:
		_scan_for_shot()


func _draw() -> void:
	super()
	var center := Vector2(0.0, -height)
	if is_metavision_active():   # aura ciano enquanto a Metavision está valendo
		draw_arc(center, placeholder_radius + 6.0, 0.0, TAU, 40, Color(0.3, 0.9, 1.0, 0.9), 2.0)
	if _see_it_armed or _see_it_live:   # See It: a área onde ele detecta chutes
		draw_arc(Vector2.ZERO, see_it_range, 0.0, TAU, 64, Color(0.4, 0.65, 1.0, 0.6), 2.0)
	if is_aiming and _aiming_backheel:   # Backheel: seta ciano = para onde a bola vai (a laranja é para onde ele olha)
		var d: Vector2 = -aim_direction
		var end: Vector2 = d * (placeholder_radius + aim_range)
		var side: Vector2 = d.orthogonal() * 8.0
		draw_line(d * (placeholder_radius + 4.0), end, Color.CYAN, 3.0)
		draw_colored_polygon(PackedVector2Array([end + d * 12.0, end + side, end - side]), Color.CYAN)


# ---------- PEÇA DE QUEBRA-CABEÇA (era o piece_zone.gd) ----------

## Peça desenhada no campo: só marca uma área e se desenha; quem aplica o efeito é o Isagi (contains).
## Fica logo acima da grama e atrás de jogadores e bola. Nasce escondida.
class Piece extends Node2D:
	enum Kind { ATTACK, MIDFIELD, DEFENSE }

	var kind: Kind
	var size: Vector2
	var color: Color
	var label: String
	var lit: bool = false:   # Isagi está em cima desta peça? (acende mais forte)
		set(value):
			if value != lit:
				lit = value
				queue_redraw()
	var _outline := PackedVector2Array()

	func _init(piece_kind: Kind, piece_size: Vector2, piece_color: Color, text: String) -> void:
		kind = piece_kind
		size = piece_size
		color = piece_color
		label = text
		visible = false
		z_index = -4000   # acima do campo (-4096), abaixo de tudo que usa a profundidade pelo y
		z_as_relative = false
		_outline = _build_outline()

	## Aparece com um pequeno efeito de entrada / some com um fade
	func fade(show_it: bool) -> void:
		if show_it:
			visible = true
			modulate.a = 0.0
			scale = Vector2(0.85, 0.85)
			var tw := create_tween().set_parallel(true)
			tw.tween_property(self, "modulate:a", 1.0, 0.4)
			tw.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			lit = false
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 0.0, 0.4)
			tw.tween_callback(func() -> void: visible = false)

	func hide_now() -> void:
		visible = false
		lit = false

	## A posição (global) está dentro da peça? (usa o retângulo; os encaixes são só enfeite)
	func contains(global_pos: Vector2) -> bool:
		return Rect2(global_position - size * 0.5, size).has_point(global_pos)

	func _draw() -> void:
		draw_colored_polygon(_outline, Color(color, 0.32 if lit else 0.16))
		var closed: PackedVector2Array = _outline.duplicate()
		closed.append(_outline[0])
		draw_polyline(closed, Color(color, 1.0 if lit else 0.7), 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(-size.x * 0.5, 8.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(1, 1, 1, 0.85))

	## Contorno no sentido horário (topo, direita, base, esquerda): pino para fora no topo e encaixe para dentro na base
	func _build_outline() -> PackedVector2Array:
		var h: Vector2 = size * 0.5
		var corners: Array[Vector2] = [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]
		var knobs: Array[float] = [1.0, 0.0, -1.0, 0.0]
		var pts := PackedVector2Array()
		for i in 4:
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			var outward: Vector2 = (b - a).normalized().orthogonal()
			var length: float = a.distance_to(b)
			var radius: float = length * 0.14
			for s in 48:
				var t: float = float(s) / 48.0
				var d: float = (t - 0.5) * length   # distância até o meio da borda
				var off: float = sqrt(radius * radius - d * d) * knobs[i] if absf(d) < radius else 0.0
				pts.append(a.lerp(b, t) + outward * off)
		return pts
