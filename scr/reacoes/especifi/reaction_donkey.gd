class_name ReactionDonkey
extends ChemicalReaction
## DONKEY; Barou X Isagi. Quem executa o movimento (trigger) é o BAROU (é ele que chuta); o parceiro é o Isagi.
## Efeito: o NUTMEG do Barou vira o TWISTED PATH (chute rasteiro 2.0x, 75%; veja barou.gd e donkey_fx.gd).

## Chave do Isagi.set_meta(): o Isagi grava {"until": rodada} quando usa o TERRITORY (veja _use_metavision no isagi.gd)
const META_TERRITORY: String = "donkey_territory"


func _init() -> void:
	id = &"donkey"
	display_name = "Donkey"
	trigger_id = "barou"
	partner_id = "isagi"
	cooldown_rounds = 12
	accent = Color(0.86, 0.03, 0.05)   # vermelho do Barou (o azul do Isagi aparece nas peças)
	description = "Reação com o Isagi: com o Predator Eye do Barou e o Territory do Isagi ativos, o Nutmeg (depois do Chop King) vira o Twisted Path."

	video_path = ""
	colors = {
		"barou": Color(0.86, 0.03, 0.05),
		"isagi": Color(0.25, 0.5, 1.0),
	}

	_say("isagi", "If you want to kill me, King...")
	_say("isagi", "...Do it right now, hungry lion.")
	_say("barou", "I'll devour you in a single shot, donkey.")
	_say("barou", "NOW DIE!!")


## Condições (TODAS): é o turno do time do Barou; o PREDATOR EYE do Barou está ativo; um aliado Isagi está com o
## Territory ativo (a Metavision que ele começou como Territory ainda vale); e o Barou usou o Chop King e está com
## o NUTMEG liberado (complemento grátis, bola ao alcance). Só confere: não toca na bola nem gasta recarga.
## Quem chama é o próprio Barou, ANTES do chute (veja _use_nutmeg no barou.gd).
func find_partner(trigger: Player) -> Player:
	# 1) turno do time + 2) Predator Eye do Barou + 3) Territory do Isagi (tudo em find_setup)
	var isagi: Isagi = find_setup(trigger)
	if isagi == null:
		return null

	# 4) O Nutmeg está liberado (Chop King feito, bola no chão, livre e ao alcance)
	var barou := trigger as Barou
	if barou == null or not barou.has_free_followup():
		return null
	return isagi


# ---------- AUXILIARES (também usados pelos efeitos e pelo Barou) ----------

## A "preparação" da reação, sem o Nutmeg: turno do time do Barou + Predator Eye ativo + Isagi aliado com o
## Territory ativo. Devolve o Isagi ou null. Só confere.
static func find_setup(trigger: Player) -> Isagi:
	var barou := trigger as Barou
	if barou == null or barou.is_down:
		return null
	var m: MatchManager = barou._get_manager()
	if m == null or m.match_over or m.current_team != barou.team:
		return null
	if not barou._eye_active():
		return null
	return find_territory_isagi(barou)


## Isagi aliado, de pé, com o Territory ainda valendo (a Metavision dele está ativa e começou como Territory)
static func find_territory_isagi(barou: Player) -> Isagi:
	for p in barou.get_tree().get_nodes_in_group("players"):
		var isagi := p as Isagi
		if isagi != null and isagi.team == barou.team and not isagi.is_down and territory_alive(isagi):
			return isagi
	return null


static func territory_alive(isagi: Isagi) -> bool:
	var m: MatchManager = isagi._get_manager()
	if m == null or not isagi.has_meta(META_TERRITORY) or not isagi.is_metavision_active():
		return false
	var info: Dictionary = isagi.get_meta(META_TERRITORY) as Dictionary
	return m.round_number <= int(info.get("until", -1))


## Barou aliado, de pé, com o Predator Eye ativo (usado pelas peças que giram em volta do Isagi)
static func find_eye_barou(isagi: Player) -> Barou:
	for p in isagi.get_tree().get_nodes_in_group("players"):
		var barou := p as Barou
		if barou != null and barou.team == isagi.team and not barou.is_down and barou._eye_active():
			return barou
	return null


## A reação não está em recarga para este time? (false também se ela não foi registrada ainda)
static func ready_for_team(from: Node, team: int) -> bool:
	var rm: ReactionManager = ReactionManager.get_for(from)
	if rm == null:
		return false
	for r: ChemicalReaction in rm.reactions:
		if r.id == &"donkey":
			return rm.is_ready(r, team)
	return false


## "Preparação" pronta E fora de recarga: é isto que liga o rastro negro dos dashes do Chop King
static func setup_ready(trigger: Player) -> bool:
	return find_setup(trigger) != null and ready_for_team(trigger, trigger.team)


## A reação Donkey disponível para o Barou AGORA (com o Nutmeg liberado e fora de recarga), ou null.
## Não usa rm.find_available(): ele devolveria a primeira reação do Barou na lista (ex: Feeding) e esconderia esta.
static func find_ready(trigger: Player) -> ChemicalReaction:
	var rm: ReactionManager = ReactionManager.get_for(trigger)
	if rm == null:
		return null
	for r: ChemicalReaction in rm.reactions:
		if r.id == &"donkey":
			return r if rm.is_ready(r, trigger.team) and r.find_partner(trigger) != null else null
	return null
