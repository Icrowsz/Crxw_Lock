class_name ReactionSuperstar
extends ChemicalReaction
## SUPERSTAR (Kiyora + Kaiser). Recarga: 12 rodadas.
##
## Condições (todas ao mesmo tempo):
##  1. A Kiyora está sob o efeito do Empire do Kaiser, como Servo GARÇOM;
##  2. A Kiyora usou o Borderline ou o Even the Gods e a bola foi parar no Kaiser (ele era um dos
##     dois aliados escolhidos E tinha menos gols, ou venceu o sorteio do empate). Ninguém tocou
##     na bola depois do passe, e ela ainda está no ar (pairando) esperando por ele;
##  3. É o turno do time deles e o Kaiser alcança a bola. O botão do chute dele vira "Be Loved".
##
## Efeito: cutscene + diálogo e o chute do Kaiser sai como Be Loved: um Magnus mais forte, com 85%
## de chance de gol e uma trilha de rosas azuis e rosas em volta da bola. A parte do chute e dos
## efeitos está no kaiser.gd (_use_shot_skill); a balança dourada está no kiyora.gd (_use_border);
## os desenhos estão no superstar_fx.gd. Aqui ficam só os dados e as condições.
##
## OBS: o Borderline/Even the Gods sempre entregam a bola SUSPENSA, e o Magnus normal só existe
## com a bola no chão. Por isso, com a Superstar de pé, o Be Loved vale com a bola em qualquer
## altura que o Kaiser alcance (no chão, ele chuta a bola suspensa; suspenso, também).


func _init() -> void:
	id = &"superstar"
	display_name = "Superstar"
	trigger_id = "kaiser"        # quem executa o movimento (o chute)
	partner_id = "kiyora"        # quem deu o passe
	cooldown_rounds = 12
	accent = Color(1.0, 0.80, 0.22)   # dourado da balança
	description = "Reação Química com a Kiyora: o Magnus vira o Be Loved."

	# Cutscene: troque o caminho do vídeo pelo seu (.ogv). Se o arquivo não existir, é pulado.
	video_path = "res://video/superstar.ogv"
	colors = {
		"kiyora": Color(0.28, 0.68, 0.64),   # azul esverdeado dela
		"kaiser": Color(0.25, 0.42, 1.0),    # azul rosa do Kaiser
	}

	# Falas de exemplo: troque pelas que você quiser (a ordem é a da cutscene)
	_add_speaker("ego", "Ego", "res://img/rostinhos/ego.png", Color(0.27, 0.27, 0.27, 1.0))
	_say("kiyora", "With my borderline decisions...")
	_say("kiyora", "Not even the Gods know who I choose to side with.")
	_say("ego", "An Emperor that's willing to sacrifice everything...")
	_say("ego", "...For his evolution...")
	_say("kaiser", "AAAARRRHHHH")


func find_partner(trigger: Player) -> Player:
	var kaiser := trigger as Kaiser
	if kaiser == null:
		return null

	var m: MatchManager = kaiser._get_manager()
	var ball: Ball = kaiser._get_ball()
	if m == null or ball == null or m.match_over or m.current_team != kaiser.team:
		return null

	# A bola precisa estar pairando (o passe alto ainda não caiu), já ter chegado ao Kaiser (não
	# está mais Voando no meio do caminho) e ele precisa alcançá-la
	if not ball.hovering or ball.is_held() or ball.get_level() == Heights.Level.FLYING:
		return null
	if kaiser.get_kick_type(ball) == Player.KickType.NONE:
		return null

	for p: Player in m.get_team_players(kaiser.team):
		var kiyora := p as Kiyora
		if kiyora == null:
			continue
		# 1) Ela é o Servo Garçom do Empire
		if not kaiser.is_waiter(kiyora):
			continue
		# 2) O último passe dela (Borderline / Even the Gods) foi para o Kaiser e a bola não foi
		#    tocada por mais ninguém depois
		var pass_info: Dictionary = kiyora.last_border_pass
		if pass_info.is_empty() or pass_info.get("target") != kaiser:
			continue
		if int(pass_info.get("touches", -1)) != ball.interaction_count or ball.last_toucher != kiyora:
			continue
		return kiyora
	return null
