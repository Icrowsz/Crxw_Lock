class_name ReactionCruel
extends ChemicalReaction
## CRUEL (Charles + Rin). Recarga: 12 rodadas.
##
## Condições (todas ao mesmo tempo):
##  1. O Charles usou o Rabona Cross e a bola ainda é a dele: ninguém tocou nela depois. O Rabona
##     Cross leva a bola ao local escolhido (nível Suspenso) NA MESMA RODADA e ela fica pairando
##     lá, então o Rin pode usar o Crash Shot logo depois, no mesmo turno (ou no próximo turno do
##     time, se a bola ainda estiver pairando);
##  2. O Rin está com o Destroyer Mode ativo;
##  3. O Rin usa o Crash Shot (ele suspenso + bola suspensa + inimigo colado nele). O botão vira
##     "Self Destruction".
##
## Efeito: cutscene + diálogo e o Crash Shot sai como Self Destruction: a força do chute aumenta
## muito, a curva é a mesma, 90% de chance de gol, com uma sombra gigante cheia de olhos e uma mão
## sobre o Rin e espinhos em volta dele e ao longo da trajetória. O Rabona Cross do Charles que
## cumpre as condições (is_rabona_charged) já sai brilhando mais, com um demônio gigante cobrindo
## o Charles. A parte do chute está no rin.gd (_use_curve_skill), a do Rabona no charles.gd e os
## efeitos no cruel_fx.gd; aqui ficam só os dados e as condições.


func _init() -> void:
	id = &"cruel"
	display_name = "Cruel"
	trigger_id = "rin"
	partner_id = "charles"
	cooldown_rounds = 12
	accent = Color(0.2, 0.9, 0.8)   # azul-esverdeado do Rin
	description = "Reação Química com o Charles: o Crash Shot vira o Self Destruction."

	# Cutscene: troque o caminho do vídeo pelo seu (.ogv). Se o arquivo não existir, é pulado.
	video_path = "res://video/cruel.ogv"
	colors = {
		"charles": Color(1.0, 0.85, 0.2),   # amarelo
		"rin": Color(0.18, 0.9, 0.75),      # azul-esverdeado
	}

	# Falas de exemplo: troque pelas que você quiser (a ordem é a da cutscene)
	_say("rin", "If i score like that... it would be lukewarm, right?")
	_say("rin", "Would you like to die with me, devil?")
	_say("charles", "HA! You're crazy!")
	_say("charles", "Alright then.. TIME TO GET CRUEL!")
	_say("rin", "Have you ever played football...")
	_say("rin", "WITH YOUR LIFE ON THE LINE??")


func find_partner(trigger: Player) -> Player:
	var rin := trigger as Rin
	if rin == null:
		return null

	# 2) O Rin está com o Destroyer Mode ativo
	if not rin.is_destroyer_active():
		return null

	var m: MatchManager = rin._get_manager()
	var ball: Ball = rin._get_ball()
	if m == null or ball == null:
		return null

	for p: Player in m.get_team_players(rin.team):
		var charles := p as Charles
		if charles == null:
			continue

		# 1) O último Rabona Cross do Charles é o dono da bola: ninguém tocou nela depois e ela ainda paira
		var rb: Dictionary = charles.last_rabona
		if rb.is_empty():
			continue
		if int(rb.get("touches", -1)) != ball.interaction_count or ball.last_toucher != charles:
			continue
		if not ball.hovering:
			continue
		return charles

	# 3) (Rin suspenso + bola suspensa + inimigo colado = Crash Shot) é conferido pelo próprio Rin:
	#    só aí o botão é o Self Destruction
	return null


## O Charles usa isto no Rabona Cross: este passe cumpre as condições da reação que já dá para
## saber (um Rin do time com o Destroyer Mode ativo e a reação fora de recarga)? Se sim, o Rabona
## sai brilhando mais e o demônio gigante cobre o Charles.
static func is_rabona_charged(charles: Charles) -> bool:
	var m: MatchManager = charles._get_manager()
	if m == null:
		return false
	var has_rin: bool = false
	for p: Player in m.get_team_players(charles.team):
		var rin := p as Rin
		if rin != null and rin.is_destroyer_active():
			has_rin = true
			break
	if not has_rin:
		return false
	var rm: ReactionManager = ReactionManager.get_for(charles)
	if rm == null:
		return false
	for reaction in rm.reactions:
		if reaction is ReactionCruel:
			return rm.is_ready(reaction, charles.team)
	return false
