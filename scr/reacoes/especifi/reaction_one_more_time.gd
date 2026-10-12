class_name ReactionOneMoreTime
extends ChemicalReaction
## ONE MORE TIME (Isagi + Hiori). Recarga: 12 rodadas (por time).
##
## Condições (todas ao mesmo tempo, na hora em que o Isagi vai chutar):
##  1. O Isagi está com a Metavision ativa;
##  2. O Hiori está com a Coldest Metavision ativa;
##  3. O Hiori usou o Ultrasadist (já "carregado", ou seja, com as duas Metavisions ativas e a
##     reação fora de recarga) e NINGUÉM tocou na bola depois dele (o Ultrasadist é um passe alto
##     para um local: a bola desce no turno seguinte do time, e é aí que o Isagi chuta);
##  4. O Isagi usa o Direct Shot (ele no chão + bola suspensa, ou os dois suspensos). O botão
##     vira "Go Beyond".
##
## Efeito: cutscene + diálogo e o Direct Shot sai como Go Beyond: 85% de chance de gol, muito mais
## forte, brilho azul de quebra-cabeças congelados e vidro quebrando na tela. A parte do chute está
## no isagi.gd (_use_shot_skill) e os efeitos visuais em one_more_time_fx.gd; aqui ficam só os
## dados e as condições.
##
## O Ultrasadist do Hiori, quando cumpre as condições, brilha e congela o chão por onde a bola
## passa (hiori.gd chama is_ultrasadist_charged() logo antes do passe).

## Marca guardada no Hiori: "o último Ultrasadist saiu carregado?" (ver is_ultrasadist_charged)
const META_CHARGED: StringName = &"omt_ultrasadist_charged"


func _init() -> void:
	id = &"one_more_time"
	display_name = "One More Time"
	trigger_id = "isagi"
	partner_id = "hiori"
	cooldown_rounds = 12
	accent = Color(0.35, 0.8, 1.0)   # azul gelo
	description = "Reação Química com o Hiori: o Direct Shot vira o Go Beyond."

	# Cutscene: troque o caminho do vídeo pelo seu (.ogv). Se o arquivo não existir, é pulado.
	video_path = "res://video/one_more_time.ogv"
	colors = {
		"isagi": Color(0.2, 0.6, 1.0),      # azul Blue Lock
		"hiori": Color(0.651, 0.882, 1.0, 1.0),    # azul gelo
	}

	# Falas de exemplo: troque pelas que você quiser (a ordem é a da cutscene)
	_say("isagi", "I wouldn't have it any other way.")
	_say("hiori", "Let's do this, buddy.")
	_say("hiori", "It's time to synchronize my vision..")
	_say("hiori", "With Isagi's goal!!!")
	_say("isagi", "WE CAN EVEN GO BEYOND..")
	_say("isagi", "OUR WILDEST DREAMS!!!")


func find_partner(trigger: Player) -> Player:
	# 1) Isagi com a Metavision ativa
	var isagi := trigger as Isagi
	if isagi == null or not isagi.is_metavision_active():
		return null

	# 2) Hiori (do mesmo time) com a Coldest Metavision ativa
	var hiori := _find_teammate(isagi, partner_id) as Hiori
	if hiori == null or not hiori.is_metavision_active():
		return null

	# 3) O último Ultrasadist do Hiori saiu "carregado" e a bola continua como ele deixou
	#    (ninguém tocou nela depois)
	var us: Dictionary = hiori.last_ultrasadist
	if us.is_empty() or not bool(hiori.get_meta(META_CHARGED, false)):
		return null
	var ball: Ball = isagi._get_ball()
	if ball == null:
		return null
	if int(us.get("touches", -1)) != ball.interaction_count or ball.last_toucher != hiori:
		return null

	# 4) (Direct Shot) é conferido pelo próprio Isagi: só aí o botão é o Go Beyond
	return hiori


## O Ultrasadist que o Hiori está usando AGORA cumpre as condições da reação? O hiori.gd chama
## isto logo antes do passe, para decidir se ele brilha. O resultado fica guardado no Hiori
## (META_CHARGED) para o find_partner() conferir depois, quando o Isagi for chutar.
static func is_ultrasadist_charged(hiori: Hiori) -> bool:
	var charged: bool = false
	if hiori != null and hiori.is_inside_tree() and hiori.is_metavision_active():
		var isagi := _find_teammate(hiori, "isagi") as Isagi
		var rm: ReactionManager = ReactionManager.get_for(hiori)
		if isagi != null and isagi.is_metavision_active() and rm != null:
			var reaction: ChemicalReaction = _lookup(rm)
			charged = reaction != null and rm.is_ready(reaction, hiori.team)
	if hiori != null:
		hiori.set_meta(META_CHARGED, charged)
	return charged


## Acha a instância registrada desta reação no ReactionManager
static func _lookup(rm: ReactionManager) -> ChemicalReaction:
	for reaction in rm.reactions:
		if reaction is ReactionOneMoreTime:
			return reaction
	return null


## Personagem do MESMO time com esse character_id (null se não existir)
static func _find_teammate(from: Player, character: String) -> Player:
	for p: Player in from.get_tree().get_nodes_in_group("players"):
		if p.team == from.team and p.character_id == character:
			return p
	return null
