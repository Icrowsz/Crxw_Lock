class_name ReactionOneMoreTime
extends ChemicalReaction
## ONE MORE TIME (Hiori + Isagi). Recarga: 12 rodadas.
##
## Condições (todas ao mesmo tempo):
##  1. O Isagi está com a Metavision ativa;
##  2. O Hiori está com a Coldest Metavision ativa;
##  3. O Hiori usou o Ultrasadist (o complemento do Glacial Cut) e a bola ainda é a dele: ninguém
##     tocou nela depois. O Ultrasadist leva a bola ao local escolhido (nível Suspenso) NA MESMA
##     RODADA e ela fica pairando lá, então o Isagi pode usar o Direct Shot logo depois, no mesmo
##     turno, com a bola ainda pairando no local;
##  4. O Isagi usa o Direct Shot (bola suspensa ao alcance). O botão vira "Go Beyond".
##
## Efeito: cutscene + diálogo e o Direct Shot sai como Go Beyond: muito mais forte e com 85% de
## chance de gol, com peças de quebra-cabeça geladas, tudo azul e vidro quebrando no chute.
## O Ultrasadist do Hiori que cumpre as condições (is_ultrasadist_charged) já sai brilhando e
## congelando o chão por onde a bola passa. A parte do chute está no isagi.gd (_use_shot_skill),
## a do Ultrasadist no hiori.gd e os efeitos no one_more_time_fx.gd; aqui ficam só os dados e
## as condições.


func _init() -> void:
	id = &"one_more_time"
	display_name = "One More Time"
	trigger_id = "isagi"
	partner_id = "hiori"
	cooldown_rounds = 12
	accent = Color(0.35, 0.75, 1.0)   # azul gelo
	description = "Reação Química com o Hiori: o Direct Shot vira o Go Beyond."

	# Cutscene: troque o caminho do vídeo pelo seu (.ogv). Se o arquivo não existir, é pulado.
	video_path = "res://video/one_more_time.ogv"
	colors = {
		"hiori": Color(0.6, 0.9, 1.0),    # azul gelo
		"isagi": Color(0.2, 0.6, 1.0),    # azul Blue Lock
	}

	# Falas de exemplo: troque pelas que você quiser (a ordem é a da cutscene)
	_say("hiori", "The ice is set. I froze the pass right where you need it.")
	_say("isagi", "Every piece is on the board... and your cold fits in perfectly.")
	_say("hiori", "Then don't waste it. One more time.")
	_say("isagi", "One more time... and this time, I go beyond!")
	_say("hiori", "Break the ice, Isagi.")
	_say("isagi", "GO BEYOND!")


func find_partner(trigger: Player) -> Player:
	var isagi := trigger as Isagi
	if isagi == null:
		return null

	# 1) O Isagi está com a Metavision ativa
	if not isagi.is_metavision_active():
		return null

	var m: MatchManager = isagi._get_manager()
	var ball: Ball = isagi._get_ball()
	if m == null or ball == null:
		return null

	for p: Player in m.get_team_players(isagi.team):
		var hiori := p as Hiori
		# 2) O Hiori está com a Coldest Metavision ativa
		if hiori == null or not hiori.is_metavision_active():
			continue

		# 3) O último Ultrasadist do Hiori é o dono da bola: ninguém tocou nela depois e ela ainda paira
		var us: Dictionary = hiori.last_ultrasadist
		if us.is_empty():
			continue
		if int(us.get("touches", -1)) != ball.interaction_count or ball.last_toucher != hiori:
			continue
		if not ball.hovering:
			continue
		return hiori

	# 4) (bola suspensa ao alcance = Direct Shot) é conferido pelo próprio Isagi: só aí o botão é o Go Beyond
	return null


## O Hiori usa isto no Ultrasadist: este passe cumpre as condições da reação que já dá para saber
## (Coldest Metavision ativa, Isagi com a Metavision ativa e reação fora de recarga)? Se sim, o
## Ultrasadist sai brilhando e congelando o chão por onde a bola passa.
static func is_ultrasadist_charged(hiori: Hiori) -> bool:
	if not hiori.is_metavision_active():
		return false
	var m: MatchManager = hiori._get_manager()
	if m == null:
		return false
	var has_isagi: bool = false
	for p: Player in m.get_team_players(hiori.team):
		var isagi := p as Isagi
		if isagi != null and isagi.is_metavision_active():
			has_isagi = true
			break
	if not has_isagi:
		return false
	var rm: ReactionManager = ReactionManager.get_for(hiori)
	if rm == null:
		return false
	for reaction in rm.reactions:
		if reaction is ReactionOneMoreTime:
			return rm.is_ready(reaction, hiori.team)
	return false
