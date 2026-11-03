class_name ReactionMarionette
extends ChemicalReaction
## MARIONETTE; Rin X Aryu. Quem executa o movimento (trigger) é o ARYU (é ele que cabeceia); o parceiro é o Rin
## (preparou a jogada). Efeito: o ELEGANT HEADER do Aryu vira o MARIONETTE HEADER (veja aryu.gd, rin.gd e marionette_fx.gd).

## Chaves do Aryu.set_meta():
##  SETUP = o Rin fez o Puppets nele e a bola chegou VOANDO: {"rin": Rin, "round": rodada, "touches": toques da bola}
##          (gravado pelo rin.gd em ReactionMarionette.arm()). É o que find_partner() confere.
##  HOLD  = a reação já foi usada (cutscene rodou) e o movimento do Aryu está acontecendo: só mantém a mão do Rin
##          até o fim do cabeceio.
const META_SETUP: StringName = &"marionette_setup"
const META_HOLD: StringName = &"marionette_hold"


func _init() -> void:
	id = &"marionette"
	display_name = "Marionette"
	trigger_id = "aryu"
	partner_id = "rin"
	cooldown_rounds = 12
	accent = Color(0.176, 0.661, 0.569)   # verde-água do Rin (o marrom do Aryu aparece no contorno dele e nas estrelinhas)
	description = "Reação com o Rin: o Puppets dele leva a bola VOANDO até o Aryu, e o Elegant Header vira o Marionette Header."

	video_path = ""
	colors = {
		"rin": Color(0.176, 0.661, 0.569),
		"aryu": Color(0.55, 0.33, 0.15),
	}

	# PLACEHOLDERS: troque pelos diálogos de verdade quando tiver (ordem = ordem da cutscene)
	_say("aryu", "That's a glamorous pass, Rin-chan..")
	_say("rin", "Just don't get in my way.")
	_say("aryu", "Its okay, because...")
	_say("aryu", "THE AIR IS MY TERRITORY!")


## Condições (TODAS): é o turno do time deles; o Rin fez o PUPPETS no Aryu nesta rodada e a bola chegou VOANDO (o rin.gd
## grava isso em Aryu.get_meta("marionette_setup") quando o passe chega); a bola continua pairando no ar, sem ninguém ter
## tocado nela depois; e o Aryu está na situação do Elegant Header (bola ao alcance, suspensa/voando).
## Quem confere isto é o próprio Aryu, ANTES do cabeceio. Só confere: não toca na bola nem gasta recarga.
func find_partner(trigger: Player) -> Player:
	var aryu := trigger as Aryu
	if aryu == null or aryu.is_down:
		return null
	var m: MatchManager = aryu._get_manager()
	var ball: Ball = aryu._get_ball()
	if m == null or ball == null or m.match_over or m.current_team != aryu.team:
		return null

	# 1) O Rin preparou: Puppets no Aryu nesta rodada, com a bola chegando voando
	var info: Dictionary = aryu.get_meta(META_SETUP, {}) as Dictionary
	var raw: Variant = info.get("rin")
	if not is_instance_valid(raw):
		return null
	var rin := raw as Rin
	if rin == null or rin.is_down or rin.team != aryu.team:
		return null
	if int(info.get("round", -1)) != m.round_number:
		return null

	# 2) A bola continua VOANDO, pairando, e ninguém tocou nela depois do passe
	if not ball.hovering or ball.is_held() or ball.get_level() != Heights.Level.FLYING:
		return null
	if ball.interaction_count != int(info.get("touches", -1)):
		return null

	# 3) O Aryu está na situação do Elegant Header (bola ao alcance e no ar; não está em Glam, etc.)
	if aryu.get_header_variant() != Aryu.HeaderVariant.HEADER:
		return null
	return rin


# ---------- AUXILIARES (usados pelo rin.gd, pelo aryu.gd e pelos efeitos) ----------

## A reação está registrada e fora de recarga para este time?
static func ready_for_team(from: Node, team: int) -> bool:
	var rm: ReactionManager = ReactionManager.get_for(from)
	if rm == null:
		return false
	for r: ChemicalReaction in rm.reactions:
		if r.id == &"marionette":
			return rm.is_ready(r, team)
	return false


## O Puppets do Rin neste aliado deve virar a reação? (aliado de pé, Elegant Header sem recarga e reação pronta)
static func can_setup(rin: Player, aryu: Aryu) -> bool:
	if aryu == null or not is_instance_valid(aryu) or aryu.is_down or aryu.team != rin.team:
		return false
	if aryu.is_on_cooldown(Aryu.CD_HEADER):
		return false
	return ready_for_team(rin, rin.team)


## A reação Marionette disponível para o Aryu AGORA (fora de recarga e com todas as condições), ou null.
static func find_ready(trigger: Player) -> ChemicalReaction:
	var rm: ReactionManager = ReactionManager.get_for(trigger)
	if rm == null:
		return null
	for r: ChemicalReaction in rm.reactions:
		if r.id == &"marionette":
			return r if rm.is_ready(r, trigger.team) and r.find_partner(trigger) != null else null
	return null


## Chamado pelo Rin quando o passe do Puppets chegou: a bola fica VOANDO com o Aryu, esperando o Elegant Header.
## Devolve false se a bola não está mais do jeito esperado (aí o Puppets segue normal).
static func arm(rin: Player, aryu: Aryu, ball: Ball) -> bool:
	var m: MatchManager = rin._get_manager()
	if m == null or m.match_over or ball == null or not is_instance_valid(aryu) or aryu.is_down:
		return false
	if not ball.hovering or ball.is_held() or ball.get_level() != Heights.Level.FLYING:
		return false
	aryu.set_meta(META_SETUP, {"rin": rin, "round": m.round_number, "touches": ball.interaction_count})
	MarionetteFX.arm_hand(aryu)
	return true


## A cutscene rodou: o preparo foi usado (não dá para repetir), mas a mão do Rin fica até o fim do movimento do Aryu
static func consume(aryu: Player) -> void:
	if aryu.has_meta(META_SETUP):
		aryu.remove_meta(META_SETUP)
	aryu.set_meta(META_HOLD, true)


## Fim do turno do time: se o Aryu não cabeceou, o preparo some e a bola que ficou voando cai
static func expire(rin: Player) -> void:
	for p in rin.get_tree().get_nodes_in_group("players"):
		var aryu := p as Aryu
		if aryu == null or aryu.team != rin.team or not (aryu.has_meta(META_SETUP) or aryu.has_meta(META_HOLD)):
			continue
		var info: Dictionary = aryu.get_meta(META_SETUP, {}) as Dictionary
		var ball: Ball = rin._get_ball()
		# só solta se a bola ainda está do jeito que o passe deixou (ninguém tocou)
		if ball != null and info.has("touches") and ball.hovering and not ball.is_held() \
				and ball.interaction_count == int(info.get("touches", -1)):
			ball.release_hover()
		MarionetteFX.finish(aryu)
